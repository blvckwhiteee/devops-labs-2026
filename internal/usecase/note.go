package usecase

import (
	"context"
	"errors"
	"time"

	"lab1/internal/domain"
)

type noteUsecase struct {
	repo domain.NoteRepository
}

func NewNoteUsecase(repo domain.NoteRepository) domain.NoteUsecase {
	return &noteUsecase{repo: repo}
}

func (u *noteUsecase) CreateNote(ctx context.Context, title, content string) (*domain.Note, error) {
	if title == "" {
		return nil, errors.New("title cannot be empty")
	}

	note := &domain.Note{
		Title:     title,
		Content:   content,
		CreatedAt: time.Now(),
	}

	if err := u.repo.Create(ctx, note); err != nil {
		return nil, err
	}

	return note, nil
}

func (u *noteUsecase) GetNotes(ctx context.Context) ([]domain.Note, error) {
	return u.repo.GetAll(ctx)
}

func (u *noteUsecase) GetNoteByID(ctx context.Context, id int) (*domain.Note, error) {
	return u.repo.GetByID(ctx, id)
}
