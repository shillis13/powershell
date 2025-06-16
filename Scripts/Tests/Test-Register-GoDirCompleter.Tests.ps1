. "$PSScriptRoot/../Initialize-CoreConfig.ps1"
. "$PSScriptRoot/../TerminalUtils/Register-GoDirCompleter.ps1"

Describe 'Register-GoDirCompleter' {
    It 'registers argument completer for godir' {
        Mock Register-ArgumentCompleter {}
        . "$PSScriptRoot/../TerminalUtils/Register-GoDirCompleter.ps1"
        Assert-MockCalled Register-ArgumentCompleter -Times 1
    }
}
