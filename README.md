# gRPC Test with Keep-Alive

This is a simple gRPC test project demonstrating client-server communication with keep-alive functionality, containerization, and Kubernetes deployment with security best practices.

## Prerequisites

- Go 1.24 or later
- Protocol Buffers compiler (protoc)
  - Download from: https://github.com/protocolbuffers/protobuf/releases
  - Add protoc to your system PATH
- Go plugins for Protocol Buffers
- Docker (for containerization)
- Kubernetes cluster (for deployment)
- NGINX Ingress Controller (for Kubernetes gRPC routing)

## Project Structure

```
.
├── ping.proto              # Protocol Buffers definition
├── server/                 # Server implementation
│   └── main.go
├── client/                 # Client implementation
│   └── main.go
├── k8s/                    # Kubernetes manifests
│   ├── server-deployment.yaml
│   ├── client-deployment.yaml
│   └── ingress.yaml
├── Dockerfile.server       # Server container definition
├── Dockerfile.client       # Client container definition
├── docker-compose.yaml     # Local development setup
├── .dockerignore           # Docker build exclusions
├── .gitignore              # Git exclusions
├── go.mod                  # Go module definition
├── go.sum                  # Go dependencies checksums
└── setup.ps1               # Automated setup script
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

To set up Kubernetes manifests:
```
.\setup.ps1 -BuildK8s
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

## Security Features

The Docker images and Kubernetes deployments include the following security features:

- Non-root user execution (UID 10001)
- Read-only root filesystem
- Dropped capabilities
- SecurityContext settings for Pod Security Standards compliance
- Secure defaults for resource limits and requests

## Kubernetes Deployment

1. Push images to a registry accessible by your Kubernetes cluster:
```
docker tag grpctest-server:latest your-registry/grpctest-server:latest
docker tag grpctest-client:latest your-registry/grpctest-client:latest
docker push your-registry/grpctest-server:latest
docker push your-registry/grpctest-client:latest
```

2. Update the image references in k8s/server-deployment.yaml and k8s/client-deployment.yaml with your registry path.

3. Apply the configurations:
```
kubectl apply -f k8s/
```

4. The server is exposed via an Ingress controller at the hostname specified in the ingress manifest (c-grpc-test-server.company.com).

## gRPC Keep-Alive Configuration

Both server and client include configurable keep-alive parameters to maintain persistent connections. These can be adjusted via environment variables.

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

## Troubleshooting

### Common Issues:

1. **Connection Refused**: Ensure the server is running and the client's SERVER_ADDR is correctly pointing to it.

2. **Pod Security Violations**: The Kubernetes manifests are configured to run with restricted Pod Security Standards. If your cluster enforces different standards, adjust the SecurityContext settings accordingly.

3. **Ingress Issues**: Make sure the NGINX Ingress Controller is configured to support gRPC traffic.

4. **Image Pull Errors**: Ensure your container registry is accessible from the Kubernetes cluster and that image names are correctly referenced.

## License

This project is made available under the MIT License.
