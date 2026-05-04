package http_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"

	deliveryhttp "lab1/internal/delivery/http"
	"lab1/internal/repository"
	"lab1/internal/usecase"
)

func newRouter() *chi.Mux {
	repo := repository.NewMemoryRepository()
	uc := usecase.NewNoteUsecase(repo)
	h := deliveryhttp.NewHandler(uc, repo)
	r := chi.NewRouter()
	h.InitRoutes(r)
	return r
}

// seedNote creates a note via POST and returns its assigned ID.
func seedNote(t *testing.T, r *chi.Mux, title, content string) int {
	t.Helper()
	body, _ := json.Marshal(map[string]string{"title": title, "content": content})
	req := httptest.NewRequest(http.MethodPost, "/notes/", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("seedNote: expected 201, got %d: %s", w.Code, w.Body.String())
	}
	var resp map[string]int
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("seedNote: failed to decode response: %v", err)
	}
	return resp["id"]
}

// --- Health endpoints ---

func TestAliveHandler(t *testing.T) {
	r := newRouter()
	req := httptest.NewRequest(http.MethodGet, "/health/alive", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestReadyHandler(t *testing.T) {
	r := newRouter()
	req := httptest.NewRequest(http.MethodGet, "/health/ready", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

// --- Root ---

func TestRootHandler(t *testing.T) {
	r := newRouter()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
	if !strings.Contains(w.Body.String(), "Notes API") {
		t.Errorf("expected body to contain 'Notes API', got: %s", w.Body.String())
	}
	ct := w.Header().Get("Content-Type")
	if !strings.Contains(ct, "text/html") {
		t.Errorf("expected HTML content-type, got %s", ct)
	}
}

// --- GET /notes/ ---

func TestGetNotes_JSON(t *testing.T) {
	r := newRouter()
	req := httptest.NewRequest(http.MethodGet, "/notes/", nil)
	req.Header.Set("Accept", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
	if !strings.Contains(w.Header().Get("Content-Type"), "application/json") {
		t.Errorf("expected JSON content-type, got %s", w.Header().Get("Content-Type"))
	}
	var items []map[string]interface{}
	if err := json.NewDecoder(w.Body).Decode(&items); err != nil {
		t.Fatalf("response is not valid JSON: %v", err)
	}
}

func TestGetNotes_HTML(t *testing.T) {
	r := newRouter()
	req := httptest.NewRequest(http.MethodGet, "/notes/", nil)
	req.Header.Set("Accept", "text/html")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
	if !strings.Contains(w.Body.String(), "<html>") {
		t.Errorf("expected HTML body, got: %s", w.Body.String())
	}
}

func TestGetNotes_WithData(t *testing.T) {
	r := newRouter()
	seedNote(t, r, "Alpha", "")
	seedNote(t, r, "Beta", "")

	req := httptest.NewRequest(http.MethodGet, "/notes/", nil)
	req.Header.Set("Accept", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	var items []map[string]interface{}
	if err := json.NewDecoder(w.Body).Decode(&items); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if len(items) != 2 {
		t.Errorf("expected 2 notes, got %d", len(items))
	}
}

// --- POST /notes/ ---

func TestCreateNote_JSON(t *testing.T) {
	r := newRouter()
	body, _ := json.Marshal(map[string]string{"title": "My Note", "content": "Body text"})
	req := httptest.NewRequest(http.MethodPost, "/notes/", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("expected 201, got %d: %s", w.Code, w.Body.String())
	}
	var resp map[string]int
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp["id"] == 0 {
		t.Error("expected non-zero id in response")
	}
}

func TestCreateNote_Form(t *testing.T) {
	r := newRouter()
	form := strings.NewReader("title=FormNote&content=FormBody")
	req := httptest.NewRequest(http.MethodPost, "/notes/", form)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("expected 201, got %d: %s", w.Code, w.Body.String())
	}
}

func TestCreateNote_EmptyTitle_JSON(t *testing.T) {
	r := newRouter()
	body, _ := json.Marshal(map[string]string{"title": "", "content": "no title"})
	req := httptest.NewRequest(http.MethodPost, "/notes/", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestCreateNote_EmptyTitle_Form(t *testing.T) {
	r := newRouter()
	form := strings.NewReader("title=&content=nobody")
	req := httptest.NewRequest(http.MethodPost, "/notes/", form)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestCreateNote_InvalidJSON(t *testing.T) {
	r := newRouter()
	req := httptest.NewRequest(http.MethodPost, "/notes/", strings.NewReader("{not valid json"))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

// --- GET /notes/{id} ---

func TestGetNoteByID(t *testing.T) {
	r := newRouter()
	id := seedNote(t, r, "Specific Note", "Some content")

	req := httptest.NewRequest(http.MethodGet, fmt.Sprintf("/notes/%d", id), nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestGetNoteByID_JSON(t *testing.T) {
	r := newRouter()
	id := seedNote(t, r, "JSON Note", "content")

	req := httptest.NewRequest(http.MethodGet, fmt.Sprintf("/notes/%d", id), nil)
	req.Header.Set("Accept", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
	var note map[string]interface{}
	if err := json.NewDecoder(w.Body).Decode(&note); err != nil {
		t.Fatalf("expected valid JSON, got error: %v", err)
	}
	if note["title"] != "JSON Note" {
		t.Errorf("expected title 'JSON Note', got %v", note["title"])
	}
}

func TestGetNoteByID_NotFound(t *testing.T) {
	r := newRouter()
	req := httptest.NewRequest(http.MethodGet, "/notes/9999", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

func TestGetNoteByID_InvalidID(t *testing.T) {
	r := newRouter()
	req := httptest.NewRequest(http.MethodGet, "/notes/abc", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}
