package main

import (
	"database/sql"
	"flag"
	"log"

	_ "github.com/go-sql-driver/mysql"
)

func main() {
	dbDSN := flag.String("db", "", "Database connection string")
	flag.Parse()

	if *dbDSN == "" {
		log.Fatal("DB DSN is required. Usage: -db \"user:pass@tcp(host:port)/dbname\"")
	}

	log.Println("Connecting to the database for migration...")
	db, err := sql.Open("mysql", *dbDSN)
	if err != nil {
		log.Fatalf("Failed to open DB: %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatalf("Database is not reachable: %v", err)
	}

	log.Println("Running migrations...")

	query := `
	CREATE TABLE IF NOT EXISTS notes (
		id INT AUTO_INCREMENT PRIMARY KEY,
		title VARCHAR(255) NOT NULL,
		content TEXT,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);`

	_, err = db.Exec(query)
	if err != nil {
		log.Fatalf("Failed to create table 'notes': %v", err)
	}

	log.Println("Migration completed successfully!")
}
