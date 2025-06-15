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


Set-LogLevel $LogDebug

# Define environment variables for base directories
#$env:PS_HOME = "$(ENV:PowerShellHome)"
#$env:PS_SCRIPTS = "$env:PS_HOME\\Scripts"
#$env:PS_MODULES = "$env:PS_HOME\\Modules"
$REPORTS_DIR = "C:\Users\shawn.hillis\OneDrive - General Dynamics Mission Systems\Documents\CPM Plus\DOs-TOs\TO24 STE LTS\DPME\Reports"

$SaveOutlookAttachments = "$PSRoot\Scripts\OutlookUtils\SaveOutlookAttachments.ps1"
$RenameFiles = "$PSRoot\Scripts\FileUtils\Rename-Files.ps1"
$BackupFilesScript = "$PSRoot\Scripts\FileUtils\Backup-Files.ps1"

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