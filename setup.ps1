param(
    [switch]$BuildContainers,
    [switch]$BuildK8s
)

# Setup script for gRPC test project

# Set the working directory to where the script is located
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptPath

Write-Host "Setting up gRPC test project..." -ForegroundColor Green
Write-Host "Working directory: $(Get-Location)" -ForegroundColor Cyan

# Create directory structure
New-Item -ItemType Directory -Force -Path "server" | Out-Null
New-Item -ItemType Directory -Force -Path "client" | Out-Null
New-Item -ItemType Directory -Force -Path "bin" | Out-Null

# Handle Go module initialization
if (-not (Test-Path "go.mod")) {
    Write-Host "Initializing Go module..." -ForegroundColor Cyan
    go mod init grpctest
} else {
    Write-Host "Go module already exists, updating dependencies..." -ForegroundColor Yellow
}

# Install required packages and update PATH
Write-Host "Installing required packages..." -ForegroundColor Cyan
$env:GO111MODULE = "on"
$userGoPath = if ($env:GOPATH) { $env:GOPATH } else { "$env:USERPROFILE\go" }
$env:Path = "$userGoPath\bin;" + $env:Path
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
go mod tidy

# Verify protoc installation and plugin path
if (-not (Get-Command protoc -ErrorAction SilentlyContinue)) {
    Write-Host "Error: protoc not found. Please install Protocol Buffers compiler first." -ForegroundColor Red
    Write-Host "Visit: https://github.com/protocolbuffers/protobuf/releases" -ForegroundColor Red
    exit 1
}

Write-Host "Verifying Go bin directory:" -ForegroundColor Cyan
if (Test-Path "$userGoPath\bin\protoc-gen-go.exe") {
    Write-Host " - Found protoc-gen-go in $userGoPath\bin" -ForegroundColor Green
} else {
    Write-Host " - protoc-gen-go not found in $userGoPath\bin" -ForegroundColor Red
}

# Clean any previously generated gRPC code
if (Test-Path "ping") {
    Write-Host "Cleaning previous gRPC generated code..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force "ping" | Out-Null
}

# Generate gRPC code with proper module pathing
Write-Host "Generating gRPC code..." -ForegroundColor Cyan
$env:PATH = "$userGoPath\bin;" + $env:PATH

# Delete previously generated files (more comprehensive cleanup)
Get-ChildItem -Path "." -Include "*.pb.go" -Recurse | Remove-Item -Force
if (Test-Path "ping") {
    Remove-Item -Recurse -Force "ping" | Out-Null
}

$protoc_result = protoc --go_out=. --go_opt=paths=source_relative --go-grpc_out=. --go-grpc_opt=paths=source_relative ping.proto 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error generating gRPC code: $protoc_result" -ForegroundColor Red
    exit 1
}

# Provide more debugging info
Write-Host "Generated files:" -ForegroundColor Green
Get-ChildItem -Recurse -Filter "*.pb.go" | ForEach-Object { 
    Write-Host " - $($_.FullName)" -ForegroundColor Cyan
    Write-Host "   Content preview: $(Get-Content $_.FullName -TotalCount 10 | Out-String)" -ForegroundColor Gray
}

# Check go.mod contents
Write-Host "Current go.mod content:" -ForegroundColor Yellow
Get-Content go.mod

Write-Host "Current directory structure:" -ForegroundColor Cyan
Get-ChildItem -Recurse | Where-Object { -not $_.PSIsContainer } | ForEach-Object { Write-Host " - $($_.FullName)" }

# Run go mod tidy with verbose output
Write-Host "Running go mod tidy with verbose output..." -ForegroundColor Cyan
go mod tidy -v

# After generating gRPC code, ensure module dependencies are up-to-date
Write-Host "Ensuring module dependencies..." -ForegroundColor Cyan
go get -u google.golang.org/grpc
go get -u google.golang.org/protobuf
go mod tidy

Write-Host "Generated files:" -ForegroundColor Green
Get-ChildItem -Recurse -Filter "*.pb.go" | ForEach-Object { Write-Host " - $($_.FullName)" }

# Add docker build function
function Build-Docker {
    param(
        [string]$DockerfileName,
        [string]$ImageName
    )
    
    Write-Host "Building Docker image: $ImageName" -ForegroundColor Cyan
    docker build -f $DockerfileName -t $ImageName .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to build Docker image $ImageName" -ForegroundColor Red
        return $false
    }
    
    Write-Host "Successfully built Docker image: $ImageName" -ForegroundColor Green
    return $true
}

# Build the applications with module-aware mode
Write-Host "Building applications with verbose output..." -ForegroundColor Cyan
$Env:GO111MODULE = "on"

Write-Host "Building server..." -ForegroundColor Cyan
$buildOutput = go build -v -o bin/server.exe server/main.go 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build server application:" -ForegroundColor Red
    Write-Host $buildOutput -ForegroundColor Red
    
    Write-Host "Module information:" -ForegroundColor Yellow
    go list -m all
    exit 1
}

Write-Host "Building client..." -ForegroundColor Cyan
$buildOutput = go build -v -o bin/client.exe client/main.go 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build client application:" -ForegroundColor Red
    Write-Host $buildOutput -ForegroundColor Red
    exit 1
}

if ($BuildContainers) {
    # Check if Docker is available
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "Docker is not available. Skipping container builds." -ForegroundColor Yellow
    }
    else {
        Write-Host "Building Docker containers..." -ForegroundColor Cyan
        $serverBuilt = Build-Docker -DockerfileName "Dockerfile.server" -ImageName "grpctest-server:latest"
        $clientBuilt = Build-Docker -DockerfileName "Dockerfile.client" -ImageName "grpctest-client:latest"
        
        if ($serverBuilt -and $clientBuilt) {
            Write-Host "Both containers built successfully!" -ForegroundColor Green
        }
    }
}

if ($BuildK8s) {
    Write-Host "Kubernetes configuration files are available in the k8s directory." -ForegroundColor Cyan
    Write-Host "To deploy to Kubernetes:" -ForegroundColor Yellow
    Write-Host "  1. Ensure your Docker images are pushed to a registry accessible by your Kubernetes cluster" -ForegroundColor Yellow
    Write-Host "  2. Update the image references in k8s/server-deployment.yaml and k8s/client-deployment.yaml" -ForegroundColor Yellow
    Write-Host "  3. Apply the configurations with: kubectl apply -f k8s/" -ForegroundColor Yellow
}

Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "Run 'bin\server.exe' to start the server locally" -ForegroundColor Cyan
Write-Host "Run 'bin\client.exe' to start the client locally" -ForegroundColor Cyan
Write-Host "Run 'docker-compose up' to start the containerized application" -ForegroundColor Cyan
