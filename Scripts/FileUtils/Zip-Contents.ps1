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

if (-not $Script:CliArgs) {
    $Script:CliArgs = $args
}

. "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"

#endregion
# ===========================================================================================

if (-not $Global:WinzipExe)     { Set-Variable -Name WinZipExe -Scope Global -Value "C:\Program Files\WinZip\WZZIP.EXE" }
if (-not $Global:WinZipArgs)    { Set-Variable -Name WinZipArgs -Scope Global -Value "-ycAES256 -P -r" }
if (-not $Script:DefPw)         { Set-Variable -Name DefPw -Scope Script -Value "1Password!" }

# Winzip command Example:
#  & "C:\Program Files\WinZip\WZZIP.EXE" -s"blahblah13!" -ycAES256 -P -r -a "$HOME\Downloads\WPS.zip" .\WindowsPowerShell\

# Example usage from command line:
# Compress-Files -SourcePaths "C:\Folder1", "C:\File1.txt" -TargetDir "C:\Backups" -NI
# Expand-Files -ZipFilePath "C:\Backups\Folder1_20230501_123456.zip" -TargetDir "C:\Restored"

# Example usage from another script:
# .\Compress-Files.ps1 -SourcePaths "C:\Folder1", "C:\File1.txt" -TargetDir "C:\Backups" -NI
# .\Expand-Files.ps1 -ZipFilePath "C:\Backups\Folder1_20230501_123456.zip" -TargetDir "C:\Restored"

# Example usage as a function:
# $zipPath = Compress-Files -SourcePaths "C:\Folder1", "C:\File1.txt" -TargetDir "C:\Backups" -NI
# Expand-Files -ZipFilePath $zipPath -TargetDir "C:\Restored"


#==================================================================================
#region
#========================================
#region Compress-Contents
<#
.SYNOPSIS
    Compresses specified files and folders into a password-protected ZIP archive using WinZip,
    supporting wildcards and folder structure preservation.

.DESCRIPTION
    Accepts one or more file or folder paths, including wildcard patterns like `.\*.bas`.
    Automatically resolves matching files while preserving folder hierarchy.
    Supports dry-run mode for previewing the compression process.

.PARAMETER SourcePaths
    One or more file or folder paths, which can include wildcards. Folder structure is preserved.

.PARAMETER TargetDir
    The output directory for the resulting ZIP file. Defaults to the current working directory.

.PARAMETER NI
    No interaction mode. Suppresses prompts and uses default ZIP name and password.

.PARAMETER ZipFileName
    Custom name for the ZIP file. If omitted, one is auto-generated from the first source item.

.PARAMETER PW
    Optional password for encryption. If not supplied, a default is used or prompted for.

.PARAMETER DryRun
    Simulates the compression process without creating the ZIP file.

.EXAMPLE
    Compress-Contents -SourcePaths .\*.bas, .\*.cls -TargetDir .\Backups -DryRun

.EXAMPLE
    Compress-Contents -SourcePaths "C:\Projects\MyModule", "C:\Temp\*.ps1" -NI
#>
#========================================
function Compress-Contents {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$SourcePaths,

        [string]$TargetDir,

        [switch]$NI,

        [string]$ZipFileName = "",

        [string]$PW = "",

        [switch]$Exec,
        [switch]$Recurse
    )

    If ($Exec) { Set-DryRun $false }
    
    # Expand wildcard paths to actual files
    $expandedPaths = @()
    foreach ($path in $SourcePaths) {
        if (Test-Path $path) {
            $expandedPaths += (Resolve-Path -Path $path).Path
        } else {
            $expandedPaths += (Get-ChildItem -Path $path -File -Recurse:$Recurse | Select-Object -ExpandProperty FullName)
        }
    }

    if (-not $expandedPaths) {
        Write-Error "No files matched the specified paths."
        return
    }

    if (-not $ZipFileName) {
        $firstSource = $expandedPaths[0]
        $baseName = if (Test-Path -Path $firstSource -PathType Container) {
            (Get-Item -Path $firstSource).Name
        } else {
            (Get-Item -Path $firstSource).BaseName
        }
        $ZipFileName = "$baseName" + "_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".zip"
        Log -Always "ZipFileName = $ZipFileName"
    }

    if (-not $PW) {
        $PW = $Script:DefPW
    }

    if (-not $NI) {
        $defaultFileNameTmp = $ZipFileName
        $ZipFileName = Read-Host -Prompt "Enter zip file name (default = $defaultFileNameTmp)"
        if (-not $ZipFileName) { $ZipFileName = $defaultFileNameTmp }

        $userPw = Read-Host -Prompt "Enter encryption password (leave blank for default)"
        if ($userPw) { $PW = $userPw }
    }

    if (-not $TargetDir) {
        $TargetDir = (Get-Location).Path
    }

    if (-not (Test-Path -Path $TargetDir)) {
        if (Get-DryRun) {
            Log -DryRun "[DryRun] Would create target directory: $TargetDir"
        } else {
            New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null
        }
    }

    $zipPath = Join-Path -Path $TargetDir -ChildPath $ZipFileName

    # Construct zip command
    $quotedFiles = $expandedPaths | ForEach-Object { '"{0}"' -f $_ }
    $zipArgs = @(
        "-s$PW"
        $Global:WinZipArgs
        "-a"
        "`"$zipPath`""
    ) + $quotedFiles

    $cmd = "`"$Global:WinZipExe`" " + ($zipArgs -join ' ')

    if (-not (Get-DryRun)) {
        #& $Global:WinZipExe @zipArgs
        Log -Dbg "Executing: $cmd"
        $null = Invoke-Expression "& $cmd"
    }
    else {
        #Log -DryRun "$Global:WinZipExe (Format-ToString($zipArgs))"
        Log -DryRun "$cmd"
    }

    return $zipPath
}
#endregion Compress-Contents
#==================================================================================


#==================================================================================
#region
function Expand-Content {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ZipFilePath,

        [string]$TargetDir
    )

    # Use the current directory as the default target directory
    if ($null -eq $TargetDir -or $TargetDir -eq "" ) { $TargetDir = (Get-Location).Path }

    # Ensure the target directory exists
    if (-not (Test-Path -Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir | Out-Null
    }

    # Extract the zip file contents to the target directory
    Add-Type -AssemblyName "System.IO.Compression.FileSystem"
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFilePath, $TargetDir)
}
#==================================================================================
