# Test-FormatUtilities.Tests.ps1

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
    
    $Script:scriptUnderTest = "$Script:PSRoot\Scripts\DevUtils\Format-Utils.ps1"

}

#endregion
# ===========================================================================================


Describe "Format-ToString" {

    BeforeAll {
        #InitializeCore
        if (-not $Script:PSRoot) {
            $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
            Write-Host "Set Script:PSRoot = $Script:PSRoot"
        }
        if (-not $Script:PSRoot) {
            throw 'Script:PSRoot must be set by the entry-point script before using internal components.'
        }

        $Script:CliArgs = $args
        . "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"
    
        $Script:scriptUnderTest = "$Script:PSRoot\Scripts\DevUtils\Format-Utils.ps1"
        . "$Script:scriptUnderTest"
    }

    It "returns '(null)' for null input" {
        $result = Format-ToString -Obj $null
        Log -Dbg "Result = $result"
        $result | Should -BeExactly "(null)"
    }

    It "converts a simple literal string as-is" {
        $result = Format-ToString -Obj "hello1"
        Log -Dbg "Result = $result"
        $result | Should -BeExactly "`"hello1`""
    }

    It "converts a simple string variable as-is" {
        $hello = "hello2"
        $result = Format-ToString -Obj $hello 
        Log -Dbg "Result = $result"
        $result | Should -BeExactly "`"$hello`""
    }

    It "formats arrays with Format-ToString recursively" {
        $result = Format-ToString -Obj @(1, 2, "three")
        Log -Dbg "Result = $result"
        $result | Should -BeExactly "[ 1; 2; `"three`" ]"
    }

    It "formats hashtables using Format-ToString" {
        $ht = @{ foo = "bar"; count = 5 }
        $htStr = Format-ToString -Obj $ht
        Log -Dbg "htString  = $htStr"
            
        $ht2 = Invoke-Expression $htStr
        $ht2Str = Format-ToString -Obj $ht2
        Log -Dbg "ht2String = $ht2Str"

        $result = ($htStr -eq $ht2Str) 

        if (-not $result) { 
            Log -Dbg "htString = $htStr"
            Log -Dbg "ht2String = $ht2Str"
        }
        $result | Should -BeTrue
    }

    It "formats custom objects without ToString method" {
        $customObj = New-Object PSObject -Property @{
            Name = "John"
            Age = 30
        }
        $result = Format-ToString -Obj $customObj
        Log -Dbg "Result = $result"
        $result | Should -BeExactly "{ Age=30; Name=`"John`" }"
    }

    It "formats custom objects with ToString method" {
        Add-Type -TypeDefinition @"
        public class CustomClass {
            public string Name { get; set; }
            public int Age { get; set; }
            public override string ToString() {
                return Name + " (" + Age + ")";
            }
        }
"@
        $customObj = [CustomClass]::new()
        $customObj.Name = "John"
        $customObj.Age = 30
        $result = Format-ToString -Obj $customObj
        Log -Dbg "Result = $result"
        $result | Should -BeExactly "John (30)"
    }

    It "formats custom objects with empty ToString method" {
        Add-Type -TypeDefinition @"
        public class CustomClassEmptyToString {
            public string Name { get; set; }
            public int Age { get; set; }
            public override string ToString() {
                return "";
            }
        }
"@
        $customObj = [CustomClassEmptyToString]::new()
        $customObj.Name = "John"
        $customObj.Age = 30
        $result = Format-ToString -Obj $customObj
        Log -Dbg "Result = $result"
        $result | Should -BeExactly "{ Age=30; Name=`"John`" }"
    }

}