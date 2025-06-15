# Define script parameters
#param (
#    [string]$TargetDir = "C:\Users\shawn.hillis\OneDrive - General Dynamics Mission Systems\Documents\CPM Plus\DOs-TOs\TO24 STE LTS\DPME\Reports\ITD_Reports",
#    [string]$SubjectFilter = "CPM+ TO24 ITD", # Adjust based on your requirement
#    [string]$SenderFilter = "oas_prod@gdit.com", # Adjust if needed
#    [string]$SearchFolder = "Inbox", # Specify the folder to search
#    [bool]$UnreadOnly = $false, # Toggle to filter unread messages
#    [string]$PrependString = "", # Optional string to prepend to the file name
#    [string]$AppendString = "" # Optional string to append to the file name (before extension)
#)
# param (
#     [string]$TargetDir = "",
#     [string]$SubjectFilter = "", # Adjust based on your requirement
#     [string]$SenderFilter = "oas_prod@gdit.com", # Adjust if needed
#     [string]$SearchFolder = "Inbox", # Specify the folder to search
#     [bool]$UnreadOnly = $false, # Toggle to filter unread messages
#     [string]$PrependString = "", # Optional string to prepend to the file name
#     [string]$AppendString = "", # Optional string to append to the file name (before extension)
#     [string]$LogFile = "C:\Windows\Temp\Python.Log" # Optional log file path
# )

# Function Descriptor:
# This script processes emails in a specified Outlook folder, filters them by subject and sender, and optionally unread status,
# and saves attachments to a target directory with optional strings to prepend or append to the file names. It also logs the details
# of emails and attachments processed if a log file path is provided.
#
# Usage:
# Run the script with the following parameters:
# -TargetDir        (string): The directory where attachments will be saved.
# -SubjectFilter    (string): The subject filter to match emails.
# -SenderFilter     (string): The sender email address to match (default: "oas_prod@gdit.com").
# -SearchFolder     (string): The name of the Outlook folder to search (default: "Inbox").
# -UnreadOnly       (bool): Toggle to filter unread messages (default: $false).
# -PrependString    (string): Optional string to prepend to the file name.
# -AppendString     (string): Optional string to append to the file name (before extension).
# -LogFile          (string): Optional log file path to log details of emails and attachments processed.
#
# Example Execution:
# .\ScriptName.ps1 -TargetDir "C:\Attachments" -SubjectFilter "Report" -SenderFilter "example@domain.com" -SearchFolder "Inbox" -UnreadOnly $true -PrependString "PRE_" -AppendString "_APP" -LogFile "C:\Logs\email_log.txt"

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


function SaveOutlookAttachments {
    param (
        [string]$TargetDir          = "",
        [string]$SubjectFilter      = "",                       # Adjust based on your requirement,
        [string]$SenderFilter       = "oas_prod@gdit.com",      # Adjust if needed,,
        [string]$SearchFolder       = "Inbox",                  # Specify the folder to search 
        [bool]$UnreadOnly           = $false,                   # Toggle to filter unread messages,
        [string]$PrependString      = "",                       # Optional string to prepend to the file name,
        [string]$AppendString       = "" #,                     # Optional string to append to the file name (before extension),
       # [string]$LogFile = "C:\Windows\Temp\Python.Log"     # Optional log file path
    )

    $numEmailsSearched = 0
    $numAttachmentsSaved = 0
    $numEmailsMarkedAsRead = 0
    $numMatchedEmailsSkippedAsRead = 0

    Log -Dbg "SaveOutlookAttachments:  TargetDir = $TargetDir, SubjectFilter = '$SubjectFilter', SenderFilters = '$SenderFilter', SearchFolder = '$SearchFolder', UnreadOnly = $UnreadOnly, PrependString = '$PrependString', AppendString = '$AppendString' #, LogFile = $LogFile"

    # Connect to Outlook
    $Outlook = New-Object -ComObject Outlook.Application
    $Namespace = $Outlook.GetNamespace("MAPI")
    $Folder = $Namespace.GetDefaultFolder([Microsoft.Office.Interop.Outlook.OlDefaultFolders]::olFolderInbox)

    if ($SearchFolder -ne "Inbox") {
        $Folder = $Folder.Folders | Where-Object { $_.Name -eq $SearchFolder }
    }

    if (-not $Folder) {
        Write-Error "Folder '$SearchFolder' not found."
        return
    }

    # Ensure the target directory exists
    if (!(Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir
    }

    # Process emails
    foreach ($Email in $Folder.Items) {
        $numEmailsSearched++

       if ($Email.Subject -like "*$SubjectFilter*" -and $Email.SenderEmailAddress -eq $SenderFilter -and $UnreadOnly -and -not $Email.UnRead ) {
            $numMatchedEmailsSkippedAsRead++
       }

         # Filter unread messages if the flag is set
        if ($UnreadOnly -and -not $Email.UnRead) {
            continue
        }

        if ($Email.Subject -like "*$SubjectFilter*" -and $Email.SenderEmailAddress -eq $SenderFilter) {
            Log -Dbg "Processing email: Subject='$($Email.Subject)', Sender='$($Email.SenderEmailAddress)'"
            foreach ($Attachment in $Email.Attachments) {
                $FileName = $Attachment.FileName
                $FileExtension = [System.IO.Path]::GetExtension($FileName)
                $BaseFileName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
                $NewFileName = "$PrependString$BaseFileName$AppendString$FileExtension"
                $FilePath = Join-Path -Path $TargetDir -ChildPath $NewFileName
                $Attachment.SaveAsFile($FilePath)
                Log -Info "Saved attachment: $FilePath"
                $numAttachmentsSaved++
            }

            # Mark email as read if the UnreadOnly flag is true
            if ($UnreadOnly) {
                $Email.UnRead = $false
                Log -Dbg "Marked email as read: Subject='$($Email.Subject)', Sender='$($Email.SenderEmailAddress)'"
                $numEmailsMarkedAsRead++
            }
        }
    }
    
Log -Info "Emails Searched = $numEmailsSearched, Attachments Saved = $numAttachmentsSaved, Emails Marked as Read = $numEmailsMarkedAsRead, Matched Emails Skipped as Read = $numMatchedEmailsSkippedAsRead"
}

# ==========================================================================================
#region      Execution Guard / Main Entrypoint
# ==========================================================================================

if ($MyInvocation.InvocationName -eq '.') {
    # Dot-sourced – do nothing, just define functions/aliases
    Write-Debug 'Script dot-sourced; skipping main execution.'
    return
}

if ($MyInvocation.MyCommand.Path -eq $PSCommandPath) {
    # Direct execution
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path)
    if (Get-Command $baseName -CommandType Function -ErrorAction SilentlyContinue) {
        Log -Info "$baseName (Format-ToString($Global:RemainingArgs))"
        (& $baseName @Global:RemainingArgs)
    } else {
        Log -Err "No function named '$baseName' found to match script entry point."
    }
} else {
    Log -Warn "Unexpected execution context: $($MyInvocation.MyCommand.Path)"
}
#endregion   Execution Guard / Main Entrypoint
# ==========================================================================================

# Main Execution Block
#SaveOutlookAttachments -TargetDir $TargetDir -SubjectFilter $SubjectFilter -SenderFilter $SenderFilter -SearchFolder $SearchFolder -UnreadOnly $UnreadOnly -PrependString $PrependString -AppendString $AppendString # -LogFile $LogFile
