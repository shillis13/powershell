# Compare-SortedCollections.Tests.ps1
# Requires: Pester v5+

function InitializeCore {
    if (-not $Script:PSRoot) {
        $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
        Write-Host "Set Script:PSRoot = $Script:PSRoot"
    }
    if (-not $Script:PSRoot) {
        throw 'Script:PSRoot must be set by the entry-point script before using internal components.'
    }

    $Script:CliArgs = $args
    . "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"

    $Script:scriptUnderTest = "$Script:PSRoot\Scripts\DevUtils\Compare-Utils.ps1"
}



Describe "Compare-SortedCollections" {

    BeforeAll {
        # InitializeCore
        if (-not $Script:PSRoot) {
            $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
            Write-Host "Set Script:PSRoot = $Script:PSRoot"
        }
        if (-not $Script:PSRoot) {
            throw 'Script:PSRoot must be set by the entry-point script before using internal components.'
        }

        $Script:CliArgs = $args
        . "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"

        $Script:scriptUnderTest = "$Script:PSRoot\Scripts\DevUtils\Compare-Utils.ps1"
        . "$Script:scriptUnderTest"
    }

    It "returns true for lists with same elements in different order" {
        $a = @(1, 2, 3)
        $b = @(3, 1, 2)

        $result = Compare-SortedCollections `
            -ContextLabel "Numbers" `
            -ListA $a `
            -ListB $b `
            -SortKey { $_ } `
            -Comparer { param($x, $y) $x -eq $y } `
            -FullEvaluation:$true

        $result | Should -BeTrue
    }

    It "returns false when lists differ in content" {
        $a = @(1, 2, 3)
        $b = @(1, 2, 4)

        $result = Compare-SortedCollections `
            -ContextLabel "Mismatch" `
            -ListA $a `
            -ListB $b `
            -SortKey { $_ } `
            -Comparer { param($x, $y) $x -eq $y }

        $result | Should -BeFalse
    }

    It "returns false when list counts differ" {
        $a = @("apple", "banana")
        $b = @("apple")

        $result = Compare-SortedCollections `
            -ContextLabel "Fruits" `
            -ListA $a `
            -ListB $b `
            -SortKey { $_ } `
            -Comparer { param($x, $y) $x -eq $y }

        $result | Should -BeFalse
    }
}
