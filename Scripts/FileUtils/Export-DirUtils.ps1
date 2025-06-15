# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

if (-not $Global:PSRoot) {
    $Global:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    Write-Host "Set Global:PSRoot = $Global:PSRoot"
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


Import-Module "$Global:PSRoot\Modules\VirtualFolderFileUtils\VirtualFolderFileUtils.psd1" -Force

# . "$env:PowerShellScripts\DevUtils\DryRun.ps1"
# . "$env:PowerShellScripts\DevUtils\Logging.ps1"
# . "$env:PowerShellScripts\DevUtils\Format-Utils.ps1"
. "$Global:PSRoot\Scripts\FileUtils\Zip-Contents.ps1"
. "$Global:PSRoot\Scripts\OutlookUtils\Outlook.Interface.ps1"

#___________________________________________________________________________________
#region 	*** PowerShell Block Guard to prevent a section of code from being read multiple times 
if (-not (Get-Variable -Name Included_Export-DirUtils_Block -Scope Global -ErrorAction SilentlyContinue)) { 
    Set-Variable -Name Included_Export-DirUtils_Block -Scope Global -Value $true
    
    Set-Variable -Name DefaultExcludeList -Scope Global -Value  @('Temp', 'Archive', 'HelpFiles', 'MSAL', 'Selenium', 'Microsoft')

    Set-Variable -Name DefaultRenameExtsList -Scope Global -Value  @{ ps1 = 'ps1.txt'; psm1 = 'psm1.txt' ; bat = 'bat.txt'; py = 'py.txt'  } 
} # Move this and endregion to end-point of code to guard
#endregion	end of guard


#======================================================================================
#region      Function : Export-CleanDir
# This function copies and sanitizes script files from a source directory for safe emailing, optionally renaming extensions and compressing the result.
#
# Usage:
# Run the function with the following parameters:
# -SourceDir        (string): Path to the source directory containing scripts to process.
# -DestDir          (string): Path to the output directory where sanitized files will be written.
# -Exclude  (string[]): Wildcard patterns for files or directories to exclude.
# -RenExt (hashtable): Hashtable mapping restricted extensions (e.g., ".ps1") to neutral ones (e.g., ".ps1_" or ".txt").
# -Zip        (string): Optional path to output a compressed ZIP file of the sanitized folder.
# Example Execution:
# Export-CleanDir -SourceDir ".\Scripts" -DestDir ".\Outbox" -RenExt @{ ".ps1"=".txt"; ".py"=".py_" } -Zip ".\Outbox.zip"
#======================================================================================
function Export-CleanDir {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$SourceDir,

        [Parameter(Mandatory)]
        [string]$DestDir,

        [string[]]$Excludes = $null,

        [hashtable]$RenameExts = $null,

        [switch]$Zip,
        [string]$ZipFile = "",

        [switch]$Email,
        [string]$EmailAddr = "",
        [string]$EmailSubject = "",
        
        [switch]$Exec,
        [switch]$NI
    )

    $renExtStr = if( $RenameExts -and $RenameExts.Count -gt 0) { Format-Hashtable -Table $RenameExts } else { "" }
    Log -Info ": -SourceDir $SourceDir -DestDir $DestDir -RenExt $renExtStr -Excludes $Excludes -Zip:$Zip -ZipFile $ZipFile -Email:$Email -EmailAddr $EmailAddr -EmailSubject $EmailSubject -Exec:$Exec"
    if ($Exec) { Set-DryRun $false }

    if (-not (Test-Path $SourceDir)) {
        throw "Source directory '$SourceDir' does not exist."
    }

    $srcInDestDirname = Split-Path -Path $SourceDir -Leaf
    $destRootDirPath = Format-Path (Join-Path $DestDir $srcInDestDirname)  

    # Delete existing destination target
    if (Test-Path $destRootDirPath) {
        if (Get-DryRun) {
            Log -DryRun "Removing existing destination directory: $destRootDirPath"
        }
        else {
            Remove-Item -Recurse -Force -Path $destRootDirPath
        }
    }

    # Create new destination directory and the src directory underneath
    if (-not (Get-DryRun)) {
        Log -Dbg "Creating destination directory: $destRootDirPath"
        New-Item -Path $destRootDirPath -ItemType Directory -Force | Out-Null
    } else {
        Log -DryRun "Create destination directory: $destRootDirPath"
    }

    # Step 1: Read source structure as VirtualFolder hierarchy with SourcePath links
    $rootSpecDir = Read-FolderHierarchy -FolderPath $SourceDir -ReadContents:$false

    if (-not $rootSpecDir) {
        $msg = "Read-FolderHierarchy returned null when reading $SourceDir."
        Log -Err "Throwing Exception: $msg"
        throw $msg
    }

    Log -Dbg "BEFORE FILTERING: `n$($rootSpecDir.PrintFolder($true, 4))"


    # Step 2: Apply exclusion filters
    if ($Excludes) {
        foreach ($pattern in $Excludes) {
            Log -Dbg "Evaluating $pattern as removal criteria."
            $rootSpecDir.RemoveMatches($pattern, $true, $true)
        }
    }

    # Step 3: Change file extensions as needed
    if ($RenameExts) {
        foreach ($key in $RenameExts.Keys) {
            if ($key) {
                Log -Dbg "Changing file extension $key to $($RenameExts[$key])"
                $rootSpecDir.ChangeItemExts($key, $RenameExts[$key])
            }
        }
    }

    Log -Dbg "AFTER FILTERING: `n$($rootSpecDir.PrintFolder($true, 4))"

    # Step 4: Write destination hierarchy
    # First make the top-level src directory under dest
    $action = [ItemActionType]::Copy
    Write-FolderHierarchy -DestFolderPath $destRootDirPath -SrcVirtualFolder $rootSpecDir -ItemAction $action -Exec:$Exec

    # Step 5: Optionally zip the destination
    if ($null -ne $ZipFile -and $ZipFile -ne "") {
        $Zip = $true
    }

    if ($Zip) { 

        # Compress directory into ZipFile
        $ZipFilePath = Compress-Contents -SourcePaths @($destRootDirPath) -TargetDir $DestDir -NI:$NI -Exec:$Exec
        Log -Info "Zipped exported directory $destRootDirPath to $ZipFilePath"
    
        if ($ZipFilePath -and $Email) {

            # Ensure an email address was specified
            if (-not $EmailAddr) { 
                $msg = "No email address provided $EmailAddr."
                Log -Err "Throwing Exception: $msg"
                Throw $msg
            }
 
            # Change $ZipFile's extension to piz
            $newZipFilePath = $ZipFilePath
            if ([System.IO.Path]::GetExtension($ZipFilePath) -eq ".zip" -or $ZipFilePath.Extension -eq ".zip") {
                $newZipFilePath = [System.IO.Path]::ChangeExtension($ZipFilePath, ".piz")
                Move-Item -Path $ZipFilePath -Destination $newZipFilePath -Force
            }
            
            # If no EmailSubject specified, use the name of the ZipFile
            if (-not $EmailSubject) { 
                $EmailSubject = Split-Path $newZipFilePath -Leaf
            }
           
            $emailArgs = @{
                To          = $EmailAddr
                Subject     = $EmailSubject
                Body        = "Email Body"
                SendNow     = $false
                Attachments =@($newZipFilePath)
            }

            if (-not (Get-DryRun)) {
                #New-OutlookEmail -To $EmailAddr -Subject $EmailSubject -Body "Email Body" -Attachments @($($originalZipFile))
                Log -Info ("New-OutlookEmail " + (Format-Hashtable -Table $emailArgs))
                New-OutlookEmail @emailArgs
            }
            else {
                #Log -DryRun "Sending Email: -To $EmailAddr -Subject $EmailSubject -Body 'Email Body' -Attachments = @($($originalZipFile))" #-SendNow
                Log -DryRun ("New-OutlookEmail " + (Format-HashTable -Table $emailArgs )) #-SendNow
            }

            # Change $ZipFile's extension back to zip
            if ([System.IO.Path]::GetExtension($ZipFilePath) -eq ".piz") {
                $newZipFilePath = [System.IO.Path]::ChangeExtension($ZipFilePath, ".zip")
                Move-Item -Path $ZipFilePath -Destination $newZipFilePath -Force
            }

        }
    }
    Log -Info "Export-CleanDir(): Export completed."
}
#endregion
#======================================================================================

#======================================================================================
#region      Function : Export-CleanDir
#
#
# @description
#   This function copies and sanitizes script files from a source directory for safe emailing,
#   optionally renaming extensions, compressing the result, and emailing the compressed file.
#
# @param SrcDir (string) The source directory containing scripts to process. Default is "$env:HOME\Documents\WindowsPowerShell".
# @param DstDir (string) The destination directory where sanitized files will be written. Default is "$env:HOMEPATH\Downloads".
# @param Excl (string[]) Wildcard patterns for files or directories to exclude. Default is @('Temp', 'Archive', 'HelpFiles', 'MSAL', 'Selenium').
# @param Zip (switch) Optional switch to compress the result into a zip file.
# @param ZipFile (string) Optional path to output a compressed ZIP file of the sanitized folder.
# @param Email (switch) Optional switch to email the compressed file.
# @param EmailAddr (string) The email address to send the compressed file to.
# @param EmailSubject (string) The subject of the email.
# @param Exec (switch) Optional switch to execute the function.
#
# @example
# Copy-CleanZipDir -SrcDir "C:\Scripts" -DstDir "C:\Outbox" -Excl @('Temp', 'Archive') -Zip -ZipFile "C:\Outbox\Scripts.zip" -Email -EmailAddr "example@example.com" -EmailSubject "Scripts Backup" -Exec
#
# =======================================================================
function Copy-CleanZipDir {
    param(
        [string]$SrcDir = "$Global:PSRoot",
        [string]$DstDir = "",
        [string[]]$ExcludeList = $null,
        [hashtable]$RenameExtsList = $null,
        [switch]$Zip,
        [string]$ZipFile,
        [switch]$Email,
        [string]$EmailAddr = "",
        [string]$EmailSubject = "",
        [switch]$Exec,
        [switch]$Interactive
    )
    if ($null -eq $DstDir -or $DstDir -eq "") {
        $DstDir = "$env:HOMEPATH\Downloads"
    }
    #Set-LogLevel $LogDebug

    $argsList = @{
        SourceDir   = $SrcDir
        DestDir     = $DstDir
    }

    # Make ExcludeList empty to not have any Excludes
    if ($null -eq $ExcludeList ) { 
        if ($Global:DefaultExcludeList) {
            $ExcludeList =  $Global:DefaultExcludeList 
        }
    }
    if ( $ExcludeList -and ($($ExcludeList.Count) -gt 0)) {
        $argsList['Excludes'] = $ExcludeList
    }

    # Make RenameExtsList empty to not have any Exts renamed
    if ($null -eq $RenameExtsList ) { 
        if ($Global:DefaultRenameExtsList) {
            $RenameExtsList = $DefaultRenameExtsList 
        }
    }
    if ($RenameExtsList -and ($($RenameExtsList.Count) -gt 0)) {
        $argsList['RenameExts'] = $RenameExtsList
    }

    if ($Zip -and (-not $ZipFile)) {
        $ZipFile = Split-Path -Path $SrcDir -Leaf
        $zipFile = "$($ZipFile).piz"
        $ZipFile = Join-Path $DstDir $ZipFile

        $argsList['Zip']     = $Zip
        $argsList['ZipFile'] = $ZipFile
    }

    if ($Zip -and $Email) {
        $argsList['Email']  = $Email

        if (-not $EmailAddr) { $EmailAddr = $global:PersonalEmail }
        $argsList['EmailAddr'] = $EmailAddr

    }

    if ($Exec) { $argsList['Exec'] = $Exec }
    if (-not $Interactive) { $argsList['NI'] = $true }

    #Log -Info "Export-CleanDir -SourceDir $SrcDir -DestDir $DstDir -Exclude $Excl -Zip:$Zip -ZipFile $ZipFile -Exec:$Exec"
    #Export-CleanDir -SourceDir $SrcDir -DestDir $DstDir -Exclude $Excl -Zip:$Zip -ZipFile $ZipFile -Exec:$Exec
    #$cmd = "& Export-CleanDir " + ($argsList -join ' ')
    #Log -Info "Invoke-Expression $cmd"
    #Invoke-Expression $cmd
    Log -Dbg ("Export-CleanDir " + (Format-Hashtable -Table $argsList ))
    Export-CleanDir @argsList
}
#endregion
#======================================================================================


#======================================================================================
# "Main" block - runs only if executed directly
#======================================================================================
#==================================================================================
# Detect if the script is being run directly or invoked
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    if ($PSBoundParameters.ContainsKey("Help") -or $PSBoundParameters.ContainsKey("?")) {
        Get-Help -Detailed
        exit
    }
}
# Main Execution Block
elseif ($MyInvocation.InvocationName -eq '.') {
    # Script is being sourced, do not execute the function
    Log -Dbg 'Script is being sourced, do not execute.'
    return
}
elseif ($MyInvocation.MyCommand.Path -eq $PSCommandPath) {
    # Script is being executed directly
    Log -Dbg "Copy-CleanZipDir (Format-Hashtable($remainingArgs))"
    Copy-CleanZipDir @remainingArgs
}
else {
    Log -Warn 'Unexpected Context: $($MyInvocation.MyCommand.Path) -ne $PSCommandPath'
}
#==================================================================================
