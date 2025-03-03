<#
.SYNOPSIS
    Runs the gRPC test server with configurable settings.
.DESCRIPTION
    This script prompts for server configuration settings and launches the server executable 
    with the specified environment variables.
.EXAMPLE
    .\run-server.ps1
#>

# Ensure we have a server.exe to run
if (-not (Test-Path "bin\server.exe")) {
    Write-Host "Error: server.exe not found in bin directory." -ForegroundColor Red
    Write-Host "Please run setup.ps1 first to build the server executable." -ForegroundColor Yellow
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

# Get server port
$port = Get-ValidatedInput -Prompt "Enter server port" -Default "50051" -Validator {
    param($p)
    $intValue = 0
    $isInt = [int]::TryParse($p, [ref]$intValue)
    return $isInt -and $intValue -gt 0 -and $intValue -lt 65536
} -ErrorMessage "Port must be a number between 1 and 65535"

# Get connection idle timeout
$maxIdle = Get-ValidatedInput -Prompt "Enter max connection idle time in seconds" -Default "15" -Validator {
    param($i)
    $intValue = 0
    return [int]::TryParse($i, [ref]$intValue) -and $intValue -gt 0
} -ErrorMessage "Value must be a positive integer"

# Get max connection age
$maxAge = Get-ValidatedInput -Prompt "Enter max connection age in seconds" -Default "30" -Validator {
    param($a)
    $intValue = 0
    return [int]::TryParse($a, [ref]$intValue) -and $intValue -gt 0
} -ErrorMessage "Value must be a positive integer"

# Get max connection age grace
$maxGrace = Get-ValidatedInput -Prompt "Enter max connection age grace period in seconds" -Default "5" -Validator {
    param($g)
    $intValue = 0
    return [int]::TryParse($g, [ref]$intValue) -and $intValue -ge 0
} -ErrorMessage "Value must be a non-negative integer"

# Get keepalive time
$keepAliveTime = Get-ValidatedInput -Prompt "Enter keepalive time in seconds" -Default "5" -Validator {
    param($t)
    $intValue = 0
    return [int]::TryParse($t, [ref]$intValue) -and $intValue -gt 0
} -ErrorMessage "Value must be a positive integer"

# Get keepalive timeout
$keepAliveTimeout = Get-ValidatedInput -Prompt "Enter keepalive timeout in seconds" -Default "1" -Validator {
    param($t)
    $intValue = 0
    return [int]::TryParse($t, [ref]$intValue) -and $intValue -gt 0
} -ErrorMessage "Value must be a positive integer"

# Get response delay
$responseDelay = Get-ValidatedInput -Prompt "Enter response delay in ms (can be a fixed value like '100' or a range like '50-200')" -Default "0-100" -Validator {
    param($d)
    
    # Check if it's a range format
    if ($d -match "^\d+-\d+$") {
        $parts = $d -split "-"
        $min = [int]::Parse($parts[0])
        $max = [int]::Parse($parts[1])
        return $min -ge 0 -and $max -ge $min
    }
    
    # Check if it's a fixed value
    $intValue = 0
    return [int]::TryParse($d, [ref]$intValue) -and $intValue -ge 0
} -ErrorMessage "Value must be a non-negative integer or a valid range (min-max)"

# Get max payload size
$maxPayloadSize = Get-ValidatedInput -Prompt "Enter max payload size in KB (can be fractional like 1024.5)" -Default "5120" -Validator {
    param($s)
    $floatValue = 0.0
    $isFloat = [float]::TryParse($s, [ref]$floatValue)
    return $isFloat -and $floatValue -gt 0
} -ErrorMessage "Value must be a positive number"

# Set the environment variables
$env:SERVER_PORT = $port
$env:MAX_CONN_IDLE_SEC = $maxIdle
$env:MAX_CONN_AGE_SEC = $maxAge
$env:MAX_CONN_AGE_GRACE_SEC = $maxGrace
$env:KEEPALIVE_TIME_SEC = $keepAliveTime
$env:KEEPALIVE_TIMEOUT_SEC = $keepAliveTimeout
$env:RESPONSE_DELAY_MS = $responseDelay
$env:MAX_PAYLOAD_SIZE_KB = $maxPayloadSize

# Display configuration summary
Write-Host "`nServer Configuration Summary:" -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor Cyan
Write-Host "Server Port: $port"
Write-Host "Max Connection Idle: $maxIdle seconds"
Write-Host "Max Connection Age: $maxAge seconds"
Write-Host "Max Connection Age Grace: $maxGrace seconds"
Write-Host "Keepalive Time: $keepAliveTime seconds"
Write-Host "Keepalive Timeout: $keepAliveTimeout seconds"
Write-Host "Response Delay: $responseDelay ms"
Write-Host "Max Payload Size: $maxPayloadSize KB"
Write-Host "--------------------------------`n" -ForegroundColor Cyan

# Run the server
Write-Host "Starting gRPC test server..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop the server.`n" -ForegroundColor Yellow

try {
    & "bin\server.exe"
}
catch {
    Write-Host "Error starting server: $_" -ForegroundColor Red
    exit 1
}
