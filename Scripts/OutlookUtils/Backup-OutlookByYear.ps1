# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

if (-not $Script:PSRoot) {
    $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    Log -Dbg "Set Script:PSRoot = $Script:PSRoot"
}
if (-not $Script:PSRoot) {
    throw "Script:PSRoot must be set by the entry-point script before using internal components."
}

if (-not $Script:CliArgs) {
    $Script:CliArgs = $args
}

. "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"

#endregion
# ===========================================================================================


. "$Script:PSRoot\Scripts\DateTimeUtils\DateTime-Utils.ps1"
. "$Script:PSRoot\Scripts\OutlookUtils\Outlook.Interface.ps1"
. "$Script:PSRoot\Scripts\OutlookUtils\OutlookLogic.ps1"

#======================================================================================
#region PowerShell Block Guard
if (-not (Get-Variable -Name Included_Backup-OutlookByYear_Block -Scope Global -ErrorAction SilentlyContinue)) {
    Set-Variable -Name Included_Backup-OutlookByYear_Block -Scope Global -Value $true

    $script:NumItemsProcessed = 0
    $script:NumItemsMovedOrCopied = 0
    $script:NumItemsNotCopiedOrMoved = 0
    $script:NumItemsMovedOrCopiedByYear = @{}
    $script:YearCountsNotMoved = @{}
    $script:folderCreateCount = 0

} # end if block guard
#endregion
#======================================================================================


#======================================================================================
#region     Function: Backup-OutlookByYear
<#
.SYNOPSIS
    Backs up Outlook items by year.
    This function backs up Outlook items from a specified source folder to destination folders grouped by year.

    This function is typically called by `Launch-OutlookArchiving.ps1`, which supplies:
      - SrcGroups: one or more source folders to pull messages from
      - DstGroups: a list of destination folders, each associated with a calendar year

    Example:
      SrcGroups = @( @{ DataFile = "Outlook Data File"; FolderPath = "Inbox/Projects" } )
      DstGroups = @( @{ DataFile = "Saved Mail 2023"; FolderPath = "Saved"; Year = 2023 } )

    Items are matched based on the configured DateSource field (e.g., 'ReceivedTime'),
    and routed to the appropriate year's folder if the timestamp matches.
.PARAMETER SrcDataFileName
    The name of the source data file.

.PARAMETER SrcFolderPath
    The path of the source folder.

.PARAMETER DateSourceStr
    The date source string to filter items.

.PARAMETER Action
    The action to perform on items (Move or Copy).

.PARAMETER MaxItemsToProcess
    The maximum number of items to process.

.PARAMETER DstGroups
    The destination groups to move or copy items to.

.EXAMPLE
    Backup-OutlookByYear -SrcDataFileName "OutlookDataFile" -SrcFolderPath "Inbox" -DateSourceStr "ReceivedTime" -Action Move -MaxItemsToProcess 100 -DstGroups $groups

.NOTES
    Ensure the required modules are imported before calling this function.
#>
function Backup-OutlookByYear {
    param (
        [string]$SrcDataFileName,
        [string]$SrcFolderPath,
        [string]$DateSourceStr,
        [ItemActionType]$Action,
        [int]$MaxItemsToProcess,
        [array]$DstGroups
    )

    $srcRoot = Get-OutlookFolder -FolderPath $SrcDataFileName
    $srcFolder = Get-OutlookFolder -FolderPath $SrcFolderPath -ParentFolder $srcRoot 

    #$dateSource = ConvertTo-OutlookDateSourceType $DateSourceStr

    if ($srcFolder) {
        $resolvedDstGroups = Resolve-DestinationFolders -Groups $DstGroups
        if ($resolvedDstGroups -and $resolvedDstGroups.Count -gt 1 ) {
            Invoke-ProcessFolder -SrcFolder $srcFolder -DstGroups $resolvedDstGroups -DateSource $DateSourceStr -Action $Action -MaxItemsToProcess $MaxItemsToProcess
        }
        else {
            Log -Err "No valid destination groups found:`n(Format-ToString($DstGroups))"
        }
    }
    else {
        Log -Err "Source folder path '$SrcFolderPath' not found under '$SrcDataFileName'."
    }
}
#endregion
#======================================================================================


#======================================================================================
#region     Function: Resolve-DestinationFolders
<#
.SYNOPSIS
    Resolves destination folders for Outlook items.

.DESCRIPTION
    This function resolves the destination folders for Outlook items based on the provided groups.

.PARAMETER Groups
    The groups containing the destination folder information.

.EXAMPLE
    Resolve-DestinationFolders -Groups $groups

.NOTES
    Ensure the required modules are imported before calling this function.
#>
function Resolve-DestinationFolders {
    param ([array]$Groups)

    $resolvedGroups = [System.Collections.Generic.List[object]]::new()

    foreach ($group in $Groups) {
        $year = $group.Year
        $baseFolder = Get-OutlookFolder -FolderPath $group.DataFile
        if (-not $baseFolder) {
            Log -Err "DataFile '$($group.DataFile)' not found."
            continue
        }

        $variants = @(
            $group.FolderPath,
            "$($group.FolderPath) $year",
            "$($group.FolderPath)-$year",
            "$($group.FolderPath)\$year",
            "$year\$($group.FolderPath)"
        )

        $group.Folder = $null
        foreach ($tryPath in $variants) {
            $candidate = Get-OutlookFolder -FolderPath $tryPath -ParentFolder $baseFolder
            if ($candidate) {
                $group.Folder = $candidate
                $group.FolderPath = $tryPath
                break
            }
        }

        if (-not $group.Folder) {
            Log -Err "Could not resolve folder path for year $year : $($group.FolderPath)"
        }
        else {
            $group.StartDate = [datetime]::new($year, 1, 1)
            $group.EndDate = $group.StartDate.AddYears(1)

            $resolvedGroups.Add($group)
        }
    }

    return $resolvedGroups
}
#endregion
#======================================================================================


#======================================================================================
#region     Function: Resolve-SubfolderGroups
<#
.SYNOPSIS
    Resolves subfolder groups for Outlook items.

.DESCRIPTION
    This function resolves subfolder groups for Outlook items based on the provided parent groups.

.PARAMETER SrcSubfolder
    The source subfolder.

.PARAMETER ParentGroups
    The parent groups containing the folder information.

.EXAMPLE
    Resolve-SubfolderGroups -SrcSubfolder $subfolder -ParentGroups $parentGroups

.NOTES
    Ensure the required modules are imported before calling this function.
#>
function Resolve-SubfolderGroups {
    param (
        [object]$SrcSubfolder,
        [array]$ParentGroups
    )

    $results = @()

    foreach ($group in $ParentGroups) {
        if (-not $group.Folder) { continue }

        $newFolderName = New-ItemNameWithDate -baseName $SrcSubfolder.Name -theDateTime $group.StartDate
        $result = New-OutlookSubfolder -ParentFolder $group.Folder -SubfolderName $newFolderName

        if ($result -and $result.Folder) {
            if ($result.wasCreated) { $script:folderCreateCount++ }
            $results += @{
                Year        = $group.Year
                DataFile    = $group.DataFile
                StartDate   = $group.StartDate
                EndDate     = $group.EndDate
                Folder      = $result.Folder
                FolderPath  = $result.FolderPath
            }
        }
    }

    return $results
}
#endregion
#======================================================================================


#======================================================================================
#region     Function: Invoke-ProcessFolder
<#
.SYNOPSIS
    Processes an Outlook folder and moves or copies items to destination folders.

.DESCRIPTION
    This function processes an Outlook folder and moves or copies items to destination folders based on the provided date source and action.

.PARAMETER SrcFolder
    The source folder to process.

.PARAMETER DstGroups
    The destination groups to move or copy items to.

.PARAMETER DateSource
    The date source string to filter items.

.PARAMETER Action
    The action to perform on items (Move or Copy).

.PARAMETER MaxItemsToProcess
    The maximum number of items to process.

.EXAMPLE
    Invoke-ProcessFolder -SrcFolder $srcFolder -DstGroups $dstGroups -DateSource "ReceivedTime" -Action Move -MaxItemsToProcess 100

.NOTES
    Ensure the required modules are imported before calling this function.
#>
function Invoke-ProcessFolder {
    param (
        [object]$SrcFolder,
        [array]$DstGroups,
        [string]$DateSource,
        [ItemActionType]$Action,
        [int]$MaxItemsToProcess
    )
    Log -Dbg " SrcFolder = $($SrcFolder.Name) : DstGroups = (Format-ToString  -Obj $DstGroups) : DateSource = $DateSource : Action = $Action"
    foreach ($dstGroup in $DstGroups) {
        if (-not $dstGroup.Folder) { continue }

        $start = $dstGroup.StartDate
        $end = $dstGroup.EndDate
        $filter = "[${DateSource}] >= '$($start.ToString("MM/dd/yyyy"))' AND [${DateSource}] < '$($end.ToString("MM/dd/yyyy"))'"
        $items = Get-OutlookItems -Folder $SrcFolder -Filter $filter -Recurse:$false #-SortField $DateSource

        if ($items.Count -gt 0) {
            Log -Info "Processing $($items.Count) items to $Action from $($SrcFolder.Name) to $($dstGroup.Folder.Name) for year $($dstGroup.Year)"
            Log -Dbg "BatchProcessing $($items.Count) items to $Action to $($dstGroup.Folder.Name) folder."
            Backup-BatchedItems -Items $items -DestFolder $dstGroup.Folder -Action $Action -MaxItemsToProcess $MaxItemsToProcess
        }
    }

    $subfolders = Get-OutlookFolders -BaseFolder $SrcFolder
    if ($subfolders) {
        $folderNames = $subfolders | Where-Object { $null -ne $_ } | ForEach-Object { $_.Name }
        Log -Dbg ("$($subfolders.Count) subfolders found in $($SrcFolder.Name) :" +  ($folderNames -join ", "))
        foreach ($subfolder in $subfolders) {
            $childGroups = Resolve-SubfolderGroups -SrcSubfolder $subfolder -ParentGroups $DstGroups
            if ($childGroups.Count -gt 0) {
                Invoke-ProcessFolder -SrcFolder $subfolder -DstGroups $childGroups -DateSource $DateSource -Action $Action -MaxItemsToProcess $MaxItemsToProcess
            }
        }
    }
    else {
        Log -Dbg "No subfolders returned for $($SrcFolder.Name)"
    }
    Log -Dbg "Completed processing for folder $($SrcFolder.Name)"
}
#endregion
#======================================================================================


#======================================================================================
#region     Function: Backup-BatchedItems
<#
.SYNOPSIS
    Backs up batched Outlook items to a destination folder.

.DESCRIPTION
    This function backs up batched Outlook items to a destination folder by moving or copying them.

.PARAMETER Items
    The items to back up.

.PARAMETER DestFolder
    The destination folder to move or copy items to.

.PARAMETER Action
    The action to perform on items (Move or Copy).

.PARAMETER MaxItemsToProcess
    The maximum number of items to process.

.EXAMPLE
    Backup-BatchedItems -Items $items -DestFolder $destFolder -Action Move -MaxItemsToProcess 100

.NOTES
    Ensure the required modules are imported before calling this function.
#>
function Backup-BatchedItems {
    param (
        [object]$Items,
        [object]$DestFolder,
        [ItemActionType]$Action,
        [int]$MaxItemsToProcess
    )

    Log -Dbg "-Items.Count = $($Items.Count) -DestFolder = $($DestFolder.Name) -Action = $Action -MaxItemsToProcess = $MaxItemsToProcess"

    for ($i = $Items.Count-1; $i -ge 0; $i--) {
        Log -Info -Dot
        $script:NumItemsProcessed++
#        $item = Get-OutlookItem -Items $Items -Index $i
        $item = $Items[$i]

        $itemType = Get-OutlookItemType $item
        if ($itemType -and $itemType -ne [OutlookItemType]::Unknown) {
            Log -Dbg "$Action OutlookItem -Item = $($item.Subject) -TargetFolder = $($DestFolder.Name) ItemType = $itemType"

            try {
                if ($Action -eq [ItemActionType]::Move) { 
                    Move-OutlookItem -Item $item -TargetFolder $DestFolder
                }
                elseif ($Action -eq [ItemActionType]::Copy) {
                    Copy-OutlookItem -Item $item -TargetFolder $DestFolder
                }
                else { Log -Err "Action type $Action is not applicable here"  }
            }
            catch {
                $msg = "Exception caught attempting to move item of type $itemType to folder $($DestFolder.Name)."
                Log -Err "Caught exception but continuing: $msg"
            }

            $script:NumItemsMovedOrCopied++
        } else {
            Log -Warn "NOT able to perform $Action on OutlookItem -Item = $(Get-OutlookItemName -Item $item) -TargetFolder = $($DestFolder.Name) ItemType = $itemType"
            $script:NumItemsNotCopiedOrMoved++
        }

        if ($MaxItemsToProcess -gt 0 -and $script:NumItemsProcessed -ge $MaxItemsToProcess) {
            Log -Dbg "Reached MaxItemsToProcess = $MaxItemsToProcess"
            return
        }

        if ($item) {
            try {
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($item) | Out-Null
                Remove-Variable item -ErrorAction SilentlyContinue
            }
            catch {
                Log -Warn "Failed to release COM object: $_ "
            }
        }
    }

    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
#endregion
#======================================================================================


#endregion
