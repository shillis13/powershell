#========================================
# Run-AllTests.ps1
# Comprehensive test runner for the PowerShell JSON Packager system
#========================================

#Requires -Modules Pester

[CmdletBinding()]
param(
    [string[]]$TestSuites = @("All"),
    
    [ValidateSet("Normal", "Detailed", "Quiet")]
    [string]$OutputLevel = "Normal",
    
    [string]$OutputPath = ".\TestResults",
    
    [switch]$GenerateReport,
    
    [switch]$StopOnFailure,
    
    [switch]$ShowCoverage,
    
    [switch]$WhatIf,
    
    [int]$MaxParallelJobs = 1
)

#========================================
#region Test Configuration
#========================================

$TestConfig = @{
    TestSuites = @{
        "DependencyAnalysis" = @{
            Name = "Dependency Analysis Tests"
            Path = "DependencyAnalysis.Tests.ps1"
            Description = "Tests for PowerShell script dependency discovery and analysis"
            Tags = @("Dependency", "Analysis", "Core")
            EstimatedDuration = "2-3 minutes"
        }
        "PackagerSystem" = @{
            Name = "Packager System Tests"
            Path = "PackagerSystem.Tests.ps1"
            Description = "Tests for the main packaging system functionality"
            Tags = @("Packaging", "Core", "FileOps")
            EstimatedDuration = "3-4 minutes"
        }
        "JsonValidation" = @{
            Name = "JSON Schema Validation Tests"
            Path = "JsonValidation.Tests.ps1"
            Description = "Tests for JSON configuration validation"
            Tags = @("Validation", "JSON", "Schema")
            EstimatedDuration = "1-2 minutes"
        }
        "Integration" = @{
            Name = "Integration Tests"
            Path = "Integration.Tests.ps1"
            Description = "End-to-end integration and workflow tests"
            Tags = @("Integration", "E2E", "Workflow")
            EstimatedDuration = "5-8 minutes"
        }
    }
    
    TestOrder = @("DependencyAnalysis", "PackagerSystem", "JsonValidation", "Integration")
    
    DefaultIncludes = @("DependencyAnalysis", "PackagerSystem", "JsonValidation")
    
    PerformanceThresholds = @{
        DependencyAnalysis = 180    # 3 minutes
        PackagerSystem = 240        # 4 minutes  
        JsonValidation = 120        # 2 minutes
        Integration = 480           # 8 minutes
    }
}

#========================================
#region Helper Functions
#========================================

function Write-TestHeader {
    param([string]$Message, [string]$Level = "Info")
    
    $colors = @{
        "Info" = "Cyan"
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error" = "Red"
    }
    
    $separator = "=" * 60
    Write-Host $separator -ForegroundColor $colors[$Level]
    Write-Host $Message -ForegroundColor $colors[$Level]
    Write-Host $separator -ForegroundColor $colors[$Level]
}

function Test-Prerequisites {
    $issues = @()
    
    # Check for Pester
    $pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $pesterModule) {
        $issues += "Pester module not found. Install with: Install-Module -Name Pester -Force"
    } elseif ($pesterModule.Version -lt [version]"5.0.0") {
        $issues += "Pester version $($pesterModule.Version) found. Version 5.0.0 or higher recommended."
    }
    
    # Check for required files
    $requiredFiles = @(
        "json_packager_system.ps1",
        "TestUtilities.ps1",
        "DependencyAnalysis.Tests.ps1",
        "PackagerSystem.Tests.ps1"
    )
    
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $PSScriptRoot $file
        if (-not (Test-Path $filePath)) {
            $issues += "Required file not found: $file"
        }
    }
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion -lt [version]"5.1") {
        $issues += "PowerShell $($PSVersionTable.PSVersion) detected. Version 5.1 or higher required."
    }
    
    return $issues
}

function Get-TestSuitesToRun {
    param([string[]]$RequestedSuites)
    
    if ($RequestedSuites -contains "All") {
        return $TestConfig.TestOrder
    }
    
    $validSuites = @()
    foreach ($suite in $RequestedSuites) {
        if ($TestConfig.TestSuites.ContainsKey($suite)) {
            $validSuites += $suite
        } else {
            Write-Warning "Unknown test suite: $suite"
            Write-Host "Available suites: $($TestConfig.TestSuites.Keys -join ', ')" -ForegroundColor Yellow
        }
    }
    
    return $validSuites
}

function Invoke-TestSuite {
    param(
        [string]$SuiteName,
        [hashtable]$SuiteConfig,
        [string]$OutputPath,
        [bool]$GenerateReport,
        [string]$OutputLevel
    )
    
    $testPath = Join-Path $PSScriptRoot $SuiteConfig.Path
    if (-not (Test-Path $testPath)) {
        Write-Warning "Test file not found: $($SuiteConfig.Path)"
        return $null
    }
    
    Write-Host "`nRunning: $($SuiteConfig.Name)" -ForegroundColor Cyan
    Write-Host "Description: $($SuiteConfig.Description)" -ForegroundColor Gray
    Write-Host "Estimated duration: $($SuiteConfig.EstimatedDuration)" -ForegroundColor Gray
    
    $pesterConfig = New-PesterConfiguration
    $pesterConfig.Run.Path = $testPath
    $pesterConfig.Output.Verbosity = switch ($OutputLevel) {
        "Quiet" { "Minimal" }
        "Detailed" { "Detailed" }
        default { "Normal" }
    }
    
    if ($GenerateReport) {
        $reportPath = Join-Path $OutputPath "$SuiteName-TestResults.xml"
        $pesterConfig.TestResult.Enabled = $true
        $pesterConfig.TestResult.OutputPath = $reportPath
        $pesterConfig.TestResult.OutputFormat = "JUnitXml"
    }
    
    $startTime = Get-Date
    $result = Invoke-Pester -Configuration $pesterConfig
    $endTime = Get-Date
    
    $duration = $endTime - $startTime
    $threshold = $TestConfig.PerformanceThresholds[$SuiteName]
    
    if ($threshold -and $duration.TotalSeconds -gt $threshold) {
        Write-Warning "Test suite '$SuiteName' took $([math]::Round($duration.TotalSeconds, 1))s (threshold: ${threshold}s)"
    }
    
    return @{
        SuiteName = $SuiteName
        Result = $result
        Duration = $duration
        StartTime = $startTime
        EndTime = $endTime
        Passed = $result.FailedCount -eq 0
    }
}

function New-TestReport {
    param(
        [array]$TestResults,
        [string]$OutputPath
    )
    
    $totalTests = ($TestResults | ForEach-Object { $_.Result.TotalCount }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    $totalPassed = ($TestResults | ForEach-Object { $_.Result.PassedCount }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    $totalFailed = ($TestResults | ForEach-Object { $_.Result.FailedCount }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    $totalSkipped = ($TestResults | ForEach-Object { $_.Result.SkippedCount }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    $totalDuration = ($TestResults | ForEach-Object { $_.Duration.TotalSeconds }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    
    $report = @"
# PowerShell JSON Packager Test Report

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Total Duration:** $([math]::Round($totalDuration, 1)) seconds

## Summary

| Metric | Count |
|--------|-------|
| Total Tests | $totalTests |
| Passed | $totalPassed |
| Failed | $totalFailed |
| Skipped | $totalSkipped |
| Success Rate | $([math]::Round(($totalPassed / $totalTests) * 100, 1))% |

## Test Suite Results

"@
    
    foreach ($testResult in $TestResults) {
        $suite = $testResult.SuiteName
        $result = $testResult.Result
        $status = if ($testResult.Passed) { "✅ PASSED" } else { "❌ FAILED" }
        $duration = [math]::Round($testResult.Duration.TotalSeconds, 1)
        
        $report += @"

### $($TestConfig.TestSuites[$suite].Name) $status

- **Duration:** ${duration}s
- **Tests:** $($result.TotalCount)
- **Passed:** $($result.PassedCount)
- **Failed:** $($result.FailedCount)
- **Skipped:** $($result.SkippedCount)

"@
        
        if ($result.FailedCount -gt 0) {
            $report += "**Failed Tests:**`n"
            foreach ($failedTest in $result.Failed) {
                $report += "- $($failedTest.Name): $($failedTest.ErrorRecord.Exception.Message)`n"
            }
        }
    }
    
    $report += @"

## Environment Information

- **PowerShell Version:** $($PSVersionTable.PSVersion)
- **OS:** $($PSVersionTable.OS)
- **Machine:** $env:COMPUTERNAME
- **User:** $env:USERNAME
- **Working Directory:** $PWD

## Test Configuration

"@
    
    foreach ($suite in $TestConfig.TestSuites.Keys) {
        $config = $TestConfig.TestSuites[$suite]
        $report += "- **$($config.Name):** $($config.Description)`n"
    }
    
    $reportPath = Join-Path $OutputPath "TestReport.md"
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    
    return $reportPath
}

function Show-TestSummary {
    param([array]$TestResults)
    
    Write-TestHeader "Test Execution Summary" "Info"
    
    $totalDuration = ($TestResults | ForEach-Object { $_.Duration.TotalSeconds }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    
    Write-Host "Total execution time: $([math]::Round($totalDuration, 1)) seconds`n" -ForegroundColor Cyan
    
    foreach ($testResult in $TestResults) {
        $suite = $testResult.SuiteName
        $result = $testResult.Result
        $color = if ($testResult.Passed) { "Green" } else { "Red" }
        $status = if ($testResult.Passed) { "PASSED" } else { "FAILED" }
        $duration = [math]::Round($testResult.Duration.TotalSeconds, 1)
        
        Write-Host "$status : $($TestConfig.TestSuites[$suite].Name) (${duration}s)" -ForegroundColor $color
        Write-Host "         Tests: $($result.PassedCount)/$($result.TotalCount) passed" -ForegroundColor Gray
        
        if ($result.FailedCount -gt 0) {
            Write-Host "         Failed tests:" -ForegroundColor Red
            foreach ($failedTest in $result.Failed) {
                Write-Host "           - $($failedTest.Name)" -ForegroundColor Red
            }
        }
        Write-Host ""
    }
    
    $overallSuccess = ($TestResults | Where-Object { -not $_.Passed }).Count -eq 0
    $overallStatus = if ($overallSuccess) { "ALL TESTS PASSED" } else { "SOME TESTS FAILED" }
    $overallColor = if ($overallSuccess) { "Success" } else { "Error" }
    
    Write-TestHeader $overallStatus $overallColor
    
    return $overallSuccess
}

#========================================
#region Main Execution
#========================================

function main {
    Write-TestHeader "PowerShell JSON Packager Test Suite" "Info"
    
    if ($WhatIf) {
        Write-Host "WhatIf mode - showing what would be executed:" -ForegroundColor Yellow
        $suitesToRun = Get-TestSuitesToRun -RequestedSuites $TestSuites
        
        foreach ($suite in $suitesToRun) {
            $config = $TestConfig.TestSuites[$suite]
            Write-Host "Would run: $($config.Name) ($($config.Path))" -ForegroundColor Yellow
            Write-Host "  Description: $($config.Description)" -ForegroundColor Gray
            Write-Host "  Duration: $($config.EstimatedDuration)" -ForegroundColor Gray
        }
        return
    }
    
    # Check prerequisites
    Write-Host "Checking prerequisites..." -ForegroundColor Cyan
    $issues = Test-Prerequisites
    if ($issues.Count -gt 0) {
        Write-TestHeader "Prerequisites Check Failed" "Error"
        foreach ($issue in $issues) {
            Write-Host "❌ $issue" -ForegroundColor Red
        }
        return $false
    }
    Write-Host "✅ All prerequisites met" -ForegroundColor Green
    
    # Create output directory
    if ($GenerateReport -or $OutputPath -ne ".\TestResults") {
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }
    }
    
    # Determine test suites to run
    $suitesToRun = Get-TestSuitesToRun -RequestedSuites $TestSuites
    if ($suitesToRun.Count -eq 0) {
        Write-Host "No valid test suites specified." -ForegroundColor Red
        return $false
    }
    
    Write-Host "`nTest suites to run: $($suitesToRun -join ', ')" -ForegroundColor Cyan
    Write-Host "Output level: $OutputLevel" -ForegroundColor Gray
    if ($GenerateReport) {
        Write-Host "Reports will be saved to: $OutputPath" -ForegroundColor Gray
    }
    
    # Run test suites
    $testResults = @()
    $overallStartTime = Get-Date
    
    foreach ($suite in $suitesToRun) {
        $suiteConfig = $TestConfig.TestSuites[$suite]
        
        try {
            $result = Invoke-TestSuite -SuiteName $suite -SuiteConfig $suiteConfig -OutputPath $OutputPath -GenerateReport $GenerateReport -OutputLevel $OutputLevel
            if ($result) {
                $testResults += $result
                
                if ($StopOnFailure -and -not $result.Passed) {
                    Write-Host "`nStopping execution due to test failure (StopOnFailure enabled)" -ForegroundColor Red
                    break
                }
            }
        }
        catch {
            Write-Host "Error running test suite '$suite': $($_.Exception.Message)" -ForegroundColor Red
            if ($StopOnFailure) {
                break
            }
        }
    }
    
    $overallEndTime = Get-Date
    $overallDuration = $overallEndTime - $overallStartTime
    
    # Generate comprehensive report
    if ($GenerateReport -and $testResults.Count -gt 0) {
        Write-Host "`nGenerating test report..." -ForegroundColor Cyan
        $reportPath = New-TestReport -TestResults $testResults -OutputPath $OutputPath
        Write-Host "Test report saved to: $reportPath" -ForegroundColor Green
    }
    
    # Show summary
    if ($testResults.Count -gt 0) {
        $overallSuccess = Show-TestSummary -TestResults $testResults
        
        Write-Host "Overall duration: $([math]::Round($overallDuration.TotalMinutes, 1)) minutes" -ForegroundColor Cyan
        
        return $overallSuccess
    } else {
        Write-Host "No tests were executed." -ForegroundColor Yellow
        return $false
    }
}

# Execute main function and set exit code
$success = main
if ($success) {
    exit 0
} else {
    exit 1
}
