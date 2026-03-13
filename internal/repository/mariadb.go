package repository

import (
	"context"
	"database/sql"
	"errors"

	"lab1/internal/domain"

	_ "github.com/go-sql-driver/mysql"
)

type mariaDBRepo struct {
	db *sql.DB
}

func NewMariaDBRepository(db *sql.DB) domain.NoteRepository {
	return &mariaDBRepo{db: db}
}

func (r *mariaDBRepo) Create(ctx context.Context, note *domain.Note) error {
	query := `INSERT INTO notes (title, content, created_at) VALUES (?, ?, ?)`

	result, err := r.db.ExecContext(ctx, query, note.Title, note.Content, note.CreatedAt)
	if err != nil {
		return err
	}

	id, err := result.LastInsertId()
	if err != nil {
		return err
	}

	note.ID = int(id)
	return nil
}

func (r *mariaDBRepo) GetAll(ctx context.Context) ([]domain.Note, error) {
	query := `SELECT id, title FROM notes`
	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notes []domain.Note
	for rows.Next() {
		var n domain.Note
		if err := rows.Scan(&n.ID, &n.Title); err != nil {
			return nil, err
		}
		notes = append(notes, n)
	}
	return notes, nil
}

func (r *mariaDBRepo) GetByID(ctx context.Context, id int) (*domain.Note, error) {
	query := `SELECT id, title, content, created_at FROM notes WHERE id = ?`
	row := r.db.QueryRowContext(ctx, query, id)

	var n domain.Note
	var content sql.NullString

	err := row.Scan(&n.ID, &n.Title, &content, &n.CreatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, errors.New("note not found")
		}
		return nil, err
	}

	n.Content = content.String
	return &n, nil
}

func (r *mariaDBRepo) Ping(ctx context.Context) error {
	return r.db.PingContext(ctx)
}
