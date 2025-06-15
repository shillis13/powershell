
# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

if (-not $Global:PSRoot) {
    $Global:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    Write-Debug "Set Global:PSRoot = $Global:PSRoot"
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

#==================================================================================
#region     Function: Select-Files
<#
    .SYNOPSIS
        Selects files based on various options.
    .PARAMETER Dir
        (Optional) The directory to search for files.
    .PARAMETER Ext
        (Optional) The file extension to filter by. If not specified, all files are included.
    .PARAMETER SubStr
        (Optional) A substring to filter filenames by. If not specified, all files are included.
    .PARAMETER Size
        (Optional) Filter files by size (in bytes). Can use operators like -gt, -lt, -ge, -le, -eq, -ne.
    .PARAMETER FilterByDate
        (Optional) Filter files by a specific date. Can use operators like -gt, -lt, -ge, -le, -eq, -ne.
    .PARAMETER SortByDate
        (Optional) Sort files by a specific date. Allowed values are: Creation, Modification, Filename.
    .PARAMETER DateSource
        (Optional) Specifies the source of the date for filtering and sorting. Allowed values are: Creation, Modification, Filename. Default is Creation.
    .PARAMETER OrderBy
        (Optional) Specifies the properties to order files by. Can be specified multiple times. Allowed values are: Name, Date, Size, Dir, Ext.
    .PARAMETER Order
        (Optional) The order to sort files: ASC or DSC. Default is ASC.
    .PARAMETER FirstN
        (Optional) Select the first N files.
    .PARAMETER LastN
        (Optional) Select the last N files.
    .PARAMETER Recurse
        (Optional) Recurse into all subdirectories, default to false.
    .PARAMETER Inverse
        (Optional) Switch to reverse the selection after filtering.
    .OUTPUTS
        A collection of selected files, optionally sorted.
#>
#==================================================================================
function Select-Files {

    param (
        [string]$Dir = ".",
        [string]$Ext = "*",
        [string]$SubStr = "",

        [scriptblock]$Size,
        [scriptblock]$FilterByDate,

        [ValidateSet("Creation", "LastWrite", "Filename")]
        [string]$SortByDate = "Creation",

        [ValidateSet("Creation", "LastWrite", "Filename")]
        [string]$DateSource = "Creation",

        [ValidateSet("Name", "Date", "Size", "Dir", "Ext")]
        [string[]]$OrderBy,
        [string]$Order = "ASC",

        [int]$FirstN,
        [int]$LastN,

        [switch]$Recurse,
        [switch]$Inverse
    )

    if (-not (Test-Path -Path $Dir -PathType Container)) {
        Log -Err "The specified directory does not exist: $Dir"
        return
    }

    $files = Get-ChildItem -Path $Dir -Filter "*$Ext" -File -Recurse:$Recurse

    if ($SubStr) {
        $files = $files | Where-Object { $_.Name -like "*$SubStr*" }
    }

    if ($Size) {
        $files = $files | Where-Object { Invoke-Expression "$($_.Length) $Size" }
    }

    if ($FilterByDate) {
        $files = $files | Where-Object {
            $fileDate = switch ($DateSource) {
                "Creation" { $_.CreationTime }
                "LastWrite" { $_.LastWriteTime }
                "Filename" {
                    if ($_ -match "\d{8}") {
                        [datetime]::ParseExact($matches[0], "yyyyMMdd", $null)
                    } else {
                        $null
                    }
                }
            }
            Invoke-Expression "$fileDate $FilterByDate"
        }
    }

    # Sorting logic based on OrderBy parameter
    foreach ($orderBy in $OrderBy) {
        switch ($orderBy) {
            "Name" {
                $files = if ($Order -eq "ASC") {
                    $files | Sort-Object -Property Name
                } else {
                    $files | Sort-Object -Property Name -Descending
                }
            }
            "Date" {
                $files = if ($Order -eq "ASC") {
                    $files | Sort-Object -Property @{
                        Expression = {
                            switch ($SortByDate) {
                                "Creation" { $_.CreationTime }
                                "Modification" { $_.LastWriteTime }
                                "Filename" {
                                    if ($_ -match "\d{8}") {
                                        [datetime]::ParseExact($matches[0], "yyyyMMdd", $null)
                                    } else {
                                        $null
                                    }
                                }
                            }
                        }
                    }
                } else {
                    $files = $files | Sort-Object -Property @{
                        Expression = {
                            switch ($SortByDate) {
                                "Creation" { $_.CreationTime }
                                "Modification" { $_.LastWriteTime }
                                "Filename" {
                                    if ($_ -match "\d{8}") {
                                        [datetime]::ParseExact($matches[0], "yyyyMMdd", $null)
                                    } else {
                                        $null
                                    }
                                }
                            }
                        }
                    } -Descending
                }
            }
            "Size" {
                $files = if ($Order -eq "ASC") {
                    $files | Sort-Object -Property Length
                } else {
                    $files | Sort-Object -Property Length -Descending
                }
            }
            "Dir" {
                $files = if ($Order -eq "ASC") {
                    $files | Sort-Object -Property DirectoryName
                } else {
                    $files | Sort-Object -Property DirectoryName -Descending
                }
            }
            "Ext" {
                $files = if ($Order -eq "ASC") {
                    $files | Sort-Object -Property Extension
                } else {
                    $files | Sort-Object -Property Extension -Descending
                }
            }
        }
    }

    $selectedFiles = $files

    if ($FirstN -or $LastN) {
        $firstFiles = @()
        $lastFiles = @()

        if ($FirstN) {
            $firstFiles = $files | Select-Object -First $FirstN
        }

        if ($LastN) {
            $lastFiles = $files | Select-Object -Last $LastN
        }

        $selectedFiles = $firstFiles + $lastFiles | Sort-Object -Unique -Property FullName
    }

    if ($Inverse) {
        $selectedFiles = $files | Where-Object { $_.FullName -notin $selectedFiles.FullName }
    }

    return $selectedFiles
}
#endregion
#==================================================================================


#==================================================================================
# Detect if the script is being run directly or invoked
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    if ($PSBoundParameters.ContainsKey("Help") -or $PSBoundParameters.ContainsKey("?")) {
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
        Log -Info "$baseName (Format-ToString($Global:RemainingArgs))"
        (& $baseName @Global:RemainingArgs)
    } else {
        Log -Err "No function named '$baseName' found to match script entry point."
    }
}
else {
    Log -Warn 'Unexpected Context: $($MyInvocation.MyCommand.Path) -ne $PSCommandPath'
}
#==================================================================================
