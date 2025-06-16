. "$PSScriptRoot/../Initialize-CoreConfig.ps1"
. "$PSScriptRoot/../DevUtils/Format-Utils.ps1"

Describe 'Get-PaddedText' {
    It 'left aligns text when width is sufficient' {
        Get-PaddedText -Text 'abc' -Width 6 -Align 'left' | Should -Be 'abc   '
    }

    It 'center aligns text when width is sufficient' {
        Get-PaddedText -Text 'abc' -Width 7 -Align 'center' | Should -Be '  abc  '
    }

    It 'right aligns text when width is sufficient' {
        Get-PaddedText -Text 'abc' -Width 5 -Align 'right' | Should -Be '  abc'
    }

    It 'uses minimum width when width too small' {
        Get-PaddedText -Text 'abc' -Width 2 -Align 'left' | Should -Be 'abc  '
    }

    It 'truncates text that exceeds width' {
        Get-PaddedText -Text 'abcdefghij' -Width 5 -Align 'left' | Should -Be 'a...j'
    }
}
