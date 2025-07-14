# RepeatedlyDownload-SharePointFile.ps1
 
# Global variables
$Global:Url =  CPM Plus Program Review - Jan 2025.pptx
$Global:WaitSeconds = 10
$Global:Overwrite = $true
$Global:DestDir = "$env:USERPROFILE\Downloads"
 
# Import the Get-SharePointFile script
. "$PSScriptRoot\Get-SharePointFile.ps1"
 
# Initialize variables
$downloads = @()
$stopDownloading = $false
 
# Function to download the file and capture metrics
function Save-File {
    param (
        [string]$Url,
        [string]$DestDir,
        [switch]$Overwrite
    )
 
    $downloadParams = @{
        Url = $Url
        DestDir = $DestDir
    }
    if (-not $Overwrite) {
        $downloadParams["DoNotPersist"] = $true
    }
 
    $downloadStartTime = Get-Date
    $result = Get-SharePointFile @downloadParams
    $downloadEndTime = Get-Date
    $duration = $downloadEndTime - $downloadStartTime
 
    if ($result) {
        $fileSizeMB = [math]::Round((Get-Item $result.FilePath).Length / 1MB, 2)
        return [PSCustomObject]@{
            StartTime = $downloadStartTime
            Duration = $duration.TotalSeconds
            FileSizeMB = $fileSizeMB
            FilePath = $result.FilePath
        }
    } else {
        return $null
    }
}
 
# Main loop
while (-not $stopDownloading) {
    $downloadResult = Save-File -Url $Global:Url -DestDir $Global:DestDir -Overwrite:$Global:Overwrite
    if ($downloadResult) {
        $downloads += $downloadResult
        Write-Host "Download completed: $($downloadResult.FilePath)"
    } else {
        Write-Host "Download failed."
    }
 
    Write-Host "Waiting for $Global:WaitSeconds seconds or press Enter to start immediately. Press Q to stop."
    $waitTask = Start-Sleep -Seconds $Global:WaitSeconds -Async
    while (-not $waitTask.IsCompleted) {
        if ($Host.UI.RawUI.KeyAvailable) {
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($key.Character -eq "`r") {
                Write-Host "Starting next download immediately..."
                break
            } elseif ($key.Character -eq "q" -or $key.Character -eq "Q") {
                $stopDownloading = $true
                break
            }
        }
    }
}
 
# Print results in CSV format
$csvOutput = $downloads | ConvertTo-Csv -NoTypeInformation
$csvOutput | ForEach-Object { Write-Host $_ }
 
# Optionally, save the CSV output to a file
$csvOutput | Out-File -FilePath "$Global:DestDir\DownloadResults.csv" -Force


