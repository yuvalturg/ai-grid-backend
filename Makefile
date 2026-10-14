SHELL := /usr/bin/env bash

GO := go
BIN_DIR := bin
BACKEND_BIN := $(BIN_DIR)/ai-grid-backend

.PHONY: all build test vet fmt-check lint verify prereqs kind-test clean-kind

all: verify

build:
	mkdir -p $(BIN_DIR)
	$(GO) build -buildvcs=false -trimpath -o $(BACKEND_BIN) ./cmd/ai-grid-backend

test:
	$(GO) test ./...

vet:
	$(GO) vet ./...

fmt-check:
	@files="$$(gofmt -l client cmd gen integration internal)"; \
	if [[ -n "$$files" ]]; then \
		echo "gofmt is required for:"; echo "$$files"; exit 1; \
	fi

lint: fmt-check vet
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
	else \
		echo "golangci-lint not installed; gofmt and go vet completed"; \
	fi

verify: build test lint

prereqs:
	bash hack/check-prereqs.sh

kind-test:
	bash hack/test-kind.sh

clean-kind:
	kind delete cluster --name "$${KIND_CLUSTER_NAME:-ai-grid-hub}"
