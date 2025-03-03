<#
.SYNOPSIS
    Runs the gRPC test client with configurable settings.
.DESCRIPTION
    This script prompts for client configuration settings and launches the client executable 
    with the specified environment variables.
.EXAMPLE
    .\run-client.ps1
#>

# Ensure we have a client.exe to run
if (-not (Test-Path "bin\client.exe")) {
    Write-Host "Error: client.exe not found in bin directory." -ForegroundColor Red
    Write-Host "Please run setup.ps1 first to build the client executable." -ForegroundColor Yellow
    exit 1
}

# Helper function to get input with validation and default value
function Get-ValidatedInput {
    param (
        [string]$Prompt,
        [string]$Default,
        [scriptblock]$Validator = { $true },
        [string]$ErrorMessage = "Invalid input. Please try again."
    )
    
    do {
        $input = Read-Host -Prompt "$Prompt (default: $Default)"
        if ($input -eq "") { $input = $Default }
        $valid = & $Validator $input
        if (-not $valid) {
            Write-Host $ErrorMessage -ForegroundColor Red
        }
    } while (-not $valid)
    
    return $input
}

# Helper function to get yes/no input
function Get-YesNoInput {
    param (
        [string]$Prompt,
        [bool]$Default
    )
    
    $defaultStr = if ($Default) { "Y" } else { "N" }
    $promptStr = "$Prompt [Y/N] (default: $defaultStr)"
    
    do {
        $input = Read-Host -Prompt $promptStr
        if ($input -eq "") { 
            return $Default
        }
        
        if ($input -eq "Y" -or $input -eq "y") {
            return $true
        }
        elseif ($input -eq "N" -or $input -eq "n") {
            return $false
        }
        
        Write-Host "Please enter Y or N." -ForegroundColor Red
    } while ($true)
}

# Get server address
$serverAddr = Get-ValidatedInput -Prompt "Enter server address (host:port)" -Default "localhost:50051"

# Get keepalive time
$keepAliveTime = Get-ValidatedInput -Prompt "Enter keepalive time in seconds" -Default "10" -Validator {
    param($t)
    $intValue = 0
    return [int]::TryParse($t, [ref]$intValue) -and $intValue -gt 0
} -ErrorMessage "Value must be a positive integer"

# Get keepalive timeout
$keepAliveTimeout = Get-ValidatedInput -Prompt "Enter keepalive timeout in seconds" -Default "2" -Validator {
    param($t)
    $intValue = 0
    return [int]::TryParse($t, [ref]$intValue) -and $intValue -gt 0
} -ErrorMessage "Value must be a positive integer"

# Get permit without stream
$permitWithoutStream = Get-YesNoInput -Prompt "Permit keepalive without active streams?" -Default $true

# Get ping interval
$pingInterval = Get-ValidatedInput -Prompt "Enter ping interval in seconds" -Default "2" -Validator {
    param($i)
    $intValue = 0
    return [int]::TryParse($i, [ref]$intValue) -and $intValue -gt 0
} -ErrorMessage "Value must be a positive integer"

# Get use payload
$usePayload = Get-YesNoInput -Prompt "Use payload test mode (instead of simple ping)?" -Default $false

# Get payload size if using payload mode
$payloadSize = "1024"
if ($usePayload) {
    $payloadSize = Get-ValidatedInput -Prompt "Enter payload size in KB (can be fractional like 1.5)" -Default "1024" -Validator {
        param($s)
        $floatValue = 0.0
        $isFloat = [float]::TryParse($s, [ref]$floatValue)
        return $isFloat -and $floatValue -gt 0
    } -ErrorMessage "Value must be a positive number"
}

# Get request timeout
$requestTimeout = Get-ValidatedInput -Prompt "Enter request timeout in seconds" -Default "10" -Validator {
    param($t)
    $intValue = 0
    return [int]::TryParse($t, [ref]$intValue) -and $intValue -gt 0
} -ErrorMessage "Value must be a positive integer"

# Set the environment variables
$env:SERVER_ADDR = $serverAddr
$env:KEEPALIVE_TIME_SEC = $keepAliveTime
$env:KEEPALIVE_TIMEOUT_SEC = $keepAliveTimeout
$env:PERMIT_WITHOUT_STREAM = if ($permitWithoutStream) { "true" } else { "false" }
$env:PING_INTERVAL_SEC = $pingInterval
$env:USE_PAYLOAD = if ($usePayload) { "true" } else { "false" }
$env:PAYLOAD_SIZE_KB = $payloadSize
$env:REQUEST_TIMEOUT_SEC = $requestTimeout

# Display configuration summary
Write-Host "`nClient Configuration Summary:" -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor Cyan
Write-Host "Server Address: $serverAddr"
Write-Host "Keepalive Time: $keepAliveTime seconds"
Write-Host "Keepalive Timeout: $keepAliveTimeout seconds"
Write-Host "Permit Without Stream: $(if ($permitWithoutStream) { 'Yes' } else { 'No' })"
Write-Host "Ping Interval: $pingInterval seconds"
Write-Host "Test Mode: $(if ($usePayload) { 'Payload' } else { 'Simple Ping' })"
if ($usePayload) {
    Write-Host "Payload Size: $payloadSize KB"
}
Write-Host "Request Timeout: $requestTimeout seconds"
Write-Host "--------------------------------`n" -ForegroundColor Cyan

# Run the client
Write-Host "Starting gRPC test client..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop the client.`n" -ForegroundColor Yellow

try {
    & "bin\client.exe"
}
catch {
    Write-Host "Error starting client: $_" -ForegroundColor Red
    exit 1
}
