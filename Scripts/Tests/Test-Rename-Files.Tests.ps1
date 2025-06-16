. "$PSScriptRoot/../Initialize-CoreConfig.ps1"
. "$PSScriptRoot/../FileUtils/Rename-Files.ps1"

Describe 'Get-FilteredFiles' {
    BeforeAll {
        $script:Dir = Join-Path $env:TEMP "Filtered_$((Get-Random))"
        $sub = Join-Path $script:Dir 'sub'
        New-Item -ItemType Directory -Path $script:Dir -Force | Out-Null
        New-Item -ItemType Directory -Path $sub -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:Dir 'a.txt') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $sub 'b.csv') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:Dir 'report.txt') -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:Dir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'filters by extension and substring' {
        $files = Get-FilteredFiles -Path $script:Dir -Extension '.txt' -Substring 'report' -Recurse
        $files.Name | Should -Be @('report.txt')
    }
}

Describe 'New-UniqueFilename' {
    BeforeAll {
        $script:Dst = Join-Path $env:TEMP "Unique_$((Get-Random))"
        New-Item -ItemType Directory -Path $script:Dst -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:Dst 'Base_20230101.txt') -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:Dst -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'generates a unique path when file exists' {
        $result = New-UniqueFilename -BaseName 'Base' -Extension '.txt' -CreationDate '20230101' -SequenceByDate:$false -DestPath $script:Dst -SrcPath $script:Dst
        Split-Path $result -Leaf | Should -Be 'Base_20230101_1.txt'
    }
}

Describe 'ConvertTo_SantizedName' {
    It 'replaces invalid characters with underscores' {
        ConvertTo_SantizedName -Name 'Inv<name>.txt' | Should -Be 'Inv_name_.txt'
    }
}

Describe 'Rename-And-MoveFiles' {
    BeforeAll {
        $script:Src = Join-Path $env:TEMP "RenameSrc_$((Get-Random))"
        $script:Dst = Join-Path $env:TEMP "RenameDst_$((Get-Random))"
        New-Item -ItemType Directory -Path $script:Src -Force | Out-Null
        New-Item -ItemType Directory -Path $script:Dst -Force | Out-Null
        $file = New-Item -ItemType File -Path (Join-Path $script:Src 'orig.csv') -Force
        (Get-Item $file.FullName).CreationTime = [datetime]'2023-01-01'
    }

    AfterAll {
        Remove-Item -Path $script:Src -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $script:Dst -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'renames and moves files' {
        Rename-And-MoveFiles -SrcPath $script:Src -DestPath $script:Dst -BaseName 'MyBase' -FilterByExtension '.csv'
        Test-Path (Join-Path $script:Dst 'MyBase_20230101.csv') | Should -BeTrue
        (Get-ChildItem -Path $script:Src).Count | Should -Be 0
    }
}
