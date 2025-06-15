# Launch-PesterTests.ps1
# Runs all relevant Pester test files with optional breakpoints
if (-not $Global:PSRoot) {
    $Global:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    Write-Debug "Set Global:PSRoot = $Global:PSRoot"
}
if (-not $Global:PSRoot) {
    throw "Global:PSRoot must be set by the entry-point script before using internal components."
}
if (-not $Global:CliArgs) {
    $Global:CliArgs = $args
}

. "$Global:PSRoot\Scripts\Initialize-CoreConfig.ps1"

#. "$env:PowerShellScripts/DevUtils/Logging.ps1"
Import-Module "$Global:PSRoot\Modules\VirtualFolderFileUtils\VirtualFolderFileUtils.psd1" -Force

Set-DryRun $false
Set-LogLevel $LogAll
#Set-LogLevel $LogDebug

$test1 = "$Global:PSRoot\Scripts\Tests\Test-CompareSortedCollections.Tests.ps1"
$test2 = "$Global:PSRoot\Scripts\Tests\Test-CompareSpecObjects.Tests.ps1"
$test3 = "$Global:PSRoot\Scripts\Tests\Test-ExportDirUtils.Tests.ps1"
$test4 = "$Global:PSRoot\Scripts\Tests\Test-FormatUtils.Tests.ps1"
$test5 = "$Global:PSRoot\Scripts\Tests\Test-NewItemNameWithDate.Tests.ps1"
$test6 = "$Global:PSRoot\Scripts\Tests\Test-CompareEquals.Tests.ps1"
$test7 = "$Global:PSRoot\Scripts\Tests\Test-CallStack.Tests.ps1"
$test8 = "$Global:PSRoot\Scripts\Tests\Test-GetOutlookItemType.Tests.ps1"
$test9 = "$Global:PSRoot\Scripts\Tests\TEst-DateTimeUtils.Tests.ps1"

# Optional breakpoints
# Set-PSBreakpoint -Script "$PSScriptRoot\..\DevUtils\Compare-Utils.ps1" -Line 25
#Set-PSBreakpoint -Command 'Start-Process'
#Set-PSBreakpoint -Command 'Invoke-Item'
#Set-PSBreakpoint -Command '&'

$conf = [PesterConfiguration]::Default
$conf.Run.Path = @($test1, $test2, $test3, $test4, $test5, $test6, $test7, $test8, $test9)
#$conf.Run.Path = @($test1, $test2, $test3, $test4, $test5, $test6)
#$conf.Run.Path = @($test4, $test6)
#$conf.Run.Path = @($test1)
#$conf.Run.Path = @($test2)
#$conf.Run.Path = @($test3)
#$conf.Run.Path = @($test4)
#$conf.Run.Path = @($test5)
#$conf.Run.Path = @($test6)
#$conf.Run.Path = @($test7)
#$conf.Run.Path = @($test8)
#$conf.Run.Path = @($test9)

$conf.Output.Verbosity = 'Detailed'

Invoke-Pester -Configuration $conf
