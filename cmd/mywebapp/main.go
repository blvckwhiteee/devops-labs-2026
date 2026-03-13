package main

import (
	"database/sql"
	"flag"
	"fmt"
	"lab1/internal/domain"
	"log"
	"net"
	"net/http"

	"github.com/coreos/go-systemd/v22/activation"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	_ "github.com/go-sql-driver/mysql"

	delivery "lab1/internal/delivery/http"
	"lab1/internal/repository"
	"lab1/internal/usecase"
)

func main() {
	port := flag.String("port", "3000", "Port to run the application on")
	dbDSN := flag.String("db", "dummy-memory-dsn", "Database connection string")
	flag.Parse()

	log.Printf("Starting mywebapp with DB: %s", *dbDSN)

	var repo domain.NoteRepository
	if *dbDSN == "dummy-memory-dsn" {
		log.Println("Using In-Memory Database")
		repo = repository.NewMemoryRepository()
	} else {
		log.Println("Using MariaDB")
		db, err := sql.Open("mysql", *dbDSN)
		if err != nil {
			log.Fatalf("Failed to open database: %v", err)
		}
		defer db.Close()
		repo = repository.NewMariaDBRepository(db)
	}

	noteUsecase := usecase.NewNoteUsecase(repo)
	handler := delivery.NewHandler(noteUsecase, repo)

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	handler.InitRoutes(r)

	listeners, err := activation.Listeners()
	if err != nil {
		log.Fatalf("Failed to get systemd listeners: %v", err)
	}

	var listener net.Listener
	if len(listeners) > 0 {
		log.Println("Using Systemd Socket Activation")
		listener = listeners[0]
	} else {
		addr := fmt.Sprintf("127.0.0.1:%s", *port)
		log.Printf("Listening on %s (manual fallback)...", addr)
		listener, err = net.Listen("tcp", addr)
		if err != nil {
			log.Fatalf("Failed to listen: %v", err)
		}
	}

	if err := http.Serve(listener, r); err != nil {
		log.Fatalf("Server stopped: %v", err)
	}
}
