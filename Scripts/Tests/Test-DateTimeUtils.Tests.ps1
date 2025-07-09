# Test-DateTimeUtils.Tests.ps1

# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

function InitializeCore {
    if (-not $Script:PSRoot) {
        $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
        Write-Host "Set Script:PSRoot = $Script:PSRoot"
    }
    if (-not $Script:PSRoot) {
        throw 'Script:PSRoot must be set by the entry-point script before using internal components.'
    }

    $Script:CliArgs = $args
    . "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"

    $Script:scriptUnderTest = "$Script:PSRoot\Scripts\DateTimeUtils\DateTime-Utils.ps1"
}



#endregion
# ===========================================================================================

Describe "DateTime-Utils.ps1" {

    BeforeAll {
        # InitializeCore
        if (-not $Script:PSRoot) {
            $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
            Write-Host "Set Script:PSRoot = $Script:PSRoot"
        }
        if (-not $Script:PSRoot) {
            throw 'Script:PSRoot must be set by the entry-point script before using internal components.'
        }

        $Script:CliArgs = $args
        . "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"

        $Script:scriptUnderTest = "$Script:PSRoot\Scripts\DateTimeUtils\DateTime-Utils.ps1"
        . "$Script:scriptUnderTest"
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

            $customObj1 = New-Object PSObject -Property @{
                Format = "yyyy-MM-ddTHH:mm:ss"
                Index = 27
                Substring = "2025-04-26T14:30:00"
                Type = "datetime"
            }
            $customObj2 = New-Object PSObject -Property @{
                Format = "MM/dd/yyyy"
                Index = 51
                Substring = "04/26/2025"
                Type = "date"
            }

            $resultStr1 = Format-ToString -Obj $result[0]
            $expectedStr1 = Format-ToString -Obj $customObj1

            $resultStr2 = Format-ToString -Obj $result[1]
            $expectedStr2 = Format-ToString -Obj $customObj2

            $resultStr1 | Should -BeExactly $expectedStr1
            $resultStr2 | Should -BeExactly $expectedStr2
        }

        It "Should find various date patterns in input string" {
            $result = Find-DateTimeSubstrings -InputString "Dates: 2025-04-26, 04/26/2025, 26/04/2025, 20250426, 2025-04, 04/2025, 2025."
            $result | Should -HaveCount 7
            $resultStr = Format-ToString -Obj $result
            $expectedValues = @()

            $resultStr | Should -Not -BeNullOrEmpty
            $resultStr | Should -Not -Be ""

            $customObj = New-Object PSObject -Property @{
                Format = "yyyy-MM-dd"
                Index = 7
                Substring = "2025-04-26"
                Type = "date"
             }
            $expectedValues += (Format-ToString -Obj $customObj)

            $customObj = New-Object PSObject -Property @{
                Format = "MM/dd/yyyy"
                Index = 19
                Substring = "04/26/2025"
                Type = "date"
            }
            $expectedValues += (Format-ToString -Obj $customObj)

            $customObj = New-Object PSObject -Property @{
                Format = "dd/MM/yyyy"
                Index = 31
                Substring = "26/04/2025"
                Type = "date"
            }
            $expectedValues += (Format-ToString -Obj $customObj)

            $customObj = New-Object PSObject -Property @{
                Format = "yyyyMMdd"
                Index = 43
                Substring = "20250426"
                Type = "date"
            }
            $expectedValues += (Format-ToString -Obj $customObj)

            $customObj = New-Object PSObject -Property  @{
                Format = "yyyy-MM"
                Index = 53
                Substring = "2025-04"
                Type = "date"
            }
            $expectedValues += (Format-ToString -Obj $customObj)

            $customObj = New-Object PSObject -Property  @{
                Format = "MM/yyyy"
                Index = 62
                Substring = "04/2025"
                Type = "date"
            }
            $expectedValues += (Format-ToString -Obj $customObj)

            $customObj = New-Object PSObject -Property @{
                Format = "yyyy"
                Index = 71
                Substring = "2025"
                Type = "date"
            }
            $expectedValues += (Format-ToString -Obj $customObj)

            foreach ($expectedStr in $expectedValues) {
                $resultStr.Contains($expectedStr) | Should -Be $true
                $resultStr | Should -Match $expectedStr
            }
        }

        It "Should find various time patterns in input string" {
            $result = Find-DateTimeSubstrings -InputString "Times: 14:30:00, 14:30, 2:30 PM, 2:30:00 PM."
            $result | Should -HaveCount 4
            $resultStr = Format-ToString -Obj $result
            $expectedValues = @()

            $resultStr | Should -Not -BeNullOrEmpty
            $resultStr | Should -Not -Be ""


            $customObj = New-Object PSObject -Property @{
                Format = "HH:mm:ss"
                Index = 7
                Substring = "14:30:00"
                Type = "time"
            }
            $expectedValues += (Format-ToString -Obj $customObj)

            $customObj = New-Object PSObject -Property @{
                Format = "HH:mm"
                Index = 17
                Substring = "14:30"
                Type = "time"
            }
            $expectedValues += (Format-ToString -Obj $customObj)

            $customObj = New-Object PSObject -Property @{
                Format = "hh:mm tt"
                Index = 24
                Substring = "2:30 PM"
                Type = "time"
            }
            $expectedValues += (Format-ToString -Obj $customObj)

            $customObj = New-Object PSObject -Property @{
                Format = "hh:mm:ss tt"
                Index = 33
                Substring = "2:30:00 PM"
                Type = "time"
            }
            $expectedValues += (Format-ToString -Obj $customObj)

            foreach ($expectedStr in $expectedValues) {
                $resultStr | Should -Match $expectedStr
            }
        }

        It "Should return empty array for input string without datetime substrings" {
            $result = Find-DateTimeSubstrings -InputString "No dates here."
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Find-DateValue" {
        It "Should find and convert the first datetime substring in input string" {
            $result = Find-DateValue -StringWithDate "The event is scheduled for 2025-04-26T14:30:00 and 04/26/2025."
            $result.Substring | Should -Be "2025-04-26T14:30:00"
            $result.Format | Should -Be "yyyy-MM-ddTHH:mm:ss"
            $result.Value | Should -Be ([datetime]"2025-04-26T14:30:00")
        }

        It "Should find and convert the first datetime substring from the back of the input string" {
            $result = Find-DateValue -StringWithDate "The event is scheduled for 2025-04-26T14:30:00 and 04/26/2025." -FromTheBack
            $result.Substring | Should -Be "04/26/2025"
            $result.Format | Should -Be "MM/dd/yyyy"
            $result.Value | Should -Be ([datetime]"2025-04-26T00:00:00")
        }

        It "Should skip the first match and find the second datetime substring in input string" {
            $result = Find-DateValue -StringWithDate "The event is scheduled for 2025-04-26T14:30:00 and 04/26/2025." -Skip 1
            $result.Substring | Should -Be "04/26/2025"
            $result.Format | Should -Be "MM/dd/yyyy"
            $result.Value | Should -Be ([datetime]"2025-04-26T00:00:00")
        }

        It "Should return the count of datetime substrings in input string" {
            $result = Find-DateValue -StringWithDate "The event is scheduled for 2025-04-26T14:30:00 and 04/26/2025." -Count
            $result | Should -Be 2
        }

        It "Should return null for input string without datetime substrings" {
            $result = Find-DateValue -StringWithDate "No dates here."
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Remove-DateTimesFromString" {
        It "Should remove datetime substrings from the input string" {
            $result = Remove-DateTimesFromString -Name "Report 2025-04-26 14:30:00"
            $result | Should -Be "Report"

            $result = Remove-DateTimesFromString -Name "Event (12/05/2025)"
            $result | Should -Be "Event"

            $result = Remove-DateTimesFromString -Name "Meeting at 10:00 AM"
            $result | Should -Be "Meeting at"

            $result = Remove-DateTimesFromString -Name "Document 2025-07-05 at 12:00:00 Sharp" 
            $result | Should -Be "Document at Sharp"

            $result = Remove-DateTimesFromString -Name "Document 2025-07-05 at 12:00:00 Sharp" -RemoveCount 1
            $result | Should -Be "Document 2025-07-05 at Sharp"

            $result = Remove-DateTimesFromString -Name "Document 2025-07-05 at 12:00:00 Sharp" -RemoveFromFront -RemoveCount 1
            $result | Should -Be "Document at 12:00:00 Sharp"

            $result = Remove-DateTimesFromString -Name "Document 2025-07-05 12:00:00" -RemoveCount 1
            $result | Should -Be "Document"

            $result = Remove-DateTimesFromString -Name "Document Date: 2025-07-05 Time: 12:00:00" -RemoveCount 1
            $result | Should -Be "Document Date: 2025-07-05 Time:"

            $result = Remove-DateTimesFromString -Name "Event (12/05/2025) Poker"
            $result | Should -Be "Event Poker"
        }

        It "Should return the same name if no datetime substrings are found" {
            $result = Remove-DateTimesFromString -Name "Report"
            $result | Should -Be "Report"
        }
    }

    Context "Get-DateTimePatterns" {
        It "Should return date patterns when -Date is specified" {
            $result = Get-DateTimePatterns -Date
            $result | Should -Not -BeNullOrEmpty
            $expected = @{ format = "yyyy-MM-dd"; type = "date"; regex = "\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])" }
            $expectedFound = $result | Where-Object {
                $_.format -eq $expected.format -and
                $_.regex -eq $expected.regex
            }
            #$result | Should -Contain $expected
            $expectedFound | Should -Not -BeNullOrEmpty
        }

        It "Should return time patterns when -Time is specified" {
            $result = Get-DateTimePatterns -Time
            $result | Should -Not -BeNullOrEmpty
            $expected = @{ format = "HH:mm:ss"; regex = "([01]?\d|2[0-3]):[0-5]\d:[0-5]\d" }

            $expectedFound = $result | Where-Object {
                $_.format -eq $expected.format -and
                $_.regex -eq $expected.regex
            }
            #$result | Should -Contain $expected
            $expectedFound | Should -Not -BeNullOrEmpty
        }

        It "Should return datetime patterns when -DateTime is specified" {
            $result = Get-DateTimePatterns -DateTime
            $result | Should -Not -BeNullOrEmpty
            $expected = @{ format = "yyyy-MM-ddTHH:mm:ss"; regex = "\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])T([01]?\d|2[0-3]):[0-5]\d:[0-5]\d" }

            $expectedFound = $result | Where-Object { $_.format -eq $expected.format -and $_.regex -eq $expected.regex }
            $expectedFound | Should -Not -BeNullOrEmpty
        }

        It "Should return all patterns when none of the switches are specified" {
            $result = Get-DateTimePatterns
            $result | Should -Not -BeNullOrEmpty
            $expected = @{ format = "yyyy-MM-dd"; regex = "\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])" }
            $expectedFound = $result | Where-Object { $_.format -eq $expected.format -and $_.regex -eq $expected.regex }
            $expectedFound | Should -Not -BeNullOrEmpty

            $expected = @{ format = "HH:mm:ss"; regex = "([01]?\d|2[0-3]):[0-5]\d:[0-5]\d" }
            $expectedFound = $result | Where-Object { $_.format -eq $expected.format -and $_.regex -eq $expected.regex }
            $expectedFound | Should -Not -BeNullOrEmpty

            $expected = @{ format = "yyyy-MM-ddTHH:mm:ss"; regex = "\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])T([01]?\d|2[0-3]):[0-5]\d:[0-5]\d" }
            $expectedFound = $result | Where-Object { $_.format -eq $expected.format -and $_.regex -eq $expected.regex }
            $expectedFound | Should -Not -BeNullOrEmpty
        }
    }
}