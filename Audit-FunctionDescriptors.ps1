powershell
<#
.SYNOPSIS
Audits PowerShell function descriptor compliance for Get-Help.

.DESCRIPTION
Scans all .ps1 and .psm1 files recursively from the current directory. 
For each function found, it determines whether it has a valid Get-Help descriptor.
Generates a summary of status per function and optionally stores verbose audit results in JSON format.

.PARAMETER OutFile
Path to the output JSON file containing detailed audit results. If not specified, output goes to stdout.

.PARAMETER DeltaFile
Path to a second JSON file to compare against for reporting deltas (e.g., post-Codex updates).

.PARAMETER VerboseAudit
Switch. If set, includes descriptor text in the JSON and console output.

.EXAMPLE
.\Audit-FunctionDescriptors.ps1 -OutFile audit_before.json

.EXAMPLE
.\Audit-FunctionDescriptors.ps1 -OutFile audit_after.json -DeltaFile audit_before.json
#>

[CmdletBinding()]
param(
    [string]$OutFile,
    [string]$DeltaFile,
    [switch]$VerboseAudit
)

function Get-FunctionAudit {
    param (
        [string]$FilePath
    )
    $content = Get-Content -Raw -Path $FilePath
    $functionRegex = '(?m)^\s*function\s+(\w+)\s*\{'
    $matches = [regex]::Matches($content, $functionRegex)

    $results = @()
    foreach ($match in $matches) {
        $funcName = $match.Groups[1].Value
        $startIdx = $match.Index
        $preContext = $content.Substring([Math]::Max(0, $startIdx - 1000), [Math]::Min(1000, $startIdx))

        $hasRegion = $preContext -match "#region\s+Function:\s*$funcName"
        $hasSynopsis = $preContext -match "\.SYNOPSIS"
        $hasHelpBlock = $preContext -match "<#(.|\n)+?#>"

        if ($hasRegion -and $hasSynopsis -and $hasHelpBlock) {
            $status = "Compliant"
        }
        elseif ($hasSynopsis -or $hasHelpBlock -or $hasRegion) {
            $status = "Partial"
        }
        else {
            $status = "Missing"
        }

        $descriptor = if ($VerboseAudit) {
            $preContext -replace '(?s)^.*?(<#(.|\n)+?#>)', '$1'
        } else { $null }

        $results += [pscustomobject]@{
            FilePath   = $FilePath
            Function   = $funcName
            Status     = $status
            Descriptor = $descriptor
        }
    }
    return $results
}

function Compare-AuditResults {
    param (
        [string]$OldPath,
        [string]$NewPath
    )
    $old = Get-Content $OldPath | ConvertFrom-Json
    $new = Get-Content $NewPath | ConvertFrom-Json

    $delta = @()
    foreach ($entry in $new) {
        $match = $old | Where-Object { $_.FilePath -eq $entry.FilePath -and $_.Function -eq $entry.Function }
        if ($match) {
            if ($match.Status -ne $entry.Status) {
                $delta += [pscustomobject]@{
                    FilePath = $entry.FilePath
                    Function = $entry.Function
                    OldStatus = $match.Status
                    NewStatus = $entry.Status
                }
            }
        } else {
            $delta += [pscustomobject]@{
                FilePath = $entry.FilePath
                Function = $entry.Function
                OldStatus = "NotPresent"
                NewStatus = $entry.Status
            }
        }
    }

    if ($delta.Count -eq 0) {
        Write-Host "No changes detected between audit files." -ForegroundColor Green
    } else {
        Write-Host "Delta Summary:" -ForegroundColor Cyan
        $delta | Format-Table -AutoSize
    }
}

$allResults = @()
Get-ChildItem -Recurse -Include *.ps1, *.psm1 | ForEach-Object {
    $allResults += Get-FunctionAudit -FilePath $_.FullName
}

if ($OutFile) {
    $allResults | ConvertTo-Json -Depth 5 | Set-Content -Path $OutFile -Encoding UTF8
    Write-Host "Audit results written to $OutFile" -ForegroundColor Yellow
} else {
    $allResults | Format-Table FilePath, Function, Status
}

if ($DeltaFile) {
    Compare-AuditResults -OldPath $DeltaFile -NewPath $OutFile
}
