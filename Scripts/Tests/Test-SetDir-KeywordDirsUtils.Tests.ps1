. "$PSScriptRoot/../Initialize-CoreConfig.ps1"
. "$PSScriptRoot/../TerminalUtils/SetDir-KeywordDirsUtils.ps1"

Describe 'SetDir-KeywordDirsUtils' {
    It 'sets and gets keyword dirs file path' {
        Set-BKeywordDirsFile 'k.psd1'
        Get-KeywordDirsFile | Should -Be 'k.psd1'
    }

    It 'publishes keyword dirs from file' {
        $tmp = Join-Path $env:TEMP "keywordDirs_$((Get-Random)).psd1"
        "@{ a = 'A'; b = 'B' }" | Set-Content -Path $tmp -Encoding UTF8
        Set-BKeywordDirsFile $tmp
        Publish-KeywordDirs
        $global:KeywordDirs.Keys | Should -Contain 'a'
        $global:KeywordDirs['a'] | Should -Be 'A'
        Remove-Item $tmp -Force
    }

    It 'adds new keyword via Edit-KeywordDirs' {
        $tmp = Join-Path $env:TEMP "keywordDirs_$((Get-Random)).psd1"
        "@{ c = 'C' }" | Set-Content -Path $tmp -Encoding UTF8
        Set-BKeywordDirsFile $tmp
        Publish-KeywordDirs
        Edit-KeywordDirs -Add @{ d = 'D' }
        $global:KeywordDirs.Keys | Should -Contain 'd'
        Remove-Item $tmp -Force
    }
}
