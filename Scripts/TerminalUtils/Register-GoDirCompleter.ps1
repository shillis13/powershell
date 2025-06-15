# PowerShell File Guard to prevent multiple includes of a file
if (Get-Variable -Name Included_Register-GoDirCompleter_ps1 -Scope Script -ErrorAction SilentlyContinue) { return }
Set-Variable -Name Included_Register-GoDirCompleter_ps1 -Scope Script -Value true

. "$env:PowerShellScripts\\TerminalUtils\\SetDir-BaseDirsUtils.ps1"  
. "$env:PowerShellScripts\\TerminalUtils\\SetDir-KeywordDirsUtils.ps1" 

# ================================================================
# Script: Register-SetDirCompleter
# Description:
#   Enables tab-completion for Set-Dir's Keyword parameter
# ================================================================
Register-ArgumentCompleter -CommandName godir -ParameterName Keyword -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    Publish-KeywordDirs
    Publish-BaseDirs

    $options = @($global:KeywordDirs.Keys) + ($global:BaseDirs | ForEach-Object { Split-Path -Leaf $_ })

    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

# ********************************************************************

