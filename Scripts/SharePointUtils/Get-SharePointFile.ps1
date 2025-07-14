#Requires -Modules Selenium

<#
.SYNOPSIS
    Downloads files from SharePoint 2019 and SharePoint 365 using persistent Chrome sessions.

.DESCRIPTION
    A modular SharePoint file downloader with clear public/private API separation.
    Public functions: Get-SharePointFile, Initialize-AuthenticationSessions
    All other functions are private implementation details.

.PARAMETER Url
    The direct URL to the SharePoint file to download.

.PARAMETER DestDir
    Optional custom destination directory for the downloaded file.

.PARAMETER DoNotPersist
    Switch to create temporary session instead of using/creating persistent sessions.

.PARAMETER Open
    Switch to open the file after successful download.

.EXAMPLE
    .\Get-SharePointFile-Redesigned.ps1
    # Setup mode - launches authentication sessions for both SP environments

.EXAMPLE
    .\Get-SharePointFile-Redesigned.ps1 -Url "https://tenant.sharepoint.com/sites/hr/Documents/policy.pdf"
    # Download mode - downloads specified file using persistent sessions

.EXAMPLE
    # When sourced:
    . .\Get-SharePointFile-Redesigned.ps1
    Get-SharePointFile -Url $url -DoNotPersist
    Initialize-AuthenticationSessions -Url $setupUrl

.NOTES
    Prerequisites:
    - Selenium PowerShell module (Install-Module -Name Selenium)
    - Google Chrome installed
    - Edit the CONFIGURATION section below for your environment
#>

[CmdletBinding()]
param(
    [string]$Url,
    [string]$DestDir,
    [switch]$DoNotPersist,
    [switch]$Open
)

#====================================================================================
# CONFIGURATION SECTION
# Edit these values for your environment
#====================================================================================

# SharePoint 365 Settings
$script:SP365_DefaultLoginUrl = "https://yourtenant.sharepoint.com"
$script:SP365_DebugPort = 9222

# SharePoint 2019 Settings
$script:SP2019_DefaultLoginUrl = "https://your-onprem-sharepoint.company.com"
$script:SP2019_DebugPort = 9223

# Download Settings
$script:DownloadTimeoutSeconds = 300
$script:CheckIntervalSeconds = 1
$script:DefaultDownloadPath = [System.IO.Path]::Combine($env:USERPROFILE, "Downloads")

# SharePoint Version Constants
$script:SP_VERSION_365 = "365"
$script:SP_VERSION_2019 = "2019"

# Session tracking variables
$script:ChromeDriver_SP365 = $null
$script:ChromeDriver_SP2019 = $null

#====================================================================================
# PUBLIC API FUNCTIONS
#====================================================================================

#====================================================================================
#region Get-SharePointFile
<#
.SYNOPSIS
    Main function to download SharePoint files with session management.

.DESCRIPTION
    This function handles the entire process of downloading a file from SharePoint.
    It connects to the appropriate SharePoint session, downloads the specified file,
    and optionally moves it to a specified destination directory and opens it.

.PARAMETER Url
    The direct URL to the SharePoint file to download.

.PARAMETER DestDir
    Optional custom destination directory for the downloaded file.

.PARAMETER DoNotPersist
    Switch to create a temporary session instead of using/creating persistent sessions.

.PARAMETER Open
    Switch to open the file after a successful download.

.OUTPUTS
    A PSCustomObject containing the success status, file path, file name, start time,
    duration, and size in bytes of the downloaded file.

.EXAMPLE
    Get-SharePointFile -Url "https://tenant.sharepoint.com/sites/hr/Documents/policy.pdf"
    # Downloads the specified file using persistent sessions.

.EXAMPLE
    Get-SharePointFile -Url "https://tenant.sharepoint.com/sites/hr/Documents/policy.pdf" -DestDir "C:\Downloads"
    # Downloads the specified file and moves it to "C:\Downloads".

.EXAMPLE
    Get-SharePointFile -Url "https://tenant.sharepoint.com/sites/hr/Documents/policy.pdf" -DoNotPersist
    # Downloads the specified file using a temporary session.

.EXAMPLE
    Get-SharePointFile -Url "https://tenant.sharepoint.com/sites/hr/Documents/policy.pdf" -Open
    # Downloads the specified file and opens it after the download is complete.
#>
#endregion
#====================================================================================
function Get-SharePointFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,
        [string]$DestDir = "",
        [switch]$OverWriteDest,
        [switch]$OpenFile,
        [switch]$DoNotPersist
     )
    
    $result = $null
    $sessionInfo = $null
    
    try {
        Write-Host "Starting SharePoint file download..." -ForegroundColor Cyan
        
        # Connect to SharePoint session
        $sessionInfo = _ConnectSharePointSession -Url $Url
        
        if (-not $sessionInfo -or -not $sessionInfo.Driver) {
            $result = @{
                Success = $false
                Error = "Failed to establish SharePoint session"
                FilePath = $null
                Duration = [TimeSpan]::Zero
            }
        }
        else {
            # Download the file
            $downloadResult = _RequestSharePointFile -Driver $sessionInfo.Driver -Url $Url
            
            if ($downloadResult -and $downloadResult.Success) {
                $finalPath = $downloadResult.FilePath
                
                # Move to destination if specified
                if ($DestDir) {
                    $moveResult = _MoveDownloadedFile -SourcePath $downloadResult.FilePath -DestinationPath $DestDir
                    if ($moveResult -and $moveResult.Success) {
                        $finalPath = $moveResult.FilePath
                    }
                }
                
                $result = @{
                    Success = $true
                    FilePath = $finalPath
                    FileName = Split-Path $finalPath -Leaf
                    StartTime = $downloadResult.StartTime
                    Duration = $downloadResult.Duration
                    SizeBytes = $downloadResult.SizeBytes
                }
                
                Write-Host "Download completed successfully!" -ForegroundColor Green
                Write-Host "File: $finalPath" -ForegroundColor White
                Write-Host "Duration: $($result.Duration.TotalSeconds) seconds" -ForegroundColor White
                
                if ($Open) {
                    _OpenDownloadedFile -FilePath $finalPath
                }
            }
            else {
                $result = $downloadResult
            }
        }
    }
    catch {
        $result = @{
            Success = $false
            Error = "Unexpected error: $($_.Exception.Message)"
            FilePath = $null
            Duration = [TimeSpan]::Zero
        }
        Write-Error $result.Error
    }
    finally {
        # Clean up if DoNotPersist
        if ($DoNotPersist -and $sessionInfo -and $sessionInfo.Driver) {
            try {
                Stop-SeDriver -Driver $sessionInfo.Driver -ErrorAction SilentlyContinue
                Write-Host "Temporary session closed." -ForegroundColor Gray
            }
            catch {
                Write-Warning "Error closing temporary session: $_"
            }
        }
    }
    
    return $result
}

#====================================================================================
#region Initialize-AuthenticationSessions
<#
.SYNOPSIS
    Sets up authentication session for a specific SharePoint environment.

.DESCRIPTION
    This function initializes the authentication session for a specified SharePoint environment.
    It determines the SharePoint version from the provided URL, connects to the appropriate session,
    and returns the session details.

.PARAMETER Url
    The URL of the SharePoint environment to set up the authentication session for.

.OUTPUTS
    A PSCustomObject containing the driver, success status, SharePoint version, and any error message.

.EXAMPLE
    Initialize-AuthenticationSessions -Url "https://yourtenant.sharepoint.com"
    # Sets up the authentication session for SharePoint 365.

.EXAMPLE
    Initialize-AuthenticationSessions -Url "https://your-onprem-sharepoint.company.com"
    # Sets up the authentication session for SharePoint 2019.
#>
#endregion
#====================================================================================
function Initialize-AuthenticationSessions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Url
    )
    
    $result = @{
        Driver = $null
        Success = $false
        SpVer = ""
        Error = ""
    }
    
    try {
        # Determine which SharePoint version we're setting up
        $spVer = _ResolveSharePointVersion -Url $Url
        $result.SpVer = $spVer
        
        $spName = if ($spVer -eq $script:SP_VERSION_365) { "SharePoint $script:SP_VERSION_365" } else { "SharePoint $script:SP_VERSION_2019" }
        
        Write-Host "Setting up $spName session..." -ForegroundColor Green
        
        $sessionResult = _ConnectSharePointSession -Url $Url
        
        if ($sessionResult -and $sessionResult.Driver) {
            Write-Host "$spName session established successfully." -ForegroundColor Green
            $result.Driver = $sessionResult.Driver
            $result.Success = $true
        }
        else {
            $errorMsg = "Failed to establish $spName session."
            Write-Warning $errorMsg
            $result.Error = $errorMsg
        }
    }
    catch {
        $errorMsg = "Error setting up authentication session: $($_.Exception.Message)"
        Write-Error $errorMsg
        $result.Error = $errorMsg
    }
    
    return $result
}

#====================================================================================
# PRIVATE IMPLEMENTATION FUNCTIONS
#====================================================================================

#====================================================================================
#region _ConnectSharePointSession
<#
.SYNOPSIS
    Establishes connection to appropriate SharePoint session based on URL.
#>
#====================================================================================
#endregion
function _ConnectSharePointSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )
    
    $result = $null
    
    try {
        # Get session info for this URL
        $sessionInfo = _GetSharePointSessionInfo -Url $Url
        
        if ($sessionInfo) {
            # Connect to auth session
            $driver = _ConnectAuthSession -SessionInfo $sessionInfo
            
            if ($driver) {
                $result = @{
                    Driver = $driver
                    SpVer = $sessionInfo.SpVer
                    AuthPort = $sessionInfo.AuthPort
                    AuthUrl = $sessionInfo.AuthUrl
                }
            }
        }
    }
    catch {
        Write-Error "Failed to connect to SharePoint session: $_"
        $result = $null
    }
    
    return $result
}

#====================================================================================
#region _GetSharePointSessionInfo
<#
.SYNOPSIS
    Resolves SharePoint version and returns session configuration info.
#>
#====================================================================================
#endregion
function _GetSharePointSessionInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )
    
    $sessionInfo = $null
    
    try {
        # Resolve SharePoint version
        $spVer = _ResolveSharePointVersion -Url $Url
        
        # Get existing driver based on version
        $existingDriver = $null
        $authPort = 0
        $authUrl = ""
        
        if ($spVer -eq $script:SP_VERSION_365) {
            $existingDriver = $script:ChromeDriver_SP365
            $authPort = $script:SP365_DebugPort
            $authUrl = $script:SP365_DefaultLoginUrl
        }
        else {
            $existingDriver = $script:ChromeDriver_SP2019
            $authPort = $script:SP2019_DebugPort
            
            # For SP2019, derive auth URL from the request URL
            $urlObject = [System.Uri]$Url
            $authUrl = "$($urlObject.Scheme)://$($urlObject.Host)"
        }
        
        # Return session info object
        $sessionInfo = @{
            Driver = $existingDriver
            SpVer = $spVer
            AuthPort = $authPort
            AuthUrl = $authUrl
        }
    }
    catch {
        Write-Error "Failed to get session info: $_"
        $sessionInfo = $null
    }
    
    return $sessionInfo
}

#====================================================================================
#region _ResolveSharePointVersion
<#
.SYNOPSIS
    Determines SharePoint version (365 or 2019) from URL pattern.
#>
#====================================================================================
#endregion
function _ResolveSharePointVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )
    
    $version = ""
    
    if ($Url -match "\.sharepoint\.com") {
        $version = $script:SP_VERSION_365
    }
    else {
        $version = $script:SP_VERSION_2019
    }
    
    return $version
}

#====================================================================================
#region _ConnectAuthSession
<#
.SYNOPSIS
    Connects to or creates authentication session for SharePoint
#>
#====================================================================================
#endregion
function _ConnectAuthSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$SessionInfo
    )
    
    $driver = $null
    
    try {
        # If driver exists, test validity
        if ($SessionInfo -and $SessionInfo.Driver) {
            $isValid = _TestSessionValidity -Driver $SessionInfo.Driver -CanaryUrl $SessionInfo.AuthUrl
            
            # If valid, return existing driver
            if ($isValid) {
                Write-Host "Using existing $($SessionInfo.SpVer) session" -ForegroundColor Green
                $driver = $SessionInfo.Driver
            }
            else {
                Write-Host "Existing $($SessionInfo.SpVer) session invalid, recreating..." -ForegroundColor Yellow
                # If invalid, recreate
                $driver = _StartAuthSession -SessionInfo $SessionInfo
            }
        }
        else {
            # No existing driver, start new session
            $driver = _StartAuthSession -SessionInfo $SessionInfo
        }
    }
    catch {
        Write-Error "Failed to connect to auth session: $_"
        $driver = $null
    }
    
    return $driver
}

#====================================================================================
#region _StartAuthSession
<#
.SYNOPSIS
    Creates new authentication session, attempting persistent connection first.
#>
#====================================================================================
#endregion
function _StartAuthSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$SessionInfo
    )
    
    $driver = $null
    
    try {
        # Try to connect to existing debug session first (original pattern)
        if ($SessionInfo) {
            $connectionTest = _TestChromeDebugConnection -Port $SessionInfo.AuthPort
            
            if ($connectionTest) {
                try {
                    $driver = Start-SeChrome -ChromeDebuggerAddress "localhost:$($SessionInfo.AuthPort)"
                    Write-Host "Connected to existing Chrome debug session on port $($SessionInfo.AuthPort)" -ForegroundColor Green
                }
                catch {
                    Write-Warning "Failed to connect to debug session: $_"
                    $driver = $null
                }
            }
            
            # If debug connection failed, start normal Selenium session (original pattern)
            if (-not $driver) {
                $driver = Start-SeChrome
                Enter-SeUrl -Url $SessionInfo.AuthUrl -Driver $driver
                Write-Host "Started new Chrome session for $($SessionInfo.SpVer)" -ForegroundColor Cyan
                Write-Host "Please complete authentication in the browser window." -ForegroundColor Yellow
                $null = Read-Host "Press Enter after completing login" -ForegroundColor Cyan
            }
            
            # 🔄 CRITICAL: Store driver in script variable for reuse
            if ($driver) {
                if ($SessionInfo.SpVer -eq $script:SP_VERSION_365) {
                    $script:ChromeDriver_SP365 = $driver
                    Write-Verbose "Stored driver in script:ChromeDriver_SP365"
                }
                else {
                    $script:ChromeDriver_SP2019 = $driver
                    Write-Verbose "Stored driver in script:ChromeDriver_SP2019"
                }
            }
        }
        else {
            Write-Error "SessionInfo is null" -ForegroundColor Red
        }
    }
    catch {
        Write-Error "Failed to start auth session: $_" -ForegroundColor Red
        $driver = $null
    }
    
    return $driver
}

#====================================================================================
#region _TestChromeDebugConnection
<#
.SYNOPSIS
    Tests if Chrome remote debugging port is accessible.
#>
#====================================================================================
#endregion
function _TestChromeDebugConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port
    )
    
    $result = $false
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connectResult = $tcpClient.BeginConnect('localhost', $Port, $null, $null)
        $result = $connectResult.AsyncWaitHandle.WaitOne(500, $false)
        
        if ($result) {
            $tcpClient.EndConnect($connectResult)
        }
        
        $tcpClient.Close()
    }
    catch {
        $result = $false
    }
    
    return $result
}

#====================================================================================
#region _TestSessionValidity
<#
.SYNOPSIS
    Checks if the current browser session is still authenticated.
#>
#====================================================================================
#endregion
function _TestSessionValidity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Driver,
        
        [Parameter(Mandatory = $true)]
        [string]$CanaryUrl
    )
    
    $isValid = $false
    
    try {
        # Navigate to canary URL to test authentication
        Enter-SeUrl -Url $CanaryUrl -Driver $Driver
        Start-Sleep -Seconds 1
        
        $redirectedUrl = Get-SeUrl -Driver $Driver
        $isValid = $redirectedUrl -notmatch "login\.microsoftonline\.com|login\.microsoft\.com"
    }
    catch {
        Write-Warning "Session validity test failed: $_"
        $isValid = $false
    }
    
    return $isValid
}

#====================================================================================
#region _RequestSharePointFile
<#
.SYNOPSIS
    Downloads file from SharePoint URL and monitors completion.
#>
#====================================================================================
#endregion
function _RequestSharePointFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Driver,
        
        [Parameter(Mandatory = $true)]
        [string]$Url
    )
    
    $result = $null
    
    try {
        # Start timer
        $startTime = Get-Date
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Extract filename from URL
        $fileName = _GetFileNameFromUrl -Url $Url
        $downloadPath = Join-Path $script:DefaultDownloadPath $fileName
        $tempDownloadPath = "$downloadPath.crdownload"
        
        # Clear any existing files
        _RemoveExistingDownloadFiles -FilePath $downloadPath -TempFilePath $tempDownloadPath
        
        Write-Host "Starting download: $fileName" -ForegroundColor Cyan
        Write-Host "    URL = $url"
        
        # Download file
        Enter-SeUrl -Url $Url -Driver $Driver
        
        # Monitor download completion
        $downloadCompleted = _WaitForDownloadCompletion -FilePath $downloadPath -TempFilePath $tempDownloadPath
        
        # Stop timer
        $timer.Stop()
        
        if ($downloadCompleted) {
            $fileSize = (Get-Item $downloadPath).Length
            
            # Return success result
            $result = @{
                Success = $true
                FilePath = $downloadPath
                FileName = $fileName
                StartTime = $startTime
                Duration = $timer.Elapsed
                SizeBytes = $fileSize
            }
        }
        else {
            $result = @{
                Success = $false
                Error = "Download timeout after $script:DownloadTimeoutSeconds seconds"
                FilePath = $null
                StartTime = $startTime
                Duration = $timer.Elapsed
                SizeBytes = 0
            }
        }
    }
    catch {
        $result = @{
            Success = $false
            Error = "Download error: $($_.Exception.Message)"
            FilePath = $null
            StartTime = if ($startTime) { $startTime } else { Get-Date }
            Duration = if ($timer) { $timer.Elapsed } else { [TimeSpan]::Zero }
            SizeBytes = 0
        }
    }
    
    return $result
}

#====================================================================================
#region _GetFileNameFromUrl
<#
.SYNOPSIS
    Extracts filename from SharePoint URL with URL decoding.
#>
#====================================================================================
#endregion
function _GetFileNameFromUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )
    
    $fileName = "DownloadedFile_$(Get-Date -Format 'yyyyMMddHHmmss')"
    
    try {
        $uri = [System.Uri]$Url
        $pathSegment = $uri.Segments[-1]
        $decodedSegment = [System.Web.HttpUtility]::UrlDecode($pathSegment)
        
        if ($decodedSegment -and $decodedSegment -ne "/" -and $decodedSegment.Contains(".")) {
            $fileName = $decodedSegment.Trim('/')
        }
    }
    catch {
        Write-Warning "Could not extract filename from URL. Using generated name: $fileName"
    }
    
    return $fileName
}

#====================================================================================
#region _RemoveExistingDownloadFiles
<#
.SYNOPSIS
    Removes existing download files to prevent conflicts.
#>
#====================================================================================
#endregion
function _RemoveExistingDownloadFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$TempFilePath
    )
    
    $filesToRemove = @($FilePath, $TempFilePath)
    
    foreach ($file in $filesToRemove) {
        if (Test-Path $file) {
            try {
                Remove-Item $file -Force
            }
            catch {
                Write-Warning "Could not remove existing file: $file - $_"
            }
        }
    }
}

#====================================================================================
#region _WaitForDownloadCompletion
<#
.SYNOPSIS
    Monitors download progress until completion or timeout.
#>
#====================================================================================
#endregion
function _WaitForDownloadCompletion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$TempFilePath
    )
    
    $completed = $false
    $elapsedSeconds = 0
    
    while ($elapsedSeconds -lt $script:DownloadTimeoutSeconds) {
        # Check if download is complete
        if ((Test-Path $FilePath) -and -not (Test-Path $TempFilePath)) {
            # Additional verification
            Start-Sleep -Seconds 1
            if ((Test-Path $FilePath) -and -not (Test-Path $TempFilePath)) {
                $completed = $true
                break
            }
        }
        
        Start-Sleep -Seconds $script:CheckIntervalSeconds
        $elapsedSeconds += $script:CheckIntervalSeconds
        
        # Progress feedback every 10 seconds
        if ($elapsedSeconds % 10 -eq 0) {
            Write-Host "Download in progress... ($elapsedSeconds/$script:DownloadTimeoutSeconds seconds)" -ForegroundColor Yellow
        }
    }
    
    return $completed
}

#====================================================================================
#region _MoveDownloadedFile
<#
.SYNOPSIS
    Moves downloaded file to destination with unique naming.
#>
#====================================================================================
#endregion
function _MoveDownloadedFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )
    
    $result = $null
    
    try {
        # Ensure destination directory exists
        if (-not (Test-Path $DestinationPath)) {
            New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        }
        
        $fileName = Split-Path $SourcePath -Leaf
        $targetPath = Join-Path $DestinationPath $fileName
        $uniquePath = _GetUniqueFilePath -Path $targetPath
        
        Move-Item -Path $SourcePath -Destination $uniquePath -Force
        
        $result = @{
            Success = $true
            FilePath = $uniquePath
            OriginalPath = $SourcePath
        }
        
        Write-Host "File moved to: $uniquePath" -ForegroundColor Cyan
    }
    catch {
        $result = @{
            Success = $false
            Error = "Failed to move file: $($_.Exception.Message)"
            FilePath = $SourcePath
        }
        Write-Error $result.Error
    }
    
    return $result
}

#====================================================================================
#region _GetUniqueFilePath
<#
.SYNOPSIS
    Generates unique file path if target already exists.
#>
#====================================================================================
#endregion
function _GetUniqueFilePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    $uniquePath = $Path
    
    if (Test-Path $Path) {
        $directory = Split-Path $Path -Parent
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        $extension = [System.IO.Path]::GetExtension($Path)
        $counter = 1
        
        do {
            $uniquePath = Join-Path $directory "$baseName ($counter)$extension"
            $counter++
        } while (Test-Path $uniquePath)
    }
    
    return $uniquePath
}

#====================================================================================
#region _OpenDownloadedFile
<#
.SYNOPSIS
    Opens downloaded file with default application.
#>
#====================================================================================
#endregion
function _OpenDownloadedFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        if (Test-Path $FilePath) {
            Invoke-Item $FilePath
            Write-Host "Opened file: $FilePath" -ForegroundColor Green
        }
        else {
            Write-Error "File not found: $FilePath"
        }
    }
    catch {
        Write-Error "Failed to open file: $_"
    }
}

#====================================================================================
# SCRIPT EXECUTION ENTRY POINT
#====================================================================================

# Only execute main logic if script is run directly (not sourced)
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = 0
    
    try {
        if ($Url) {
            # Download mode - download the specified file
            Write-Host "SharePoint File Downloader - Download Mode" -ForegroundColor Cyan
            $downloadResult = Get-SharePointFile -Url $Url -DestDir $DestDir -DoNotPersist:$DoNotPersist -Open:$Open
            
            if (-not $downloadResult -or -not $downloadResult.Success) {
                Write-Error "Download failed: $(if ($downloadResult) { $downloadResult.Error } else { 'Unknown error' })"
                $exitCode = 1
            }
        }
        else {
            # Setup mode - initialize authentication sessions
            Write-Host "SharePoint File Downloader - Setup Mode" -ForegroundColor Cyan
            Write-Host "Setting up authentication sessions for SharePoint environments..." -ForegroundColor Yellow
            Write-Host ""
            
            $setupSuccess = $false
            
            # Setup SP365 session
            if ($script:SP365_DefaultLoginUrl) {
                $sp365Result = Initialize-AuthenticationSessions -Url $script:SP365_DefaultLoginUrl
                if ($sp365Result.Success) {
                    $setupSuccess = $true
                }
            }
            
            # Setup SP2019 session  
            if ($script:SP2019_DefaultLoginUrl) {
                $sp2019Result = Initialize-AuthenticationSessions -Url $script:SP2019_DefaultLoginUrl
                if ($sp2019Result.Success) {
                    $setupSuccess = $true
                }
            }
            
            if ($setupSuccess) {
                Write-Host ""
                Write-Host "Setup complete. You can now use the script to download files:" -ForegroundColor Cyan
                Write-Host "  .\Get-SharePointFile-Redesigned.ps1 -Url `"your-sharepoint-url`"" -ForegroundColor White
            }
            else {
                Write-Warning "No SharePoint sessions could be established."
                $exitCode = 1
            }
        }
    }
    catch {
        Write-Error "Script execution failed: $_"
        $exitCode = 1
    }
    
    exit $exitCode
}
