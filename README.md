# gRPC Test with Keep-Alive

This is a simple gRPC test project demonstrating client-server communication with keep-alive functionality.

## Prerequisites

- Go 1.24 or later
- Protocol Buffers compiler (protoc)
  - Download from: https://github.com/protocolbuffers/protobuf/releases
  - Add protoc to your system PATH
- Go plugins for Protocol Buffers


## Project Structure

```
.
├── ping.proto
├── server/
│   └── main.go
├── client/
│   └── main.go
├── k8s/
│   ├── server-deployment.yaml
│   ├── client-deployment.yaml
│   └── ingress.yaml
├── Dockerfile.server
├── Dockerfile.client
├── docker-compose.yaml
└── setup.ps1
```

## Manual Setup

1. Install required Go packages:
   ```
   go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
   go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
   ```

2. Generate gRPC code:
   ```
   protoc --go_out=. --go_opt=paths=source_relative --go-grpc_out=. --go-grpc_opt=paths=source_relative ping.proto
   ```

3. Run the server:
   ```
   go run server/main.go
   ```

4. In another terminal, run the client:
   ```
   go run client/main.go
   ```

## Automated Setup

Run the provided PowerShell script:
```
.\setup.ps1
```

This will set up the project, generate the gRPC code, and build the binaries.

To build Docker containers as well:
```
.\setup.ps1 -BuildContainers
```

## Docker Setup

Build and run using Docker Compose:
```
docker-compose up
```

Build images individually:
```
docker build -f Dockerfile.server -t grpctest-server:latest .
docker build -f Dockerfile.client -t grpctest-client:latest .
```

Run containers individually:
```
docker run -p 50051:50051 grpctest-server:latest
docker run -e SERVER_ADDR=host.docker.internal:50051 grpctest-client:latest
```

## Kubernetes Deployment

1. Push images to a registry accessible by your Kubernetes cluster:
```
docker tag grpctest-server:latest your-registry/grpctest-server:latest
docker tag grpctest-client:latest your-registry/grpctest-client:latest
docker push your-registry/grpctest-server:latest
docker push your-registry/grpctest-client:latest
```

2. Update the image references in k8s/server-deployment.yaml and k8s/client-deployment.yaml

3. Apply the configurations:
```
kubectl apply -f k8s/
```

## Environment Variables

### Server:
- SERVER_PORT: Port for the gRPC server (default: 50051)
- MAX_CONN_IDLE_SEC: Max idle time in seconds (default: 15)
- MAX_CONN_AGE_SEC: Max connection age in seconds (default: 30)
- MAX_CONN_AGE_GRACE_SEC: Grace period for max age in seconds (default: 5)
- KEEPALIVE_TIME_SEC: Keepalive time in seconds (default: 5)
- KEEPALIVE_TIMEOUT_SEC: Keepalive timeout in seconds (default: 1)

### Client:
- SERVER_ADDR: Address of the gRPC server (default: localhost:50051)
- KEEPALIVE_TIME_SEC: Keepalive time in seconds (default: 10)
- KEEPALIVE_TIMEOUT_SEC: Keepalive timeout in seconds (default: 2)
- PERMIT_WITHOUT_STREAM: Permit keepalive without streams (default: true)
- PING_INTERVAL_SEC: Interval between pings in seconds (default: 2)
