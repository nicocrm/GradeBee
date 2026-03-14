package main

import (
	"fmt"
	"net/http"
	"os"

	"github.com/joho/godotenv"
	handler "github.com/nicogaller/gradebee/backend"
)

func main() {
	// Load .env from project root when running locally (../.env relative to backend/)
	_ = godotenv.Load("../.env")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	fmt.Printf("Listening on :%s\n", port)
	http.ListenAndServe(":"+port, http.HandlerFunc(handler.Handle))
}
