#Requires -Modules Pester

#========================================
# DependencyAnalysis.Tests.ps1
# Pester tests for PowerShell script dependency analysis functionality
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
    $Global:TestBaseDir = Get-TestTempDirectory -Prefix "DepAnalysisTest"
    Write-Host "Test directory: $Global:TestBaseDir" -ForegroundColor Green
}

AfterAll {
    # Clean up test environment
    if ($Global:TestBaseDir -and (Test-Path $Global:TestBaseDir)) {
        Remove-TestDirectory -Path $Global:TestBaseDir
    }
}

Describe "Find-ScriptDependencies" {
    Context "Simple dependency chain" {
        BeforeAll {
            $Script:TestProject = New-TestProjectStructure -BasePath $Global:TestBaseDir -ProjectName "SimpleDeps"
        }
        
        It "Should discover all files in dependency chain" {
            $result = Find-ScriptDependencies -StartingFiles @($Script:TestProject.MainScript) -SearchPaths @($Script:TestProject.ProjectPath)
            
            $result | Should -Not -BeNullOrEmpty
            $result.AllFiles | Should -Not -BeNullOrEmpty
            $result.AllFiles.Count | Should -BeGreaterThan 1
            
            # Should find main script and its dependencies
            $result.AllFiles | Should -Contain $Script:TestProject.MainScript
            
            # Check that key dependencies are found
            $libConfigPath = Join-Path $Script:TestProject.ProjectPath "lib\Config.ps1"
            $result.AllFiles | Should -Contain $libConfigPath
        }
        
        It "Should build correct dependency graph" {
            $result = Find-ScriptDependencies -StartingFiles @($Script:TestProject.MainScript) -SearchPaths @($Script:TestProject.ProjectPath)
            
            $result.DependencyGraph | Should -Not -BeNullOrEmpty
            $result.DependencyGraph.ContainsKey($Script:TestProject.MainScript) | Should -Be $true
            
            $mainScriptDeps = $result.DependencyGraph[$Script:TestProject.MainScript].Dependencies
            $mainScriptDeps | Should -Not -BeNullOrEmpty
            $mainScriptDeps.Count | Should -BeGreaterThan 0
            
            # Should have dot-source dependencies
            $dotSourceDeps = $mainScriptDeps | Where-Object { $_.Type -eq 'DotSource' }
            $dotSourceDeps | Should -Not -BeNullOrEmpty
        }
        
        It "Should resolve relative paths correctly" {
            $result = Find-ScriptDependencies -StartingFiles @($Script:TestProject.MainScript) -SearchPaths @($Script:TestProject.ProjectPath)
            
            $mainScriptDeps = $result.DependencyGraph[$Script:TestProject.MainScript].Dependencies
            $resolvedDeps = $mainScriptDeps | Where-Object { $_.ResolutionStatus -eq 'Resolved' }
            
            $resolvedDeps | Should -Not -BeNullOrEmpty
            $resolvedDeps.Count | Should -BeGreaterThan 0
            
            # All resolved dependencies should have valid ResolvedPath
            foreach ($dep in $resolvedDeps) {
                $dep.ResolvedPath | Should -Not -BeNullOrEmpty
                Test-Path $dep.ResolvedPath | Should -Be $true
            }
        }
        
        It "Should generate accurate summary information" {
            $result = Find-ScriptDependencies -StartingFiles @($Script:TestProject.MainScript) -SearchPaths @($Script:TestProject.ProjectPath)
            
            $result.Summary | Should -Not -BeNullOrEmpty
            $result.Summary.TotalFiles | Should -Be $result.AllFiles.Count
            $result.Summary.StartingFiles | Should -Contain $Script:TestProject.MainScript
            $result.Summary.SearchPaths | Should -Contain $Script:TestProject.ProjectPath
            $result.Summary.AnalysisDate | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Unresolved dependencies" {
        BeforeAll {
            $Script:UnresolvedProject = New-TestProjectStructure -BasePath $Global:TestBaseDir -ProjectName "UnresolvedDeps" -IncludeUnresolvedDeps
        }
        
        It "Should identify unresolved dependencies" {
            $result = Find-ScriptDependencies -StartingFiles @($Script:UnresolvedProject.MainScript) -SearchPaths @($Script:UnresolvedProject.ProjectPath)
            
            # Find dependencies with 'NotFound' status
            $allDeps = @()
            foreach ($file in $result.DependencyGraph.Keys) {
                $allDeps += $result.DependencyGraph[$file].Dependencies
            }
            
            $unresolvedDeps = $allDeps | Where-Object { $_.ResolutionStatus -eq 'NotFound' }
            $unresolvedDeps | Should -Not -BeNullOrEmpty
            $unresolvedDeps.Count | Should -BeGreaterThan 0
            
            # Should have null ResolvedPath for unresolved dependencies
            foreach ($dep in $unresolvedDeps) {
                $dep.ResolvedPath | Should -BeNullOrEmpty
                $dep.OriginalPath | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Variable-based paths" {
        BeforeAll {
            $Script:VariableProject = New-TestProjectStructure -BasePath $Global:TestBaseDir -ProjectName "VariablePaths" -IncludeVariablePaths
        }
        
        It "Should identify variable-based dependencies" {
            $result = Find-ScriptDependencies -StartingFiles @($Script:VariableProject.MainScript) -SearchPaths @($Script:VariableProject.ProjectPath)
            
            # Find dependencies with 'Variable' status
            $allDeps = @()
            foreach ($file in $result.DependencyGraph.Keys) {
                $allDeps += $result.DependencyGraph[$file].Dependencies
            }
            
            $variableDeps = $allDeps | Where-Object { $_.ResolutionStatus -eq 'Variable' }
            $variableDeps | Should -Not -BeNullOrEmpty
            
            # Should identify variable patterns
            foreach ($dep in $variableDeps) {
                $dep.OriginalPath | Should -Match '\$'
            }
        }
    }
    
    Context "Multiple search paths" {
        BeforeAll {
            # Create additional search path with shared utilities
            $Script:SharedUtilsPath = Join-Path $Global:TestBaseDir "SharedUtils"
            New-Item -Path $Script:SharedUtilsPath -ItemType Directory -Force | Out-Null
            
            $sharedScript = @"
# SharedUtility.ps1 - Shared across projects
function Get-SharedFunction {
    return "Shared functionality"
}
"@
            $sharedScript | Out-File -FilePath "$Script:SharedUtilsPath\SharedUtility.ps1" -Encoding UTF8
            
            # Create test project that references shared utility
            $Script:MultiPathProject = New-TestProjectStructure -BasePath $Global:TestBaseDir -ProjectName "MultiPath"
            
            # Add reference to shared utility in main script
            $mainContent = Get-Content $Script:MultiPathProject.MainScript -Raw
            $mainContent += "`n. `$PSScriptRoot\..\SharedUtils\SharedUtility.ps1"
            $mainContent | Out-File -FilePath $Script:MultiPathProject.MainScript -Encoding UTF8
        }
        
        It "Should find dependencies across multiple search paths" {
            $searchPaths = @($Script:MultiPathProject.ProjectPath, $Script:SharedUtilsPath)
            $result = Find-ScriptDependencies -StartingFiles @($Script:MultiPathProject.MainScript) -SearchPaths $searchPaths
            
            $sharedUtilPath = Join-Path $Script:SharedUtilsPath "SharedUtility.ps1"
            $result.AllFiles | Should -Contain $sharedUtilPath
        }
    }
    
    Context "Circular dependencies" {
        BeforeAll {
            $Script:CircularProject = New-TestProjectWithCircularDeps -BasePath $Global:TestBaseDir
        }
        
        It "Should handle circular dependencies gracefully" {
            # This should not hang or crash
            $result = Find-ScriptDependencies -StartingFiles @($Script:CircularProject.ScriptA) -SearchPaths @($Script:CircularProject.ProjectPath) -MaxDepth 5
            
            $result | Should -Not -BeNullOrEmpty
            $result.AllFiles | Should -Contain $Script:CircularProject.ScriptA
            $result.AllFiles | Should -Contain $Script:CircularProject.ScriptB
        }
        
        It "Should respect MaxDepth parameter" {
            $result = Find-ScriptDependencies -StartingFiles @($Script:CircularProject.ScriptA) -SearchPaths @($Script:CircularProject.ProjectPath) -MaxDepth 2
            
            # Should still find both files but limit recursion depth
            $result.AllFiles | Should -Contain $Script:CircularProject.ScriptA
            $result.AllFiles | Should -Contain $Script:CircularProject.ScriptB
            
            # Check that depth was respected in analysis
            foreach ($file in $result.DependencyGraph.Keys) {
                $fileInfo = $result.DependencyGraph[$file]
                $fileInfo.AnalyzedDepth | Should -BeLessOrEqual 2
            }
        }
    }
}

Describe "Resolve-ScriptPath" {
    Context "Path resolution" {
        BeforeAll {
            $Script:TestProject = New-TestProjectStructure -BasePath $Global:TestBaseDir -ProjectName "PathResolution"
        }
        
        It "Should resolve relative paths correctly" {
            $sourceFile = $Script:TestProject.MainScript
            $referencedPath = "lib\Config.ps1"
            $searchPaths = @($Script:TestProject.ProjectPath)
            
            $resolved = Resolve-ScriptPath -SourceFile $sourceFile -ReferencedPath $referencedPath -SearchPaths $searchPaths
            
            $resolved | Should -Not -BeNullOrEmpty
            Test-Path $resolved | Should -Be $true
            $resolved | Should -Match "Config\.ps1$"
        }
        
        It "Should handle absolute paths" {
            $sourceFile = $Script:TestProject.MainScript
            $configPath = Join-Path $Script:TestProject.ProjectPath "lib\Config.ps1"
            $searchPaths = @($Script:TestProject.ProjectPath)
            
            $resolved = Resolve-ScriptPath -SourceFile $sourceFile -ReferencedPath $configPath -SearchPaths $searchPaths
            
            $resolved | Should -Be $configPath
        }
        
        It "Should return null for non-existent paths" {
            $sourceFile = $Script:TestProject.MainScript
            $referencedPath = "NonExistent\File.ps1"
            $searchPaths = @($Script:TestProject.ProjectPath)
            
            $resolved = Resolve-ScriptPath -SourceFile $sourceFile -ReferencedPath $referencedPath -SearchPaths $searchPaths
            
            $resolved | Should -BeNullOrEmpty
        }
    }
}

Describe "New-DependencyPackageConfig" {
    Context "Config generation from dependency analysis" {
        BeforeAll {
            $Script:TestProject = New-TestProjectStructure -BasePath $Global:TestBaseDir -ProjectName "ConfigGen"
            $Script:DependencyResult = Find-ScriptDependencies -StartingFiles @($Script:TestProject.MainScript) -SearchPaths @($Script:TestProject.ProjectPath)
        }
        
        It "Should generate valid package configuration" {
            $configPath = Join-Path $Global:TestBaseDir "generated-config.json"
            
            $config = New-DependencyPackageConfig -DependencyResult $Script:DependencyResult -OutputPath $configPath -PackageName "TestGenerated"
            
            # Config file should be created
            Test-Path $configPath | Should -Be $true
            
            # Config should have required sections
            $config | Should -Not -BeNullOrEmpty
            $config.package | Should -Not -BeNullOrEmpty
            $config.files | Should -Not -BeNullOrEmpty
            $config.package.name | Should -Be "TestGenerated"
            $config.package.auto_generated | Should -Be $true
        }
        
        It "Should include dependency metadata" {
            $configPath = Join-Path $Global:TestBaseDir "metadata-config.json"
            
            $config = New-DependencyPackageConfig -DependencyResult $Script:DependencyResult -OutputPath $configPath
            
            $config.dependency_metadata | Should -Not -BeNullOrEmpty
            $config.dependency_metadata.total_files_analyzed | Should -Be $Script:DependencyResult.AllFiles.Count
            $config.dependency_metadata.starting_files | Should -Contain $Script:TestProject.MainScript
        }
        
        It "Should identify unresolved dependencies" {
            # Create project with unresolved dependencies
            $unresolvedProject = New-TestProjectStructure -BasePath $Global:TestBaseDir -ProjectName "UnresolvedForConfig" -IncludeUnresolvedDeps
            $unresolvedResult = Find-ScriptDependencies -StartingFiles @($unresolvedProject.MainScript) -SearchPaths @($unresolvedProject.ProjectPath)
            
            $configPath = Join-Path $Global:TestBaseDir "unresolved-config.json"
            $config = New-DependencyPackageConfig -DependencyResult $unresolvedResult -OutputPath $configPath
            
            $config.dependency_metadata.unresolved_dependencies | Should -Not -BeNullOrEmpty
            $config.dependency_metadata.unresolved_dependencies.Count | Should -BeGreaterThan 0
            
            # Each unresolved dependency should have required properties
            foreach ($unresolved in $config.dependency_metadata.unresolved_dependencies) {
                $unresolved.file | Should -Not -BeNullOrEmpty
                $unresolved.dependency | Should -Not -BeNullOrEmpty
                $unresolved.line | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe "Show-DependencyAnalysis" {
    Context "Analysis display" {
        BeforeAll {
            $Script:TestProject = New-TestProjectStructure -BasePath $Global:TestBaseDir -ProjectName "DisplayTest"
            $Script:DependencyResult = Find-ScriptDependencies -StartingFiles @($Script:TestProject.MainScript) -SearchPaths @($Script:TestProject.ProjectPath)
        }
        
        It "Should display analysis without errors" {
            # This mainly tests that the function runs without throwing exceptions
            { Show-DependencyAnalysis -DependencyResult $Script:DependencyResult } | Should -Not -Throw
        }
    }
}

Describe "Integration scenarios" {
    Context "Real-world project simulation" {
        BeforeAll {
            # Create a more complex project structure
            $Script:ComplexProject = New-TestProjectStructure -BasePath $Global:TestBaseDir -ProjectName "ComplexProject"
            
            # Add additional nested dependencies
            $advancedScript = @"
# Advanced.ps1 - More complex script with multiple dependencies
. `$PSScriptRoot\lib\Config.ps1
. `$PSScriptRoot\lib\Logging.ps1
. `$PSScriptRoot\utils\StringHelpers.ps1

# Import additional module
Import-Module `$PSScriptRoot\lib\DataAccess.ps1 -Force

function Start-AdvancedProcessing {
    [CmdletBinding()]
    param([string]`$InputData)
    
    `$config = Get-ProjectConfig
    Write-Log "Processing: `$InputData" -Level "Info"
    `$formatted = Format-String -Input `$InputData
    
    return Get-TestData -DataType "String"
}

if (`$MyInvocation.InvocationName -ne '.') {
    Start-AdvancedProcessing -InputData `$args[0]
}
"@
            $advancedScript | Out-File -FilePath "$($Script:ComplexProject.ProjectPath)\Advanced.ps1" -Encoding UTF8
        }
        
        It "Should handle complex dependency chains correctly" {
            $advancedScriptPath = Join-Path $Script:ComplexProject.ProjectPath "Advanced.ps1"
            $result = Find-ScriptDependencies -StartingFiles @($advancedScriptPath) -SearchPaths @($Script:ComplexProject.ProjectPath)
            
            # Should find all expected files
            $result.AllFiles.Count | Should -BeGreaterThan 4
            
            # Should identify both dot-source and import dependencies
            $allDeps = @()
            foreach ($file in $result.DependencyGraph.Keys) {
                $allDeps += $result.DependencyGraph[$file].Dependencies
            }
            
            $dotSourceDeps = $allDeps | Where-Object { $_.Type -eq 'DotSource' }
            $dotSourceDeps.Count | Should -BeGreaterThan 0
        }
        
        It "Should generate comprehensive package config for complex project" {
            $advancedScriptPath = Join-Path $Script:ComplexProject.ProjectPath "Advanced.ps1"
            $result = Find-ScriptDependencies -StartingFiles @($advancedScriptPath) -SearchPaths @($Script:ComplexProject.ProjectPath)
            
            $configPath = Join-Path $Global:TestBaseDir "complex-config.json"
            $config = New-DependencyPackageConfig -DependencyResult $result -OutputPath $configPath -PackageName "ComplexProject"
            
            $config.package.name | Should -Be "ComplexProject"
            $config.files.Count | Should -BeGreaterThan 0
            
            # Should include all discovered files in the config
            $config.dependency_metadata.total_files_analyzed | Should -Be $result.AllFiles.Count
        }
    }
}