
#Write-Host "Loading Format-Utils.ps1"


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


#___________________________________________________________________________________
#region 	*** PowerShell Block Guard to prevent a section of code from being read multiple times 
if (-not $Global:Included_Format_Utils_Block) { 
    $Global:Included_Format_Utils_Block = $true

    . "$Script:PSRoot\Scripts\DevUtils\Logging.ps1"

} 
# Move this and endregion to end-point of code to guard
#endregion	end of guard

if (-not $script:PadText_MinTextWidth) { $script:PadText_MinTextWidth = 5  }
if (-not $Global:Empty_Hashtable) { Set-Variable -Name Empty_Hashtable -Value "(empty hashtable)" -Scope Global -Option ReadOnly }
if (-not $Global:Quote) { $Global:Quote = ([char]0x22) }

#==============================================================
#region     Function:  Format-ToString
<#
.SYNOPSIS
    Returns a string representation of an object, with special handling for null, arrays, hashtables, and objects.

.DESCRIPTION
    This function converts an object to its string representation. It handles various types of objects,
    including null values, arrays, hashtables, and objects, providing a readable string format for each type.
    The function supports optional parameters for customizing the output format, including labels, delimiters,
    and indentation.

.PARAMETER Obj
    The object to convert.

.PARAMETER Label
    Optional label to prepend to the output.

.PARAMETER FieldDelimiter
    Separator between key-value pairs (default is "; ").

.PARAMETER RecordDelimiter
    Separator between records (default is newline).

.PARAMETER Separator
    Separator between key and value (default is "=").

.PARAMETER Indent
    Indentation level for pretty printing (default is 0).

.PARAMETER IndentIncrement
    Amount of indentation added for nested structures (default is 4).

.PARAMETER Pretty
    If set, outputs one key-value pair per line for hashtables and arrays.

.OUTPUTS
    [string] Formatted string representation of the input.

.EXAMPLE
    $nullValue = $null
    $result = Format-ToString -Obj $nullValue
    Write-Host $result
    # Output: (null)

.EXAMPLE
    $stringValue = "Hello, World!"
    $result = Format-ToString -Obj $stringValue
    Write-Host $result
    # Output: "Hello, World!"

.EXAMPLE
    $arrayValue = @(1, 2, 3)
    $result = Format-ToString -Obj $arrayValue
    Write-Host $result
    # Output: [ 1, 2, 3 ]

.EXAMPLE
    $hashTableValue = @{ Name = "John"; Age = 30 }
    $result = Format-ToString -Obj $hashTableValue
    Write-Host $result
    # Output: @{ Name="John"; Age=30 }

.EXAMPLE
    $hashTableValue = @{ Name = "John"; Age = 30 }
    $result = Format-ToString -Obj $hashTableValue -Pretty
    Write-Host $result
    # Output:
    # @{
    #     Name="John"
    #     Age=30
    # }

.EXAMPLE
    $objectValue = New-Object PSObject -Property @{ Name = "John"; Age = 30 }
    $result = Format-ToString -Obj $objectValue
    Write-Host $result
    # Output: { Name="John"; Age=30 }

.EXAMPLE
    $objectValue = New-Object PSObject -Property @{ Name = "John"; Age = 30 }
    $result = Format-ToString -Obj $objectValue -Pretty
    Write-Host $result
    # Output:
    # {
    #     Name="John"
    #     Age=30
    # }

.EXAMPLE
    $nestedValue = @{
        Name = "John"
        Age = 30
        Address = @{
            Street = "123 Main St"
            City = "Anytown"
        }
    }
    $result = Format-ToString -Obj $nestedValue
    Write-Host $result
    # Output: @{ Name="John"; Age=30; Address=@{ Street="123 Main St"; City="Anytown" } }

.EXAMPLE
    $nestedValue = @{
        Name = "John"
        Age = 30
        Address = @{
            Street = "123 Main St"
            City = "Anytown"
        }
    }
    $result = Format-ToString -Obj $nestedValue -Pretty
    Write-Host $result
    # Output:
    # @{
    #     Name="John"
    #     Age=30
    #     Address=@{
    #         Street="123 Main St"
    #         City="Anytown"
    #     }
    # }

#>
#==============================================================
function Format-ToString {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        $Obj,

        [string]$Label = "",
        [string]$FieldDelimiter = "; ",
        [string]$RecordDelimiter = "`n",
        [string]$Separator = "=",
        [int]$Indent = 0,
        [int]$IndentIncrement = 4,
        [switch]$Pretty
    )

    $result = ""

    if ($null -eq $Obj) {
        $result = "(null)"

    } elseif ($Obj -is [string]) {
        $result = ('"' + $($Obj) + '"')

    } elseif ($Obj -is [array] ) {
        If ($Obj.Count -gt 0) {
            $result = _FormatArray -Array $Obj -FieldDelimiter $FieldDelimiter -RecordDelimiter $RecordDelimiter -Separator $Separator -Indent $Indent -IndentIncrement $IndentIncrement -Pretty:$Pretty
        }

    } elseif ($Obj -is [hashtable]) {
        if ($Obj.Count -gt 0) {
            $result = _FormatHashtable -Table $Obj -Label $Label -FieldDelimiter $FieldDelimiter -RecordDelimiter $RecordDelimiter -Separator $Separator -Indent $Indent -IndentIncrement $IndentIncrement -Pretty:$Pretty
        }

    } else {
        # Check if the object has a ToString method
        $toStringMethod = $Obj | Get-Member -Name "ToString" -MemberType Method -ErrorAction SilentlyContinue
        if ($toStringMethod) {
            $result = $Obj.ToString()
        } 
        
        if ($result -eq "" -and $Obj -is [object]) {
            $properties = $Obj | Get-Member -MemberType Property, NoteProperty | Where-Object { $_.MemberType -in @('Property', 'NoteProperty') }
            if ($properties -and $properties.Count -gt 0) {
                $entries = @()
                foreach ($property in $properties | Sort-Object Name) {
                    $propName = $property.Name
                    $propValue = $Obj.$propName
                    $val = Format-ToString -Obj $propValue -FieldDelimiter $FieldDelimiter -RecordDelimiter $RecordDelimiter -Separator $Separator -Indent ($Indent + $IndentIncrement) -IndentIncrement $IndentIncrement -Pretty:$Pretty
                    $entries += "$propName$Separator$val"
                }
                $result = "{ " + ($entries -join $FieldDelimiter) + " }"
            } else {
                # Fallback to the type name if no properties are found
                $result = $Obj.GetType().FullName
            }
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


function _FormatArray {
    param (
        [Parameter(Mandatory)] [object[]]$Array,
        [string]$FieldDelimiter = ", ",
        [string]$RecordDelimiter = "`n",
        [string]$Separator = "=",
        [int]$Indent = 0,
        [int]$IndentIncrement = 4,
        [switch]$Pretty
    )

    $indentStr = ' ' * $Indent
    $result = @()
    foreach ($item in $Array) {
        if ($null -eq $item) {
            $result += "$indentStr(null)"
        }
        elseif ($item -is [System.Collections.IDictionary]) {
            $nested = _FormatHashtable -Table $item -FieldDelimiter $FieldDelimiter -RecordDelimiter $RecordDelimiter -Separator $Separator -Indent ($Indent + $IndentIncrement) -IndentIncrement $IndentIncrement -Pretty:$Pretty
            $result += "$indentStr$nested"
        }
        elseif ($item -is [System.Collections.IEnumerable] -and -not ($item -is [string])) {
            $nested = _FormatArray -Array $item -FieldDelimiter $FieldDelimiter -RecordDelimiter $RecordDelimiter -Separator $Separator -Indent ($Indent + $IndentIncrement) -IndentIncrement $IndentIncrement -Pretty:$Pretty
            $result += "$indentStr$nested"
        }
        elseif ($item -is [object]) {
            $formattedItem = Format-ToString -Obj $item -FieldDelimiter $FieldDelimiter -RecordDelimiter $RecordDelimiter -Separator $Separator -Indent ($Indent + $IndentIncrement) -IndentIncrement $IndentIncrement -Pretty:$Pretty
            $result += "$indentStr$formattedItem"
        }
        else {
            $result += "$indentStr$item"
        }
    }
    $output = "[ " + ($result -join $FieldDelimiter) + " ]"
    return $output
}


function _FormatHashtable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Table,

        [string]$Label = "",
        [string]$FieldDelimiter = "; ",
        [string]$RecordDelimiter = "`n",
        [string]$Separator = "=",
        [int]$Indent = 0,
        [int]$IndentIncrement = 4,
        [switch]$Pretty
    )

    $indentStr = ' ' * $Indent
    $output = ""

    if ($Table.Count -eq 0) {
        if ($Label) { $output = "$($Label): (empty hashtable)" }
        else { $output = "(empty hashtable)"}
    }
    else {
        if ($Pretty) {
            $FieldDelimiter = $RecordDelimiter
        }

        $pairs = foreach ($entry in $Table.GetEnumerator() | Sort-Object Key) {
            $key = $entry.Key.ToString()
            $val = Format-ToString -Obj $entry.Value -FieldDelimiter $FieldDelimiter -RecordDelimiter $RecordDelimiter -Separator $Separator -Indent ($Indent + $IndentIncrement) -IndentIncrement $IndentIncrement -Pretty:$Pretty
            "$indentStr$($key)$($Separator)$($val)"
        }

        $output = $pairs -join $FieldDelimiter

        if ($Label) {
            $output = "$($Label):`n@{ $output }"
        } else {
            $output = "@{ $output }"
        }
    }
    return $output
}