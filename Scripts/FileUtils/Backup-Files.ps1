# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

if (-not $Script:PSRoot) {
    $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    Write-Host "Set Script:PSRoot = $Script:PSRoot"
}
if (-not $Script:PSRoot) {
    throw "Script:PSRoot must be set by the entry-point script before using internal components."
}

#if (-not $Script:CliArgs) {
    $Script:CliArgs = $args
#}

. "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"

#endregion
# ===========================================================================================


<#
.SYNOPSIS
    Archives files based on various options.

.DESCRIPTION
    This script uses SelectFiles.ps1 to find files in the specified source directory, orders them by date-time, and returns the files in ascending order except for the last file (which would be the newest file). It then moves those files to the specified archive directory.

.PARAMETER SrcPath
    The source directory to search for files.

.PARAMETER DestPath
    (Optional) The archive directory to move files to. Defaults to $SrcPath\Archive.

.PARAMETER DontUseDateInFilename
    (Optional) Switch to not use date in the filename for ordering. Default is false.

.PARAMETER KeepNVersions
    (Optional) The number of most recent files to keep in the source directory. Default is 1.

.EXAMPLE
    .\ArchiveFiles.ps1 -SrcPath "C:\Files" -DestPath "C:\Archive" -DontUseDateInFilename -KeepNVersions 1
#>

# Imports
. "$ENV:PowerShellScripts\FileUtils\Select-Files.ps1"

#==================================================================================
#region     Function: Backup-Files
function Backup-Files {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SrcPath,

        [Parameter(Mandatory = $false)]
        [string]$DestPath,
        [Parameter(Mandatory = $false)]
        [switch]$UseDateInFilename,

        [Parameter(Mandatory = $false)]
        [int]$KeepNVersions = 1,

        [switch]$Exec
    )

    if ($Exec) { Set-DryRun $false }
    
    $argList = @{
        Dir     = $SrcPath
        OrderBy = "Date"
        Order   = "ASC"
        LastN   = $KeepNVersions
        Inverse = $true
    }

    if (-not $DestPath) {
        $DestPath = Join-Path -Path $SrcPath -ChildPath "Archive"
    }

    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('UseDateInFilename') -or $UseDateInFilename) { 
        $argList["DateSource"]  = "Filename"
    }

    if (-not (Test-Path -Path $DestPath)) {
        New-Item -ItemType Directory -Path $DestPath | Out-Null
    }

    #Log -Always "Select-Files -Dir $SrcPath -DateSource $DateSource -OrderBy Date -Order ASC -LastN $KeepNVersions -Inverse"
    #$fileList  = Select-Files -Dir $SrcPath -DateSource $DateSource -OrderBy Date -Order ASC -LastN $KeepNVersions -Inverse
    Log -Dbg ("Select-Files " + (Format-ToString -Obj $argList))
    $fileList = @() # Ensure it is empty
    $fileList = Select-Files @argList

    if ($fileList) {
        foreach ($file in $fileList) {
            if (-not [string]::IsNullOrWhiteSpace($file)) {
                $filePath = $file.FullName
                if ( Test-Path -Path $filePath) {
                    $destination = Join-Path -Path $DestPath -ChildPath (Split-Path -Path $file -Leaf)

                    if (Get-DryRun) {
                        Log -DryRun "Moved: $filePath`nTo: $destination"
                    } else {
                        Move-Item -Path $filePath -Destination $destination -Force
                        Log -Info "Moved: $filePath`nTo: $destination" 
                        #Write-Host ""
                    }
                } else {
                    Log -Err "File not found: $filePath.`n"
                }
            }
            else {
                Log -Warn "Empty filename listed."
            }
        }
    } else {
        Log -Warn "No files found to archive."
    }
}
#endregion
#==================================================================================


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
        Log -Info ("$baseName " + (Format-ToString($Global:RemainingArgs)))
        (& $baseName @Global:RemainingArgs)
    } else {
        Log -Err "No function named '$baseName' found to match script entry point."
    }
} else {
    Log -Warn "Unexpected execution context: $($MyInvocation.MyCommand.Path)"
}
#endregion   Execution Guard / Main Entrypoint
# ==========================================================================================
