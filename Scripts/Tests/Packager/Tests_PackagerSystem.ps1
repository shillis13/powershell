#Requires -Modules Pester

#========================================
# PackagerSystem.Tests.ps1
# Pester tests for the main PowerShell packaging system functionality
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
    
    # Set up test environment
    $Global:TestBaseDir = Get-TestTempDirectory -Prefix "PackagerSystemTest"
    Write-Host "Test directory: $Global:TestBaseDir" -ForegroundColor Green
}

AfterAll {
    # Clean up test environment
    if ($Global:TestBaseDir -and (Test-Path $Global:TestBaseDir)) {
        Remove-TestDirectory -Path $Global:TestBaseDir
    }
}

Describe "Read-PackageConfig" {
    Context "Valid JSON configurations" {
        BeforeAll {
            $Script:BasicConfigPath = Join-Path $Global:TestBaseDir "basic-config.json"
            New-TestPackageConfig -OutputPath $Script:BasicConfigPath -ConfigType "Basic"
        }
        
        It "Should load valid JSON configuration successfully" {
            $config = Read-PackageConfig -ConfigPath $Script:BasicConfigPath
            
            $config | Should -Not -BeNullOrEmpty
            $config.package | Should -Not -BeNullOrEmpty
            $config.files | Should -Not -BeNullOrEmpty
            $config.package.name | Should -Be "Test Package"
        }
        
        It "Should convert PSCustomObject to hashtable" {
            $config = Read-PackageConfig -ConfigPath $Script:BasicConfigPath
            
            $config | Should -BeOfType [hashtable]
            $config.package | Should -BeOfType [hashtable]
            $config.files | Should -BeOfType [array]
        }
        
        It "Should validate required sections" {
            $config = Read-PackageConfig -ConfigPath $Script:BasicConfigPath
            
            $config.ContainsKey('package') | Should -Be $true
            $config.ContainsKey('files') | Should -Be $true
        }
    }
    
    Context "Invalid configurations" {
        It "Should return null for non-existent file" {
            $nonExistentPath = Join-Path $Global:TestBaseDir "non-existent.json"
            
            $config = Read-PackageConfig -ConfigPath $nonExistentPath
            
            $config | Should -BeNullOrEmpty
        }
        
        It "Should return null for invalid JSON" {
            $invalidJsonPath = Join-Path $Global:TestBaseDir "invalid.json"
            "{ invalid json content" | Out-File -FilePath $invalidJsonPath -Encoding UTF8
            
            $config = Read-PackageConfig -ConfigPath $invalidJsonPath
            
            $config | Should -BeNullOrEmpty
        }
        
        It "Should return null for missing required sections" {
            $incompleteConfigPath = Join-Path $Global:TestBaseDir "incomplete.json"
            @{ package = @{ name = "Test" } } | ConvertTo-Json | Out-File -FilePath $incompleteConfigPath -Encoding UTF8
            
            $config = Read-PackageConfig -ConfigPath $incompleteConfigPath
            
            $config | Should -BeNullOrEmpty
        }
    }
}

Describe "ConvertTo-ConfigHashtable" {
    Context "Object conversion" {
        It "Should convert PSCustomObject to hashtable" {
            $jsonString = '{"name": "test", "values": [1, 2, 3], "nested": {"key": "value"}}'
            $psObject = $jsonString | ConvertFrom-Json
            
            $hashtable = ConvertTo-ConfigHashtable -InputObject $psObject
            
            $hashtable | Should -BeOfType [hashtable]
            $hashtable.name | Should -Be "test"
            $hashtable.values | Should -BeOfType [array]
            $hashtable.nested | Should -BeOfType [hashtable]
        }
        
        It "Should handle arrays correctly" {
            $array = @(
                [PSCustomObject]@{ name = "item1"; value = 1 },
                [PSCustomObject]@{ name = "item2"; value = 2 }
            )
            
            $result = ConvertTo-ConfigHashtable -InputObject $array
            
            $result | Should -BeOfType [array]
            $result.Count | Should -Be 2
            $result[0] | Should -BeOfType [hashtable]
            $result[0].name | Should -Be "item1"
        }
        
        It "Should handle null values" {
            $result = ConvertTo-ConfigHashtable -InputObject $null
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should preserve primitive values" {
            ConvertTo-ConfigHashtable -InputObject "string" | Should -Be "string"
            ConvertTo-ConfigHashtable -InputObject 42 | Should -Be 42
            ConvertTo-ConfigHashtable -InputObject $true | Should -Be $true
        }
    }
}

Describe "New-PackageConfigTemplate" {
    Context "Template generation" {
        It "Should create minimal template" {
            $templatePath = Join-Path $Global:TestBaseDir "minimal-template.json"
            
            $template = New-PackageConfigTemplate -OutputPath $templatePath -PackageName "MinimalTest" -Version "1.0.0" -Minimal
            
            Test-Path $templatePath | Should -Be $true
            $template.package.name | Should -Be "MinimalTest"
            $template.files.Count | Should -Be 1
            $template.ContainsKey('post_package') | Should -Be $false
        }
        
        It "Should create comprehensive template" {
            $templatePath = Join-Path $Global:TestBaseDir "comprehensive-template.json"
            
            $template = New-PackageConfigTemplate -OutputPath $templatePath -PackageName "ComprehensiveTest" -Version "2.0.0"
            
            Test-Path $templatePath | Should -Be $true
            $template.package.name | Should -Be "ComprehensiveTest"
            $template.files.Count | Should -BeGreaterThan 1
            $template.ContainsKey('directories') | Should -Be $true
            $template.ContainsKey('post_package') | Should -Be $true
        }
        
        It "Should generate valid JSON content" {
            $templatePath = Join-Path $Global:TestBaseDir "valid-template.json"
            
            New-PackageConfigTemplate -OutputPath $templatePath -PackageName "ValidTest" | Out-Null
            
            # Should be able to read back as valid JSON
            $content = Get-Content $templatePath -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }
    }
}

Describe "New-DirectoryStructure" {
    Context "Directory creation" {
        BeforeAll {
            $Script:ComplexConfigPath = Join-Path $Global:TestBaseDir "complex-config.json"
            New-TestPackageConfig -OutputPath $Script:ComplexConfigPath -ConfigType "Complex"
            $Script:ComplexConfig = Read-PackageConfig -ConfigPath $Script:ComplexConfigPath
        }
        
        It "Should create base directory" {
            $outputPath = Join-Path $Global:TestBaseDir "package-output"
            
            $result = New-DirectoryStructure -BasePath $outputPath -Config $Script:ComplexConfig -Force
            
            $result | Should -Be $true
            Test-Path $outputPath | Should -Be $true
        }
        
        It "Should create directories from file destinations" {
            $outputPath = Join-Path $Global:TestBaseDir "package-dirs"
            
            New-DirectoryStructure -BasePath $outputPath -Config $Script:ComplexConfig -Force | Out-Null
            
            # Check that directories from file destinations are created
            foreach ($fileGroup in $Script:ComplexConfig.files) {
                $expectedDir = Join-Path $outputPath $fileGroup.destination
                if ($fileGroup.destination) {  # Skip empty destinations
                    Test-Path $expectedDir | Should -Be $true
                }
            }
        }
        
        It "Should create explicit directories" {
            $outputPath = Join-Path $Global:TestBaseDir "explicit-dirs"
            
            New-DirectoryStructure -BasePath $outputPath -Config $Script:ComplexConfig -Force | Out-Null
            
            # Check explicit directories
            foreach ($dir in $Script:ComplexConfig.directories) {
                $expectedDir = Join-Path $outputPath $dir
                Test-Path $expectedDir | Should -Be $true
            }
        }
        
        It "Should handle Force parameter correctly" {
            $outputPath = Join-Path $Global:TestBaseDir "force-test"
            
            # Create directory first
            New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
            "existing content" | Out-File -FilePath "$outputPath\existing.txt"
            
            # Should succeed with Force
            $result = New-DirectoryStructure -BasePath $outputPath -Config $Script:ComplexConfig -Force
            $result | Should -Be $true
        }
    }
}

Describe "Process-FileGroup" {
    Context "File processing" {
        BeforeAll {
            # Create source files for testing
            $Script:SourceDir = Join-Path $Global:TestBaseDir "source"
            New-Item -Path $Script:SourceDir -ItemType Directory -Force | Out-Null
            
            # Create test PowerShell files
            "# Test script 1" | Out-File -FilePath "$Script:SourceDir\test1.ps1" -Encoding UTF8
            "# Test script 2" | Out-File -FilePath "$Script:SourceDir\test2.ps1" -Encoding UTF8
            "# Backup script" | Out-File -FilePath "$Script:SourceDir\backup.ps1" -Encoding UTF8
            
            # Create lib subdirectory
            New-Item -Path "$Script:SourceDir\lib" -ItemType Directory -Force | Out-Null
            "# Library script" | Out-File -FilePath "$Script:SourceDir\lib\library.ps1" -Encoding UTF8
            
            # Set up working directory
            Push-Location $Script:SourceDir
        }
        
        AfterAll {
            Pop-Location
        }
        
        It "Should process wildcard patterns" {
            $outputPath = Join-Path $Global:TestBaseDir "wildcard-output"
            New-Item -Path "$outputPath\scripts" -ItemType Directory -Force | Out-Null
            
            $fileGroup = @{
                name = "test_scripts"
                source = "*.ps1"
                destination = "scripts"
                preserve_structure = $false
            }
            
            $result = Process-FileGroup -FileGroup $fileGroup -BasePath $outputPath
            
            $result.GroupName | Should -Be "test_scripts"
            $result.FilesProcessed | Should -Be 3  # test1.ps1, test2.ps1, backup.ps1
            $result.SuccessCount | Should -Be 3
            
            # Check that files were copied
            Test-Path "$outputPath\scripts\test1.ps1" | Should -Be $true
            Test-Path "$outputPath\scripts\test2.ps1" | Should -Be $true
        }
        
        It "Should respect exclude patterns" {
            $outputPath = Join-Path $Global:TestBaseDir "exclude-output"
            New-Item -Path "$outputPath\scripts" -ItemType Directory -Force | Out-Null
            
            $fileGroup = @{
                name = "filtered_scripts"
                source = "*.ps1"
                destination = "scripts"
                preserve_structure = $false
                exclude = @("*backup*")
            }
            
            $result = Process-FileGroup -FileGroup $fileGroup -BasePath $outputPath
            
            $result.FilesProcessed | Should -Be 2  # Only test1.ps1 and test2.ps1
            Test-Path "$outputPath\scripts\test1.ps1" | Should -Be $true
            Test-Path "$outputPath\scripts\backup.ps1" | Should -Be $false
        }
        
        It "Should handle preserve_structure option" {
            $outputPath = Join-Path $Global:TestBaseDir "preserve-output"
            New-Item -Path "$outputPath\lib" -ItemType Directory -Force | Out-Null
            
            $fileGroup = @{
                name = "lib_scripts"
                source = "lib\*.ps1"
                destination = "lib"
                preserve_structure = $true
            }
            
            $result = Process-FileGroup -FileGroup $fileGroup -BasePath $outputPath
            
            $result.FilesProcessed | Should -Be 1
            Test-Path "$outputPath\lib\library.ps1" | Should -Be $true
        }
        
        It "Should handle flatten option" {
            $outputPath = Join-Path $Global:TestBaseDir "flatten-output"
            New-Item -Path "$outputPath\scripts" -ItemType Directory -Force | Out-Null
            
            $fileGroup = @{
                name = "flattened_scripts"
                source = "lib\*.ps1"
                destination = "scripts"
                flatten = $true
            }
            
            $result = Process-FileGroup -FileGroup $fileGroup -BasePath $outputPath
            
            $result.FilesProcessed | Should -Be 1
            Test-Path "$outputPath\scripts\library.ps1" | Should -Be $true
        }
        
        It "Should handle DryRun mode" {
            $outputPath = Join-Path $Global:TestBaseDir "dryrun-output"
            New-Item -Path "$outputPath\scripts" -ItemType Directory -Force | Out-Null
            
            $fileGroup = @{
                name = "dryrun_scripts"
                source = "*.ps1"
                destination = "scripts"
                preserve_structure = $false
            }
            
            $result = Process-FileGroup -FileGroup $fileGroup -BasePath $outputPath -DryRun
            
            $result.FilesProcessed | Should -Be 3
            $result.SuccessCount | Should -Be 3
            
            # Files should not actually be copied in dry run
            Test-Path "$outputPath\scripts\test1.ps1" | Should -Be $false
        }
    }
}

Describe "Invoke-PackageOperation" {
    Context "Complete packaging operation" {
        BeforeAll {
            # Create a test project
            $Script:TestProject = New-TestProjectStructure -BasePath $Global:TestBaseDir -ProjectName "PackageTest"
            
            # Create package config for this project
            $Script:PackageConfigPath = Join-Path $Global:TestBaseDir "package-test-config.json"
            $packageConfig = @{
                package = @{
                    name = "Package Test"
                    version = "1.0.0"
                    description = "Test package for packaging operation"
                }
                directories = @("scripts", "lib", "docs")
                files = @(
                    @{
                        name = "main_scripts"
                        source = "*.ps1"
                        destination = "scripts"
                        preserve_structure = $false
                    },
                    @{
                        name = "lib_scripts"
                        source = "lib\*.ps1"
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
                        path = "INSTALL.txt"
                        content = "Installation instructions here"
                    }
                )
            }
            $packageConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $Script:PackageConfigPath -Encoding UTF8
            $Script:LoadedConfig = Read-PackageConfig -ConfigPath $Script:PackageConfigPath
            
            # Set working directory to test project
            Push-Location $Script:TestProject.ProjectPath
        }
        
        AfterAll {
            Pop-Location
        }
        
        It "Should execute complete packaging operation successfully" {
            $outputPath = Join-Path $Global:TestBaseDir "complete-package"
            
            $result = Invoke-PackageOperation -Config $Script:LoadedConfig -OutputPath $outputPath -Force
            
            $result.Success | Should -Be $true
            $result.TotalFiles | Should -BeGreaterThan 0
            $result.SuccessCount | Should -Be $result.TotalFiles
            Test-Path $outputPath | Should -Be $true
        }
        
        It "Should create correct directory structure" {
            $outputPath = Join-Path $Global:TestBaseDir "structure-package"
            
            Invoke-PackageOperation -Config $Script:LoadedConfig -OutputPath $outputPath -Force | Out-Null
            
            # Check directories were created
            Test-Path "$outputPath\scripts" | Should -Be $true
            Test-Path "$outputPath\lib" | Should -Be $true
            Test-Path "$outputPath\docs" | Should -Be $true
        }
        
        It "Should copy files to correct locations" {
            $outputPath = Join-Path $Global:TestBaseDir "files-package"
            
            Invoke-PackageOperation -Config $Script:LoadedConfig -OutputPath $outputPath -Force | Out-Null
            
            # Check that main script was copied to scripts directory
            Test-Path "$outputPath\scripts\Main.ps1" | Should -Be $true
            
            # Check that lib scripts were copied with structure preserved
            Test-Path "$outputPath\lib\Config.ps1" | Should -Be $true
            Test-Path "$outputPath\lib\Logging.ps1" | Should -Be $true
            
            # Check that README was copied to docs
            Test-Path "$outputPath\docs\README.md" | Should -Be $true
        }
        
        It "Should execute post-package actions" {
            $outputPath = Join-Path $Global:TestBaseDir "postaction-package"
            
            Invoke-PackageOperation -Config $Script:LoadedConfig -OutputPath $outputPath -Force | Out-Null
            
            # Check that post-package file was created
            Test-Path "$outputPath\INSTALL.txt" | Should -Be $true
            $content = Get-Content "$outputPath\INSTALL.txt" -Raw
            $content | Should -Match "Installation instructions"
        }
        
        It "Should create package manifest" {
            $outputPath = Join-Path $Global:TestBaseDir "manifest-package"
            
            Invoke-PackageOperation -Config $Script:LoadedConfig -OutputPath $outputPath -Force | Out-Null
            
            # Check that manifest was created
            Test-Path "$outputPath\package-manifest.json" | Should -Be $true
            
            $manifest = Get-Content "$outputPath\package-manifest.json" | ConvertFrom-Json
            $manifest.package.name | Should -Be "Package Test"
            $manifest.files | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle DryRun mode correctly" {
            $outputPath = Join-Path $Global:TestBaseDir "dryrun-package"
            
            $result = Invoke-PackageOperation -Config $Script:LoadedConfig -OutputPath $outputPath -DryRun
            
            $result.TotalFiles | Should -BeGreaterThan 0
            
            # Directory should not be created in dry run
            Test-Path $outputPath | Should -Be $false
        }
    }
}

Describe "New-Package (Main Entry Point)" {
    Context "Package mode" {
        BeforeAll {
            # Create test project and config
            $Script:TestProject = New-TestProjectStructure -BasePath $Global:TestBaseDir -ProjectName "MainTest"
            $Script:MainConfigPath = Join-Path $Global:TestBaseDir "main-test-config.json"
            New-TestPackageConfig -OutputPath $Script:MainConfigPath -ConfigType "Basic"
            
            Push-Location $Script:TestProject.ProjectPath
        }
        
        AfterAll {
            Pop-Location
        }
        
        It "Should execute Package mode successfully" {
            $outputPath = Join-Path $Global:TestBaseDir "main-package"
            
            $result = New-Package -ConfigPath $Script:MainConfigPath -OutputPath $outputPath -Mode Package -Force
            
            $result.Success | Should -Be $true
            Test-Path $outputPath | Should -Be $true
        }
        
        It "Should handle AutoAnalyzeDependencies mode" {
            $outputPath = Join-Path $Global:TestBaseDir "auto-package"
            
            $result = New-Package -StartingFiles @($Script:TestProject.MainScript) -OutputPath $outputPath -Mode AutoPackage -Force
            
            $result.Success | Should -Be $true
            $result.DependencyAnalysis | Should -Not -BeNullOrEmpty
            $result.GeneratedConfig | Should -Not -BeNullOrEmpty
            Test-Path $result.GeneratedConfig | Should -Be $true
        }
        
        It "Should handle AnalyzeDependencies mode" {
            $result = New-Package -StartingFiles @($Script:TestProject.MainScript) -Mode AnalyzeDependencies
            
            $result.AllFiles | Should -Not -BeNullOrEmpty
            $result.DependencyGraph | Should -Not -BeNullOrEmpty
            $result.Summary | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Error handling" {
        It "Should throw for missing config file" {
            $nonExistentConfig = Join-Path $Global:TestBaseDir "non-existent-config.json"
            
            { New-Package -ConfigPath $nonExistentConfig -Mode Package } | Should -Throw
        }
        
        It "Should throw for missing starting files in dependency analysis" {
            { New-Package -StartingFiles @() -Mode AnalyzeDependencies } | Should -Throw
        }
    }
}

Describe "Update-DotSourcePaths" {
    Context "Path rewriting for flattened structures" {
        BeforeAll {
            # Create test project with scripts that need path updates
            $Script:FlattenProject = Join-Path $Global:TestBaseDir "FlattenProject"
            New-Item -Path $Script:FlattenProject -ItemType Directory -Force | Out-Null
            
            # Create main script with relative paths
            $mainScript = @"
# Main.ps1 - Script with relative dependencies
. `$PSScriptRoot\lib\Config.ps1
. `$PSScriptRoot\utils\StringHelpers.ps1

function Start-Main {
    return "Main function"
}
"@
            $mainScript | Out-File -FilePath "$Script:FlattenProject\Main.ps1" -Encoding UTF8
            
            # Create target files
            New-Item -Path "$Script:FlattenProject\lib" -ItemType Directory -Force | Out-Null
            "# Config.ps1" | Out-File -FilePath "$Script:FlattenProject\lib\Config.ps1" -Encoding UTF8
            
            New-Item -Path "$Script:FlattenProject\utils" -ItemType Directory -Force | Out-Null
            "# StringHelpers.ps1" | Out-File -FilePath "$Script:FlattenProject\utils\StringHelpers.ps1" -Encoding UTF8
            
            # Create package with flattening
            $Script:PackageConfig = @{
                package = @{ name = "Flatten Test"; version = "1.0.0" }
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
            
            # Package the files first
            Push-Location $Script:FlattenProject
            $Script:PackageOutput = Join-Path $Global:TestBaseDir "flatten-package"
            Invoke-PackageOperation -Config $Script:PackageConfig -OutputPath $Script:PackageOutput -Force | Out-Null
            Pop-Location
        }
        
        It "Should update dot-source paths correctly" {
            $result = Update-DotSourcePaths -PackageConfig $Script:PackageConfig -PackagePath $Script:PackageOutput -CreateBackups
            
            $result.Success | Should -Be $true
            $result.PathsUpdated | Should -BeGreaterThan 0
            $result.ScriptsUpdated | Should -BeGreaterThan 0
        }
        
        It "Should create backup files when requested" {
            Update-DotSourcePaths -PackageConfig $Script:PackageConfig -PackagePath $Script:PackageOutput -CreateBackups | Out-Null
            
            # Should have backup files
            $backupFiles = Get-ChildItem -Path $Script:PackageOutput -Filter "*.backup" -Recurse
            $backupFiles.Count | Should -BeGreaterThan 0
        }
        
        It "Should handle DryRun mode" {
            $result = Update-DotSourcePaths -PackageConfig $Script:PackageConfig -PackagePath $Script:PackageOutput -DryRun
            
            $result.Success | Should -Be $true
            # In dry run, no actual changes should be made
        }
        
        It "Should preserve file content structure" {
            Update-DotSourcePaths -PackageConfig $Script:PackageConfig -PackagePath $Script:PackageOutput | Out-Null
            
            $updatedContent = Get-Content "$Script:PackageOutput\scripts\Main.ps1" -Raw
            $updatedContent | Should -Match "function Start-Main"
            $updatedContent | Should -Match "\. .*Config\.ps1"
            $updatedContent | Should -Match "\. .*StringHelpers\.ps1"
        }
    }
}