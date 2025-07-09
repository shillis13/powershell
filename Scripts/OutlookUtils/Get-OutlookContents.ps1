# ********************************************************************
# Script: Get-OutlookContents.ps1
# Description:
#   Retrieves a list of subfolders or items from a specified nested folder path
#   within an Outlook data file. Utilizes shared Outlook.Interface functions.
#
# Parameters:
#   -DataFile (string): Name of the Outlook Data File (e.g., 'Archive' or 'Personal Folders')
#   -FolderPath (string): Backslash-delimited folder path (e.g., 'Inbox\Subfolder1\Subfolder2')
#   -Folders (switch): If specified, lists subfolders
#   -Items (switch): If specified, lists items in the final folder
#   -Recursive (switch): If specified, lists subfolders and items recursively
#   -Count (switch): If specified, only counts the folders and/or items as specified
#
# Examples:
#   .\Get-OutlookContents.ps1 -DataFile "Archive" -FolderPath "Inbox\Subfolder1" -Items
#   .\Get-OutlookContents.ps1 -DataFile "Personal Folders" -FolderPath "Projects\2023" -Folders
#   .\Get-OutlookContents.ps1 -DataFile "Archive" -FolderPath "Inbox" -Folders -Recursive
#   .\Get-OutlookContents.ps1 -DataFile "Archive" -FolderPath "Inbox" -Items -Count
# ********************************************************************

param (
    [Parameter(Mandatory = $true)]
    [string]$DataFile,

    [Parameter(Mandatory = $true)]
    [string]$FolderPath,

    [switch]$Folders,
    [switch]$Items,
    [switch]$Recursive,
    [switch]$Count
)

# Import Outlook.Interface functions (adjust path as needed)
. "$ENV:PowerShellScripts\DevUtils\Logging.ps1"
. "$ENV:PowerShellScripts\OutlookUtils\Outlook.Interface.ps1"

# Validate options
if (-not $Folders -and -not $Items) {
    Log -Err "You must specify at least one of -Folders or -Items."
    exit 1
}

# Get the root folder of the data file
$topFolder = Get-OutlookNamespace -DataFileName $DataFile
if (-not $topFolder) {
    Log -Err  "Could not locate top folder for data file: $DataFile"
    exit 1
}

# Split the folder path into an array
$FolderParts = $FolderPath -split '\\'

# Traverse the folder path
$currentFolder = $topFolder
foreach ($folderName in $FolderParts) {
    $nextFolder = $currentFolder.Folders | Where-Object { $_.Name -eq $folderName }
    if (-not $nextFolder) {
        Log -Err  "Folder '$folderName' not found under '$($currentFolder.Name)'"
        exit 1
    }
    $currentFolder = $nextFolder
}

# Function to list contents recursively
function Get-ContentsRecursively {
    param (
        [object]$Folder,
        [switch]$Folders,
        [switch]$Items,
        [switch]$Count
    )

    if ($Count) {
        $folderCount = 0
        $itemCount = 0

        if ($Folders) {
            $folderCount = $Folder.Folders.Count
            Write-Output "Subfolders under '$($Folder.Name)': $folderCount"
        }

        if ($Items) {
            $items = Get-OutlookItems -Folder $Folder
            $itemCount = $items.Count
            Write-Output "Items in '$($Folder.Name)': $itemCount"
        }

        foreach ($subFolder in $Folder.Folders) {
            Get-ContentsRecursively -Folder $subFolder -Folders:$Folders -Items:$Items -Count:$Count
        }
    } else {
        if ($Folders) {
            Log -MsgOnly -Always "Subfolders under '$($Folder.Name)':"
            $Folder.Folders | ForEach-Object { $_.Name }
        }

        if ($Items) {
            Log -MsgOnly -Always  "Items in '$($Folder.Name)':"
            $items = Get-OutlookItems -Folder $Folder
            foreach ($item in $items) {
                $name = Get-OutlookItemName -Item $item
                Write-Output " - $name"
            }
        }

        foreach ($subFolder in $Folder.Folders) {
            Get-ContentsRecursively -Folder $subFolder -Folders:$Folders -Items:$Items
        }
    }
}

# Output content
if ($Recursive) {
    Get-ContentsRecursively -Folder $currentFolder -Folders:$Folders -Items:$Items -Count:$Count
} else {
    if ($Count) {
        if ($Folders) {
            $folderCount = $currentFolder.Folders.Count
            Write-Output "Subfolders under '$($currentFolder.Name)': $folderCount"
        }

        if ($Items) {
            $items = Get-OutlookItems -Folder $currentFolder
            $itemCount = $items.Count
            Write-Output "Items in '$($currentFolder.Name)': $itemCount"
        }
    } else {
        if ($Folders) {
            Log -MsgOnly -Always "Subfolders under '$($currentFolder.Name)':"
            $currentFolder.Folders | ForEach-Object { $_.Name }
        }

        if ($Items) {
            Log -MsgOnly -Always  "Items in '$($currentFolder.Name)':"
            $items = Get-OutlookItems -Folder $currentFolder
            foreach ($item in $items) {
                $name = Get-OutlookItemName -Item $item
                Write-Output " - $name"
            }
        }
    }
}