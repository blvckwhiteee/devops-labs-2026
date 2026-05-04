package http

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"lab1/internal/domain"

	"github.com/go-chi/chi/v5"
)

type CreateNoteResponse struct {
	ID int `json:"id"`
}

type NoteListItemResponse struct {
	ID    int    `json:"id"`
	Title string `json:"title"`
}

type CreateNoteDTO struct {
	Title   string `json:"title"`
	Content string `json:"content"`
}

type Handler struct {
	usecase domain.NoteUsecase
	repo    domain.NoteRepository
}

func NewHandler(u domain.NoteUsecase, r domain.NoteRepository) *Handler {
	return &Handler{usecase: u, repo: r}
}

func (h *Handler) InitRoutes(r chi.Router) {
	r.Get("/", h.rootHandler)

	r.Route("/health", func(r chi.Router) {
		r.Get("/alive", h.aliveHandler)
		r.Get("/ready", h.readyHandler)
	})

	r.Route("/notes", func(r chi.Router) {
		r.Get("/", h.getNotes)
		r.Post("/", h.createNote)
		r.Get("/{id}", h.getNoteByID)
	})
}

func (h *Handler) aliveHandler(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("OK"))
}

func (h *Handler) readyHandler(w http.ResponseWriter, r *http.Request) {
	if err := h.repo.Ping(r.Context()); err != nil {
		http.Error(w, "DB Error: "+err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("OK"))
}

func (h *Handler) rootHandler(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write([]byte(`<html><body><h1>Notes API</h1><ul><li><a href="/notes">GET /notes</a></li><li>POST /notes</li><li>GET /notes/&lt;id&gt;</li></ul></body></html>`))
}

func (h *Handler) getNotes(w http.ResponseWriter, r *http.Request) {
	notes, err := h.usecase.GetNotes(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	items := make([]NoteListItemResponse, 0, len(notes))
	for _, n := range notes {
		items = append(items, NoteListItemResponse{
			ID:    n.ID,
			Title: n.Title,
		})
	}
	h.getRespond(w, r, items, formatNotesHTML(notes))
}

func (h *Handler) createNote(w http.ResponseWriter, r *http.Request) {
	var dto CreateNoteDTO

	if strings.Contains(r.Header.Get("Content-Type"), "application/json") {
		if err := json.NewDecoder(r.Body).Decode(&dto); err != nil {
			http.Error(w, "Invalid JSON", http.StatusBadRequest)
			return
		}
	} else {
		err := r.ParseForm()
		if err != nil {
			http.Error(w, "Unparsable json", http.StatusBadRequest)
			return
		}
		dto.Title = r.FormValue("title")
		dto.Content = r.FormValue("content")
	}

	note, err := h.usecase.CreateNote(r.Context(), dto.Title, dto.Content)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	response := CreateNoteResponse{
		ID: note.ID,
	}
	w.WriteHeader(http.StatusCreated)
	h.postRespond(w, response)
}

func (h *Handler) getNoteByID(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")

	id, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "Invalid ID", http.StatusBadRequest)
		return
	}

	note, err := h.usecase.GetNoteByID(r.Context(), id)
	if err != nil {
		http.Error(w, "Not Found", http.StatusNotFound)
		return
	}

	html := fmt.Sprintf(`<html><body><h1>%s</h1><p>ID: %d</p><p>%s</p></body></html>`, note.Title, note.ID, note.Content)
	h.getRespond(w, r, note, html)
}

func (h *Handler) getRespond(w http.ResponseWriter, r *http.Request, data interface{}, html string) {
	if strings.Contains(r.Header.Get("Accept"), "text/html") {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = w.Write([]byte(html))
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(data)
}

func (h *Handler) postRespond(w http.ResponseWriter, data interface{}) {
	err := json.NewEncoder(w).Encode(data)
	if err != nil {
		return
	}

}

func formatNotesHTML(notes []domain.Note) string {
	html := "<html><body><h1>All Notes</h1><table border='1'><tr><th>ID</th><th>Title</th></tr>"
	for _, n := range notes {
		html += fmt.Sprintf("<tr><td>%d</td><td>%s</td></tr>", n.ID, n.Title)
	}
	html += "</table></body></html>"
	return html
}
