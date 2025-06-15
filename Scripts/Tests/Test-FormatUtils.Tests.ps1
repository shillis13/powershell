# Test-FormatUtilities.Tests.ps1



Describe "Format-Hashtable" {

    BeforeAll {
        # Load module and dependencies
        #Import-Module "$env:PowerShellModules\Log Utils\FormatUtilities.psm1" -Force
        . "$env:PowerShellScripts\DevUtils\Format-Utils.ps1" 
        . "$env:PowerShellScripts\DevUtils\Compare-Utils.ps1" 

        #Set-LogLevel $LogDebug
    }

    It "formats an empty hashtable without label" {
        $result = Format-Hashtable -Table @{}
        Log -Dbg "Result = $result"
        $result | Should -BeExactly "(empty hashtable)"
    }

    It "formats an empty hashtable with label" {
        $result = Format-Hashtable -Table @{} -Label "Config"
        Log -Dbg "Result = $result"
        $result | Should -BeExactly "Config: (empty hashtable)"
    }

    It "formats a simple hashtable in default style" {
        $ht = @{ a = 1; b = 2 }
        $result = Format-Hashtable -Table $ht
        Log -Dbg "Result = $result"
        $expected = "a=1; b=2" -split "; " | Sort-Object | Out-String
        ($result -split "; " | Sort-Object | Out-String) | Should -BeExactly $expected
    }

    It "formats with Pretty switch to use newline" {
        $ht = @{ x = "foo"; y = "bar" }
        $result = Format-Hashtable -Table $ht -Pretty
        Log -Dbg "Result = $result"
        ($result -split "`n").Count | Should -Be 2
    }

    It "applies label prefix if provided" {
        $ht = @{ a = 42 }
        $result = Format-Hashtable -Table $ht -Label "MyLabel"
        Log -Dbg "Result = $result"
        $result | Should -Match "^MyLabel: \n"
    }
}

Describe "Format-ToString" {

    BeforeAll {
        # Load module and dependencies
        #Import-Module "$env:PowerShellModules\Log Utils\FormatUtilities.psm1" -Force
        . "$env:PowerShellScripts\DevUtils\Format-Utils.ps1"
    }

#    Invoke-LogLevelOverride -LogLevel $LogDebug -ScriptBlock {
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
            $result | Should -BeExactly "[ 1, 2, `"three`" ]"
        }

        It "formats hashtables using Format-Hashtable" {
            $ht = @{ foo = "bar"; count = 5 }
            $htStr = Format-ToString -Obj $ht
            Log -Dbg "htString  = $htStr"
                
            $ht2 = Invoke-Expression $htStr
            $ht2Str = Format-ToString -Obj $ht2
            Log -Dbg "ht2String = $ht2Str"

            $result = ($htStr -eq $ht2Str) 
            #if (-not $results) { $result = Compare-Equals($ht, $ht2) }

            if (-not $result) { 
                Log -Dbg "htString = $htStr"
                Log -Dbg "ht2String = $ht2Str"
            }
            $result | Should -BeTrue
        }
#    }
}
