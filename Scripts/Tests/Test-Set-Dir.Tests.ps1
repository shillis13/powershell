. "$PSScriptRoot/../Initialize-CoreConfig.ps1"
. "$PSScriptRoot/../TerminalUtils/Set-Dir.ps1"

Describe 'Set-Dir' {
    BeforeAll {
        $script:Target = Join-Path $env:TEMP "GoDir_$((Get-Random))"
        New-Item -ItemType Directory -Path $script:Target -Force | Out-Null
        $global:KeywordDirs = @{ test = $script:Target }
        $global:BaseDirs = @($env:TEMP)
    }

    AfterAll {
        Remove-Item -Path $script:Target -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'navigates to keyword directory' {
        Mock Set-Location {}
        Set-Dir -Keyword 'test'
        Assert-MockCalled Set-Location -ParameterFilter { $Path -eq $script:Target } -Times 1
    }

    It 'falls back to base dirs when keyword missing' {
        $dir = Join-Path $env:TEMP 'fallback'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Mock Set-Location {}
        Set-Dir -Keyword (Split-Path -Leaf $dir)
        Assert-MockCalled Set-Location -ParameterFilter { $Path -eq $dir } -Times 1
        Remove-Item $dir -Recurse -Force
    }
}
