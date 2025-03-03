package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"net"
	"os"
	"strconv"
	"time"

	pb "grpctest" // Import from the module root, not a subdirectory

	"google.golang.org/grpc"
	"google.golang.org/grpc/keepalive"
)

type server struct {
	pb.UnimplementedPingServiceServer
}

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

// getEnvIntRange reads an environment variable as a range (min-max) and returns a random value in that range
func getEnvIntRange(key string, defaultMin, defaultMax int) int {
	val, exists := os.LookupEnv(key)
	if !exists {
		// Use random value between defaults
		return defaultMin + rand.Intn(defaultMax-defaultMin+1)
	}

	// Try to parse as range "min-max"
	var min, max int
	n, err := fmt.Sscanf(val, "%d-%d", &min, &max)
	if err == nil && n == 2 && min <= max {
		return min + rand.Intn(max-min+1)
	}

	// Try to parse as fixed value
	fixed, err := strconv.Atoi(val)
	if err == nil {
		return fixed
	}

	log.Printf("Warning: Invalid value for %s, using default range: %d-%d", key, defaultMin, defaultMax)
	return defaultMin + rand.Intn(defaultMax-defaultMin+1)
}

func (s *server) Ping(ctx context.Context, req *pb.PingRequest) (*pb.PingResponse, error) {
	// Get configured delay from environment or use default
	delayMs := getEnvIntRange("RESPONSE_DELAY_MS", 0, 100)

	log.Printf("Received ping: %v (delaying %dms)", req.Message, delayMs)

	// Simulate processing delay
	time.Sleep(time.Duration(delayMs) * time.Millisecond)

	return &pb.PingResponse{
		Message:   "Pong: " + req.Message,
		Timestamp: time.Now().Unix(),
		DelayMs:   int32(delayMs),
	}, nil
}

func (s *server) PingWithPayload(ctx context.Context, req *pb.PayloadRequest) (*pb.PayloadResponse, error) {
	// Get configured delay from environment or use default
	delayMs := getEnvIntRange("RESPONSE_DELAY_MS", 0, 100)

	// Get max payload size from environment or use default (5MB)
	maxPayloadKB := getEnvFloat("MAX_PAYLOAD_SIZE_KB", 5*1024)

	// Limit requested size to max configured size
	requestedSizeKB := float64(req.SizeKb)
	if requestedSizeKB <= 0 {
		// Default to 1MB if not specified
		requestedSizeKB = 1024
	}

	actualSizeKB := requestedSizeKB
	if actualSizeKB > maxPayloadKB {
		log.Printf("Requested payload size %.2fKB exceeds maximum %.2fKB, capping", requestedSizeKB, maxPayloadKB)
		actualSizeKB = maxPayloadKB
	}

	log.Printf("Received payload request: %v, size: %.2fKB (delaying %dms)",
		req.Message, actualSizeKB, delayMs)

	// Generate payload of specified size - convert KB to bytes with proper rounding
	payloadSize := int(actualSizeKB * 1024)
	payload := make([]byte, payloadSize)

	// Fill with pseudo-random data
	rand.Read(payload)

	// Simulate processing delay
	time.Sleep(time.Duration(delayMs) * time.Millisecond)

	return &pb.PayloadResponse{
		Message:   "Payload response: " + req.Message,
		Timestamp: time.Now().Unix(),
		SizeKb:    float32(actualSizeKB),
		DelayMs:   int32(delayMs),
		Payload:   payload,
	}, nil
}

func main() {
	// Initialize random seed
	rand.Seed(time.Now().UnixNano())

	port := os.Getenv("SERVER_PORT")
	if port == "" {
		port = "50051"
	}

	address := ":" + port
	lis, err := net.Listen("tcp", address)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	// Read keepalive parameters from environment variables
	maxIdle := getEnvInt("MAX_CONN_IDLE_SEC", 15)
	maxAge := getEnvInt("MAX_CONN_AGE_SEC", 30)
	maxGrace := getEnvInt("MAX_CONN_AGE_GRACE_SEC", 5)
	keepAliveTime := getEnvInt("KEEPALIVE_TIME_SEC", 5)
	keepAliveTimeout := getEnvInt("KEEPALIVE_TIMEOUT_SEC", 1)

	// Read performance-related parameters
	maxPayloadKB := getEnvFloat("MAX_PAYLOAD_SIZE_KB", 5*1024)
	delayRange := os.Getenv("RESPONSE_DELAY_MS")
	if delayRange == "" {
		delayRange = "0-100"
	}

	kaParams := keepalive.ServerParameters{
		MaxConnectionIdle:     time.Duration(maxIdle) * time.Second,
		MaxConnectionAge:      time.Duration(maxAge) * time.Second,
		MaxConnectionAgeGrace: time.Duration(maxGrace) * time.Second,
		Time:                  time.Duration(keepAliveTime) * time.Second,
		Timeout:               time.Duration(keepAliveTimeout) * time.Second,
	}

	log.Printf("Server starting with keepalive params: idle=%ds, age=%ds, grace=%ds, time=%ds, timeout=%ds",
		maxIdle, maxAge, maxGrace, keepAliveTime, keepAliveTimeout)
	log.Printf("Performance config: max_payload=%.2fKB, delay_range=%s",
		maxPayloadKB, delayRange)

	s := grpc.NewServer(grpc.KeepaliveParams(kaParams))
	pb.RegisterPingServiceServer(s, &server{})
	log.Printf("Server listening at %v", lis.Addr())
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
