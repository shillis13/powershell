
Describe "Export-DirUtils Test of Directory Hierarchy" {
    #region     BeforeAll
    BeforeAll {
        # Dot-source or define the function you're testing or need to use
        Import-Module "$env:PowerShellModules\VirtualFolderFileUtils\VirtualFolderFileUtils.psd1" -Force
        . "$env:PowerShellScripts\FileUtils\Export-DirUtils.ps1" 
        . "$env:PowerShellScripts\DevUtils\Logging.ps1"
        . "$env:PowerShellScripts\DevUtils\DryRun.ps1"
        . "$env:PowerShellScripts\FileUtils\Zip-Contents.ps1" 
        . "$env:PowerShellScripts\FileUtils\Export-DirUtils.ps1"      

        function Write-DirFileTestHierarchy {
            param([string]$RootPath)

            $rootDirname = Format-Path (Split-Path -Path $RootPath -Leaf)

            $root      = New-VirtualFolder -Name $rootDirname -ParentFolder $null
            $excluded1 = New-VirtualFolder -Name 'excluded1' -ParentFolder $root
            $level1    = New-VirtualFolder -Name 'level1'    -ParentFolder $root
            $sub1      = New-VirtualFolder -Name 'sub1'      -ParentFolder $level1
            $sub2      = New-VirtualFolder -Name 'sub2'      -ParentFolder $level1
            $excluded2 = New-VirtualFolder -Name 'excluded2' -ParentFolder $level1
            $deep1     = New-VirtualFolder -Name 'deep1'     -ParentFolder $sub1
            $deep2     = New-VirtualFolder -Name 'deep2'     -ParentFolder $sub2

            # Files under each dir
            $null = New-VirtualItem -BaseName 'main' -Ext 'ps1' -ParentFolder $root     -Contents '# main.ps1'
            $null = New-VirtualItem -BaseName 'utils' -Ext 'py' -ParentFolder $root     -Contents '# utils.py'
            $null = New-VirtualItem -BaseName 'config' -Ext 'json' -ParentFolder $root  -Contents '{ "val": 1 }'
            $null = New-VirtualItem -BaseName 'ignore' -Ext 'tmp' -ParentFolder $root   -Contents 'temp data'

            $null = New-VirtualItem -BaseName 'a' -Ext 'ps1'    -ParentFolder $sub1 -Contents 'a'
            $null = New-VirtualItem -BaseName 'b' -Ext 'py'     -ParentFolder $sub1 -Contents 'b'
            $null = New-VirtualItem -BaseName 'c' -Ext 'conf'   -ParentFolder $sub1 -Contents 'c'
            $null = New-VirtualItem -BaseName 'd' -Ext 'txt'    -ParentFolder $sub1 -Contents 'd'

            $null = New-VirtualItem -BaseName 'x' -Ext 'sh'     -ParentFolder $sub2 -Contents 'x'
            $null = New-VirtualItem -BaseName 'y' -Ext 'ps1'    -ParentFolder $sub2 -Contents 'y'
            $null = New-VirtualItem -BaseName 'z' -Ext 'py'     -ParentFolder $sub2 -Contents 'z'
            $null = New-VirtualItem -BaseName 'w' -Ext 'json'   -ParentFolder $sub2 -Contents 'w'

            $null = New-VirtualItem -BaseName 'shouldNot' -Ext 'ps1' -ParentFolder $excluded1 -Contents 'nope'
            $null = New-VirtualItem -BaseName 'skipme' -Ext 'txt'    -ParentFolder $excluded1 -Contents 'nope'

            $null = New-VirtualItem -BaseName 'dontcopy' -Ext 'py'  -ParentFolder $excluded2 -Contents 'nope'
            $null = New-VirtualItem -BaseName 'leave' -Ext 'txt'    -ParentFolder $excluded2 -Contents 'nope'

            $null = New-VirtualItem -BaseName 'deep' -Ext 'ps1' -ParentFolder $deep1 -Contents 'deep'
            $null = New-VirtualItem -BaseName 'also' -Ext 'py'  -ParentFolder $deep1 -Contents 'also'
            $null = New-VirtualItem -BaseName 'not' -Ext 'json' -ParentFolder $deep1 -Contents '{}'
            $null = New-VirtualItem -BaseName 'this' -Ext 'tmp' -ParentFolder $deep1 -Contents 'tmp'

            $null = New-VirtualItem -BaseName 'more' -Ext 'ps1'     -ParentFolder $deep2 -Contents 'more'
            $null = New-VirtualItem -BaseName 'evenmore' -Ext 'sh'  -ParentFolder $deep2 -Contents 'sh'
            $null = New-VirtualItem -BaseName 'config' -Ext 'json'  -ParentFolder $deep2 -Contents '{ "val": 2 }'
            $null = New-VirtualItem -BaseName 'script' -Ext 'py'    -ParentFolder $deep2 -Contents 'script'

            $writeAction = [ItemActionType]::Write
            Write-FolderHierarchy -DestFolderPath $RootPath -SrcVirtualFolder $root -ItemAction $writeAction
            return $root
        }
    }
    #endregion

    It "copies and filters correctly and matches expected structure" {
        $testRoot = Join-Path $env:TEMP "ScriptTest_$(Get-Random)"
        $src = "$testRoot\src"
        $dst = "$testRoot\dst"
        $zip = "$testRoot\out.zip"

        New-Item -ItemType Directory -Path $src -Force | Out-Null
        New-Item -ItemType Directory -Path $dst -Force | Out-Null

        $excludedDirs = @('excluded1', 'level1\excluded2')
        $root = Write-DirFileTestHierarchy -RootPath $src
        $root = $root

        #$expectedSpecDir = $root.Clone()
        $expectedSpecDir = Read-FolderHierarchy -FolderPath $src -ReadContents:$false
        $expectedSpecDir.RemoveMatches('excluded', $true, $true)
        $expectedSpecDir.RemoveMatches('temp', $false, $true)
        $expectedSpecDir.RemoveMatches('backup', $false, $true)
        $expectedSpecDir.ChangeItemExts('ps1', 'txt', $true)
        $expectedSpecDir.ChangeItemExts('psm1', 'txt', $true)

        #Export-CleanDir -SourceDir $src -DestDir $dst -Exclude $excludedDirs -Zip -ZipFile $zip -NI
        Copy-CleanZipDir -SrcDir $src -DstDir $dst -ExcludeList $excludedDirs -Zip -ZipFile $zip -NI -Exec

        $srcDirname = Split-Path -Path $src -Leaf
        $readRootDirPath = Join-Path $dst $srcDirname
        $dstSpecDir = Read-FolderHierarchy -FolderPath $readRootDirPath -ReadContents:$false

        $equal = $expectedSpecDir.Equals($dstSpecDir)

        $equal | Should -BeTrue

        if (-not $equal) {
            Write-Host "Expected Structure:`n$($expectedSpecDir.PrintFolder($true, 0, $null))"
            Write-Host "Actual Structure:`n$($dstSpecDir.PrintFolder($true, 0, $null))"
        }
    }
}
