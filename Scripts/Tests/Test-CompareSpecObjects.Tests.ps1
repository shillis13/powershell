# Compare-SpecObjects.Tests.ps1
# Requires: Pester v5+

# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

function InitializeCore {
    if (-not $Script:PSRoot) {
        $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
        Write-Host "Set Script:PSRoot = $Script:PSRoot"
    }
    if (-not $Script:PSRoot) {
        throw 'Script:PSRoot must be set by the entry-point script before using internal components.'
    }

    $Script:CliArgs = $args
    . "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"
}


#endregion
# ===========================================================================================


Describe "Compare-SortedCollections with VirtualItems and VirtualFolder" {

    BeforeAll {
        #InitializeCore
        if (-not $Script:PSRoot) {
            $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
            Write-Host "Set Script:PSRoot = $Script:PSRoot"
        }
        if (-not $Script:PSRoot) {
            throw 'Script:PSRoot must be set by the entry-point script before using internal components.'
        }

        $Script:CliArgs = $args
        . "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"
        # Import-Module "$env:PowerShellModules/VirtualFolderFileUtils/VirtualFolderFileUtils.psd1" -Force
        . "$Script:PSRoot\Scripts\FileUtils\VirtualFolderFileUtils.ps1"
    }

    It "returns true for equivalent List of Items in different order" {
        $F1 = New-VirtualItem -BaseName 'A' -Ext 'txt' -Contents 'One'
        $F2 = New-VirtualItem -BaseName 'B' -Ext 'txt' -Contents 'Two'

        $A = @($F1, $F2)
        $B = @($F2.Clone(), $F1.Clone())

        $result = Compare-SortedCollections `
            -ContextLabel "VirtualItem" `
            -ListA $A `
            -ListB $B `
            -SortKey { $_.Name() } `
            -Comparer { param($x, $y) $x.Equals($y, $false) } 

        $result | Should -BeTrue
    }

    It "returns true for two equivalent directories with Items in different order" {
        $F1 = New-VirtualItem -BaseName 'A' -Ext 'txt' -Contents 'One'
        $F2 = New-VirtualItem -BaseName 'B' -Ext 'txt' -Contents 'Two'

        $A = New-VirtualFolder -Name "Folder"
        $B = $A.Clone($Global:CloneType_Recursive)

        $A.Items = @($F1, $F2)
        $B.Items = @($F2.Clone(), $F1.Clone())

        $result = $A.Equals($B)

        $result | Should -BeTrue
    }

    It "returns false for VirtualFolders with unequal SubDirs" {
        $P1 = New-VirtualFolder -Name 'Parent'
        $P2 = New-VirtualFolder -Name 'Parent'

        $P1.AddSubFolder((New-VirtualFolder -Name 'ChildA'))
        $P2.AddSubFolder((New-VirtualFolder -Name 'ChildB'))

        $result = $P1.Equals($P2)
        $result | Should -BeFalse
    }

    It "returns false when VirtualItem differ in content" {
        $F1 = New-VirtualItem -BaseName 'X' -Ext 'txt' -Contents 'Good'
        $F2 = $F1.Clone()
        $F2.SetContents('Bad')

        $result = Compare-SortedCollections `
            -ContextLabel "VirtualItem" `
            -ListA @($F1) `
            -ListB @($F2) `
            -SortKey { $_.Name() } `
            -Comparer { param($x, $y) $x.Equals($y) }

        $result | Should -BeFalse
    }
}
