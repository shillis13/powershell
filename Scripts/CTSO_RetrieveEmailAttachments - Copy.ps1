
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

#endregion
# ===========================================================================================

#$REPORTS_DIR = "P:\Implementation\Engineering\Project Mgmt\SpendPlan\Data\Raw_Data"
$REPORTS_DIR = "C:\Users\shawn.hillis\OneDrive - General Dynamics Mission Systems\Documents\Excel\SpendPlan\Data\Raw_Data"

$SaveOutlookAttachments = Join-Path $PSScriptRoot "OutlookUtils\SaveOutlookAttachments.ps1"
$RenameFiles = Join-Path $PSScriptRoot "FileUtils\Rename-Files.ps1"
$BackupFilesScript = Join-Path $PSScriptRoot "FileUtils\Backup-Files.ps1"

# ******************************************************************
# * Retrieve ITD Reports
# ******************************************************************

# Parameters for SaveOutlookAttachments
$SrcPath = Join-Path $REPORTS_DIR "ITDReports"
$SubjectFilter = "CTSO 529899 ITD"
$SenderFilter = "oas_prod@gdit.com"
$PrependString = "CTSO_529889_ITD"
$UnreadOnly = 1

# Parameters for RenameFiles
$BaseName = "$PrependString"
$DestPath = $SrcPath
$FileExtension = ".csv"
$FilenameSubstring = "$PrependString"

# Print and Call SaveOutlookAttachments.ps1
#$saveOutlookCmd = "$env:PowerShellScripts\\OutlookUtils\\SaveOutlookAttachments.ps1 -TargetDir `"$SrcPath`" -SubjectFilter `"$SubjectFilter`" -SenderFilter `"$SenderFilter`" -PrependString `"$PrependString`" -UnreadOnly $UnreadOnly"
$saveOutlookCmd = "& `"$SaveOutlookAttachments`" -TargetDir `"$SrcPath`" -SubjectFilter `"$SubjectFilter`" -SenderFilter `"$SenderFilter`" -PrependString `"$PrependString`" -UnreadOnly $UnreadOnly"
Write-Output "Executing: $saveOutlookCmd"
Invoke-Expression "$saveOutlookCmd"
Write-Output ""

# Print and Call RenameFiles.ps1
#$renameFilesCmd = "$env:PowerShellScripts\\FileUtils\\RenameFiles.ps1 -SrcPath `"$SrcPath`" -DestPath `"$DestPath`" -BaseName `"$BaseName`" -FileExtension `"$FileExtension`" -FilenameSubstring `"$FilenameSubstring`""
$renameFilesCmd = "& `"$RenameFiles`" -SrcPath `"$SrcPath`" -DestPath `"$DestPath`" -BaseName `"$BaseName`" -FileExtension `"$FileExtension`" -FilenameSubstring `"$FilenameSubstring`" -Exec"
Write-Output "Executing: $renameFilesCmd"
Invoke-Expression $renameFilesCmd
Write-Output ""

# Print and Call BackupFilesScript.ps1 for ITD Reports
#$BackupFilesScriptCmd = "$env:PowerShellScripts\\FileUtils\\BackupFilesScript.ps1 -SrcPath `"$SrcPath`" -ArchivePath `"$DestPath\Archive`" -UseDateInFilename -KeepNVersions 1"
$BackupFilesScriptCmd = "& `"$BackupFilesScript`" -SrcPath `"$SrcPath`" -DestPath `"$DestPath\Archive`" -UseDateInFilename -KeepNVersions 1 -Exec"
Write-Output "Executing: $BackupFilesScriptCmd"
Invoke-Expression $BackupFilesScriptCmd
Write-Output ""


# ******************************************************************
# * Retrieve Unanet Daily Timecard Reports
# ******************************************************************

# Parameters for SaveOutlookAttachments
$SrcPath = Join-Path $REPORTS_DIR "TimesheetReports"
$SubjectFilter = "CTSO Unanet Daily Timecard Report"
$SenderFilter = "oas_prod@gdit.com"
$PrependString = "CTSO_529889_WeeklyTimesheet"
$UnreadOnly = 1

# Parameters for RenameFiles
$BaseName = "$PrependString"
$DestPath = $SrcPath
$FileExtension = ".csv"
$FilenameSubstring = "$PrependString"

# Print and Call SaveOutlookAttachments.ps1
#$saveOutlookCmd = "$env:PowerShellScripts\\OutlookUtils\\SaveOutlookAttachments.ps1 -TargetDir `"$SrcPath`" -SubjectFilter `"$SubjectFilter`" -SenderFilter `"$SenderFilter`" -PrependString `"$PrependString`" -UnreadOnly $UnreadOnly"
$saveOutlookCmd = "& `"$SaveOutlookAttachments`" -TargetDir `"$SrcPath`" -SubjectFilter `"$SubjectFilter`" -SenderFilter `"$SenderFilter`" -PrependString `"$PrependString`" -UnreadOnly $UnreadOnly"
Write-Output "Executing: $saveOutlookCmd"
Invoke-Expression "$saveOutlookCmd"
Write-Output ""

# Print and Call RenameFiles.ps1
#$renameFilesCmd = "$env:PowerShellScripts\\FileUtils\\RenameFiles.ps1 -SrcPath `"$SrcPath`" -DestPath `"$DestPath`" -BaseName `"$BaseName`" -FileExtension `"$FileExtension`" -FilenameSubstring `"$FilenameSubstring`""
$renameFilesCmd = "& `"$RenameFiles`" -SrcPath `"$SrcPath`" -DestPath `"$DestPath`" -BaseName `"$BaseName`" -FileExtension `"$FileExtension`" -FilenameSubstring `"$FilenameSubstring`" -Exec"
Write-Output "Executing: $renameFilesCmd"
Invoke-Expression $renameFilesCmd
Write-Output ""

# Print and Call BackupFilesScript.ps1 for ITD Reports
#$BackupFilesScriptCmd = "$env:PowerShellScripts\\FileUtils\\BackupFilesScript.ps1 -SrcPath `"$SrcPath`" -ArchivePath `"$DestPath\Archive`" -UseDateInFilename -KeepNVersions 1"
$BackupFilesScriptCmd = "& `"$BackupFilesScript`" -SrcPath `"$SrcPath`" -DestPath `"$DestPath\Archive`" -UseDateInFilename -KeepNVersions 1 -Exec"
Write-Output "Executing: $BackupFilesScriptCmd"
Invoke-Expression $BackupFilesScriptCmd
Write-Output ""


# ******************************************************************
# * Retrieve Open Commits Reports
# ******************************************************************

# Parameters for SaveOutlookAttachments
$SrcPath = Join-Path $REPORTS_DIR "OpenCommitReports"
$SubjectFilter = "CTSO Open Commits"
$SenderFilter = "oas_prod@gdit.com"
$PrependString = "CTSO_529899_OpenCommits"
$UnreadOnly = 1

# Parameters for RenameFiles
$BaseName = "$PrependString"
$DestPath = $SrcPath
$FileExtension = ".csv"
$FilenameSubstring = "$PrependString"

# Print and Call SaveOutlookAttachments.ps1
#$saveOutlookCmd = "$env:PowerShellScripts\\OutlookUtils\\SaveOutlookAttachments.ps1 -TargetDir `"$SrcPath`" -SubjectFilter `"$SubjectFilter`" -SenderFilter `"$SenderFilter`" -PrependString `"$PrependString`" -UnreadOnly $UnreadOnly"
$saveOutlookCmd = "& `"$SaveOutlookAttachments`" -TargetDir `"$SrcPath`" -SubjectFilter `"$SubjectFilter`" -SenderFilter `"$SenderFilter`" -PrependString `"$PrependString`" -UnreadOnly $UnreadOnly"
Write-Output "Executing: $saveOutlookCmd"
Invoke-Expression "$saveOutlookCmd"
Write-Output ""

# Print and Call RenameFiles.ps1
#$renameFilesCmd = "$env:PowerShellScripts\\FileUtils\\RenameFiles.ps1 -SrcPath `"$SrcPath`" -DestPath `"$DestPath`" -BaseName `"$BaseName`" -FileExtension `"$FileExtension`" -FilenameSubstring `"$FilenameSubstring`""
$renameFilesCmd = "& `"$RenameFiles`" -SrcPath `"$SrcPath`" -DestPath `"$DestPath`" -BaseName `"$BaseName`" -FileExtension `"$FileExtension`" -FilenameSubstring `"$FilenameSubstring`" -Exec"
Write-Output "Executing: $renameFilesCmd"
Invoke-Expression $renameFilesCmd
Write-Output ""

# Print and Call BackupFilesScript.ps1 for ITD Reports
#$BackupFilesScriptCmd = "$env:PowerShellScripts\\FileUtils\\BackupFilesScript.ps1 -SrcPath `"$SrcPath`" -ArchivePath `"$DestPath\Archive`" -UseDateInFilename -KeepNVersions 1"
$BackupFilesScriptCmd = "& `"$BackupFilesScript`" -SrcPath `"$SrcPath`" -DestPath `"$DestPath\Archive`" -UseDateInFilename -KeepNVersions 1 -Exec"
Write-Output "Executing: $BackupFilesScriptCmd"
Invoke-Expression $BackupFilesScriptCmd
Write-Output ""

Write-Host "Press any key to exit..."
[void][System.Console]::ReadKey($true)