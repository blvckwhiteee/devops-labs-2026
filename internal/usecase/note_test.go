package usecase_test

import (
	"context"
	"errors"
	"testing"

	"lab1/internal/domain"
	"lab1/internal/usecase"
)

// mockRepo is a simple in-memory stub that satisfies domain.NoteRepository.
type mockRepo struct {
	notes     []domain.Note
	nextID    int
	createErr error
}

func newMockRepo() *mockRepo {
	return &mockRepo{nextID: 1}
}

func (m *mockRepo) Create(_ context.Context, note *domain.Note) error {
	if m.createErr != nil {
		return m.createErr
	}
	note.ID = m.nextID
	m.nextID++
	m.notes = append(m.notes, *note)
	return nil
}

func (m *mockRepo) GetAll(_ context.Context) ([]domain.Note, error) {
	return m.notes, nil
}

func (m *mockRepo) GetByID(_ context.Context, id int) (*domain.Note, error) {
	for _, n := range m.notes {
		if n.ID == id {
			cp := n
			return &cp, nil
		}
	}
	return nil, errors.New("not found")
}

func (m *mockRepo) Ping(_ context.Context) error {
	return nil
}

func TestCreateNote(t *testing.T) {
	uc := usecase.NewNoteUsecase(newMockRepo())

	note, err := uc.CreateNote(context.Background(), "Title", "Content")

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if note.Title != "Title" {
		t.Errorf("expected title %q, got %q", "Title", note.Title)
	}
	if note.Content != "Content" {
		t.Errorf("expected content %q, got %q", "Content", note.Content)
	}
	if note.ID == 0 {
		t.Error("expected ID to be assigned")
	}
	if note.CreatedAt.IsZero() {
		t.Error("expected CreatedAt to be set")
	}
}

func TestCreateNote_EmptyTitle(t *testing.T) {
	uc := usecase.NewNoteUsecase(newMockRepo())

	_, err := uc.CreateNote(context.Background(), "", "Content")

	if err == nil {
		t.Error("expected error when title is empty")
	}
}

func TestCreateNote_EmptyContent(t *testing.T) {
	uc := usecase.NewNoteUsecase(newMockRepo())

	note, err := uc.CreateNote(context.Background(), "Title", "")

	if err != nil {
		t.Fatalf("empty content should be allowed, got error: %v", err)
	}
	if note.Content != "" {
		t.Errorf("expected empty content, got %q", note.Content)
	}
}

func TestCreateNote_RepoError(t *testing.T) {
	repo := newMockRepo()
	repo.createErr = errors.New("storage failure")
	uc := usecase.NewNoteUsecase(repo)

	_, err := uc.CreateNote(context.Background(), "Title", "Body")

	if err == nil {
		t.Error("expected error when repo fails")
	}
}

func TestGetNotes_Empty(t *testing.T) {
	uc := usecase.NewNoteUsecase(newMockRepo())

	notes, err := uc.GetNotes(context.Background())

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(notes) != 0 {
		t.Errorf("expected 0 notes, got %d", len(notes))
	}
}

func TestGetNotes(t *testing.T) {
	uc := usecase.NewNoteUsecase(newMockRepo())
	uc.CreateNote(context.Background(), "First", "")
	uc.CreateNote(context.Background(), "Second", "")
	uc.CreateNote(context.Background(), "Third", "")

	notes, err := uc.GetNotes(context.Background())

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(notes) != 3 {
		t.Errorf("expected 3 notes, got %d", len(notes))
	}
}

func TestGetNoteByID(t *testing.T) {
	uc := usecase.NewNoteUsecase(newMockRepo())
	created, _ := uc.CreateNote(context.Background(), "Hello", "World")

	got, err := uc.GetNoteByID(context.Background(), created.ID)

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Title != "Hello" {
		t.Errorf("expected title %q, got %q", "Hello", got.Title)
	}
	if got.Content != "World" {
		t.Errorf("expected content %q, got %q", "World", got.Content)
	}
}

func TestGetNoteByID_NotFound(t *testing.T) {
	uc := usecase.NewNoteUsecase(newMockRepo())

	_, err := uc.GetNoteByID(context.Background(), 9999)

	if err == nil {
		t.Error("expected error for non-existent note")
	}
}

func TestGetNoteByID_CorrectNote(t *testing.T) {
	uc := usecase.NewNoteUsecase(newMockRepo())
	uc.CreateNote(context.Background(), "First", "")
	second, _ := uc.CreateNote(context.Background(), "Second", "specific")
	uc.CreateNote(context.Background(), "Third", "")

	got, err := uc.GetNoteByID(context.Background(), second.ID)

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Title != "Second" {
		t.Errorf("fetched wrong note: expected %q, got %q", "Second", got.Title)
	}
}
