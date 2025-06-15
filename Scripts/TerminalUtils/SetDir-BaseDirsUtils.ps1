


#___________________________________________________________________________________
#region 	*** PowerShell Block Guard to prevent a section of code from being read multiple times 
if (-not (Get-Variable -Name Included_SetDir-BaseDirsUtils_Block -Scope Global -ErrorAction SilentlyContinue)) { 
    Set-Variable -Name Included_SetDir-BaseDirsUtils_Block -Scope Global -Value $true
    
    [string]$script:BaseDirsFile = "$env:PowerShellHome\\BaseDirs.psd1"
    $global:BaseDirs = $null

} # Move this and endregion to end-point of code to guard
#endregion	end of guard

function Set-BaseDirsFile {
    param (
        [string]$filename
    )
    $script:BaseDirsFile = $filename
    $script:BaseDirsFile = $script:BaseDirsFile
}

function Get-BaseDirsFile {
    return $script:BaseDirsFile
}

# ================================================================
# Function: Publish-BaseDirs
# Description:
#   Loads BaseDirs from BaseDirs.psd1 into global memory.
# ================================================================
function Publish-BaseDirs {
    $theBaseDirsFilename = Get-BaseDirsFile
    if (!(Test-Path $theBaseDirsFilename)) {
        @(
            ".",
            "$env:HOMEPATH",
            "$env:PowerShellHome"
        ) | Out-File -FilePath Get-BaseDirsFile -Encoding UTF8
    }
    else {
        Write-Host "Cannot find BaseDirs file: $(Get-BaseDirsFile)"
    }
    $global:BaseDirs = Invoke-Expression (Get-Content -Raw -Path $(Get-BaseDirsFile))
    $global:BaseDirs = $global:BaseDirs
}

# ================================================================
# Function: Edit-BaseDirs
# Description:
#   View, Add, or Remove base directories used for fallback search in Set-Dir.
#
# Parameters:
#   -Add (string): Directory path to add.
#   -Del (string): Directory path to remove.
#
# Usage:
#   Edit-BaseDirs
#   Edit-BaseDirs -Add "C:\Dev"
#   Edit-BaseDirs -Del "C:\Temp"
# ================================================================
function Edit-BaseDirs {
    [CmdletBinding()]
    param (
        [string]$Add,
        [string]$Del
    )

    Publish-BaseDirs

    if ($Add) {
        if (-not ($global:BaseDirs -contains $Add)) {
            $global:BaseDirs += $Add
            Write-Host "Added BaseDir: $Add" -ForegroundColor Green
        } else {
            Write-Host "BaseDir already exists: $Add" -ForegroundColor Yellow
        }
    }
    elseif ($Del) {
        if ($global:BaseDirs -contains $Del) {
            $global:BaseDirs = $global:BaseDirs | Where-Object { $_ -ne $Del }
            Write-Host "Removed BaseDir: $Del" -ForegroundColor Green
        } else {
            Write-Host "BaseDir not found: $Del" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "`n=== Current BaseDirs ===" -ForegroundColor Cyan
        $global:BaseDirs | ForEach-Object { Write-Host "  $_" }
        return
    }

    "`n@(`n" + ($global:BaseDirs | ForEach-Object { "`"$($_)`"," }) + "`n)" | Set-Content -Path $(Get-BaseDirsFile) -Encoding UTF8
    Publish-BaseDirs
}

# ********************************************************************
