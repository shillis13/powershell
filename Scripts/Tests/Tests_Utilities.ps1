#========================================
#region TestUtilities
<#
.SYNOPSIS
Helper utilities for creating test directory structures and test PowerShell files.

.DESCRIPTION
Provides functions to create virtual test directories with PowerShell files containing
realistic dot-source and import statements for testing the packager system.
Uses VirtualFolderFileUtils.ps1 for directory creation.
#>
#========================================
#endregion

# Import VirtualFolderFileUtils if available
$VirtualFolderUtilsPath = Join-Path $PSScriptRoot "..\..\FileUtils\VirtualFolderFileUtils.ps1"
if (Test-Path $VirtualFolderUtilsPath) {
    . $VirtualFolderUtilsPath
} else {
    Write-Warning "VirtualFolderFileUtils.ps1 not found. Some test utilities may not work."
}

#========================================
#region New-TestProjectStructure
<#
.SYNOPSIS
Creates a complete test project structure with interdependent PowerShell files.
#>
#========================================
#endregion
function New-TestProjectStructure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,
        
        [string]$ProjectName = "TestProject",
        
        [switch]$IncludeUnresolvedDeps,
        
        [switch]$IncludeVariablePaths
    )
    
    $projectPath = Join-Path $BasePath $ProjectName
    
    # Create directory structure
    $directories = @(
        $projectPath,
        "$projectPath\lib",
        "$projectPath\lib\helpers",
        "$projectPath\utils",
        "$projectPath\config",
        "$projectPath\docs"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
    }
    
    # Create main entry point script
    $mainScript = @"
#========================================
# Main.ps1 - Entry point for test project
#========================================

# Dot-source library files
. `$PSScriptRoot\lib\Config.ps1
. `$PSScriptRoot\lib\Logging.ps1
. `$PSScriptRoot\utils\StringHelpers.ps1

# Import module (if needed)
Import-Module `$PSScriptRoot\lib\DataAccess.ps1 -Force

function Start-TestProject {
    [CmdletBinding()]
    param([string]`$InputPath)
    
    Write-Log "Starting test project with input: `$InputPath"
    `$config = Get-ProjectConfig
    `$cleanInput = Format-String -Input `$InputPath
    
    return `$config
}

# Main execution
if (`$MyInvocation.InvocationName -ne '.') {
    Start-TestProject -InputPath `$args[0]
}
"@
    
    $mainScript | Out-File -FilePath "$projectPath\Main.ps1" -Encoding UTF8
    
    # Create config script
    $configScript = @"
#========================================
# Config.ps1 - Configuration management
#========================================

# Dot-source helpers
. `$PSScriptRoot\helpers\Validation.ps1
. `$PSScriptRoot\helpers\ErrorHandling.ps1

function Get-ProjectConfig {
    [CmdletBinding()]
    param()
    
    `$configPath = Join-Path `$PSScriptRoot "..\config\settings.json"
    
    if (Test-Path `$configPath) {
        `$config = Get-Content `$configPath | ConvertFrom-Json
        return Confirm-ConfigValid -Config `$config
    } else {
        return Get-DefaultConfig
    }
}

function Get-DefaultConfig {
    return @{
        Version = "1.0.0"
        LogLevel = "Info"
        OutputPath = ".\output"
    }
}
"@
    
    $configScript | Out-File -FilePath "$projectPath\lib\Config.ps1" -Encoding UTF8
    
    # Create logging script
    $loggingScript = @"
#========================================
# Logging.ps1 - Logging utilities
#========================================

# Dot-source error handling
. `$PSScriptRoot\helpers\ErrorHandling.ps1

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = `$true)]
        [string]`$Message,
        
        [ValidateSet("Info", "Warning", "Error", "Debug")]
        [string]`$Level = "Info"
    )
    
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    `$logEntry = "[$timestamp] [$Level] `$Message"
    
    Write-Host `$logEntry
    
    # Log to file if configured
    `$config = Get-ProjectConfig
    if (`$config.LogFile) {
        `$logEntry | Out-File -FilePath `$config.LogFile -Append
    }
}
"@
    
    if ($IncludeUnresolvedDeps) {
        $loggingScript += @"

# This creates an unresolved dependency for testing
. `$PSScriptRoot\missing-module.ps1
"@
    }
    
    if ($IncludeVariablePaths) {
        $loggingScript += @"

# This creates a variable-based path for testing
`$libPath = `$PSScriptRoot
. "`$libPath\helpers\DynamicHelper.ps1"
"@
    }
    
    $loggingScript | Out-File -FilePath "$projectPath\lib\Logging.ps1" -Encoding UTF8
    
    # Create data access script
    $dataAccessScript = @"
#========================================
# DataAccess.ps1 - Data access layer
#========================================

# Dot-source validation helpers
. `$PSScriptRoot\helpers\Validation.ps1

function Get-TestData {
    [CmdletBinding()]
    param([string]`$DataType)
    
    `$isValid = Test-DataType -Type `$DataType
    if (-not `$isValid) {
        throw "Invalid data type: `$DataType"
    }
    
    return @{ Type = `$DataType; Data = "Sample data" }
}

Export-ModuleMember -Function Get-TestData
"@
    
    $dataAccessScript | Out-File -FilePath "$projectPath\lib\DataAccess.ps1" -Encoding UTF8
    
    # Create helper scripts
    $validationScript = @"
#========================================
# Validation.ps1 - Validation utilities
#========================================

function Confirm-ConfigValid {
    [CmdletBinding()]
    param([hashtable]`$Config)
    
    if (-not `$Config.Version) {
        throw "Configuration missing Version"
    }
    
    return `$Config
}

function Test-DataType {
    [CmdletBinding()]
    param([string]`$Type)
    
    return `$Type -in @("String", "Number", "Object")
}
"@
    
    $validationScript | Out-File -FilePath "$projectPath\lib\helpers\Validation.ps1" -Encoding UTF8
    
    $errorHandlingScript = @"
#========================================
# ErrorHandling.ps1 - Error handling utilities
#========================================

function Write-ErrorDetails {
    [CmdletBinding()]
    param([System.Management.Automation.ErrorRecord]`$ErrorRecord)
    
    Write-Host "Error: `$(`$ErrorRecord.Exception.Message)" -ForegroundColor Red
    Write-Host "Line: `$(`$ErrorRecord.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
}

function Invoke-WithErrorHandling {
    [CmdletBinding()]
    param([scriptblock]`$ScriptBlock)
    
    try {
        & `$ScriptBlock
    } catch {
        Write-ErrorDetails -ErrorRecord `$_
        throw
    }
}
"@
    
    $errorHandlingScript | Out-File -FilePath "$projectPath\lib\helpers\ErrorHandling.ps1" -Encoding UTF8
    
    # Create string helpers
    $stringHelpersScript = @"
#========================================
# StringHelpers.ps1 - String manipulation utilities
#========================================

function Format-String {
    [CmdletBinding()]
    param([string]`$Input)
    
    return `$Input.Trim().ToLower()
}

function Join-StringArray {
    [CmdletBinding()]
    param(
        [string[]]`$Array,
        [string]`$Delimiter = ","
    )
    
    return `$Array -join `$Delimiter
}
"@
    
    $stringHelpersScript | Out-File -FilePath "$projectPath\utils\StringHelpers.ps1" -Encoding UTF8
    
    # Create configuration file
    $configJson = @{
        Version = "1.0.0"
        LogLevel = "Info"
        OutputPath = ".\output"
        LogFile = ".\logs\app.log"
    }
    
    $configJson | ConvertTo-Json | Out-File -FilePath "$projectPath\config\settings.json" -Encoding UTF8
    
    # Create README
    $readme = @"
# Test Project

This is a test project created for testing the PowerShell packager system.

## Structure

- **Main.ps1** - Entry point
- **lib/** - Core library files
  - **Config.ps1** - Configuration management
  - **Logging.ps1** - Logging utilities
  - **DataAccess.ps1** - Data access layer
  - **helpers/** - Helper utilities
- **utils/** - Utility functions
- **config/** - Configuration files

## Dependencies

This project demonstrates various dependency patterns:
- Direct dot-sourcing (`. file.ps1`)
- Relative path dependencies
- Module imports
- Nested dependencies
"@
    
    if ($IncludeUnresolvedDeps) {
        $readme += "`n- Unresolved dependencies (for testing)"
    }
    
    if ($IncludeVariablePaths) {
        $readme += "`n- Variable-based paths (for testing)"
    }
    
    $readme | Out-File -FilePath "$projectPath\README.md" -Encoding UTF8
    
    Write-Verbose "Created test project structure at: $projectPath"
    
    return @{
        ProjectPath = $projectPath
        MainScript = "$projectPath\Main.ps1"
        ExpectedFiles = @(
            "$projectPath\Main.ps1",
            "$projectPath\lib\Config.ps1",
            "$projectPath\lib\Logging.ps1",
            "$projectPath\lib\DataAccess.ps1",
            "$projectPath\lib\helpers\Validation.ps1",
            "$projectPath\lib\helpers\ErrorHandling.ps1",
            "$projectPath\utils\StringHelpers.ps1"
        )
        ConfigFile = "$projectPath\config\settings.json"
        ReadmeFile = "$projectPath\README.md"
    }
}

#========================================
#region New-TestPackageConfig
<#
.SYNOPSIS
Creates test package configuration files for testing.
#>
#========================================
#endregion
function New-TestPackageConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [string]$ConfigType = "Basic"
    )
    
    switch ($ConfigType) {
        "Basic" {
            $config = @{
                package = @{
                    name = "Test Package"
                    version = "1.0.0"
                    description = "Test package configuration"
                    author = "Test Suite"
                }
                files = @(
                    @{
                        name = "main_scripts"
                        source = "*.ps1"
                        destination = "scripts"
                        preserve_structure = $false
                    }
                )
            }
        }
        
        "Complex" {
            $config = @{
                package = @{
                    name = "Complex Test Package"
                    version = "2.1.0"
                    description = "Complex package with multiple file groups"
                    author = "Test Suite"
                    tags = @("test", "complex", "powershell")
                }
                directories = @("scripts", "lib", "docs", "config")
                files = @(
                    @{
                        name = "core_scripts"
                        source = "*.ps1"
                        destination = "scripts"
                        preserve_structure = $false
                        exclude = @("*test*", "*backup*")
                    },
                    @{
                        name = "library_files"
                        source = "lib/*.ps1"
                        destination = "lib"
                        preserve_structure = $true
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
                        content = "# Installation Instructions`n`nCopy scripts to your PowerShell path."
                    }
                )
            }
        }
        
        "Flattened" {
            $config = @{
                package = @{
                    name = "Flattened Test Package"
                    version = "1.0.0"
                    description = "Test package with flattened structure"
                }
                files = @(
                    @{
                        name = "all_scripts"
                        source = "*.ps1"
                        destination = "scripts"
                        flatten = $true
                    },
                    @{
                        name = "lib_scripts"
                        source = "lib/*.ps1"
                        destination = "scripts"
                        flatten = $true
                    }
                )
            }
        }
        
        default {
            throw "Unknown config type: $ConfigType"
        }
    }
    
    $jsonContent = $config | ConvertTo-Json -Depth 10
    $jsonContent | Out-File -FilePath $OutputPath -Encoding UTF8
    
    Write-Verbose "Created test package config: $OutputPath"
    return $config
}

#========================================
#region New-TestProjectWithCircularDeps
<#
.SYNOPSIS
Creates a test project with circular dependencies for testing edge cases.
#>
#========================================
#endregion
function New-TestProjectWithCircularDeps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )
    
    $projectPath = Join-Path $BasePath "CircularDepsProject"
    
    if (-not (Test-Path $projectPath)) {
        New-Item -Path $projectPath -ItemType Directory -Force | Out-Null
    }
    
    # Script A depends on Script B
    $scriptA = @"
# ScriptA.ps1 - Depends on ScriptB
. `$PSScriptRoot\ScriptB.ps1

function FunctionA {
    return "A: " + (FunctionB)
}
"@
    
    # Script B depends on Script A (circular)
    $scriptB = @"
# ScriptB.ps1 - Depends on ScriptA (circular dependency)
. `$PSScriptRoot\ScriptA.ps1

function FunctionB {
    return "B"
}
"@
    
    $scriptA | Out-File -FilePath "$projectPath\ScriptA.ps1" -Encoding UTF8
    $scriptB | Out-File -FilePath "$projectPath\ScriptB.ps1" -Encoding UTF8
    
    return @{
        ProjectPath = $projectPath
        ScriptA = "$projectPath\ScriptA.ps1"
        ScriptB = "$projectPath\ScriptB.ps1"
    }
}

#========================================
#region Assert-TestFile
<#
.SYNOPSIS
Helper function for asserting test file properties in Pester tests.
#>
#========================================
#endregion
function Assert-TestFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [string]$ExpectedContent,
        
        [string[]]$ExpectedDependencies,
        
        [switch]$ShouldExist = $true
    )
    
    if ($ShouldExist) {
        if (-not (Test-Path $FilePath)) {
            throw "Expected file does not exist: $FilePath"
        }
        
        if ($ExpectedContent) {
            $actualContent = Get-Content $FilePath -Raw
            if ($actualContent -notlike "*$ExpectedContent*") {
                throw "File does not contain expected content: $ExpectedContent"
            }
        }
        
        if ($ExpectedDependencies) {
            $content = Get-Content $FilePath -Raw
            foreach ($dependency in $ExpectedDependencies) {
                if ($content -notlike "*$dependency*") {
                    throw "File does not contain expected dependency: $dependency"
                }
            }
        }
    } else {
        if (Test-Path $FilePath) {
            throw "File should not exist but does: $FilePath"
        }
    }
}

#========================================
#region Get-TestTempDirectory
<#
.SYNOPSIS
Creates and returns a temporary directory for tests.
#>
#========================================
#endregion
function Get-TestTempDirectory {
    [CmdletBinding()]
    param([string]$Prefix = "PackagerTest")
    
    $tempBase = [System.IO.Path]::GetTempPath()
    $tempName = "$Prefix-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
    $tempPath = Join-Path $tempBase $tempName
    
    New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
    
    return $tempPath
}

#========================================
#region Remove-TestDirectory
<#
.SYNOPSIS
Safely removes test directories with retry logic.
#>
#========================================
#endregion
function Remove-TestDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [int]$MaxRetries = 3
    )
    
    if (-not (Test-Path $Path)) {
        return
    }
    
    $retryCount = 0
    while ($retryCount -lt $MaxRetries) {
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            Write-Verbose "Successfully removed test directory: $Path"
            return
        } catch {
            $retryCount++
            if ($retryCount -ge $MaxRetries) {
                Write-Warning "Failed to remove test directory after $MaxRetries attempts: $Path"
                Write-Warning "Error: $($_.Exception.Message)"
                return
            }
            Start-Sleep -Milliseconds 500
        }
    }
}

# Export functions for use in test files
Export-ModuleMember -Function @(
    'New-TestProjectStructure',
    'New-TestPackageConfig', 
    'New-TestProjectWithCircularDeps',
    'Assert-TestFile',
    'Get-TestTempDirectory',
    'Remove-TestDirectory'
)