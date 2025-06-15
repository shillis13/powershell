# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

if (-not $Global:PSRoot) {
    $Global:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    Log -Dbg "Set Global:PSRoot = $Global:PSRoot"
}
if (-not $Global:PSRoot) {
    throw "Global:PSRoot must be set by the entry-point script before using internal components."
}

if (-not $Global:CliArgs) {
    $Global:CliArgs = $args
}

. "$Global:PSRoot\Scripts\Initialize-CoreConfig.ps1"
. "$Global:PSRoot\Scripts\OutlookUtils\SaveOutlookAttachments.ps1"
. "$Global:PSRoot\Scripts\FileUtils\Rename-Files.ps1"
. "$Global:PSRoot\Scripts\FileUtils\Backup-Files.ps1"

#endregion
# ===========================================================================================

#$REPORTS_DIR = "P:\Implementation\Engineering\Project Mgmt\SpendPlan\Data\Raw_Data"
$REPORTS_DIR = "C:\Users\shawn.hillis\OneDrive - General Dynamics Mission Systems\Documents\Excel\SpendPlan\Data\Raw_Data"

#$SaveOutlookAttachments = Join-Path $PSScriptRoot "OutlookUtils\SaveOutlookAttachments.ps1"
#$RenameFiles = Join-Path $PSScriptRoot "FileUtils\Rename-Files.ps1"
#$BackupFilesScript = Join-Path $PSScriptRoot "FileUtils\Backup-Files.ps1"

# Define the parameters for each report type
$reportParams = @(
    @{
        SrcPath = Join-Path $REPORTS_DIR "ITDReports"
        SubjectFilter = "CTSO 529899 ITD"
        SenderFilter = "oas_prod@gdit.com"
        PrependString = "CTSO_529889_ITD"
        UnreadOnly = 1
    },
    @{
        SrcPath = Join-Path $REPORTS_DIR "TimesheetReports"
        SubjectFilter = "CTSO Unanet Daily Timecard Report"
        SenderFilter = "oas_prod@gdit.com"
        PrependString = "CTSO_529889_WeeklyTimesheet"
        UnreadOnly = 1
    },
    @{
        SrcPath = Join-Path $REPORTS_DIR "OpenCommitReports"
        SubjectFilter = "CTSO Open Commits"
        SenderFilter = "oas_prod@gdit.com"
        PrependString = "CTSO_529899_OpenCommits"
        UnreadOnly = 1
    }
)

foreach ($params in $reportParams) {
    # Parameters for SaveOutlookAttachments
    $saveOutlookParams = @{
        TargetDir = $params.SrcPath
        SubjectFilter = $params.SubjectFilter
        SenderFilter = $params.SenderFilter
        PrependString = $params.PrependString
        UnreadOnly = $params.UnreadOnly
    }

    # Parameters for RenameFiles
    $renameFilesParams = @{
        SrcPath = $params.SrcPath
        DestPath = $params.SrcPath
        BaseName = $params.PrependString
        FileExtension = ".csv"
        FilenameSubstring = $params.PrependString
        Exec = $true
    }

    # Parameters for BackupFilesScript
    $backupFilesParams = @{
        SrcPath = $params.SrcPath
        DestPath = Join-Path $params.SrcPath "Archive"
        UseDateInFilename = $true
        KeepNVersions = 1
        Exec = $true
    }

    # Call SaveOutlookAttachments.ps1
    Write-Output "Executing SaveOutlookAttachments.ps1 with parameters: $saveOutlookParams"
    #SaveOutlookAttachments @saveOutlookParams
    Write-Output ""

    # Call RenameFiles.ps1
    Write-Output "Executing RenameFiles.ps1 with parameters: $renameFilesParams"
    Rename-And-MoveFiles @renameFilesParams
    Write-Output ""

    # Call BackupFilesScript.ps1
    Write-Output "Executing BackupFilesScript.ps1 with parameters: $backupFilesParams"
    Backup-Files @backupFilesParams
    Write-Output ""
}

Write-Host "Press any key to exit..."
[void][System.Console]::ReadKey($true)