# Звіт по покриттю коду тестами

## Команда запуску

```bash
go test -coverprofile=coverage.out -covermode=atomic ./...
go tool cover -func=coverage.out
```

Покриття перевіряється автоматично у CI-пайплайні (job `test`) при кожному push у main або при відкритті PR. Мінімальний поріг - **40%**. `coverage-report` завантажується у GitHub Actions Artifacts після кожного успішного запуску CI на гілці main.

---

## Перевірка покриття

```bash
go test -coverprofile=coverage.out -covermode=atomic ./...
go tool cover -func=coverage.out
```

---

## Покриття по пакетах

### `internal/repository` - ~50%

Пакет містить два репозиторії: in-memory (для тестів) і MariaDB (для production).



**`memory.go` - покриті методи:**

| Метод | Тести |
|---|---|
| `NewMemoryRepository()` | `TestMemoryRepository_Create` |
| `Create()` | `TestMemoryRepository_Create`, `TestMemoryRepository_Create_AutoIncrement`, `TestMemoryRepository_Concurrent` |
| `GetAll()` | `TestMemoryRepository_GetAll_Empty`, `TestMemoryRepository_GetAll`, `TestMemoryRepository_GetAll_IsolatesCopy` |
| `GetByID()` | `TestMemoryRepository_GetByID`, `TestMemoryRepository_GetByID_NotFound`, `TestMemoryRepository_GetByID_IsolatesCopy` |
| `Ping()` | `TestMemoryRepository_Ping` |

**`mariadb.go` - не покритий:** Реалізація `Create`, `GetAll`, `GetByID`, `Ping` через `database/sql` не тестується без живої БД.

---

### `internal/usecase` - ~100%

| Метод | Тести |
|---|---|
| `NewNoteUsecase()` | Усі тести usecase |
| `CreateNote()` | `TestCreateNote`, `TestCreateNote_EmptyTitle`, `TestCreateNote_EmptyContent`, `TestCreateNote_RepoError` |
| `GetNotes()` | `TestGetNotes_Empty`, `TestGetNotes` |
| `GetNoteByID()` | `TestGetNoteByID`, `TestGetNoteByID_NotFound`, `TestGetNoteByID_CorrectNote` |



---

### `internal/delivery/http` - 89.9%



| Тест | Ендпоінт | Сценарій |
|---|---|---|
| `TestAliveHandler` | `GET /health/alive` | 200 OK |
| `TestReadyHandler` | `GET /health/ready` | 200 OK (Ping успішний) |
| `TestRootHandler` | `GET /` | 200 OK, HTML-відповідь |
| `TestGetNotes_JSON` | `GET /notes/` | 200, Content-Type: application/json |
| `TestGetNotes_HTML` | `GET /notes/` | 200, HTML-відповідь |
| `TestGetNotes_WithData` | `GET /notes/` | Список з 2 нотаток |
| `TestCreateNote_JSON` | `POST /notes/` | JSON body, 201 Created |
| `TestCreateNote_Form` | `POST /notes/` | Form body, 201 Created |
| `TestCreateNote_EmptyTitle_JSON` | `POST /notes/` | Порожній title → 400 |
| `TestCreateNote_EmptyTitle_Form` | `POST /notes/` | Порожній title form → 400 |
| `TestCreateNote_InvalidJSON` | `POST /notes/` | Некоректний JSON → 400 |
| `TestGetNoteByID` | `GET /notes/{id}` | 200, нотатка знайдена |
| `TestGetNoteByID_JSON` | `GET /notes/{id}` | 200, JSON-відповідь з полями |
| `TestGetNoteByID_NotFound` | `GET /notes/9999` | 404 Not Found |
| `TestGetNoteByID_InvalidID` | `GET /notes/abc` | 400 Bad Request |



---

### `internal/domain` 

Пакет не містить виконуваної логіки. 

---

## Тестові файли

| Файл | Пакет | Кількість тестів |
|---|---|---|
| `internal/delivery/http/handler_test.go` | `http_test` | 15 |
| `internal/usecase/note_test.go` | `usecase_test` | 9 |
| `internal/repository/memory_test.go` | `repository_test` | 9 |

Усього: **33 тести**.

---


