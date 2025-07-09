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

if (-not $global:dateTimeDelimiters) {
    $global:dateTimeDelimiters = @("T", " ")
}

#endregion
# ===========================================================================================



# ===========================================================================================
#region      Function: ConvertTo-DateTime
# Description:
#   Converts a flexible string into a DateTime object by dynamically
#   combining date and time formats with specified dateTimeDelimiters.
#   Supports:
#     - 24-hour and 12-hour time formats
#     - Tolerant of missing date or time parts
#     - Assumes fallback date for time-only strings
#
# Parameters:
#   - dateString (string): The input date or datetime string to parse.
#   - FallbackDateTime (datetime, optional): If only a time is provided,
#       this date is used for the missing date portion. Defaults to today.
#   - Format (string, optional): The specific format to use for parsing.
#       Defaults to "" which means all formats will be tried.
#
# Returns:
#   - datetime: The parsed DateTime object.
#
# Throws:
#   - An error if the input cannot be parsed.
#
# Example Usage:
#   $dt = ConvertTo-DateTime "2025-04-26T14:30:00"
#   $dt = ConvertTo-DateTime "04/26/25 2:30 PM"
#   $dt = ConvertTo-DateTime "2:30 PM" -FallbackDateTime (Get-Date "2000-01-01")
#   $dt = ConvertTo-DateTime "2025-04-26T14:30:00" -Format "yyyy-MM-ddTHH:mm:ss"
# ===========================================================================================
function ConvertTo-DateTime {
    param (
        [string]$dateString,
        [datetime]$FallbackDateTime, #= (Get-Date),
        [string]$Format = ""
    )

    if (-not $FallbackDateTime) {
        $FallbackDateTime = (Get-Date)
    }
    $dateTime = $null
    #$dateTimeFormats = @()

    # # Get all the patterns
    # if ($Format -eq "") {
    $patterns = Get-DateTimePatterns -Delimiters $global:dateTimeDelimiters -Date -Time -DateTime
    #     foreach ($pattern in $patterns) {
    #         $dateTimeFormats += $pattern.format
    #     }
    # } else {
    #     $dateTimeFormats += $Format
    # }

    #$method = [datetime].GetMethod("ParseExact", [Type[]]@([string], [string], [System.IFormatProvider]))
    #Write-Host "Method Info: " $method

    # 1st. Try each pattern with [datetime]::ParseExact. The reason we do this first is for the case of $dateString being just a time,
    # we want to honor the $FallbackDateTime. If we did either ::Parse() first, they would parse the time but use today's date.
    foreach ($pattern in $patterns) {
        try {
            $format = $pattern.format
            # if ($format -eq "hh:mm tt" -or $format -eq "h:mm tt") {
            #     Write-Host "Break Here"
            # }
            $dateTime = [datetime]::ParseExact($dateString, $format, [System.Globalization.CultureInfo]::InvariantCulture) 
            if ($dateTime.Year -eq 1 -or $pattern.type -eq "time") {
                #$dateTime = Get-Date -Year $FallbackDateTime.Year -Month $FallbackDateTime.Month -Day $FallbackDateTime.Day `
                #    -Hour $dateTime.Hour -Minute $dateTime.Minute -Second $dateTime.Second
                $dateTime = [datetime]::new(
                    $FallbackDateTime.Year, $FallbackDateTime.Month, $FallbackDateTime.Day, 
                    $dateTime.Hour,         $dateTime.Minute,        $dateTime.Second)
            }
            break
        } catch {
            # continue
        }
    }

    # 2nd, Try [datetimeoffset]::Parse
    if (-not $dateTime) {
        try {
            $dateTime = [datetimeoffset]::Parse($dateString).DateTime
        } catch {
            # continue
        }
    }

    # 3rd, Try [datetime]::Parse, although I don't know why this would succeed when [datetimeoffset]::parse failed
    if (-not $dateTime) {
        try {
            $dateTime = [datetime]::Parse($dateString)
        } catch {
            # continue
        }
    }

    # Throw exception if all attempts fail
    if (-not $dateTime) {
        throw "Unable to parse date string: '$dateString'"
    }

    return $dateTime
}
#endregion
# ===========================================================================================


# ===========================================================================================
#region     Function: Find-DateTimeSubstrings
<#
.SYNOPSIS
    Finds and extracts date, time, or datetime substrings from a given input string.

.DESCRIPTION
    This function takes an input string and searches for substrings that match any of the
    specified date, time, or datetime formats. It returns a hashtable with the format that
    matched and the substring that matched.

    If none of -DateTimes, -Dates, or -Times are specified, then it will be as if all of them were specified.

.PARAMETER InputString
    The input string to search for date, time, or datetime substrings.

.PARAMETER Patterns
    An array of custom patterns to use for matching date, time, or datetime substrings.

.PARAMETER DateTimes
    If set, searches for datetime substrings.

.PARAMETER Dates
    If set, searches for date substrings.

.PARAMETER Times
    If set, searches for time substrings.

.OUTPUTS
    A hashtable containing the format and matched substring.

.EXAMPLE
    $result = Find-DateTimeSubstrings -InputString "The event is scheduled for 2025-04-26T14:30:00 and 04/26/2025."
    # Output:
    # Type       Format              Substring           Index
    # ----       ------              ---------           -----
    # DateTime   yyyy-MM-ddTHH:mm:ss 2025-04-26T14:30:00  25
    # Date       MM/dd/yyyy          04/26/2025          48

.EXAMPLE
    $result = Find-DateTimeSubstrings -InputString "Meeting at 10:00 AM on 07/05/2025."
    # Output:
    # Type       Format     Substring   Index
    # ----       ------     ---------   -----
    # Time       hh:mm tt   10:00 AM    11
    # Date       MM/dd/yyyy 07/05/2025  22

.EXAMPLE
    $result = Find-DateTimeSubstrings -InputString "Start: 2025-07-05 08:00:00, End: 2025-07-05 17:00:00"
    # Output:
    # Type       Format              Substring           Index
    # ----       ------              ---------           -----
    # DateTime   yyyy-MM-dd HH:mm:ss 2025-07-05 08:00:00 7
    # DateTime   yyyy-MM-dd HH:mm:ss 2025-07-05 17:00:00 30

.EXAMPLE
    $result = Find-DateTimeSubstrings -InputString "No dates or times here."
    # Output:
    # (empty array)

#>
# ===========================================================================================
function Find-DateTimeSubstrings {
    param (
        [string]$InputString,
        [array]$Patterns,
        [switch]$DateTimes,
        [switch]$Dates,
        [switch]$Times
    )

    # If Patterns is null or empty, get patterns based on the specified switches
    if (-not $Patterns) {
        $Patterns = Get-DateTimePatterns -DateTimes:$DateTimes -Dates:$Dates -Times:$Times
    }

    $theMatches = @()
    $uniqueMatches = @{ }
    $matchedIndices = @()

    # Search for matches using the specified or default patterns
    foreach ($pattern in $Patterns) {
        $regexPattern = $pattern.regex

        $matchesFound = [regex]::Matches($InputString, $regexPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        foreach ($match in $matchesFound) {
            $matchedString = $match.Value
            $startIndex = $match.Index
            $endIndex = $startIndex + $matchedString.Length - 1

            # Check for overlapping matches
            $overlap = $false
            foreach ($matchedRange in $matchedIndices) {
                if (($startIndex -le $matchedRange.End) -and ($endIndex -ge $matchedRange.Start)) {
                    $overlap = $true
                    break
                }
            }

            if (-not $overlap) {
                $matchKey = "$($pattern.type):$($startIndex)"
                if (-not $uniqueMatches.ContainsKey($matchKey)) {
                    $uniqueMatches[$matchKey] = $true
                    $theMatches += @(
                        [PSCustomObject]@{
                            Type = $pattern.type
                            Format = $pattern.format
                            Substring = $matchedString
                            Index = $startIndex
                            #Regex = $regexPattern
                        }
                    )
                    $matchedIndices += [PSCustomObject]@{ Start = $startIndex; End = $endIndex }
                }
            }
        }
    }

    return $theMatches
}
#endregion
# ===========================================================================================

# ===========================================================================================
#region     Function: Find-DateValue
<#
.SYNOPSIS
    Finds and extracts the first date, time, or datetime value from a given input string.

.DESCRIPTION
    This function takes an input string, searches for substrings that match any of the
    specified date, time, or datetime formats, and converts the first match to a DateTime object.
    It returns a hashtable with the keys 'substring', 'format', 'regex', and 'value'.
    
    If -FromTheBack is specified, the search is performed from back to front.
    The -Skip parameter allows skipping the first N matches.
    The -Count parameter returns the number of matches found.

.PARAMETER StringWithDate
    The input string to search for date, time, or datetime substrings.

.PARAMETER Patterns
    An array of custom patterns to use for matching date, time, or datetime substrings.

.PARAMETER DateTimes
    If set, searches for datetime substrings.

.PARAMETER Dates
    If set, searches for date substrings.

.PARAMETER Times
    If set, searches for time substrings.

.PARAMETER FromTheBack
    If set, searches from the back to the front of the string.

.PARAMETER Skip
    The number of matches to skip.

.PARAMETER Count
    If set, returns the number of matches found.

.OUTPUTS
    A hashtable containing the keys 'substring', 'format', 'regex', and 'value'.

.EXAMPLE
    $result = Find-DateValue -StringWithDate "The event is scheduled for 2025-04-26T14:30:00 and 04/26/2025."
    Write-Host "Substring: $($result.substring), Format: $($result.format), Regex: $($result.regex), Value: $($result.value)"
#>
# ===========================================================================================
function Find-DateValue {
    param (
        [string]$StringWithDate,
        [array]$Patterns,
        [switch]$DateTimes,
        [switch]$Dates,
        [switch]$Times,
        [switch]$FromTheBack,
        [int]$Skip = 0,
        [switch]$Count
    )

    # Find all date, time, or datetime substrings in the input string
    $theMatches = Find-DateTimeSubstrings -InputString $StringWithDate -Patterns $Patterns -DateTimes:$DateTimes -Dates:$Dates -Times:$Times

    # Sort matches based on the FromTheBack parameter
    if ($FromTheBack) {
        $theMatches = $theMatches | Sort-Object -Property Index -Descending
    } else {
        $theMatches = $theMatches | Sort-Object -Property Index
    }

    # Skip the specified number of matches
    if ($Skip -gt 0) {
        $theMatches = $theMatches | Select-Object -Skip $Skip
        if ($theMatches -isnot [array]) {
            $theMatches = @($theMatches)
        }
    }

    # Return the count of matches if the Count parameter is specified
    if ($Count) {
        return $theMatches.Count
    }

    # Extract the first match after skipping
    $result = $null
    if ($theMatches.Count -gt 0) {
        $match = $theMatches[0]
        $value = ConvertTo-DateTime -dateString $match.Substring -Format $match.Format
        $result = @{
            Type = $match.type
            Format = $match.format
            Substring = $match.Substring
            Index = $match.Index
            Value = $value
        }
    }

    return $result
}
#endregion
# ===========================================================================================


# ===========================================================================================
#region     Function: Remove-DateTimesFromString
<#
.SYNOPSIS
    Removes date, time, or datetime substrings from a given input string.

.DESCRIPTION
    This function takes an input string and searches for substrings that match any of the
    specified date, time, or datetime formats. It removes these substrings based on the 
    specified parameters, including any enclosing characters. If the enclosing characters 
    are the same, only one of them is removed. If two consecutive non-alphanumeric characters 
    are left together after removal, one of them is removed.

.PARAMETER Name
    The input string to remove date, time, or datetime substrings from.

.PARAMETER RemoveFromFront
    If set, removes date, time, or datetime substrings starting from the front of the string. 
    This option requires that RemoveCount be specified, or else it removes all date-times.

.PARAMETER RemoveCount
    The number of date, time, or datetime substrings to remove. If not specified, all substrings are removed.  
    By default starts from the back.

.PARAMETER Dates
    If set, only date substrings are removed.

.PARAMETER Times
    If set, only time substrings are removed.

.OUTPUTS
    A string with the specified date, time, or datetime substrings removed.

.EXAMPLE
    $result = Remove-DateTimesFromString -Name "Report_2025-07-05"
    # Output: "Report"

.EXAMPLE
    $result = Remove-DateTimesFromString -Name "Event (12/05/2025)"
    # Output: "Event"

.EXAMPLE
    $result = Remove-DateTimesFromString -Name "Meeting at 10:00 AM"
    # Output: "Meeting at"

.EXAMPLE
    $result = Remove-DateTimesFromString -Name "Document 2025-07-05 at 12:00:00" -RemoveFromFront
    # Output: "Document at 12:00:00"

.EXAMPLE
    $result = Remove-DateTimesFromString -Name "Document 2025-07-05 12:00:00" -RemoveCount 1
    # Output: "Document"

.EXAMPLE
    $result = Remove-DateTimesFromString -Name "Document Date: 2025-07-05 Time: 12:00:00" -RemoveCount 1
    # Output: "Document Date: 2025-07-05 Time:"

.EXAMPLE
    $result = Remove-DateTimesFromString -Name "Event (12/05/2025) Poker"
    # Output: "Event Poker"

#>
# ===========================================================================================
function Remove-DateTimesFromString {
    param (
        [string]$Name,
        [int]$RemoveCount = 0,
        [switch]$RemoveFromFront,
        [switch]$Dates,
        [switch]$Times,
        [switch]$StrictMode
    )

    # Determine the appropriate patterns to use based on the parameters
    $patterns = if ($Dates) {
        Get-DateTimePatterns -Date
    } elseif ($Times) {
        Get-DateTimePatterns -Time
    } else {
        Get-DateTimePatterns -Date -Time -DateTime
    }

    # Find all date, time, or datetime substrings in the input string
    $foundMatches = Find-DateTimeSubstrings -InputString $Name -Patterns $patterns | Sort-Object -Property Index -Descending

    # If a specific number of matches to remove is specified and it is less than the total number of matches
    if ($RemoveCount -gt 0 -and $RemoveCount -lt $foundMatches.Count) {
        if ($RemoveFromFront) {
            # Remove elements from the front to retain only the last $RemoveCount elements
            $foundMatches = $foundMatches | Select-Object -Skip ($foundMatches.Count - $RemoveCount)
        } else {
            # Retain only the first $RemoveCount elements from the back
            $foundMatches = $foundMatches | Select-Object -First $RemoveCount
        }
    }

    # Iterate through each match to remove the substrings from the input string
    foreach ($match in $foundMatches) {
        $startIndex = $match.Index
        $endIndex = $startIndex + $match.Substring.Length - 1
        $leftChar = if ($startIndex -gt 0) { $Name[$startIndex - 1] } else { '' }
        $rightChar = if ($endIndex -lt ($Name.Length - 1)) { $Name[$endIndex + 1] } else { '' }

        # Remove the matched substring along with any enclosing characters
        if (-not $StrictMode) {
            if ($leftChar -match '[\(\{\<]' -and $rightChar -match '[\)\}\>]' ) {
                $Name = $Name.Remove($startIndex - 1, $match.Substring.Length + 2)
            } elseif ($leftChar -match '[\s_\-]' -and $rightChar -match '[\s_\-]') {
                $Name = $Name.Remove($startIndex, $match.Substring.Length + 1)
            } else {
                $Name = $Name.Remove($startIndex, $match.Substring.Length)
            }
        } else {
            $Name = $Name.Remove($startIndex, $match.Substring.Length)
        }
    }

    # Remove consecutive non-alphanumeric characters that may have been left together after removal
    $Name = $Name -replace '([^\w\s])\1', '$1'

    # Remove double spaces that may have been left together after removal
    $Name = $Name -replace '\s{2,}', ' '

    # Return the modified string
    return $Name.Trim()
}
#endregion
# ===========================================================================================



# ===========================================================================================
#region     Function: Get-DateTimePatterns
<#
.SYNOPSIS
    Returns a list of common date, time, and datetime regex patterns and their formats.

.DESCRIPTION
    This helper function provides regex patterns that match typical date, time, and datetime formats.
    These can be reused by utilities that need to remove or validate such dates.

.PARAMETER Delimiters
    The delimiters to use between date and time formats. Defaults to $global:dateTimeDelimiters.

.PARAMETER Date
    Include date formats.

.PARAMETER Time
    Include time formats.

.PARAMETER DateTime
    Include datetime formats.

.OUTPUTS
    A list of hashtables with keys 'format' and 'regex' matching various date, time, and datetime formats.

.EXAMPLE
    # Get all date, time, and datetime patterns
    $patterns = Get-DateTimePatterns -Date -Time -DateTime

    # Iterate over the patterns and print the format and regex
    foreach ($pattern in $patterns) {
        Write-Host "Format: $($pattern.format), Regex: $($pattern.regex)"
    }

.EXAMPLE
    # Get only date patterns
    $datePatterns = Get-DateTimePatterns -Date

    # Parse the return values
    foreach ($pattern in $datePatterns) {
        $format = $pattern.format
        $regex = $pattern.regex
        Write-Host "Date Format: $format, Regex: $regex"
    }
#>
function Get-DateTimePatterns {
    param (
        [string[]]$Delimiters = $global:dateTimeDelimiters,
        [switch]$Date,
        [switch]$Time,
        [switch]$DateTime
    )

    # If none of the switches are specified, set them all to true
    if (-not $Date -and -not $Time -and -not $DateTime) {
        $Date = $true
        $Time = $true
        $DateTime = $true
    }

    $patterns = @()

    $datePatterns = @(
        @{ format = "yyyy-MM-dd"; regex = "\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])" },
        @{ format = "MM-dd-yyyy"; regex = "(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])-\d{4}" },
        @{ format = "MM/dd/yyyy"; regex = "(0[1-9]|1[0-2])/(0[1-9]|[12]\d|3[01])/\d{4}" },
        @{ format = "dd/MM/yyyy"; regex = "(0[1-9]|[12]\d|3[01])/(0[1-9]|1[0-2])/\d{4}" },
        @{ format = "yyyyMMdd"; regex = "\d{4}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])" },
        @{ format = "yyyy-MM"; regex = "\d{4}-(0[1-9]|1[0-2])" },
        @{ format = "MM/yyyy"; regex = "(0[1-9]|1[0-2])/\d{4}" },
        @{ format = "MM-yyyy"; regex = "(0[1-9]|1[0-2])-\d{4}" },
        @{ format = "MM_yyyy"; regex = "(0[1-9]|1[0-2])_\d{4}" },
        @{ format = "yyyy"; regex = "\d{4}" },
        @{ format = "yy-MM-dd"; regex = "\d{2}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])" },
        @{ format = "MM/dd/yy"; regex = "(0[1-9]|1[0-2])/(0[1-9]|[12]\d|3[01])/\d{2}" },
        @{ format = "dd/MM/yy"; regex = "(0[1-9]|[12]\d|3[01])/(0[1-9]|1[0-2])/\d{2}" },
        @{ format = "yyMMdd"; regex = "\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])" },
        @{ format = "yy-MM"; regex = "\d{2}-(0[1-9]|1[0-2])" },
        @{ format = "MM/yy"; regex = "(0[1-9]|1[0-2])/\d{2}" },
        @{ format = "MM-yy"; regex = "(0[1-9]|1[0-2])-\d{2}" },
        @{ format = "MM_yy"; regex = "(0[1-9]|1[0-2])_\d{2}" }
    )

    $timePatterns = @(
		# Secs AM|PM TZ
        @{ format = "hh:mm:ss tt zzz"; regex = "(0?[1-9]|1[0-2]):[0-5]\d:[0-5]\d (AM|PM) [+-][01]?\d:[0-5]\d" },
        @{ format = "hh.mm.ss tt zzz"; regex = "(0?[1-9]|1[0-2])\.[0-5]\d\.[0-5]\d (AM|PM) [+-][01]?\d:[0-5]\d" },
        @{ format = "h:mm:ss tt zzz"; regex = "([1-9]|1[0-2]):[0-5]\d:[0-5]\d (AM|PM) [+-][01]?\d:[0-5]\d" },
        @{ format = "h.mm.ss tt zzz"; regex = "([1-9]|1[0-2])\.[0-5]\d\.[0-5]\d (AM|PM) [+-][01]?\d:[0-5]\d" },
		# Secs, TZ
        @{ format = "HH.mm.ss zzz"; regex = "([01]?\d|2[0-3])\.[0-5]\d\.[0-5]\d [+-][01]?\d:[0-5]\d" },
        @{ format = "HH:mm:ss zzz"; regex = "([01]?\d|2[0-3]):[0-5]\d:[0-5]\d [+-][01]?\d:[0-5]\d" },
        @{ format = "h:mm:ss zzz"; regex = "([1-9]|1[0-2]):[0-5]\d:[0-5]\d [+-][01]?\d:[0-5]\d" },
        @{ format = "h.mm.ss zzz"; regex = "([1-9]|1[0-2])\.[0-5]\d\.[0-5]\d [+-][01]?\d:[0-5]\d" },
		# Secs, AM|PM
        @{ format = "hh:mm:ss tt"; regex = "(0?[1-9]|1[0-2]):[0-5]\d:[0-5]\d (AM|PM)" },
        @{ format = "hh.mm.ss tt"; regex = "(0?[1-9]|1[0-2])\.[0-5]\d\.[0-5]\d (AM|PM)" },
        @{ format = "h:mm:ss tt"; regex = "([1-9]|1[0-2]):[0-5]\d:[0-5]\d (AM|PM)" },
        @{ format = "h.mm.ss tt"; regex = "([1-9]|1[0-2])\.[0-5]\d\.[0-5]\d (AM|PM)" },
		# AM|PM TZ
        @{ format = "hh:mm tt zzz"; regex = "(0?[1-9]|1[0-2]):[0-5]\d (AM|PM) [+-][01]?\d:[0-5]\d" },
        @{ format = "hh.mm tt zzz"; regex = "(0?[1-9]|1[0-2])\.[0-5]\d (AM|PM) [+-][01]?\d:[0-5]\d" },
        @{ format = "h:mm tt zzz"; regex = "([1-9]|1[0-2]):[0-5]\d (AM|PM) [+-][01]?\d:[0-5]\d" },
        @{ format = "h.mm tt zzz"; regex = "([1-9]|1[0-2])\.[0-5]\d (AM|PM) [+-][01]?\d:[0-5]\d" }
		# Secs
        @{ format = "HH:mm:ss"; regex = "([01]?\d|2[0-3]):[0-5]\d:[0-5]\d" },
        @{ format = "HH.mm.ss"; regex = "([01]?\d|2[0-3])\.[0-5]\d\.[0-5]\d" },
        @{ format = "h:mm:ss"; regex = "([1-9]|1[0-2]):[0-5]\d:[0-5]\d" },
        @{ format = "h.mm.ss"; regex = "([1-9]|1[0-2])\.[0-5]\d\.[0-5]\d" },
		# TZ
        @{ format = "HH:mm zzz"; regex = "([01]?\d|2[0-3]):[0-5]\d [+-][01]?\d:[0-5]\d" },
        @{ format = "HH.mm zzz"; regex = "([01]?\d|2[0-3])\.[0-5]\d [+-][01]?\d:[0-5]\d" },
        @{ format = "h:mm zzz"; regex = "([1-9]|1[0-2]):[0-5]\d [+-][01]?\d:[0-5]\d" },
        @{ format = "h.mm zzz"; regex = "([1-9]|1[0-2])\.[0-5]\d [+-][01]?\d:[0-5]\d" }
		# AM|PM
        @{ format = "hh:mm tt"; regex = "(0?[1-9]|1[0-2]):[0-5]\d (AM|PM)" },
        @{ format = "hh.mm tt"; regex = "(0?[1-9]|1[0-2])\.[0-5]\d (AM|PM)" },
        @{ format = "h:mm tt"; regex = "([1-9]|1[0-2]):[0-5]\d (AM|PM)" },
        @{ format = "h.mm tt"; regex = "([1-9]|1[0-2])\.[0-5]\d (AM|PM)" },
		# Hours Mins
        @{ format = "HH:mm"; regex = "([01]?\d|2[0-3]):[0-5]\d" },
        @{ format = "HH.mm"; regex = "([01]?\d|2[0-3])\.[0-5]\d" },
        @{ format = "h:mm"; regex = "([1-9]|1[0-2]):[0-5]\d" },
        @{ format = "h.mm"; regex = "([1-9]|1[0-2])\.[0-5]\d" }
    )

    # Generate datetime patterns if $DateTime is specified
    if ($DateTime) {
        foreach ($delimiter in $Delimiters) {
            foreach ($datePattern in $datePatterns) {
                foreach ($timePattern in $timePatterns) {
                    $patterns += @{
                        type = "datetime"
                        format = "$($datePattern.format)$delimiter$($timePattern.format)"
                        regex = "$($datePattern.regex)$delimiter$($timePattern.regex)"
                    }
                }
            }
        }
    }

    # Add date patterns if $Date is specified
    if ($Date) {
        foreach ($datePattern in $datePatterns) {
            $patterns += @{
                type = "date"
                format = $datePattern.format
                regex = $datePattern.regex
            }
        }
    }

    # Add time patterns if $Time is specified
    if ($Time) {
        foreach ($timePattern in $timePatterns) {
            $patterns += @{
                type = "time"
                format = $timePattern.format
                regex = $timePattern.regex
            }
        }
    }

    return $patterns
}#endregion
# ===========================================================================================


# ===========================================================================================
#region     Function: Test-ConvertToDateTime
# Description:
#   Tests the ConvertTo-DateTime function with various date and time formats.
# ===========================================================================================
function Test-ConvertToDateTime {
    param (
        [string]$dateString,
        [datetime]$expectedResult
    )

    try {
        $result = ConvertTo-DateTime -dateString $dateString

        # [datetime] comparisons
        if ($result -eq $expectedResult) {
            Write-Host "PASS: $dateString -> $result"
        } else {
            $difference = New-TimeSpan -Start $result -End $expectedResult
            Write-Host "FAIL: $dateString -> $result (Expected: $expectedResult, Difference: $difference)"
        }

        # Now compare string outputs
        if ($result.ToString() -eq $expectedResult.ToString()) {
            Write-Host "PASS: String Comparison: $($result.ToString()) vs $($expectedResult.ToString())"
        } else {
            Write-Host "FAIL: String Comparison: $($result.ToString()) vs $($expectedResult.ToString())"
        }
    } catch {
        Write-Host "ERROR: $dateString -> $_"
    }
}

if ($args[0] -eq "-Test") {
    # Test cases
    $todayDate = Get-Date -Format 'yyyy-MM-dd' -Hour 0 -Minute 0 -Second 0
    $testCases = @(
        @{ dateString = "2025-04-26T14:30:00"; expectedResult = [datetime]"2025-04-26T14:30:00" },
        @{ dateString = "2025-04-26 14:30:00"; expectedResult = [datetime]"2025-04-26T14:30:00" },
        @{ dateString = "2025-04-26"; expectedResult = [datetime]"2025-04-26T00:00:00" },
        @{ dateString = "04/26/2025"; expectedResult = [datetime]"2025-04-26T00:00:00" },
        @{ dateString = "26/04/2025"; expectedResult = [datetime]"2025-04-26T00:00:00" },
        @{ dateString = "20250426"; expectedResult = [datetime]"2025-04-26T00:00:00" },
        @{ dateString = "2025-04"; expectedResult = [datetime]"2025-04-01T00:00:00" },
        @{ dateString = "04/2025"; expectedResult = [datetime]"2025-04-01T00:00:00" },
        @{ dateString = "2025"; expectedResult = [datetime]"2025-01-01T00:00:00" },
        @{ dateString = "14:30:00"; expectedResult = [datetime]"$todayDate 14:30:00" },
        @{ dateString = "14:30"; expectedResult = [datetime]"$todayDate 14:30:00" }
    )

    # Run test cases
    foreach ($testCase in $testCases) {
        Test-ConvertToDateTime -dateString $testCase.dateString -expectedResult $testCase.expectedResult
    }
}
#endregion
# =================================================================================