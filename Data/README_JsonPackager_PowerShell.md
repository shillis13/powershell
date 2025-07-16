# PowerShell JSON Packager System

A comprehensive, dependency-aware packaging system for PowerShell projects that automates the collection, organization, and deployment of scripts and their dependencies.

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Quick Start](#quick-start)
- [Configuration File Structure](#configuration-file-structure)
- [Basic Examples](#basic-examples)
- [Advanced Examples](#advanced-examples)
- [Dependency Analysis](#dependency-analysis)
- [Directory Structure Management](#directory-structure-management)
- [Post-Package Actions](#post-package-actions)
- [Command Line Interface](#command-line-interface)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Schema Validation](#schema-validation)

## Overview

The PowerShell JSON Packager System is designed to solve the common problem of deploying PowerShell projects to colleagues and production environments. Instead of manually copying files and figuring out dependencies, this system:

1. **Analyzes PowerShell scripts** to discover dependencies through dot-sourcing (`. ./lib/module.ps1`) and import statements
2. **Reads JSON configuration files** that define how to package your project
3. **Automatically collects all required files** based on your configuration rules
4. **Creates organized deployment packages** with proper directory structures
5. **Handles path rewriting** when directory structures are flattened
6. **Generates installation documentation** and deployment manifests

### What Problems Does It Solve?

- **Dependency Hell**: Automatically discovers and includes all script dependencies
- **Manual Packaging**: No more forgetting to include required files
- **Deployment Consistency**: Same package structure every time
- **Path Management**: Automatically updates relative paths when restructuring
- **Documentation**: Generates installation instructions and file manifests
- **Version Control**: Tracks what's included in each package version

## Key Features

### 🔍 Automatic Dependency Discovery
- Analyzes PowerShell scripts to find dot-source dependencies (`. ./lib/config.ps1`)
- Traces dependency chains through multiple levels
- Handles circular dependencies gracefully
- Reports unresolved dependencies for manual review

### 📦 Flexible Packaging Options
- **Preserve Structure**: Keep original directory layout
- **Flatten Structure**: Put all files in single directory with automatic path rewriting
- **Selective Inclusion**: Include/exclude files with pattern matching
- **Multiple File Groups**: Different rules for different types of files

### 🛠️ Post-Package Automation
- Create installation scripts and documentation
- Generate version information files
- Execute custom scripts after packaging
- Create ZIP archives for distribution

### 📋 Configuration Management
- JSON-based configuration files with schema validation
- Template generation for common scenarios
- Auto-generation from dependency analysis
- Multiple configuration formats supported

### 🔄 Multiple Operation Modes
- **Package Mode**: Create packages from existing configurations
- **Auto-Package Mode**: Analyze dependencies and package in one step
- **Analyze Mode**: Just analyze dependencies without packaging
- **Install Mode**: Deploy packages to target locations

## Quick Start

### 1. Install Prerequisites

```powershell
# Ensure PowerShell 5.1 or later
$PSVersionTable.PSVersion

# The system uses only built-in PowerShell capabilities - no additional modules required
```

### 2. Create a Simple Package Configuration

Create a file named `my-package-config.json`:

```json
{
  "package": {
    "name": "My PowerShell Tools",
    "version": "1.0.0",
    "description": "Collection of useful PowerShell utilities"
  },
  "files": [
    {
      "name": "scripts",
      "source": "*.ps1",
      "destination": "scripts"
    }
  ]
}
```

### 3. Run the Packager

```powershell
# Package your project
.\json_packager_system.ps1 -ConfigPath "my-package-config.json" -OutputPath ".\release" -Mode Package

# Or use auto-analysis mode
.\json_packager_system.ps1 -StartingFiles @("MyMainScript.ps1") -OutputPath ".\release" -Mode AutoPackage
```

## Configuration File Structure

A JSON package configuration file controls how the packager operates. Here's the complete structure:

### Required Sections

```json
{
  "package": {
    "name": "Package Name",           // Required: Package identifier
    "version": "1.0.0"               // Required: Semantic version (x.y.z)
  },
  "files": [                         // Required: At least one file group
    {
      "name": "group_name",          // Required: Unique identifier
      "source": "*.ps1",            // Required: Source file pattern
      "destination": "scripts"       // Required: Target directory (can be "")
    }
  ]
}
```

### Optional Sections

```json
{
  "package": {
    "name": "Advanced Package",
    "version": "2.1.0",
    "description": "Optional package description",
    "author": "Your Name",
    "created_date": "2025-07-15",
    "tags": ["powershell", "utilities"]
  },
  
  "directories": [                   // Optional: Explicit directory creation
    "scripts", "lib", "docs", "config"
  ],
  
  "files": [
    {
      "name": "main_scripts",
      "source": "*.ps1",
      "destination": "scripts",
      "preserve_structure": false,    // Optional: Maintain source directory layout
      "flatten": false,              // Optional: Put all files in destination root
      "exclude": [                   // Optional: Patterns to exclude
        "*test*", "*backup*"
      ]
    }
  ],
  
  "post_package": [                  // Optional: Actions after packaging
    {
      "type": "create_file",
      "path": "INSTALL.md",
      "content": "# Installation Instructions\n..."
    },
    {
      "type": "zip_package",
      "name": "my-package-v1.0"
    }
  ]
}
```

## Basic Examples

### Example 1: Simple Script Collection

**Scenario**: Package all PowerShell scripts in current directory

```json
{
  "package": {
    "name": "Simple Scripts",
    "version": "1.0.0"
  },
  "files": [
    {
      "name": "all_scripts",
      "source": "*.ps1",
      "destination": "scripts"
    }
  ]
}
```

**What it does**:
1. Creates `scripts/` directory in package
2. Copies all `.ps1` files from current directory to `scripts/`
3. Generates `package-manifest.json` with file inventory

### Example 2: Organized Project Structure

**Scenario**: Package a project with separate library and utility files

```json
{
  "package": {
    "name": "Organized Project",
    "version": "1.2.0",
    "description": "Well-organized PowerShell project"
  },
  "directories": ["scripts", "lib", "utils", "docs"],
  "files": [
    {
      "name": "main_scripts",
      "source": "*.ps1",
      "destination": "scripts",
      "exclude": ["*test*", "*backup*"]
    },
    {
      "name": "library_files",
      "source": "lib/*.ps1",
      "destination": "lib",
      "preserve_structure": true
    },
    {
      "name": "utilities",
      "source": "utils/*.ps1",
      "destination": "utils"
    },
    {
      "name": "documentation",
      "source": "*.md",
      "destination": "docs"
    }
  ]
}
```

**What it does**:
1. Creates organized directory structure: `scripts/`, `lib/`, `utils/`, `docs/`
2. Copies main scripts (excluding test and backup files)
3. Preserves library directory structure
4. Includes documentation files

### Example 3: Flattened Structure with Path Rewriting

**Scenario**: Put all scripts in one directory and fix relative paths

```json
{
  "package": {
    "name": "Flattened Package",
    "version": "1.0.0"
  },
  "files": [
    {
      "name": "all_scripts",
      "source": "*.ps1",
      "destination": "scripts",
      "flatten": true
    },
    {
      "name": "lib_scripts",
      "source": "lib/*.ps1",
      "destination": "scripts",
      "flatten": true
    }
  ]
}
```

**Usage with path rewriting**:
```powershell
.\json_packager_system.ps1 -ConfigPath "flatten-config.json" -UpdateDotSourcePaths -OutputPath ".\package"
```

**What it does**:
1. Copies all scripts to single `scripts/` directory
2. Updates dot-source paths like `. ./lib/config.ps1` to `. ./config.ps1`
3. Creates backup files before making changes

## Advanced Examples

### Example 4: SharePoint Tools Package

**Scenario**: Package a complex SharePoint automation toolkit

```json
{
  "$schema": "./json_packager_schema.json",
  "package": {
    "name": "SharePoint File Download Tools",
    "version": "1.2.0",
    "description": "PowerShell scripts for downloading files from SharePoint 2019 and 365",
    "author": "DevOps Team",
    "created_date": "2025-07-15",
    "tags": ["sharepoint", "powershell", "file-download", "automation"]
  },
  
  "directories": [
    "scripts", "lib", "config", "docs", "drivers"
  ],
  
  "files": [
    {
      "name": "core_scripts",
      "source": "Get-SharePointFile*.ps1",
      "destination": "scripts",
      "preserve_structure": false,
      "exclude": ["*backup*", "*temp*"]
    },
    {
      "name": "library_scripts",
      "source": "lib/*.ps1",
      "destination": "lib", 
      "preserve_structure": true,
      "exclude": ["*test*"]
    },
    {
      "name": "configuration_files",
      "source": "config/*.json",
      "destination": "config",
      "exclude": ["*secret*", "*local*"]
    },
    {
      "name": "documentation",
      "source": "*.md",
      "destination": "docs",
      "exclude": ["TODO.md", "PRIVATE*.md"]
    }
  ],
  
  "post_package": [
    {
      "type": "create_file",
      "path": "INSTALL.md",
      "content": "# SharePoint Tools Installation\n\n## Quick Start\n1. Extract to your preferred location\n2. Copy scripts to your PowerShell modules path\n3. Configure settings in config\\sharepoint-config.json\n4. Install Chrome WebDriver in drivers\\ directory\n\n## Requirements\n- PowerShell 5.1 or later\n- Selenium PowerShell module\n- Chrome browser\n\n## Usage\nSee docs\\README.md for detailed instructions."
    },
    {
      "type": "create_file",
      "path": "VERSION.json",
      "content": {
        "version": "1.2.0",
        "build_date": "2025-07-15T13:00:00.000Z",
        "package_name": "SharePoint File Download Tools",
        "dependencies": {
          "selenium": ">=3.0.0",
          "chrome": ">=90.0"
        }
      }
    },
    {
      "type": "zip_package",
      "name": "sharepoint-tools-v1.2.0"
    }
  ]
}
```

**What it does**:
1. Creates professional directory structure
2. Includes only production files (excludes tests, backups, secrets)
3. Preserves library structure while flattening others
4. Generates comprehensive installation documentation
5. Creates version tracking file with dependency information
6. Produces ZIP archive for easy distribution

### Example 5: Multi-Environment Package

**Scenario**: Package with different configurations for dev/staging/production

```json
{
  "package": {
    "name": "Multi-Environment Tools",
    "version": "2.0.0",
    "description": "Tools with environment-specific configurations"
  },
  
  "directories": ["scripts", "config", "docs"],
  
  "files": [
    {
      "name": "core_scripts",
      "source": "src/core/*.ps1",
      "destination": "scripts"
    },
    {
      "name": "config_templates",
      "source": "config/templates/*.json",
      "destination": "config"
    }
  ],
  
  "post_package": [
    {
      "type": "create_file",
      "path": "config/development.json",
      "content": {
        "environment": "development",
        "debug_mode": true,
        "log_level": "DEBUG",
        "api_endpoint": "https://dev-api.company.com"
      }
    },
    {
      "type": "create_file",
      "path": "config/production.json", 
      "content": {
        "environment": "production",
        "debug_mode": false,
        "log_level": "WARN",
        "api_endpoint": "https://api.company.com"
      }
    },
    {
      "type": "create_file",
      "path": "deploy.ps1",
      "content": "param([string]$Environment)\n\nWrite-Host \"Deploying to $Environment environment\"\n$config = Get-Content \"config\\$Environment.json\" | ConvertFrom-Json\nWrite-Host \"Using endpoint: $($config.api_endpoint)\""
    }
  ]
}
```

## Dependency Analysis

The packager can automatically analyze your PowerShell scripts to discover dependencies:

### How Dependency Analysis Works

1. **Starts with entry point scripts** you specify
2. **Scans for dot-source statements** like `. $PSScriptRoot\lib\config.ps1`
3. **Resolves relative paths** using search directories
4. **Recursively analyzes discovered files** to find their dependencies
5. **Builds complete dependency graph** showing all relationships
6. **Reports unresolved dependencies** for manual review

### Using Auto-Package Mode

```powershell
# Analyze dependencies and package automatically
.\json_packager_system.ps1 -StartingFiles @("Get-SharePointFile.ps1") -Mode AutoPackage -OutputPath ".\package"
```

**What this does**:
1. Analyzes `Get-SharePointFile.ps1` for dependencies
2. Follows all dot-source chains (`. ./lib/config.ps1`, etc.)
3. Generates package configuration automatically
4. Creates package with all discovered files
5. Reports any unresolved dependencies

### Dependency Analysis Only

```powershell
# Just analyze dependencies without packaging
.\json_packager_system.ps1 -StartingFiles @("MyScript.ps1") -Mode AnalyzeDependencies
```

### Example Dependency Chain

Given this structure:
```
MyProject/
├── Main.ps1                    # Entry point
├── lib/
│   ├── Config.ps1             # . $PSScriptRoot\helpers\Validation.ps1
│   ├── Logging.ps1            # . $PSScriptRoot\helpers\ErrorHandling.ps1
│   └── helpers/
│       ├── Validation.ps1
│       └── ErrorHandling.ps1
└── utils/
    └── StringHelpers.ps1
```

**Main.ps1 contains**:
```powershell
. $PSScriptRoot\lib\Config.ps1
. $PSScriptRoot\lib\Logging.ps1
. $PSScriptRoot\utils\StringHelpers.ps1
```

**Dependency analysis discovers**:
- Main.ps1 → lib/Config.ps1 → lib/helpers/Validation.ps1
- Main.ps1 → lib/Logging.ps1 → lib/helpers/ErrorHandling.ps1  
- Main.ps1 → utils/StringHelpers.ps1

**Auto-generated configuration includes all 6 files**.

## Directory Structure Management

### Preserve Structure vs. Flatten

#### Preserve Structure (`"preserve_structure": true`)
Maintains the original directory layout:
```
Source:          Package:
lib/             lib/
├── config.ps1   ├── config.ps1
└── helpers/     └── helpers/
    └── util.ps1     └── util.ps1
```

#### Flatten (`"flatten": true`)
Puts all files in the destination directory:
```
Source:          Package:
lib/             scripts/
├── config.ps1   ├── config.ps1
└── helpers/     └── util.ps1
    └── util.ps1
```

### File Pattern Matching

The packager supports powerful file pattern matching:

```json
{
  "name": "pattern_examples",
  "source": "src/**/*.ps1",          // Recursive: all .ps1 files in src/ and subdirectories
  "destination": "scripts",
  "exclude": [
    "*test*",                       // Exclude files with "test" in name
    "backup_*",                     // Exclude files starting with "backup_"
    "*.tmp",                        // Exclude temporary files
    "**/debug/**"                   // Exclude anything in debug directories
  ]
}
```

### Directory Creation

The packager creates directories in several ways:

1. **Automatic**: From file `destination` properties
2. **Explicit**: Listed in `directories` array  
3. **Preserved**: When `preserve_structure: true`

```json
{
  "directories": ["scripts", "lib", "docs", "config"],  // Explicit creation
  "files": [
    {
      "destination": "tools"        // Automatic creation
    }
  ]
}
```

## Post-Package Actions

Post-package actions run after all files are copied and allow you to:

### Create Files

```json
{
  "type": "create_file",
  "path": "INSTALL.md",
  "content": "# Installation Instructions\n\nCopy scripts to your PowerShell path."
}
```

### Create JSON Files

```json
{
  "type": "create_file",
  "path": "VERSION.json",
  "content": {
    "version": "1.0.0",
    "build_date": "2025-07-15T13:00:00Z",
    "components": ["core", "utilities", "documentation"]
  }
}
```

### Create ZIP Archives

```json
{
  "type": "zip_package",
  "name": "my-tools-v1.0.0"
}
```

### Run Custom Scripts

```json
{
  "type": "run_script",
  "script": "./post-build.ps1",
  "arguments": ["--verify", "--sign"]
}
```

## Command Line Interface

### Basic Usage

```powershell
# Package mode (default)
.\json_packager_system.ps1 -ConfigPath "config.json" -OutputPath ".\release"

# Specify mode explicitly
.\json_packager_system.ps1 -ConfigPath "config.json" -OutputPath ".\release" -Mode Package
```

### Auto-Package Mode

```powershell
# Auto-analyze and package
.\json_packager_system.ps1 -StartingFiles @("Main.ps1") -OutputPath ".\package" -Mode AutoPackage

# With custom search paths
.\json_packager_system.ps1 -StartingFiles @("Main.ps1") -SearchPaths @(".", "./lib", "./shared") -Mode AutoPackage
```

### Dependency Analysis Only

```powershell
# Just analyze dependencies
.\json_packager_system.ps1 -StartingFiles @("Main.ps1") -Mode AnalyzeDependencies

# Generate package config from analysis
.\json_packager_system.ps1 -StartingFiles @("Main.ps1") -SearchPaths @(".") -Mode AutoPackage -OutputPath ".\temp"
```

### Advanced Options

```powershell
# Update dot-source paths for flattened structures
.\json_packager_system.ps1 -ConfigPath "config.json" -UpdateDotSourcePaths -OutputPath ".\package"

# Dry run (preview without making changes)
.\json_packager_system.ps1 -ConfigPath "config.json" -DryRun

# Force overwrite existing output
.\json_packager_system.ps1 -ConfigPath "config.json" -Force -OutputPath ".\package"
```

### Package and Install Mode

```powershell
# Package and install in one operation
.\json_packager_system.ps1 -ConfigPath "package-config.json" -InstallConfigPath "install-config.json" -Mode PackageAndInstall
```

## Best Practices

### Configuration Organization

1. **Use descriptive names** for file groups:
   ```json
   { "name": "core_business_logic", "source": "src/core/*.ps1" }
   { "name": "utility_functions", "source": "src/utils/*.ps1" }
   ```

2. **Group related files** together:
   ```json
   { "name": "authentication_module", "source": "auth/*.ps1", "destination": "lib/auth" }
   { "name": "logging_module", "source": "logging/*.ps1", "destination": "lib/logging" }
   ```

3. **Use consistent exclusion patterns**:
   ```json
   "exclude": ["*test*", "*backup*", "*.tmp", "*debug*"]
   ```

### Dependency Management

1. **Start with main entry points** in auto-analysis:
   ```powershell
   -StartingFiles @("Install.ps1", "Uninstall.ps1", "Configure.ps1")
   ```

2. **Include search paths** for shared libraries:
   ```powershell
   -SearchPaths @(".", "./lib", "./shared", "./modules")
   ```

3. **Review unresolved dependencies** before packaging

### Packaging Strategies

1. **Development packages**: Include debug files and documentation
   ```json
   { "exclude": ["*secret*"] }  // Only exclude secrets
   ```

2. **Production packages**: Exclude development artifacts
   ```json
   { "exclude": ["*test*", "*debug*", "*dev*", "*.tmp", "*backup*"] }
   ```

3. **Distribution packages**: Include installation documentation
   ```json
   {
     "post_package": [
       { "type": "create_file", "path": "INSTALL.md", "content": "..." },
       { "type": "zip_package", "name": "my-package-v1.0" }
     ]
   }
   ```

### Version Management

1. **Use semantic versioning**: `major.minor.patch`
2. **Include build metadata** in post-package actions
3. **Tag packages** with descriptive labels
4. **Document changes** in generated files

## Troubleshooting

### Common Issues

#### "Configuration file not found"
```powershell
# Check file path
Test-Path "my-config.json"

# Use absolute path if needed
.\json_packager_system.ps1 -ConfigPath "C:\Projects\MyProject\config.json"
```

#### "Failed to parse JSON configuration"
```powershell
# Validate JSON syntax
Get-Content "config.json" | ConvertFrom-Json

# Use schema validation
.\Compare-ToJsonSchema.ps1 -JsonPath "config.json" -SchemaPath "json_packager_schema.json"
```

#### "No files found matching pattern"
```powershell
# Test file patterns
Get-ChildItem -Path "*.ps1"
Get-ChildItem -Path "lib/*.ps1" -Recurse

# Check exclusion patterns
Get-ChildItem -Path "*.ps1" | Where-Object { $_.Name -notlike "*test*" }
```

#### "Unresolved dependencies found"
```powershell
# Review dependency analysis output
.\json_packager_system.ps1 -StartingFiles @("Main.ps1") -Mode AnalyzeDependencies

# Check search paths
.\json_packager_system.ps1 -StartingFiles @("Main.ps1") -SearchPaths @(".", "./lib", "./modules") -Mode AnalyzeDependencies
```

### Debugging Tips

1. **Use DryRun mode** to preview operations:
   ```powershell
   .\json_packager_system.ps1 -ConfigPath "config.json" -DryRun
   ```

2. **Check generated configurations** in auto-package mode:
   ```powershell
   .\json_packager_system.ps1 -StartingFiles @("Main.ps1") -Mode AutoPackage
   # Check the auto-generated-package.json file
   ```

3. **Validate configurations** before packaging:
   ```powershell
   .\Compare-ToJsonSchema.ps1 -JsonPath "config.json" -SchemaPath "json_packager_schema.json"
   ```

### Performance Issues

1. **Limit search scope** with specific patterns:
   ```json
   { "source": "src/core/*.ps1" }  // Instead of "**/*.ps1"
   ```

2. **Use exclusion patterns** to skip large directories:
   ```json
   { "exclude": ["**/node_modules/**", "**/bin/**", "**/obj/**"] }
   ```

3. **Test with small file sets** first

## Schema Validation

The packager includes JSON schema validation to ensure configuration correctness:

### Validating Configurations

```powershell
# Validate a configuration file
.\Compare-ToJsonSchema.ps1 -JsonPath "my-config.json" -SchemaPath "json_packager_schema.json"

# Get detailed validation results
.\Compare-ToJsonSchema.ps1 -JsonPath "my-config.json" -SchemaPath "json_packager_schema.json" -OutputFormat Detailed
```

### Schema Features

The JSON schema validates:
- **Required properties**: `package.name`, `package.version`, `files`
- **Data types**: Strings, arrays, objects, booleans
- **Patterns**: Semantic version format (`1.2.3` or `1.2.3-beta.1`)
- **Constraints**: Array minimum items, string minimum length
- **Enums**: Valid values for `post_package.type`, etc.

### Common Validation Errors

1. **Missing required properties**:
   ```json
   // ❌ Invalid - missing version
   { "package": { "name": "Test" } }
   
   // ✅ Valid  
   { "package": { "name": "Test", "version": "1.0.0" } }
   ```

2. **Invalid version format**:
   ```json
   // ❌ Invalid version
   { "package": { "version": "1.0" } }
   
   // ✅ Valid version
   { "package": { "version": "1.0.0" } }
   ```

3. **Empty required arrays**:
   ```json
   // ❌ Invalid - empty files array
   { "files": [] }
   
   // ✅ Valid - at least one file group
   { "files": [{ "name": "scripts", "source": "*.ps1", "destination": "scripts" }] }
   ```

---

## Advanced Topics

### Creating Package Templates

Generate reusable configuration templates:

```powershell
# Create minimal template
.\json_packager_system.ps1 -Mode CreateTemplate -PackageName "My Project" -OutputPath "template.json" -Minimal

# Create comprehensive template  
.\json_packager_system.ps1 -Mode CreateTemplate -PackageName "My Project" -OutputPath "template.json"
```

### Integration with CI/CD

Example Azure DevOps pipeline step:

```yaml
- task: PowerShell@2
  displayName: 'Package PowerShell Tools'
  inputs:
    targetType: 'inline'
    script: |
      .\json_packager_system.ps1 -ConfigPath "build-config.json" -OutputPath "$(Build.ArtifactStagingDirectory)" -Force
      
      if ($LASTEXITCODE -ne 0) {
        throw "Packaging failed"
      }
```

### Custom Post-Package Scripts

Example post-package script for signing:

```powershell
# post-package-sign.ps1
param([string]$PackagePath)

Write-Host "Signing PowerShell scripts in: $PackagePath"

Get-ChildItem -Path $PackagePath -Filter "*.ps1" -Recurse | ForEach-Object {
    Set-AuthenticodeSignature -FilePath $_.FullName -Certificate $cert
}
```

Configuration:
```json
{
  "post_package": [
    {
      "type": "run_script",
      "script": "./post-package-sign.ps1"
    }
  ]
}
```

---

The PowerShell JSON Packager System provides a powerful, flexible foundation for automating PowerShell project deployment. Its dependency analysis capabilities and comprehensive configuration options make it suitable for projects ranging from simple script collections to complex enterprise tools.

For additional help and examples, see the included test configurations in `test-configurations.json` and the comprehensive test suite in the `*.Tests.ps1` files.