# Logging.ps1
# This script provides logging functionality with different log levels.
# It includes an enumerated LogLevel parameter and a global log level setting.
# Log messages with LogLevel of Always are always printed, else only print log messages where LogLevel -le global log level.

# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

if (-not $Script:PSRoot) {
    $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    #Write-Host "Set Global:PSRoot = $Script:PSRoot"
    . "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"

}
if (-not $Script:PSRoot) {
    throw "Script:PSRoot must be set by the entry-point script before using internal components."
}

if (-not $Script:CliArgs -and $args) {
    $Script:CliArgs = $args
}

if (-not $Script:Included_Get_Logging_Utils_Block) { 
    $Script:Included_Get_Logging_Utils_Block = $true

    . "$Script:PSRoot\Scripts\DevUtils\Get-CallStack.ps1"
}

#endregion
# ===========================================================================================

<#
$stackframe properties:

Property	        Description
---------------     ------------------------------------------------------
FunctionName	    Name of the function or command being executed.
ScriptName	        The full path to the script file containing the code. May be $null in REPL or dynamic contexts.
ScriptLineNumber	The line number in the script where the function or command is executing.
OffsetInLine	    The character offset (column) where the statement starts.
Arguments	        The raw arguments passed into the command or function (not always reliable).
InvocationInfo	    A detailed InvocationInfo object containing even more metadata.
Position	        A System.Management.Automation.Language.IScriptExtent showing exact source span.
ToString()	        Returns a formatted string: FunctionName at ScriptName:ScriptLineNumber.
#>

<#
.SYNOPSIS
    Defines the LogLevel enumeration for categorizing log messages by severity and type.

.DESCRIPTION
    The LogLevel enumeration provides a set of named constants to represent different levels of logging severity and types of log messages.
    These levels are used to control the verbosity and detail of the log output, allowing for filtering and selective logging based on the global log level setting.

.ENUMERATION MEMBERS
    Never      = -1    # Disables logging.
    Always     = 0     # Logs messages that should always be printed.
    Error      = 1     # Logs error messages.
    Warn       = 2     # Logs warning messages.
    Info       = 4     # Logs informational messages.
    Debug      = 8     # Logs debug messages.
    EntryExit  = 16    # Logs method entry and exit points.
    CallStack = 32    # Logs stack trace information.
    All        = 256   # Logs all messages.

.NOTES
    This enumeration is used throughout the script to specify the log level for various logging operations.
#>
enum LogLevel {
    Never      = -1
    Always     = 0
    Error      = 1
    Warn       = 2
    Info       = 4
    Debug      = 8
    EntryExit  = 16
    CallStack  = 32
    All        = 256
}

#==================================================================================
#region INIT: Global Variables
#==================================================================================
if (-not (Get-Variable -Name Included_Logging_Block -Scope Script -ErrorAction SilentlyContinue)) {
    Set-Variable -Name Included_Logging_Block -Scope Script -Value $true

    $Global:GlobalLogLevel = [LogLevel]::Info
    $Global:LogFileName    = "$Script:PSRoot\PowerShellLog.txt"

    $Global:LogAlways     = [LogLevel]::Always
    $Global:LogError      = [LogLevel]::Error
    $Global:LogWarn       = [LogLevel]::Warn
    $Global:LogInfo       = [LogLevel]::Info
    $Global:LogDebug      = [LogLevel]::Debug
    $Global:LogEntryExit  = [LogLevel]::EntryExit
    $Global:LogCallStack  = [LogLevel]::CallStack
    $Global:LogAll        = [LogLevel]::All
    $Global:LogNever      = [LogLevel]::Never
}
#endregion
#==================================================================================


#==================================================================================
#region GETTERS/SETTERS & Converter
#==================================================================================
function Set-LogFilePathName {
    param([string]$FileName)
    $global:LogFileName = $FileName
    $global:LogFileName = $global:LogFileName
}
function Get-LogFilePathName { return $global:LogFileName }

function Set-LogLevel {
    param([LogLevel]$LogLevel)
    $global:GlobalLogLevel = $LogLevel
    $global:GlobalLogLevel = $global:GlobalLogLevel

}
function Get-LogLevel { return $global:GlobalLogLevel }

# function ConvertTo-LogLevel {
#     [CmdletBinding()]
#     param( [Parameter(Mandatory)][string]$LogLevel )
#     $enumLogLevel = [LogLevel]::Info
#     try { $enumLogLevel = [LogLevel]::Parse([string]$LogLevel, $true) }
#     catch { Write-Warning "ConvertTo-LogLevel: Unable to convert $LogLevel to a LogLevel - falling back to $($enumLogLevel.ToString())." }
#     return $enumLogLevel
# }
function ConvertTo-LogLevel {
    [CmdletBinding()]
    param( [Parameter(Mandatory)][string]$LogLevel )
    $enumLogLevel = [LogLevel]::Info
    $logLevelLower = $LogLevel.ToLower()
    
    if ($logLevelLower -eq "never") {
        $enumLogLevel = [LogLevel]::Never
    } elseif ($logLevelLower -eq "always") {
        $enumLogLevel = [LogLevel]::Always
    } elseif ($logLevelLower -eq "error") {
        $enumLogLevel = [LogLevel]::Error
    } elseif ($logLevelLower -eq "warn") {
        $enumLogLevel = [LogLevel]::Warn
    } elseif ($logLevelLower -eq "info") {
        $enumLogLevel = [LogLevel]::Info
    } elseif ($logLevelLower -eq "debug") {
        $enumLogLevel = [LogLevel]::Debug
    } elseif ($logLevelLower -eq "entryexit") {
        $enumLogLevel = [LogLevel]::EntryExit
    } elseif ($logLevelLower -eq "callstack") {
        $enumLogLevel = [LogLevel]::CallStack
    } elseif ($logLevelLower -eq "all") {
        $enumLogLevel = [LogLevel]::All
    } else {
        Write-Warning "ConvertTo-LogLevel: Unable to convert $LogLevel to a LogLevel - falling back to $($enumLogLevel.ToString())."
    }
    
    return $enumLogLevel
}
#endregion
#==================================================================================


#==================================================================================
#region     Function: Invoke-LogLevelOverride
#==================================================================================
function Invoke-LogLevelOverride {
    param (
        [Parameter(Mandatory)]
        [LogLevel]$LogLevel,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $prevLogLevel = Get-LogLevel
    $null = Set-LogLevel $LogLevel
    try {
        & $ScriptBlock
    }
    finally {
        $null = Set-LogLevel $prevLogLevel
    }
}
#endregion
#==================================================================================

#==================================================================================
#region Function: Trace-EntryExit
# Description:
#   Executes a script block with automatic Log -Entry and Log -Exit via .Dispose().
# Parameters:
#   - Message (string): The message for Log -Entry.
#   - ScriptBlock (scriptblock): The body to execute.

#==================================================================================
function Trace-EntryExit {
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $null = Log -Entry -StackOffset 1 -Msg $Message
    try {
        & $ScriptBlock
    }
    finally {
        # if ($null -ne $scope -and $null -ne $scope.Dispose) {
        #     $scope.Dispose()
        # }
        Log -Exit -StackOffset 1 -Msg $Message
    }
}
#endregion
#==================================================================================


#==================================================================================
#region      Function: Log
# Description: Logs a message with a specified log level.
# Parameters:
#   - Debug: Switch to log a debug message.
#   - Error: Switch to log an error message.
#   - Warn: Switch to log a warning message.
#   - Info: Switch to log an informational message.
#   - Always: Switch to always log the message.
#   - Append: Switch to append the message without a newline prefix, timestamp, or log level.
#   - LogFile: The file path to log the message.
#   - Msg: The message to log.
#   - DryRun: Switch to log the message regardless of the global log level.
# Usage:
#   Log "This is an info message"
#   Log -Error "This is an error message"
#   Log "This is also an error message" -Error
#   Log -Warn -Debug "This is a warn message"
#   Log -Append "This message is appended"
#   Log -DryRun "This is a dry run message"
# Example:
# function Process-Data {
#     $entryLog = Log -Entry "Begin processing data set"
#
#     # Simulated work
#     Start-Sleep -Milliseconds 500
#
#     # Exit log is triggered automatically when $entryLog goes out of scope
# }
#
# Expected Output:
# [2025-05-21 14:03:17] [Trace] Process-Data:2 : ▶️ Enter Process-Data : Begin processing data set
# [2025-05-21 14:03:18] [Trace] Process-Data:2 : ◀️ Exit Process-Data
#==================================================================================
function Log {
    param(
        [switch]$Dbg,
        [switch]$Err,
        [switch]$Warn,
        [switch]$Info,
        [switch]$Always,
        [switch]$DryRun,
        [string]$Tag,
        [switch]$NoMsg,
        [switch]$MsgOnly,
        [switch]$NoNewLine,
        [string]$LogFile,
        [switch]$Entry,
        [switch]$Exit,
        [switch]$CallStack,
        [switch]$Dot,
        [Parameter(Mandatory = $false)][int]$StackOffset,
        [Parameter(Position = 0, Mandatory = $false)][string]$Msg
    )

    $levelData = Get-LogLevelAndColor @PSBoundParameters
    $LogLevel = $levelData.Level
    $color = $levelData.Color

    if ( -not $StackOffset ) { $StackOffset = 1 } else { $StackOffset += 1 }
    if ( -not $LogFile) { $LogFile = Get-LogFilePathName }
    if ( -not $Tag ) { $Tag = $levelData.Tag }

    #$theStack = Get-CallStack
    $stackFrame = (Get-StackFrame -Index 0 -Skip $StackOffset)
    $fnName = $stackFrame.FunctionName

    if ($Dot) {
        $Msg = "."
        #Write-LogMessage -Message $Msg -Color $color -NoNewLine:$true
        $MsgOnly = $true
    }

    if ($CallStack) {
        #$Msg = "$Msg`n" + (((Get-PSCallStack)[($StackOffset)] | ForEach-Object {
        #    "    $($_.FunctionName) @ $($_.ScriptName):$($_.ScriptLineNumber)"
        $Msg = "$Msg`n$(Get-CallStack -Skip $StackOffset)"
    }

    if ($Entry) {
        $Msg = "Enter $fnName : $Msg"
    }

    if ($Exit) {
        $Msg = "Exit $fnName : $Msg"
    }

    if ([int]$global:GlobalLogLevel -eq [int]$Global:LogAll -or [int]$LogLevel -le [int]$global:GlobalLogLevel -or $DryRun) {
        $logPrefix = if (-not $MsgOnly) { Format-LogPrefix -Level $LogLevel -Tag $Tag -Frame $stackFrame } else { "" }
        $logEntry = if (-not $NoMsg) { "$logPrefix $Msg" } else { $logPrefix }

        Write-LogMessage -Message $logEntry -Color $color -NoNewLine:$NoNewLine -LogFile:$LogFile

        if ($Entry) {
            $logEntryExitObj = [PSCustomObject]@{}
            Add-Member -InputObject $logEntryExitObj -MemberType ScriptMethod -Name Dispose -Value {
                Log -Exit -StackOffset 1 -Msg "$fnName"
            }#.GetNewClosure()
            return $logEntryExitObj
        }
    }
}

#endregion
#==================================================================================


#==================================================================================
#region INTERNAL: Get-LogLevelAndColor
#==================================================================================
function Get-LogLevelAndColor {
    param(
        [switch]$Dbg,   [switch]$Warn,      [switch]$Info,
        [switch]$Err,   [switch]$Always,    [switch]$DryRun,
        [switch]$Entry, [switch]$Exit,      [switch]$CallStack,
        [switch]$Dot
    )

    $level = $Global:LogAll
    $color = "White"
    $tag = ""

    if ($Always   -and [int]$Global:LogAlways     -lt [int]$level) { $level = $Global:LogAlways;     $color = "Cyan";   $tag = "ALWAYS"     }    if ($Dbg      -and [int]$Global:LogDebug      -lt [int]$level) { $level = $Global:LogDebug;      $color = "Gray";   $tag = "DEBUG "    }
    if ($Warn     -and [int]$Global:LogWarn       -lt [int]$level) { $level = $Global:LogWarn;       $color = "Yellow"; $tag = " WARN "    }
    if ($Entry    -and ([int]$Global:LogEntryExit -lt [int]$level)) {
        $level = $Global:LogEntryExit; $color = "Magenta"; $tag = "ENTRY "
    }
    if ($Exit     -and ([int]$Global:LogEntryExit -lt [int]$level)) {
        $level = $Global:LogEntryExit; $color = "Magenta"; $tag = " EXIT "
    }
    if ($CallStack -and [int]$Global:LogCallStack -lt [int]$level) {
        $level = $Global:LogCallStack; $color = "DarkGray"; $tag = "STACK "
    }
    if ($DryRun   -and [int]$Global:LogDryRun     -lt [int]$level) { $level = $Global:LogDryRun;     $color = "Blue";   $tag = "DRYRUN"     }
    if ($Info     -and [int]$Global:LogInfo       -lt [int]$level) { $level = $Global:LogInfo;       $color = "Green";  $tag = " INFO "     }
    if ($Err      -and [int]$Global:LogError      -lt [int]$level) { $level = $Global:LogError;      $color = "Red";    $tag = "ERROR "     }


    return @{ Level = $level; Color = $color; Tag = $tag }
}


#==================================================================================
#region INTERNAL: Format-LogPrefix
#==================================================================================
function Format-LogPrefix {
    param (
        [LogLevel]$LogLevel,
        [string]$Tag,
        [switch]$DryRun,
        [switch]$MsgOnly,
        [object]$Frame
    )
    if ($MsgOnly) { return "" }

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $functionName = $Frame.FunctionName
    $lineNumber = $Frame.ScriptLineNumber
    $fileName = if ($Frame.ScriptName) {
        [System.IO.Path]::GetFileName($stackFrame.ScriptName)
    } else {
        "<NoFile>"
    }
    $levelLabel = if ($Tag) { "[$Tag]" } elseif ($DryRun) { "[DryRun]" } else { "[$LogLevel]" }
    $indent = " " * ($script:LogIndentLevel * 2)

    return "[$timestamp] $levelLabel $($fileName):$($lineNumber):$($functionName): $indent"
}
#endregion
#==================================================================================


#==================================================================================
#region INTERNAL: Write-LogMessage
#==================================================================================
function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewLine,
        [string]$LogFile
    )

    Write-Host -NoNewLine:$NoNewLine $Message -ForegroundColor $Color

    if ($LogFile) {
        Add-Content -Path $LogFile -Value $Message -NoNewLine:$NoNewLine
    }
    elseif (Get-LogFilePathName) {
        Add-Content -Path (Get-LogFilePathName) -Value $Message -NoNewLine:$NoNewLine
    }
}

#endregion
#==================================================================================


#==================================================================================
# # Example: Function Entry/Exit
# function Process-Data {
#     $entryLog = Log -Entry "Begin processing data set"

#     # Simulated work
#     Start-Sleep -Milliseconds 500

#     # Exit log is triggered automatically when $entryLog goes out of scope
# }

# Expected Output:
# [2025-05-21 14:03:17] [Trace] Process-Data:2 : ▶️ Enter Process-Data : Begin processing data set
# [2025-05-21 14:03:18] [Trace] Process-Data:2 : ◀️ Exit Process-Data

# -------------------------------------------------------------------------

# Example: Logging with Stack Trace
# function Invoke-Failure {
#     Log -Err -CallStack "Unexpected error occurred"
# }

# Expected Output:
# [2025-05-21 14:06:09] [Trace] Invoke-Failure:3 : Unexpected error occurred
#     Invoke-Failure @ Invoke-Failure.ps1:3
#     Perform-Operation @ Operations.ps1:17
#     main @ Start.ps1:6

# -------------------------------------------------------------------------

# Example: Tagged debug message
# Log -Dbg -Tag "SYNC" "Starting folder sync"

# Expected Output:
# [2025-05-21 14:08:00] [SYNC] Start-Sync:42 : Starting folder sync

# -------------------------------------------------------------------------

# Example: Dry run info log
# Log -DryRun -Info "Would delete 10 stale entries"

# Expected Output:
# [2025-05-21 14:09:12] [DryRun] Cleanup-Entries:21 : Would delete 10 stale entries

# -------------------------------------------------------------------------

# Example: Append and formatting options
# Log -Info -MsgOnly ">>> Starting >>>"
# Log -Info -NoMsg "Just want the prefix"
# Log -Info -NoNewLine "Still working..."

# Expected Output:
# >>> Starting >>>
# [2025-05-21 14:11:00] [Info] MyFunction:99 :
# [2025-05-21 14:11:01] [Info] MyFunction:100 : Still working...

# -------------------------------------------------------------------------

# Example: Manual Dispose in try/finally block
# function Critical-Section {
#     $scope = Log -Entry "Starting critical section"

#     try {
#         # Work
#     }
#     finally {
#         $scope.Dispose()
#     }
# }

# Expected Output:
# [timestamp] [Trace] Critical-Section:2 : ▶️ Enter Critical-Section : Starting critical section
# [timestamp] [Trace] Critical-Section:7 : ◀️ Exit Critical-Section

# -------------------------------------------------------------------------

