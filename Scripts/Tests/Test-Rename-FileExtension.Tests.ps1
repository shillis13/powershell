. "$PSScriptRoot/../Initialize-CoreConfig.ps1"
. "$PSScriptRoot/../FileUtils/Rename-FileExtension.ps1"

Describe 'Rename-FileExtension' {
    BeforeAll {
        $script:Dir = Join-Path $env:TEMP "RenameExt_$((Get-Random))"
        New-Item -ItemType Directory -Path $script:Dir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:Dir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'renames file extensions' {
        $file = New-Item -ItemType File -Path (Join-Path $script:Dir 'a.txt') -Force
        Rename-FileExtension -OldExt 'txt' -NewExt 'log' -Dir $script:Dir
        Test-Path (Join-Path $script:Dir 'a.log') | Should -BeTrue
        Test-Path $file.FullName | Should -BeFalse
    }

    It 'performs dry run when -DryRun used' {
        $file = New-Item -ItemType File -Path (Join-Path $script:Dir 'b.txt') -Force
        Rename-FileExtension -OldExt 'txt' -NewExt 'log' -Dir $script:Dir -DryRun
        Test-Path $file.FullName | Should -BeTrue
        Test-Path (Join-Path $script:Dir 'b.log') | Should -BeFalse
        Remove-Item $file.FullName -Force
    }
}
