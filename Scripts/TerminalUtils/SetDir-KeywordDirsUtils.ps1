

#___________________________________________________________________________________
#region 	*** PowerShell Block Guard to prevent a section of code from being read multiple times 
if (-not (Get-Variable -Name Included_SetDir-BaseDirsUtils_Block -Scope Global -ErrorAction SilentlyContinue)) { 
    Set-Variable -Name Included_SetDir-BaseDirsUtils_Block -Scope Global -Value $true
    
    [string]$script:KeywordDirsFile = "$env:PowerShellHome\\BaseDirs.psd1"
    $global:KeywordDirs = $null

} # Move this and endregion to end-point of code to guard
#endregion	end of guard

function Set-BKeywordDirsFile {
    param (
        [string]$filename
    )
    $script:KeywordDirsFile = $filename
    $script:KeywordDirsFile = $script:KeywordDirsFile
}

function Get-KeywordDirsFile {
    return $script:KeywordDirsFile
}

# ================================================================
# Function: Edit-KeywordDirs
# Description:
#   View, Add, or Remove keyword-to-directory mappings for Set-Dir.
#
# Parameters:
#   -Add (hashtable): Key=keyword, Value=full path
#   -Del (string): Keyword to remove
#
# Usage:
#   Edit-KeywordDirs
#   Edit-KeywordDirs -Add @{ "dev" = "C:\Dev" }
#   Edit-KeywordDirs -Del "dev"
# ================================================================
function Edit-KeywordDirs {
    [CmdletBinding()]
    param (
        [hashtable]$Add,
        [string]$Del
    )

    Publish-KeywordDirs

    if ($Add) {
        foreach ($key in $Add.Keys) {
            $global:KeywordDirs[$key] = $Add[$key]
            Write-Host "Added mapping: $key -> $($Add[$key])" -ForegroundColor Green
        }
    }
    elseif ($Del) {
        if ($global:KeywordDirs.ContainsKey($Del)) {
            $global:KeywordDirs.Remove($Del)
            Write-Host "Removed mapping for keyword: $Del" -ForegroundColor Green
        } else {
            Write-Host "Keyword not found: $Del" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "`n=== Current Keyword Mappings ===" -ForegroundColor Cyan
        foreach ($pair in $global:KeywordDirs.GetEnumerator()) {
            Write-Host "  $($pair.Key) -> $($pair.Value)"
        }
        return
    }

    "`n@{`n" + ($global:KeywordDirs.GetEnumerator() | ForEach-Object { "`"$($_.Key)`" = `"$($_.Value)`"" }) + "`n}" | Set-Content -Path $(Get-KeywordDirsFile) -Encoding UTF8
    Publish-KeywordDirs
}


# ================================================================
# Function: Publish-KeywordDirs
# Description:
#   Loads KeywordDirs from KeywordDirs.psd1 into global memory.
# ================================================================
function Publish-KeywordDirs {
    
    if (-not (Test-Path $(Get-KeywordDirsFile))) {
        @{} | Out-File -FilePath $(Get-KeywordDirsFile) -Encoding UTF8
    }
    $global:KeywordDirs = Invoke-Expression (Get-Content -Raw -Path $(Get-KeywordDirsFile))
}
