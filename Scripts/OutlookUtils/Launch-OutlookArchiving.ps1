
# ===========================================================================================
#region       Ensure that Outlook is running and accessible
# ===========================================================================================
Get-Variable | Where-Object { $_.Value -is [__ComObject] } | ForEach-Object { "[$($_.Name)] = $($_.Value.GetType().FullName)" }
$comVars = Get-Variable | Where-Object { $_.Value -is [__ComObject] }

if ($comVars.Count -eq 0) {
    Write-Host "✅ No COM objects currently in session."
} else {
    Write-Host "⚠️ COM objects found in session:"
    $comVars | ForEach-Object {
        Write-Host "[$($_.Name)] = $($_.Value.GetType().FullName)"
    }
}
#endregion
# ===========================================================================================


# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================
if (-not $Global:PSRoot) {
    $Global:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    Write-Host "Set Global:PSRoot = $Global:PSRoot"
}
if (-not $Global:PSRoot) {
    throw "Global:PSRoot must be set by the entry-point script before using internal components."
}

if (-not $Global:CliArgs) {
    $Global:CliArgs = $args
}

. "$Global:PSRoot\Scripts\Initialize-CoreConfig.ps1"
. "$ENV:PowerShellScripts\OutlookUtils\Backup-OutlookByYear.ps1"

#endregion
# ===========================================================================================

# ===================================================================================
#region REQUIRED CONFIGURATION – EDIT THESE TWO ARRAYS TO MATCH YOUR OUTLOOK SETUP
# ===================================================================================

# DstGroups define the archive **DESTINATIONS** for each year.
# - DataFile: The name of the Outlook Data File (.pst) shown in your folder list.
# - FolderPath: The folder inside that data file where emails should go (e.g., "Saved" or "Archive/2022").
# - Year: The calendar year of emails that should go into this group.

$DstGroups = @(
    @{ DataFile = "Saved Mail 2021"; FolderPath = "Saved"; Year = 2021 },
    @{ DataFile = "Saved Mail 2022"; FolderPath = "Saved"; Year = 2022 },
    @{ DataFile = "Saved Mail 2023"; FolderPath = "Saved"; Year = 2023 },
    @{ DataFile = "Saved Mail 2024"; FolderPath = "Saved"; Year = 2024 }
)


# SrcGroups define the source **FOLDERS TO ARCHIVE FROM**
# - DataFile: The name of the Outlook Data File containing your inbox (e.g., "Outlook Data File").
# - FolderPath: The path to the folder you want to archive (e.g., "Inbox/Clients").
#   Use "/" to separate subfolders, matching what you see in Outlook.

$SrcGroups = @(
    @{ DataFile = "shawn.hillis@gd-ms.com"; FolderPath = "* Saved" }
    #@{ DataFile = "Online Archive - Shawn.Hillis@gd-ms.com"; FolderPath = "2022 - Inprogress" }
    #@{ DataFile = "Online Archive - Shawn.Hillis@gd-ms.com"; FolderPath = "2023 Partial" }
)

#endregion
# ===================================================================================


# ===================================================================================
#region ADVANCED OPTIONS – CHANGE ONLY IF YOU WANT TO MODIFY DEFAULT BEHAVIOR
# ===================================================================================

# Set to $true to simulate changes without moving or copying anything
$null = Set-DryRun $false

# Default action is Move (removes from source); change to Copy to preserve original emails
$Action = [ItemActionType]::Move

# Field used to determine email date. Usually "ReceivedTime" or "SentOn"
$DateSourceStr = "ReceivedTime"

#endregion
# ===================================================================================


# ===================================================================================
#region LOGGING SETTINGS – OPTIONAL
# ===================================================================================

$null = Set-LogLevel $LogInfo
$null = Set-LogFilePathName "$env:PowerShellHome\PowerShellLog.txt"

#endregion
# ===================================================================================



# ===================================================================================
# Execute archive per source group
# ===================================================================================
foreach ($src in $SrcGroups) {
    Log -Info ">>> Launching archive for: $($src.DataFile)\$($src.FolderPath)" 

    $null = Backup-OutlookByYear `
        -SrcDataFileName $src.DataFile `
        -SrcFolderPath $src.FolderPath `
        -DateSourceStr $DateSourceStr `
        -Action $Action `
        -MaxItemsToProcess 0 `
        -DstGroups $DstGroups
}

Log -Info "`nAll archiving runs complete."
