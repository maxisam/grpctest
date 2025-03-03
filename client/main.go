package main

import (
	"context"
	"fmt"
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

// getEnvBool reads an environment variable and returns a bool with default value
func getEnvBool(key string, defaultVal bool) bool {
	val, exists := os.LookupEnv(key)
	if !exists {
		return defaultVal
	}
	if val == "true" || val == "1" || val == "yes" {
		return true
	}
	if val == "false" || val == "0" || val == "no" {
		return false
	}
	log.Printf("Warning: Invalid value for %s, using default: %v", key, defaultVal)
	return defaultVal
}

// getEnvFloat reads an environment variable and returns a float with default value
func getEnvFloat(key string, defaultVal float64) float64 {
	val, exists := os.LookupEnv(key)
	if !exists {
		return defaultVal
	}
	floatVal, err := strconv.ParseFloat(val, 64)
	if err != nil {
		log.Printf("Warning: Invalid value for %s, using default: %f", key, defaultVal)
		return defaultVal
	}
	return floatVal
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

	permitWithoutStream := getEnvBool("PERMIT_WITHOUT_STREAM", false)
	pingInterval := getEnvInt("PING_INTERVAL_SEC", 2)

	// Read payload-related parameters
	usePayload := getEnvBool("USE_PAYLOAD", false)
	payloadSizeKB := getEnvFloat("PAYLOAD_SIZE_KB", 1024) // Default to 1MB
	timeoutSec := getEnvInt("REQUEST_TIMEOUT_SEC", 100)

	kaParams := keepalive.ClientParameters{
		Time:                time.Duration(keepAliveTime) * time.Second,
		Timeout:             time.Duration(keepAliveTimeout) * time.Second,
		PermitWithoutStream: permitWithoutStream,
	}

	log.Printf("Client connecting to %s with keepalive params: time=%ds, timeout=%ds, permitWithoutStream=%v",
		serverAddr, keepAliveTime, keepAliveTimeout, permitWithoutStream)

	if usePayload {
		log.Printf("Using payload mode with size: %.2f KB", payloadSizeKB)
	}

	conn, err := grpc.Dial(serverAddr,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithKeepaliveParams(kaParams))
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()

	client := pb.NewPingServiceClient(conn)

	for {
		if usePayload {
			sendPayloadRequest(client, payloadSizeKB, timeoutSec)
		} else {
			sendPingRequest(client, timeoutSec)
		}
		time.Sleep(time.Duration(pingInterval) * time.Second)
	}
}

func sendPingRequest(client pb.PingServiceClient, timeoutSec int) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutSec)*time.Second)
	defer cancel()

	startTime := time.Now()
	resp, err := client.Ping(ctx, &pb.PingRequest{Message: "Hello"})
	duration := time.Since(startTime)

	if err != nil {
		log.Printf("could not ping: %v", err)
	} else {
		log.Printf("Response: %s (timestamp: %d, server delay: %dms, round-trip: %dms)",
			resp.Message, resp.Timestamp, resp.DelayMs, duration.Milliseconds())
	}
}

func sendPayloadRequest(client pb.PingServiceClient, sizeKB float64, timeoutSec int) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutSec)*time.Second)
	defer cancel()

	startTime := time.Now()
	resp, err := client.PingWithPayload(ctx, &pb.PayloadRequest{
		Message: fmt.Sprintf("Request %.2fKB payload", sizeKB),
		SizeKb:  float32(sizeKB),
	})
	duration := time.Since(startTime)

	if err != nil {
		log.Printf("could not request payload: %v", err)
	} else {
		log.Printf("Payload Response: %s (size: %.2fKB, server delay: %dms, round-trip: %dms)",
			resp.Message, resp.SizeKb, resp.DelayMs, duration.Milliseconds())
	}
}
