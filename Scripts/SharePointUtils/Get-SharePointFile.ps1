#Requires -Modules Selenium

<#
.SYNOPSIS
    Downloads files from SharePoint 2019 and SharePoint 365 using persistent Chrome sessions.

.DESCRIPTION
    A modular SharePoint file downloader that follows the original pattern with improved structure.
    Supports both setup mode (for initial authentication) and download mode.
    Can be executed directly or sourced for function access.

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
    .\Get-SharePointFile-Redesigned.ps1 -Url $url -DestDir "C:\Downloads" -Open
    # Download with custom destination and auto-open

.EXAMPLE
    # When sourced:
    . .\Get-SharePointFile-Redesigned.ps1
    Get-SharePointFile -Url $url -DoNotPersist
    # Function access with temporary session

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

#========================================
# CONFIGURATION SECTION
# Edit these values for your environment
#========================================

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

# Session tracking variables
$script:ChromeDriver_SP365 = $null
$script:ChromeDriver_SP2019 = $null

#========================================
# CORE FUNCTIONS
#========================================

#========================================
#region Get-SharePointFile
.SYNOPSIS
Main function to download SharePoint files with session management.
#========================================
#endregion
function Get-SharePointFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,
        
        [string]$DestDir,
        
        [switch]$DoNotPersist,
        
        [switch]$Open
    )
    
    $result = $null
    $sessionInfo = $null
    
    try {
        Write-Host "Starting SharePoint file download..." -ForegroundColor Cyan
        
        # 4.1. Connect to SharePoint session
        $sessionInfo = Connect-SharePointSession -Url $Url
        
        if (-not $sessionInfo -or -not $sessionInfo.Driver) {
            $result = @{
                Success = $false
                Error = "Failed to establish SharePoint session"
                FilePath = $null
                Duration = [TimeSpan]::Zero
            }
        }
        else {
            # 4.2. Download the file
            $downloadResult = Request-SharePointFile -Driver $sessionInfo.Driver -Url $Url
            
            if ($downloadResult -and $downloadResult.Success) {
                $finalPath = $downloadResult.FilePath
                
                # 4.4. Move to destination if specified
                if ($DestDir) {
                    $moveResult = Move-DownloadedFile -SourcePath $downloadResult.FilePath -DestinationPath $DestDir
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
                    Open-DownloadedFile -FilePath $finalPath
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
        # 4.3. Clean up if DoNotPersist
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

#========================================
#region Connect-SharePointSession
.SYNOPSIS
Establishes connection to appropriate SharePoint session based on URL.
#========================================
#endregion
function Connect-SharePointSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )
    
    $result = $null
    
    try {
        # 5.1. Get session info for this URL
        $sessionInfo = Get-SharePointSessionInfo -Url $Url
        
        if ($sessionInfo) {
            # 5.2. Connect to auth session
            $driver = Connect-AuthSession -SessionInfo $sessionInfo
            
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

#========================================
#region Get-SharePointSessionInfo
.SYNOPSIS
Resolves SharePoint version and returns session configuration info.
#========================================
#endregion
function Get-SharePointSessionInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )
    
    $sessionInfo = $null
    
    try {
        # 5.1.1. Resolve SharePoint version
        $spVer = Resolve-SharePointVersion -Url $Url
        
        # 5.1.2. Get existing driver based on version
        $existingDriver = $null
        $authPort = 0
        $authUrl = ""
        
        if ($spVer -eq "365") {
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
        
        # 5.1.4. Return session info object
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

#========================================
#region Resolve-SharePointVersion
.SYNOPSIS
Determines SharePoint version (365 or 2019) from URL pattern.
#========================================
#endregion
function Resolve-SharePointVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )
    
    $version = ""
    
    if ($Url -match "\.sharepoint\.com") {
        $version = "365"
    }
    else {
        $version = "2019"
    }
    
    return $version
}

#========================================
#region Connect-AuthSession
.SYNOPSIS
Connects to or creates authentication session for SharePoint.
#========================================
#endregion
function Connect-AuthSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$SessionInfo
    )
    
    $driver = $null
    
    try {
        # 5.2.1. If driver exists, test validity
        if ($SessionInfo -and $SessionInfo.Driver) {
            $isValid = Test-SessionValidity -Driver $SessionInfo.Driver -CanaryUrl $SessionInfo.AuthUrl
            
            # 5.2.2. If valid, return existing driver
            if ($isValid) {
                Write-Host "Using existing $($SessionInfo.SpVer) session" -ForegroundColor Green
                $driver = $SessionInfo.Driver
            }
            else {
                Write-Host "Existing $($SessionInfo.SpVer) session invalid, recreating..." -ForegroundColor Yellow
                # 5.2.3. If invalid, recreate
                # Note: For bulk session recreation, consider calling Initialize-SharePointSessions
                $driver = Start-AuthSession -SessionInfo $SessionInfo
            }
        }
        else {
            # 5.2.3. No existing driver, start new session
            $driver = Start-AuthSession -SessionInfo $SessionInfo
        }
    }
    catch {
        Write-Error "Failed to connect to auth session: $_"
        $driver = $null
    }
    
    return $driver
}

#========================================
#region Start-AuthSession
.SYNOPSIS
Creates new authentication session, attempting persistent connection first.
#========================================
#endregion
function Start-AuthSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$SessionInfo
    )
    
    $driver = $null
    
    try {
        # Try to connect to existing debug session first (original pattern)
        if ($SessionInfo) {
            $connectionTest = Test-ChromeDebugConnection -Port $SessionInfo.AuthPort
            
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
                $null = Read-Host "Press Enter after completing login"
            }
            
            # Store driver in script variable for reuse
            if ($driver) {
                if ($SessionInfo.SpVer -eq "365") {
                    $script:ChromeDriver_SP365 = $driver
                }
                else {
                    $script:ChromeDriver_SP2019 = $driver
                }
            }
        }
        else {
            Write-Error "SessionInfo is null"
        }
    }
    catch {
        Write-Error "Failed to start auth session: $_"
        $driver = $null
    }
    
    return $driver
}

#========================================
#region Test-ChromeDebugConnection
.SYNOPSIS
Tests if Chrome remote debugging port is accessible.
#========================================
#endregion
function Test-ChromeDebugConnection {
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

#========================================
#region Test-SessionValidity
.SYNOPSIS
Checks if the current browser session is still authenticated.
#========================================
#endregion
function Test-SessionValidity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Driver,
        
        [Parameter(Mandatory = $true)]
        [string]$CanaryUrl
    )
    
    $isValid = $false
    
    try {
        $currentUrl = Get-SeUrl -Driver $Driver
        
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

#========================================
#region Request-SharePointFile
.SYNOPSIS
Downloads file from SharePoint URL and monitors completion.
#========================================
#endregion
function Request-SharePointFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Driver,
        
        [Parameter(Mandatory = $true)]
        [string]$Url
    )
    
    $result = $null
    
    try {
        # 4.2.1. Start timer
        $startTime = Get-Date
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Extract filename from URL
        $fileName = Get-FileNameFromUrl -Url $Url
        $downloadPath = Join-Path $script:DefaultDownloadPath $fileName
        $tempDownloadPath = "$downloadPath.crdownload"
        
        # Clear any existing files
        Remove-ExistingDownloadFiles -FilePath $downloadPath -TempFilePath $tempDownloadPath
        
        Write-Host "Starting download: $fileName" -ForegroundColor Cyan
        
        # 4.2.2. Download file
        Enter-SeUrl -Url $Url -Driver $Driver
        
        # Monitor download completion
        $downloadCompleted = Wait-ForDownloadCompletion -FilePath $downloadPath -TempFilePath $tempDownloadPath
        
        # 4.2.3. Stop timer
        $timer.Stop()
        
        if ($downloadCompleted) {
            $fileSize = (Get-Item $downloadPath).Length
            
            # 4.2.4. Return success result
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

#========================================
#region Get-FileNameFromUrl
.SYNOPSIS
Extracts filename from SharePoint URL with URL decoding.
#========================================
#endregion
function Get-FileNameFromUrl {
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

#========================================
#region Remove-ExistingDownloadFiles
.SYNOPSIS
Removes existing download files to prevent conflicts.
#========================================
#endregion
function Remove-ExistingDownloadFiles {
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

#========================================
#region Wait-ForDownloadCompletion
.SYNOPSIS
Monitors download progress until completion or timeout.
#========================================
#endregion
function Wait-ForDownloadCompletion {
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

#========================================
#region Move-DownloadedFile
.SYNOPSIS
Moves downloaded file to destination with unique naming.
#========================================
#endregion
function Move-DownloadedFile {
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
        $uniquePath = Get-UniqueFilePath -Path $targetPath
        
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

#========================================
#region Get-UniqueFilePath
.SYNOPSIS
Generates unique file path if target already exists.
#========================================
#endregion
function Get-UniqueFilePath {
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

#========================================
#region Open-DownloadedFile
.SYNOPSIS
Opens downloaded file with default application.
#========================================
#endregion
function Open-DownloadedFile {
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

#========================================
#region Initialize-SharePointSessions
.SYNOPSIS
Sets up authentication sessions for both SharePoint environments.
#========================================
#endregion
function Initialize-SharePointSessions {
    [CmdletBinding()]
    param()
    
    $result = @{
        SP365Success = $false
        SP2019Success = $false
        OverallSuccess = $false
    }
    
    try {
        Write-Host "Setting up SharePoint authentication sessions..." -ForegroundColor Cyan
        
        # Setup SP365 session
        Write-Host "Setting up SharePoint 365 session..." -ForegroundColor Green
        $sp365Result = Connect-SharePointSession -Url $script:SP365_DefaultLoginUrl
        
        if ($sp365Result) {
            Write-Host "SharePoint 365 session established successfully." -ForegroundColor Green
            $result.SP365Success = $true
        }
        else {
            Write-Warning "Failed to establish SharePoint 365 session."
        }
        
        # Setup SP2019 session
        Write-Host "Setting up SharePoint 2019 session..." -ForegroundColor Green
        $sp2019Result = Connect-SharePointSession -Url $script:SP2019_DefaultLoginUrl
        
        if ($sp2019Result) {
            Write-Host "SharePoint 2019 session established successfully." -ForegroundColor Green
            $result.SP2019Success = $true
        }
        else {
            Write-Warning "Failed to establish SharePoint 2019 session."
        }
        
        # Overall success if at least one session established
        $result.OverallSuccess = $result.SP365Success -or $result.SP2019Success
        
        if ($result.OverallSuccess) {
            Write-Host "Session setup completed." -ForegroundColor Cyan
        }
        else {
            Write-Warning "No SharePoint sessions could be established."
        }
    }
    catch {
        Write-Error "Session initialization failed: $_"
        $result.OverallSuccess = $false
    }
    
    return $result
}

#========================================
#region mainEntryBlock
.SYNOPSIS
Main execution entry point for the script.
#========================================
#endregion
function mainEntryBlock {
    [CmdletBinding()]
    param(
        [string]$Url,
        [string]$DestDir,
        [switch]$DoNotPersist,
        [switch]$Open
    )
    
    $exitCode = 0
    
    if (-not $Url) {
        # Setup mode - launch authentication sessions for both environments
        Write-Host "SharePoint File Downloader - Setup Mode" -ForegroundColor Cyan
        Write-Host "This will open authentication sessions for both SharePoint environments." -ForegroundColor Yellow
        Write-Host ""
        
        try {
            # 1.1 & 1.2. Initialize both SharePoint sessions
            $sessionSetupResult = Initialize-SharePointSessions
            
            if ($sessionSetupResult -and $sessionSetupResult.OverallSuccess) {
                Write-Host ""
                Write-Host "Setup complete. You can now use the script to download files:" -ForegroundColor Cyan
                Write-Host "  .\Get-SharePointFile-Redesigned.ps1 -Url `"your-sharepoint-url`"" -ForegroundColor White
            }
            else {
                Write-Warning "Setup completed with errors. Some SharePoint environments may not be accessible."
                $exitCode = 1
            }
        }
        catch {
            Write-Error "Setup failed: $_"
            $exitCode = 1
        }
    }
    else {
        # 2. Download mode - download the specified file
        $downloadResult = Get-SharePointFile -Url $Url -DestDir $DestDir -DoNotPersist:$DoNotPersist -Open:$Open
        
        if (-not $downloadResult -or -not $downloadResult.Success) {
            Write-Error "Download failed: $(if ($downloadResult) { $downloadResult.Error } else { 'Unknown error' })"
            $exitCode = 1
        }
    }
    
    return $exitCode
}

#========================================
# SCRIPT EXECUTION ENTRY POINT
#========================================

# Only execute main logic if script is run directly (not sourced)
if ($MyInvocation.InvocationName -ne '.') {
    $result = mainEntryBlock -Url $Url -DestDir $DestDir -DoNotPersist:$DoNotPersist -Open:$Open
    exit $result
}