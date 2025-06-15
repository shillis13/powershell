
# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

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
# ===========================================================================================


# . "$Global:PSRoot\Scripts\FileUtils\Select-Files.ps1"  # TODO Incorporate


#------------------------------------------------------------------
#region     *** Show Help Function
<#
.SYNOPSIS
    Displays help information for the Rename-FileExtension function.

.DESCRIPTION
    Provides usage instructions and examples for the Rename-FileExtension function.

.EXAMPLE
    Show-Help-RenameFileExtension
#>
function Show-Help-RenameFileExtension {

    Write-Host @"
This function renames file extensions in a specified directory.

USAGE:
    Rename-FileExtension -OldExt "txt" -NewExt "log" [-Recurse] [-Help] [-DryRun]

PARAMETERS:
    -OldExt        (string): The old file extension to search for.
    -NewExt        (string): The new file extension to rename to.
    -Recurse       (switch): Optional. If specified, includes files in subdirectories.
    -DryRun        (switch): Optional. If specified, simulates the renaming without making actual changes.
    -Help          (switch): Optional. If specified, displays this help message.

NOTES:
- The extensions can be specified with or without the dot (".").
"@
    exit
}
#endregion

#--------------------------------------------------------------------
#region     *** Rename-FileExtension
<#
.SYNOPSIS
    This function renames file extensions in a specified directory.

.DESCRIPTION
    Provides usage instructions and examples for the Rename-FileExtension function.

.EXAMPLE
    Show-Help-RenameFileExtension
#>
function Rename-FileExtension {
    param (
        [string]$OldExt,
        [string]$NewExt,
        [string]$Dir = ".",
        [switch]$Recurse = $false
    )

    if ($Help) {
        Show-Help-RenameFileExtension
        return
    }

    if (-not $Dir) { $Dir = "." }

    if (-not $OldExt -or -not $NewExt) {
        Log -Info "Usage: Rename-FileExtension -OldExt oldExt -NewExt newExt [-Recurse] [-DryRun] [-Help]"
        Log -Info 'Example: Rename-FileExtension -OldExt "txt" -NewExt "log" -Recurse'
        return
    }

    # Remove leading dots if present
    if ($OldExt.StartsWith(".")) { $OldExt = $OldExt.Substring(1) }
    if ($NewExt.StartsWith(".")) { $NewExt = $NewExt.Substring(1) }

    # Set the recurse option
    #$searchOption = if ($Recurse) { [System.IO.SearchOption]::AllDirectories } else { [System.IO.SearchOption]::TopDirectoryOnly }

    # Get the files and rename them
    #$files = Get-ChildItem -Path . -Filter "*.$OldExt" -File -SearchOption $searchOption
    $files = Get-ChildItem -Path $Dir -Filter "*.$OldExt" -File -Recurse:$Recurse
    foreach ($file in $files) {
        $newName = "$($file.BaseName).$NewExt"
        if (Get-DryRun) {
            Log -DryRun "Rename: '$($file.FullName)' to '$newName'"
        } else {
            Log -Dbg "Renaming '$($file.FullName)' to '$newName'"
            Rename-Item -Path $file.FullName -NewName $newName
        }
    }
}

#endRegion


# # Main script block to allow the script to be executed directly
# if ($MyInvocation.MyCommand.Path -eq $PSCommandPath) {
#     param (
#         [string]$OldExt,
#         [string]$NewExt,
#         [switch]$Recurse,
#         [switch]$Exec,
#         [switch]$Help
#     )

#     if ($Exec) {
#         Set-DryRun $false
#     }
    
#     Rename-FileExtension -OldExt $OldExt -NewExt $NewExt -Recurse:$Recurse -Help:$Help

#     Log -ALways "Press any key to exit..."
#     [void][System.Console]::ReadKey($true)
# }
#     Log -Always "InvocName = $($MyInvocation.InvocationName)"
#     Log -Always "CmdPath = $PSCommandPath"
#     Log -Always "Press any key to exit..."

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
    Log -Dbg "ArgsRemaining = $($ArgsRemaining -join ' ')"
    try {
        # Replace with your actual function
        Log -Dbg "Rename-FileExtension $ArgsRemaining"
        Rename-FileExtension @ArgsRemaining
    } catch {
        Log -Err "Execution failed: $_"
    }
} else {
    Log -Warn "Unexpected execution context: $($MyInvocation.MyCommand.Path)"
}
#endregion   Execution Guard / Main Entrypoint
# ==========================================================================================