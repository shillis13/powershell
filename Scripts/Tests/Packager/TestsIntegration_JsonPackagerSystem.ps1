#Requires -Modules Pester

#========================================
# Integration.Tests.ps1
# End-to-end integration tests for the complete PowerShell packaging workflow
#========================================

BeforeAll {
    # Import the main packager system
    $PackagerPath = Join-Path $PSScriptRoot "json_packager_system.ps1"
    if (Test-Path $PackagerPath) {
        . $PackagerPath
    } else {
        throw "Cannot find json_packager_system.ps1 at: $PackagerPath"
    }
    
    # Import test utilities
    $TestUtilitiesPath = Join-Path $PSScriptRoot "TestUtilities.ps1"
    if (Test-Path $TestUtilitiesPath) {
        . $TestUtilitiesPath
    } else {
        throw "Cannot find TestUtilities.ps1 at: $TestUtilitiesPath"
    }
    
    # Import JSON validator if available
    $ValidatorPath = Join-Path $PSScriptRoot "Compare-ToJsonSchema.ps1"
    if (Test-Path $ValidatorPath) {
        . $ValidatorPath
    }
    
    # Set up test environment
    $Global:TestBaseDir = Get-TestTempDirectory -Prefix "IntegrationTest"
    Write-Host "Integration test directory: $Global:TestBaseDir" -ForegroundColor Green
}

AfterAll {
    # Clean up test environment
    if ($Global:TestBaseDir -and (Test-Path $Global:TestBaseDir)) {
        Remove-TestDirectory -Path $Global:TestBaseDir
    }
}

Describe "Complete End-to-End Packaging Workflow" {
    Context "SharePoint Tools Package Simulation" {
        BeforeAll {
            # Create a realistic SharePoint tools project structure
            $Script:SharePointProject = Join-Path $Global:TestBaseDir "SharePointProject"
            New-Item -Path $Script:SharePointProject -ItemType Directory -Force | Out-Null
            
            # Create main SharePoint script
            $mainSharePointScript = @"
#========================================
# Get-SharePointFile.ps1 - Main SharePoint file downloader
#========================================

# Import required libraries
. `$PSScriptRoot\lib\Config.ps1
. `$PSScriptRoot\lib\Logging.ps1
. `$PSScriptRoot\lib\WebDriver.ps1
. `$PSScriptRoot\utils\FileUtils.ps1

function Get-SharePointFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = `$true)]
        [string]`$Url,
        
        [string]`$DestinationPath = ".\downloads",
        
        [switch]`$Force
    )
    
    Write-Log "Starting SharePoint file download from: `$Url"
    
    `$config = Get-SharePointConfig
    `$driver = Initialize-WebDriver -Config `$config
    
    try {
        `$downloadResult = Start-FileDownload -Driver `$driver -Url `$Url -DestinationPath `$DestinationPath -Force:`$Force
        Write-Log "Download completed: `$(`$downloadResult.FilePath)"
        return `$downloadResult
    }
    finally {
        if (`$driver) {
            Stop-WebDriver -Driver `$driver
        }
    }
}

# Auto-execution logic
if (`$MyInvocation.InvocationName -ne '.') {
    if (`$args.Count -gt 0) {
        Get-SharePointFile -Url `$args[0]
    } else {
        Write-Host "Usage: Get-SharePointFile.ps1 <SharePoint-URL>"
    }
}
"@
            
            # Create library directory and files
            New-Item -Path "$Script:SharePointProject\lib" -ItemType Directory -Force | Out-Null
            
            $configScript = @"
# Config.ps1 - Configuration management for SharePoint tools
. `$PSScriptRoot\helpers\Validation.ps1

function Get-SharePointConfig {
    [CmdletBinding()]
    param()
    
    `$configPath = Join-Path `$PSScriptRoot "..\config\sharepoint-config.json"
    
    if (Test-Path `$configPath) {
        `$config = Get-Content `$configPath | ConvertFrom-Json
        return Confirm-SharePointConfig -Config `$config
    }
    
    return Get-DefaultSharePointConfig
}

function Get-DefaultSharePointConfig {
    return @{
        ChromeDriverPath = ".\drivers\chromedriver.exe"
        DownloadTimeout = 300
        RetryAttempts = 3
        LogLevel = "Info"
    }
}
"@
            
            $loggingScript = @"
# Logging.ps1 - Logging utilities
. `$PSScriptRoot\helpers\ErrorHandling.ps1

`$script:LogFile = `$null

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = `$true)]
        [string]`$Message,
        
        [ValidateSet("Debug", "Info", "Warning", "Error")]
        [string]`$Level = "Info"
    )
    
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    `$logEntry = "[$timestamp] [$Level] `$Message"
    
    Write-Host `$logEntry -ForegroundColor $(switch(`$Level) {
        "Debug" { "Gray" }
        "Info" { "White" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
    })
    
    if (`$script:LogFile) {
        `$logEntry | Out-File -FilePath `$script:LogFile -Append
    }
}

function Set-LogFile {
    [CmdletBinding()]
    param([string]`$Path)
    
    `$script:LogFile = `$Path
    Write-Log "Logging initialized to: `$Path"
}
"@
            
            $webDriverScript = @"
# WebDriver.ps1 - Selenium WebDriver management
. `$PSScriptRoot\helpers\ErrorHandling.ps1

function Initialize-WebDriver {
    [CmdletBinding()]
    param([hashtable]`$Config)
    
    Write-Log "Initializing Chrome WebDriver"
    
    # This would normally initialize Selenium WebDriver
    # For testing purposes, we'll return a mock driver object
    return @{
        Type = "ChromeDriver"
        SessionId = "test-session-123"
        Config = `$Config
        IsInitialized = `$true
    }
}

function Start-FileDownload {
    [CmdletBinding()]
    param(
        [hashtable]`$Driver,
        [string]`$Url,
        [string]`$DestinationPath,
        [switch]`$Force
    )
    
    Write-Log "Starting download from: `$Url"
    
    # Mock download simulation
    `$fileName = "downloaded-file-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    `$filePath = Join-Path `$DestinationPath `$fileName
    
    if (-not (Test-Path `$DestinationPath)) {
        New-Item -Path `$DestinationPath -ItemType Directory -Force | Out-Null
    }
    
    "Mock SharePoint file content from `$Url" | Out-File -FilePath `$filePath
    
    return @{
        Success = `$true
        FilePath = `$filePath
        FileName = `$fileName
        DownloadTime = (Get-Date)
        FileSize = (Get-Item `$filePath).Length
    }
}

function Stop-WebDriver {
    [CmdletBinding()]
    param([hashtable]`$Driver)
    
    Write-Log "Stopping WebDriver session: `$(`$Driver.SessionId)"
    # Cleanup logic would go here
}
"@
            
            # Create helpers directory and files
            New-Item -Path "$Script:SharePointProject\lib\helpers" -ItemType Directory -Force | Out-Null
            
            $validationScript = @"
# Validation.ps1 - Configuration validation
function Confirm-SharePointConfig {
    [CmdletBinding()]
    param([hashtable]`$Config)
    
    if (-not `$Config.ChromeDriverPath) {
        throw "ChromeDriverPath is required in configuration"
    }
    
    if (-not `$Config.DownloadTimeout) {
        `$Config.DownloadTimeout = 300  # Default 5 minutes
    }
    
    return `$Config
}

function Test-SharePointUrl {
    [CmdletBinding()]
    param([string]`$Url)
    
    return `$Url -match "sharepoint\\.com|sharepoint.*\\.(gov|org|net)"
}
"@
            
            $errorHandlingScript = @"
# ErrorHandling.ps1 - Error handling utilities
function Invoke-WithRetry {
    [CmdletBinding()]
    param(
        [scriptblock]`$ScriptBlock,
        [int]`$MaxAttempts = 3,
        [int]`$DelaySeconds = 1
    )
    
    `$attempt = 1
    while (`$attempt -le `$MaxAttempts) {
        try {
            return & `$ScriptBlock
        }
        catch {
            Write-Log "Attempt `$attempt failed: `$(`$_.Exception.Message)" -Level Warning
            
            if (`$attempt -eq `$MaxAttempts) {
                throw
            }
            
            `$attempt++
            Start-Sleep -Seconds `$DelaySeconds
        }
    }
}

function Write-ErrorDetails {
    [CmdletBinding()]
    param([System.Management.Automation.ErrorRecord]`$ErrorRecord)
    
    Write-Log "Error: `$(`$ErrorRecord.Exception.Message)" -Level Error
    Write-Log "Line: `$(`$ErrorRecord.InvocationInfo.ScriptLineNumber)" -Level Error
    Write-Log "Script: `$(`$ErrorRecord.InvocationInfo.ScriptName)" -Level Error
}
"@
            
            # Create utils directory and files
            New-Item -Path "$Script:SharePointProject\utils" -ItemType Directory -Force | Out-Null
            
            $fileUtilsScript = @"
# FileUtils.ps1 - File utility functions
function Test-FileDownloadPath {
    [CmdletBinding()]
    param([string]`$Path)
    
    if (-not (Test-Path `$Path)) {
        New-Item -Path `$Path -ItemType Directory -Force | Out-Null
        Write-Log "Created download directory: `$Path"
    }
    
    return (Resolve-Path `$Path).Path
}

function Get-SafeFileName {
    [CmdletBinding()]
    param([string]`$FileName)
    
    `$invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    `$safeName = `$FileName
    
    foreach (`$char in `$invalidChars) {
        `$safeName = `$safeName -replace [regex]::Escape(`$char), "_"
    }
    
    return `$safeName
}

function Get-FileHash {
    [CmdletBinding()]
    param([string]`$FilePath)
    
    if (Test-Path `$FilePath) {
        return (Get-FileHash -Path `$FilePath -Algorithm SHA256).Hash
    }
    
    return `$null
}
"@
            
            # Create config directory and files
            New-Item -Path "$Script:SharePointProject\config" -ItemType Directory -Force | Out-Null
            
            $configJson = @{
                ChromeDriverPath = "./drivers/chromedriver.exe"
                DownloadTimeout = 300
                RetryAttempts = 3
                LogLevel = "Info"
                SharePointSites = @{
                    SP2019 = "https://sharepoint.company.com"
                    SP365 = "https://company.sharepoint.com"
                }
                DownloadPath = "./downloads"
            }
            $configJson | ConvertTo-Json -Depth 5 | Out-File -FilePath "$Script:SharePointProject\config\sharepoint-config.json" -Encoding UTF8
            
            # Create drivers directory (empty for testing)
            New-Item -Path "$Script:SharePointProject\drivers" -ItemType Directory -Force | Out-Null
            
            # Create documentation
            $readme = @"
# SharePoint File Download Tools

A comprehensive PowerShell toolkit for downloading files from SharePoint 2019 and SharePoint 365.

## Features

- Automated login and authentication
- Support for both SharePoint 2019 and SharePoint 365
- Robust error handling and retry logic
- Configurable download settings
- Detailed logging

## Usage

``````powershell
# Download a single file
.\Get-SharePointFile.ps1 "https://company.sharepoint.com/sites/team/documents/file.pdf"

# Import as module
Import-Module .\Get-SharePointFile.ps1
Get-SharePointFile -Url "https://sharepoint.company.com/file.docx" -DestinationPath "C:\Downloads"
``````

## Configuration

Edit `config\sharepoint-config.json` to customize settings:

- ChromeDriverPath: Path to Chrome WebDriver executable
- DownloadTimeout: Maximum time to wait for downloads (seconds)
- RetryAttempts: Number of retry attempts for failed operations
- LogLevel: Logging verbosity (Debug, Info, Warning, Error)

## Requirements

- PowerShell 5.1 or later
- Chrome browser
- Chrome WebDriver
- Selenium PowerShell module

## Installation

1. Download and extract the package
2. Install Chrome WebDriver to the drivers directory
3. Configure settings in sharepoint-config.json
4. Run Get-SharePointFile.ps1

## Troubleshooting

See the logs directory for detailed execution logs.
"@
            $readme | Out-File -FilePath "$Script:SharePointProject\README.md" -Encoding UTF8
            
            # Save all script contents to files
            $mainSharePointScript | Out-File -FilePath "$Script:SharePointProject\Get-SharePointFile.ps1" -Encoding UTF8
            $configScript | Out-File -FilePath "$Script:SharePointProject\lib\Config.ps1" -Encoding UTF8
            $loggingScript | Out-File -FilePath "$Script:SharePointProject\lib\Logging.ps1" -Encoding UTF8
            $webDriverScript | Out-File -FilePath "$Script:SharePointProject\lib\WebDriver.ps1" -Encoding UTF8
            $validationScript | Out-File -FilePath "$Script:SharePointProject\lib\helpers\Validation.ps1" -Encoding UTF8
            $errorHandlingScript | Out-File -FilePath "$Script:SharePointProject\lib\helpers\ErrorHandling.ps1" -Encoding UTF8
            $fileUtilsScript | Out-File -FilePath "$Script:SharePointProject\utils\FileUtils.ps1" -Encoding UTF8
            
            Push-Location $Script:SharePointProject
        }
        
        AfterAll {
            Pop-Location
        }
        
        It "Should analyze dependencies for complex SharePoint project" {
            $mainScript = Join-Path $Script:SharePointProject "Get-SharePointFile.ps1"
            
            $result = Find-ScriptDependencies -StartingFiles @($mainScript) -SearchPaths @($Script:SharePointProject)
            
            $result | Should -Not -BeNullOrEmpty
            $result.AllFiles.Count | Should -BeGreaterThan 5
            $result.Summary.TotalFiles | Should -BeGreaterThan 5
            
            # Should find all the key files
            $expectedFiles = @(
                "Get-SharePointFile.ps1",
                "Config.ps1",
                "Logging.ps1", 
                "WebDriver.ps1",
                "Validation.ps1",
                "ErrorHandling.ps1",
                "FileUtils.ps1"
            )
            
            foreach ($expectedFile in $expectedFiles) {
                $found = $result.AllFiles | Where-Object { $_ -like "*$expectedFile" }
                $found | Should -Not -BeNullOrEmpty -Because "Should find $expectedFile"
            }
        }
        
        It "Should generate appropriate package configuration from dependencies" {
            $mainScript = Join-Path $Script:SharePointProject "Get-SharePointFile.ps1"
            $depResult = Find-ScriptDependencies -StartingFiles @($mainScript) -SearchPaths @($Script:SharePointProject)
            
            $configPath = Join-Path $Global:TestBaseDir "sharepoint-auto-config.json"
            $config = New-DependencyPackageConfig -DependencyResult $depResult -OutputPath $configPath -PackageName "SharePointTools"
            
            # Verify config structure
            $config.package.name | Should -Be "SharePointTools"
            $config.files | Should -Not -BeNullOrEmpty
            $config.dependency_metadata.total_files_analyzed | Should -Be $depResult.AllFiles.Count
            
            # Config file should exist and be valid JSON
            Test-Path $configPath | Should -Be $true
            { Get-Content $configPath | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "Should package SharePoint project successfully" {
            $mainScript = Join-Path $Script:SharePointProject "Get-SharePointFile.ps1"
            $depResult = Find-ScriptDependencies -StartingFiles @($mainScript) -SearchPaths @($Script:SharePointProject)
            
            $configPath = Join-Path $Global:TestBaseDir "sharepoint-package-config.json"
            New-DependencyPackageConfig -DependencyResult $depResult -OutputPath $configPath -PackageName "SharePointTools" | Out-Null
            
            $outputPath = Join-Path $Global:TestBaseDir "sharepoint-package"
            $result = New-Package -ConfigPath $configPath -OutputPath $outputPath -Mode Package -Force
            
            $result.Success | Should -Be $true
            Test-Path $outputPath | Should -Be $true
            
            # Check that key files were packaged
            Test-Path "$outputPath\scripts\Get-SharePointFile.ps1" | Should -Be $true
            Test-Path "$outputPath\package-manifest.json" | Should -Be $true
            
            # Verify manifest content
            $manifest = Get-Content "$outputPath\package-manifest.json" | ConvertFrom-Json
            $manifest.package.name | Should -Be "SharePointTools"
            $manifest.files | Should -Not -BeNullOrEmpty
        }
        
        It "Should create deployable package with proper structure" {
            $packageOutput = Join-Path $Global:TestBaseDir "sharepoint-final-package"
            
            # Create comprehensive config for deployment
            $deployConfig = @{
                package = @{
                    name = "SharePoint File Download Tools"
                    version = "1.2.0"
                    description = "Complete SharePoint automation toolkit"
                    author = "Integration Test"
                }
                directories = @("scripts", "lib", "config", "docs", "drivers")
                files = @(
                    @{
                        name = "main_script"
                        source = "Get-SharePointFile.ps1"
                        destination = "scripts"
                        preserve_structure = $false
                    },
                    @{
                        name = "library_files"
                        source = "lib\*.ps1"
                        destination = "lib"
                        preserve_structure = $true
                    },
                    @{
                        name = "config_files"
                        source = "config\*.json"
                        destination = "config"
                        preserve_structure = $false
                    },
                    @{
                        name = "utility_files"
                        source = "utils\*.ps1"
                        destination = "lib\utils"
                        preserve_structure = $false
                    },
                    @{
                        name = "documentation"
                        source = "*.md"
                        destination = "docs"
                        preserve_structure = $false
                    }
                )
                post_package = @(
                    @{
                        type = "create_file"
                        path = "INSTALL.md"
                        content = "# SharePoint Tools Installation\n\n1. Extract to preferred location\n2. Configure settings in config\\sharepoint-config.json\n3. Install Chrome WebDriver in drivers\\ directory\n4. Run scripts\\Get-SharePointFile.ps1\n\n## Requirements\n- PowerShell 5.1+\n- Chrome browser\n- Chrome WebDriver"
                    },
                    @{
                        type = "create_file"
                        path = "VERSION.json"
                        content = @{
                            version = "1.2.0"
                            build_date = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                            package_name = "SharePoint File Download Tools"
                            created_by = "Integration Test"
                        }
                    }
                )
            }
            
            $deployConfigPath = Join-Path $Global:TestBaseDir "sharepoint-deploy-config.json"
            $deployConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $deployConfigPath -Encoding UTF8
            
            $result = New-Package -ConfigPath $deployConfigPath -OutputPath $packageOutput -Mode Package -Force
            
            $result.Success | Should -Be $true
            
            # Verify complete package structure
            Test-Path "$packageOutput\scripts\Get-SharePointFile.ps1" | Should -Be $true
            Test-Path "$packageOutput\lib\Config.ps1" | Should -Be $true
            Test-Path "$packageOutput\lib\helpers\Validation.ps1" | Should -Be $true
            Test-Path "$packageOutput\lib\utils\FileUtils.ps1" | Should -Be $true
            Test-Path "$packageOutput\config\sharepoint-config.json" | Should -Be $true
            Test-Path "$packageOutput\docs\README.md" | Should -Be $true
            Test-Path "$packageOutput\INSTALL.md" | Should -Be $true
            Test-Path "$packageOutput\VERSION.json" | Should -Be $true
            
            # Verify VERSION.json content
            $version = Get-Content "$packageOutput\VERSION.json" | ConvertFrom-Json
            $version.version | Should -Be "1.2.0"
            $version.package_name | Should -Be "SharePoint File Download Tools"
        }
    }
    
    Context "Auto-Package Mode Integration" {
        BeforeAll {
            # Create a simpler test project for auto-packaging
            $Script:SimpleProject = New-TestProjectStructure -BasePath $Global:TestBaseDir -ProjectName "SimpleAutoPackage"
            Push-Location $Script:SimpleProject.ProjectPath
        }
        
        AfterAll {
            Pop-Location
        }
        
        It "Should auto-analyze and package in one operation" {
            $outputPath = Join-Path $Global:TestBaseDir "auto-package-result"
            
            $result = New-Package -StartingFiles @($Script:SimpleProject.MainScript) -OutputPath $outputPath -Mode AutoPackage -Force
            
            $result.Success | Should -Be $true
            $result.DependencyAnalysis | Should -Not -BeNullOrEmpty
            $result.GeneratedConfig | Should -Not -BeNullOrEmpty
            $result.PackageResult | Should -Not -BeNullOrEmpty
            
            # Generated config should exist
            Test-Path $result.GeneratedConfig | Should -Be $true
            
            # Package should be created
            Test-Path $outputPath | Should -Be $true
            Test-Path "$outputPath\scripts\Main.ps1" | Should -Be $true
        }
        
        It "Should handle path rewriting for flattened structure" {
            $outputPath = Join-Path $Global:TestBaseDir "flattened-auto-package"
            
            # Create config that flattens structure
            $flattenConfig = @{
                package = @{ name = "Flattened Test"; version = "1.0.0" }
                files = @(
                    @{
                        name = "all_scripts"
                        source = "*.ps1"
                        destination = "scripts"
                        flatten = $true
                    },
                    @{
                        name = "lib_scripts"
                        source = "lib\*.ps1"
                        destination = "scripts"
                        flatten = $true
                    },
                    @{
                        name = "util_scripts"
                        source = "utils\*.ps1"
                        destination = "scripts"
                        flatten = $true
                    }
                )
            }
            
            $configPath = Join-Path $Global:TestBaseDir "flatten-config.json"
            $flattenConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8
            
            $result = New-Package -ConfigPath $configPath -OutputPath $outputPath -Mode Package -UpdateDotSourcePaths -Force
            
            $result.Success | Should -Be $true
            
            # Check that dot-source paths were updated
            $mainScriptContent = Get-Content "$outputPath\scripts\Main.ps1" -Raw
            $mainScriptContent | Should -Match '\.\s+\.\\'  # Should have relative paths updated
        }
    }
}

Describe "Performance and Scale Testing" {
    Context "Large project simulation" {
        BeforeAll {
            # Create a project with many files to test performance
            $Script:LargeProject = Join-Path $Global:TestBaseDir "LargeProject"
            New-Item -Path $Script:LargeProject -ItemType Directory -Force | Out-Null
            
            # Create main script
            $mainContent = "# Main.ps1 - Entry point`n"
            for ($i = 1; $i -le 20; $i++) {
                $mainContent += ". `$PSScriptRoot\lib\Module$i.ps1`n"
            }
            $mainContent | Out-File -FilePath "$Script:LargeProject\Main.ps1" -Encoding UTF8
            
            # Create lib directory with many modules
            New-Item -Path "$Script:LargeProject\lib" -ItemType Directory -Force | Out-Null
            for ($i = 1; $i -le 20; $i++) {
                $moduleContent = @"
# Module$i.ps1 - Generated module $i
function Get-Function$i {
    return "Function $i result"
}
"@
                $moduleContent | Out-File -FilePath "$Script:LargeProject\lib\Module$i.ps1" -Encoding UTF8
            }
            
            Push-Location $Script:LargeProject
        }
        
        AfterAll {
            Pop-Location
        }
        
        It "Should handle large dependency analysis efficiently" {
            $mainScript = Join-Path $Script:LargeProject "Main.ps1"
            
            $startTime = Get-Date
            $result = Find-ScriptDependencies -StartingFiles @($mainScript) -SearchPaths @($Script:LargeProject)
            $endTime = Get-Date
            
            $duration = $endTime - $startTime
            
            $result.AllFiles.Count | Should -Be 21  # Main + 20 modules
            $duration.TotalSeconds | Should -BeLessThan 10  # Should complete within 10 seconds
        }
        
        It "Should package large projects efficiently" {
            $configPath = Join-Path $Global:TestBaseDir "large-project-config.json"
            $largeConfig = @{
                package = @{ name = "Large Test Project"; version = "1.0.0" }
                files = @(
                    @{
                        name = "all_scripts"
                        source = "*.ps1"
                        destination = "scripts"
                        preserve_structure = $false
                    },
                    @{
                        name = "lib_modules"
                        source = "lib\*.ps1"
                        destination = "lib"
                        preserve_structure = $false
                    }
                )
            }
            $largeConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8
            
            $outputPath = Join-Path $Global:TestBaseDir "large-project-package"
            
            $startTime = Get-Date
            $result = New-Package -ConfigPath $configPath -OutputPath $outputPath -Mode Package -Force
            $endTime = Get-Date
            
            $duration = $endTime - $startTime
            
            $result.Success | Should -Be $true
            $result.TotalFiles | Should -Be 21
            $duration.TotalSeconds | Should -BeLessThan 15  # Should package within 15 seconds
        }
    }
}

Describe "Error Handling and Edge Cases" {
    Context "Invalid configurations" {
        It "Should handle malformed JSON config gracefully" {
            $invalidJsonPath = Join-Path $Global:TestBaseDir "invalid-config.json"
            "{ invalid json content" | Out-File -FilePath $invalidJsonPath -Encoding UTF8
            
            { New-Package -ConfigPath $invalidJsonPath -Mode Package } | Should -Throw
        }
        
        It "Should handle missing dependencies gracefully" {
            $projectWithMissing = New-TestProjectStructure -BasePath $Global:TestBaseDir -ProjectName "MissingDeps" -IncludeUnresolvedDeps
            
            $depResult = Find-ScriptDependencies -StartingFiles @($projectWithMissing.MainScript) -SearchPaths @($projectWithMissing.ProjectPath)
            
            # Should complete analysis even with missing dependencies
            $depResult | Should -Not -BeNullOrEmpty
            $depResult.AllFiles | Should -Not -BeNullOrEmpty
            
            # Should be able to generate config with unresolved dependencies
            $configPath = Join-Path $Global:TestBaseDir "missing-deps-config.json"
            $config = New-DependencyPackageConfig -DependencyResult $depResult -OutputPath $configPath
            
            $config.dependency_metadata.unresolved_dependencies | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle circular dependencies without hanging" {
            $circularProject = New-TestProjectWithCircularDeps -BasePath $Global:TestBaseDir
            
            # This should complete without hanging
            $timeout = 30  # 30 second timeout
            $job = Start-Job -ScriptBlock {
                param($ProjectPath, $ScriptA)
                . $using:PackagerPath
                Find-ScriptDependencies -StartingFiles @($ScriptA) -SearchPaths @($ProjectPath) -MaxDepth 5
            } -ArgumentList $circularProject.ProjectPath, $circularProject.ScriptA
            
            $completed = Wait-Job -Job $job -Timeout $timeout
            $completed | Should -Not -BeNullOrEmpty
            
            $result = Receive-Job -Job $job
            Remove-Job -Job $job -Force
            
            $result | Should -Not -BeNullOrEmpty
            $result.AllFiles | Should -Contain $circularProject.ScriptA
            $result.AllFiles | Should -Contain $circularProject.ScriptB
        }
    }
    
    Context "File system edge cases" {
        It "Should handle very long file paths" {
            $longPathProject = Join-Path $Global:TestBaseDir "VeryLongProjectNameThatExceedsNormalLimits"
            New-Item -Path $longPathProject -ItemType Directory -Force | Out-Null
            
            $veryLongPath = Join-Path $longPathProject "VeryLongSubdirectoryNameThatIsUnusuallyLong"
            New-Item -Path $veryLongPath -ItemType Directory -Force | Out-Null
            
            $scriptContent = "# LongPath.ps1`nfunction Test-LongPath { return 'OK' }"
            $scriptPath = Join-Path $veryLongPath "VeryLongScriptNameThatExceedsNormalConventions.ps1"
            $scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8
            
            # Should handle long paths without error
            { Find-ScriptDependencies -StartingFiles @($scriptPath) -SearchPaths @($longPathProject) } | Should -Not -Throw
        }
        
        It "Should handle special characters in paths" {
            $specialCharProject = Join-Path $Global:TestBaseDir "Special Chars & Symbols"
            New-Item -Path $specialCharProject -ItemType Directory -Force | Out-Null
            
            $scriptContent = "# Special.ps1`nfunction Test-Special { return 'OK' }"
            $specialScriptPath = Join-Path $specialCharProject "Script with spaces & symbols.ps1"
            $scriptContent | Out-File -FilePath $specialScriptPath -Encoding UTF8
            
            # Should handle special characters without error
            { Find-ScriptDependencies -StartingFiles @($specialScriptPath) -SearchPaths @($specialCharProject) } | Should -Not -Throw
        }
    }
}