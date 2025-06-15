# ===========================================================================================
#region     Test-DateTimeUtils.Tests.ps1
<#
.SYNOPSIS
    Pester tests for DateTimeUtils.ps1 functions.
#>
# ===========================================================================================
# Ensure DevUtils is sourced before running these tests.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\..\DevUtils\CallStack.ps1"

if (-not $Global:PSRoot) {
    $Global:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    Write-Host "Set Global:PSRoot = $Global:PSRoot"
}
if (-not $Global:PSRoot) {
    throw "Global:PSRoot must be set by the entry-point script before using internal components."
}

#if (-not $Global:CliArgs) {
    $Global:CliArgs = $args
#}

Describe "DateTimeUtils.ps1" {

    BeforeAll {
        # Ensure DateTimeUtils is sourced before running these tests.
        . "$Global:PSRoot\Scripts\DateTimeUtils\DateTimeUtils.ps1"
    }

    Context "ConvertTo-DateTime" {
        It "Should convert valid datetime strings" {
            $result = ConvertTo-DateTime "2025-04-26T14:30:00"
            $result | Should -BeOfType "datetime"
            $result | Should -Be ([datetime]"2025-04-26T14:30:00")

            $result = ConvertTo-DateTime "04/26/25 2:30 PM"
            $result | Should -BeOfType "datetime"
            $result | Should -Be ([datetime]"2025-04-26T14:30:00")

            $result = ConvertTo-DateTime "2:30 PM" -FallbackDateTime (Get-Date "2000-01-01")
            $result | Should -BeOfType "datetime"
            $result | Should -Be ([datetime]"2000-01-01T14:30:00")
        }

        It "Should convert valid date strings" {
            $result = ConvertTo-DateTime "2025-04-26"
            $result | Should -BeOfType "datetime"
            $result | Should -Be ([datetime]"2025-04-26T00:00:00")

            $result = ConvertTo-DateTime "04/26/2025"
            $result | Should -BeOfType "datetime"
            $result | Should -Be ([datetime]"2025-04-26T00:00:00")

            $result = ConvertTo-DateTime "26/04/2025"
            $result | Should -BeOfType "datetime"
            $result | Should -Be ([datetime]"2025-04-26T00:00:00")

            $result = ConvertTo-DateTime "20250426"
            $result | Should -BeOfType "datetime"
            $result | Should -Be ([datetime]"2025-04-26T00:00:00")

            $result = ConvertTo-DateTime "2025-04"
            $result | Should -BeOfType "datetime"
            $result | Should -Be ([datetime]"2025-04-01T00:00:00")

            $result = ConvertTo-DateTime "04/2025"
            $result | Should -BeOfType "datetime"
            $result | Should -Be ([datetime]"2025-04-01T00:00:00")

            $result = ConvertTo-DateTime "2025"
            $result | Should -BeOfType "datetime"
            $result | Should -Be ([datetime]"2025-01-01T00:00:00")
        }

        It "Should convert valid time strings" {
            $todayDate = Get-Date -Format 'yyyy-MM-dd' -Hour 0 -Minute 0 -Second 0

            $result = ConvertTo-DateTime "14:30:00"
            $result | Should -BeOfType "datetime"
            $result | Should -Be ([datetime]"$todayDate 14:30:00")

            $result = ConvertTo-DateTime "14:30"
            $result | Should -BeOfType "datetime"
            $result | Should -Be ([datetime]"$todayDate 14:30:00")

            $result = ConvertTo-DateTime "2:30 PM"
            $result | Should -BeOfType "datetime"
            $result | Should -Be ([datetime]"$todayDate 14:30:00")

            $result = ConvertTo-DateTime "2:30:00 PM"
            $result | Should -BeOfType "datetime"
            $result | Should -Be ([datetime]"$todayDate 14:30:00")
        }

        It "Should throw an error for invalid datetime strings" {
            { ConvertTo-DateTime "invalid-date-string" } | Should -Throw "Unable to parse date string: 'invalid-date-string'"
        }
    }

    Context "Find-DateTimeSubstrings" {
        It "Should find datetime substrings in input string" {
            $result = Find-DateTimeSubstrings -InputString "The event is scheduled for 2025-04-26T14:30:00 and 04/26/2025."
            $result | Should -HaveCount 2
            $result | Should -Contain @{
                Type = "datetime"
                Format = "yyyy-MM-ddTHH:mm:ss"
                Substring = "2025-04-26T14:30:00"
                Index = 27
            }
            $result | Should -Contain @{
                Type = "date"
                Format = "MM/dd/yyyy"
                Substring = "04/26/2025"
                Index = 51
            }
        }

        It "Should find various date patterns in input string" {
            $result = Find-DateTimeSubstrings -InputString "Dates: 2025-04-26, 04/26/2025, 26/04/2025, 20250426, 2025-04, 04/2025, 2025."
            $result | Should -HaveCount 7
            $result | Should -Contain @{
                Type = "date"
                Format = "yyyy-MM-dd"
                Substring = "2025-04-26"
                Index = 7
            }
            $result | Should -Contain @{
                Type = "date"
                Format = "MM/dd/yyyy"
                Substring = "04/26/2025"
                Index = 18
            }
            $result | Should -Contain @{
                Type = "date"
                Format = "dd/MM/yyyy"
                Substring = "26/04/2025"
                Index = 29
            }
            $result | Should -Contain @{
                Type = "date"
                Format = "yyyyMMdd"
                Substring = "20250426"
                Index = 40
            }
            $result | Should -Contain @{
                Type = "date"
                Format = "yyyy-MM"
                Substring = "2025-04"
                Index = 49
            }
            $result | Should -Contain @{
                Type = "date"
                Format = "MM/yyyy"
                Substring = "04/2025"
                Index = 57
            }
            $result | Should -Contain @{
                Type = "date"
                Format = "yyyy"
                Substring = "2025"
                Index = 65
            }
        }

        It "Should find various time patterns in input string" {
            $result = Find-DateTimeSubstrings -InputString "Times: 14:30:00, 14:30, 2:30 PM, 2:30:00 PM."
            $result | Should -HaveCount 4
            $result | Should -Contain @{
                Type = "time"
                Format = "HH:mm:ss"
                Substring = "14:30:00"
                Index = 7
            }
            $result | Should -Contain @{
                Type = "time"
                Format = "HH:mm"
                Substring = "14:30"
                Index = 17
            }
            $result | Should -Contain @{
                Type = "time"
                Format = "h:mm tt"
                Substring = "2:30 PM"
                Index = 24
            }
            $result | Should -Contain @{
                Type = "time"
                Format = "h:mm:ss tt"
                Substring = "2:30:00 PM"
                Index = 33
            }
        }

        It "Should return empty array for input string without datetime substrings" {
            $result = Find-DateTimeSubstrings -InputString "No dates here."
            $result | Should -BeEmpty
        }
    }

    Context "Find-DateValue" {
        It "Should find and convert the first datetime substring in input string" {
            $result = Find-DateValue -StringWithDate "The event is scheduled for 2025-04-26T14:30:00 and 04/26/2025."
            $result.Substring | Should -Be "2025-04-26T14:30:00"
            $result.Format | Should -Be "yyyy-MM-ddTHH:mm:ss"
            $result.Value | Should -Be ([datetime]"2025-04-26T14:30:00")
        }

        It "Should return null for input string without datetime substrings" {
            $result = Find-DateValue -StringWithDate "No dates here."
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Remove-TrailingDateFromName" {
        It "Should remove trailing date from name" {
            $result = Remove-TrailingDateFromName -Name "Report 2025-04-26"
            $result | Should -Be "Report"

            $result = Remove-TrailingDateFromName -Name "Report (2025)"
            $result | Should -Be "Report"

            $result = Remove-TrailingDateFromName -Name "Report 04-26-2025"
            $result | Should -Be "Report"
        }

        It "Should return the same name if no trailing date is found" {
            $result = Remove-TrailingDateFromName -Name "Report"
            $result | Should -Be "Report"
        }
    }

    Context "Get-DateTimePatterns" {
        It "Should return date patterns when -Date is specified" {
            $result = Get-DateTimePatterns -Date
            $result | Should -Not -BeEmpty
            $result | Should -Contain @{ format = "yyyy-MM-dd"; regex = "\d{4}-\d{2}-\d{2}" }
        }

        It "Should return time patterns when -Time is specified" {
            $result = Get-DateTimePatterns -Time
            $result | Should -Not -BeEmpty
            $result | Should -Contain @{ format = "HH:mm:ss"; regex = "\d{2}:\d{2}:\d{2}" }
        }

        It "Should return datetime patterns when -DateTime is specified" {
            $result = Get-DateTimePatterns -DateTime
            $result | Should -Not -BeEmpty
            $result | Should -Contain @{ format = "yyyy-MM-ddTHH:mm:ss"; regex = "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}" }
        }
    }
}
#endregion