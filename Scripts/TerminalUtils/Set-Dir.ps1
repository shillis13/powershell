# PowerShell File Guard to prevent multiple includes of a file
if (Get-Variable -Name Included_Set-Dir_ps1 -Scope Script -ErrorAction SilentlyContinue) { return }
Set-Variable -Name Included_Set-Dir_ps1 -Scope Script -Value true

# Import modules
. "$env:PowerShellScripts\\DevUtils\\Logging.ps1" # TODO: Integrate

. "$env:PowerShellScripts\\TerminalUtils\\SetDir-BaseDirsUtils.ps1"  
. "$env:PowerShellScripts\\TerminalUtils\\SetDir-KeywordDirsUtils.ps1" 

#==================================================================================
#region      Function: Set-Dir
# Description:
#   Quickly set location (cd) to a common folder using a short keyword,
#   or by searching fallback base directories.
#
# Parameters:
#   -Keyword (string): Short keyword or folder name to navigate to.
#   -List (switch): Display all available keywords and base directories.
#
# Aliases:
#   godir
#
# Usage:
#   godir docs
#   godir temp
#   godir -List
#==================================================================================
function Set-Dir {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $false)]
        [string]$Keyword,

        [switch]$List
    )

    Publish-KeywordDirs
    Publish-BaseDirs

    if ($List) {
        Write-Host "`n=== Available Keywords ===" -ForegroundColor Cyan
        foreach ($key in $KeywordDirs.Keys) {
            Write-Host "  $key -> $($KeywordDirs[$key])"
        }

        Write-Host "`n=== Available BaseDirs ===" -ForegroundColor Cyan
        foreach ($dir in $BaseDirs) {
            Write-Host "  $dir"
        }
        return
    }

    $normalizedKeyword = $Keyword.Trim().ToLower()

    # Try Keyword First
    if ($KeywordDirs.ContainsKey($normalizedKeyword)) {
        $targetPath = $KeywordDirs[$normalizedKeyword]

        if (Test-Path $targetPath) {
            Set-Location $targetPath
            Write-Host "Moved to $targetPath" -ForegroundColor Green
            return
        } else {
            Write-Host "Mapped path '$targetPath' does not exist." -ForegroundColor Red
            return
        }
    }

    # Fallback: Try Searching BaseDirs
    foreach ($baseDir in $BaseDirs) {
        $potentialPath = Join-Path -Path $baseDir -ChildPath $Keyword
        if (Test-Path $potentialPath) {
            Set-Location $potentialPath
            Write-Host "Moved to $potentialPath" -ForegroundColor Green
            return
        }
    }

    Write-Host "Could not resolve keyword or locate directory for '$Keyword'." -ForegroundColor Yellow
}
#endregion
# ********************************************************************

