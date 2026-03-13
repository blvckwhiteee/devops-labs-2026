package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	_ "github.com/go-sql-driver/mysql" // Додали драйвер сюди

	delivery "lab1/internal/delivery/http"
	"lab1/internal/domain"
	"lab1/internal/repository"
	"lab1/internal/usecase"
)

func main() {
	port := flag.String("port", "3000", "Port to run the application on")
	dbDSN := flag.String("db", "dummy-memory-dsn", "Database connection string")
	flag.Parse()

	log.Printf("Starting mywebapp with DB: %s", *dbDSN)

	// Вибір репозиторію
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

	// Dependency Injection
	noteUsecase := usecase.NewNoteUsecase(repo)
	handler := delivery.NewHandler(noteUsecase, repo)

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	handler.InitRoutes(r)

	addr := fmt.Sprintf(":%s", *port)
	log.Printf("Listening on %s...", addr)

	if err := http.ListenAndServe(addr, r); err != nil {
		log.Fatalf("Server stopped: %v", err)
	}
}
