package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/joho/godotenv"
	handler "github.com/nicogaller/gradebee/backend"
)

func main() {
	// Load .env from project root when running locally (../.env relative to backend/)
	if err := godotenv.Load("../.env"); err != nil && !os.IsNotExist(err) {
		log.Printf("warning: loading .env: %v", err)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	fmt.Printf("Listening on :%s\n", port)
	if err := http.ListenAndServe(":"+port, http.HandlerFunc(handler.Handle)); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
