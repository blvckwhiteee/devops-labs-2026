package repository

import (
	"context"
	"errors"
	"sync"

	"lab1/internal/domain"
)

type memoryRepo struct {
	mu    sync.RWMutex
	notes map[int]*domain.Note
	seq   int
}

func NewMemoryRepository() domain.NoteRepository {
	return &memoryRepo{
		notes: make(map[int]*domain.Note),
		seq:   1,
	}
}

func (r *memoryRepo) Create(ctx context.Context, note *domain.Note) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	note.ID = r.seq
	r.seq++
	noteCopy := *note
	r.notes[note.ID] = &noteCopy
	return nil
}

func (r *memoryRepo) GetAll(ctx context.Context) ([]domain.Note, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var list []domain.Note
	for _, n := range r.notes {
		list = append(list, domain.Note{ID: n.ID, Title: n.Title, Content: n.Content, CreatedAt: n.CreatedAt})
	}
	return list, nil
}

func (r *memoryRepo) GetByID(ctx context.Context, id int) (*domain.Note, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	note, exists := r.notes[id]
	if !exists {
		return nil, errors.New("note not found")
	}
	noteCopy := *note
	return &noteCopy, nil
}

func (r *memoryRepo) Ping(ctx context.Context) error {
	return nil
}
