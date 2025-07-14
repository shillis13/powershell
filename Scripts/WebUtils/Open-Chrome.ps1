<#
.SYNOPSIS
    Minimal Chrome launcher for SharePoint file downloads.

.DESCRIPTION
    Simple functions to launch Chrome with download or view options.
    No remote debugging, no complex session management.

.NOTES
    Prerequisites: Google Chrome installed
#>

# [CmdletBinding()]
# param()

#========================================
# SCRIPT VARIABLES
#========================================

# Default download path
$script:DefaultDownloadPath = [System.IO.Path]::Combine($env:USERPROFILE, "Downloads")

# Chrome executable paths (common locations)
$script:ChromePaths = @(
    "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "${env:LOCALAPPDATA}\Google\Chrome\Application\chrome.exe"
)

#========================================
# PRIVATE HELPER FUNCTIONS
#========================================

#========================================
#region _FindChromeExecutable
<#
.SYNOPSIS
Locates Chrome executable on the system.
#>
#========================================
#endregion
function _FindChromeExecutable {
    [CmdletBinding()]
    param()
    
    $chromePath = $null
    
    foreach ($path in $script:ChromePaths) {
        if (Test-Path $path) {
            $chromePath = $path
            break
        }
    }
    
    if (-not $chromePath) {
        # Try to find via PATH
        try {
            $chromePath = (Get-Command chrome.exe -ErrorAction SilentlyContinue).Source
        }
        catch {
            # Chrome not found
        }
    }
    
    return $chromePath
}

#========================================
# PUBLIC FUNCTIONS
#========================================

#========================================
#region Get-ChromeOptions
<#
.SYNOPSIS
Returns Chrome command-line arguments for download or view behavior.

.DESCRIPTION
Creates Chrome arguments optimized for either downloading files automatically 
or viewing them in the browser. Defaults to download behavior unless -View is specified.

.PARAMETER View
Switch to configure Chrome for viewing files in browser instead of downloading.

.EXAMPLE
$options = Get-ChromeOptions
# Returns arguments for automatic downloads

.EXAMPLE  
$options = Get-ChromeOptions -View
# Returns arguments for viewing files in browser
#>
#========================================
#endregion
function Get-ChromeOptions {
    [CmdletBinding()]
    param(
        [switch]$View
    )
    
    $arguments = @()
    
    # Base arguments 
    $arguments += "--no-first-run"
    $arguments += "--no-default-browser-check"
    $arguments += "--disable-infobars"
    $arguments += "--disable-notifications"
    $arguments += "--new-window"
    
    if ($View) {
        # Configure for viewing files in browser (minimal restrictions)
        Write-Verbose "Configured Chrome options for VIEW behavior"
    }
    else {
        # Configure for automatic downloads  
        $arguments += "--disable-extensions"
        $arguments += "--disable-plugins"  
        $arguments += "--disable-pdf-extension"
        Write-Verbose "Configured Chrome options for DOWNLOAD behavior"
    }
    
    return $arguments
}

#========================================
#region Open-Chrome
<#
.SYNOPSIS
Opens a URL in Chrome with specified options.

.DESCRIPTION
Launches Chrome with the specified URL and options. Chrome will handle 
authentication and downloads automatically based on the options provided.

.PARAMETER Url
The URL to open in Chrome.

.PARAMETER Options
Chrome command-line arguments. If not provided, uses default download options.

.EXAMPLE
Open-Chrome -Url "https://tenant.sharepoint.com/sites/hr/Documents/file.pdf"
# Opens URL in Chrome with download options

.EXAMPLE
$viewOptions = Get-ChromeOptions -View
Open-Chrome -Url "https://sharepoint.com/file.pdf" -Options $viewOptions
# Opens URL with view options
#>
#========================================
#endregion
function Open-Chrome {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,
        
        [string[]]$Options
    )
    
    $processes = @()
    
    try {
        # Find Chrome executable
        $chromePath = _FindChromeExecutable
        if (-not $chromePath) {
            Write-Error "Chrome executable not found"
            return $false
        }
        
        # Get default options if none provided
        if (-not $Options) {
            $Options = Get-ChromeOptions
        }
        
        # Add URL to arguments
        $allArguments = $Options + @("`"$Url`"")
        
        # Launch Chrome
        Write-Verbose "Launching Chrome with URL: $allArguments"
        $processes += Start-Process -FilePath $chromePath -ArgumentList $allArguments -WindowStyle Minimized -PassThru

    }
    catch {
        Write-Error "Failed to open URL in Chrome: $_"
    }
    
    return $processes
}

## ==========================================================================================
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
        Write-Host "$baseName $args"
        (& $baseName @args)
    } else {
       Write-Error "No function named '$baseName' found to match script entry point."
    }
} else {
    Write-Error "Unexpected execution context: $($MyInvocation.MyCommand.Path)"
}
#endregion   Execution Guard / Main Entrypoint
# ==========================================================================================