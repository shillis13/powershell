# ===========================================================
#region	Ensure PSRoot and Dot Source Core Globals
# ===========================================================

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
# ===========================================================

# Import modules
. "$Script:PSRoot\Scripts\FileUtils\Select-Files.ps1" # TODO: integrate

#-------------------------------------------------------
#region     Show Help Functions
# Function to display help
function Show-Help-MoveFiles {
    <#
    .SYNOPSIS
        Displays help information for the MoveFiles script.

    .DESCRIPTION
        Provides usage instructions and examples for the MoveFiles script.

    .EXAMPLE
        Show-Help
    #>
    Write-Host @"
This script moves files from a source directory to a destination directory by:
1. Filtering files based on specified file patterns.
2. Moving the filtered files to the specified destination directory.
3. Retrying the operation for patterns with no matches until a total timeout is reached.

USAGE:
    .\MoveFiles.ps1 -srcDir "C:\Users\shawn.hillis\Downloads" -dstDir "C:\Archive" -filePattern "TO24 NGIS 1.0" -filePattern "Another Pattern" -TOTAL_TIMEOUT 300 -DELAY_SECONDS 10

PARAMETERS:
    -srcDir        (string): The source directory to search for files.
    -dstDir        (string): The destination directory to move files to.
    -filePattern   (string[]): A list of file patterns to search for (can be specified multiple times).
    -TOTAL_TIMEOUT (int): Total timeout in seconds (default: 300 seconds).
    -DELAY_SECONDS (int): Delay between retries in seconds (default: 10 seconds).

NOTES:
- If -filePattern is omitted, all files in the source directory will be moved.
"@
    exit
}

#endregion


# Main function to move files
function Move-Files {
    [CmdletBinding()]
    param (
        [string]$srcDir,
        [string]$dstDir,
        [string[]]$filePattern,
        [int]$TOTAL_TIMEOUT = 300,
        [int]$DELAY_SECONDS = 10,
        [switch]$Recurse,
        [switch]$Help,
        [switch]$DryRun
    )

    if ($Help) {
        Show-Help-MoveFiles
        exit
    }

    Log -Dbg "Validating parameters..."

    # Validate input parameters
    if (-not $srcDir -or -not $dstDir -or -not $filePattern) {
        Log -Warn "Invalid parameters for Move-Files: $($Global:RemainingArgs)"
        Log -Info -MsgOnly "Usage: .\MoveFiles.ps1 -srcDir srcDir -dstDir dstDir -filePattern filePattern [-TOTAL_TIMEOUT TOTAL_TIMEOUT] [-DELAY_SECONDS DELAY_SECONDS]"
        Log -Info -MsgOnly 'Example: .\MoveFiles.ps1 -srcDir "C:\Users\shawn.hillis\Downloads" -dstDir "C:\Archive" -filePattern "TO24 NGIS 1.0" -filePattern "Another Pattern" -Recurse -TOTAL_TIMEOUT 300 -DELAY_SECONDS 10'
        exit
    }

    # Ensure the destination directory exists
    if (-not (Test-Path -Path $dstDir)) {
        if (-not (Get-DryRun)) {
            New-Item -ItemType Directory -Path $dstDir | Out-Null
        }
        Log -Info "Created destination directory: $dstDir"
    }

    Log -Dbg "Validated parameters."

    # Get the script start time
    $start_time = Get-Date

    while ($true) {
        $noMatchPatterns = @()

        Log -Dbg "Processing patterns at $(Get-Date -Format HH:mm:ss)"

        foreach ($pattern in $filePattern) {
            $pattern = $pattern + "*"
            Log -Dbg "Processing pattern '$pattern'"
            $fileFound = $false

            $files = Get-ChildItem -Path $srcDir -Filter $pattern -Recurse:$Recurse

            foreach ($file in $files) {
                $fileFound = $true
                if (Get-DryRun) {
                    Log -DryRun "DryRun: Moving file: '$($file.FullName)' to: '$dstDir'"
                } else {
                    Log -Info "Moving file: '$($file.FullName)' to: '$dstDir'"
                    Move-Item -Path $file.FullName -Destination $dstDir -Force
                }
            }

            if (-not $fileFound) {
                Log -Warn "No files found for pattern '$pattern'"
                $noMatchPatterns += $pattern
            }
        }

        if ($noMatchPatterns.Count -gt 0) {
            Log -Dbg "Patterns with no matches:"
            foreach ($pattern in $noMatchPatterns) {
                Log -Dbg "- $pattern"
            }

            # Calculate elapsed time
            $elapsed_time = (New-TimeSpan -Start $start_time).TotalSeconds

            if ($elapsed_time -ge $TOTAL_TIMEOUT) {
                Log -Dbg "Total timeout of $TOTAL_TIMEOUT seconds reached. Exiting script."
                Log -Dbg "Patterns still with no matches:"
                foreach ($pattern in $noMatchPatterns) {
                    Log -Dbg "- $pattern"
                }
                exit
            }

            Log -Info "Waiting for $DELAY_SECONDS seconds before retrying..."
            Start-Sleep -Seconds $DELAY_SECONDS
            $filePattern = $noMatchPatterns
        } else {
            Log -Dbg "All patterns have been processed successfully."
            break
        }
    }
}

# # If the script is being executed directly, call the function
# if ($MyInvocation.InvocationName -eq $PSCommandPath) {
#     Move-Files @PSBoundParameters
    
#     Log -ALways "Press any key to exit..."
#     [void][System.Console]::ReadKey($true)
# }

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
        Log -Info "$baseName (Format-ToString($Global:RemainingArgs))"
        (& $baseName @Global:RemainingArgs)
    } else {
        Log -Err "No function named '$baseName' found to match script entry point."
    }
} else {
    Log -Warn "Unexpected execution context: $($MyInvocation.MyCommand.Path)"
}
#endregion   Execution Guard / Main Entrypoint
# ==========================================================================================