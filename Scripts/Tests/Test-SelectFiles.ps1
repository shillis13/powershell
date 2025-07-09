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
    
    # Test_SelectFiles.Tests.ps1
    $Script:scriptUnderTest = "$Script:PSRoot\Scripts\FileUtils\Select-Files.ps1"
}

#endregion
# ===========================================================================================

Describe "Select-Files Tests" {

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
    
        # Test_SelectFiles.Tests.ps1
        $Script:scriptUnderTest = "$Script:PSRoot\Scripts\FileUtils\Select-Files.ps1"
        . "$Script:scriptUnderTest"

        # Define the test directory and file structure
        $TestDir = "$Script:PSRoot\Temp"
        $SubDir1 = "$TestDir\SubDir1"
        $SubDir2 = "$TestDir\SubDir2"

        # Create test directories
        New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
        New-Item -ItemType Directory -Path $SubDir1 -Force | Out-Null
        New-Item -ItemType Directory -Path $SubDir2 -Force | Out-Null

        # Create test files
        $files = @(
            @{ Name = "file1.txt"; Content = "Test file 1"; CreationTime = "2022-01-01" },
            @{ Name = "file2.txt"; Content = "Test file 2"; CreationTime = "2022-02-01" },
            @{ Name = "file3.csv"; Content = "Test file 3"; CreationTime = "2022-03-01" },
            @{ Name = "file4.csv"; Content = "Test file 4"; CreationTime = "2022-04-01" },
            @{ Name = "file5.txt"; Content = "Test file 5"; CreationTime = "2022-05-01" },
            @{ Name = "report1.txt"; Content = "Report file 1"; CreationTime = "2022-06-01" },
            @{ Name = "report2.txt"; Content = "Report file 2"; CreationTime = "2022-07-01" }
        )

        foreach ($file in $files) {
            $filePath = Join-Path -Path $TestDir -ChildPath $file.Name
            New-Item -ItemType File -Path $filePath -Force | Out-Null
            Set-Content -Path $filePath -Value $file.Content
            $(Get-Item -Path $filePath).CreationTime = [datetime]$file.CreationTime
        }

        # Create test files in subdirectories
        $subFiles = @(
            @{ Name = "subfile1.txt"; Content = "Sub file 1"; CreationTime = "2022-08-01"; Dir = $SubDir1 },
            @{ Name = "subfile2.txt"; Content = "Sub file 2"; CreationTime = "2022-09-01"; Dir = $SubDir1 },
            @{ Name = "subfile3.csv"; Content = "Sub file 3"; CreationTime = "2022-10-01"; Dir = $SubDir2 },
            @{ Name = "subfile4.csv"; Content = "Sub file 4"; CreationTime = "2022-11-01"; Dir = $SubDir2 }
        )

        foreach ($subFile in $subFiles) {
            $filePath = Join-Path -Path $subFile.Dir -ChildPath $subFile.Name
            New-Item -ItemType File -Path $filePath -Force | Out-Null
            Set-Content -Path $filePath -Value $subFile.Content
            $(Get-Item -Path $filePath).CreationTime = [datetime]$subFile.CreationTime
        }
    }

    Context "Select all .txt files in the main directory" {
        It "Should select all .txt files in the main directory" {
            $ActualResults = Select-Files -Dir $TestDir -Ext ".txt" | Select-Object -ExpandProperty FullName
            $ExpectedResults = @(
                "$TestDir\file1.txt",
                "$TestDir\file2.txt",
                "$TestDir\file5.txt",
                "$TestDir\report1.txt",
                "$TestDir\report2.txt"
            )
            $ActualResults | Should -BeExactly $ExpectedResults
        }
    }

    Context "Select files containing 'report' in the name" {
        It "Should select files containing 'report' in the name" {
            $ActualResults = Select-Files -Dir $TestDir -SubStr "report" | Select-Object -ExpandProperty FullName
            $ExpectedResults = @(
                "$TestDir\report1.txt",
                "$TestDir\report2.txt"
            )
            $ActualResults | Should -BeExactly $ExpectedResults
        }
    }

    Context "Select files created after 2022-05-01" {
        It "Should select files created after 2022-05-01" {
            $ActualResults = Select-Files -Dir $TestDir -FilterByDate { param($date) $date -gt '2022-05-01' } | Select-Object -ExpandProperty FullName
            $ExpectedResults = @(
                "$TestDir\report1.txt",
                "$TestDir\report2.txt"
            )
            $ActualResults | Should -BeExactly $ExpectedResults
        }
    }

    Context "Select the first 2 files sorted by name" {
        It "Should select the first 2 files sorted by name" {
            $ActualResults = Select-Files -Dir $TestDir -OrderBy Name -Order ASC -FirstN 2 | Select-Object -ExpandProperty FullName
            $ExpectedResults = @(
                "$TestDir\file1.txt",
                "$TestDir\file2.txt"
            )
            $ActualResults | Should -BeExactly $ExpectedResults
        }
    }

    Context "Select all files in subdirectories" {
        It "Should select all files in subdirectories" {
            $ActualResults = Select-Files -Dir $TestDir -Recurse | Select-Object -ExpandProperty FullName
            $ExpectedResults = @(
                "$TestDir\file1.txt",
                "$TestDir\file2.txt",
                "$TestDir\file3.csv",
                "$TestDir\file4.csv",
                "$TestDir\file5.txt",
                "$TestDir\report1.txt",
                "$TestDir\report2.txt",
                "$SubDir1\subfile1.txt",
                "$SubDir1\subfile2.txt",
                "$SubDir2\subfile3.csv",
                "$SubDir2\subfile4.csv"
            )
            $ActualResults | Should -BeExactly $ExpectedResults
        }
    }

    AfterAll {
        # Cleanup test directory after tests
        Remove-Item -Path $TestDir -Recurse -Force
    }
}