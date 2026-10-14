FROM golang:1.26.3 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o /out/ai-grid-backend ./cmd/ai-grid-backend

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/ai-grid-backend /ai-grid-backend
EXPOSE 8080
ENTRYPOINT ["/ai-grid-backend"]
