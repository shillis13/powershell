#Write-Host "Loading CallStack.ps1"

# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

if (-not $Script:PSRoot) {
    $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    Write-Host "Set Script:PSRoot = $Script:PSRoot"
    
    . "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"
}
if (-not $Script:PSRoot) {
    throw "Script:PSRoot must be set by the entry-point script before using internal components."
}

if (-not $Script:CliArgs -and $args) {
    $Script:CliArgs = $args
}

    
if (-not $Script:Included_Get_Callstack_Utils_Block) { 
    $Script:Included_Get_Callstack_Utils_Block = $true

    . "$Script:PSRoot\Scripts\DevUtils\Format-Utils.ps1"
}

#endregion
# ===========================================================================================

#=========================
#region     CallStack.ps1
<#
.SYNOPSIS
    Utilities for retrieving and formatting the PowerShell call stack.

.DESCRIPTION
    Contains helper functions for examining the current call stack,
    getting the current or caller function, and converting stack traces
    to a readable string format.

.NOTES
    Dot-source from DevUtils to enable debugging/logging introspection.

    SKIP and INDEX usage:
    - $Skip refers to how many levels up to skip in the current stack.
      Each function that processes the stack should increment $Skip by 1
      to account for its own invocation unless already adjusted.
    - $Index is used when retrieving a specific stack frame after skipping.
      For example, Index = 0 gets the current function (after skip),
      Index = 1 gets the caller, and so on.

    Max settings:
    - Any Max* value set to 0 indicates "no maximum" or "unlimited" behavior.
    - Call stack formatting dynamically sizes each column to fit actual data,
      constrained by the Max* widths.
#>
#=========================

#=========================
# Configuration
#=========================
if (-not $script:CallStack_MaxDepth)     { $script:CallStack_MaxDepth     = 10 }
if (-not $script:CallStack_MaxFcnWidth)  { $script:CallStack_MaxFcnWidth  = 40 }
if (-not $script:CallStack_MaxPathWidth) { $script:CallStack_MaxPathWidth = 50 }
if (-not $script:CallStack_MaxLocWidth)  { $script:CallStack_MaxLocWidth  = 50 }
if (-not $script:CallStack_MaxLineWidth) { $script:CallStack_MaxLineWidth = 6  }


# ========================================
<#
.SYNOPSIS
    Sets the maximum values for call stack depth and column widths.

.DESCRIPTION
    This function allows you to configure the maximum depth of the call stack
    and the maximum widths for function, file, and line columns.

.PARAMETER MaxDepth
    The maximum depth of the call stack to retrieve.

.PARAMETER MaxFcnWidth
    The maximum width for the function name column.

.PARAMETER MaxLocWidth
    The maximum width for the file name column.

.PARAMETER MaxLineWidth
    The maximum width for the line number column.

.EXAMPLE
    Set-CallStackMax -MaxDepth 20 -MaxFcnWidth 50 -MaxLocWidth 60 -MaxLineWidth 10
#>
# ========================================
function Set-CallStackMax {
    [CmdletBinding()]
    param(
        [int]$MaxDepth,
        [int]$MaxFcnWidth,
        [int]$MaxPathWidth,
        [int]$MaxLocWidth,
        [int]$MaxLineWidth
    )

    if ($PSBoundParameters.ContainsKey('MaxDepth'))     { $script:CallStack_MaxDepth      = $MaxDepth }
    if ($PSBoundParameters.ContainsKey('MaxPathWidth')) { $script:CallStack_MaxPathWidth  = $MaxPathWidth }
    if ($PSBoundParameters.ContainsKey('MaxFcnWidth'))  { $script:CallStack_MaxFcnWidth   = $MaxFcnWidth }
    if ($PSBoundParameters.ContainsKey('MaxLocWidth'))  { $script:CallStack_MaxLocWidth   = $MaxLocWidth }
    if ($PSBoundParameters.ContainsKey('MaxLineWidth')) { $script:CallStack_MaxLineWidth  = $MaxLineWidth }
}

# ========================================
<#
.SYNOPSIS
    Retrieves the current maximum settings for call stack depth and column widths.
.DESCRIPTION
    This function returns an object containing the current maximum settings
    for call stack depth and column widths.
.EXAMPLE
    $maxSettings    = Get-CallStackMax
    $theMaxDepth    = $maxSettings.MaxDepth
    $theMaxFcnWidth = $maxSettings.MaxFcnWidth
#>
# ========================================
function Get-CallStackMax {
    [CmdletBinding()]
    param()

    $valueObj = [PSCustomObject]@{
        MaxDepth     = $script:CallStack_MaxDepth
        MaxFcnWidth  = $script:CallStack_MaxFcnWidth
        MaxPathWidth = $script:CallStack_MaxPathWidth
        MaxLocWidth  = $script:CallStack_MaxLocWidth
        MaxLineWidth = $script:CallStack_MaxLineWidth
    }
    return $valueObj
}


# ========================================
<#
.SYNOPSIS
    Retrieves the current call stack with optional depth and skip parameters.

.DESCRIPTION
    This function retrieves the current call stack up to a specified depth,
    skipping a specified number of frames, and returns the formatted stack trace.

.PARAMETER Depth
    The maximum depth of the call stack to retrieve. Defaults to the global maximum depth.

.PARAMETER Skip
    The number of stack frames to skip. Defaults to 0.

.EXAMPLE
    $stack = Get-CallStack -Depth 5 -Skip 1
    
    [#] Function      Script                                             Line  Location
    [0] DummyC        C:\Users\shawn.hillis\O...est-CallStack.Tests.ps1 45    Test-CallStack.Tests.ps1: line 45
    [1] DummyB        C:\Users\shawn.hillis\O...est-CallStack.Tests.ps1 44    Test-CallStack.Tests.ps1: line 44
    [2] DummyA        C:\Users\shawn.hillis\O...est-CallStack.Tests.ps1 43    Test-CallStack.Tests.ps1: line 43
    [3]               (31 frame(s) skipped)
    [4] <ScriptBlock> C:\Users\shawn.hillis\O...est-CallStack.Tests.ps1 13    Test-CallStack.Tests.ps1: line 13
    [5] <ScriptBlock>                                                    1     <No file>

.OUTPUT
    PSCustomObject with properties: MaxDepth, MaxFcnWidth, MaxLocWidth, MaxLineWidth
#>
# ========================================
function Get-CallStack {
    [CmdletBinding()]
    param(
        [int]$Depth = $script:CallStack_MaxDepth,
        [int]$Skip = 0
    )

    $Skip += 1
    $frames = _GetCallStack -Depth $Depth -Skip $Skip
    $formatted = _FormatCallStack -Frames $frames
    return $formatted
}


#-----------------------------
function Get-StackFrame {
    [CmdletBinding()]
    param(
        [int]$Index,
        [int]$Skip = 0,
        [int]$Depth = $script:CallStack_MaxDepth

    )

    $Skip += 1
    $frames = _GetCallStack -Depth $Depth -Skip $Skip
    $frame = if ($Index -ge 0 -and $Index -lt $frames.Count) { $frames[$Index] } else { $null }
    return $frame
}

#-----------------------------
function Get-CurrentFunctionName {
    [CmdletBinding()]
    param(
        [int]$Skip = 0
    )

    $Skip += 1
    $frame = Get-StackFrame -Index 0 -Skip $Skip
    $name = $frame.FunctionName
    return $name
}

# ========================================
<#
.SYNOPSIS
    Retrieves the name of the caller function.

.DESCRIPTION
    This function retrieves the name of the caller function in the call stack after
    skipping a specified number of frames.

.PARAMETER Skip
    The number of stack frames to skip.

.EXAMPLE
    $callerFunctionName = Get-CallerFunctionName -Skip 1

.OUTPUT
    String representing the caller function name.
#>
# ========================================
function Get-CallerFunctionName {
    [CmdletBinding()]
    param(
        [int]$Skip = 0
    )

    $Skip += 1
    $frame = Get-StackFrame -Index 1 -Skip $Skip
    $name = $frame.FunctionName
    return $name
}

#-----------------------------
#region    Private/Internal Methods

function _GetCallStack {
    param(
        [int]$Depth = $script:CallStack_MaxDepth,
        [int]$Skip = 0
    )

    $Skip += 1
    $stack = Get-PSCallStack
    $stack = Get-PSCallStack | Select-Object -Skip $Skip

    if ($Depth -gt 0 -and $stack.Count -gt $Depth) {
        $half = [math]::Floor($Depth / 2)
        $top    = $stack[0..($half)]
        $bottom = $stack[($stack.Count - $half)..($stack.Count - 1)]

        $ellipsis = [PSCustomObject]@{
            FunctionName     = " "
            Location         = "($($stack.Count - $Depth) frame(s) skipped) "
            ScriptName       = " " #"($($stack.Count - $Depth) frame(s) skipped) "
            #ScriptLineNumber = " "
         }

        $stack = @($top + $ellipsis + $bottom)
    }

    return $stack
}

function _FormatCallStack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Frames
    )

    if (-not $Frames -or $Frames.Count -eq 0) {
        return "<No call stack>"
    }

    # Calculate maximum actual widths for each column
    $maxFcn  = ($Frames | Where-Object { $_.FunctionName -notlike "... (*) frame(s) skipped) ..." } | ForEach-Object { $_.FunctionName.Length } | Measure-Object -Maximum).Maximum
    $maxLoc  = ($Frames | Where-Object { $_.Location -ne "" } | ForEach-Object { $_.Location.Length } | Measure-Object -Maximum).Maximum
    $maxPath = ($Frames | Where-Object { $_.ScriptName   -ne "" } | ForEach-Object { $_.ScriptName.Length } | Measure-Object -Maximum).Maximum
    #$maxLine = ($Frames | Where-Object { $null -ne $_.ScriptLineNumber } | ForEach-Object { $_.ScriptLineNumber.ToString().Length } | Measure-Object -Maximum).Maximum

    $widthFcn  = if ($script:CallStack_MaxFcnWidth  -gt 0) { [Math]::Min($maxFcn,  $script:CallStack_MaxFcnWidth)  } else { $maxFcn }
    $widthLoc  = if ($script:CallStack_MaxLocWidth -gt 0) { [Math]::Min($maxLoc, $script:CallStack_MaxLocWidth) } else { $maxLoc }
    $widthPath  = if ($script:CallStack_MaxPathWidth  -gt 0) { [Math]::Min($maxPath,  $script:CallStack_MaxPathWidth)  } else { $maxPath }
    #$widthLine = if ($script:CallStack_MaxLineWidth -gt 0) { [Math]::Min($maxLine, $script:CallStack_MaxLineWidth) } else { $maxLine }
 
    $lines = @()

    # Add column headers
    $padFcn    = Get-PaddedText -Text "Function"  -Width $widthFcn
    $padLoc    = Get-PaddedText -Text "Location"  -Width $widthLoc
    $padScript = Get-PaddedText -Text "Full Path" -Width $widthPath
    #$padLine   = Get-PaddedText -Text $line     -Width $widthLine   -Align "center"
    $lines += "[#] $padFcn    $padLoc    $padScript"

    for ($i = 0; $i -lt $Frames.Count; $i++) {
        $frame = $Frames[$i]
        if ($frame) {
            $fcn    = if ($null -ne $frame.FunctionName)        { $frame.FunctionName }     else { " " }
            $file   = if ($null -ne $frame.Location)            { $frame.Location }         else { " " }
            $script = if ($null -ne $frame.ScriptName)          { $frame.ScriptName }       else { " " }
            #$line   = if ($null -ne $frame.ScriptLineNumber)    { $frame.ScriptLineNumber } else { " " }

            $padFcn     = Get-PaddedText -Text $fcn      -Width $widthFcn
            $padLoc     = Get-PaddedText -Text $file     -Width $widthLoc
            $padScript  = Get-PaddedText -Text $script   -Width $widthPath
            #$padLine   = Get-PaddedText -Text $line     -Width $widthLine   -Align "center"
            $lines += "[$i] $padFcn    $padLoc    $padScript"
        }
    }
    $callStackStr = ($lines -join "`n")
    return $callStackStr
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
        Log -Info "$baseName $(Format-ToString($Global:RemainingArgs))"
        (& $baseName @Global:RemainingArgs)
    } else {
        Log -Err "No function named '$baseName' found to match script entry point."
    }
} else {
    Log -Warn "Unexpected execution context: $($MyInvocation.MyCommand.Path)"
}
#endregion   Execution Guard / Main Entrypoint
# ==========================================================================================

#endregion

