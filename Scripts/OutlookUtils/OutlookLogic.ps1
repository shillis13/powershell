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


<#
.SYNOPSIS
    Reusable business logic for organizing Outlook items by year and buffer month range.

.DESCRIPTION
    This module provides pure logic utilities that are safe to test and reuse outside of Outlook COM.
    Includes logic for timestamp matching and building folder paths.

.NOTES
    
#>

# ================================================================
# Function Descriptor:
# Function: Test-DateInRange
# Description:
#   Determines if a timestamp is within a specified date range or within the same year if EndDateTime is not specified.
# Parameters:
#   - TheDateTime (datetime): The date and time to test.
#   - StartDateTime (datetime): The start date and time of the range.
#   - EndDateTime (datetime, Optional): The end date and time of the range. If not specified, the function checks if TheDateTime is within the same year as StartDateTime.
# Returns:
#   - Hashtable: A hashtable with keys 'Match' (boolean) and 'Reason' (string) indicating whether TheDateTime is within the specified range or year, and the reason for the result.
# Example Usage:
#   $result = Test-DateInRange -TheDateTime (Get-Date "2025-04-26") -StartDateTime (Get-Date "2025-01-01") -EndDateTime (Get-Date "2025-12-31")
#   if ($result.Match) {
#       Write-Host "The date is within the range. Reason: $($result.Reason)"
#   } else {
#       Write-Host "The date is not within the range. Reason: $($result.Reason)"
#   }
# ================================================================
function Test-DateInRange {
    param (
        [datetime]$TheDateTime,
        [datetime]$StartDateTime,
        [datetime]$EndDateTime = $null
    )

    $result = @{
        Match  = $false
        Reason = "out of range"
    }

    if ($EndDateTime -eq $null) {
        if ($TheDateTime.Year -eq $StartDateTime.Year) {
            $result.Match = $true
            $result.Reason = "same year"
        } else {
            $result.Reason = "different year"
        }
    } elseif ($TheDateTime -ge $StartDateTime -and $TheDateTime -le $EndDateTime) {
        $result.Match = $true
        $result.Reason = "within range"
    }

    return $result
}


# ============================================================
#region     Function: New-ItemNameWithDate
<#
.SYNOPSIS
    Produces a new folder/item name by stripping trailing date formats and appending a new year.
.DESCRIPTION
    Cleans a base name by removing common trailing date formats (e.g., "Archive 2022") 
    and appends the specified year to produce a normalized, dated name.
.PARAMETER baseName
    The original name which may include a trailing date suffix.
.PARAMETER theDateTime
    The DateTime object from which the year will be extracted.
.OUTPUTS
    [string] A new name string like "Archive 2025", with old date suffixes removed.
.EXAMPLE
    New-ItemNameWithDate -baseName "Client Reports 2022" -theDateTime (Get-Date "2025-01-01")
    # Returns: "Client Reports 2025"
#>
function New-ItemNameWithDate {
    param (
        [string]$baseName,
        [datetime]$theDateTime
    )
    $newName = ""
    if (-not $baseName -or -not $theDateTime ) {
        Log -Warn "Cannot have null or missing parameters: baseName = $baseName : theDateTime = $theDateTime."
    }
    else {
        $cleanName = Remove-TrailingDateFromName -Name $baseName
        $year = $theDateTime.Year
        $newName = "$cleanName $year"
    }
    return $newName
}
