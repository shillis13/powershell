
Write-Host "Loading Format-Utils.ps1"

# Imports and Dot Sources
# "$Global:PSRoot/Scripts/DevUtils/Logging.ps1"
if ($Global:PSRoot) {
    . "$Global:PSRoot/Scripts/DevUtils/Logging.ps1"
}
else {
    Write-Error "Global:PSRoot not found, resorting to PSScriptRoot."
    . "$PSScriptRoot/../DevUtils/Logging.ps1"
}

#___________________________________________________________________________________
#region 	*** PowerShell Block Guard to prevent a section of code from being read multiple times 
if (-not (Get-Variable -Name Included_Format-Utils_Block -Scope Global -ErrorAction SilentlyContinue)) { 
    Set-Variable -Name Included_Format-Utils_Block -Scope Global -Value $true

    Set-Variable -Name quote -Value ([char]0x22) -Scope Global -Option ReadOnly
    
    #Set-Variable -Name PadText_MinTextWidth -Value 5 -Scope Global -Option ReadOnly

} # Move this and endregion to end-point of code to guard
#endregion	end of guard

if (-not $script:PadText_MinTextWidth) { $script:PadText_MinTextWidth = 5  }


#==============================================================
#region     Function:  Format-Hashtable
<#
.SYNOPSIS
    Returns a formatted string representation of a hashtable.

.PARAMETER Table
    The hashtable to format.

.PARAMETER Label
    Optional label to prepend to the output.

.PARAMETER Delimiter
    Separator between key-value pairs (default = "; ")

.PARAMETER Separator
    Separator between key and value (default = "=")

.PARAMETER Pretty
    If set, outputs one key-value pair per line.

.PARAMETER NoColor
    If set, disables colored output (Write-Host-based coloring).

.OUTPUTS
    [string] Formatted hashtable string
#>
#==============================================================
function Format-Hashtable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Table,

        [string]$Label = "",

        [string]$Delimiter = "; ",

        [string]$Separator = "=",

        [switch]$Pretty
    )

    $output = ""

    if ($Table.Count -eq 0) {
        if ($Label) { $output = "$($Label): (empty hashtable)" }
        else { $output = "(empty hashtable)"}
        #return if ($Label) { "$($Label): (empty hashtable)" } else { "(empty hashtable)" }
    }
        else {
        if ($Pretty) {
            $Delimiter = "`n"
        }

        #$pairs = $Table.GetEnumerator() | Sort-Object Key | ForEach-Object {
        $pairs = foreach ($entry in $Table.GetEnumerator() | Sort-Object Key) {
            $key = $entry.Key.ToString()
            $val = $entry.Value.ToString()
            "$($key)$($Separator)$($val)"
        }

        $output = $pairs -join $Delimiter

        if ($Label) {
            #return "$($Label): `n$output"
            $output = "$($Label): `n$($output)"
        }
    }
    return $output
}
#endregion
#==============================================================


#==============================================================
#region     function:  Format-Array
function Format-Array {
    param (
        [Parameter(Mandatory)] [object[]]$Array,
        [int]$Indent = 0
    )

    $indentStr = ' ' * $Indent
    $result = @()
    foreach ($item in $Array) {
        if ($null -eq $item) {
            $result += "$indentStr(null)"
        }
        elseif ($item -is [System.Collections.IDictionary]) {
            $result += "$indentStr@{"
            foreach ($k in $item.Keys) {
                $val = $item[$k]
                if ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) {
                    $nested = Format-Array -Array $val -Indent ($Indent + 4)
                    $result += "$indentStr    $k = [`n$nested`n$indentStr    ]"
                } else {
                    $result += "$indentStr    $k = $val"
                }
            }
            $result += "$indentStr}"
        }
        elseif ($item -is [System.Collections.IEnumerable] -and -not ($item -is [string])) {
            $nested = Format-Array -Array $item -Indent ($Indent + 4)
            $result += "$indentStr@(`n$nested`n$indentStr)"
        }
        else {
            $result += "$indentStr$item"
        }
    }
    $output = ($result -join "`n")
    return $output
}
#endregion
#==============================================================


#==============================================================
#region     Function:  Format-ToString
<#
.SYNOPSIS
    Returns a string representation of an object, with special handling for null, arrays, and hashtables.

.PARAMETER Obj
    The object to convert.

.OUTPUTS
    [string] Formatted string representation of the input.
#>
#==============================================================
function Format-ToString {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        $Obj,

        [string]$FormatMethod
    )

    $result = ""

    if ($null -eq $Obj) {
        $result = "(null)"

    } elseif ($Obj -is [string]) {
        $result = ('"' + $($Obj) + '"')

    } elseif ($Obj -is [array]) {
        $parts = @()

        foreach ($item in $Obj) {
            $parts += Format-ToString -Obj $item -FormatMethod $FormatMethod
        }
        $result = "[ " + ($parts -join ", ") + " ]"

    } elseif ($Obj -is [hashtable]) {
        $entries = @()
        foreach ($key in $Obj.Keys) {
            if ( $null -eq $key -or $null -eq $Obj[$key] ) {
                Log -Warn "Key[$($i)] or Obj[$($key)] is null."
            }
            else {
                $val = Format-ToString -Obj $Obj[$key] -FormatMethod $FormatMethod
                $entries += "$key = $val"
            }
        }

        $result = "@{ " + ($entries -join "; ") + " }"

    } else {
        if ($FormatMethod -and ($Obj | Get-Member -Name $FormatMethod -MemberType Properties, Methods)) {
            $value = $Obj.$FormatMethod.Invoke()
            $result = $value
        } else {
            $result = $Obj.ToString()
        }
    }

    return $result
}
#endregion
#==============================================================


function Get-PaddedText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][int]$Width,
        #[Parameter(Position = 2)]
        [ValidateSet('left', 'center', 'right')]
        [string]$Align = 'left'
    )

    if ($null -eq $Text) { $Text = "" }

    $paddedText = $Text
    if ($Width -lt $script:PadText_MinTextWidth) { $Width = $script:PadText_MinTextWidth }

    if ($Text.Length -le $Width) {
        if ($Align -eq "left") {
            $paddedText = $Text.PadRight($Width)
        }
        elseif ($Align -eq "center") {
            $totalPadding = $Width - $Text.Length
            $leftPadding = [math]::Ceiling($totalPadding / 2)
            $rightPadding = $totalPadding - $leftPadding
            $paddedText = (" " * $leftPadding) + $Text + (" " * $rightPadding)
        }
        elseif ($Align -eq "right" ) {
            $paddedText = $Text.PadLeft($Width)
        }
        else {
            Log -Warn "Unrecognized Align value: $Align."
            $paddedText = $Text.PadRight($Width)
        }
    } else {
        $half = [math]::Floor(($Width - 3) / 2)
        $start = $Text.Substring(0, $half)
        $end = $Text.Substring($Text.Length - $half)
        $paddedText = "$start...$end"
    }
    return $paddedText
}
