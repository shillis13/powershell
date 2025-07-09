# ===========================================================================================
# Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

if (-not $Script:PSRoot) {
    $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    Write-Debug "Set Script:PSRoot = $Script:PSRoot"
}
if (-not $Script:PSRoot) {
    throw 'Script:PSRoot must be set by the entry-point script before using internal components.'
}

if (-not $Script:CliArgs) {
    $Script:CliArgs = $args
}

. "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"

# ===========================================================================================
# Function: Select-Files
# ===========================================================================================
function Select-Files {

    param (
        [string]$Dir = '.',
        [string]$Ext = '*',
        [string]$SubStr = '',

        [scriptblock[]]$Size, 
        [scriptblock[]]$FilterByDate, 

        [ValidateSet('Creation', 'LastWrite', 'Filename')]
        [string]$DateSource = 'Creation',

        [ValidateSet('Name', 'Date', 'Size', 'Dir', 'Ext')]
        [string[]]$OrderBy,
        [string]$Order = 'ASC',

        [int]$FirstN,
        [int]$LastN,

        [switch]$Recurse,
        [switch]$Inverse,
        [switch]$HelpVerbose 
    )

    if ($HelpVerbose) { 
        Get-Help -Detailed 
        Write-Host 'Examples:' 
        Write-Host "  Select-Files -Dir 'C:\Files' -Ext '.txt'" 
        Write-Host '  Selects all .txt files in the specified directory.' 
        Write-Host '' 
        Write-Host "  Select-Files -Dir 'C:\Files' -SubStr 'report'" 
        Write-Host "  Selects all files containing 'report' in the filename." 
        Write-Host '' 
        Write-Host "  Select-Files -Dir 'C:\Files' -Size { $_ -gt 100KB -and $_ -lt 1MB }" 
        Write-Host '  Selects all files with size between 100KB and 1MB.' 
        Write-Host '' 
        Write-Host "  Select-Files -Dir 'C:\Files' -FilterByDate { $_ -gt '2022-01-01' -and $_ -lt '2023-01-01' }" 
        Write-Host '  Selects all files created between January 1, 2022, and January 1, 2023.' 
        Write-Host '' 
        Write-Host "  Select-Files -Dir 'C:\Files' -OrderBy Name -Order ASC -FirstN 5" 
        Write-Host '  Selects the first 5 files sorted by name in ascending order.' 
        Write-Host '' 
        Write-Host "  Select-Files -Dir 'C:\Files' -Recurse" 
        Write-Host '  Selects all files in the specified directory and its subdirectories.' 
        Write-Host '' 
        Write-Host "  Select-Files -Dir 'C:\Files' -Inverse" 
        Write-Host '  Selects all files except those that match the specified filters.' 
        Write-Host '' 
        Write-Host '  Select-Files --help-verbose' 
        Write-Host '  Displays detailed help with examples.' 
        return 
    } 

    if (-not (Test-Path -Path $Dir -PathType Container)) {
        Log -Err "The specified directory does not exist: $Dir"
        return
    }

    $files = Get-ChildItem -Path $Dir -Filter "*$Ext" -File -Recurse:$Recurse

    if ($SubStr) {
        $files = $files | Where-Object { $_.Name -like "*$SubStr*" }
    }


    if ($Size) {
        foreach ($sizeFilter in $Size) { 
            $files = $files | Where-Object { Invoke-Expression "$($_.Length) $sizeFilter" }
        }
    }

    if ($FilterByDate) {
        foreach ($dateFilter in $FilterByDate) { 
            $files = $files | Where-Object {
                if ($DateSource -eq 'Creation') {
                    $fileDate = $_.CreationTime
                }
                elseif ($DateSource -eq 'LastWrite') {
                    $fileDate = $_.LastWriteTime
                }
                elseif ($DateSource -eq 'Filename') {
                    if ($_.Name -match '\d{8}') {
                        $fileDate = [datetime]::ParseExact($matches[0], 'yyyyMMdd', $null)
                    }
                    else {
                        $fileDate = $null
                    }
                }
                else {
                    $fileDate = $null
                }
                if (& $dateFilter $fileDate) {
                    $true
                }
                else {
                    $false
                }
            }
        }
    }

    # Precompute the date value for each file and store it in a custom property
    foreach ($file in $files) {
        if ($DateSource -eq 'Creation') {
            $customDate = $file.CreationTime
        }
        elseif ($DateSource -eq 'LastWrite') {
            $customDate = $file.LastWriteTime
        }
        elseif ($DateSource -eq 'Filename') {
            if ($file.Name -match '\d{8}') {
                $customDate = [datetime]::ParseExact($matches[0], 'yyyyMMdd', $null)
            }
            else {
                $customDate = $null
            }
        }
        else {
            $customDate = $null
        }

        $file | Add-Member -MemberType NoteProperty -Name CustomDate -Value $customDate -PassThru | Out-Null
    }

    # Sorting logic based on OrderBy parameter
    foreach ($orderBy in $OrderBy) {
        if ($orderBy -eq 'Name') {
            $files = if ($Order -eq 'ASC') {
                $files | Sort-Object -Property Name
            }
            else {
                $files | Sort-Object -Property Name -Descending
            }
        }
        elseif ($orderBy -eq 'Date') {
            $files = if ($Order -eq 'ASC') {
                $files | Sort-Object -Property CustomDate
            }
            else {
                $files | Sort-Object -Property CustomDate -Descending
            }
        }
        elseif ($orderBy -eq 'Size') {
            $files = if ($Order -eq 'ASC') {
                $files | Sort-Object -Property Length
            }
            else {
                $files | Sort-Object -Property Length -Descending
            }
        }
        elseif ($orderBy -eq 'Dir') {
            $files = if ($Order -eq 'ASC') {
                $files | Sort-Object -Property DirectoryName
            }
            else {
                $files | Sort-Object -Property DirectoryName -Descending
            }
        }
        elseif ($orderBy -eq 'Ext') {
            $files = if ($Order -eq 'ASC') {
                $files | Sort-Object -Property Extension
            }
            else {
                $files | Sort-Object -Property Extension -Descending
            }
        }
    }

    $selectedFiles = $files | Sort-Object -Property FullName -Unique

    if ($FirstN -or $LastN) {
        $firstFiles = @()
        $lastFiles = @()

        if ($FirstN) { $firstFiles = $selectedFiles | Select-Object -First $FirstN }
        if ($LastN) { $lastFiles = $selectedFiles | Select-Object -Last $LastN }
        $selectedFiles = $firstFiles + $lastFiles | Sort-Object -Unique -Property FullName
    }

    if ($Inverse) {
        $selectedFiles = $files | Where-Object { $_.FullName -notin $selectedFiles.FullName }
    }

    return $selectedFiles.FullName
}
# ===========================================================================================
# Detect if the script is being run directly or invoked
# ===========================================================================================
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    if ($PSBoundParameters.ContainsKey('Help') -or $PSBoundParameters.ContainsKey('?')) {
        Get-Help -Detailed
        exit
    }
}
# Main Execution Block
elseif ($MyInvocation.InvocationName -eq '.') {
    # Script is being sourced, do not execute the function
    Log -Dbg 'Script is being sourced, do not execute.'
    return
}
elseif ($MyInvocation.MyCommand.Path -eq $PSCommandPath) {
    # Script is being executed directly
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path)
    if (Get-Command $baseName -CommandType Function -ErrorAction SilentlyContinue) {
        if ($Global:RemainingArgs) {
            Log -Info "$baseName (Format-ToString -Obj $Global:RemainingArgs)"
        } else {
            Log -Info "$baseName"
        }
        (& $baseName @Global:RemainingArgs)
    }
    else {
        Log -Err "No function named '$baseName' found to match script entry point."
    }
}
else {
    Log -Warn 'Unexpected Context: $($MyInvocation.MyCommand.Path) -ne $PSCommandPath'
}
# ===========================================================================================



