# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

if (-not $Script:PSRoot) {
    $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    Write-Debug "Set Script:PSRoot = $Script:PSRoot"
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


#==================================================================================
#region      Function Descriptor: Get-FilteredFiles
# This function filters files based on extension and filename substring.
#
# Parameters:
# -Path: The directory path to search for files.
# -Extension: The file extension to filter by.
# -Substring: The filename substring to filter by.
#
# Returns:
# An array of filtered files.
#==================================================================================
function Get-FilteredFiles {
    param (
        [string]$Path,
        [string]$Extension,
        [string]$Substring,
        [switch]$Recurse
    )

    $Files = Get-ChildItem -Path $Path -File -Recurse:$Recurse
    #Log -Dbg "Get-FilteredFiles(): files found in $Path with Recurse = $Recurse : $Files."

    if ($Extension -ne "") {
        $Files = $Files | Where-Object { $_.Extension -eq $Extension }
        #Log -Dbg "Get-FilteredFiles(): files remaining with extension = $Extension : $Files"
    }

    if ($Substring -ne "") {
        $Files = $Files | Where-Object { $_.Name -like "*${Substring}*" }
        #Log -Dbg "Get-FilteredFiles(): files remaining that mactch substring = $Substring : $Files"
    }

    #Log -Dbg "Get-FilteredFiles(): returning files: $Files"
    $Files
}
#endregion
#==================================================================================


#==================================================================================
#region      Function Descriptor: New-UniqueFilename
# This function generates a unique filename by appending a sequence value.
#
# Parameters:
# -BaseName: The base name to use in the new filename.
# -Extension: The file extension.
# -CreationDate: The creation date to include in the filename.
# -SequenceByDate: A flag to indicate whether to use the creation date as the sequencer.
# -DestPath: The destination directory path.
# -SrcPath: The source directory path.
#
# Returns:
# A unique file path.
#==================================================================================
function New-UniqueFilename {
    param (
        [string]$BaseName,
        [string]$Extension,
        [string]$CreationDate,
        [bool]$SequenceByDate,
        [string]$DestPath,
        [string]$SrcPath
    )

    $seq = 1
    $newFileName = "$BaseName`_$CreationDate$Extension"
    $newFilePath = Join-Path -Path $DestPath -ChildPath $newFileName

    while (Test-Path $newFilePath) {
        if ($SequenceByDate) {
            $newFileName = "$BaseName`_$CreationDate`_$seq$Extension"
        } else {
            $newFileName = "$BaseName`_$CreationDate`_$seq$Extension"
        }
        $newFilePath = Join-Path -Path $DestPath -ChildPath $newFileName
        $seq++
    }

    return $newFilePath
}
#endregion
#==================================================================================


#==================================================================================
#region      Function Descriptor: Rename-And-MoveFiles
# This function processes files in a specified directory by:
# 1. Filtering files based on an optional file extension and/or filename substring (AND conditions).
# 2. Renaming files to include a base name and creation date.
# 3. Moving the files to the specified destination directory.
# 4. Appending a sequence value to the filename if multiple files have the same name.
#
# Usage:
# Run the function with the following parameters:
# -SrcPath            (string): The source directory containing files to process (default: "C:\Users\...").
# -DestPath           (string): The destination directory for the processed files (default: "C:\Users\...").
# -BaseName           (string): The base name to use in renamed files (default: "ITD").
# -FilterByExtension  (string): (Optional) Filter files by extension (e.g., ".txt").
# -FilterBySubstring  (string): (Optional) Filter files containing this substring in their name.
# -SequenceByDate     (bool): (Optional) Use the file's creation date as the sequencer. Default is false.
#
# Example Execution:
# .\MoveAndRenameFiles.ps1 -SrcPath "C:\MyPath" -DestPath "C:\MyDestPath" -BaseName "MyBase" -FilterByExtension ".txt" -FilterBySubstring "Report" -SequenceByDate $true 
#==================================================================================
function Rename-And-MoveFiles {
    param (
        [string]$SrcPath = "",
        [string]$DestPath = $SrcPath,
        [string]$BaseName = "",
        [string]$FilterByExtension = ".csv",
        [string]$FilterBySubstring = "",
        [switch]$SequenceByDate = $false,
        [switch]$Exec
    )

    Log -Dbg "Rename-And-MoveFiles -SrcPath $ScrPath -DestPath $DestPath -BaseName $BaseName -FilterByExtension $FilterByExtension -SequenceByDate $SequenceByDate"

    if ($Exec) { Set-DryRun $False }

    # Ensure the destination directory exists
    if (!(Test-Path $DestPath)) {
        New-Item -ItemType Directory -Path $DestPath
    }
 
    # Get filtered files
    $Files = Get-FilteredFiles -Path $SrcPath -Extension $FilterByExtension -Substring $FilterBySubstring |
        Sort-Object CreationTime -Descending

    Log -Dbg "Rename-And-MoveFiles(): FilteredFiles : $Files"

    # Log files found
    if ($Files.Count -gt 0) {
        Log -Info "Files found:"
        foreach ($File in $Files) {
            Log -Info "  - $($File.FullName)"
        }
    } else {
        Log -Info "No files found matching the specified criteria."
    }

    # Process files
    if ($Files.Count -gt 0) {
        foreach ($File in $Files) {
            $CreationDate = $File.CreationTime.ToString("yyyyMMdd")
            Log -Dbg "File: '$File.Name' has creation date: $CreationDate"
            Log -Dbg "$NewFilePath = New-UniqueFilename -BaseName $BaseName -Extension $FilterByExtension -CreationDate $CreationDate -SequenceByDate $SequenceByDate -DestPath $DestPath -SrcPath $SrcPath"
            $NewFilePath = New-UniqueFilename -BaseName $BaseName -Extension $FilterByExtension -CreationDate $CreationDate -SequenceByDate $SequenceByDate -DestPath $DestPath -SrcPath $SrcPath

            # Move and rename file
            Move-Item -Path $File.FullName -Destination $NewFilePath -Force
            Log -Info "Moved and renamed: $($File.FullName)  ([Environment]::NewLine) to: $NewFilePath"
        }
    } else {
        Log -Info "No files found matching the specified criteria."
    }
}
#endregion
#======================================================================================


# ================================================================
#region      Function: ConvertTo_SantizedName
# Description:
#   Sanitizes a given string by replacing specified characters with a replacement character.
#   Useful for creating file names that do not contain invalid characters.
#
# Parameters:
#   - Name (string): The input string to be sanitized. (Mandatory)
#   - ReplacementChar (string): The character to replace invalid characters with. Default is '_'.
#   - CharsToReplace (string): A regex pattern specifying characters to replace. Default is '[\[\]<>\\|/?*"''`()]'.
#
# Returns:
#   - string: The sanitized string with invalid characters replaced.
#
# Example Usage:
#   $sanitized = ConvertTo_SantizedName -Name "Invalid/FileName.txt"    # Returns "Invalid_Filename.txt"
#   $sanitized = ConvertTo_SantizedName -Name "Invalid<FileName>.txt" -ReplacementChar "-"  # Returns "Invalid-Filename-.txt"
#
# Notes:
#   - The function logs a debug message if any characters are replaced.
# ================================================================
function ConvertTo_SantizedName {
    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$ReplacementChar = '_', 
        # Escapes: backslash = '\\', literal brackets = '\[\]'
        # The rest are literals due to being in single quotes.
        [string]$CharsToReplace = '[\[\]<>\\|/?*"''`()]'
    )
    $sanitizedName = $Name -replace $CharsToReplace, $ReplacementChar
    if ($sanitizedName -ne $Name ) { Log -Dbg "Sanitized Name: $Name => $sanitizedName"}
    return $sanitizedName
}
#endregion
#======================================================================================


#======================================================================================
# Main Execution Block
# if ($MyInvocation.InvocationName -eq ".") {
#     # Script is being sourced, do not execute the function
#     Log -Dbg "Script is being sourced, do not execute."
#     return
# } 
# elseif ($MyInvocation.MyCommand.Path -eq $PSCommandPath) {
#     # Script is being executed directly
#     Log -Dbg "Rename-And-MoveFiles @args"
#     Rename-And-MoveFiles @args
# }
# else {
#     Log -Warn "Unexpected Context: $($MyInvocation.MyCommand.Path) -ne $PSCommandPath"
# }
#======================================================================================


# ==========================================================================================
#region      Execution Guard / Main Entrypoint
# ==========================================================================================

if ($MyInvocation.InvocationName -eq '.') {
    # Dot-sourced – do nothing, just define functions/aliases
    Log -Dbg 'Script dot-sourced; skipping main execution.'
    return
}


if ($MyInvocation.MyCommand.Path -eq $PSCommandPath) {
    # Direct execution
    Log -Dbg "RemainingArgs = $($RemainingArgs -join ' ')"
    try {
        # Replace with your actual function
        Log -Dbg "Rename-And-MoveFiles $RemainingArgs"
        (& Rename-And-MoveFiles @RemainingArgs)
    } catch {
        Log -Err -CallStack "Execution failed: $_"
    }
} else {
    Log -Warn "Unexpected execution context: $($MyInvocation.MyCommand.Path)"
}
#endregion   Execution Guard / Main Entrypoint
# ==========================================================================================