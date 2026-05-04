FROM golang:1.26-bookworm AS builder

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY cmd ./cmd
COPY internal ./internal

RUN CGO_ENABLED=0 GOOS=linux go build -o /out/mywebapp-server ./cmd/mywebapp
    CGO_ENABLED=0 GOOS=linux go build -o /out/mywebapp-migrate ./cmd/migrate

FROM busybox:1.37.0-uclibc AS busybox

FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app

COPY --from=builder /out/mywebapp-server /app/mywebapp-server
COPY --from=builder /out/mywebapp-migrate /app/mywebapp-migrate
COPY --from=busybox /bin/wget /bin/wget
