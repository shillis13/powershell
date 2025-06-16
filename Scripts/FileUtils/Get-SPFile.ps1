#=========================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ========================================================================

if (-not $Global:PSRoot) {
    $Global:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    Log -Dbg "Set Global:PSRoot = $Global:PSRoot"
}
if (-not $Global:PSRoot) {
    throw "Global:PSRoot must be set by the entry-point script before using internal components."
}

if (-not $Global:CliArgs) {
    $Global:CliArgs = $args
}

. "$Global:PSRoot\Scripts\Initialize-CoreConfig.ps1"

#endregion
# ======================================================================

# ======================================================================
#region           Function: Get-SPFile
# ======================================================================
<#
.SYNOPSIS
    Downloads a file from SharePoint using Microsoft Graph API.

.DESCRIPTION
    This function downloads a file from SharePoint using the Microsoft Graph API.
    It supports authentication via device code flow and can infer the output filename
    from the URL if not specified. It also supports looped downloads with optional overlap.

.PARAMETER Url
    The URL of the SharePoint file to download.

.PARAMETER UserId
    The User ID for authentication.

.PARAMETER OutFile
    The output file path where the downloaded file will be saved.

.PARAMETER LoopSeconds
    The interval in seconds for looped downloads. Default is 0 (no loop).

.PARAMETER AllowOverlap
    If specified, allows overlapping downloads in looped mode.

.PARAMETER File
    An optional file parameter.

.PARAMETER Help
    Displays the help message.

.PARAMETER ShowHelp
    Displays the help message.

.PARAMETER HelpAlias
    Alias for the Help parameter.

.EXAMPLE
    Get-SPFile -Url "https://yourcompany.sharepoint.com/sites/ProjectX/Shared%20Documents/folder/Report.xlsx" -UserId "you@yourcompany.com" -OutFile "C:\Downloads\Report.xlsx"

.NOTES
    - If -OutFile is omitted, the filename will be extracted from the URL.
    - No app registration or ClientId needed.
    - Login is handled via secure Microsoft device login prompt.
#>
function Get-SPFile {
    param (
        [string]$Url,
        [string]$UserId,

        [Alias("o")]
        [string]$OutFile,

        [int]$LoopSeconds = 0,
        [switch]$AllowOverlap,
        [string]$File = $null,

        [switch]$Help,
        [switch]$ShowHelp,
        [Alias("--help", "-Help")]
        [switch]$HelpAlias
    )

    # Check for Help or ShowHelp switches
    if ($Help -or $ShowHelp -or $HelpAlias) {
        Show-Help
        return
    }

    # Print the args array for debugging
    Log -Dbg "Arguments: (Convert-ToString($args))"
    # foreach ($arg in $args) {
    #     Write-Host "Arg: $arg"
    # }

    # Prompt for mandatory parameters if not provided
    if (-not $Url) {
        $Url = Read-Host "Please enter the SharePoint file URL"
    }

    if (-not $UserId) {
        $UserId = Read-Host "Please enter your User ID"
    }

    # ============================
    # Infer OutFile from URL if needed
    # ============================
    if (-not $OutFile) {
        if ($Url -match "/([^/?]+)\?") {
            $OutFile = $matches[1]
        } elseif ($Url -match "/([^/?]+)$") {
            $OutFile = $matches[1]
        } else {
            Log -Err "Unable to infer output filename from URL. Use -o to specify it."
            return
        }
    }

    # ============================
    # Extract Tenant Domain
    # ============================
    if ($Url -match "https://([^.]+)\.sharepoint\.com") {
        $Domain = "$($matches[1]).onmicrosoft.com"
    } elseif ($Url -match "https://([^.]+)\.sharepoint\.us") {
        $Domain = "$($matches[1]).onmicrosoft.com"
    } elseif ($Url -match "https://([^.]+)\.sharepoint-df\.com") {
        $Domain = "$($matches[1]).onmicrosoft.com"
    } else {
        Log -Err "Unable to determine SharePoint domain from URL."
        return
    }

    # ============================
    # Extract SiteName and FilePath
    # ============================
    if ($Url -match "/sites/([^/]+)/(.+?)(\?|$)") {
        $SiteName = $matches[1]
        $FilePath = $matches[2] -replace "%20", " "
    } elseif ($Url -match "/:p:/r/sites/([^/]+)/(.+?)(\?|$)") {
        $SiteName = $matches[1]
        $FilePath = $matches[2] -replace "%20", " "
    } else {
        Log -Err "Unable to parse SiteName and FilePath from URL."
        return
    }

    $TenantId = Get-TenantId -DomainName $Domain
    if (-not $TenantId) { return }

    # ============================
    # Authenticate via device code flow
    # ============================
    Import-Module MSAL.PS -ErrorAction Stop

    try {
        $token = Get-MsalToken -TenantId $TenantId `
            -ClientId "04f0c124-f2bc-4f6c-affe-01a709e901a7" ` # Public MS Graph app
            -Scopes "https://graph.microsoft.com/.default" `
            -LoginHint $UserId `
            -DeviceCode
        $AccessToken = $token.AccessToken
    } catch {
        Log -Err "Authentication failed: $_"
        return
    }

    # Call the function to download the file
    Get-SharePointFile -AccessToken $AccessToken -SiteName $SiteName -FilePath $FilePath -OutFile $OutFile

    if ($LoopSeconds -gt 0) {
        Log -Info "Starting looped downloads every $LoopSeconds seconds (Overlap Allowed: $($AllowOverlap.IsPresent))"
        Get-SharePointFile -AccessToken $AccessToken -SiteName $SiteName -FilePath $FilePath -OutFile $OutFile -IntervalSeconds $LoopSeconds -AllowOverlap:$AllowOverlap
    } else {
        Get-SharePointFile -AccessToken $AccessToken -SiteName $SiteName -FilePath $FilePath -OutFile $OutFile
    }
}
#endregion
# ======================================================================


# ======================================================================
#region           Function: Get-TenantId
# ======================================================================
<#
.SYNOPSIS
    Retrieves the Tenant ID from the domain name.

.DESCRIPTION
    This function retrieves the Tenant ID from the domain name by querying the
    Microsoft online login endpoint.

.PARAMETER DomainName
    The domain name to query for the Tenant ID.

.EXAMPLE
    $tenantId = Get-TenantId -DomainName "yourcompany.onmicrosoft.com"

.NOTES
    - This function uses the Microsoft online login endpoint to fetch the Tenant ID.
#>
function Get-TenantId {
    param ([string]$DomainName)

    $url = "https://login.microsoftonline.com/$DomainName/v2.0/.well-known/openid-configuration"
    try {
        $response = Invoke-RestMethod -Uri $url -UseBasicParsing
        if ($response.issuer -match "/([0-9a-fA-F-]{36})/") {
            return $matches[1]
        }
    } catch {
        Log -Err "Failed to fetch TenantId from domain: $DomainName"
    }
    return $null
}
#endregion
# ======================================================================


# ======================================================================
#region           Function: Get-SharePointFile
# ======================================================================
<#
.SYNOPSIS
    Downloads a file from SharePoint using the Microsoft Graph API.

.DESCRIPTION
    This function downloads a file from SharePoint using the Microsoft Graph API.
    It requires an access token, site name, file path, and output file path.

.PARAMETER AccessToken
    The access token for authentication.

.PARAMETER SiteName
    The name of the SharePoint site.

.PARAMETER FilePath
    The path to the file within the SharePoint site.

.PARAMETER OutFile
    The output file path where the downloaded file will be saved.

.EXAMPLE
    Get-SharePointFile -AccessToken $accessToken -SiteName "ProjectX" -FilePath "Shared Documents/folder/Report.xlsx" -OutFile "C:\Downloads\Report.xlsx"

.NOTES
    - This function uses the Microsoft Graph API to download the file.
#>
function Get-SharePointFile {
    param (
        [string]$AccessToken,
        [string]$SiteName,
        [string]$FilePath,
        [string]$OutFile
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Get Site ID
    $siteResult = Invoke-RestMethod -Headers @{ Authorization = "Bearer $AccessToken" } `
        -Uri "https://graph.microsoft.com/v1.0/sites/root:/$SiteName"
    if (-not $siteResult.id) {
        Log -Err "Failed to get Site ID for site: $SiteName"
        return
    }
    $SiteId = $siteResult.id

    # Get Drive ID
    $driveResult = Invoke-RestMethod -Headers @{ Authorization = "Bearer $AccessToken" } `
        -Uri "https://graph.microsoft.com/v1.0/sites/$SiteId/drive"
    if (-not $driveResult.id) {
        Log -Err "Failed to get Drive ID for site: $SiteName"
        return
    }
    $DriveId = $driveResult.id

    # Get Item ID
    $itemResult = Invoke-RestMethod -Headers @{ Authorization = "Bearer $AccessToken" } `
        -Uri "https://graph.microsoft.com/v1.0/drives/$DriveId/root:/$FilePath"
    if (-not $itemResult.id) {
        Log -Err "Failed to get Item ID for file: $FilePath"
        return
    }
    $ItemId = $itemResult.id

    # Download File
    Log -Dbg "Downloading to $OutFile"
    $fileResult = Invoke-RestMethod -Headers @{ Authorization = "Bearer $AccessToken" } `
        -Uri "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$ItemId/content" `
        -OutFile $OutFile
    if ($fileResult) {
        Log -Info "File downloaded successfully to: $OutFile"
    } else {
        Log -Err "Failed to download file: $FilePath"
    }

    $stopwatch.Stop()
    Log -Info "Download completed in $($stopwatch.Elapsed.TotalSeconds) seconds."
}
#endregion
# ======================================================================


# ======================================================================
#region           Function: Start-DownloadLoop
# ======================================================================
<#
.SYNOPSIS
    Starts a loop to download a SharePoint file at regular intervals.

.DESCRIPTION
    This function starts a loop to download a SharePoint file at regular intervals.
    It supports overlapping downloads if specified.

.PARAMETER AccessToken
    The access token for authentication.

.PARAMETER SiteName
    The name of the SharePoint site.

.PARAMETER FilePath
    The path to the file within the SharePoint site.

.PARAMETER OutFile
    The output file path where the downloaded file will be saved.

.PARAMETER IntervalSeconds
    The interval in seconds for looped downloads.

.PARAMETER AllowOverlap
    If specified, allows overlapping downloads in looped mode.

.EXAMPLE
    Start-DownloadLoop -AccessToken $accessToken -SiteName "ProjectX" -FilePath "Shared Documents/folder/Report.xlsx" -OutFile "C:\Downloads\Report.xlsx" -IntervalSeconds 60 -AllowOverlap

.NOTES
    - This function uses the Microsoft Graph API to download the file.
#>
function Start-DownloadLoop {
    param (
        [string]$AccessToken,
        [string]$SiteName,
        [string]$FilePath,
        [string]$OutFile,
        [int]$IntervalSeconds,
        [switch]$AllowOverlap
    )

    $task = $null
    while ($true) {
        if (-not $AllowOverlap -and $null -ne $task -and !$task.IsCompleted) {
            Start-Sleep -Seconds 1
            continue
        }

        $task = Start-Job {
            param($AccessToken, $SiteName, $FilePath, $OutFile)
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            Get-SharePointFile -AccessToken $AccessToken -SiteName $SiteName -FilePath $FilePath -OutFile $OutFile
            $sw.Stop()
            $timestamp = (Get-Date -Format "yyyyMMdd-HHmmss")
            $elapsed = '{0:N2}' -f $sw.Elapsed.TotalSeconds
            $newName = "$($OutFile)_$($timestamp)_${elapsed}s"
            Copy-Item $OutFile -Destination $newName -Force
            Log -Info "Backed up as $newName"
        } -ArgumentList $AccessToken, $SiteName, $FilePath, $OutFile

        Start-Sleep -Seconds $IntervalSeconds
    }
}
#endregion
# ======================================================================


# ======================================================================
#region           Function: Show-Help
# ======================================================================
<#
.SYNOPSIS
    Displays the help message for the script.

.DESCRIPTION
    This function displays the help message for the script, including usage examples
    and notes about the parameters.

.EXAMPLE
    Show-Help

.NOTES
    - This function provides detailed usage information for the script.
#>
function Show-Help {
    Write-Host @"
Downloads a SharePoint file using Microsoft Graph API with your Microsoft 365 login.

USAGE:
    .\Download-SPFile.ps1 `
        -Url ""https://yourcompany.sharepoint.com/sites/ProjectX/Shared%20Documents/folder/Report.xlsx"" `
        -UserId ""you@yourcompany.com"" `
        -o ""C:\Downloads\Report.xlsx""

NOTES:
- If -o is omitted, the filename will be extracted from the URL.
- No app registration or ClientId needed.
- Login is handled via secure Microsoft device login prompt.
"@
    return
}
#endregion  
# ==========================================================================================


# ==========================================================================================
#region      Execution Guard / Main Entrypoint
# ==========================================================================================

if ($MyInvocation.InvocationName -eq '.') {
    # Dot-sourced – do nothing, just define functions/aliases
    Write-Debug 'Script dot-sourced; skipping main execution.'
    return
}

if ($MyInvocation.MyCommand.Path -eq $PSCommandPath) {
    # Direct execution
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path)
    if (Get-Command $baseName -CommandType Function -ErrorAction SilentlyContinue) {
        Log -Info "$baseName (Format-ToString($Global:RemainingArgs))"
        (& $baseName @Global:RemainingArgs)
    } else {
        Log -Err "No function named '$baseName' found to match script entry point."
    }
} else {
    Log -Warn "Unexpected execution context: $($MyInvocation.MyCommand.Path)"
}
#endregion   Execution Guard / Main Entrypoint
# ==========================================================================================
