# PowerShell File Guard to prevent multiple includes of a file
if (Get-Variable -Name Included_PowerShell_Aliases_ps1 -Scope Global -ErrorAction SilentlyContinue) { return }
Set-Variable -Name Included_PowerShell_Aliases_ps1 -Scope Global -Value $true

# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

if (-not $Global:PSRoot) {
    $Global:PSRoot = (Resolve-Path "$PSScriptRoot").Path
    Write-Host "Set Global:PSRoot = $Global:PSRoot"
}
if (-not $Global:PSRoot) {
    throw "Global:PSRoot must be set by the entry-point script before using internal components."
}

if (-not $Global:CliArgs) {
    $Global:CliArgs = $args
}

. "$Global:PSRoot\Scripts\Initialize-CoreConfig.ps1"

#endregion
# ===========================================================================================

$global:PersonalEmail = "shawn.hillis@gmail.com"

#----------------------------------------------------
#region 	Alias Function Helpers

function Global:Get-Env {
	Get-ChildItem env:
}

function Convert-FileExts {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Curr,
        [Parameter(Mandatory = $true)]
        [string]$New,
        [switch]$Recurse
    )

    $Curr = $Curr.TrimStart(".").Trim()
    $New = $New.TrimStart(".").Trim()

    Get-ChildItem -Filter "*.$Curr" -Recurse:$Recurse | Rename-Item -NewName { $_.BaseName + ".$New" }
}

#endregion


#----------------------------------------------------
#region 	Aliases

Set-Alias -Name npp -Value "C:\Program Files\Notepad++\notepad++.exe"
Set-Alias -Name llm -Value  "$env:PowerShellScriptsDir\AIUtils\llm_wrapper.ps1" 

Set-Alias -Name renExt -Value Rename-FileExtension 
Set-Alias -Name setDir -Value Set-Dir 
set-Alias -Name psZip -Value Compress-Contents
set-Alias -Name psUnzip -Value Expand-Content
set-Alias -Name copyDir -Value Copy-CleanZipDir

#endregion

Write-Host "Loaded aliases..."