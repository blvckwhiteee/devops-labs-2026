package domain

import (
	"context"
	"time"
)

type Note struct {
	ID        int       `json:"id"`
	Title     string    `json:"title"`
	Content   string    `json:"content,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

type NoteRepository interface {
	Create(ctx context.Context, note *Note) error
	GetAll(ctx context.Context) ([]Note, error)
	GetByID(ctx context.Context, id int) (*Note, error)
	Ping(ctx context.Context) error
}

type NoteUsecase interface {
	CreateNote(ctx context.Context, title, content string) (*Note, error)
	GetNotes(ctx context.Context) ([]Note, error)
	GetNoteByID(ctx context.Context, id int) (*Note, error)
}
