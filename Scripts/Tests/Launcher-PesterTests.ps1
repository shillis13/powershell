# Launch-PesterTests.ps1
# Runs all relevant Pester test files with optional breakpoints
if (-not $Script:PSRoot) {
    $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    Write-Debug "Set Script:PSRoot = $Script:PSRoot"
}
if (-not $Script:PSRoot) {
    throw "Script:PSRoot must be set by the entry-point script before using internal components."
}
if (-not $Script:CliArgs) {
    $Script:CliArgs = $args
}

. "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"

#. "$env:PowerShellScripts/DevUtils/Logging.ps1"
#Import-Module "$Script:PSRoot\Modules\VirtualFolderFileUtils\VirtualFolderFileUtils.psd1" -Force

Set-DryRun $false
#Set-LogLevel $LogAll
#Set-LogLevel $LogDebug

$test01 = "$Script:PSRoot\Scripts\Tests\Test-CompareSortedCollections.Tests.ps1"
$test02 = "$Script:PSRoot\Scripts\Tests\Test-CompareSpecObjects.Tests.ps1"
$test03 = "$Script:PSRoot\Scripts\Tests\Test-ExportDirUtils.Tests.ps1"
$test04 = "$Script:PSRoot\Scripts\Tests\Test-FormatUtils.Tests.ps1"
$test05 = "$Script:PSRoot\Scripts\Tests\Test-NewItemNameWithDate.Tests.ps1"
$test06 = "$Script:PSRoot\Scripts\Tests\Test-CompareEquals.Tests.ps1"
$test07 = "$Script:PSRoot\Scripts\Tests\Test-CallStack.Tests.ps1"
$test08 = "$Script:PSRoot\Scripts\Tests\Test-GetOutlookItemType.Tests.ps1"
$test09 = "$Script:PSRoot\Scripts\Tests\Test-DateTimeUtils.Tests.ps1"
$test10 = "$Script:PSRoot\Scripts\Tests\Test-Logging.Tests.ps1"
$test11 = "$Script:PSRoot\Scripts\Tests\Test-SelectFiles.Tests.ps1"


# Optional breakpoints
# Set-PSBreakpoint -Script "$PSScriptRoot\..\DevUtils\Compare-Utils.ps1" -Line 25
#Set-PSBreakpoint -Command 'Start-Process'
#Set-PSBreakpoint -Command 'Invoke-Item'
#Set-PSBreakpoint -Command '&'

$conf = [PesterConfiguration]::Default
$conf.Run.Path = @($test01, $test02, $test03, $test04, $test05, $test06, $test07, $test08, $test09, $test10, $test11)
#$conf.Run.Path = @($test01, $test02, $test03, $test04, $test05, $test06)

$conf.Output.Verbosity = 'Detailed'

Invoke-Pester -Configuration $conf
