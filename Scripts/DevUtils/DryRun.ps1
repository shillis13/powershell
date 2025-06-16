<# ##########################################################################
 enum ItemActionType {
        UnknownAction
        NoAction
        Move
        Copy
        Write
        Delete
        Clear
        Rename
        Touch

    } 
}


#___________________________________________________________________________________
#region 	*** PowerShell Block Guard to prevent multiple includes of a file
if (-not (Get-Variable -Name Included_DryRun_Block -Scope Global -ErrorAction SilentlyContinue)) {
    Set-Variable -Name Included_DryRun_Block -Scope Global -Value true
    If (Get-Variable -Name Included_Logging_ps1 -Scope Global -ErrorAction SilentlyContinue) { Log -Dbg 'Reading code block: DryRun_Block' }
    else { Write-Host 'Reading code block: DryRun_Block' }

   
    # Initialize Private DryRun flag
    $global:pDryRun = $true

}
# Move this and endregion to end-point of code to guard
#endregion	end of guard


#=======================================================================================
#region     Function: Set dry-run mode 
<#
.SYNOPSIS
    Sets the dry-run mode globally.

.PARAMETER Enabled
    A boolean value indicating whether to enable or disable dry-run mode.

.EXAMPLE
    Set-DryRun -Enabled $true
# ==================================================
#region               Function: Set-DryRun
<#
.SYNOPSIS
    Sets the dry-run mode globally.

.PARAMETER Enabled
    Enable or disable dry-run mode.

.OUTPUTS
    None

.EXAMPLE
    Set-DryRun -Enabled $true

.NOTES
    Maintains global:pDryRun state.
#>
function Set-DryRun {
    [CmdletBinding()]
    param (
        [bool]$Enabled
    )
    $global:pDryRun = $Enabled
    $global:pDryRun = $global:pDryRun
}
#endregion
# ==================================================
#=======================================================================================


# ==================================================
#region               Function: Get-DryRun
<#
.SYNOPSIS
    Gets the current dry-run state.

.OUTPUTS
    [bool]

.EXAMPLE
    $state = Get-DryRun

.NOTES
    Returns the global:pDryRun setting.
#>
function Get-DryRun {
    [CmdletBinding()]
    param()
    return $global:pDryRun
}
#endregion
# ==================================================


# ==================================================
#region               Function: Invoke-WithDryRunOverride
<#
.SYNOPSIS
    Invokes a script block temporarily overriding dry-run mode.

.PARAMETER TemporaryState
    Temporary dry-run state to use.

.PARAMETER GlobalBlock
    Script block to execute.

.OUTPUTS
    None

.EXAMPLE
    Invoke-WithDryRunOverride -TemporaryState $false -GlobalBlock { Do-Stuff }
#>
function Invoke-WithDryRunOverride {
    [CmdletBinding()]
    param (
        [bool]$TemporaryState,
        [scriptblock]$GlobalBlock
    )
    $originalState = $global:pDryRun
    try {
        $global:pDryRun = $TemporaryState
        & $GlobalBlock
    } finally {
        $global:pDryRun = $originalState
    }
}
#endregion
# ==================================================
#=======================================================================================

