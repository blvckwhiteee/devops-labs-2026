package repository_test

import (
	"context"
	"sync"
	"testing"

	"lab1/internal/domain"
	"lab1/internal/repository"
)

func TestMemoryRepository_Create(t *testing.T) {
	repo := repository.NewMemoryRepository()
	note := &domain.Note{Title: "Test", Content: "Body"}

	err := repo.Create(context.Background(), note)

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if note.ID == 0 {
		t.Error("expected ID to be assigned after Create")
	}
}

func TestMemoryRepository_Create_AutoIncrement(t *testing.T) {
	repo := repository.NewMemoryRepository()
	ctx := context.Background()

	n1 := &domain.Note{Title: "First"}
	n2 := &domain.Note{Title: "Second"}
	if err := repo.Create(ctx, n1); err != nil {
		t.Fatalf("setup: %v", err)
	}
	if err := repo.Create(ctx, n2); err != nil {
		t.Fatalf("setup: %v", err)
	}

	if n1.ID == n2.ID {
		t.Error("expected distinct IDs for different notes")
	}
	if n2.ID != n1.ID+1 {
		t.Errorf("expected sequential IDs, got %d and %d", n1.ID, n2.ID)
	}
}

func TestMemoryRepository_GetAll_Empty(t *testing.T) {
	repo := repository.NewMemoryRepository()

	notes, err := repo.GetAll(context.Background())

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(notes) != 0 {
		t.Errorf("expected 0 notes, got %d", len(notes))
	}
}

func TestMemoryRepository_GetAll(t *testing.T) {
	repo := repository.NewMemoryRepository()
	ctx := context.Background()
	if err := repo.Create(ctx, &domain.Note{Title: "A"}); err != nil {
		t.Fatalf("setup: %v", err)
	}
	if err := repo.Create(ctx, &domain.Note{Title: "B"}); err != nil {
		t.Fatalf("setup: %v", err)
	}
	if err := repo.Create(ctx, &domain.Note{Title: "C"}); err != nil {
		t.Fatalf("setup: %v", err)
	}

	notes, err := repo.GetAll(ctx)

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(notes) != 3 {
		t.Errorf("expected 3 notes, got %d", len(notes))
	}
}

func TestMemoryRepository_GetAll_IsolatesCopy(t *testing.T) {
	repo := repository.NewMemoryRepository()
	ctx := context.Background()
	if err := repo.Create(ctx, &domain.Note{Title: "Original"}); err != nil {
		t.Fatalf("setup: %v", err)
	}

	notes, _ := repo.GetAll(ctx)
	notes[0].Title = "Mutated"

	notes2, _ := repo.GetAll(ctx)
	if notes2[0].Title == "Mutated" {
		t.Error("GetAll should return copies, not references to internal state")
	}
}

func TestMemoryRepository_GetByID(t *testing.T) {
	repo := repository.NewMemoryRepository()
	ctx := context.Background()
	original := &domain.Note{Title: "Hello", Content: "World"}
	if err := repo.Create(ctx, original); err != nil {
		t.Fatalf("setup: %v", err)
	}

	got, err := repo.GetByID(ctx, original.ID)

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Title != original.Title {
		t.Errorf("expected title %q, got %q", original.Title, got.Title)
	}
	if got.Content != original.Content {
		t.Errorf("expected content %q, got %q", original.Content, got.Content)
	}
}

func TestMemoryRepository_GetByID_NotFound(t *testing.T) {
	repo := repository.NewMemoryRepository()

	_, err := repo.GetByID(context.Background(), 9999)

	if err == nil {
		t.Error("expected error when note does not exist")
	}
}

func TestMemoryRepository_GetByID_IsolatesCopy(t *testing.T) {
	repo := repository.NewMemoryRepository()
	ctx := context.Background()
	original := &domain.Note{Title: "Original"}
	if err := repo.Create(ctx, original); err != nil {
		t.Fatalf("setup: %v", err)
	}

	got, _ := repo.GetByID(ctx, original.ID)
	got.Title = "Mutated"

	got2, _ := repo.GetByID(ctx, original.ID)
	if got2.Title == "Mutated" {
		t.Error("GetByID should return a copy, not a reference to internal state")
	}
}

func TestMemoryRepository_Ping(t *testing.T) {
	repo := repository.NewMemoryRepository()

	if err := repo.Ping(context.Background()); err != nil {
		t.Errorf("Ping should always return nil, got %v", err)
	}
}

func TestMemoryRepository_Concurrent(t *testing.T) {
	repo := repository.NewMemoryRepository()
	ctx := context.Background()
	const n = 50

	var wg sync.WaitGroup
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := repo.Create(ctx, &domain.Note{Title: "concurrent"}); err != nil {
				t.Errorf("unexpected error during concurrent Create: %v", err)
				return
			}
		}()
	}
	wg.Wait()

	notes, err := repo.GetAll(ctx)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(notes) != n {
		t.Errorf("expected %d notes after concurrent creates, got %d", n, len(notes))
	}
}
