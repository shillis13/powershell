
#Write-Host "Loading Compare-Utils.ps1"

# Imports and Dot Sources
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
        
if (-not $Global:Included_Format_Utils_Block) { 
    $Global:Included_Format_Utils_Block = $true

    . "$Script:PSRoot\Scripts\DevUtils\Logging.ps1"
} 

#======================================================================================
#region   Function: Compare-SortedCollections
<#
.SYNOPSIS
    Compares two object collections by sorting and pairwise equality using a custom comparer.

.PARAMETER ContextLabel
    Label used for logging context (e.g., "File", "SubDir").

.PARAMETER ListA
    First list of objects to compare.

.PARAMETER ListB
    Second list of objects to compare.

.PARAMETER SortKey
    ScriptBlock that returns the key to sort and align objects.

.PARAMETER Comparer
    ScriptBlock that returns $true if two aligned objects are considered equal.

.PARAMETER FullEvaluation
    If $true, evaluates all entries and returns $false if any differ; otherwise exits on first mismatch.

.OUTPUTS
    [bool] $true if all elements match by the comparer after sort alignment; otherwise $false.
#>
function Compare-SortedCollections {
    param (
        [Parameter(Mandatory)]
        [string] $ContextLabel,

        [Parameter(Mandatory)]
        [object[]] $ListA,

        [Parameter(Mandatory)]
        [object[]] $ListB,

        [Parameter(Mandatory)]
        [scriptblock] $SortKey,

        [Parameter(Mandatory)]
        [scriptblock] $Comparer,

        [bool] $FullEvaluation = $false
    )
    $isEqual = $true

    if ($null -eq $ListA -or $null -eq $ListB) {
        Log -Warn "ListA or ListB are null"
        $isEqual = $false
    }
    else {   
        $sortedA = $ListA | Sort-Object -Property $SortKey
        $sortedB = $ListB | Sort-Object -Property $SortKey

        if ($sortedA.Count -ne $sortedB.Count) {
            Log -Dbg "$ContextLabel count mismatch: $($sortedA.Count) vs $($sortedB.Count)"
            return $false
        }

        $count = $sortedA.Count
        for ($i = 0; $i -lt $count; $i++) {
            $a = $sortedA[$i]
            $b = $sortedB[$i]

            if ($null -eq $a -or $null -eq $b) {
                Log -Warn "One of \$a or \$b is null."
                $isEqual = false
            }
            elseif (-not (& $Comparer $a $b )) {
                Log -Dbg "$ContextLabel mismatch at index $i : $($a.ToString()) vs $($b.ToString())"
                $isEqual = $false
                break
            }
            else {
                $isEqual = $true
            }
        }
    }

    return $isEqual
}
#endregion
#=======================================================================================

#======================================================================================
#region   Function: Compare-Equals
<#
.SYNOPSIS
    Performs a deep equality comparison between two objects, including arrays and hashtables.
.DESCRIPTION
    Compares two inputs ($Lhs and $Rhs) by value, including nested structures like arrays
    and hashtables. Supports an optional -ComparisonMethod that can be a method or property
    name used to extract comparable identity from complex objects.
.PARAMETER Lhs
    The first object to compare.
.PARAMETER Rhs
    The second object to compare.
.PARAMETER ComparisonMethod
    Optional name of a method or property to call on each object to extract a comparison value.
.RETURNS
    [bool] True if the objects are considered equal; otherwise, false.
#>
#======================================================================================
function Compare-Equals {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)] $Lhs,                           # Left-hand side object
        [Parameter(Mandatory = $false)] $Rhs,                           # Right-hand side object
        [string]$ComparisonMethod = ""                                  # Optional property/method to use for comparison
    )

    $isEqual = $false  # Initialize result to false

    # Case 1: Both values are null
    if ($null -eq $Lhs -and $null -eq $Rhs) {
        $isEqual = $true
    }
    # Case 2: Only one value is null
    elseif ($null -eq $Lhs -or $null -eq $Rhs) {
        $isEqual = $false
    }
    # Case 3: Type mismatch
    elseif ($Lhs.GetType() -ne $Rhs.GetType()) {
        $isEqual = $false
    }
    # Case 4: Dictionary (hashtable) comparison
    elseif ($Lhs -is [System.Collections.IDictionary]) {
        $lhsKeys = $Lhs.Keys
        $rhsKeys = $Rhs.Keys

        if ($lhsKeys.Count -ne $rhsKeys.Count) {
            $isEqual = $false
        } else {
            $keyMismatch = $false
            foreach ($key in $lhsKeys) {
                if (-not $rhsKeys.Contains($key)) {
                    $keyMismatch = $true
                    break
                }
                # Recursive comparison of each key's value
                if (-not (Compare-Equals -Lhs $Lhs[$key] -Rhs $Rhs[$key] -ComparisonMethod $ComparisonMethod)) {
                    $keyMismatch = $true
                    break
                }
            }
            $isEqual = -not $keyMismatch
        }
    }
    # Case 5: Enumerable (arrays/lists) but not strings
    elseif ($Lhs -is [System.Collections.IEnumerable] -and -not ($Lhs -is [string])) {
        $lhsList = @($Lhs)
        $rhsList = @($Rhs)
        if ($lhsList.Count -ne $rhsList.Count) {
            $isEqual = $false
        } else {
            $listMismatch = $false
            for ($i = 0; $i -lt $lhsList.Count; $i++) {
                if (-not (Compare-Equals -Lhs $lhsList[$i] -Rhs $rhsList[$i] -ComparisonMethod $ComparisonMethod)) {
                    $listMismatch = $true
                    break
                }
            }
            $isEqual = -not $listMismatch
        }
    }
    # Case 6: Comparison using a specific method or property
    elseif ($ComparisonMethod) {
        $lhsProp = $Lhs.PSObject.Properties[$ComparisonMethod]
        $rhsProp = $Rhs.PSObject.Properties[$ComparisonMethod]

        if ($lhsProp -and $rhsProp) {
            $lhsVal = $lhsProp.Value
            $rhsVal = $rhsProp.Value

            if ($lhsVal -is [scriptblock]) { $lhsVal = & $lhsVal }     # Invoke scriptblock if needed
            if ($rhsVal -is [scriptblock]) { $rhsVal = & $rhsVal }

            $isEqual = ($lhsVal -eq $rhsVal)
        } else {
            $isEqual = $false
        }
    }
    # Case 7: Default comparison using -eq
    else {
        $isEqual = ($Lhs -eq $Rhs)
    }

    return $isEqual
}
#endregion
#======================================================================================
