. "$PSScriptRoot/../Initialize-CoreConfig.ps1"
. "$PSScriptRoot/../FileUtils/Select-Files.ps1"

Describe 'Select-Files' {
    BeforeAll {
        $script:TestDir = Join-Path $env:TEMP "SelectFilesTest_$((Get-Random))"
        $null = New-Item -ItemType Directory -Path $script:TestDir -Force
        $null = New-Item -ItemType File -Path (Join-Path $script:TestDir 'file1.txt') -Force
        $null = New-Item -ItemType File -Path (Join-Path $script:TestDir 'file2.csv') -Force
        $null = New-Item -ItemType File -Path (Join-Path $script:TestDir 'report.txt') -Force
        $sub = Join-Path $script:TestDir 'Sub'
        $null = New-Item -ItemType Directory -Path $sub -Force
        $null = New-Item -ItemType File -Path (Join-Path $sub 'file3.txt') -Force
    }

    AfterAll {
        Remove-Item -Path $script:TestDir -Recurse -Force
    }

    It 'filters by extension' {
        $result = Select-Files -Dir $script:TestDir -Ext '.txt' -Recurse | Select-Object -ExpandProperty Name
        $result | Should -Contain 'file1.txt'
        $result | Should -Contain 'report.txt'
        $result | Should -Contain 'file3.txt'
        $result | Should -Not -Contain 'file2.csv'
    }

    It 'filters by substring' {
        $result = Select-Files -Dir $script:TestDir -SubStr 'report' | Select-Object -ExpandProperty Name
        $result | Should -Be @('report.txt')
    }

    It 'recurses into subdirectories with -Recurse' {
        $result = Select-Files -Dir $script:TestDir -Ext '.txt' -Recurse | Select-Object -ExpandProperty Name
        $result | Should -Contain 'file3.txt'
    }
}
