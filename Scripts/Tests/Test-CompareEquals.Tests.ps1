#======================================================================================
# Compare-Equals.Tests.ps1
#======================================================================================

# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================
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
    
    # Test_SelectFiles.Tests.ps1
    $Script:scriptUnderTest = "$Script:PSRoot\Scripts\DevUtils\Compare-Utils.ps1"
}

#endregion
# ===========================================================================================


Describe "Compare-Equals" {

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
    
        # Test_SelectFiles.Tests.ps1
        $Script:scriptUnderTest = "$Script:PSRoot\Scripts\DevUtils\Compare-Utils.ps1"
        . "$Script:scriptUnderTest"
    }

    Context "Null and primitive values" {
        It "Returns true for two nulls" {
            $result = Compare-Equals -Lhs $null -Rhs $null
            $result | Should -BeTrue
        }
        It "Returns false for null vs value" {
            $result =  Compare-Equals -Lhs $null -Rhs 42 
            $result | Should -BeFalse
        }
        It "Returns true for identical values" {
            $result = Compare-Equals -Lhs 5 -Rhs 5 
            $result | Should -BeTrue
        }
        It "Returns false for different values" {
            $result = Compare-Equals -Lhs "foo" -Rhs "bar"
            $result | Should -BeFalse
        }
    }

    Context "Array comparisons" {
        It "Returns true for identical arrays" {
            $result = Compare-Equals -Lhs @(1,2,3) -Rhs @(1,2,3)
            $result | Should -BeTrue
        }
        It "Returns false for arrays of different lengths" {
            $result = Compare-Equals -Lhs @(1,2,3) -Rhs @(1,2)
            $result | Should -BeFalse
        }
        It "Returns false for arrays with same values in different order" {
            $result = Compare-Equals -Lhs @(1,2,3) -Rhs @(3,2,1)
            $result | Should -BeFalse
        }
    }

    Context "Hashtable comparisons" {
        It "Returns true for matching hashtables" {
            $a = @{ foo = "bar"; count = 3 }
            $b = @{ count = 3; foo = "bar" }
            $result = Compare-Equals -Lhs $a -Rhs $b
            $result | Should -BeTrue
        }
        It "Returns false for mismatched keys" {
            $a = @{ foo = "bar"; count = 3 }
            $b = @{ foo = "bar"; extra = 99 }
            $result = Compare-Equals -Lhs $a -Rhs $b
            $result | Should -BeFalse
        }
    }

    Context "Custom ComparisonMethod" {
        It "Uses custom method to compare objects" {
            $obj1 = [PSCustomObject]@{ ID = 123; Name = "Alpha" }
            $obj2 = [PSCustomObject]@{ ID = 123; Name = "Beta" }

            $result = Compare-Equals -Lhs $obj1 -Rhs $obj2 -ComparisonMethod "ID" 
            $result | Should -BeTrue
        }
        It "Fails if ComparisonMethod not found" {
            $obj1 = [PSCustomObject]@{ ID = 123 }
            $obj2 = [PSCustomObject]@{ ID = 123 }
            $result = Compare-Equals -Lhs $obj1 -Rhs $obj2 -ComparisonMethod "Nonexistent" 
            $result | Should -BeFalse
        }
    }
}
