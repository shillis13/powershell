# RepeatedlyDownload-SharePointFile.ps1

# Global variables
# $Script:Url = "https://gdo365.sharepoint.us/:p:/r/sites/ENG-ORLTCH/Repository/Management/Program Management/Program Management Reviews/CPM Plus - McLaughlin/2025/01 - January/CPM Plus Program Review - Jan 2025.pptx?d=wd9f56e7a630d477b8ec7d1282f593c4c&csf=1&web=1&e=qDBZKw"
$Script:Url = 'https://gdo365.sharepoint.us/sites/ENG-ORLTCH/_layouts/15/download.aspx?UniqueId=d9f56e7a%2D630d%2D477b%2D8ec7%2Dd1282f593c4c'

$Script:DownloadTotalWaitSeconds = 300
$Script:DownloadLoopWaitSeconds = 2
#$Script:MoveFileWaitSeconds = 10
#$Script:MoveFileTotalWaitSeconds = 30

$Script:Overwrite = $true

$Script:DownloadDir = "$env:USERPROFILE\Downloads"
$Script:DestDir = "$env:USERPROFILE\Downloads\DLPerfTest"
$Script:FilePattern = 'CPM Plus Program Review - Jan 2025'
$Script:DownloadFunction = 'Open-Chrome'
#$Script:DownloadFunction = "Get-SharePointFile"

# Import the Get-SharePointFile script
# . "$PSScriptRoot\Get-SharePointFile.ps1"
. "$PSScriptRoot\..\WebUtils\Open-Chrome.ps1"
. "$PSScriptRoot\..\TerminalUtils\Get-KeyPressed.ps1"


# Function to download the file and capture metrics
function Save-File {
    param (
        [string]$Url,
        [string]$DestDir,
        [switch]$Overwrite
    )

    $downloadParams = @{
        Url = $Url
    }
    #if (-not $Overwrite) {
    #    $downloadParams["DoNotPersist"] = $true
    # }

    #$downloadStartTime = Get-Date
    $processes = (& $Script:DownloadFunction @downloadParams)

    return $processes
}


function Move-Files {
    [CmdletBinding()]
    param (
        [string]$srcDir,
        [string]$dstDir,
        [string[]]$filePattern,
        [datetime]$StartDate = [datetime]::MinValue,
        [datetime]$EndDate = [datetime]::Today,
        # [int]$TOTAL_TIMEOUT = 120,
        # [int]$DELAY_SECONDS = 10,
        [switch]$Recurse,
        [switch]$Help,
        [switch]$DryRun
    )
    $filesMoved = @()

    Write-Debug 'Validating parameters...'

    # Validate input parameters
    if (-not $srcDir -or -not $dstDir -or -not $filePattern) {
        Write-Warning "Invalid parameters for Move-Files: $args"
        Write-Host  'Usage: .\Move-Files.ps1 -srcDir srcDir -dstDir dstDir -filePattern filePattern [-StartDate StartDate] [-EndDate EndDate]' # [-TOTAL_TIMEOUT TOTAL_TIMEOUT] [-DELAY_SECONDS DELAY_SECONDS]'
        Write-Host  'Example: .\Move-Files.ps1 -srcDir "C:\Users\shawn.hillis\Downloads" -dstDir "C:\Archive" -filePattern "TO24 NGIS 1.0" -filePattern "Another Pattern" -StartDate "2025-01-01" -EndDate "2025-12-31" -Recurse'
        exit
    }

    # Ensure the destination directory exists
    if (-not (Test-Path -Path $dstDir)) {
        if (-not (Get-DryRun)) {
            New-Item -ItemType Directory -Path $dstDir | Out-Null
        }
        Write-Host "Created destination directory: $dstDir" -ForegroundColor Cyan
    }

    
    # Adjust StartDate and EndDate times if only a date is specified
    if ($StartDate -ne [datetime]::MinValue -and $StartDate.Hour -eq 0 -and $StartDate.Minute -eq 0 -and $StartDate.Second -eq 0) {
        $StartDate = $StartDate.AddHours(0).AddMinutes(0).AddSeconds(1)
    }

    if ($EndDate.Hour -eq 0 -and $EndDate.Minute -eq 0 -and $EndDate.Second -eq 0) {
        $EndDate = $EndDate.AddHours(23).AddMinutes(59).AddSeconds(59)
    }


    Write-Debug 'Validated parameters.'

    $noMatchPatterns = @()

    Write-Debug "Processing patterns at $(Get-Date -Format HH:mm:ss)"

    foreach ($pattern in $filePattern) {
        $pattern = $pattern + '*'
        Write-Debug "Processing pattern '$pattern'"
        $fileFound = $false

        $files = Get-ChildItem -Path $srcDir -Filter $pattern -Recurse:$Recurse | Where-Object {
            $_.CreationTime -ge $StartDate -and $_.CreationTime -le $EndDate
        }

        foreach ($file in $files) {
            Write-Verbose "Moving file: '$($file.FullName)' to: '$dstDir'" 
            Move-Item -Path $file.FullName -Destination $dstDir -Force
            $filesMoved += $file
        }

        if (-not $fileFound) {
            Write-Warning "No files found for pattern '$pattern'"
            $noMatchPatterns += $pattern
        }
    }

    return $filesMoved
}


function Test-SharePointPerf() {
    [CmdletBinding()]
    param (
        [string]$Url = $Script:Url,
        [string]$Pattern = $Script:FilePattern
    )
    # Initialize variables
    $results = @()
    $stopDownloading = $false

    # Main loop
    while (-not $stopDownloading) {
        $processes = Save-File -Url $Script:Url -DestDir $Script:DestDir -Overwrite:$Script:Overwrite
   
        # Get the Loop start time
        $start_time = Get-Date

        Write-Host "Waiting for $Script:DownloadTotalWaitSeconds seconds or press Enter to start immediately. Press Q to stop." -ForegroundColor Cyan
        $keepWaiting = $true

        while ($elapsed_time -lt $Script:DownloadTotalWaitSeconds -and $keepWaiting) {

            $files += Move-Files -SrcDir $Script:DownloadDir -DstDir $Script:DestDir -FilePattern $Script:FilePattern -StartDate $(Get-Date -Format MM/dd/yyyy)
            $waitTask = Start-Job -ScriptBlock { Start-Sleep -Seconds $Script:DownloadLoopWaitSeconds }
                
            while (-not $waitTask.IsCompleted) {
                $pressed = Get-KeyPressed -ShowKey

                if ($pressed) {
                    if ($pressed.Key.ToLower() -eq $script:KEY_ENTER) {
                        Write-Host 'Starting next download immediately...' -ForegroundColor Cyan
                        $keepWaiting = $false
                        break
                    }
                    elseif ($pressed.Key.ToLower() -eq 'q' ) {
                        $keepWaiting = $false
                        $stopDownloading = $true
                        break
                    }
                }
            
                # Calculate elapsed time
                $elapsed_time = (New-TimeSpan -Start $start_time).TotalSeconds
                $percentComplete = ( $elapsed_time / $Script:DownloadTotalWaitSeconds) * 100
                Write-Progress -Activity "Waiting until next automatic download" -PercentComplete $percentComplete
           }
            
            # Calculate elapsed time
            $elapsed_time = (New-TimeSpan -Start $start_time).TotalSeconds

            #Write-Progress -Activity "Next automatic download" -Status "Waiting ..." -PercentComplete = ($Script:DownloadTotalWaitSeconds / $elapsed_time )
        }

        # Cleanup Chrome Processes that had been started
        foreach ($process in $processes) {
            try {
                $stopProcessResult = Stop-Process -InputObject $process -PassThru
                Write-Debug "Stop-Process: $stopProcessResult"
            } catch {
                Write-Warning "Exception when attempting to Stop-Process: $_"
            }
        }
    }
   
    # Loop through all the files and extract the data
    foreach ($file in $files) {
        Write-Verbose "Found file $file" 
        # Get file details
        $downloadData = [PSCustomObject]@{
            FileName             = $file.Name
            FullPath             = $file.FullName
            CreationDateTime     = $file.CreationTime
            LastModifiedDateTime = $file.LastWriteTime
            DurationSecs         = ($file.LastWriteTime - $file.CreationTime).TotalSeconds
        }

        if ($downloadData) {
            $results += $downloadData
        }
        else {
            Write-Error 'Download failure: $downloadData'
        }
    }


    # Print results in CSV format
    $csvOutput = $results | ConvertTo-Csv -NoTypeInformation
    $csvOutput | ForEach-Object { Write-Host $_ }

    $dateTimeString = Get-Date -Format "yyyyMMdd_HH:MM:SS"

    # Optionally, save the CSV output to a file
    $filePath = "$Script:DestDir\DownloadResults_$($dateTimeString).csv"
    Write-Verbose "Writing results to: $filePath"
    $csvOutput | Out-File -FilePath "$filePath" -Force
}

## ==========================================================================================
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
        Write-Verbose "$baseName $args)"
        (& $baseName @args)
    }
    else {
        Write-Error "No function named '$baseName' found to match script entry point."
    }
}
else {
    Write-Error "Unexpected execution context: $($MyInvocation.MyCommand.Path)"
}
#endregion   Execution Guard / Main Entrypoint
# ==========================================================================================