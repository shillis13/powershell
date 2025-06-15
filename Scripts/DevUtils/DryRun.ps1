<# ##########################################################################
.SYNOPSIS
    Dry-run control module for safe globaling execution.

.DEglobalION
    Provides a centralized, reusable way to manage dry-run behavior in globals.
    Default state is DryRun = $true, enforcing safe no-operation mode until explicitly overridden.

.NOTES

#############################################################################
#>
if ( -not ('ItemActionType' -as [type])) {
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
#>
function Set-DryRun {
    param (
        [bool]$Enabled
    )
    $global:pDryRun = $Enabled
    $global:pDryRun = $global:pDryRun
}
#endregion
#=======================================================================================


#=======================================================================================
#region     Function: Get current dry-run state
<#
.SYNOPSIS
    Gets the current dry-run state.

.RETURNS
    A boolean indicating whether dry-run mode is enabled or disabled.

.EXAMPLE
    $dryRunState = Get-DryRun
#>
function Get-DryRun {
    return $global:pDryRun
}
#endregion
#=======================================================================================



#=======================================================================================
#region     Function: Invoke-WithDryRunOverride
<#
.SYNOPSIS
    Invokes a global block temporarily overriding the dry-run mode.

.PARAMETER TemporaryState
    A boolean value indicating the temporary state of dry-run mode.

.PARAMETER globalBlock
    A script block to execute while the dry-run mode is temporarily overridden.

.EXAMPLE
    Invoke-WithDryRunOverride -TemporaryState $false -globalBlock { <script> }
#>
function Invoke-WithDryRunOverride {
    [CmdletBinding()]
    param (
        [bool]$TemporaryState,
        [globalblock]$globalBlock
    )

    $originalState = $global:pDryRun
    try {
        $global:pDryRun = $TemporaryState
        & $globalBlock
    } finally {
        $global:pDryRun = $originalState
    }
}
#endregion
#=======================================================================================

