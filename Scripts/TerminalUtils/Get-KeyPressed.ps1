#========================================
#region Get-KeyPressed
<#
.SYNOPSIS
Captures keyboard input with modifier key detection using non-blocking console operations.

.DESCRIPTION
Uses [Console]::KeyAvailable and [Console]::ReadKey to capture keyboard input
with three distinct operating modes determined by parameters:

- Default: Non-blocking (checks once and returns immediately)
- -Blocking: Waits indefinitely until a key is pressed  
- -Timeout {secs}: Waits up to specified seconds, then returns null

If both -Blocking and -Timeout are specified, -Timeout takes precedence.

Returns detailed information about the pressed key including modifier states 
and character representation.

.PARAMETER Blocking
If specified, waits indefinitely until a key is pressed (unless -Timeout is also specified)

.PARAMETER Timeout
Maximum time to wait for a key press in seconds. If > 0, enables timeout mode.

.PARAMETER ShowKey
If true, echoes the pressed key to the console. Default is false (silent).

.EXAMPLE
# Non-blocking check (default)
$key = Get-KeyPressed
if ($key) { Write-Host "Key: $($key.Key)" }

.EXAMPLE
# Wait indefinitely for a key
$key = Get-KeyPressed -Blocking
Write-Host "You pressed: $($key.Key)"

.EXAMPLE
# Wait up to 5 seconds for a key press
$key = Get-KeyPressed -Timeout 5
if ($key) { Write-Host "You pressed: $($key.Key)" } else { Write-Host "Timeout!" }
#>
#========================================
#endregion

# Script-scoped constants for common special keys
$script:KEY_ENTER = [char]13        # Carriage return (\r)
$script:KEY_TAB = [char]9           # Tab character (\t)
$script:KEY_ESCAPE = [char]27       # Escape character
$script:KEY_SPACE = [char]32        # Space character
$script:KEY_BACKSPACE = [char]8     # Backspace character

# ConsoleKey enum constants for special key detection
$script:KEYCODE_ENTER = [ConsoleKey]::Enter
$script:KEYCODE_TAB = [ConsoleKey]::Tab
$script:KEYCODE_ESCAPE = [ConsoleKey]::Escape
$script:KEYCODE_SPACE = [ConsoleKey]::Spacebar
$script:KEYCODE_BACKSPACE = [ConsoleKey]::Backspace
$script:KEYCODE_DELETE = [ConsoleKey]::Delete
$script:KEYCODE_F1 = [ConsoleKey]::F1
$script:KEYCODE_F2 = [ConsoleKey]::F2
$script:KEYCODE_F3 = [ConsoleKey]::F3
$script:KEYCODE_F4 = [ConsoleKey]::F4
$script:KEYCODE_F5 = [ConsoleKey]::F5
$script:KEYCODE_UP = [ConsoleKey]::UpArrow
$script:KEYCODE_DOWN = [ConsoleKey]::DownArrow
$script:KEYCODE_LEFT = [ConsoleKey]::LeftArrow
$script:KEYCODE_RIGHT = [ConsoleKey]::RightArrow

function Get-KeyPressed {
    [CmdletBinding()]
    param(
        [switch]$Blocking,
        [int]$Timeout = 0,
        [switch]$ShowKey
    )

    # Determine mode based on parameters
    # Priority: Timeout > 0 = Timeout mode, else Blocking switch = Blocking mode, else NonBlocking
    $useTimeout = $Timeout -gt 0
    $useBlocking = $Blocking -and -not $useTimeout
    
    # Non-blocking: Check once and return immediately (default behavior)
    if (-not $useTimeout -and -not $useBlocking) {
        if ([Console]::KeyAvailable) {
            $keyInfo = [Console]::ReadKey(!$ShowKey)
            return [PSCustomObject]@{
                Key = $keyInfo.KeyChar.ToString()
                KeyCode = $keyInfo.Key
                Shift = ($keyInfo.Modifiers -band [ConsoleModifiers]::Shift) -eq [ConsoleModifiers]::Shift
                Ctrl = ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) -eq [ConsoleModifiers]::Control
                Alt = ($keyInfo.Modifiers -band [ConsoleModifiers]::Alt) -eq [ConsoleModifiers]::Alt
                RawKeyInfo = $keyInfo
                Timestamp = Get-Date
            }
        }
        return $null
    }
    
    # Blocking or Timeout modes
    $startTime = Get-Date
    
    do {
        if ([Console]::KeyAvailable) {
            $keyInfo = [Console]::ReadKey(!$ShowKey)
            return [PSCustomObject]@{
                Key = $keyInfo.KeyChar.ToString()
                KeyCode = $keyInfo.Key
                Shift = ($keyInfo.Modifiers -band [ConsoleModifiers]::Shift) -eq [ConsoleModifiers]::Shift
                Ctrl = ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) -eq [ConsoleModifiers]::Control
                Alt = ($keyInfo.Modifiers -band [ConsoleModifiers]::Alt) -eq [ConsoleModifiers]::Alt
                RawKeyInfo = $keyInfo
                Timestamp = Get-Date
            }
        }
        
        # Small delay to prevent excessive CPU usage in blocking modes
        Start-Sleep -Milliseconds 10
        
        # For Timeout mode, check if time exceeded
        if ($useTimeout -and ((Get-Date) - $startTime).TotalSeconds -ge $Timeout) {
            return $null
        }
        
    } while ($useBlocking -or $useTimeout)
    
    return $null
}

#========================================
#region Key Comparison Examples
<#
.SYNOPSIS
Demonstrates various ways to compare and handle key input.
#>
#========================================
#endregion

# Example 1: Non-blocking key check (returns immediately)
function Test-NonBlockingInput {
    Write-Host "Non-blocking demo - doing work while checking for 's' to stop..."
    $counter = 0
    
    do {
        # Do other work
        Write-Host "Working... $counter" -NoNewline
        Start-Sleep -Milliseconds 500
        Write-Host "`r" -NoNewline
        $counter++
        
        # Check for key press without blocking - returns immediately
        $key = Get-KeyPressed
        if ($key -and $key.Key.ToLower() -eq 's') {
            Write-Host "`nStop key pressed!"
            break
        }
        
    } while ($counter -lt 100)
    
    Write-Host "Demo completed."
}

# Example 2: Blocking key input (waits indefinitely)
function Test-BlockingInput {
    Write-Host "Blocking demo - waiting for any key (will wait forever until key pressed)..."
    
    $key = Get-KeyPressed -Blocking
    Write-Host "You pressed: '$($key.Key)'"
    
    Write-Host "Press 'q' to quit..."
    do {
        $key = Get-KeyPressed -Blocking
        Write-Host "Key: $($key.Key)"
    } while ($key.Key.ToLower() -ne 'q')
}

# Example 3: Timeout blocking (waits up to specified time)
function Test-TimeoutInput {
    Write-Host "Timeout demo - you have 5 seconds to press a key..."
    
    $key = Get-KeyPressed -Timeout 5
    if ($key) {
        Write-Host "You pressed '$($key.Key)' in time!"
    } else {
        Write-Host "Timeout! No key was pressed."
    }
}

# Example 4: Menu system using different modes
function Show-AdvancedKeyMenu {
    Write-Host @"
Advanced Key Menu Demo:
1 - Option One
2 - Option Two  
Y - Yes
N - No
Q - Quit
Press any key to start, or wait 3 seconds to auto-start...
"@

    # Wait 3 seconds for user input, then auto-start
    $key = Get-KeyPressed -Timeout 3
    if ($key) {
        Write-Host "Key pressed: $($key.Key) - starting menu"
    } else {
        Write-Host "Auto-starting menu..."
    }

    do {
        # Non-blocking check allows other processing
        $key = Get-KeyPressed
        if ($key) {
            switch ($key.Key.ToLower()) {
                '1' { Write-Host "Option One selected!" }
                '2' { Write-Host "Option Two selected!" }
                'y' { Write-Host "Yes selected!" }
                'n' { Write-Host "No selected!" }
                'q' { 
                    Write-Host "Goodbye!"
                    break 
                }
                default {
                    Write-Host "Unknown key: $($key.Key)"
                }
            }
        }
        
        # Do other background work
        Start-Sleep -Milliseconds 100
        
    } while ($true)
}

# Example 5: Interactive prompt with timeout
function Get-UserChoice {
    param(
        [string]$Prompt = "Continue? (Y/N)",
        [int]$TimeoutSeconds = 10,
        [char]$DefaultChoice = 'N'
    )
    
    Write-Host "$Prompt (timeout in $TimeoutSeconds seconds, default: $DefaultChoice): " -NoNewline
    
    $key = Get-KeyPressed -Timeout $TimeoutSeconds -ShowKey
    
    if ($key) {
        Write-Host ""  # New line after the key
        return $key.Key.ToUpper()
    } else {
        Write-Host $DefaultChoice  # Show the default choice
        return $DefaultChoice
    }
}

# Example 6: Special key detection using constants
function Test-SpecialKeyDetection {
    Write-Host @"
Special Key Detection Demo:
- Press Enter to confirm
- Press Tab to indent
- Press Escape to cancel
- Press Space to continue
- Press F1 for help
- Press Arrow keys to navigate
- Press 'q' to quit
"@

    do {
        $key = Get-KeyPressed -Blocking
        
        # Method 1: Using character constants (for keys that produce characters)
        if ($key.Key -eq $script:KEY_ENTER) {
            Write-Host "Enter pressed - confirmed!"
        }
        elseif ($key.Key -eq $script:KEY_TAB) {
            Write-Host "Tab pressed - indenting..."
        }
        elseif ($key.Key -eq $script:KEY_ESCAPE) {
            Write-Host "Escape pressed - cancelling..."
        }
        elseif ($key.Key -eq $script:KEY_SPACE) {
            Write-Host "Space pressed - continuing..."
        }
        
        # Method 2: Using KeyCode constants (preferred for special keys)
        elseif ($key.KeyCode -eq $script:KEYCODE_F1) {
            Write-Host "F1 pressed - showing help!"
        }
        elseif ($key.KeyCode -eq $script:KEYCODE_UP) {
            Write-Host "Up arrow - moving up"
        }
        elseif ($key.KeyCode -eq $script:KEYCODE_DOWN) {
            Write-Host "Down arrow - moving down" 
        }
        elseif ($key.KeyCode -eq $script:KEYCODE_LEFT) {
            Write-Host "Left arrow - moving left"
        }
        elseif ($key.KeyCode -eq $script:KEYCODE_RIGHT) {
            Write-Host "Right arrow - moving right"
        }
        elseif ($key.KeyCode -eq $script:KEYCODE_DELETE) {
            Write-Host "Delete pressed"
        }
        elseif ($key.KeyCode -eq $script:KEYCODE_BACKSPACE) {
            Write-Host "Backspace pressed"
        }
        
        # Regular character keys
        elseif ($key.Key.ToLower() -eq 'q') {
            Write-Host "Quit selected - goodbye!"
            break
        }
        else {
            Write-Host "Other key: '$($key.Key)' (KeyCode: $($key.KeyCode))"
        }
        
    } while ($true)
}

# Example 7: Enter key variations and best practices
function Test-EnterKeyDetection {
    Write-Host @"
Enter Key Detection Methods:
Type some text and press Enter to see different detection methods...
(Type 'quit' and press Enter to exit)
"@

    do {
        Write-Host "Input: " -NoNewline
        $input = ""
        
        # Build input string character by character until Enter
        do {
            $key = Get-KeyPressed -Blocking -ShowKey
            
            # Check for Enter using different methods
            if ($key.Key -eq $script:KEY_ENTER) {
                Write-Host ""  # New line
                Write-Host "Enter detected using character constant: [char]13"
                break
            }
            elseif ($key.KeyCode -eq $script:KEYCODE_ENTER) {
                Write-Host ""  # New line  
                Write-Host "Enter detected using KeyCode constant: ConsoleKey.Enter"
                break
            }
            elseif ($key.Key -eq "`r") {
                Write-Host ""  # New line
                Write-Host "Enter detected using carriage return literal"
                break
            }
            elseif ([int][char]$key.Key -eq 13) {
                Write-Host ""  # New line
                Write-Host "Enter detected using ASCII code 13"
                break
            }
            elseif ($key.KeyCode -eq $script:KEYCODE_BACKSPACE) {
                # Handle backspace
                if ($input.Length -gt 0) {
                    $input = $input.Substring(0, $input.Length - 1)
                    Write-Host "`b `b" -NoNewline  # Erase character
                }
            }
            else {
                # Add character to input (if it's a printable character)
                if ($key.Key -match '\S' -or $key.Key -eq ' ') {
                    $input += $key.Key
                }
            }
            
        } while ($true)
        
        Write-Host "You entered: '$input'"
        
        if ($input.ToLower() -eq 'quit') {
            Write-Host "Goodbye!"
            break
        }
        
    } while ($true)
}

# Example 8: Multi-key combinations and sequences
function Test-KeyCombinations {
    Write-Host @"
Key Combination Detection:
- Ctrl+C: Copy
- Ctrl+V: Paste  
- Ctrl+Enter: Submit
- Alt+F4: Exit
- Shift+Tab: Reverse tab
- Regular Enter: New line
- Escape to quit
"@

    do {
        $key = Get-KeyPressed -Blocking
        
        # Check combinations first (more specific)
        if ($key.Ctrl -and $key.Key.ToLower() -eq 'c') {
            Write-Host "Ctrl+C - Copy command"
        }
        elseif ($key.Ctrl -and $key.Key.ToLower() -eq 'v') {
            Write-Host "Ctrl+V - Paste command"
        }
        elseif ($key.Ctrl -and $key.Key -eq $script:KEY_ENTER) {
            Write-Host "Ctrl+Enter - Submit command"
        }
        elseif ($key.Alt -and $key.KeyCode -eq $script:KEYCODE_F4) {
            Write-Host "Alt+F4 - Exit application"
            break
        }
        elseif ($key.Shift -and $key.Key -eq $script:KEY_TAB) {
            Write-Host "Shift+Tab - Reverse tab"
        }
        
        # Then check individual keys
        elseif ($key.Key -eq $script:KEY_ENTER) {
            Write-Host "Enter - New line"
        }
        elseif ($key.Key -eq $script:KEY_ESCAPE) {
            Write-Host "Escape - Quitting..."
            break
        }
        else {
            $modifiers = @()
            if ($key.Ctrl) { $modifiers += "Ctrl" }
            if ($key.Alt) { $modifiers += "Alt" }  
            if ($key.Shift) { $modifiers += "Shift" }
            
            $modStr = if ($modifiers.Count -gt 0) { ($modifiers -join "+") + "+" } else { "" }
            Write-Host "$modStr$($key.Key)"
        }
        
    } while ($true)
}

# Example 5: Non-blocking key check in a loop
function Test-NonBlockingInput {
    Write-Host "Starting non-blocking demo (press 's' to stop)..."
    $counter = 0
    
    do {
        # Do other work
        Write-Host "Working... $counter" -NoNewline
        Start-Sleep -Milliseconds 500
        Write-Host "`r" -NoNewline
        $counter++
        
        # Check for key press without blocking
        $key = Get-KeyPressed
        if ($key -and $key.Key.ToLower() -eq 's') {
            Write-Host "`nStop key pressed!"
            break
        }
        
    } while ($counter -lt 100)
    
    Write-Host "Demo completed."
}

# Usage Examples:
<#
# NON-BLOCKING: Check once and return immediately (default)
$key = Get-KeyPressed
if ($key) {
    Write-Host "Key available: $($key.Key)"
} else {
    Write-Host "No key available right now"
}

# BLOCKING: Wait indefinitely until a key is pressed
Write-Host "Press any key to continue..."
$key = Get-KeyPressed -Blocking
Write-Host "You pressed: $($key.Key)"

# TIMEOUT: Wait up to specified seconds, then return null
Write-Host "You have 5 seconds to press a key..."
$key = Get-KeyPressed -Timeout 5
if ($key) {
    Write-Host "You pressed: $($key.Key)"
} else {
    Write-Host "Timeout - no key pressed"
}

# SPECIAL KEY DETECTION using constants:

# Enter key detection (multiple methods - use character constant for consistency)
$key = Get-KeyPressed -Blocking
if ($key.Key -eq $script:KEY_ENTER) {
    Write-Host "Enter pressed!"
}

# Alternative Enter detection using KeyCode (also reliable)
if ($key.KeyCode -eq $script:KEYCODE_ENTER) {
    Write-Host "Enter pressed (via KeyCode)!"
}

# Other special keys using character constants
if ($key.Key -eq $script:KEY_TAB) { Write-Host "Tab pressed!" }
if ($key.Key -eq $script:KEY_ESCAPE) { Write-Host "Escape pressed!" }
if ($key.Key -eq $script:KEY_SPACE) { Write-Host "Space pressed!" }

# Special keys that don't have character representation - use KeyCode
if ($key.KeyCode -eq $script:KEYCODE_F1) { Write-Host "F1 pressed!" }
if ($key.KeyCode -eq $script:KEYCODE_UP) { Write-Host "Up arrow!" }
if ($key.KeyCode -eq $script:KEYCODE_DELETE) { Write-Host "Delete pressed!" }

# Key combinations
if ($key.Ctrl -and $key.Key -eq $script:KEY_ENTER) {
    Write-Host "Ctrl+Enter pressed!"
}

# Practical examples for each mode:

# Non-blocking: Background monitoring
do {
    # Do work
    Write-Host "Working..." -NoNewline
    Start-Sleep -Milliseconds 500
    
    # Quick check for escape key
    $key = Get-KeyPressed
    if ($key -and $key.Key -eq $script:KEY_ESCAPE) {
        Write-Host "User cancelled!"
        break
    }
} while ($workNotDone)

# Blocking: Wait for Enter to continue
Write-Host "Press Enter to continue..."
do {
    $key = Get-KeyPressed -Blocking
} while ($key.Key -ne $script:KEY_ENTER)

# Timeout: User prompt with default
$choice = Get-UserChoice -Prompt "Save changes? (Y/N)" -TimeoutSeconds 10 -DefaultChoice 'Y'

# Parameter combinations:
Get-KeyPressed              # Non-blocking (default)
Get-KeyPressed -Blocking    # Wait forever
Get-KeyPressed -Timeout 5   # Wait 5 seconds max
Get-KeyPressed -Blocking -Timeout 5  # -Timeout takes precedence (5 second timeout)

# Best practices for Enter key:
# 1. Use $script:KEY_ENTER for character comparison (most reliable)
# 2. Use $script:KEYCODE_ENTER for KeyCode comparison  
# 3. Both methods work, character constant is preferred for keys that produce characters
# 4. For function keys, arrows, etc. that don't produce printable characters, use KeyCode constants
#>
