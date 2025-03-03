package main

import (
	"context"
	"log"
	"os"
	"strconv"
	"time"

	pb "grpctest" // Import from the module root, not a subdirectory

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/keepalive"
)

// getEnvInt reads an environment variable and returns an int with default value
func getEnvInt(key string, defaultVal int) int {
	val, exists := os.LookupEnv(key)
	if !exists {
		return defaultVal
	}
	intVal, err := strconv.Atoi(val)
	if err != nil {
		log.Printf("Warning: Invalid value for %s, using default: %d", key, defaultVal)
		return defaultVal
	}
	return intVal
}

func main() {
	// Read server address from environment variable or use default
	serverAddr := os.Getenv("SERVER_ADDR")
	if serverAddr == "" {
		serverAddr = "localhost:50051"
	}

	// Read keepalive parameters from environment variables
	keepAliveTime := getEnvInt("KEEPALIVE_TIME_SEC", 10)
	keepAliveTimeout := getEnvInt("KEEPALIVE_TIMEOUT_SEC", 2)

	permitWithoutStream := true
	if os.Getenv("PERMIT_WITHOUT_STREAM") == "false" {
		permitWithoutStream = false
	}

	pingInterval := getEnvInt("PING_INTERVAL_SEC", 2)

	kaParams := keepalive.ClientParameters{
		Time:                time.Duration(keepAliveTime) * time.Second,
		Timeout:             time.Duration(keepAliveTimeout) * time.Second,
		PermitWithoutStream: permitWithoutStream,
	}

	log.Printf("Client connecting to %s with keepalive params: time=%ds, timeout=%ds, permitWithoutStream=%v",
		serverAddr, keepAliveTime, keepAliveTimeout, permitWithoutStream)

	conn, err := grpc.Dial(serverAddr,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithKeepaliveParams(kaParams))
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()

	client := pb.NewPingServiceClient(conn)

	for {
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		resp, err := client.Ping(ctx, &pb.PingRequest{Message: "Hello"})
		if err != nil {
			log.Printf("could not ping: %v", err)
		} else {
			log.Printf("Response: %s (timestamp: %d)", resp.Message, resp.Timestamp)
		}
		cancel()
		time.Sleep(time.Duration(pingInterval) * time.Second)
	}
}
