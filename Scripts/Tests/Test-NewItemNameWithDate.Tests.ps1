# Tests/New-ItemNameWithDate.Tests.ps1
# Basic validation for New-ItemNameWithDate using Pester

#$here = Split-Path -Parent $MyInvocation.MyCommand.Path

                                                                                                                                                                                                                                                                                          #===============================================================================================                                                                                                                                   
Describe "New-ItemNameWithDate" {

    $script:cases = @()

    BeforeAll {
        . "$env:PowerShellScripts\DateTimeUtils\DateTimeUtils.ps1"
        . "$env:PowerShellScripts\OutLookUtils\OutlookLogic.ps1"


        $script:cases = @(
            @{ base = "Reports 2021";           date = [datetime]"2025-01-01";  expected = "Reports 2025" },
            @{ base = "Stuff (2020)";           date = [datetime]"2024-07-01";  expected = "Stuff 2024" },
            @{ base = "Logs 12-31-2022";        date = [datetime]"2023-03-15";  expected = "Logs 2023" },
            @{ base = "Notes 2022-11-05";       date = [datetime]"2026-01-01";  expected = "Notes 2026" },
            @{ base = "Summary 2023-12-31";     date = [datetime]"2024-01-01";  expected = "Summary 2024" },
            @{ base = "Budget 06-2023";         date = [datetime]"2024-06-01";  expected = "Budget 2024" },
            @{ base = "Budget 06_2023";         date = [datetime]"2024-06-01";  expected = "Budget 2024" },
            @{ base = "Invoices";               date = [datetime]"2027-01-01";  expected = "Invoices 2027" },
            @{ base = "Monthly-Review (2019)";  date = [datetime]"2025-01-01";  expected = "Monthly-Review 2025" },
            @{ base = "NoDateSuffix";           date = [datetime]"2022-02-02";  expected = "NoDateSuffix 2022" }
        )
    }

    It "Processes all tests case" {
        foreach ($case in $script:cases) {
            #It "Transforms '$($case.base)' with date $($case.date) => '$($case.expected)'" {
            #$dt = [datetime]::ParseExact($case.date.ToString(), "yyyy-MM-dd", $null)
            $result = (New-ItemNameWithDate -baseName $case.base -theDateTime $case.date) # $dt
            #$result = New-ItemNameWithDate -baseName $case.base -theDateTime ([datetime]$case.date)
            $result | Should -BeExactly $case.expected
        }
    }
}
                                   
#===============================================================================================                                                                                                                                   
# Simple validation test for New-ItemNameWithDate
Describe "New-ItemNameWithDate" {
    
    BeforeAll {
        . "$env:PowerShellScripts\DateTimeUtils\DateTimeUtils.ps1"
        . "$env:PowerShellScripts\OutLookUtils\OutlookLogic.ps1"
        . "$env:PowerShellScripts\DateTimeUtils\DateTimeUtils.ps1"      

        $script:testDate = [datetime]"2023-04-15"
    }

    It "Appends year to a simple name" {
        New-ItemNameWithDate -baseName "Clients" -theDateTime $script:testDate | Should -Be "Clients 2023"
    }

    It "Replaces trailing year in form 'Name 2021'" {
        New-ItemNameWithDate -baseName "Clients 2021" -theDateTime $script:testDate | Should -Be "Clients 2023"
    }

    It "Handles names with (year)" {
        New-ItemNameWithDate -baseName "Archive (2020)" -theDateTime $script:testDate | Should -Be "Archive 2023"
    }

    It "Removes trailing MM-YYYY pattern" {
        New-ItemNameWithDate -baseName "Budget 03-2022" -theDateTime $script:testDate | Should -Be "Budget 2023"
    }

    It "Handles MM_DD_YYYY with spaces" {
        New-ItemNameWithDate -baseName "Report 12-31-2021" -theDateTime $script:testDate | Should -Be "Report 2023"
    }

    It "Leaves names with no date unchanged except appending year" {
        New-ItemNameWithDate -baseName "Invoices" -theDateTime $script:testDate | Should -Be "Invoices 2023"
    }

    It "Removes YYYY-MM-DD date format" {
        New-ItemNameWithDate -baseName "Update 2021-09-01" -theDateTime $script:testDate | Should -Be "Update 2023"
    }

    It "Handles multiple date formats robustly" {
        $names = @(
            "Clients 2022",
            "Clients (2022)",
            "Clients 03-2022",
            "Clients 2022-03-01",
            "Clients 03_2022"
        )
        foreach ($name in $names) {
            New-ItemNameWithDate -baseName $name -theDateTime $testDate | Should -Be "Clients 2023"
        }
    }
}
