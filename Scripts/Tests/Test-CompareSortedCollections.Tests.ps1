# Compare-SortedCollections.Tests.ps1
# Requires: Pester v5+


Describe "Compare-SortedCollections" {

    BeforeAll {
        # Dot-source the function you're testing
        . "$env:PowerShellScripts/DevUtils/Compare-Utils.ps1"
        . "$env:PowerShellScripts/DevUtils/Logging.ps1"
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
