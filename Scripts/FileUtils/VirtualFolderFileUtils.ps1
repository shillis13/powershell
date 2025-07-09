# DirFileSpecTools.psm1 - Module for Spec-Driven Directory and File Creation


if (-not $Script:PSRoot) {
    $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    #Write-Host "Set Global:PSRoot = $Script:PSRoot"
    . "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"

}
if (-not $Script:PSRoot) {
    throw "Script:PSRoot must be set by the entry-point script before using internal components."
}

if (-not $Script:CliArgs -and $args) {
    $Script:CliArgs = $args
}

# enum CloneType {
#     Self
#     Shallow
#     Recursive
# }
# $null = [CloneType]::Recursive
$Script:CloneType_Recursive = "Recursive"
$Script:CloneType_Shallow = "Shallow"
$Script:CloneType_Self = "Self"


<#
.SYNOPSIS
    Normalizes a path by trimming trailing backslashes. Optionally sanitizes invalid characters in the leaf.

.PARAMETER path
    The path to normalize.

.PARAMETER Sanitize
    Optional switch to replace invalid file name characters in the leaf with underscores.

.EXAMPLE
    Format-Path 'C:\Temp\Folder\'         # → 'C:\Temp\Folder'
    Format-Path 'C:\Invalid:Name' -Sanitize  # → 'C:\Invalid_Name'
#>
function Format-Path {
    param(
        [string]$path,
        [switch]$Sanitize
    )

    if ([string]::IsNullOrWhiteSpace($path)) {
        $msg = "Input path is null or empty."
        Log -Warn "Throwing Exception: $msg"
        throw "Format-Path: $msg"
    }

    if ($path -match '^[A-Za-z]:\\.*[A-Za-z]:\\') {
        $msg = "Path contains multiple rooted prefixes: '$path'."
        Log -Warn "Throwing Exception: $msg"
        throw "Format-Path: $msg"
    }

    if ($Sanitize) {
        $leaf = Split-Path $path -Leaf
        $parent = Split-Path $path -Parent
        $invalid = [System.IO.Path]::GetInvalidFileNameChars()
        $pattern = ($invalid | ForEach-Object { [Regex]::Escape($_) }) -join '|'
        $cleanLeaf = $leaf -replace $pattern, '_'
        $path = if ($parent) { Join-Path $parent $cleanLeaf } else { $cleanLeaf }
    }

    return $path.TrimEnd('\')
}
#endregion
#==================================================================================

#======================================================================================
#region         Function: Resolve-ToAbsPath
<#
.SYNOPSIS
    Resolves a path to an absolute form. Uses Resolve-Path if possible; otherwise falls back to .NET.

.PARAMETER path
    A string path to resolve.

.RETURNS
    A normalized absolute path with trailing backslashes removed.

.EXAMPLE
    Resolve-ToAbsPath '.\Temp'       # → 'C:\Users\You\Temp'
    Resolve-ToAbsPath 'C:\Foo\'      # → 'C:\Foo'
#>
function Resolve-ToAbsPath {
    param([string]$path)

    if ([string]::IsNullOrWhiteSpace($path)) {
        $msg = "Input path is null or empty."
        Log -Warn "Throwing Exception: $msg"
        throw "Resolve-ToAbsPath: $msg"
    }

    if ($path -match '^[A-Za-z]:\\.*[A-Za-z]:\\') {
        $msg = "Malformed path with multiple rooted prefixes: '$path'"
        Log -Warn "Throwing Exception: $msg"
        throw "Resolve-ToAbsPath: $msg"
    }

    $absPath = try {
        (Resolve-Path -LiteralPath $path -ErrorAction Stop).Path
    } catch {
        try {
            [System.IO.Path]::GetFullPath($path)
        } catch {
            $msg = "Cannot resolve '$path'. $_"
            Log -Warn "Throwing Exception: $msg"
            throw "Resolve-ToAbsPath: $msg"
        }
    }

    return Format-Path $absPath
}
#endregion
#==================================================================================


#======================================================================================
#region      Function:  Compare-IfNotNullOrEmpty
<#
.SYNOPSIS
    Compares two arrays if they are not null or empty, using an optional comparer scriptblock.

.PARAMETER A
    The first array to compare.

.PARAMETER B
    The second array to compare.

.PARAMETER ComparerBlock
    An optional scriptblock to use for comparison if both arrays are not null or empty.

.RETURNS
    A boolean indicating whether the arrays are considered equal based on the provided conditions and comparer.

.EXAMPLE
    $result = Compare-IfNotNullOrEmpty -A $array1 -B $array2 -ComparerBlock { $array1 -eq $array2 }
#>
function Compare-IfNotNullOrEmpty {
    param(
        [object[]]$A,
        [object[]]$B, 
        [scriptblock]$ComparerBlock = $null
    )
    $result = $true

    $aEmpty = (-not $A -or $A.Count -eq 0)
    $bEmpty = (-not $B -or $B.Count -eq 0)

    if ($aEmpty -and $bEmpty) { $result = $true }
    elseif ($aEmpty -or $bEmpty ) { $result = $false }
    elseif ($null -eq $ComparerBlock) {
        # Assume equal structurally if both are non-empty and no comparer given
        $result = $true
    }
    else {
        $result = & $ComparerBlock
    }
    return $result
}

#endregion
#==================================================================================



#======================================================================================
#region     Function: Test-CircularReference
<#
.SYNOPSIS
    Checks for circular references by recursively walking children of an object.

.PARAMETER StartObject
    The starting object to evaluate for cycles.

.PARAMETER GetChildren
    A script block that returns children for a given object.

.EXAMPLE
    Test-CircularReference -StartObject $root -GetChildren { param($x) $x.GetSubFolders($false) }
#>
#======================================================================================
function Test-CircularReference {
    param (
        [Parameter(Mandatory)] $StartObject,
        [Parameter(Mandatory)] [scriptblock]$GetChildren
    )
    #Log -Dbg " : StartObject = $($StartObject.Name)"
    $visited = New-Object 'System.Collections.Generic.HashSet[object]'
    $stack = [System.Collections.Stack]::new()
    $stack.Push($StartObject)

    $circRefFound = $false

    while ($stack.Count -gt 0) {
         $current = $stack.Pop()
        if ($visited.Contains($current)) {
            $circRefFound = $true
            break
        }
        [void]$visited.Add($current)
        $children = & $GetChildren $current
        foreach ($child in $children) {
            $stack.Push($child)
        }
    }
    return $circRefFound
}
#endregion
#======================================================================================


#======================================================================================
#region      Class: VirtualFolder
# Description: Represents a directory with metadata, subdirectories, and files.
# Properties:
#   - FolderName: (string) The name of the directory.
#   - CreationTime: (datetime) The creation time of the directory.
#   - ModificationTime: (datetime) The last modification time of the directory.
#   - SubDirs: (SpecDir[]) The subdirectories within this directory.
#   - ParentDir: (SpecDir) The parent directory.
#   - Files: (SpecItem[]) The files within this directory.
# Methods:
#   - VirtualFolder: Constructor to initialize a new VirtualFolder.
#   - AddSubDir: Adds a subdirectory to this directory.
#   - GetSubDir: Retrieves a subdirectory by name, optionally searching recursively.
#   - GetSubDirs: Retrieves all subdirectories, optionally recursively.
#   - AddItem: Adds a file to this directory.
#   - GetFiles: Retrieves all files, optionally recursively.
#   - GetPath: Returns the full path of this directory.
#   - ChangeFileExts: Changes the file extensions of all files matching a given extension.
#   - RemoveMatches: Removes files and/or directories matching a given string.
#   - ToString: Returns the directory name.
#   - Equals: Checks equality with another VirtualFolder.
#   - Clone: Creates a deep copy of this VirtualFolder.
#   - PrintFolder: Prints the directory structure.
#======================================================================================
class VirtualFolder {
    [string]$_name
    [VirtualFolder[]]$SubFolders
    [VirtualItem[]]$Items
    [VirtualFolder]$ParentFolder

    VirtualFolder([string]$Name, [VirtualFolder]$ParentFolder = $null) {
        $this._name = Format-Path ($Name.Trim())
        $this.SubFolders = @()
        $this.Items = @()
        $this.ParentFolder = $ParentFolder
        if ($null -ne $this.ParentFolder) {
            $this.ParentFolder.AddSubFolder($this)
        }
    }

    [string]ToString() {
        return $this.GetRelativePath()
    }

    [string]Name() { return $this.GetName() }
    [string]GetName() { return $this._name }
    [void]SetName([string]$Name) { 
        $this._name = Format-Path ($Name.Trim()) 
    }

    [void]AddSubFolder([VirtualFolder]$subFolder) {
        if (-not ($this.SubFolders | Where-Object { $_.Equals($subFolder) })) {
            $circularReferenceFound = $false
            $circularReferenceFound = Test-CircularReference -StartObject $subFolder -GetChildren { param($f) $f.GetSubFolders($false) }
            if ($circularReferenceFound) {
                Log -Warn "Circular reference detected. Skipping subfolder: $($subFolder.Name)"
            } else {
                $subFolder.ParentFolder = $this
                $this.SubFolders += $subFolder
            }
        }
    }

    [void]AddItem([VirtualItem]$item) {
        $item.ParentFolder = $this
        if (-not ($this.Items | Where-Object { $_.Equals($item) })) {
            $this.Items += $item
        }
    }

    [VirtualFolder[]]GetSubFolders() { return $this.GetSubFolders($false) }
    [VirtualFolder[]]GetSubFolders([bool]$Recurse = $false) {
        $result = @($this.SubFolders)
        if ($Recurse) {
            foreach ($sub in $this.SubFolders) {
                $result += $sub.GetSubFolders($true)
            }
        }
        return $result
    }

    [VirtualItem[]]GetItems() { return $this.GetItems($false) }
    [VirtualItem[]]GetItems([bool]$Recurse = $false) {
        $result = @($this.Items)
        if ($Recurse) {
            foreach ($sub in $this.SubFolders) {
                $result += $sub.GetItems($true)
            }
        }
        return $result
    }

    [VirtualFolder]GetSubFolder([string]$Name) { return $this.GetSubFolder($Name, $false) }
    [VirtualFolder]GetSubFolder([string]$Name, [bool]$SearchRecurse = $false) {
        foreach ($sub in $this.SubFolders) {
            if ($sub.Name() -ieq $Name) { return $sub }
        }
        if ($SearchRecurse) {
            foreach ($sub in $this.SubFolders) {
                $result = $sub.GetSubFolder($Name, $true)
                if ($null -ne $result) { return $result }
            }
        }
        return $null
    }

    [void]ChangeItemExts([string]$oldExt, [string]$newExt) { $this.ChangeItemExts($oldExt, $newExt, $false) }
    [void]ChangeItemExts([string]$oldExt, [string]$newExt, [bool]$Recurse = $false) {
        foreach ($item in $this.Items) {
            if ($item.Ext -ieq $oldExt) { $item.Ext = $newExt }
        }
        if ($Recurse) {
            foreach ($sub in $this.SubFolders) {
                $sub.ChangeItemExts($oldExt, $newExt, $Recurse)
            }
        }
    }

    [void]RemoveMatches([string]$pattern, [bool]$MatchDirs) { [void]$this.RemoveMatches($pattern, $MatchDirs, $false) }
    [void]RemoveMatches([string]$pattern, [bool]$MatchDirs, [bool]$recurse = $false ) {
        $regex = [regex]::Escape($pattern)
        if ($MatchDirs) {
            $this.SubFolders = $this.SubFolders | Where-Object { $null -ne $_ -and $_.GetRelativePath() -notmatch $regex }
        }
        $this.Items = $this.Items | Where-Object { $null -ne $_  -and $_.Name() -notmatch $regex }

        if ($recurse) {
            foreach ($sub in $this.SubFolders) {
                $sub.RemoveMatches($pattern, $MatchDirs, $recurse )
            }
        }
    }

    [string]GetRelativePath() {
        $result = $this.Name()
        if ($null -ne $this.ParentFolder) {
            $result = Join-Path $this.ParentFolder.GetRelativePath() $result
        }
        return Format-Path $result
    }

    [bool]Equals([object]$other) {
        return $this.Equals($other, $true, $false)
    }

    [bool]Equals([object]$other, [bool]$EqContents = $true, [bool]$Recurse = $false) {
        $isEqual = $true

        if ($null -eq $other -or $other.GetType() -ne $this.GetType()) {
            $isEqual = $false
        } else {
            $otherFolder = [VirtualFolder]$other

            if ($this.Name() -ne $otherFolder.Name()) {
                $isEqual = $false
            }

            if ($isEqual) {
                $itemsThis  = @(if ($Recurse) { $this.GetItems($true) } else { $this.GetItems($false) })
                $itemsOther = @(if ($Recurse) { $otherFolder.GetItems($true) } else { $otherFolder.GetItems($false) })

                if (-not (Compare-IfNotNullOrEmpty -A $itemsThis -B $itemsOther -ComparerBlock {
                    Compare-SortedCollections `
                        -ContextLabel "Items" `
                        -ListA $itemsThis `
                        -ListB $itemsOther `
                        -SortKey { $_.Name() } `
                        -Comparer { param ($a, $b) $a.Equals($b, $EqContents) }
                })) {
                    $isEqual = $false
                }
            }

            if ($isEqual) {
                $foldersThis  = @(if ($Recurse) { $this.GetSubFolders($true) } else { $this.GetSubFolders($false) })
                $foldersOther = @(if ($Recurse) { $otherFolder.GetSubFolders($true) } else { $otherFolder.GetSubFolders($false) })

                if (-not (Compare-IfNotNullOrEmpty -A $foldersThis -B $foldersOther -ComparerBlock {
                    Compare-SortedCollections `
                        -ContextLabel "Folders" `
                        -ListA $foldersThis `
                        -ListB $foldersOther `
                        -SortKey { $_.Name() } `
                        -Comparer { param ($a, $b) $a.Equals($b, $EqContents, $Recurse) }
                })) {
                    $isEqual = $false
                }
            }
        }
        return $isEqual
    }

    [VirtualFolder]Clone([string]$CloneType = 'Recursive') {
        $clone = [VirtualFolder]::new($this.Name(), $null)

        if ($CloneType -eq $Global:CloneType_Shallow -or $CloneType -eq $Global:CloneType_Recursive) {
            foreach ($sub in $this.GetSubFolders()) {
                $child = if ($CloneType -eq $Global:CloneType_Recursive) {
                    $sub.Clone($Global:CloneType_Recursive)
                } else {
                    [VirtualFolder]::new($sub.Name(), $clone)
                }
                $clone.AddSubFolder($child)
            }

            foreach ($item in $this.GetItems($false)) {
                $clone.AddItem($item.Clone())
            }
        }

        return $clone
    }

    [string]PrintFolder() { return $this.PrintFolder($true, 0, $null) }
    [string]PrintFolder([bool]$Recurse = $true, [int]$indentLevel = 0) { return $this.PrintFolder($Recurse, $IndentLevel, $null) }
    [string]PrintFolder([bool]$Recurse = $true, [int]$indentLevel = 0, [System.Collections.Generic.HashSet[string]]$visitedFolders = $null) {
        if ($null -eq $visitedFolders) {
            $visitedFolders = [System.Collections.Generic.HashSet[string]]::new()
        }

        $indent = " " * $indentLevel
        $output = "$indent$($this.Name())`n"
        $output += "$indent" + ('-' * $this.Name().Length) + "`n"
    
        # Check for circular reference
        if ($visitedFolders.Contains($this.Name())) {
            $output += "$indent Circular reference detected at $($this.Name())`n"
            return $output
        } else {
            $visitedFolders.Add($this.Name())
        }

        foreach ($sub in $this.SubFolders) {
            $output += "$indent|d-- $($sub.Name())`n"
        }

        foreach ($item in $this.Items) {
            $output += "$indent|f-- $($item.Name())`n"
        }

        $output += "$indent" + ('=' * 40) + "`n"
        if ($Recurse) {
            foreach ($sub in $this.SubFolders) {
                $output += $sub.PrintFolder($true, $indentLevel + 4, $visitedFolders)
            }
        }
        return $output
    }
}

#endregion
#======================================================================================

#======================================================================================
#region     Class: VirtualItem
# Description: Represents a item with metadata and content.
# Properties:
#   - BaseName: (string) The base name of the item (without extension).
#   - Ext: (string) The item extension.
#   - Contents: (string) The contents of the item.
#   - Size: (int) The size of the item contents.
#   - CreationTime: (datetime) The creation time of the item.
#   - ModificationTime: (datetime) The last modification time of the item.
#   - SourcePath (string) The path back to the source item
#   - Parentfolder: (SpecDir) The parent directory.
# Methods:
#   - VirtualItem: Constructor to initialize a new VirtualItem.
#   - Name: Returns the Name with extension.
#   - ToString: Returns the full path of the file.
#   - Equals: Checks equality with another VirtualItem.
#   - Clone: Creates a deep copy of this VirtualItem.
#======================================================================================
class VirtualItem {
    [string]$_baseName
    [string]$_ext
    [string]$_contents
    [string]$_sourcePath
    [int64]$_size = -1
    [bool]$_isDirtySize = $true
    [datetime]$_creationTime = [datetime]::Now
    [datetime]$_modificationTime = [datetime]::Now
    [VirtualFolder]$ParentFolder

    VirtualItem ([string]$BaseName, [string]$Ext, [string]$SourcePath = "", [VirtualFolder]$ParentFolder = $null, [string]$Contents = $null) {
        if (-not $BaseName) {
            Log -Err "Throwing Exception: BaseName parameter cannot be empty or null"
            Throw "BaseName parameter cannot be empty or null"
        }
        $this._baseName = Format-Path $BaseName.Trim() -Sanitize
        $this._ext = if ($Ext) { $Ext.TrimStart('.').Trim() } else { "" }
        $this._sourcePath = if ($SourcePath) { Format-Path $SourcePath } else { "" }
        $this._contents = if ($null -ne $Contents) { $Contents.Trim() } else { $null }
        $this._isDirtySize = $true

        $this.ParentFolder = $ParentFolder
        if ($null -ne $this.ParentFolder) { $this.ParentFolder.AddItem($this) }
    }

    [string]ToString() {
        return $this.GetRelativePath()
    }

    [string]Name() {
        $name = $this._baseName
        if ($this._ext -ne "") { $name = "$($name).$($this._ext)" }
        #return Format-Path (($this._ext -ne "") ? "$($this._baseName).$($this._ext)" : $this._baseName)
        return $name
    }

    [void]SetContents([string]$Contents) {
        $this._contents = $Contents
        $this._isDirtySize = $true
        $this._modificationTime = [datetime]::Now
    }

    [string]GetSourcePath() { return $this._sourcePath }
    [void]SetSourcePath([string]$SourcePath) {
        $this._sourcePath = Format-Path $SourcePath
        $this._isDirtySize = $true
    }

    [void]SetName([string]$Name) { $this.SetName($Name, "") }
    [void]SetName([string]$BaseName, [string]$Ext = "") {
        $this._baseName = Format-Path $BaseName.Trim() -Sanitize
        $this._ext = if ($Ext) { $Ext.TrimStart('.').Trim() } else { "" }
    }

    [string]GetRelativePath() { return $this.GetRelativePath($false) }
    [string]GetRelativePath([bool]$UseSrc = $false) {
        $result = ""
        if (-not $UseSrc) {
            $result = $this.Name()
            if ($null -ne $this.ParentFolder) {
                $result = Join-Path $this.ParentFolder.GetRelativePath() $result
            }
        }
        else {
            # ** TODO **
        }
        return Format-Path $result
    }

    [string]GetContents() { return $this.GetContents($false) }
    [string]GetContents([bool]$UseSrc = $false) {
        $contents = $null
        if (-not $UseSrc) {
            $contents = $this._contents
        }
        elseif ($this._sourcePath -and (Test-Path $this._sourcePath)) {
            $contents = Get-Content -Path $this._sourcePath -Raw
        }
        return $contents
    }

    [int64]GetSize() { return $this.GetSize($false) }
    [int64]GetSize([bool]$UseSrc = $false) {
        $size = 0
        if ($UseSrc -and $this._sourcePath -and (Test-Path $this._sourcePath)) {
            $size = (Get-Item $this._sourcePath).Length
        }
        elseif ($this._isDirtySize) {
            $size = if ($this._contents) {
                [System.Text.Encoding]::UTF8.GetByteCount($this._contents)
            } else { 0 }
            $this._size = $size
            $this._isDirtySize = $false
        }
        else {
            $size = $this._size
        }
        return $size
    }

    [void]SetCreationTime([datetime]$CreationTime) { $this.SetCreationTime( $CreationTime, $false ) }
    [void]SetCreationTime([datetime]$CreationTime, [bool]$UseSrc = $false) {
        if (-not $UseSrc) {
            $this._creationTime = $CreationTime
            # Should we: if(_creationTime > _modificationTime ) set _modificationTime = _creationTime ?
        }
        elseif ($this._sourcePath -and (Test-Path $this._sourcePath)) {
            (Get-Item $this._sourcePath).CreationTime = $CreationTime
        }
    }

    [datetime]GetCreationTime() { return $this.GetCreationTime($false) }
    [datetime]GetCreationTime([bool]$UseSrc = $false) {
        $time = [datetime]::MinValue
        if (-not $UseSrc) {
            $time = $this._creationTime
        }
        elseif ($this._sourcePath -and (Test-Path $this._sourcePath)) {
            $time = (Get-Item $this._sourcePath).CreationTime
        }
        return $time
    }

    [void]SetModificationTime([datetime]$ModificationTime) { $this.SetModificationTime( $ModificationTime, $false ) }
    [void]SetModificationTime([datetime]$ModificationTime, [bool]$UseSrc = $false) {
        if (-not $UseSrc) {
            $this._modificationTime = $ModificationTime
            # Should we: if(_modificationTime < _creationTime ) set _creationTime = _modificationTime  ?
        }
        elseif ($this._sourcePath -and (Test-Path $this._sourcePath)) {
            (Get-Item $this._sourcePath).LastWriteTime = $ModificationTime
        }
    }

    [datetime]GetModificationTime() { return $this.GetModificationTime($false) }
    [datetime]GetModificationTime([bool]$UseSrc = $false) {
        $time = [datetime]::MinValue
        if (-not $UseSrc) {
            $time = $this._modificationTime
        }
        elseif ($this._sourcePath -and (Test-Path $this._sourcePath)) {
            $time = (Get-Item $this._sourcePath).LastWriteTime
        }
        return $time
    }

    [bool]Equals([object]$other) {
        return $this.Equals($other, $true)
    }

    [bool]Equals([object]$other, [bool]$EqContents = $true) {
        $isEqual = $true

        if ($null -eq $other -or $other.GetType() -ne $this.GetType()) {
            $isEqual = $false
        }
        else {
            $otherItem = [VirtualItem]$other

            if ($this.Name() -ine $otherItem.Name()) {
                $isEqual = $false
            }
            elseif ($this.GetSize($false) -ne $otherItem.GetSize($false)) {
                $isEqual = $false
            }
            elseif ($this.GetCreationTime($false) -ne $otherItem.GetCreationTime($false)) {
                $isEqual = $false
            }
            elseif ($this.GetModificationTime($false) -ne $otherItem.GetModificationTime($false)) {
                $isEqual = $false
            }
            elseif ($this._sourcePath -and $otherItem._sourcePath -and
                    (Test-Path $this._sourcePath) -and (Test-Path $otherItem._sourcePath)) {
                $lenThis = (Get-Item $this._sourcePath).Length
                $lenOther = (Get-Item $otherItem._sourcePath).Length
                if ($lenThis -ne $lenOther) {
                    $isEqual = $false
                }
            }

            if ($isEqual -and $EqContents) {
                $aHasContents = ($null -ne $this._contents)
                $bHasContents = ($null -ne $otherItem._contents)

                if ($aHasContents -and $bHasContents) {
                    if ($this._contents -ine $otherItem._contents) {
                        $isEqual = $false
                    }
                }
                elseif ($this._sourcePath -and $otherItem._sourcePath -and
                        (Test-Path $this._sourcePath) -and (Test-Path $otherItem._sourcePath)) {
                    $srcA = Get-Content $this._sourcePath -Raw
                    $srcB = Get-Content $otherItem._sourcePath -Raw
                    if ($srcA -ine $srcB) {
                        $isEqual = $false
                    }
                }
            }
        }
        return $isEqual
    }

    [VirtualItem]Clone() {
        $clone = [VirtualItem]::new($this._baseName, $this._ext, $this._sourcePath, $null, $this._contents)
        $clone._creationTime = $this._creationTime
        $clone._modificationTime = $this._modificationTime
        $clone._size = $this._size
        $clone._isDirtySize = $this._isDirtySize
        return $clone
    }
}

#endregion  
#======================================================================================

#======================================================================================
#region  Function: New-VirtualFolder
# Description: Creates a new VirtualFolder object.
# Parameters:
#   - FolderName: (string) The name of the directory.
#   - parentDir: (SpecDir) [Optional] The parent directory.
# Returns: A new VirtualFolder object.
#======================================================================================
<#
.SYNOPSIS
    Creates a new VirtualFolder object.

.PARAMETER Name
    The name of the directory.

.PARAMETER ParentFolder
    The parent directory. (Optional)

.RETURNS
    A new VirtualFolder object.

.EXAMPLE
    $newFolder = New-VirtualFolder -Name 'NewFolder'
#>
function New-VirtualFolder {
    param(
        [string]$Name, 
        [VirtualFolder]$ParentFolder = $null
    )
    $aNewVirtDir = [VirtualFolder]::new($Name, $ParentFolder)
    if ($null -eq $aNewVirtDir -or $aNewVirtDir.Name() -eq "") {
        Log -Err "Unable to construct [VirtualFolder]: name = $Name : dir = $ParentFolder"
    }
    return $aNewVirtDir
}
#endregion  
#======================================================================================

#======================================================================================
#region     Function: New-VirtualItem
# Description: Creates a new SpecItem object.
# Parameters:
#   - BaseName: (string) The base name of the file.
#   - Ext: (string) The file extension.
#   - SourcePath (string) [Optional] The path back to the source file
#   - ParentDir: (SpecDir) [Optional] The parent directory.
#   - Contents: (string) [Optional] The content of the file.
# Returns: A new SpecItem object.
#======================================================================================
<#
.SYNOPSIS
    Creates a new VirtualItem object.

.PARAMETER BaseName
    The base name of the file.

.PARAMETER Ext
    The file extension.

.PARAMETER SourcePath
    The path back to the source file. (Optional)

.PARAMETER ParentFolder
    The parent directory. (Optional)

.PARAMETER Contents
    The content of the file. (Optional)

.RETURNS
    A new VirtualItem object.

.EXAMPLE
    $newItem = New-VirtualItem -BaseName 'File1' -Ext 'txt'
#>
function New-VirtualItem {
    param(
        [string]$BaseName, 
        [string]$Ext, 
        [string]$SourcePath = "", 
        [VirtualFolder]$ParentFolder = $null,
        [string]$Contents = ""
    )
    $aNewVirtualItem = [VirtualItem]::new($BaseName, $Ext, $SourcePath, $ParentFolder, $Contents)
     if ($null -eq $aNewVirtualItem -or $aNewVirtualItem.baseName -eq "") {
        Log -Err "Unable to construct [VirtualItem]: BaseName = $BaseName : Ext = $Ext : SourcePath = $SourcePath : Dir = $ParentFolder : Contents = $Contents"
    }
    return $aNewVirtualItem
}
#endregion  
#======================================================================================


#======================================================================================
#region     Function:  Write-FolderHierarchy
<#
.SYNOPSIS
    Writes the contents of a VirtualFolder to the filesystem using Copy, Move, or Write.

.PARAMETER DestFolderPath
    The absolute path where the contents of the source VirtualFolder will be written.

.PARAMETER SrcVirtualFolder
    The source VirtualFolder whose contents will be written to DestFolderPath.

.PARAMETER FileAction
    Indicates how files should be written: Copy, Move, or Write.

.PARAMETER Exec
    If specified (or if Get-DryRun is false), actions will be executed. Otherwise, dry run mode is assumed.

.EXAMPLE
    Write-FolderHierarchy -DestFolderPath 'C:\Target' -SrcVirtualFolder $mySpecDir -FileAction "Write" -Exec
#>
#======================================================================================
function Write-FolderHierarchy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$DestFolderPath,

        [Parameter(Mandatory)]
        $SrcVirtualFolder,

        [ItemActionType]$ItemAction = [ItemActionType]::Write,

        [switch]$Exec
    )
    
    if ($Exec) { Set-DryRun $false }

    Log -Dbg "Write-FolderHierarchy(): -DestFolderPath $DestFolderPath -SrcVirtualFolder $($SrcVirtualFolder.Name()) -ItemAction $itemAction -Exec=$Exec"

    $targetFolderPath = Resolve-ToAbsPath $DestFolderPath

    if (-not (Test-Path -Path $targetFolderPath -PathType Container)) {
        $msg = "Target folder does not exist: $targetFolderPath"
        Log -Warn "Throwing Exception: $msg"
        if (-not (Get-DryRun)) {
            throw "Write-FolderHierarchy(): $msg"
        }
    }

    # Create or overwrite files in this directory
    foreach ($item in $SrcVirtualFolder.Items) {
        $itemPath = Join-Path $targetFolderPath $item.Name()
        
        if (-not (Get-DryRun)) {
            if ($itemAction -eq [ItemActionType]::Copy -and $item.GetSourcePath()) {
                Copy-Item -Path $item.GetSourcePath() -Destination $itemPath -Force
            } 
            elseif ($itemAction -eq [ItemActionType]::Move -and $item.GetSourcePath()) {
                Move-Item -Path $item.GetSourcePath() -Destination $itemPath -Force
            } 
            elseif (($itemAction -eq [ItemActionType]::Write) -and ($null -ne $item)) {
                try {
                   Set-Content -Path $itemPath -Value $item.GetContents($false) -Force
                }
                catch {
                    $msg = $_
                    Log -Err "Re-Throwing Exception: $msg"
                    throw $msg
                }
            } 
            else {
                Log -Warn "Write-FolderHierarchy(): Cannot $itemAction without valid source or content."
            }

            if ($item.GetCreationTime($false) -gt [datetime]::MinValue) {
                $(Get-Item $itemPath).CreationTime    = $item.GetCreationTime($false)
            }
            if ($item.GetModificationTime($false) -gt [datetime]::MinValue) {
                $(Get-Item $itemPath).LastWriteTime   = $item.GetModificationTime($false)
            }
        } 
        else {
            Log -DryRun "$itemAction file: $itemPath"
            Log -DryRun "Set $itemPath CreationTime  = $($item.GetCreationTime($false))"
            Log -DryRun "Set $itemPath LastWriteTime = $($item.GetModificationTime($false))"
        }
    }

    # Recurse into SubFolderectories
    foreach ($childFolder in $SrcVirtualFolder.SubFolders) {
        $childDirPath = Join-Path $targetFolderPath $childFolder.Name()
        if (-not (Test-Path -Path $childDirPath -PathType Container)) {
            if (-not (Get-DryRun)) {
                New-Item -Path $childDirPath -ItemType Directory -Force | Out-Null
            }
            else {
                Log -DryRun "Create Folder: $childDirPath"               
            }
        }

        Write-FolderHierarchy -DestFolderPath $childDirPath -SrcVirtualFolder $childFolder -ItemAction $itemAction -Exec:$Exec
    }
}
#endregion
#======================================================================================


#======================================================================================
#region      Function: Read-FolderHierarchy
# Description: Reads the directory and file hierarchy from the specified root directory.
# Parameters:
#   - RootDir: (String) The root directory from which the hierarchy will be read.
#   - ReadContents: (switch) When turn on will read the contents of the files into memory.
# Returns: A VirtualFolder as the root and containing all the read files and folders.
#======================================================================================
<#
.SYNOPSIS
    Reads the directory and file hierarchy from the specified root directory.

.PARAMETER FolderPath
    The root directory from which the hierarchy will be read.

.PARAMETER ReadContents
    When turned on, will read the contents of the files into memory.

.RETURNS
    A VirtualFolder as the root and containing all the read files and folders.

.EXAMPLE
    $rootFolder = Read-FolderHierarchy -FolderPath 'C:\Source' -ReadContents
#>
function Read-FolderHierarchy {
    param (
        [Parameter(Mandatory)]
        [string]$FolderPath,

        [switch]$ReadContents
    )

    $normalizedRoot = Format-Path $FolderPath
    if (-not (Test-Path -Path $normalizedRoot -PathType Container)) {
        Log -Warn "Path $normalizedRoot not found or not a folder."
        return $null
    }

    # Split-Path is a system-derived path component.
    # If reused beyond construction, normalize or sanitize with Format-Path.
    $virtFolder = New-VirtualFolder -Name (Split-Path $normalizedRoot -Leaf) -ParentFolder $null

    #$rootInfo = Get-Item -Path $normalizedRoot
    #$virtFolder.SetCreationTime($rootInfo.CreationTime)
    #$virtFolder.ModificationTime = $rootInfo.LastWriteTime

    Log -Dbg "Entering: $normalizedRoot"

    foreach ($item in Get-ChildItem -Path $normalizedRoot -File) {
        $contents = if ($ReadContents) { Get-Content -Path $item.FullName -Raw } else { $null }
        $vi = New-VirtualItem -BaseName $item.BaseName -Ext $item.Extension.TrimStart('.') -SourcePath $item.FullName -ParentDir $virtFolder -Contents $contents
        $vi.SetCreationTime($item.CreationTime)
        $vi.SetModificationTime($item.LastWriteTime)

        if (Get-DryRun) {
            #Log -DryRun "Discovered file: $($f.Filename()) under $($rootSpecDir.GetRelativePath())"
        }

        $virtFolder.AddItem($vi)
    }

    foreach ($sub in Get-ChildItem -Path $normalizedRoot -Directory) {
        $subPath = Resolve-ToAbsPath $sub.FullName
        $childFolder = Read-FolderHierarchy -FolderPath $subPath -ReadContents:$ReadContents
        #$childFolder.ParentFolder = $virtFolder
        $virtFolder.AddSubFolder($childFolder)
    }

    return $virtFolder
}
#endregion
#======================================================================================

#[void][CloneType]::GetEnumNames()
#Export-ModuleMember -Function New-VirtualFolder, New-VirtualItem, Write-FolderHierarchy, Read-FolderHierarchy, Format-Path, Resolve-ToAbsPath -Alias * -Variable * 
#[void][System.Enum]::GetValues([CloneType])
#$null = [CloneType]::Recursive
