# PowerShell JSON Packager - Testing Guide

This document provides comprehensive guidance for testing the PowerShell JSON Packager system using the included Pester test suite.

## Test Suite Overview

The test suite consists of multiple specialized test files that cover all aspects of the packaging system:

### Core Test Files

1. **TestUtilities.ps1** - Helper functions for creating test environments
2. **DependencyAnalysis.Tests.ps1** - Tests for PowerShell script dependency discovery
3. **PackagerSystem.Tests.ps1** - Tests for the main packaging functionality  
4. **JsonValidation.Tests.ps1** - Tests for JSON schema validation
5. **Integration.Tests.ps1** - End-to-end integration tests
6. **Compare-ToJsonSchema.ps1** - JSON schema validation utility
7. **Run-AllTests.ps1** - Comprehensive test runner

### Configuration Files

- **test-configurations.json** - Sample package configurations for testing
- **json_packager_schema.json** - JSON schema for package validation

## Prerequisites

### Required Software

- **PowerShell 5.1 or later** - Core runtime
- **Pester 5.0+** - Testing framework
- **Git** (optional) - For cloning and version control

### Installation

```powershell
# Install Pester (if not already installed)
Install-Module -Name Pester -Force -SkipPublisherCheck

# Verify installation
Get-Module -Name Pester -ListAvailable
```

### Required Files

Ensure all these files are in the same directory:

```
├── json_packager_system.ps1       # Main packager system
├── json_packager_schema.json      # JSON schema
├── TestUtilities.ps1              # Test helper functions
├── DependencyAnalysis.Tests.ps1   # Dependency tests
├── PackagerSystem.Tests.ps1       # Main system tests
├── JsonValidation.Tests.ps1       # Validation tests
├── Integration.Tests.ps1          # Integration tests
├── Compare-ToJsonSchema.ps1       # Schema validator
├── Run-AllTests.ps1               # Test runner
├── test-configurations.json       # Test configs
└── README-Testing.md              # This file
```

## Running Tests

### Quick Start

Run all tests with default settings:

```powershell
.\Run-AllTests.ps1
```

### Test Suite Selection

Run specific test suites:

```powershell
# Run only dependency analysis tests
.\Run-AllTests.ps1 -TestSuites @("DependencyAnalysis")

# Run core functionality tests
.\Run-AllTests.ps1 -TestSuites @("DependencyAnalysis", "PackagerSystem")

# Run integration tests only
.\Run-AllTests.ps1 -TestSuites @("Integration")
```

### Output Control

Control test output verbosity:

```powershell
# Quiet output (minimal)
.\Run-AllTests.ps1 -OutputLevel Quiet

# Detailed output (verbose)
.\Run-AllTests.ps1 -OutputLevel Detailed

# Normal output (default)
.\Run-AllTests.ps1 -OutputLevel Normal
```

### Report Generation

Generate detailed test reports:

```powershell
# Generate reports in default location (.\TestResults)
.\Run-AllTests.ps1 -GenerateReport

# Generate reports in custom location
.\Run-AllTests.ps1 -GenerateReport -OutputPath "C:\TestReports"
```

### Advanced Options

```powershell
# Stop on first failure
.\Run-AllTests.ps1 -StopOnFailure

# Preview what would be executed
.\Run-AllTests.ps1 -WhatIf

# Show test coverage (if supported)
.\Run-AllTests.ps1 -ShowCoverage
```

## Individual Test Files

### Running Single Test Files

You can run individual test files directly with Pester:

```powershell
# Run dependency analysis tests
Invoke-Pester .\DependencyAnalysis.Tests.ps1

# Run packager system tests
Invoke-Pester .\PackagerSystem.Tests.ps1

# Run with specific configuration
$config = New-PesterConfiguration
$config.Run.Path = ".\Integration.Tests.ps1"
$config.Output.Verbosity = "Detailed"
Invoke-Pester -Configuration $config
```

### Test File Descriptions

#### DependencyAnalysis.Tests.ps1

Tests the PowerShell script dependency discovery functionality:

- **Find-ScriptDependencies** - Core dependency analysis
- **Resolve-ScriptPath** - Path resolution logic
- **Circular dependencies** - Handling of circular references
- **Unresolved dependencies** - Missing file detection
- **Variable paths** - Dynamic path handling

```powershell
# Run only dependency analysis tests
Invoke-Pester .\DependencyAnalysis.Tests.ps1 -Tag "Dependency"
```

#### PackagerSystem.Tests.ps1

Tests the main packaging system functionality:

- **Configuration loading** - JSON config parsing
- **Directory creation** - Package structure setup
- **File operations** - Copying, filtering, flattening
- **Post-package actions** - File creation, script execution
- **Path rewriting** - Dot-source path updates

```powershell
# Run packaging system tests
Invoke-Pester .\PackagerSystem.Tests.ps1 -Tag "Core"
```

#### JsonValidation.Tests.ps1

Tests JSON schema validation:

- **Schema compliance** - Configuration validation
- **Error detection** - Invalid config handling
- **Built-in validation** - PowerShell native JSON support
- **Custom validation** - Extended validation rules

```powershell
# Run validation tests
Invoke-Pester .\JsonValidation.Tests.ps1 -Tag "Validation"
```

#### Integration.Tests.ps1

Tests complete end-to-end workflows:

- **SharePoint project simulation** - Real-world scenario
- **Auto-package mode** - Dependency analysis + packaging
- **Performance testing** - Large project handling
- **Error scenarios** - Edge case handling

```powershell
# Run integration tests (takes longer)
Invoke-Pester .\Integration.Tests.ps1 -Tag "Integration"
```

## Test Configuration

### Using Test Configurations

The `test-configurations.json` file contains predefined package configurations for testing:

```powershell
# Load test configurations
$testConfigs = Get-Content .\test-configurations.json | ConvertFrom-Json

# Use a specific test configuration
$config = $testConfigs.sharepoint_test_config
$config | ConvertTo-Json -Depth 10 | Out-File test-package.json

# Test the configuration
.\json_packager_system.ps1 -ConfigPath test-package.json -OutputPath .\test-output -Mode Package
```

### Creating Custom Test Configurations

Create your own test configurations:

```powershell
# Create a minimal test config
$customConfig = @{
    package = @{
        name = "My Test Package"
        version = "1.0.0"
    }
    files = @(
        @{
            name = "scripts"
            source = "*.ps1"
            destination = "scripts"
        }
    )
}

$customConfig | ConvertTo-Json -Depth 10 | Out-File my-test-config.json
```

## Understanding Test Results

### Test Output Interpretation

```
Running: Dependency Analysis Tests
Description: Tests for PowerShell script dependency discovery and analysis
Estimated duration: 2-3 minutes

Tests completed in 00:02:15

PASSED : Dependency Analysis Tests (135.2s)
         Tests: 24/24 passed

PASSED : Packager System Tests (89.7s)  
         Tests: 18/18 passed

FAILED : JSON Validation Tests (45.3s)
         Tests: 7/9 passed
         Failed tests:
           - Should validate complex package configuration
           - Should detect pattern violations

ALL TESTS PASSED
```

### Test Result Files

When using `-GenerateReport`, several files are created:

```
TestResults/
├── TestReport.md                    # Comprehensive markdown report
├── DependencyAnalysis-TestResults.xml  # JUnit XML for CI/CD
├── PackagerSystem-TestResults.xml     # JUnit XML for CI/CD
├── JsonValidation-TestResults.xml     # JUnit XML for CI/CD
└── Integration-TestResults.xml        # JUnit XML for CI/CD
```

## Testing Workflows

### Development Workflow

1. **Unit Tests First** - Run individual test files during development
2. **Integration Testing** - Run integration tests for end-to-end validation
3. **Full Suite** - Run complete test suite before commits

```powershell
# Development cycle
.\Run-AllTests.ps1 -TestSuites @("DependencyAnalysis", "PackagerSystem") -OutputLevel Detailed

# Pre-commit validation
.\Run-AllTests.ps1 -GenerateReport -StopOnFailure
```

### CI/CD Integration

For automated testing in CI/CD pipelines:

```powershell
# CI/CD test execution
.\Run-AllTests.ps1 -OutputLevel Quiet -GenerateReport -OutputPath $env:BUILD_ARTIFACTSTAGINGDIRECTORY

# Check exit code
if ($LASTEXITCODE -ne 0) {
    Write-Error "Tests failed"
    exit 1
}
```

### Performance Testing

Run performance-focused tests:

```powershell
# Focus on performance scenarios
Invoke-Pester .\Integration.Tests.ps1 -Tag "Performance"

# Large project simulation
Invoke-Pester .\Integration.Tests.ps1 -TestName "*Large project simulation*"
```

## Troubleshooting

### Common Issues

#### Pester Version Conflicts

```powershell
# Check Pester version
Get-Module -Name Pester -ListAvailable

# Remove old versions
Get-Module -Name Pester -ListAvailable | Uninstall-Module -Force

# Install latest version
Install-Module -Name Pester -Force -SkipPublisherCheck
```

#### Missing Dependencies

```powershell
# Verify all required files exist
$requiredFiles = @(
    "json_packager_system.ps1",
    "TestUtilities.ps1", 
    "DependencyAnalysis.Tests.ps1",
    "PackagerSystem.Tests.ps1"
)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        Write-Warning "Missing required file: $file"
    }
}
```

#### Test Environment Issues

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Verify execution policy
Get-ExecutionPolicy

# Set execution policy if needed
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Test Debugging

#### Verbose Output

```powershell
# Run with maximum verbosity
$config = New-PesterConfiguration
$config.Run.Path = ".\DependencyAnalysis.Tests.ps1"
$config.Output.Verbosity = "Detailed"
$config.Should.ErrorAction = "Continue"
Invoke-Pester -Configuration $config
```

#### Isolated Test Execution

```powershell
# Run a single test
Invoke-Pester .\DependencyAnalysis.Tests.ps1 -TestName "*Should discover all files*"

# Run tests with specific tags
Invoke-Pester .\Integration.Tests.ps1 -Tag "SharePoint"
```

#### Manual Test Environment Setup

```powershell
# Create test environment manually
. .\TestUtilities.ps1
$testDir = Get-TestTempDirectory -Prefix "ManualTest"
$project = New-TestProjectStructure -BasePath $testDir -ProjectName "DebugTest"

# Examine the created structure
Get-ChildItem -Path $project.ProjectPath -Recurse
```

## Test Coverage

### What's Tested

- ✅ **Dependency Analysis** - Script relationship discovery
- ✅ **Path Resolution** - Relative and absolute path handling
- ✅ **Configuration Parsing** - JSON config loading and validation
- ✅ **File Operations** - Copying, filtering, structure preservation
- ✅ **Schema Validation** - JSON schema compliance checking
- ✅ **Error Handling** - Graceful failure and recovery
- ✅ **Performance** - Large project handling
- ✅ **Integration** - End-to-end workflow testing

### What's Not Tested

- ❌ **Actual Selenium Operations** - Mocked in tests
- ❌ **Network Operations** - File downloads simulated
- ❌ **PowerShell Module Installation** - Assumed to be present
- ❌ **Cross-Platform Compatibility** - Windows-focused

## Contributing Tests

### Adding New Tests

1. **Follow Naming Conventions** - `Feature.Tests.ps1`
2. **Use Test Utilities** - Leverage existing helper functions
3. **Clean Up Resources** - Use `BeforeAll`/`AfterAll` properly
4. **Document Test Purpose** - Clear descriptions and contexts

### Test Structure Template

```powershell
#Requires -Modules Pester

BeforeAll {
    # Import required modules and utilities
    . $PSScriptRoot/TestUtilities.ps1
    
    # Setup test environment
    $Global:TestBaseDir = Get-TestTempDirectory -Prefix "MyTest"
}

AfterAll {
    # Clean up test environment
    Remove-TestDirectory -Path $Global:TestBaseDir
}

Describe "My Feature" {
    Context "Specific scenario" {
        BeforeAll {
            # Setup for this context
        }
        
        It "Should perform expected behavior" {
            # Test implementation
            $result = Invoke-MyFeature
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
```

## Best Practices

### Test Organization

- **Group related tests** in the same context
- **Use descriptive names** for tests and contexts
- **Setup and teardown** properly to avoid test pollution
- **Mock external dependencies** to ensure test isolation

### Performance Considerations

- **Use temporary directories** for test artifacts
- **Clean up after tests** to prevent disk space issues
- **Limit test scope** to essential functionality
- **Parallel execution** for independent test suites

### Maintenance

- **Update tests** when adding new features
- **Refactor tests** when code structure changes
- **Document test intent** for future maintainers
- **Version test configurations** alongside code changes

## Resources

### Documentation

- [Pester Documentation](https://pester.dev/docs/quick-start)
- [PowerShell Testing Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/writing-portable-modules)

### Example Commands

```powershell
# Complete test suite with reporting
.\Run-AllTests.ps1 -GenerateReport -OutputPath .\Reports

# Quick validation during development  
.\Run-AllTests.ps1 -TestSuites @("DependencyAnalysis") -OutputLevel Quiet

# Performance testing
.\Run-AllTests.ps1 -TestSuites @("Integration") -OutputLevel Detailed

# Schema validation testing
Invoke-Pester .\JsonValidation.Tests.ps1 -Tag "Schema"
```

This testing guide provides comprehensive coverage for validating the PowerShell JSON Packager system functionality, from individual components to complete integration scenarios.