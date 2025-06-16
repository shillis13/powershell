. "$PSScriptRoot/../Initialize-CoreConfig.ps1"
. "$PSScriptRoot/../TerminalUtils/SetDir-BaseDirsUtils.ps1"

Describe 'SetDir-BaseDirsUtils' {
    It 'sets and gets the base dirs file path' {
        Set-BaseDirsFile 'test.psd1'
        Get-BaseDirsFile | Should -Be 'test.psd1'
    }

    It 'publishes base dirs from file' {
        $tmp = Join-Path $env:TEMP "baseDirs_$((Get-Random)).psd1"
        "@('A','B')" | Set-Content -Path $tmp -Encoding UTF8
        Set-BaseDirsFile $tmp
        Publish-BaseDirs
        $global:BaseDirs | Should -Contain 'A'
        $global:BaseDirs | Should -Contain 'B'
        Remove-Item $tmp -Force
    }

    It 'adds new base dir via Edit-BaseDirs' {
        $tmp = Join-Path $env:TEMP "baseDirs_$((Get-Random)).psd1"
        "@('A')" | Set-Content -Path $tmp -Encoding UTF8
        Set-BaseDirsFile $tmp
        Publish-BaseDirs
        Edit-BaseDirs -Add 'B'
        $global:BaseDirs | Should -Contain 'B'
        Remove-Item $tmp -Force
    }
}
