# ===========================================================================================
#region     Test-Logging.Tests.ps1
<#
.SYNOPSIS
    Pester tests for Logging.ps1 functions.
#>
# ===========================================================================================

# ===========================================================================================
#region       Ensure PSRoot and Dot Source Core Globals
# ===========================================================================================

function InitializeCore {
    if (-not $Script:PSRoot) {
        $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
        Write-Host "Set Script:PSRoot = $Script:PSRoot"
    }
    if (-not $Script:PSRoot) {
        throw 'Script:PSRoot must be set by the entry-point script before using internal components.'
    }

    $Script:CliArgs = $args
    . "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"
    
    $Script:scriptUnderTest = "$Script:PSRoot\Scripts\DevUtils\Logging.ps1"
}

#endregion
# ===========================================================================================


Describe "Logging.ps1" {

    BeforeAll {
        # InitializeCore
        if (-not $Script:PSRoot) {
            $Script:PSRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
            Write-Host "Set Script:PSRoot = $Script:PSRoot"
        }
        if (-not $Script:PSRoot) {
            throw 'Script:PSRoot must be set by the entry-point script before using internal components.'
        }

        $Script:CliArgs = $args
        . "$Script:PSRoot\Scripts\Initialize-CoreConfig.ps1"
    
        $Script:scriptUnderTest = "$Script:PSRoot\Scripts\DevUtils\Logging.ps1"
        . "$Script:scriptUnderTest"
    }

    Context "LogLevel Enumeration" {
        It "Should define the correct log levels" {
            [int][LogLevel]::Never | Should -Be -1
            [int][LogLevel]::Always | Should -Be 0
            [int][LogLevel]::Error | Should -Be 1
            [int][LogLevel]::Warn | Should -Be 2
            [int][LogLevel]::Info | Should -Be 4
            [int][LogLevel]::Debug | Should -Be 8
            [int][LogLevel]::EntryExit | Should -Be 16
            [int][LogLevel]::CallStack | Should -Be 32
            [int][LogLevel]::All | Should -Be 256
        }
    }

    Context "Set-LogFilePathName and Get-LogFilePathName" {
        It "Should set and get the log file path name" {
            Set-LogFilePathName -FileName "C:\Temp\LogFile.txt"
            $logFilePath = Get-LogFilePathName
            $logFilePath | Should -Be "C:\Temp\LogFile.txt"
        }
    }

    Context "Set-LogLevel and Get-LogLevel" {
        It "Should set and get the log level" {
            Set-LogLevel -LogLevel ([LogLevel]::Debug)
            $logLevel = Get-LogLevel
            $logLevel | Should -Be ([LogLevel]::Debug)
        }
    }

    Context "ConvertTo-LogLevel" {
        It "Should convert a valid log level string to LogLevel enum" {
            $logLevel = ConvertTo-LogLevel -LogLevel "Error"
            $logLevel | Should -Be ([LogLevel]::Error)
        }

        It "Should fallback to Info for an invalid log level string" {
            $logLevel = ConvertTo-LogLevel -LogLevel "InvalidLevel"
            $logLevel | Should -Be ([LogLevel]::Info)
        }
    }

    Context "Invoke-LogLevelOverride" {
        It "Should override the log level for the duration of the script block" {
            $initialLogLevel = Get-LogLevel
            Invoke-LogLevelOverride -LogLevel ([LogLevel]::Debug) -ScriptBlock {
                $overriddenLogLevel = Get-LogLevel
                $overriddenLogLevel | Should -Be ([LogLevel]::Debug)
            }
            $finalLogLevel = Get-LogLevel
            $finalLogLevel | Should -Be $initialLogLevel
        }
    }

    Context "Trace-EntryExit" {
        It "Should log entry and exit messages" {
            Set-LogLevel -LogLevel ([LogLevel]::EntryExit)

            $logFile = "C:\temp\TestLog.txt"
            If (Test-Path -Path $logFile) { Remove-Item -Path $logFile -Force }
            Set-LogFilePathName -FileName $logFile

            Trace-EntryExit -Message "Testing entry and exit" -ScriptBlock {
                # Simulated work
                Start-Sleep -Milliseconds 100
            }

            $logContent = Get-Content -Path (Get-LogFilePathName)
            $logContent.Count | Should -BeExactly 2
            $logContent[0] | Should -Match "ENTRY"
            $logContent[1] | Should -Match "EXIT"
            $logFile | Should -FileContentMatch "ENTRY"
            $logFile | Should -FileContentMatch "EXIT"

            Remove-Item -Path $logFile -Force         
        }
    }

    Context "Log" {
        It "Should log messages with different log levels" {
            $logFile = "C:\Temp\TestLog.txt"
            if (Test-Path -Path $logFile) { Remove-Item -Path $logFile -Force }
            Set-LogFilePathName -FileName $logFile

            Log -Info "This is an info message"
            Log -Err  "This is an error message"
            Log -Warn "This is a warning message"
            Log -Dbg  "This is a debug message"

            $logContent = Get-Content -Path $logFile
            $logContent.Count | Should -BeExactly 4
            $logContent[0] | Should -Match "INFO"
            $logContent[1] | Should -Match "ERROR"
            $logContent[2] | Should -Match "WARN"
            $logContent[3] | Should -Match "DEBUG"

            Remove-Item -Path $logFile -Force
        }

        It "Should log entry and exit messages with the -Entry and -Exit switches" {
            $logFile = "C:\Temp\TestLog.txt"
            if (Test-Path -Path $logFile) { Remove-Item -Path $logFile -Force }
            Set-LogFilePathName -FileName $logFile

            function Test-EntryExit {
                $entryLog = Log -Entry "Begin processing data set"
                if ($entryLog) {}
                Start-Sleep -Milliseconds 100
                $entryLog.Dispose()
            }

            Test-EntryExit

            $logContent = Get-Content -Path $logFile
            $logContent.Count | Should -BeExactly 2
            $logContent[0] | Should -Match "ENTRY"
            $logContent[0] | Should -Match "Begin processing data set" 
            $logContent[1] | Should -Match "EXIT"
            $logFile | Should -FileContentMatch "ENTRY"
            $logFile | Should -FileContentMatch "Begin processing data set" 
            $logFile | Should -FileContentMatch "EXIT"

            Remove-Item -Path $logFile -Force
        }

        It "Should log messages with a custom tag" {
            $logFile = "C:\Temp\TestLog.txt"
            if (Test-Path -Path $logFile) { Remove-Item -Path $logFile -Force }
            Set-LogFilePathName -FileName $logFile

            Log -Dbg -Tag "CUSTOM" "This is a custom tagged message"

            $logContent = Get-Content -Path $logFile
            $logContent.Count | Should -BeExactly 1
            $logContent | Should -Match "[CUSTOM]"
            $logFile | Should -FileContentMatch "[CUSTOM]"

            Remove-Item -Path $logFile -Force
        }

        It "Should log messages with stack trace information" {
            $logFile = "C:\Temp\TestLog.txt"
            if (Test-Path -Path $logFile) { Remove-Item -Path $logFile -Force }
            Set-LogFilePathName -FileName $logFile

            function Test-StackTrace {
                Log -Warn -CallStack "Expected error occurred"
            }

            Test-StackTrace

            #$logContent = Get-Content -Path $logFile
            $logFile | Should -FileContentMatch "Expected error occurred"
            $logFile | Should -FileContentMatch "Test-StackTrace"
            $logFile | Should -FileContentMatch "WARN"

            Remove-Item -Path $logFile -Force
        }

        It "Should log messages in dry run mode" {
            $logFile = "C:\Temp\TestLog.txt"
            if (Test-Path -Path $logFile) { Remove-Item -Path $logFile -Force }
            Set-LogFilePathName -FileName $logFile

            Log -DryRun -Info "This is a dry run message"

            $logContent = Get-Content -Path $logFile
            $logContent | Should -Match "[DryRun]"
            $logContent | Should -Match "[INFO]"

            Remove-Item -Path $logFile -Force
        }

        It "Should log messages with different formatting options" {
            $logFile = "C:\Temp\TestLog.txt"
            if (Test-Path -Path $logFile) { Remove-Item -Path $logFile -Force }
            Set-LogFilePathName -FileName $logFile

            Log -Info -MsgOnly ">>> Starting >>>"
            Log -Info -NoMsg "Just want the prefix"
            Log -Info -NoNewLine "Still working..."
            Log -Info -MsgOnly "<<< Done <<<"

            $logContent = Get-Content -Path $logFile
            $logContent.Count | Should -BeExactly 3
            $logContent[0] | Should -Match ">>> Starting >>>"
            $logContent[1] | Should -Not -Match "Just want the prefix"
            $logContent[2] | Should -Match "INFO"
            $logContent[2] | Should -Match "Still working..."
            $logContent[2] | Should -Match "<<< Done <<<"
            $logFile | Should -FileContentMatch ">>> Starting >>>"
            $logFile | Should -Not -FileContentMatch "Just want the prefix"
            $logFile | Should -FileContentMatch "INFO"
            $logFile | Should -FileContentMatch "Still working..."
            $logFile | Should -FileContentMatch "<<< Done <<<"

            Remove-Item -Path $logFile -Force
        }
    }

    Context "Format-LogPrefix" {
        It "Should format the log prefix correctly" {
            $prefix = Format-LogPrefix -LogLevel ([LogLevel]::Info) -Tag "TEST"
            $prefix | Should -Match "[ INFO ]"
            $prefix | Should -Match "\[TEST\]"
        }
    }

    Context "Write-LogMessage" {
        It "Should write the log message to the console and log file" {
            $logFile = "C:\Temp\TestLog.txt"
            if (Test-Path -Path $logFile) { Remove-Item -Path $logFile -Force }
            Set-LogFilePathName -FileName $logFile

            Write-LogMessage -Message "Test log message" -Color "Green"

            $logContent = Get-Content -Path $logFile
            $logContent | Should -Contain "Test log message"

            Remove-Item -Path $logFile -Force
        }
    }
}
#endregion# ===========================================================================================
