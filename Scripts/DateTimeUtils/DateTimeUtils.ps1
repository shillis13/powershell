# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

if (-not $Global:PSRoot) {
    $Global:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    Write-Host "Set Global:PSRoot = $Global:PSRoot"
}
if (-not $Global:PSRoot) {
    throw "Global:PSRoot must be set by the entry-point script before using internal components."
}

if (-not $Global:CliArgs) {
    $Global:CliArgs = $args
}

. "$Global:PSRoot\Scripts\Initialize-CoreConfig.ps1"

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

.PARAMETER InputString
    The input string to search for date, time, or datetime substrings.

.OUTPUTS
    A hashtable containing the format and matched substring.

.EXAMPLE
    $result = Find-DateTimeSubstrings -InputString "The event is scheduled for 2025-04-26T14:30:00 and 04/26/2025."
#>
# ===========================================================================================
function Find-DateTimeSubstrings {
    param (
        [string]$InputString
    )

    $theMatches = @()
    $uniqueMatches = @{ }
    $matchedIndices = @()

    # Search for matches
    $patterns = Get-DateTimePatterns -Delimiters $global:dateTimeDelimiters -Date -Time -DateTime
    foreach ($pattern in $patterns) {
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

.PARAMETER StringWithDate
    The input string to search for date, time, or datetime substrings.

.OUTPUTS
    A hashtable containing the keys 'substring', 'format', 'regex', and 'value'.

.EXAMPLE
    $result = Find-DateValue -StringWithDate "The event is scheduled for 2025-04-26T14:30:00 and 04/26/2025."
    Write-Host "Substring: $($result.substring), Format: $($result.format), Regex: $($result.regex), Value: $($result.value)"
#>
# ===========================================================================================
function Find-DateValue {
    param (
        [string]$StringWithDate
    )

    $result = $null
    $theMatches = Find-DateTimeSubstrings -InputString $StringWithDate

    if ($theMatches.Count -gt 0) {
        $match = $theMatches[0]
        $value = ConvertTo-DateTime -dateString $match.Substring -Format $match.Format
        $result = @{
            Substring = $match.Substring
            Format = $match.Format
            Regex = $match.Regex
            Value = $value
        }
    }

    return $result
}
#endregion
# ===========================================================================================


# ===========================================================================================
#region     Function: Remove-TrailingDateFromName
function Remove-TrailingDateFromName {
    param (
        [string]$Name
    )
    $patterns = Get-DateTimePatterns -Date
    foreach ($pattern in $patterns) {
        if ($Name -match $pattern.regex) {
            return ($Name -replace $pattern.regex, '').TrimEnd()
        }
    }
    return $Name
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

    $patterns = @()

    $datePatterns = @(
        @{ format = "yyyy-MM-dd"; regex = "\d{4}-\d{2}-\d{2}" },
        @{ format = "MM/dd/yyyy"; regex = "\d{2}/\d{2}/\d{4}" },
        @{ format = "dd/MM/yyyy"; regex = "\d{2}/\d{2}/\d{4}" },
        @{ format = "yyyyMMdd"; regex = "\d{8}" },
        @{ format = "yyyy-MM"; regex = "\d{4}-\d{2}" },
        @{ format = "MM/yyyy"; regex = "\d{2}/\d{4}" },
        @{ format = "yyyy"; regex = "\d{4}" },
        @{ format = "yy-MM-dd"; regex = "\d{2}-\d{2}-\d{2}" },
        @{ format = "MM/dd/yy"; regex = "\d{2}/\d{2}/\d{2}" },
        @{ format = "dd/MM/yy"; regex = "\d{2}/\d{2}/\d{2}" },
        @{ format = "yyMMdd"; regex = "\d{6}" },
        @{ format = "yy-MM"; regex = "\d{2}-\d{2}" },
        @{ format = "MM/yy"; regex = "\d{2}/\d{2}" }
    )

    $timePatterns = @(
        @{ format = "HH:mm:ss"; regex = "\d{2}:\d{2}:\d{2}" },
        @{ format = "HH:mm"; regex = "\d{2}:\d{2}" },
        @{ format = "HH.mm.ss"; regex = "\d{2}\.\d{2}\.\d{2}" },
        @{ format = "HH.mm"; regex = "\d{2}\.\d{2}" },
        @{ format = "HH:mm:ss zzz"; regex = "\d{2}:\d{2}:\d{2} [+-]\d{2}:\d{2}" },
        @{ format = "HH:mm zzz"; regex = "\d{2}:\d{2} [+-]\d{2}:\d{2}" },
        @{ format = "HH.mm.ss zzz"; regex = "\d{2}\.\d{2}\.\d{2} [+-]\d{2}:\d{2}" },
        @{ format = "HH.mm zzz"; regex = "\d{2}\.\d{2} [+-]\d{2}:\d{2}" },
        @{ format = "hh:mm:ss tt"; regex = "\d{2}:\d{2}:\d{2} (AM|PM)" },
        @{ format = "hh:mm tt"; regex = "\d{2}:\d{2} (AM|PM)" },
        @{ format = "hh.mm.ss tt"; regex = "\d{2}\.\d{2}\.\d{2} (AM|PM)" },
        @{ format = "hh.mm tt"; regex = "\d{2}\.\d{2} (AM|PM)" },
        @{ format = "hh:mm:ss tt zzz"; regex = "\d{2}:\d{2}:\d{2} (AM|PM) [+-]\d{2}:\d{2}" },
        @{ format = "hh:mm tt zzz"; regex = "\d{2}:\d{2} (AM|PM) [+-]\d{2}:\d{2}" },
        @{ format = "hh.mm.ss tt zzz"; regex = "\d{2}\.\d{2}\.\d{2} (AM|PM) [+-]\d{2}:\d{2}" },
        @{ format = "hh.mm tt zzz"; regex = "\d{2}\.\d{2} (AM|PM) [+-]\d{2}:\d{2}" }
        @{ format = "h:mm:ss tt"; regex = "\d{1,2}:\d{2}:\d{2} (AM|PM)" },
        @{ format = "h:mm tt"; regex = "\d{1,2}:\d{2} (AM|PM)" },
        @{ format = "h.mm.ss tt"; regex = "\d{1,2}\.\d{2}\.\d{2} (AM|PM)" },
        @{ format = "h.mm tt"; regex = "\d{1,2}\.\d{2} (AM|PM)" },
        @{ format = "h:mm:ss tt zzz"; regex = "\d{1,2}:\d{2}:\d{2} (AM|PM) [+-]\d{2}:\d{2}" },
        @{ format = "h:mm tt zzz"; regex = "\d{1,2}:\d{2} (AM|PM) [+-]\d{2}:\d{2}" },
        @{ format = "h.mm.ss tt zzz"; regex = "\d{1,2}\.\d{2}\.\d{2} (AM|PM) [+-]\d{2}:\d{2}" },
        @{ format = "h.mm tt zzz"; regex = "\d{1,2}\.\d{2} (AM|PM) [+-]\d{2}:\d{2}" }
    )

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

    if ($Date) {
        foreach ($datePattern in $datePatterns) {
            $patterns += @{
                type = "date"
                format = $datePattern.format
                regex = $datePattern.regex
            }
        }
    }

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