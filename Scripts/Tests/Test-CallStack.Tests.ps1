#=========================
#region     Test-CallStack.Tests.ps1
<#
.SYNOPSIS
    Pester tests for CallStack.ps1 functions.
#>
#=========================

# Ensure DevUtils is sourced before running these tests.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\..\DevUtils\CallStack.ps1"

if (-not $Global:PSRoot) {
    $Global:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    Write-Host "Set Global:PSRoot = $Global:PSRoot"
}
if (-not $Global:PSRoot) {
    throw "Global:PSRoot must be set by the entry-point script before using internal components."
}

#if (-not $Global:CliArgs) {
    $Global:CliArgs = $args
#}


Describe "CallStack.ps1" {

    BeforeAll {
        . "$Global:PSRoot\Scripts\DevUtils\CallStack.ps1"
    }

    Context "Get-CallStackMax and Set-CallStackMax" {
        It "Should return default max values" {
            $result = Get-CallStackMax
            $result.MaxDepth     | Should -Be 10
            $result.MaxFcnWidth  | Should -Be 40
            $result.MaxFileWidth | Should -Be 50
            $result.MaxLineWidth | Should -Be 6
        }

        It "Should allow updating max values" {
            Set-CallStackMax -MaxDepth 5 -MaxFcnWidth 20 -MaxFileWidth 30 -MaxLineWidth 4
            $result = Get-CallStackMax
            $result.MaxDepth     | Should -Be 5
            $result.MaxFcnWidth  | Should -Be 20
            $result.MaxFileWidth | Should -Be 30
            $result.MaxLineWidth | Should -Be 4

            # Set values back to previous
            Set-CallStackMax -MaxDepth 10 -MaxFcnWidth 40 -MaxFileWidth 50 -MaxLineWidth 6
        }
    }

    Context "Get-CallStack" {
        It "Should return a string with multiple frames" {
            function DummyA { DummyB }
            function DummyB { DummyC }
            function DummyC { return Get-CallStack -Depth 5 }
            $stack = DummyA
            Write-Host "Call Stack:`n$stack"
            $stack -split "\n" | Should -HaveCount 7
            $stack | Should -Match "DummyA"
            $stack | Should -Match "DummyB"
            $stack | Should -Match "DummyC"
        }

        It "Should insert ellipsis when exceeding max depth" {
            Set-CallStackMax -MaxDepth 3
            function X1 { X2 }
            function X2 { X3 }
            function X3 { X4 }
            function X4 { X5 }
            function X5 { return Get-CallStack }
            $result = X1
            $result | Should -Match "... \("
        }
    }

    Context "Get-StackFrame" {
        It "Should retrieve a specific frame" {
            function Foo { Bar }
            function Bar { return Get-StackFrame -Index 0 }
            $frame = Foo
            $frame.FunctionName | Should -Be "Bar"
        }

        It "Should return null for out-of-bounds index" {
            $frame = Get-StackFrame -Index 9999
            $frame | Should -BeNullOrEmpty
        }
    }

    Context "Get-CurrentFunctionName and Get-CallerFunctionName" {
        It "Should return the current function name" {
            function Here { return Get-CurrentFunctionName }
            $name = Here
            $name | Should -Be "Here"
        }

        It "Should return the caller function name" {
            function A { B }
            function B { return Get-CallerFunctionName }
            $caller = A
            $caller | Should -Be "A"
        }
    }
}
#endregion
