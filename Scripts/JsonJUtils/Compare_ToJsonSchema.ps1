#========================================
#region Compare-ToJsonSchema
<#
.SYNOPSIS
Validates a JSON file or content against a JSON schema.

.DESCRIPTION
Generic JSON schema validation script that works with built-in PowerShell capabilities
and optionally supports advanced validation with Newtonsoft.Json.Schema if available.

.PARAMETER JsonPath
Path to the JSON file to validate.

.PARAMETER JsonContent
JSON content as string to validate directly.

.PARAMETER SchemaPath
Path to the JSON schema file.

.PARAMETER SchemaContent
JSON schema content as string.

.PARAMETER OutputFormat
Format for validation results: Summary, Detailed, or JSON.

.PARAMETER StrictMode
Enable strict validation (all properties must be defined in schema).

.PARAMETER ShowStats
Include validation statistics in the output.

.PARAMETER TestMode
Run built-in validation tests.

.EXAMPLE
Compare-ToJsonSchema -JsonPath "config.json" -SchemaPath "schema.json"

.EXAMPLE
Compare-ToJsonSchema -JsonContent $jsonString -SchemaPath "schema.json" -OutputFormat Detailed

.EXAMPLE
Compare-ToJsonSchema -TestMode
#>
#========================================
#endregion
function Compare-ToJsonSchema {
    [CmdletBinding(DefaultParameterSetName = 'FilePath')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'FilePath')]
        [string]$JsonPath,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Content')]
        [string]$JsonContent,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'FilePath')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Content')]
        [string]$SchemaPath,
        
        [Parameter(ParameterSetName = 'SchemaContent')]
        [string]$SchemaContent,
        
        [ValidateSet('Summary', 'Detailed', 'JSON')]
        [string]$OutputFormat = 'Summary',
        
        [switch]$StrictMode,
        
        [switch]$ShowStats,
        
        [switch]$TestMode
    )
    
    if ($TestMode) {
        return Invoke-JsonValidationTests
    }
    
    $startTime = Get-Date
    
    try {
        # Load JSON content
        if ($PSCmdlet.ParameterSetName -eq 'FilePath') {
            if (-not (Test-Path $JsonPath)) {
                throw "JSON file not found: $JsonPath"
            }
            $jsonString = Get-Content -Path $JsonPath -Raw
        } else {
            $jsonString = $JsonContent
        }
        
        # Load schema content
        if ($SchemaContent) {
            $schemaString = $SchemaContent
        } else {
            if (-not (Test-Path $SchemaPath)) {
                throw "Schema file not found: $SchemaPath"
            }
            $schemaString = Get-Content -Path $SchemaPath -Raw
        }
        
        # Parse JSON and schema
        try {
            $jsonObject = $jsonString | ConvertFrom-Json
            $schemaObject = $schemaString | ConvertFrom-Json
        } catch {
            throw "Failed to parse JSON or schema: $($_.Exception.Message)"
        }
        
        # Perform validation
        $validationResult = Test-JsonAgainstSchema -JsonObject $jsonObject -SchemaObject $schemaObject -StrictMode:$StrictMode
        
        # Calculate statistics
        $endTime = Get-Date
        $validationTime = $endTime - $startTime
        
        $statistics = @{
            ValidationTime = $validationTime
            TotalFields = (Get-ObjectFieldCount -Object $jsonObject)
            SchemaRules = (Get-SchemaRuleCount -Schema $schemaObject)
            ValidationMethod = if (Get-Command -Name 'Test-Json' -ErrorAction SilentlyContinue) { 'PowerShell-Native' } else { 'Custom' }
        }
        
        # Format result
        $result = @{
            IsValid = $validationResult.IsValid
            Errors = $validationResult.Errors
            Warnings = $validationResult.Warnings
            Statistics = if ($ShowStats) { $statistics } else { $null }
            Schema = @{
                Path = $SchemaPath
                Type = $schemaObject.'$schema'
                Title = $schemaObject.title
            }
            Json = @{
                Path = if ($JsonPath) { $JsonPath } else { '<content>' }
                Size = $jsonString.Length
            }
        }
        
        # Format output based on requested format
        switch ($OutputFormat) {
            'Summary' {
                return Format-ValidationSummary -Result $result
            }
            'Detailed' {
                return Format-ValidationDetailed -Result $result
            }
            'JSON' {
                return $result | ConvertTo-Json -Depth 10
            }
            default {
                return $result
            }
        }
        
    } catch {
        $errorResult = @{
            IsValid = $false
            Errors = @(
                @{
                    Path = 'root'
                    Message = $_.Exception.Message
                    Type = 'ValidationError'
                }
            )
            Warnings = @()
            Statistics = $null
        }
        
        if ($OutputFormat -eq 'JSON') {
            return $errorResult | ConvertTo-Json -Depth 10
        } else {
            return $errorResult
        }
    }
}

#========================================
#region Test-JsonAgainstSchema
<#
.SYNOPSIS
Core JSON validation logic against schema rules.
#>
#========================================
#endregion
function Test-JsonAgainstSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $JsonObject,
        
        [Parameter(Mandatory = $true)]
        $SchemaObject,
        
        [switch]$StrictMode,
        
        [string]$CurrentPath = 'root'
    )
    
    $errors = @()
    $warnings = @()
    
    # Check if PowerShell 6+ Test-Json is available
    if (Get-Command -Name 'Test-Json' -ErrorAction SilentlyContinue) {
        try {
            $jsonString = $JsonObject | ConvertTo-Json -Depth 100
            $schemaString = $SchemaObject | ConvertTo-Json -Depth 100
            $isValid = Test-Json -Json $jsonString -Schema $schemaString
            
            if (-not $isValid) {
                $errors += @{
                    Path = $CurrentPath
                    Message = "JSON does not conform to schema"
                    Type = "SchemaValidation"
                }
            }
            
            return @{
                IsValid = $isValid
                Errors = $errors
                Warnings = $warnings
            }
        } catch {
            # Fall back to custom validation if Test-Json fails
        }
    }
    
    # Custom validation logic for compatibility
    $validationErrors = Test-ObjectAgainstSchemaCustom -Object $JsonObject -Schema $SchemaObject -Path $CurrentPath -StrictMode:$StrictMode
    
    return @{
        IsValid = ($validationErrors.Count -eq 0)
        Errors = $validationErrors
        Warnings = $warnings
    }
}

#========================================
#region Test-ObjectAgainstSchemaCustom
<#
.SYNOPSIS
Custom JSON schema validation implementation for compatibility.
#>
#========================================
#endregion
function Test-ObjectAgainstSchemaCustom {
    [CmdletBinding()]
    param(
        $Object,
        $Schema,
        [string]$Path = 'root',
        [switch]$StrictMode
    )
    
    $errors = @()
    
    # Type validation
    if ($Schema.type) {
        $expectedType = $Schema.type
        $actualType = Get-JsonType -Object $Object
        
        if ($actualType -ne $expectedType) {
            $errors += @{
                Path = $Path
                Message = "Expected type '$expectedType' but got '$actualType'"
                Type = "TypeMismatch"
            }
            return $errors  # Can't continue validation if type is wrong
        }
    }
    
    # Object-specific validation
    if ($Schema.type -eq 'object' -or (-not $Schema.type -and $Object -is [PSCustomObject])) {
        # Required properties
        if ($Schema.required) {
            foreach ($requiredProp in $Schema.required) {
                $hasProperty = $false
                if ($Object.PSObject.Properties.Name -contains $requiredProp) {
                    $hasProperty = $true
                }
                
                if (-not $hasProperty) {
                    $errors += @{
                        Path = "$Path.$requiredProp"
                        Message = "Required property '$requiredProp' is missing"
                        Type = "MissingProperty"
                    }
                }
            }
        }
        
        # Property validation
        if ($Schema.properties) {
            foreach ($property in $Object.PSObject.Properties) {
                $propName = $property.Name
                $propValue = $property.Value
                $propSchema = $Schema.properties.$propName
                
                if ($propSchema) {
                    $propErrors = Test-ObjectAgainstSchemaCustom -Object $propValue -Schema $propSchema -Path "$Path.$propName" -StrictMode:$StrictMode
                    $errors += $propErrors
                } elseif ($StrictMode) {
                    $errors += @{
                        Path = "$Path.$propName"
                        Message = "Property '$propName' is not defined in schema (strict mode)"
                        Type = "UnknownProperty"
                    }
                }
            }
        }
    }
    
    # Array-specific validation
    if ($Schema.type -eq 'array' -or ($Object -is [Array])) {
        if ($Schema.minItems -and $Object.Count -lt $Schema.minItems) {
            $errors += @{
                Path = $Path
                Message = "Array has $($Object.Count) items but minimum is $($Schema.minItems)"
                Type = "ArrayConstraint"
            }
        }
        
        if ($Schema.maxItems -and $Object.Count -gt $Schema.maxItems) {
            $errors += @{
                Path = $Path
                Message = "Array has $($Object.Count) items but maximum is $($Schema.maxItems)"
                Type = "ArrayConstraint"
            }
        }
        
        # Item validation
        if ($Schema.items) {
            for ($i = 0; $i -lt $Object.Count; $i++) {
                $itemErrors = Test-ObjectAgainstSchemaCustom -Object $Object[$i] -Schema $Schema.items -Path "$Path[$i]" -StrictMode:$StrictMode
                $errors += $itemErrors
            }
        }
    }
    
    # String-specific validation
    if ($Schema.type -eq 'string' -or ($Object -is [string])) {
        if ($Schema.minLength -and $Object.Length -lt $Schema.minLength) {
            $errors += @{
                Path = $Path
                Message = "String length $($Object.Length) is less than minimum $($Schema.minLength)"
                Type = "StringConstraint"
            }
        }
        
        if ($Schema.maxLength -and $Object.Length -gt $Schema.maxLength) {
            $errors += @{
                Path = $Path
                Message = "String length $($Object.Length) is greater than maximum $($Schema.maxLength)"
                Type = "StringConstraint"
            }
        }
        
        if ($Schema.pattern) {
            if ($Object -notmatch $Schema.pattern) {
                $errors += @{
                    Path = $Path
                    Message = "String '$Object' does not match pattern '$($Schema.pattern)'"
                    Type = "PatternMismatch"
                }
            }
        }
        
        if ($Schema.enum) {
            if ($Object -notin $Schema.enum) {
                $errors += @{
                    Path = $Path
                    Message = "Value '$Object' is not in allowed values: $($Schema.enum -join ', ')"
                    Type = "EnumViolation"
                }
            }
        }
    }
    
    # Number-specific validation
    if ($Schema.type -in @('number', 'integer') -or ($Object -is [int] -or $Object -is [double])) {
        if ($Schema.minimum -and $Object -lt $Schema.minimum) {
            $errors += @{
                Path = $Path
                Message = "Value $Object is less than minimum $($Schema.minimum)"
                Type = "NumberConstraint"
            }
        }
        
        if ($Schema.maximum -and $Object -gt $Schema.maximum) {
            $errors += @{
                Path = $Path
                Message = "Value $Object is greater than maximum $($Schema.maximum)"
                Type = "NumberConstraint"
            }
        }
    }
    
    return $errors
}

#========================================
#region Helper Functions
#========================================

function Get-JsonType {
    param($Object)
    
    if ($Object -eq $null) { return 'null' }
    if ($Object -is [bool]) { return 'boolean' }
    if ($Object -is [int] -or $Object -is [long]) { return 'integer' }
    if ($Object -is [double] -or $Object -is [decimal]) { return 'number' }
    if ($Object -is [string]) { return 'string' }
    if ($Object -is [array]) { return 'array' }
    if ($Object -is [PSCustomObject] -or $Object -is [hashtable]) { return 'object' }
    
    return 'unknown'
}

function Get-ObjectFieldCount {
    param($Object, [int]$Count = 0)
    
    if ($Object -is [PSCustomObject]) {
        $Count += $Object.PSObject.Properties.Count
        foreach ($prop in $Object.PSObject.Properties) {
            $Count = Get-ObjectFieldCount -Object $prop.Value -Count $Count
        }
    } elseif ($Object -is [array]) {
        foreach ($item in $Object) {
            $Count = Get-ObjectFieldCount -Object $item -Count $Count
        }
    }
    
    return $Count
}

function Get-SchemaRuleCount {
    param($Schema, [int]$Count = 0)
    
    if ($Schema.type) { $Count++ }
    if ($Schema.required) { $Count += $Schema.required.Count }
    if ($Schema.properties) { $Count += $Schema.properties.PSObject.Properties.Count }
    if ($Schema.pattern) { $Count++ }
    if ($Schema.minimum -or $Schema.maximum) { $Count++ }
    if ($Schema.minItems -or $Schema.maxItems) { $Count++ }
    if ($Schema.minLength -or $Schema.maxLength) { $Count++ }
    
    return $Count
}

function Format-ValidationSummary {
    param($Result)
    
    $summary = [PSCustomObject]@{
        IsValid = $Result.IsValid
        ErrorCount = $Result.Errors.Count
        WarningCount = $Result.Warnings.Count
    }
    
    if ($Result.Statistics) {
        $summary | Add-Member -NotePropertyName 'ValidationTime' -NotePropertyValue $Result.Statistics.ValidationTime.TotalMilliseconds
        $summary | Add-Member -NotePropertyName 'TotalFields' -NotePropertyValue $Result.Statistics.TotalFields
    }
    
    if (-not $Result.IsValid) {
        $summary | Add-Member -NotePropertyName 'FirstError' -NotePropertyValue $Result.Errors[0].Message
    }
    
    return $summary
}

function Format-ValidationDetailed {
    param($Result)
    
    return [PSCustomObject]@{
        IsValid = $Result.IsValid
        Summary = @{
            ErrorCount = $Result.Errors.Count
            WarningCount = $Result.Warnings.Count
            ValidationTime = if ($Result.Statistics) { $Result.Statistics.ValidationTime.TotalMilliseconds } else { $null }
        }
        Errors = $Result.Errors
        Warnings = $Result.Warnings
        Statistics = $Result.Statistics
        Sources = @{
            JsonPath = $Result.Json.Path
            SchemaPath = $Result.Schema.Path
            SchemaType = $Result.Schema.Type
        }
    }
}

#========================================
#region Invoke-JsonValidationTests
<#
.SYNOPSIS
Built-in validation tests for the JSON schema validator.
#>
#========================================
#endregion
function Invoke-JsonValidationTests {
    Write-Host "Running JSON Schema Validation Tests..." -ForegroundColor Green
    
    $testResults = @()
    
    # Test 1: Valid JSON against simple schema
    try {
        $simpleSchema = @{
            type = "object"
            required = @("name")
            properties = @{
                name = @{ type = "string" }
                age = @{ type = "integer"; minimum = 0 }
            }
        }
        
        $validJson = @{
            name = "John"
            age = 30
        }
        
        $result = Test-JsonAgainstSchema -JsonObject $validJson -SchemaObject $simpleSchema
        $testResults += @{
            Test = "Valid JSON against simple schema"
            Passed = $result.IsValid
            Details = if (-not $result.IsValid) { $result.Errors[0].Message } else { "OK" }
        }
    } catch {
        $testResults += @{
            Test = "Valid JSON against simple schema"
            Passed = $false
            Details = $_.Exception.Message
        }
    }
    
    # Test 2: Invalid JSON (missing required field)
    try {
        $invalidJson = @{
            age = 30
            # Missing required 'name' field
        }
        
        $result = Test-JsonAgainstSchema -JsonObject $invalidJson -SchemaObject $simpleSchema
        $testResults += @{
            Test = "Invalid JSON (missing required field)"
            Passed = (-not $result.IsValid)
            Details = if ($result.IsValid) { "Should have failed validation" } else { "OK - Correctly detected missing field" }
        }
    } catch {
        $testResults += @{
            Test = "Invalid JSON (missing required field)"
            Passed = $false
            Details = $_.Exception.Message
        }
    }
    
    # Test 3: Type mismatch
    try {
        $typeMismatchJson = @{
            name = 123  # Should be string
            age = 30
        }
        
        $result = Test-JsonAgainstSchema -JsonObject $typeMismatchJson -SchemaObject $simpleSchema
        $testResults += @{
            Test = "Type mismatch detection"
            Passed = (-not $result.IsValid)
            Details = if ($result.IsValid) { "Should have detected type mismatch" } else { "OK - Correctly detected type mismatch" }
        }
    } catch {
        $testResults += @{
            Test = "Type mismatch detection"
            Passed = $false
            Details = $_.Exception.Message
        }
    }
    
    # Display results
    Write-Host "`nTest Results:" -ForegroundColor Cyan
    Write-Host "=============" -ForegroundColor Cyan
    
    $passedCount = 0
    foreach ($test in $testResults) {
        $status = if ($test.Passed) { "PASS" } else { "FAIL" }
        $color = if ($test.Passed) { "Green" } else { "Red" }
        
        Write-Host "$status : $($test.Test)" -ForegroundColor $color
        if (-not $test.Passed) {
            Write-Host "       Details: $($test.Details)" -ForegroundColor Yellow
        }
        
        if ($test.Passed) { $passedCount++ }
    }
    
    Write-Host "`nSummary: $passedCount/$($testResults.Count) tests passed" -ForegroundColor $(if ($passedCount -eq $testResults.Count) { "Green" } else { "Yellow" })
    
    return @{
        TotalTests = $testResults.Count
        PassedTests = $passedCount
        FailedTests = $testResults.Count - $passedCount
        Results = $testResults
    }
}

# Main execution logic
if ($MyInvocation.InvocationName -ne '.') {
    # Script is being executed directly
    param(
        [string]$JsonPath = "",
        [string]$JsonContent = "",
        [string]$SchemaPath = "",
        [string]$SchemaContent = "",
        [string]$OutputFormat = "Summary",
        [switch]$StrictMode,
        [switch]$ShowStats,
        [switch]$TestMode
    )
    
    try {
        if ($TestMode) {
            $result = Compare-ToJsonSchema -TestMode
        } elseif ($JsonContent) {
            $result = Compare-ToJsonSchema -JsonContent $JsonContent -SchemaPath $SchemaPath -OutputFormat $OutputFormat -StrictMode:$StrictMode -ShowStats:$ShowStats
        } else {
            $result = Compare-ToJsonSchema -JsonPath $JsonPath -SchemaPath $SchemaPath -OutputFormat $OutputFormat -StrictMode:$StrictMode -ShowStats:$ShowStats
        }
        
        if ($OutputFormat -eq 'JSON') {
            Write-Output $result
        } else {
            $result | Format-Table -AutoSize
        }
        
        if ($result.IsValid) {
            exit 0
        } else {
            exit 1
        }
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}