#================================================================================#
#region     Initialize-CoreConfig
<#
.SYNOPSIS
    Parses and applies global CLI arguments (e.g., -Exec, -LogLevel) and supports optional config defaults.

.DESCRIPTION
    Centralized handler for common global args like -Exec, -LogLevel, and -Help.
    Dot-sources all DevUtils for immediate access to logging, dry-run, and utilities.
    Supports optional config defaults from ..\Config\GlobalArgs.psd1.

.NOTES
    Usage (in script):
        . "$PSScriptRoot\..\Initialize-CoreConfig.ps1"

    Depends on: Logging.ps1, DryRun.ps1, etc.
#>
#================================================================================#

#___________________________________________________________________________________
#region 	 PowerShell Block Guard to prevent a section of code from being read multiple times 
if (-not (Get-Variable -Name Included_Initialize-CoreConfig_Block -Scope Global -ErrorAction SilentlyContinue)) { 
    Set-Variable -Name Included_Initialize-CoreConfig_Block -Scope Global -Value $true
    #Dot Source the Aliases file
    . "PowerShell_Aliases.ps1"   
} # Move this and endregion to end-point of code to guard
#endregion	end of guard


#---------------------------------------------------------
#region     Dot-source DevUtils
$devUtilsPath = Join-Path $PSScriptRoot ".\DevUtils"
if (Test-Path $devUtilsPath) {
    Get-ChildItem -Path $devUtilsPath -Filter *.ps1 | ForEach-Object {
        Write-Debug "Dot-sourcing DevUtils: $($_.Name)"
        . $_.FullName
        # Write-Host "Dot-sourced $($_.FullName)"
    }
} else {
    Write-Warning "DevUtils path not found: $devUtilsPath"
}
#endregion


#----------------------------------------------------------
#region     Parse Arguments
$logLevelArg = $null
$execArg = $false
$helpArg = $false
$remainingArgs = @()

Write-Host ("CliArgs = " + (Format-ToString($Global:CliArgs)))

for ($i = 0; $i -lt $Global:CliArgs.Count; $i++) {
    Write-Host "args[$i] = $($Global:CliArgs[$i])"
    if ($Global:CliArgs[$i] -match "-LogLevel") {
            if ($i + 1 -lt $Global:CliArgs.Count) {
                $logLevelArg = $Global:CliArgs[$i + 1]
                $i++
            }
    } elseif ($Global:CliArgs[$i] -match "-Debug") {
        $DebugPreference = "Continue"
    } elseif ($Global:CliArgs[$i] -match "-Exec") {
        $execArg = $true
    } elseif ($Global:CliArgs[$i] -match "-Help") {
        $helpArg = $true
    } else {
        $remainingArgs += $Global:CliArgs[$i]
    }
}
Write-Host "LogLevelArg = $logLevelArg  : execArg = $execArg   :   helpArg = $helpArg   : remainingArgs = " (Format-ToString($remainingArgs))
#endregion


#---------------------------------------------------------
#region     Load Optional Config
$configDefaults = @{}
$configPath = Join-Path $PSScriptRoot "..\Config\GlobalArgs.psd1"
if (Test-Path $configPath) {
    try {
        $configDefaults = Import-PowerShellDataFile $configPath
        Log -Dbg "Loaded config defaults from: $configPath"
    } catch {
        Log -Warn "Failed to load config from $configPath : $_"
    }
}
#endregion


#-------------------------------------------------------
#region     Effective Parameters
$effectiveLogLevel = if ($logLevelArg) {
    $logLevelArg
} elseif ($configDefaults -is [hashtable] -and $configDefaults.ContainsKey("LogLevel")) {
    $configDefaults["LogLevel"]
} else {
    "Info"
}

$effectiveDryRun = if ($execArg) {
    $false
} elseif ($configDefaults -is [hashtable] -and $configDefaults.ContainsKey("DryRun")) {
    $configDefaults["DryRun"]
} else {
    $true
}
#endregion


#----------------------------------------------------
#region     Apply Side Effects
Set-LogLevel $effectiveLogLevel
Log -Dbg "LogLevel set to: $effectiveLogLevel"

Set-DryRun $effectiveDryRun
Log -Dbg "DryRun mode set to: $effectiveDryRun"

if ($helpArg) {
    #Write-Host "Common Args: -Exec, -LogLevel <level>, -Help"
    Get-Help $Global:CliArgs[0]
    exit 0
}
#endregion

#----------------------------------------------------
#region     Export Remaining Args
Set-Variable -Name RemainingArgs -Scope Global -Value $remainingArgs
#endregion
