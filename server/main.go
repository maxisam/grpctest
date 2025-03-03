package main

import (
	"context"
	"log"
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

func (s *server) Ping(ctx context.Context, req *pb.PingRequest) (*pb.PingResponse, error) {
	log.Printf("Received ping: %v", req.Message)
	return &pb.PingResponse{
		Message:   "Pong: " + req.Message,
		Timestamp: time.Now().Unix(),
	}, nil
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

func main() {
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

	kaParams := keepalive.ServerParameters{
		MaxConnectionIdle:     time.Duration(maxIdle) * time.Second,
		MaxConnectionAge:      time.Duration(maxAge) * time.Second,
		MaxConnectionAgeGrace: time.Duration(maxGrace) * time.Second,
		Time:                  time.Duration(keepAliveTime) * time.Second,
		Timeout:               time.Duration(keepAliveTimeout) * time.Second,
	}

	log.Printf("Server starting with keepalive params: idle=%ds, age=%ds, grace=%ds, time=%ds, timeout=%ds",
		maxIdle, maxAge, maxGrace, keepAliveTime, keepAliveTimeout)

	s := grpc.NewServer(grpc.KeepaliveParams(kaParams))
	pb.RegisterPingServiceServer(s, &server{})
	log.Printf("Server listening at %v", lis.Addr())
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
