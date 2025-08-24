# Test-Packager.Tests.ps1

# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

Describe "Packager.ps1" {
    BeforeAll {
        if (-not $Script:PSRoot) {
            $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
            Write-Host "Set Script:PSRoot = $Script:PSRoot"
        }
        if (-not $Script:PSRoot) {
            throw 'Script:PSRoot must be set by the entry-point script before using internal components.'
        }

        $Script:CliArgs = $args
        . "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"

        $Script:scriptUnderTest = "$Script:PSRoot\Scripts\Packager\Packager.ps1"
        . "$Script:scriptUnderTest"
    }

    Context "ConvertTo-ConfigHashtable" {
        It "Converts PSCustomObject to hashtable" {
            $input = [pscustomobject]@{
                Name = "Test"
                Nested = [pscustomobject]@{ Value = 42 }
                Array = @(
                    [pscustomobject]@{ Item = 1 },
                    [pscustomobject]@{ Item = 2 }
                )
            }

            $result = ConvertTo-ConfigHashtable -InputObject $input

            $result | Should -BeOfType Hashtable
            $result.Name | Should -Be "Test"
            $result.Nested | Should -BeOfType Hashtable
            $result.Nested.Value | Should -Be 42
            $result.Array | Should -HaveCount 2
            $result.Array[0].Item | Should -Be 1
        }
    }

    Context "New-PackageConfigTemplate" {
        It "Creates minimal package config file" {
            $path = Join-Path $TestDrive 'template.json'

            $template = New-PackageConfigTemplate -OutputPath $path -PackageName 'TestPkg' -Version '9.9.9' -Minimal

            Test-Path $path | Should -BeTrue
            $template.package.name | Should -Be 'TestPkg'
            $template.package.version | Should -Be '9.9.9'

            $json = Get-Content $path -Raw | ConvertFrom-Json
            $json.package.name | Should -Be 'TestPkg'
            $json.package.version | Should -Be '9.9.9'
        }
    }

    Context "New-DirectoryStructure" {
        It "Creates directories from config" {
            $base = Join-Path $TestDrive 'out'
            $config = @{
                files = @(
                    @{ destination = 'scripts' },
                    @{ destination = 'docs' }
                )
                directories = @('tests')
            }

            $result = New-DirectoryStructure -BasePath $base -Config $config -Force
            $result | Should -BeTrue
            (Test-Path (Join-Path $base 'scripts')) | Should -BeTrue
            (Test-Path (Join-Path $base 'docs')) | Should -BeTrue
            (Test-Path (Join-Path $base 'tests')) | Should -BeTrue
        }
    }
}

# ===========================================================================================
#endregion
# ===========================================================================================
