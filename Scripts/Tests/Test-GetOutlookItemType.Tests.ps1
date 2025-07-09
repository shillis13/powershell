# =========================
# Get-OutlookItemType.Tests.ps1
# =========================

# Ensure DevUtils is sourced before running these tests.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\..\DevUtils\Get-CallStack.ps1"

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
    
    $Script:scriptUnderTest = "$Script:PSRoot\Scripts\OutlookUtils\Outlook.Interface.ps1"
}


Describe "Get-OutlookItemType" {

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
    
        $Script:scriptUnderTest = "$Script:PSRoot\Scripts\OutlookUtils\Outlook.Interface.ps1"
        . "$Script:scriptUnderTest"

        function New-FakeOutlookItem {
            param (
                [string]$MessageClass,
                [string]$Subject = "Test Subject",
                [string]$EntryID = "123"
            )

            return [pscustomobject]@{
                MessageClass = $MessageClass
                Subject      = $Subject
                EntryID      = $EntryID
            }
        }
    }


    It "returns Mail for IPM.Note" {
        $item = New-FakeOutlookItem "IPM.Note"
        $result = Get-OutlookItemType -Item $item
        $result | Should -Be ([OutlookItemType]::Mail)
    }

    It "returns Mail for IPM.Note.SMIME" {
        $item = New-FakeOutlookItem "IPM.Note.SMIME"
        $result = Get-OutlookItemType -Item $item
        $result | Should -Be ([OutlookItemType]::Mail)
    }

    It "returns Meeting for IPM.Schedule.Meeting.Request" {
        $item = New-FakeOutlookItem "IPM.Schedule.Meeting.Request"
        $result = Get-OutlookItemType -Item $item
        $result | Should -Be ([OutlookItemType]::Meeting)
    }

    It "returns Appointment for IPM.Appointment" {
        $item = New-FakeOutlookItem "IPM.Appointment"
        $result = Get-OutlookItemType -Item $item
        $result | Should -Be ([OutlookItemType]::Appointment)
    }

    It "returns Contact for IPM.Contact" {
        $item = New-FakeOutlookItem "IPM.Contact"
        $result = Get-OutlookItemType -Item $item
        $result | Should -Be ([OutlookItemType]::Contact)
    }

    It "returns Contact for IPM.DistList" {
        $item = New-FakeOutlookItem "IPM.DistList"
        $result = Get-OutlookItemType -Item $item
        $result | Should -Be ([OutlookItemType]::Contact)
    }

    It "returns Unknown for IPM.Unknown.Type" {
        $item = New-FakeOutlookItem "IPM.Unknown.Type"
        $result = Get-OutlookItemType -Item $item
        $result | Should -Be ([OutlookItemType]::Unknown)
    }
}
