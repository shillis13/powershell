# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

if (-not $Script:PSRoot) {
    $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..").Path
    Write-Host "Set Script:PSRoot = $Script:PSRoot"
}
if (-not $Script:PSRoot) {
    throw "Script:PSRoot must be set by the entry-point script before using internal components."
}

if (-not $Script:CliArgs) {
    $Script:CliArgs = $args
}

. "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"
. "$Script:PSRoot\Scripts\OutlookUtils\SaveOutlookAttachments.ps1"
. "$Script:PSRoot\Scripts\FileUtils\Rename-Files.ps1"
. "$Script:PSRoot\Scripts\FileUtils\Backup-Files.ps1"

#endregion
# ===========================================================================================

#$REPORTS_DIR = "P:\Implementation\Engineering\Project Mgmt\SpendPlan\Data\Raw_Data"
$REPORTS_DIR = "C:\Users\shawn.hillis\OneDrive - General Dynamics Mission Systems\Documents\CPM Plus\DOs-TOs\TO24 STE LTS\DPME\Reports"

#$SaveOutlookAttachments = Join-Path $PSScriptRoot "OutlookUtils\SaveOutlookAttachments.ps1"
#$RenameFiles = Join-Path $PSScriptRoot "FileUtils\Rename-Files.ps1"
#$BackupFilesScript = Join-Path $PSScriptRoot "FileUtils\Backup-Files.ps1"

# Define the parameters for each report type
$reportParams = @(
    @{
        SrcPath = Join-Path $REPORTS_DIR "ITD_Reports"
        SubjectFilter = "CPM+ TO24 ITD"
        SenderFilter = "oas_prod@gdit.com"
        PrependString = "TO24_532326_ITD"
        UnreadOnly = 1
    },
    @{
        SrcPath = Join-Path $REPORTS_DIR "Weekly_Timecard_Reports"
        SubjectFilter = "CPM+ TO24 Unanet Daily Timecard Report"
        SenderFilter = "oas_prod@gdit.com"
        PrependString = "TO24_532326_WeeklyTimesheet"
        UnreadOnly = 1
    },
    @{
        SrcPath = Join-Path $REPORTS_DIR "Open_Commit_Reports"
        SubjectFilter = "TO24 Open Commits"
        SenderFilter = "oas_prod@gdit.com"
        PrependString = "TO24_532326_OpenCommits"
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
    Write-Output "Executing SaveOutlookAttachments with parameters: $(Format-ToString -Obj $saveOutlookParams)"
    SaveOutlookAttachments @saveOutlookParams
    Write-Output ""

    # Call RenameFiles.ps1
    Write-Output "Executing Rename-Files.ps1 with parameters: $(Format-ToString -Obj $renameFilesParams)"
    Rename-And-MoveFiles @renameFilesParams
    Write-Output ""

    # Call BackupFilesScript.ps1
    Write-Output "Executing Backup-Files.ps1 with parameters: $(Format-ToString -Obj $backupFilesParams)"
    Backup-Files @backupFilesParams
    Write-Output ""
}

Write-Host "Press any key to exit..."
[void][System.Console]::ReadKey($true)
<#
# ******************************************************************
# * Retrieve ITD Reports
# ******************************************************************

# Parameters for SaveOutlookAttachments
$SrcPath = Join-Path $REPORTS_DIR "ITD_Reports"
$SubjectFilter = "CPM+ TO24 ITD"
$SenderFilter = "oas_prod@gdit.com"
$PrependString = "TO24_532326_ITD_"
$UnreadOnly = 1

# Parameters for RenameFiles
$BaseName = "$PrependString"
$DestPath = $SrcPath
$FileExtension = ".csv"
$FilenameSubstring = "$PrependString"

# Print and Call SaveOutlookAttachments.ps1
#$saveOutlookCmd = "$env:PowerShellScripts\\OutlookUtils\\SaveOutlookAttachments.ps1 -TargetDir `"$SrcPath`" -SubjectFilter `"$SubjectFilter`" -SenderFilter `"$SenderFilter`" -PrependString `"$PrependString`" -UnreadOnly $UnreadOnly"
$saveOutlookCmd = "& `"$SaveOutlookAttachments`" -TargetDir `"$SrcPath`" -SubjectFilter `"$SubjectFilter`" -SenderFilter `"$SenderFilter`" -PrependString `"$PrependString`" -UnreadOnly $UnreadOnly"
Log -Dbg "Executing: $saveOutlookCmd"
Invoke-Expression "$saveOutlookCmd"

# Print and Call RenameFiles.ps1
#$renameFilesCmd = "$env:PowerShellScripts\\FileUtils\\RenameFiles.ps1 -SrcPath `"$SrcPath`" -DestPath `"$DestPath`" -BaseName `"$BaseName`" -FileExtension `"$FileExtension`" -FilenameSubstring `"$FilenameSubstring`""
$renameFilesCmd = "& `"$RenameFiles`" -SrcPath `"$SrcPath`" -DestPath `"$DestPath`" -BaseName `"$BaseName`" -FileExtension `"$FileExtension`" -FilenameSubstring `"$FilenameSubstring`" -Exec"
Log -Dbg "`nExecuting: $renameFilesCmd"
Invoke-Expression $renameFilesCmd

# Print and Call BackupFilesScript.ps1 for ITD Reports
#$BackupFilesScriptCmd = "$env:PowerShellScripts\\FileUtils\\BackupFilesScript.ps1 -SrcPath `"$SrcPath`" -ArchivePath `"$DestPath\Archive`" -UseDateInFilename -KeepNVersions 1"
$BackupFilesScriptCmd = "& `"$BackupFilesScript`" -SrcPath `"$SrcPath`" -DestPath `"$DestPath\Archive`" -UseDateInFilename -KeepNVersions 1 -Exec"
Log -Dbg "`nExecuting: $BackupFilesScriptCmd"
Invoke-Expression $BackupFilesScriptCmd

# ******************************************************************
# * Retrieve Unanet Daily Timecard Reports
# ******************************************************************

# Parameters for SaveOutlookAttachments
$SrcPath = Join-Path $REPORTS_DIR "Weekly_Timecard_Reports"
$SubjectFilter = "CPM+ TO24 Unanet Daily Timecard Report"
$SenderFilter = "oas_prod@gdit.com"
$PrependString = "TO24_532326_WeeklyTimesheet_"
$UnreadOnly = 1

# Parameters for RenameFiles
$BaseName = "$PrependString"
$DestPath = $SrcPath
$FileExtension = ".csv"
$FilenameSubstring = "$PrependString"

# Print and Call SaveOutlookAttachments.ps1
#$saveOutlookCmd = "$env:PowerShellScripts\\OutlookUtils\\SaveOutlookAttachments.ps1 -TargetDir `"$SrcPath`" -SubjectFilter `"$SubjectFilter`" -SenderFilter `"$SenderFilter`" -PrependString `"$PrependString`" -UnreadOnly $UnreadOnly"
$saveOutlookCmd = "& `"$SaveOutlookAttachments`" -TargetDir `"$SrcPath`" -SubjectFilter `"$SubjectFilter`" -SenderFilter `"$SenderFilter`" -PrependString `"$PrependString`" -UnreadOnly $UnreadOnly"
Log -Dbg "`nExecuting: $saveOutlookCmd"
Invoke-Expression $saveOutlookCmd

# Print and Call RenameFiles.ps1
#$renameFilesCmd = "$env:PowerShellScripts\\FileUtils\\RenameFiles.ps1 -SrcPath `"$SrcPath`" -DestPath `"$DestPath`" -BaseName `"$BaseName`" -FileExtension `"$FileExtension`" -FilenameSubstring `"$FilenameSubstring`""
$renameFilesCmd = "& `"$RenameFiles`" -SrcPath `"$SrcPath`" -DestPath `"$DestPath`" -BaseName `"$BaseName`" -FileExtension `"$FileExtension`" -FilenameSubstring `"$FilenameSubstring`" -Exec"
Log -Dbg "`nExecuting: $renameFilesCmd"
Invoke-Expression $renameFilesCmd

# Print and Call BackupFilesScript.ps1 for ITD Reports
#$BackupFilesScriptCmd = "$env:PowerShellScripts\\FileUtils\\BackupFilesScript.ps1 -SrcPath `"$SrcPath`" -ArchivePath `"$DestPath\Archive`" -UseDateInFilename -KeepNVersions 1"
$BackupFilesScriptCmd = "& `"$BackupFilesScript`" -SrcPath `"$SrcPath`" -DestPath `"$DestPath\Archive`" -UseDateInFilename -KeepNVersions 1 -Exec"
Log -Dbg "`nExecuting: $BackupFilesScriptCmd"
Invoke-Expression $BackupFilesScriptCmd

# ******************************************************************
# * Retrieve Open Commits Reports
# ******************************************************************

# Parameters for SaveOutlookAttachments
$SrcPath = Join-Path $REPORTS_DIR "Open_Commit_Reports"
$SubjectFilter = "TO24 Open Commits"
$SenderFilter = "oas_prod@gdit.com"
$PrependString = "TO24_532326_OpenCommits"
$UnreadOnly = 1

# Parameters for RenameFiles
$BaseName = "$PrependString"
$DestPath = $SrcPath
$FileExtension = ".csv"
$FilenameSubstring = "$PrependString"

# Print and Call SaveOutlookAttachments.ps1
#$saveOutlookCmd = "$env:PowerShellScripts\\OutlookUtils\\SaveOutlookAttachments.ps1 -TargetDir `"$SrcPath`" -SubjectFilter `"$SubjectFilter`" -SenderFilter `"$SenderFilter`" -PrependString `"$PrependString`" -UnreadOnly $UnreadOnly"
$saveOutlookCmd = "& `"$SaveOutlookAttachments`" -TargetDir `"$SrcPath`" -SubjectFilter `"$SubjectFilter`" -SenderFilter `"$SenderFilter`" -PrependString `"$PrependString`" -UnreadOnly $UnreadOnly"
Log -Dbg "`nExecuting: $saveOutlookCmd"
Invoke-Expression $saveOutlookCmd

# Print and Call RenameFiles.ps1
#$renameFilesCmd = "$env:PowerShellScripts\\FileUtils\\RenameFiles.ps1 -SrcPath `"$SrcPath`" -DestPath `"$DestPath`" -BaseName `"$BaseName`" -FileExtension `"$FileExtension`" -FilenameSubstring `"$FilenameSubstring`""
$renameFilesCmd = "& `"$RenameFiles`" -SrcPath `"$SrcPath`" -DestPath `"$DestPath`" -BaseName `"$BaseName`" -FileExtension `"$FileExtension`" -FilenameSubstring `"$FilenameSubstring`" -Exec"
Log -Dbg "`nExecuting: $renameFilesCmd"
Invoke-Expression $renameFilesCmd

# Print and Call BackupFilesScript.ps1 for ITD Reports
#$BackupFilesScriptCmd = "$env:PowerShellScripts\\FileUtils\\BackupFilesScript.ps1 -SrcPath `"$SrcPath`" -ArchivePath `"$DestPath\Archive`" -UseDateInFilename -KeepNVersions 1"
$BackupFilesScriptCmd = "& `"$BackupFilesScript`" -SrcPath `"$SrcPath`" -DestPath `"$DestPath\Archive`" -UseDateInFilename -KeepNVersions 1 -Exec"
Log -Dbg "`nExecuting: $BackupFilesScriptCmd"
Invoke-Expression $BackupFilesScriptCmd


Write-Host "Press any key to exit..."
[void][System.Console]::ReadKey($true)

#>