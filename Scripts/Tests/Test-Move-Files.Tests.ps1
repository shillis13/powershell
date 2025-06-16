. "$PSScriptRoot/../Initialize-CoreConfig.ps1"
. "$PSScriptRoot/../FileUtils/Move-Files.ps1"

Describe 'Move-Files' {
    BeforeAll {
        $script:Src = Join-Path $env:TEMP "MoveFilesSrc_$((Get-Random))"
        $script:Dst = Join-Path $env:TEMP "MoveFilesDst_$((Get-Random))"
        New-Item -ItemType Directory -Path $script:Src -Force | Out-Null
        New-Item -ItemType Directory -Path $script:Dst -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:Src -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $script:Dst -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'moves matching files to destination' {
        $file = New-Item -ItemType File -Path (Join-Path $script:Src 'foo.txt') -Force
        Move-Files -srcDir $script:Src -dstDir $script:Dst -filePattern 'foo' -TOTAL_TIMEOUT 1 -DELAY_SECONDS 0
        Test-Path (Join-Path $script:Dst $file.Name) | Should -BeTrue
        Test-Path $file.FullName | Should -BeFalse
    }

    It 'respects DryRun switch' {
        $file = New-Item -ItemType File -Path (Join-Path $script:Src 'bar.txt') -Force
        Move-Files -srcDir $script:Src -dstDir $script:Dst -filePattern 'bar' -DryRun -TOTAL_TIMEOUT 1 -DELAY_SECONDS 0
        Test-Path $file.FullName | Should -BeTrue
        Test-Path (Join-Path $script:Dst $file.Name) | Should -BeFalse
        Remove-Item $file.FullName -Force
    }
}
