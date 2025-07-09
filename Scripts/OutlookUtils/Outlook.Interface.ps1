#==================================================================================
#region ** Enums and Variables **
#==================================================================================

# Define Enum for Outlook Date Source Types
enum OutlookDateSourceType {
    ReceivedTime
    SentOn
    CreationTime
    LastModificationTime
    Start
    End
    DueDate
    DateCompleted
}

# Define the OutlookItemType enum
enum OutlookItemType {
    Unknown
    All
    Mail
    Appointment
    Meeting
    Task
    Contact
    Note
    Journal
    Post
    Sharing
    Receipt
    Voicemail
}
#endregion
#==================================================================================


# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

if (-not $Script:PSRoot) {
    $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    Write-Host "Set Script:PSRoot = $Script:PSRoot"
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


#___________________________________________________________________________________
#region 	*** PowerShell Block Guard to prevent a section of code from being read multiple times 
if (-not (Get-Variable -Name Included_Outlook.Interface_Block -Scope Global -ErrorAction SilentlyContinue)) { 
    Set-Variable -Name Included_Outlook.Interface_Block -Scope Global -Value $true

    $script:OutlookNamespace = $null  # also called Namespace

} # Move this and endregion to end-point of code to guard
#endregion	end of guard


#endregion
#==================================================================================

#==================================================================================
#region ** Functions / Methods **
#==================================================================================


#======================================================================================
#region     Function: Get-OutlookNamespace
<#
.SYNOPSIS
    Returns the Outlook MAPI namespace used to access all data files and folders.

.DESCRIPTION
    This is the entry point to all Outlook stores and folders. Internally uses
    Outlook.Application COM object and calls GetNamespace("MAPI").

.RETURNS
    The Outlook namespace object.

.EXAMPLE
    $namespace = Get-OutlookNamespace

.NOTES
    Ensure the required modules are imported before calling this function.
#>
#======================================================================================
function Get-OutlookNamespace {
    if ($null -eq $script:OutlookNamespace) {
        $outlook = New-Object -ComObject Outlook.Application
        $script:Namespace = $outlook.GetNamespace("MAPI")
    }

    return $script:Namespace
}
#endregion
#======================================================================================


#======================================================================================
#region     Function: ConvertTo-OutlookDateSourceType
<#
.SYNOPSIS
    Converts a string representation of an OutlookDateSourceType enum value to its corresponding enum type.

.DESCRIPTION
    This function converts a string representation of an OutlookDateSourceType enum value to its corresponding enum type, ignoring case.

.PARAMETER DateSourceString
    The string representation of the enum value.

.RETURNS
    The corresponding OutlookDateSourceType enum value.

.EXAMPLE
    ConvertTo-OutlookDateSourceType -DateSourceString "ReceivedTime"

.NOTES
    Ensure the required modules are imported before calling this function.
#>
#======================================================================================
function ConvertTo-OutlookDateSourceType {
    param (
        [string]$DateSourceString
    )

    try {
        return [OutlookDateSourceType]::Parse([OutlookDateSourceType], $DateSourceString, $true)
    } catch {
        throw "Invalid OutlookDateSourceType: $DateSourceString"
    }
}
#endregion
#======================================================================================



#======================================================================================
#region     Function: ConvertTo-OutlookItemEnumType
<#
.SYNOPSIS
    Converts a string representation of an OutlookItemType enum value to its corresponding enum type.

.DESCRIPTION
    This function converts a string representation of an OutlookItemType enum value to its corresponding enum type, ignoring case.

.PARAMETER enumString
    The string representation of the enum value.

.RETURNS
    The corresponding OutlookItemType enum value.

.EXAMPLE
    ConvertTo-OutlookItemEnumType -enumString "Mail"

.NOTES
    Ensure the required modules are imported before calling this function.
#>
#======================================================================================
function ConvertTo-OutlookItemEnumType {
    param (
        [string]$enumString
    )

    try {
        return [OutlookItemType]::Parse([OutlookItemType], $enumString, $true)
    } catch {
        throw "Invalid OutlookItemType: $enumString"
    }
}
#endregion
#======================================================================================



#======================================================================================
#region     Function: Get-OutlookItemType
<#
.SYNOPSIS
    Maps an Outlook item's MessageClass to a logical OutlookItemType enum.

.DESCRIPTION
    This function maps an Outlook item's MessageClass to a logical OutlookItemType enum.

.PARAMETER Item
    The Outlook item to classify.

.RETURNS
    The logical type of the Outlook item as an OutlookItemType enum value.

.EXAMPLE
    $itemType = Get-OutlookItemType -Item $mailItem

.NOTES
    Ensure the required modules are imported before calling this function.
#>
#======================================================================================
function Get-OutlookItemType {
    param (
        [object]$Item
    )

    $itemType = [OutlookItemType]::Unknown

    if ($Item -and $Item.MessageClass) {
        try {
            $mc = $Item.MessageClass

            $matchers = @(
                @{ Pattern = "^IPM\.Note(\.|$)";                 Type = "Mail" }
                @{ Pattern = "^IPM\.Note\.SMIME";                Type = "Mail" }
                @{ Pattern = "^IPM\.Schedule\.Meeting\.(Request|Resp|Canceled|Notification\.Forward)"; Type = "Meeting" }
                @{ Pattern = "^IPM\.Appointment";                Type = "Appointment" }
                @{ Pattern = "^IPM\.Contact";                    Type = "Contact" }
                @{ Pattern = "^IPM\.DistList";                   Type = "Contact" }
                @{ Pattern = "^IPM\.Task(Request|\.Accept|\.Decline|\.Update)?"; Type = "Task" }
                @{ Pattern = "^IPM\.StickyNote";                 Type = "Note" }
                @{ Pattern = "^IPM\.Activity";                   Type = "Journal" }
                @{ Pattern = "^IPM\.Post";                       Type = "Post" }
                @{ Pattern = "^IPM\.Sharing";                    Type = "Sharing" }
                @{ Pattern = "^REPORT\.|^Receipt\.|^IPM\.Recall\.Report\.|^IPM\.Outlook\.Recall"; Type = "Receipt" }
                @{ Pattern = "^IPM\.Note\.Microsoft\.Voicemail"; Type = "Voicemail" }
                @{ Pattern = "Acrobat\.Document";                Type = "Document" }
            )

            foreach ($rule in $matchers) {
                if ($mc -match $rule.Pattern) {
                    $itemType = [OutlookItemType]::$($rule.Type)
                    Log -Always "Resolved $mc to $ItemType."
                    break
                }
            }

            if ($itemType -eq [OutlookItemType]::Unknown) {
                $subject = if ($Item.PSObject.Properties["Subject"]) { $Item.Subject } else { "N/A" }
                $entryID = if ($Item.PSObject.Properties["EntryID"]) { $Item.EntryID } else { "N/A" }
                Log -Warn "Get-OutlookItemType(): Unrecognized item MessageClass: $mc. Subject: $subject, EntryID: $entryID."
            }
        }
        catch {
            Log -Err "Get-OutlookItemType(): Exception occurred. Error: $_"
        }
    }

    return $itemType
}

function Get-OutlookItemType2 {
    param (
        [object]$Item
    )

    $itemType = [OutlookItemType]::Unknown

    if ($Item -and $Item.MessageClass) {
        try {
            switch -Regex ($Item.MessageClass) {
                "^IPM\.Note(\.|$)"                            { $itemType = [OutlookItemType]::Mail }
                "^IPM\.Note\.SMIME"                           { $itemType = [OutlookItemType]::Mail }
                "^IPM\.Schedule\.Meeting\.(Request|Resp|Canceled|Notification\.Forward)" { $itemType = [OutlookItemType]::Meeting }
                "^IPM\.Appointment"                           { $itemType = [OutlookItemType]::Appointment }
                "^IPM\.Contact"                               { $itemType = [OutlookItemType]::Contact }
                "^IPM\.DistList"                              { $itemType = [OutlookItemType]::Contact }
                "^IPM\.Task(Request|\.Accept|\.Decline|\.Update)?" { $itemType = [OutlookItemType]::Task }
                "^IPM\.StickyNote"                            { $itemType = [OutlookItemType]::Note }
                "^IPM\.Activity"                              { $itemType = [OutlookItemType]::Journal }
                "^IPM\.Post"                                  { $itemType = [OutlookItemType]::Post }
                "^IPM\.Sharing"                               { $itemType = [OutlookItemType]::Sharing }
                "^REPORT\."                                   { $itemType = [OutlookItemType]::Receipt }
                "^Receipt\."                                  { $itemType = [OutlookItemType]::Receipt }
                "^IPM\.Recall\.Report\."                      { $itemType = [OutlookItemType]::Receipt }
                "^IPM\.Outlook\.Recall"                       { $itemType = [OutlookItemType]::Receipt }
                "^IPM\.Note\.Microsoft\.Voicemail"            { $itemType = [OutlookItemType]::Voicemail }
                "^Acrobat\.Document\.Dc"                      { $itemType = [OutlookItemType]::Document }
                "^AcrobatDocument\.Dc"                        { $itemType = [OutlookItemType]::Document }
                "^AcrobatDocument\.Dc"                        { $itemType = [OutlookItemType]::Document }
                default {
                    $subject = if ($Item.PSObject.Properties["Subject"]) { $Item.Subject } else { "N/A" }
                    $entryID = if ($Item.PSObject.Properties["EntryID"]) { $Item.EntryID } else { "N/A" }
                    Log -Warn "Get-OutlookItemType(): Unrecognized item MessageClass: $($Item.MessageClass). Subject: $subject, EntryID: $entryID."
                }
            }
        } catch {
            Log -Err "Get-OutlookItemType(): Exception occurred. Error: $_"
        }
    }

    return $itemType
}
#endregion
#==================================================================================


#==================================================================================
#region     Function: Get-OutlookFolder
<#
.SYNOPSIS
    Retrieves a specific Outlook folder by navigating a folder path from a starting point.

.DESCRIPTION
    Starts at a parent folder or the Outlook namespace and walks down the folder tree using a path
    string like 'Saved\Clients\Important'. Path separators can be "\", "\\" or "/".
    Supports optional strict mode to throw if the path can't be fully resolved.

.PARAMETER FolderPath
    The folder path to locate. Mandatory. Can include single or nested folder names.

.PARAMETER ParentFolder
    Optional. If provided, path navigation begins here instead of the namespace.

.PARAMETER Namespace
    Optional. The Outlook namespace to use. Defaults to Get-OutlookNamespace.

.PARAMETER Strict
    Optional. If set, the function throws on failure. Otherwise, returns $null and logs a warning.

.RETURNS
    The target Outlook folder object, or $null if not found and -Strict is not used.

#>
#======================================================================================
function Get-OutlookFolder {
    param (
        [Parameter(Mandatory = $true)][string]$FolderPath,
        [object]$ParentFolder = $null,
        [switch]$Strict
    )

    $folder = $null

    $folderList = if ($ParentFolder) { $ParentFolder.Folders } else { (Get-OutlookNamespace).Folders }

    if (-not $folderList -or $folderList.Count -eq 0) {
        $msg = "Starting folder list is empty."
        if ($Strict) {
            Log -Err $msg
            throw $msg
        } else {
            Log -Warn $msg
        }
    }
    else {
        $FolderPath = $FolderPath.Trim()
        $pathParts = ($FolderPath -replace '[\\/]+', '\') -split '\\'

        foreach ($pathPart in $pathParts) {
            $pathPart = $pathPart.Trim()
            $folder = $folderList | Where-Object { $_.Name -eq $pathPart }

            if (-not $folder) {
                $folderListStr = Format-ToString $folderList
                $msg = "Cannot find part '$pathPart' from path '$FolderPath' in list of folders: $folderListStr."
                if ($Strict) {
                    Log -Err $msg
                    throw $msg
                }
                else {
                    Log -Warn $msg
                }
                $folder = $null
                break
            }
            else { $folderList = $folder.Folders }
        }
    }

    return $folder
}
#endregion
#==================================================================================


#==================================================================================
#region      Function: Get-OutlookFolders
<#
.SYNOPSIS
    Retrieves all child folders from a starting Outlook folder, optionally recursively.

.DESCRIPTION
    Begins from a specified base folder, resolved path, namespace, or default namespace if none given.
    Returns all direct child folders, and optionally recurses into each child.

.PARAMETER BaseFolder
    Optional. The starting Outlook folder object.

.PARAMETER FolderPath
    Optional. A path used to locate the starting folder (relative to BaseFolder or Namespace).

.PARAMETER Namespace
    Optional. Outlook namespace. Defaults to Get-OutlookNamespace if not provided.

.PARAMETER Recurse
    Optional. If set, walks folders recursively and returns all descendants.

.RETURNS
    A flat list of Outlook folders found under the resolved starting point.

#>
#======================================================================================
function Get-OutlookFolders {
    param (
        [object]$BaseFolder = $null,
        [string]$FolderPath = "",
        [object]$DataFile = $null,
        [switch]$Recurse
    )

    $startingFolder = if ($FolderPath) {
        Get-OutlookFolder -FolderPath $FolderPath -ParentFolder $BaseFolder #-DataFile $DataFile
    } elseif ($BaseFolder) {
        $BaseFolder
    } elseif ($DataFile) {
        $DataFile
    } else {
        Get-OutlookNamespace
    }

    $folders = @()
    foreach ($f in $startingFolder.Folders) {
        $folders += $f
        if ($Recurse) {
            $folders += Get-OutlookFolders -BaseFolder $f -Recurse
        }
    }

    return $folders
}
#endregion
#======================================================================================



#======================================================================================
#region     Function: Get-OutlookItems
<#
.SYNOPSIS
    Retrieves items from a specified Outlook folder filtered by logical ItemType.

.DESCRIPTION
    Retrieves items from a specified Outlook folder filtered by logical ItemType. Supports optional recursion.

.PARAMETER Folder
    The Outlook folder from which to retrieve items.

.PARAMETER Filter
    Optional. A filter string to apply to the items.

.PARAMETER ItemTypes
    Optional. An array of logical item types to include. Defaults to All.

.PARAMETER Recurse
    Optional. If set, retrieves items from subfolders recursively.

.RETURNS
    A collection of filtered Outlook items.

.EXAMPLE
    $items = Get-OutlookItems -Folder $inboxFolder -ItemTypes @([OutlookItemType]::Mail)

.NOTES
    Ensure the required modules are imported before calling this function.
#>
#======================================================================================
function Get-OutlookItems {
    param (
        [object]$Folder,
        [string]$Filter = "",
        [OutlookItemType[]]$ItemTypes,
        [switch]$Recurse
    )
    $_entryLog = Log -Entry ": -Folder = $($Folder.Name) -Filter = $Filter -ItemTypes = $ItemTypes -Recurse = $Recurse"
    $null = $_entryLog
    
    $result = @()

    try {
        # Apply MAPI filter if provided
        $items = if ($Filter) {
            $Folder.Items.Restrict($Filter)
        } else {
            $Folder.Items
        }
    }
    catch {
        $msg = $_
        Log -Err "Re-Throwing Exception: $msg"
        throw $msg
    }

    if (-not $ItemTypes -or $($ItemTypes.Count) -eq 0 ) { $ItemTypes = @([OutlookItemType]::All) }
    if ($ItemTypes -contains [OutlookItemType]::All) {
        $result = $items
    } else {
        foreach ($item in $items) {
            if (Get-OutlookItemType -Item $item -in $ItemTypes) {
                $result += $item
            }
        }
    }

    try {
    if ($Recurse) {
        foreach ($subFolder in $Folder.Folders) {
            $result += Get-OutlookItems -Folder $subFolder -ItemTypes $ItemTypes -Filter $Filter -Recurse:$true
        }
    }
    }
    catch {
        $msg = $_
        Log -Err "Re-Throwing Exception: $msg"
        throw $msg
    }

    return $result
}

#endregion
#======================================================================================



#======================================================================================
#region     Function: Get-OutlookItem
<#
.SYNOPSIS
    Retrieves a specific Outlook item from a folder by name and optional type filtering.

.DESCRIPTION
    Retrieves a specific Outlook item from a folder by name and optional type filtering.

.PARAMETER Folder
    The Outlook folder to search.

.PARAMETER ItemName
    The name (subject) of the item to retrieve.

.PARAMETER ItemTypes
    Optional. An array of logical item types to filter by. Defaults to All.

.RETURNS
    The matching Outlook item or $null if not found.

.EXAMPLE
    $item = Get-OutlookItem -Folder $inboxFolder -ItemName "Meeting Request"

.NOTES
    Ensure the required modules are imported before calling this function.
#>
#======================================================================================
function Get-OutlookItem {
    param (
        [object]$Folder,
        [string]$ItemName,
        [OutlookItemType[]]$ItemTypes = @([OutlookItemType]::All)
    )

    if ($ItemTypes -contains [OutlookItemType]::All) {
        $filteredItems = $Folder.Items
    } else {
        $filteredItems = @()
        foreach ($item in $Folder.Items) {
            if (Get-OutlookItemType -Item $item -in $ItemTypes) {
                $filteredItems += $item
            }
        }
    }

    $result = $filteredItems | Where-Object { $_.Subject -eq $ItemName }
    return $result
}
#endregion
#======================================================================================


#======================================================================================
#region     Function: Get-OutlookItemName
<#
.SYNOPSIS
    Retrieves a display name for an Outlook item based on its logical type.

.DESCRIPTION
    Retrieves a display name for an Outlook item based on its logical type.

.PARAMETER Item
    The Outlook item.

.PARAMETER NameProperty
    Optional. The property name to use for the item's name.

.RETURNS
    The name of the Outlook item (Subject, FullName, etc.).

.EXAMPLE
    $itemName = Get-OutlookItemName -Item $mailItem

.NOTES
    Ensure the required modules are imported before calling this function.
#>
#======================================================================================
function Get-OutlookItemName {
    param (
        [object]$Item,
        [string]$NameProperty
    )
    $result = $null

    if (-not $Item ) {
        Log -Warn 'null Item passed to function.'
    }
    else {
        Log -Dbg "Type = $($Item.GetType().FullName), MessageClass = $($Item.MessageClass)"

        if ($Item) {
            if (-not $NameProperty) {
                $itemType = Get-OutlookItemType -Item $Item
                if ($itemType -eq [OutlookItemType]::Mail -or
                    $itemType -eq [OutlookItemType]::Appointment -or
                    $itemType -eq [OutlookItemType]::Meeting -or
                    $itemType -eq [OutlookItemType]::Task -or
                    $itemType -eq [OutlookItemType]::Receipt -or
                    $itemType -eq [OutlookItemType]::Note -or
                    $itemType -eq [OutlookItemType]::Journal -or
                    $itemType -eq [OutlookItemType]::Document -or
                    $itemType -eq [OutlookItemType]::Post) {
                    $NameProperty = 'Subject'
                }
                elseif ($itemType -eq [OutlookItemType]::Contact) {
                    $NameProperty = 'FullName'
                }
                else {
                    Log -Err -CallStack "Get-OutlookItemName(): Unsupported item type: $itemType for item of class $($Item.MessageClass)"
                }
            }

            if ($NameProperty) {
                try {
                    $result = $Item.PSObject.Properties[$NameProperty].Value
                }
                catch {
                    Log -Err "Failed to retrieve property '$NameProperty'. Error: $_"
                }
            }
        }
    }

    return $result
}
#endregion
#======================================================================================



#======================================================================================
#region     Function: Get-OutlookProperty
<#
.SYNOPSIS
    Retrieves a specified property from an Outlook item.

.DESCRIPTION
    Retrieves a specified property from an Outlook item. Supports both direct access and reflection-based access.

.PARAMETER Item
    The Outlook item.

.PARAMETER PropertyName
    The name of the property to retrieve.

.RETURNS
    The value of the specified property.

.EXAMPLE
    $propertyValue = Get-OutlookProperty -Item $mailItem -PropertyName "ReceivedTime"

.NOTES
    Ensure the required modules are imported before calling this function.
#>
#======================================================================================
function Get-OutlookProperty {
    param (
        [Parameter(Mandatory)]
        [object]$Item,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    $propertyValue = $null
    $msgClass = $null

    try {
        # Try direct access first
        if ($Item.PSObject.Properties[$PropertyName]) { 
            $propertyValue = $Item.$PropertyName 
        }

        # If that fails or returns null, try invokeMember fallback
        if (-not $propertyValue ) { 
            $propertyValue = $Item.GetType().InvokeMember($PropertyName, 'GetProperty', $null, $Item, $null) 
        }

        if (-not $propertyValue ) {
            $msgClass = $Item.MessageClass 
            Log -Warn "Get-OutlookProperty(): Property = '$PropertyName' not found on COM Object of MessageClass = $msgClass"
        }
    }
    catch {
        $err = $_   # same as $PSItem, which is the thrown error
        Log -Warn "Get-OutlookProperty(): Exception thrown attempting to get Property = '$PropertyName' on COM Object of MessageClass = $msgClass : Exception Name = [$($err.Exception.GetType().FullName)] : Exception Message = $($err.Exception.Message)."
    }
    
    return $propertyValue
}
#endregion
#======================================================================================


#======================================================================================
#region     Function: Get-OutlookItemDateTime
<#
.SYNOPSIS
    Extracts a usable DateTimeStamp from an Outlook item based on the specified DateSource.

.DESCRIPTION
    Extracts a usable DateTimeStamp from an Outlook item based on the specified DateSource.

.PARAMETER Item
    The Outlook item (mail/calendar/task) from which to extract the DateTimeStamp.

.PARAMETER DateSource
    The date property to use for extracting the DateTimeStamp. Valid values are:
    "ReceivedTime", "SentOn", "CreationTime", "LastModificationTime", "Start", "End", "DueDate", "DateCompleted".

.RETURNS
    The extracted DateTimeStamp if the specified DateSource is supported by the item type; otherwise, $null.

.EXAMPLE
    $dateTimeStamp = Get-OutlookItemDateTime -Item $mailItem -DateSource "SentOn"

.NOTES
    Ensure the required modules are imported before calling this function.
#>
#======================================================================================
function Get-OutlookItemDateTime {
    param (
        [object]$Item,
        [OutlookDateSourceType]$DateSource = [OutlookDateSourceType]::ReceivedTime
    )

    $dateTimeStamp = $null

    if ($DateSource -eq [OutlookDateSourceType]::ReceivedTime -and $Item.PSObject.Properties["ReceivedTime"]) { $dateTimeStamp = Get-OutlookProperty $Item "ReceivedTime" } 
    elseif ($DateSource -eq [OutlookDateSourceType]::SentOn -and $Item.PSObject.Properties["SentOn"]) { $dateTimeStamp = Get-OutlookProperty $Item "SentOn" } 
    elseif ($DateSource -eq [OutlookDateSourceType]::CreationTime -and $Item.PSObject.Properties["CreationTime"]) { $dateTimeStamp = Get-OutlookProperty $Item "CreationTime" } 
    elseif ($DateSource -eq [OutlookDateSourceType]::LastModificationTime -and $Item.PSObject.Properties["LastModificationTime"]) { $dateTimeStamp = Get-OutlookProperty $Item "LastModificationTime" } 
    elseif ($DateSource -eq [OutlookDateSourceType]::Start -and $Item.PSObject.Properties["Start"]) { $dateTimeStamp = Get-OutlookProperty $Item "Start" } 
    elseif ($DateSource -eq [OutlookDateSourceType]::End -and $Item.PSObject.Properties["End"]) { $dateTimeStamp = Get-OutlookProperty $Item "End" } 
    elseif ($DateSource -eq [OutlookDateSourceType]::DueDate -and $Item.PSObject.Properties["DueDate"]) { $dateTimeStamp = Get-OutlookProperty $Item "DueDate" } 
    elseif ($DateSource -eq [OutlookDateSourceType]::DateCompleted -and $Item.PSObject.Properties["DateCompleted"]) { $dateTimeStamp = Get-OutlookProperty $Item "DateCompleted" } 
    else { Log -Warn "Get-OutlookItemDateTime(): Unknown DateSource = $DateSource." }

    if (-not $dateTimeStamp) {
        Log -Err "Get-OutlookItemDateTime(): Unable to Get valid dateTimeStamp from DateSource $DateSource for item MessageClass = $($Item.MessageClass)."
        Log -Dbg "Get-OutlookItemDateTime(): Gettig default DateSource for item = $($Item.Name)."
        $DateSource = Get-OutlookItemDefaultDateSource $Item
        if ($DateSource) { 
            Log -Dbg "Get-OutlookItemDateTime(): Attempting to use DateTimeSource = $DateSource for MessageClass = $($Item.MessageClass) for Item = $($Item.Name)."
            $dateTimeStamp = Get-OutlookItemDateTime -Item $Item -DateSource $DateSource 
        }
        else { Log -Warn "Get-OutlookItemDateTime(): No valid $DateSource found." }
    }

    return $dateTimeStamp
}
#endregion
#======================================================================================


#======================================================================================
#region     Function: Get-OutlookItemDefaultDateSource
<#
.SYNOPSIS
    Determines the default DateTime source for a given Outlook item based on its type.

.DESCRIPTION
    Determines the default DateTime source for a given Outlook item based on its type.

.PARAMETER Item
    The Outlook item to evaluate.

.RETURNS
    The default DateTime source for the item as an OutlookDateSourceType enum value.

.EXAMPLE
    $defaultDateSource = Get-OutlookItemDefaultDateSource -Item $mailItem

.NOTES
    Ensure the required modules are imported before calling this function.
#>
#======================================================================================
function Get-OutlookItemDefaultDateSource {
    param (
        [object]$Item
    )

    $defaultDateSource = [OutlookDateSourceType]::ReceivedTime

    $itemType = Get-OutlookItemType -Item $Item

    if ($itemType -eq [OutlookItemType]::Mail)              { $defaultDateSource = [OutlookDateSourceType]::ReceivedTime } 
    elseif ($itemType -eq [OutlookItemType]::Appointment)   { $defaultDateSource = [OutlookDateSourceType]::Start } 
    elseif ($itemType -eq [OutlookItemType]::Meeting)       { $defaultDateSource = [OutlookDateSourceType]::Start } 
    elseif ($itemType -eq [OutlookItemType]::Task)          { $defaultDateSource = [OutlookDateSourceType]::DueDate } 
    elseif ($itemType -eq [OutlookItemType]::Contact)       { $defaultDateSource = [OutlookDateSourceType]::CreationTime } 
    elseif ($itemType -eq [OutlookItemType]::Note)          { $defaultDateSource = [OutlookDateSourceType]::CreationTime } 
    elseif ($itemType -eq [OutlookItemType]::Journal)       { $defaultDateSource = [OutlookDateSourceType]::Start } 
    elseif ($itemType -eq [OutlookItemType]::Post)          { $defaultDateSource = [OutlookDateSourceType]::CreationTime } 
    elseif ($itemType -eq [OutlookItemType]::Sharing)       { $defaultDateSource = [OutlookDateSourceType]::ReceivedTime } 
    elseif ($itemType -eq [OutlookItemType]::Receipt)       { $defaultDateSource = [OutlookDateSourceType]::CreationTime } 
    elseif ($itemType -eq [OutlookItemType]::Voicemail)     { $defaultDateSource = [OutlookDateSourceType]::ReceivedTime } 
    else { Log -Warn "Get-OutlookItemDefaultDateSource(): Unrecognized item type: $itemType. Defaulting to ReceivedTime." }
    return $defaultDateSource
}
#endregion
#======================================================================================



#======================================================================================
#region     Function: Move-OutlookItem
<#
.SYNOPSIS
    Moves an Outlook item to a specified target folder.

.DESCRIPTION
    Moves an Outlook item to a specified target folder.

.PARAMETER Item
    The Outlook item to be moved.

.PARAMETER TargetFolder
    The target folder to move the item to.

.RETURNS
    The moved item if the move was successful, otherwise $null.

.EXAMPLE
    $movedItem = Move-OutlookItem -Item $mailItem -TargetFolder $archiveFolder

.NOTES
    Ensure the required modules are imported before calling this function.
#>
#======================================================================================
function Move-OutlookItem {
    param (
        [object]$Item,
        [object]$TargetFolder
    )

    $movedItem = $null

    If (Get-DryRun) {
        Log -DryRun "Move $(Get-OutlookItemName -Item $item) To: $($TargetFolder.Name)"
        $movedItem = $Item
    } else {
        try {
            $movedItem = $Item.Move($TargetFolder)
            Log -Dbg "Moved $(Get-OutlookItemName -Item $item) To: $($TargetFolder.Name)"
        }
        catch {
            $itemName = Get-OutlookItemName $Item
            $msg = "Exception attempting to move item $itemName to $($TargetFolder.Name)"
            Log -Err "Re-thowing Exception: $msg"
            throw $msg
        }
    }
    return $movedItem
}
#endregion
#======================================================================================


#======================================================================================
#region     Function: Copy-OutlookItem
<#
.SYNOPSIS
    Copies an Outlook item and moves the copy to a specified target folder.

.DESCRIPTION
    Copies an Outlook item and moves the copy to a specified target folder.

.PARAMETER Item
    The Outlook item to be copied and moved.

.PARAMETER TargetFolder
    The target folder to move the copied item to.

.RETURNS
    The copied and moved item if successful, otherwise $null.

.EXAMPLE
    $copiedItem = Copy-OutlookItem -Item $mailItem -TargetFolder $archiveFolder

.NOTES
    Ensure the required modules are imported before calling this function.
#>
function Copy-OutlookItem {
    param (
        [object]$Item,
        [object]$TargetFolder
    )

    $copiedItem = $null

    If (Get-DryRun) {
        Log -DryRun "Copied $(Get-OutlookItemName -Item $item) To: $($TargetFolder.Name)"
        $copiedItem = $Item
    } else {
        $copiedItem = $Item.Copy().Move($TargetFolder)
        Log -Dbg "Copied $(Get-OutlookItemName -Item $item) To: $($TargetFolder.Name)"
    }
    return $copiedItem
}
#endregion
#======================================================================================



#======================================================================================
#region     Function: New-OutlookSubfolder
<#
.SYNOPSIS
    Creates a subfolder under a given parent folder if it doesn't already exist.

.DESCRIPTION
    Creates a subfolder under a given parent folder if it doesn't already exist.

.PARAMETER ParentFolder
    The parent folder under which the subfolder will be created.

.PARAMETER SubfolderName
    The name of the subfolder to be created.

.RETURNS
    A custom object containing:
    - Folder: The created or existing subfolder object.
    - wasCreated: A boolean indicating if the subfolder was newly created.

.EXAMPLE
    $result = New-OutlookSubfolder -ParentFolder $inboxFolder -SubfolderName "2025 Reports"

.NOTES
    Ensure the required modules are imported before calling this function.
#>
#======================================================================================
function New-OutlookSubfolder {
    param (
        [object]$ParentFolder,
        [string]$SubfolderName
    )

    Log -Dbg "Attempting to create folder: $($ParentFolder.Name)/$SubfolderName"

    # Initialize result variable
    $result = $null

    # Validate SubfolderName
    if (-not $SubfolderName) {
        Log -Err "SubfolderName is null or empty: $subfolderName."
    }
    elseif ($SubfolderName -match '[<>:"/\|?]') {
        $oldfolderName = $SubfolderName
        $SubfolderName = ConvertTo_SantizedName $oldfolderName
        Log -Warn "Invalid subfolderName = $oldfolderName : converted to: $SubfolderName."
    }

    $existingFolder = $ParentFolder.Folders | Where-Object { $_.Name -eq $SubfolderName }
    if ($existingFolder) {
        $result = [pscustomobject]@{
            Folder = $existingFolder
            wasCreated = $false
        }            
        Log -Dbg "New-OutlookSubfolder(): Folder: $($ParentFolder.Name)/$SubfolderName already exists"
    }
    else {
        if (Get-DryRun) {
            # Make a fake folder
            $fakeSubFolder = [pscustomobject]@{
                Name    = $SubfolderName # Only the local name, not a full path
                Folders = @()
                Items   = @()
            }
            $result = [pscustomobject]@{
                Folder = $fakeSubFolder
                wasCreated = $true
            }
            Log -DryRun "New-OutlookSubfolder(): Created fake folder: $($ParentFolder.Name)/$SubfolderName."
        } else {
            try {
                $newSubfolder = $ParentFolder.Folders.Add($SubfolderName)
                $result = [pscustomobject]@{
                    Folder = $newSubfolder
                    wasCreated = $true
                }
                Log -Dbg "New-OutlookSubfolder(): Created folder: $($newSubfolder.Name)"
            }
            catch {
                Log -Err "New-OutlookSubfolder(): Failed to create Folder $($ParentFolder.Name)/$SubfolderName '. Error: $_"
            }
        }
    }

    return $result
}
#endregion
#==================================================================================


#==================================================================================
#region      Function:  New-OutlookEmail 
<#
.SYNOPSIS
    Creates and optionally sends a new Outlook email.

.DESCRIPTION
    Uses the Outlook COM interface to create an email. Supports setting To, CC, BCC, Subject, Body,
    attachments, and optionally sending the email immediately or opening it as a draft.

.PARAMETER To
    The primary recipient(s) of the email.

.PARAMETER Subject
    The subject line of the email.

.PARAMETER Body
    The plain text or HTML content of the email body.

.PARAMETER CC
    Optional CC recipient(s).

.PARAMETER BCC
    Optional BCC recipient(s).

.PARAMETER Attachments
    An array of file paths to attach.

.PARAMETER AsHtml
    If present, interprets the Body as HTML.

.PARAMETER SendNow
    If present, sends the email immediately. Otherwise, displays it for review/editing.

.EXAMPLE
    New-OutlookEmail -To "someone@example.com" -Subject "Hello" -Body "This is a test"

.EXAMPLE
    New-OutlookEmail -To "team@example.com" -Subject "Update" -Body "<b>All systems go</b>" -AsHtml -SendNow

.NOTES
    Author: ChatGPT for PianoMan
    Date: $(Get-Date -Format "yyyy-MM-dd")
#>
#==================================================================================
function New-OutlookEmail {
    param (
        [Parameter(Mandatory)] [string]$To,
        [Parameter(Mandatory)] [string]$Subject,
        [Parameter(Mandatory)] [string]$Body,
        [string]$CC = "",
        [string]$BCC = "",
        [string[]]$Attachments = @(),
        [switch]$AsHtml,
        [switch]$SendNow
    )

    $outlook = New-Object -ComObject Outlook.Application
    $mail = $outlook.CreateItem(0)  # olMailItem

    $mail.To = $To
    $mail.Subject = $Subject

    if ($AsHtml) {
        $mail.HTMLBody = $Body
    } else {
        $mail.Body = $Body
    }

    if ($CC)  { $mail.CC  = $CC }
    if ($BCC) { $mail.BCC = $BCC }

    foreach ($file in $Attachments) {
        if ($file -and (Test-Path $file)) {
            $mail.Attachments.Add($file)
        }
    }

    if ($SendNow) {
        $mail.Send()
    } else {
        $mail.Display()
    }

    return $mail
}
#endregion
#=====================================================================================


#==================================================================================
#region     ** Future AI Integration Points **
#==================================================================================


# Placeholder: AI-driven summarization of Outlook item
function OutlookItemSummary {
    param ([object]$Item)
    # TODO: Use body/subject/timestamp to create LLM input
    return "Summary not implemented (but soon)"
}


# Placeholder: Classify the item with tags or labels using an AI model
function Set-OutlookItemClassification {
    param ([object]$Item)
    # TODO: Use semantic analysis to categorize
    return "Classification pending."
}
#endregion
#==================================================================================


#endregion
#==================================================================================
