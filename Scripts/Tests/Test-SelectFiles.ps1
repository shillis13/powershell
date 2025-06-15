# Test_SelectFiles.ps1
$scriptUnderTest = "$env:PowerShellScripts\\FileUtils\\Select-Files.ps1"

# Define a Directory object 

# Define the test directory and file structure
$TestDir = "$env:PowerShellDir\\Temp"
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

# Function to run a test case
function Start-TestCase {
    param (
        [string]$Description,
        [string]$Command,
        [array]$ExpectedResults
    )

    Write-Host "Running Test Case: $Description"
 
    Write-Host "Invoking: `"$Command`""
    $ActualResults = Invoke-Expression $Command

    $Comparison = Compare-Object -ReferenceObject $ExpectedResults -DifferenceObject $ActualResults

    if ($Comparison) {
        Write-Host "FAILED: Test Case: $Description"
        Write-Host "Expected Results:"
        $ExpectedResults | ForEach-Object { Write-Host $_ }
        Write-Host "Actual Results:"
        $ActualResults | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "PASSED: Test Case: $Description"
    }
    Write-Host "-----------------------------------"
}

# Test cases
$testCases = @(
    @{
        Description = "Select all .txt files in the main directory";
        Command = "$scriptUnderTest -Dir `"$TestDir`" -Ext '.txt' | Select-Object -ExpandProperty FullName";
        ExpectedResults = @(
            "$TestDir\file1.txt",
            "$TestDir\file2.txt",
            "$TestDir\file5.txt",
            "$TestDir\report1.txt",
            "$TestDir\report2.txt"
        )
    },
    @{
        Description = "Select files containing 'report' in the name";
        Command = "$scriptUnderTest -Dir `"$TestDir`" -SubStr 'report' | Select-Object -ExpandProperty FullName";
        ExpectedResults = @(
            "$TestDir\report1.txt",
            "$TestDir\report2.txt"
        )
    },
    @{
        Description = "Select files created after 2022-05-01";
        Command = "$scriptUnderTest -Dir `"$TestDir`" -FilterByDate -gt '2022-05-01' | Select-Object -ExpandProperty FullName";
        ExpectedResults = @(
            "$TestDir\report1.txt",
            "$TestDir\report2.txt"
        )
    },
    @{
        Description = "Select the first 2 files sorted by name";
        Command = "$scriptUnderTest -Dir `"$TestDir`" -OrderBy Name -Order ASC -FirstN 2 | Select-Object -ExpandProperty FullName";
        ExpectedResults = @(
            "$TestDir\file1.txt",
            "$TestDir\file2.txt"
        )
    },
    @{
        Description = "Select all files in subdirectories";
        Command = "$scriptUnderTest -Dir `"$TestDir`" -SubDirs | Select-Object -ExpandProperty FullName";
        ExpectedResults = @(
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
    }
)

# Run all test cases
foreach ($testCase in $testCases) {
    Start-TestCase -Description $testCase.Description -Command $testCase.Command -ExpectedResults $testCase.ExpectedResults
}

# Cleanup test directory after tests
Remove-Item -Path $TestDir -Recurse -Force