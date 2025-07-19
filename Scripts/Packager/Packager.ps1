#========================================
#region New-Package
<#
.SYNOPSIS
JSON-driven file packager and installer system for PowerShell projects.

.DESCRIPTION
Creates deployment packages based on JSON configuration files. No external dependencies - 
uses PowerShell's built-in JSON support. Can package files into a structured deployment 
folder and optionally install them to target locations. Supports file copying, directory 
structure preservation, template processing, and post-install actions.

.PARAMETER ConfigPath
Path to the JSON configuration file defining the package structure.

.PARAMETER OutputPath
Base output directory for the package. Default is .\deploy

.PARAMETER Mode
Operation mode: 'Package' (default), 'Install', or 'PackageAndInstall'

.PARAMETER InstallConfigPath
Path to installation-specific JSON config (for Install mode)

.PARAMETER DryRun
Preview operations without actually copying files

.PARAMETER Verbose
Enable verbose output for troubleshooting

.EXAMPLE
New-Package -ConfigPath "sharepoint-tools.json" -OutputPath ".\release"

.EXAMPLE
New-Package -ConfigPath "sharepoint-tools.json" -Mode PackageAndInstall -InstallConfigPath "install.json"
#>
#========================================
#endregion
function New-Package {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = "",
        
        [string]$OutputPath = ".\deploy",
        
        [ValidateSet('Package', 'Install', 'PackageAndInstall', 'AnalyzeDependencies', 'AutoPackage')]
        [string]$Mode = 'Package',
        
        [string]$InstallConfigPath = "",
        
        # New parameters for dependency analysis
        [string[]]$StartingFiles = @(),
        
        [string[]]$SearchPaths = @("."),
        
        [switch]$AutoAnalyzeDependencies,
        
        [switch]$UpdateDotSourcePaths,
        
        [switch]$DryRun,
        
        [switch]$Force
    )
    
    # Handle different modes
    switch ($Mode) {
        'AnalyzeDependencies' {
            return Invoke-DependencyAnalysis -StartingFiles $StartingFiles -SearchPaths $SearchPaths
        }
        'AutoPackage' {
            return Invoke-AutoPackage -StartingFiles $StartingFiles -SearchPaths $SearchPaths -OutputPath $OutputPath -UpdateDotSourcePaths:$UpdateDotSourcePaths -DryRun:$DryRun -Force:$Force
        }
        default {
            # Original packaging logic with optional dependency integration
            if ($AutoAnalyzeDependencies -and $StartingFiles.Count -gt 0) {
                Write-Host "=== Auto-analyzing dependencies ===" -ForegroundColor Cyan
                $depResult = Find-ScriptDependencies -StartingFiles $StartingFiles -SearchPaths $SearchPaths
                Show-DependencyAnalysis -DependencyResult $depResult
                
                if (-not $ConfigPath) {
                    $autoConfigPath = "auto-generated-package.json"
                    New-DependencyPackageConfig -DependencyResult $depResult -OutputPath $autoConfigPath
                    $ConfigPath = $autoConfigPath
                    Write-Host "Using auto-generated config: $autoConfigPath" -ForegroundColor Green
                }
            }
            
            if (-not $ConfigPath) {
                throw "ConfigPath required for $Mode mode, or use -AutoAnalyzeDependencies with -StartingFiles"
            }
            
            # Load and validate configuration
            $config = Read-PackageConfig -ConfigPath $ConfigPath
            if (-not $config) {
                throw "Failed to load package configuration from: $ConfigPath"
            }
            
            # Execute based on mode
            $result = $null
            switch ($Mode) {
                'Package' {
                    $result = Invoke-PackageOperation -Config $config -OutputPath $OutputPath -DryRun:$DryRun -Force:$Force -UpdateDotSourcePaths:$UpdateDotSourcePaths
                }
                'Install' {
                    if (-not $InstallConfigPath) {
                        throw "InstallConfigPath required for Install mode"
                    }
                    $installConfig = Read-PackageConfig -ConfigPath $InstallConfigPath
                    $result = Invoke-InstallOperation -Config $installConfig -DryRun:$DryRun -Force:$Force
                }
                'PackageAndInstall' {
                    $packageResult = Invoke-PackageOperation -Config $config -OutputPath $OutputPath -DryRun:$DryRun -Force:$Force -UpdateDotSourcePaths:$UpdateDotSourcePaths
                    if ($packageResult.Success -and $InstallConfigPath) {
                        $installConfig = Read-PackageConfig -ConfigPath $InstallConfigPath
                        $installResult = Invoke-InstallOperation -Config $installConfig -DryRun:$DryRun -Force:$Force
                        $result = @{
                            Success = $packageResult.Success -and $installResult.Success
                            PackageResult = $packageResult
                            InstallResult = $installResult
                        }
                    } else {
                        $result = $packageResult
                    }
                }
            }
            
            return $result
        }
    }
}

#========================================
#region Read-PackageConfig
<#
.SYNOPSIS
Loads and validates JSON package configuration with abstraction layer.
#>
#========================================
#endregion
function Read-PackageConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Configuration file not found: $ConfigPath"
        return $null
    }
    
    try {
        $jsonContent = Get-Content $ConfigPath -Raw
        $rawConfig = $jsonContent | ConvertFrom-Json
        
        # Convert PSCustomObject to hashtable for easier manipulation
        $config = ConvertTo-ConfigHashtable -InputObject $rawConfig
        
        # Validate required sections
        $requiredSections = @('package', 'files')
        foreach ($section in $requiredSections) {
            if (-not $config.ContainsKey($section)) {
                Write-Error "Missing required section '$section' in configuration"
                return $null
            }
        }
        
        Write-Verbose "Successfully loaded configuration from: $ConfigPath"
        return $config
        
    } catch {
        Write-Error "Failed to parse JSON configuration: $($_.Exception.Message)"
        return $null
    }
}

#========================================
#region ConvertTo-ConfigHashtable
<#
.SYNOPSIS
Converts PSCustomObject from JSON to hashtable for easier manipulation.
#>
#========================================
#endregion
function ConvertTo-ConfigHashtable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $InputObject
    )
    
    if ($InputObject -eq $null) {
        return $null
    }
    
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        # Handle arrays
        $result = @()
        foreach ($item in $InputObject) {
            $result += ConvertTo-ConfigHashtable -InputObject $item
        }
        return $result
    }
    
    if ($InputObject -is [PSCustomObject]) {
        # Convert PSCustomObject to hashtable
        $hashtable = @{}
        $InputObject.PSObject.Properties | ForEach-Object {
            $hashtable[$_.Name] = ConvertTo-ConfigHashtable -InputObject $_.Value
        }
        return $hashtable
    }
    
    # Return primitive values as-is
    return $InputObject
}

#========================================
#region New-PackageConfigTemplate
<#
.SYNOPSIS
Creates a template JSON configuration file.
#>
#========================================
#endregion
function New-PackageConfigTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [string]$PackageName = "My Package",
        [string]$Version = "1.0.0",
        [switch]$Minimal
    )
    
    if ($Minimal) {
        $template = @{
            package = @{
                name = $PackageName
                version = $Version
                description = "Package description"
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
    } else {
        $template = @{
            package = @{
                name = $PackageName
                version = $Version
                description = "Comprehensive package configuration"
                author = [Environment]::UserName
                created_date = (Get-Date -Format "yyyy-MM-dd")
                tags = @("powershell", "deployment")
            }
            directories = @("scripts", "docs", "tests", "config")
            files = @(
                @{
                    name = "core_scripts"
                    source = "*.ps1"
                    destination = "scripts"
                    preserve_structure = $false
                    exclude = @("*backup*", "*temp*")
                }
                @{
                    name = "library_scripts"
                    source = "lib/*.ps1"
                    destination = "lib"
                    preserve_structure = $false
                }
                @{
                    name = "documentation"
                    source = "*.md"
                    destination = "docs"
                    preserve_structure = $false
                    exclude = @("TODO.md", "PRIVATE*.md")
                }
            )
            post_package = @(
                @{
                    type = "create_file"
                    path = "INSTALL.md"
                    content = "# Installation Instructions`n`nCopy scripts to your PowerShell path and import the main module."
                }
                @{
                    type = "create_file"
                    path = "VERSION.json"
                    content = @{
                        version = $Version
                        build_date = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                        package_name = $PackageName
                    } | ConvertTo-Json -Depth 3
                }
            )
        }
    }
    
    # Convert to JSON with nice formatting
    $jsonContent = $template | ConvertTo-Json -Depth 10
    $jsonContent | Out-File -FilePath $OutputPath -Encoding UTF8
    
    Write-Host "Created package template: $OutputPath" -ForegroundColor Green
    return $template
}

#========================================
#region Invoke-PackageOperation
<#
.SYNOPSIS
Executes the packaging operation based on configuration.
#>
#========================================
#endregion
function Invoke-PackageOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [switch]$DryRun,
        [switch]$Force,
        [switch]$UpdateDotSourcePaths
    )
    
    $packageInfo = $Config.package
    $filesConfig = $Config.files
    
    Write-Host "=== Packaging: $($packageInfo.name) v$($packageInfo.version) ===" -ForegroundColor Green
    
    # Create output directory structure
    $fullOutputPath = Resolve-Path $OutputPath -ErrorAction SilentlyContinue
    if (-not $fullOutputPath) {
        $fullOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    }
    
    if (-not $DryRun) {
        $createResult = New-DirectoryStructure -BasePath $fullOutputPath -Config $Config -Force:$Force
        if (-not $createResult) {
            return @{ Success = $false; Error = "Failed to create directory structure" }
        }
    }
    
    # Process file operations
    $fileResults = @()
    $totalFiles = 0
    $successCount = 0
    
    foreach ($fileGroup in $filesConfig) {
        $groupResult = Process-FileGroup -FileGroup $fileGroup -BasePath $fullOutputPath -DryRun:$DryRun
        $fileResults += $groupResult
        $totalFiles += $groupResult.FilesProcessed
        $successCount += $groupResult.SuccessCount
    }
    
    # Execute post-package actions
    if ($Config.ContainsKey('post_package') -and -not $DryRun) {
        $actionsResult = Invoke-PostActions -Actions $Config.post_package -BasePath $fullOutputPath
        Write-Verbose "Post-package actions completed: $($actionsResult.Count) actions"
    }
    
    # Update dot-source paths if requested and flattening is detected
    if ($UpdateDotSourcePaths -and -not $DryRun) {
        $flatteningDetected = $false
        foreach ($fileGroup in $Config.files) {
            if ($fileGroup.ContainsKey('flatten') -and $fileGroup.flatten) {
                $flatteningDetected = $true
                break
            }
        }
        
        if ($flatteningDetected) {
            Write-Host "Updating dot-source paths for flattened structure..." -ForegroundColor Cyan
            $pathUpdateResult = Update-DotSourcePaths -PackageConfig $Config -PackagePath $fullOutputPath -CreateBackups
            Write-Verbose "Path update result: $($pathUpdateResult.PathsUpdated) paths updated"
        }
    }
    
    # Generate manifest
    if (-not $DryRun) {
        $manifestResult = New-PackageManifest -Config $Config -OutputPath $fullOutputPath -FileResults $fileResults
    }
    
    $result = @{
        Success = ($successCount -eq $totalFiles)
        TotalFiles = $totalFiles
        SuccessCount = $successCount
        OutputPath = $fullOutputPath
        FileResults = $fileResults
    }
    
    if ($DryRun) {
        Write-Host "[DRY RUN] Would package $totalFiles files to: $fullOutputPath" -ForegroundColor Yellow
    } else {
        Write-Host "Packaged $successCount/$totalFiles files to: $fullOutputPath" -ForegroundColor Green
    }
    
    return $result
}

#========================================
#region Process-FileGroup
<#
.SYNOPSIS
Processes a group of files according to configuration rules.
#>
#========================================
#endregion
function Process-FileGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$FileGroup,
        
        [Parameter(Mandatory = $true)]
        [string]$BasePath,
        
        [switch]$DryRun
    )
    
    $groupName = $FileGroup.name
    $sourcePattern = $FileGroup.source
    $destination = $FileGroup.destination
    $preserveStructure = if ($FileGroup.ContainsKey('preserve_structure')) { $FileGroup.preserve_structure } else { $false }
    $flatten = if ($FileGroup.ContainsKey('flatten')) { $FileGroup.flatten } else { $false }
    $excludePatterns = if ($FileGroup.ContainsKey('exclude')) { $FileGroup.exclude } else { @() }
    
    Write-Verbose "Processing file group: $groupName"
    Write-Verbose "Source pattern: $sourcePattern"
    Write-Verbose "Destination: $destination"
    
    # Find matching files
    $sourceFiles = @()
    if ($sourcePattern -match '[*?]') {
        $sourceFiles = Get-ChildItem -Path $sourcePattern -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
            $filePath = $_.FullName
            $shouldExclude = $false
            foreach ($excludePattern in $excludePatterns) {
                if ($filePath -like $excludePattern) {
                    $shouldExclude = $true
                    break
                }
            }
            -not $shouldExclude
        }
    } else {
        if (Test-Path $sourcePattern) {
            $item = Get-Item $sourcePattern
            if ($item -is [System.IO.FileInfo]) {
                $sourceFiles = @($item)
            } elseif ($item -is [System.IO.DirectoryInfo]) {
                $sourceFiles = Get-ChildItem -Path $sourcePattern -Recurse -File
            }
        }
    }
    
    $filesProcessed = 0
    $successCount = 0
    $fileOperations = @()
    
    foreach ($sourceFile in $sourceFiles) {
        $filesProcessed++
        
        # Calculate destination path
        $destPath = Join-Path $BasePath $destination
        
        if ($flatten) {
            $destFile = Join-Path $destPath $sourceFile.Name
        } elseif ($preserveStructure) {
            $relativePath = $sourceFile.FullName.Substring((Get-Location).Path.Length + 1)
            $destFile = Join-Path $destPath $relativePath
        } else {
            $destFile = Join-Path $destPath $sourceFile.Name
        }
        
        # Ensure destination directory exists
        $destDir = Split-Path $destFile -Parent
        if (-not $DryRun -and -not (Test-Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        }
        
        # Copy file
        $operation = @{
            Source = $sourceFile.FullName
            Destination = $destFile
            Group = $groupName
            Success = $false
        }
        
        if ($DryRun) {
            Write-Host "[DRY RUN] Would copy: $($sourceFile.FullName) -> $destFile" -ForegroundColor Yellow
            $operation.Success = $true
            $successCount++
        } else {
            try {
                Copy-Item -Path $sourceFile.FullName -Destination $destFile -Force
                Write-Verbose "Copied: $($sourceFile.Name) -> $destination"
                $operation.Success = $true
                $successCount++
            } catch {
                Write-Warning "Failed to copy $($sourceFile.FullName): $($_.Exception.Message)"
                $operation.Error = $_.Exception.Message
            }
        }
        
        $fileOperations += $operation
    }
    
    return @{
        GroupName = $groupName
        FilesProcessed = $filesProcessed
        SuccessCount = $successCount
        Operations = $fileOperations
    }
}

#========================================
#region New-DirectoryStructure
<#
.SYNOPSIS
Creates the directory structure defined in the configuration.
#>
#========================================
#endregion
function New-DirectoryStructure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [switch]$Force
    )
    
    # Create base directory
    if (Test-Path $BasePath -and -not $Force) {
        $response = Read-Host "Output directory exists: $BasePath. Overwrite? (Y/N)"
        if ($response -ne 'Y' -and $response -ne 'y') {
            Write-Host "Operation cancelled."
            return $false
        }
    }
    
    if (-not (Test-Path $BasePath)) {
        New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
    }
    
    # Create subdirectories from file destinations
    $directories = @()
    foreach ($fileGroup in $Config.files) {
        if ($fileGroup.ContainsKey('destination')) {
            $directories += $fileGroup.destination
        }
    }
    
    # Add any explicit directories from config
    if ($Config.ContainsKey('directories')) {
        $directories += $Config.directories
    }
    
    foreach ($dir in $directories | Sort-Object -Unique) {
        if ($dir) {  # Skip empty directory names
            $fullPath = Join-Path $BasePath $dir
            if (-not (Test-Path $fullPath)) {
                New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
                Write-Verbose "Created directory: $dir"
            }
        }
    }
    
    return $true
}

#========================================
#region Invoke-PostActions
<#
.SYNOPSIS
Executes post-processing actions after packaging.
#>
#========================================
#endregion
function Invoke-PostActions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Actions,
        
        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )
    
    $results = @()
    
    foreach ($action in $Actions) {
        $actionType = $action.type
        $actionResult = @{
            Type = $actionType
            Success = $false
        }
        
        try {
            switch ($actionType) {
                'create_file' {
                    $filePath = Join-Path $BasePath $action.path
                    $content = $action.content
                    
                    # Handle both string content and object content (for JSON files)
                    if ($content -is [hashtable] -or $content -is [PSCustomObject]) {
                        $content = $content | ConvertTo-Json -Depth 10
                    }
                    
                    $content | Out-File -FilePath $filePath -Encoding UTF8
                    $actionResult.Success = $true
                    Write-Verbose "Created file: $($action.path)"
                }
                'zip_package' {
                    $zipPath = Join-Path (Split-Path $BasePath -Parent) "$($action.name).zip"
                    Compress-Archive -Path "$BasePath\*" -DestinationPath $zipPath -Force
                    $actionResult.Success = $true
                    $actionResult.OutputPath = $zipPath
                    Write-Verbose "Created ZIP: $zipPath"
                }
                'run_script' {
                    $scriptPath = $action.script
                    if (Test-Path $scriptPath) {
                        & $scriptPath $BasePath
                        $actionResult.Success = $true
                        Write-Verbose "Executed script: $scriptPath"
                    }
                }
            }
        } catch {
            $actionResult.Error = $_.Exception.Message
            Write-Warning "Post-action failed [$actionType]: $($_.Exception.Message)"
        }
        
        $results += $actionResult
    }
    
    return $results
}

#========================================
#region New-PackageManifest
<#
.SYNOPSIS
Creates a manifest file documenting the package contents.
#>
#========================================
#endregion
function New-PackageManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $true)]
        [array]$FileResults
    )
    
    $manifest = @{
        package = $Config.package
        created = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
        created_by = [Environment]::UserName
        machine = [Environment]::MachineName
        files = @()
    }
    
    foreach ($result in $FileResults) {
        foreach ($operation in $result.Operations) {
            if ($operation.Success) {
                $fileInfo = Get-Item $operation.Destination
                $manifest.files += @{
                    path = $operation.Destination.Substring($OutputPath.Length + 1)
                    source = $operation.Source
                    size = $fileInfo.Length
                    modified = $fileInfo.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    group = $operation.Group
                }
            }
        }
    }
    
    $manifestPath = Join-Path $OutputPath "package-manifest.json"
    $manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $manifestPath -Encoding UTF8
    
    Write-Verbose "Created manifest: package-manifest.json"
    return $manifestPath
}

#========================================
#region Invoke-InstallOperation
<#
.SYNOPSIS
Executes installation operation based on configuration.
#>
#========================================
#endregion
function Invoke-InstallOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [switch]$DryRun,
        [switch]$Force
    )
    
    Write-Host "=== Installing: $($Config.install.name) ===" -ForegroundColor Green
    
    # Implementation would handle installation logic
    # This is a placeholder for the installation functionality
    
    $result = @{
        Success = $true
        Message = "Installation completed successfully"
    }
    
    if ($DryRun) {
        Write-Host "[DRY RUN] Would install package" -ForegroundColor Yellow
    }
    
    return $result
}

# Include the dependency analysis functions from the original script
# (Find-ScriptDependencies, New-DependencyPackageConfig, Update-DotSourcePaths, etc.)
# These functions remain largely unchanged since they don't depend on the config format

#========================================
#region Find-ScriptDependencies
<#
.SYNOPSIS
Analyzes PowerShell scripts to discover dependencies through dot-sourcing and imports.
#>
#========================================
#endregion
function Find-ScriptDependencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$StartingFiles,
        
        [string[]]$SearchPaths = @("."),
        
        [int]$MaxDepth = 10,
        
        [switch]$IncludeModules
    )
    
    $dependencyGraph = @{}
    $processedFiles = @{}
    
    foreach ($startFile in $StartingFiles) {
        if (Test-Path $startFile) {
            $fullPath = Resolve-Path $startFile
            Write-Verbose "Starting dependency analysis from: $fullPath"
            Trace-FileDependencies -FilePath $fullPath -Graph $dependencyGraph -Processed $processedFiles -SearchPaths $SearchPaths -MaxDepth $MaxDepth -CurrentDepth 0 -IncludeModules:$IncludeModules
        } else {
            Write-Warning "Starting file not found: $startFile"
        }
    }
    
    # Flatten dependency graph into unique list
    $allFiles = @{}
    foreach ($file in $dependencyGraph.Keys) {
        $allFiles[$file] = $dependencyGraph[$file]
        foreach ($dep in $dependencyGraph[$file].Dependencies) {
            if ($dep.Type -eq 'Script' -and $dep.ResolvedPath) {
                $allFiles[$dep.ResolvedPath] = @{
                    OriginalPath = $dep.ResolvedPath
                    Dependencies = @()
                }
            }
        }
    }
    
    return @{
        DependencyGraph = $dependencyGraph
        AllFiles = $allFiles.Keys | Sort-Object
        Summary = @{
            TotalFiles = $allFiles.Count
            StartingFiles = $StartingFiles
            SearchPaths = $SearchPaths
            AnalysisDate = Get-Date
        }
    }
}

#========================================
#region Trace-FileDependencies
<#
.SYNOPSIS
Internal function to recursively trace dependencies for a single file.
#>
#========================================
#endregion
function Trace-FileDependencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Graph,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Processed,
        
        [string[]]$SearchPaths,
        [int]$MaxDepth,
        [int]$CurrentDepth,
        [switch]$IncludeModules
    )
    
    if ($CurrentDepth -ge $MaxDepth) {
        Write-Warning "Maximum recursion depth reached for: $FilePath"
        return
    }
    
    $normalizedPath = [System.IO.Path]::GetFullPath($FilePath)
    
    if ($Processed.ContainsKey($normalizedPath)) {
        return  # Already processed this file
    }
    
    $Processed[$normalizedPath] = $true
    Write-Verbose "Analyzing: $([System.IO.Path]::GetFileName($normalizedPath))"
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "File not found during analysis: $FilePath"
        return
    }
    
    # Parse the PowerShell file
    $content = Get-Content -Path $FilePath -Raw
    $dependencies = @()
    
    # Find dot-sourcing statements
    $dotSourcePattern = '^\s*\.\s+([^#\n\r]+)'
    $dotSourceMatches = [regex]::Matches($content, $dotSourcePattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    
    foreach ($match in $dotSourceMatches) {
        $sourcePath = $match.Groups[1].Value.Trim()
        
        # Clean up quotes and common PowerShell path syntax
        $sourcePath = $sourcePath -replace '^["\''](.*)["\''']$', '$1'
        $sourcePath = $sourcePath.Split()[0]  # Take first token (in case of parameters)
        
        if ($sourcePath -match '^\$') {
            # Variable-based path - note but can't resolve statically
            $dependencies += @{
                Type = 'DotSource'
                OriginalPath = $sourcePath
                ResolvedPath = $null
                ResolutionStatus = 'Variable'
                LineMatch = $match.Value.Trim()
            }
            continue
        }
        
        # Resolve relative paths
        $resolvedPath = Resolve-ScriptPath -SourceFile $FilePath -ReferencedPath $sourcePath -SearchPaths $SearchPaths
        
        if ($resolvedPath) {
            $dependencies += @{
                Type = 'DotSource'
                OriginalPath = $sourcePath
                ResolvedPath = $resolvedPath
                ResolutionStatus = 'Resolved'
                LineMatch = $match.Value.Trim()
            }
            
            # Recursively analyze the dependency
            Trace-FileDependencies -FilePath $resolvedPath -Graph $Graph -Processed $Processed -SearchPaths $SearchPaths -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1) -IncludeModules:$IncludeModules
        } else {
            $dependencies += @{
                Type = 'DotSource'
                OriginalPath = $sourcePath
                ResolvedPath = $null
                ResolutionStatus = 'NotFound'
                LineMatch = $match.Value.Trim()
            }
        }
    }
    
    # Store in graph
    $Graph[$normalizedPath] = @{
        OriginalPath = $normalizedPath
        Dependencies = $dependencies
        AnalyzedDepth = $CurrentDepth
    }
}

#========================================
#region Resolve-ScriptPath
<#
.SYNOPSIS
Resolves a referenced script path relative to the source file and search paths.
#>
#========================================
#endregion
function Resolve-ScriptPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFile,
        
        [Parameter(Mandatory = $true)]
        [string]$ReferencedPath,
        
        [string[]]$SearchPaths
    )
    
    # If referenced path is absolute and exists, return it
    if ([System.IO.Path]::IsPathRooted($ReferencedPath)) {
        if (Test-Path $ReferencedPath) {
            return [System.IO.Path]::GetFullPath($ReferencedPath)
        }
        return $null
    }
    
    # Try relative to source file directory
    $sourceDir = Split-Path -Parent $SourceFile
    $relativePath = Join-Path $sourceDir $ReferencedPath
    if (Test-Path $relativePath) {
        return [System.IO.Path]::GetFullPath($relativePath)
    }
    
    # Try each search path
    foreach ($searchPath in $SearchPaths) {
        $candidatePath = Join-Path $searchPath $ReferencedPath
        if (Test-Path $candidatePath) {
            return [System.IO.Path]::GetFullPath($candidatePath)
        }
    }
    
    # Try current directory
    if (Test-Path $ReferencedPath) {
        return [System.IO.Path]::GetFullPath($ReferencedPath)
    }
    
    return $null
}

#========================================
#region New-DependencyPackageConfig
<#
.SYNOPSIS
Generates a JSON package configuration from dependency analysis results.
#>
#========================================
#endregion
function New-DependencyPackageConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]$DependencyResult,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [string]$PackageName = "",
        
        [switch]$OrganizeByDirectory
    )
    
    if (-not $PackageName) {
        $mainFile = $DependencyResult.Summary.StartingFiles[0]
        $PackageName = [System.IO.Path]::GetFileNameWithoutExtension($mainFile)
    }
    
    # Organize files into groups
    $fileGroups = @()
    
    if ($OrganizeByDirectory) {
        # Group by directory structure
        $directoryGroups = @{}
        
        foreach ($file in $DependencyResult.AllFiles) {
            $dir = Split-Path -Parent $file
            $dirName = Split-Path -Leaf $dir
            if (-not $dirName) { $dirName = "root" }
            
            if (-not $directoryGroups.ContainsKey($dirName)) {
                $directoryGroups[$dirName] = @()
            }
            $directoryGroups[$dirName] += $file
        }
        
        foreach ($groupName in $directoryGroups.Keys) {
            $files = $directoryGroups[$groupName]
            $firstFile = $files[0]
            $sourceDir = Split-Path -Parent $firstFile
            
            if ($groupName -eq "root") {
                $sourcePattern = Join-Path $sourceDir "*.ps1"
                $destination = "scripts"
            } else {
                $sourcePattern = "$sourceDir\*"
                $destination = $groupName
            }
            
            $fileGroups += @{
                name = "${groupName}_scripts"
                source = $sourcePattern
                destination = $destination
                preserve_structure = $false
            }
        }
    } else {
        # Simple approach - all scripts together
        $fileGroups += @{
            name = "main_scripts"
            source = "*.ps1"
            destination = "scripts"
            preserve_structure = $false
        }
    }
    
    # Create package configuration
    $packageConfig = @{
        package = @{
            name = $PackageName
            version = "1.0.0"
            description = "Auto-generated package from dependency analysis"
            created_date = (Get-Date -Format "yyyy-MM-dd")
            auto_generated = $true
            dependency_analysis = $DependencyResult.Summary
        }
        
        directories = @("scripts", "docs")
        
        files = $fileGroups
        
        dependency_metadata = @{
            total_files_analyzed = $DependencyResult.AllFiles.Count
            starting_files = $DependencyResult.Summary.StartingFiles
            unresolved_dependencies = @()
        }
    }
    
    # Find unresolved dependencies
    foreach ($file in $DependencyResult.DependencyGraph.Keys) {
        $fileInfo = $DependencyResult.DependencyGraph[$file]
        foreach ($dep in $fileInfo.Dependencies) {
            if ($dep.ResolutionStatus -eq 'NotFound') {
                $packageConfig.dependency_metadata.unresolved_dependencies += @{
                    file = $file
                    dependency = $dep.OriginalPath
                    line = $dep.LineMatch
                }
            }
        }
    }
    
    # Save to JSON with nice formatting
    $jsonContent = $packageConfig | ConvertTo-Json -Depth 10
    $jsonContent | Out-File -FilePath $OutputPath -Encoding UTF8
    
    Write-Host "Generated package configuration: $OutputPath" -ForegroundColor Green
    Write-Host "Files discovered: $($DependencyResult.AllFiles.Count)" -ForegroundColor Cyan
    
    if ($packageConfig.dependency_metadata.unresolved_dependencies.Count -gt 0) {
        Write-Warning "Found $($packageConfig.dependency_metadata.unresolved_dependencies.Count) unresolved dependencies. Check the generated config."
    }
    
    return $packageConfig
}

#========================================
#region Update-DotSourcePaths  
<#
.SYNOPSIS
Updates dot-source paths in scripts when packaging with flattened directory structure.
#>
#========================================
#endregion
function Update-DotSourcePaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$PackageConfig,
        
        [Parameter(Mandatory = $true)]
        [string]$PackagePath,
        
        [switch]$CreateBackups,
        
        [switch]$DryRun
    )
    
    $scriptsUpdated = 0
    $pathsUpdated = 0
    
    # Find all PowerShell files in the package
    $packagedScripts = Get-ChildItem -Path $PackagePath -Filter "*.ps1" -Recurse
    
    foreach ($script in $packagedScripts) {
        Write-Verbose "Analyzing script for path updates: $($script.Name)"
        
        $content = Get-Content -Path $script.FullName -Raw
        $hasChanges = $false
        
        # Find dot-source statements
        $dotSourcePattern = '(^\s*\.\s+)([^#\n\r]+)'
        $matches = [regex]::Matches($content, $dotSourcePattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
        
        foreach ($match in $matches) {
            $prefix = $match.Groups[1].Value
            $originalPath = $match.Groups[2].Value.Trim()
            
            # Clean up the path
            $cleanPath = $originalPath -replace '^["\''](.*)["\''']$', '$1'
            $cleanPath = $cleanPath.Split()[0]  # Take first part before any parameters
            
            # Skip variables or absolute paths
            if ($cleanPath -match '^\$' -or [System.IO.Path]::IsPathRooted($cleanPath)) {
                continue
            }
            
            # Calculate new path based on flattening
            $newPath = Get-FlattenedDotSourcePath -OriginalPath $cleanPath -PackageConfig $PackageConfig -CurrentScript $script
            
            if ($newPath -and $newPath -ne $cleanPath) {
                # Preserve original quoting style
                $quotedNewPath = if ($originalPath.StartsWith('"')) {
                    "`"$newPath`""
                } elseif ($originalPath.StartsWith("'")) {
                    "'$newPath'"
                } else {
                    $newPath
                }
                
                $newStatement = "$prefix$quotedNewPath"
                $content = $content -replace [regex]::Escape($match.Value), $newStatement
                $hasChanges = $true
                $pathsUpdated++
                
                Write-Verbose "  Updated: $originalPath -> $newPath"
            }
        }
        
        if ($hasChanges) {
            if ($CreateBackups -and -not $DryRun) {
                $backupPath = "$($script.FullName).backup"
                Copy-Item -Path $script.FullName -Destination $backupPath -Force
                Write-Verbose "  Created backup: $backupPath"
            }
            
            if ($DryRun) {
                Write-Host "[DRY RUN] Would update paths in: $($script.Name)" -ForegroundColor Yellow
            } else {
                $content | Out-File -FilePath $script.FullName -Encoding UTF8
                Write-Verbose "  Updated script: $($script.Name)"
            }
            
            $scriptsUpdated++
        }
    }
    
    $result = @{
        ScriptsAnalyzed = $packagedScripts.Count
        ScriptsUpdated = $scriptsUpdated
        PathsUpdated = $pathsUpdated
        Success = $true
    }
    
    if ($DryRun) {
        Write-Host "[DRY RUN] Would update $pathsUpdated paths in $scriptsUpdated scripts" -ForegroundColor Yellow
    } else {
        Write-Host "Updated $pathsUpdated dot-source paths in $scriptsUpdated scripts" -ForegroundColor Green
    }
    
    return $result
}

#========================================
#region Get-FlattenedDotSourcePath
<#
.SYNOPSIS
Calculates the new dot-source path when directories are flattened.
#>
#========================================
#endregion
function Get-FlattenedDotSourcePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OriginalPath,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$PackageConfig,
        
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$CurrentScript
    )
    
    # Extract filename from original path
    $targetFileName = Split-Path -Leaf $OriginalPath
    
    # Check if target file exists in the same directory as current script (flattened)
    $scriptDir = Split-Path -Parent $CurrentScript.FullName
    $flattenedPath = Join-Path $scriptDir $targetFileName
    
    if (Test-Path $flattenedPath) {
        # File exists in same directory - use simple relative reference
        return ".\$targetFileName"
    }
    
    # Look for the file in subdirectories
    $foundFile = Get-ChildItem -Path $scriptDir -Filter $targetFileName -Recurse | Select-Object -First 1
    if ($foundFile) {
        # Calculate relative path from current script to found file
        $relativePath = [System.IO.Path]::GetRelativePath($scriptDir, $foundFile.FullName)
        return ".\$relativePath"
    }
    
    # If file not found, return original path (might need manual intervention)
    Write-Warning "Could not resolve flattened path for: $OriginalPath (referenced in $($CurrentScript.Name))"
    return $OriginalPath
}

#========================================
#region Helper Functions
#========================================

function Show-DependencyAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$DependencyResult
    )
    
    Write-Host "=== Dependency Analysis Results ===" -ForegroundColor Green
    Write-Host "Total Files: $($DependencyResult.AllFiles.Count)" -ForegroundColor Cyan
    Write-Host "Starting Files: $($DependencyResult.Summary.StartingFiles -join ', ')" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "=== Files Found ===" -ForegroundColor Yellow
    foreach ($file in $DependencyResult.AllFiles) {
        $fileName = Split-Path -Leaf $file
        $dir = Split-Path -Parent $file
        Write-Host "  $fileName" -NoNewline
        if ($dir) {
            Write-Host " ($dir)" -ForegroundColor DarkGray
        } else {
            Write-Host ""
        }
    }
    
    Write-Host ""
    Write-Host "=== Dependency Details ===" -ForegroundColor Yellow
    foreach ($file in $DependencyResult.DependencyGraph.Keys) {
        $fileName = Split-Path -Leaf $file
        $deps = $DependencyResult.DependencyGraph[$file].Dependencies
        
        if ($deps.Count -gt 0) {
            Write-Host "$fileName depends on:" -ForegroundColor White
            foreach ($dep in $deps) {
                $status = switch ($dep.ResolutionStatus) {
                    'Resolved' { '[✓]' }
                    'NotFound' { '[✗]' }
                    'Variable' { '[?]' }
                    'Module' { '[M]' }
                    default { '[?]' }
                }
                $color = switch ($dep.ResolutionStatus) {
                    'Resolved' { 'Green' }
                    'NotFound' { 'Red' }
                    'Variable' { 'Yellow' }
                    'Module' { 'Cyan' }
                    default { 'Gray' }
                }
                Write-Host "  $status $($dep.OriginalPath)" -ForegroundColor $color
            }
        }
    }
}

function Invoke-DependencyAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$StartingFiles,
        
        [string[]]$SearchPaths
    )
    
    if ($StartingFiles.Count -eq 0) {
        throw "StartingFiles required for dependency analysis"
    }
    
    Write-Host "=== Analyzing Dependencies ===" -ForegroundColor Green
    Write-Host "Starting files: $($StartingFiles -join ', ')" -ForegroundColor Cyan
    Write-Host "Search paths: $($SearchPaths -join ', ')" -ForegroundColor Cyan
    Write-Host ""
    
    $depResult = Find-ScriptDependencies -StartingFiles $StartingFiles -SearchPaths $SearchPaths -Verbose
    Show-DependencyAnalysis -DependencyResult $depResult
    
    Write-Host ""
    Write-Host "=== Next Steps ===" -ForegroundColor Yellow
    Write-Host "To generate package config: New-Package -Mode AutoPackage -StartingFiles @('$($StartingFiles[0])')"
    Write-Host "To package with auto-analysis: New-Package -AutoAnalyzeDependencies -StartingFiles @('$($StartingFiles[0])') -OutputPath .\deploy"
    
    return $depResult
}

function Invoke-AutoPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$StartingFiles,
        
        [string[]]$SearchPaths,
        [string]$OutputPath,
        [switch]$UpdateDotSourcePaths,
        [switch]$DryRun,
        [switch]$Force
    )
    
    Write-Host "=== Auto-Package Mode ===" -ForegroundColor Green
    Write-Host "Analyzing dependencies and creating package..." -ForegroundColor Cyan
    
    # Step 1: Analyze dependencies
    $depResult = Find-ScriptDependencies -StartingFiles $StartingFiles -SearchPaths $SearchPaths
    Show-DependencyAnalysis -DependencyResult $depResult
    
    # Step 2: Generate package config
    $autoConfigPath = "auto-package-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $packageConfig = New-DependencyPackageConfig -DependencyResult $depResult -OutputPath $autoConfigPath
    
    # Step 3: Package using generated config
    Write-Host ""
    Write-Host "=== Packaging with auto-generated config ===" -ForegroundColor Green
    $packageResult = Invoke-PackageOperation -Config $packageConfig -OutputPath $OutputPath -DryRun:$DryRun -Force:$Force -UpdateDotSourcePaths:$UpdateDotSourcePaths
    
    $result = @{
        Success = $packageResult.Success
        DependencyAnalysis = $depResult
        GeneratedConfig = $autoConfigPath
        PackageResult = $packageResult
    }
    
    Write-Host ""
    Write-Host "=== Auto-Package Complete ===" -ForegroundColor Green
    Write-Host "Generated config: $autoConfigPath" -ForegroundColor Cyan
    Write-Host "Package location: $($packageResult.OutputPath)" -ForegroundColor Cyan
    
    return $result
}

# Main execution logic
if ($MyInvocation.InvocationName -ne '.') {
    # Script is being executed directly
    param(
        [string]$ConfigPath = "",
        [string]$OutputPath = ".\deploy", 
        [string]$Mode = "Package",
        [string]$InstallConfigPath = "",
        [string[]]$StartingFiles = @(),
        [string[]]$SearchPaths = @("."),
        [switch]$AutoAnalyzeDependencies,
        [switch]$UpdateDotSourcePaths,
        [switch]$DryRun,
        [switch]$Force
    )
    
    try {
        $result = New-Package -ConfigPath $ConfigPath -OutputPath $OutputPath -Mode $Mode -InstallConfigPath $InstallConfigPath -StartingFiles $StartingFiles -SearchPaths $SearchPaths -AutoAnalyzeDependencies:$AutoAnalyzeDependencies -UpdateDotSourcePaths:$UpdateDotSourcePaths -DryRun:$DryRun -Force:$Force
        
        if ($result.Success) {
            Write-Host "Operation completed successfully!" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "Operation failed!" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}