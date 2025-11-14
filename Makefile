.PHONY: sdk-test sdk-integration-test backend-test test run backend-build backend-start run-ios run-web

PYTHON ?= python3
VENV ?= .venv
STAMP := $(VENV)/.installed
PIP := $(VENV)/bin/pip
PYTEST := $(VENV)/bin/pytest
BACKEND_DIR := backend
BACKEND_NODE_MODULES := $(BACKEND_DIR)/node_modules
APP_DIR := app/conductor_app
FLUTTER ?= $(HOME)/opt/flutter/bin/flutter

# Try to detect the active local IP (override with `HOST_IP=x.x.x.x` if needed)
# Prefer RFC1918 LAN IPs (avoid CGNAT like 100.x from Tailscale)
HOST_IP ?= $(shell sh -c '\
  for iface in en0 en1; do \
    ip=$$(ipconfig getifaddr $$iface 2>/dev/null || true); \
    echo $$ip; \
  done | \
  awk \'/^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)/ {print; exit}\' || true';)
# Fallback to first non-loopback if nothing matched
HOST_IP := $(or $(HOST_IP),$(shell ifconfig | awk '/inet / && $$2 != "127.0.0.1" {print $$2}' | egrep '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)' | head -n1))
API_URL := http://$(HOST_IP):4000
WS_FULL_URL := ws://$(HOST_IP):4000/ws/app

.PHONY: deps deps-sdk deps-backend
deps: deps-sdk deps-backend

deps-sdk: $(STAMP)

$(STAMP): sdk/requirements-dev.txt
	if [ ! -d "$(VENV)" ]; then \
		$(PYTHON) -m venv $(VENV); \
	fi
	$(PIP) install --upgrade pip
	$(PIP) install -r sdk/requirements-dev.txt
	touch $(STAMP)

deps-backend: $(BACKEND_NODE_MODULES)

$(BACKEND_NODE_MODULES): $(BACKEND_DIR)/package.json $(BACKEND_DIR)/package-lock.json
	npm --prefix $(BACKEND_DIR) install

test-sdk: deps-sdk
	PYTHONPATH=$(PWD)/sdk $(PYTEST) sdk/tests

test-sdk-integration: deps-sdk
	BACKEND_EVENTS_URL=http://127.0.0.1:4000/events PYTHONPATH=$(PWD)/sdk $(PYTEST) sdk/tests/test_mcp_integration.py

test-backend: deps-backend
	npm --prefix $(BACKEND_DIR) test

test-app:
	cd $(APP_DIR); $(FLUTTER) test

test: test-backend test-sdk test-app

backend-build: deps-backend
	npm --prefix $(BACKEND_DIR) run build

run: backend-build
	cd $(BACKEND_DIR) && PORT=4000 HOST=0.0.0.0 npm start

run-web:
	@if [ -z "$(HOST_IP)" ]; then \
        echo "Could not determine HOST_IP automatically. Set HOST_IP=x.x.x.x and retry."; \
        exit 1; \
    fi
	@echo "Using HOST_IP=$(HOST_IP) API_URL=$(API_URL)"
	cd $(APP_DIR) && \
    $(FLUTTER) run -d chrome --web-hostname=0.0.0.0 --web-port=6150 --dart-define=API_BASE_URL=$(API_URL)

# >> xcrun simctl list
SIMULATOR=8887531C-E1FB-4AF9-A96F-FBD41773E39C
IPHONE11=00008030-001C48211E28802E

start-simulator:
	xcrun simctl boot $(SIMULATOR)

run-ios:
	@if [ -z "$(HOST_IP)" ]; then \
        echo "Could not determine HOST_IP automatically. Pass HOST_IP=x.x.x.x (your Mac IP)."; \
        exit 1; \
    fi
	@echo "Using HOST_IP=$(HOST_IP) API_URL=$(API_URL) WS_URL=$(WS_FULL_URL)"
	cd $(APP_DIR) && \
    $(FLUTTER) run --device-id $(IPHONE11) \
        --dart-define=API_BASE_URL=$(API_URL) \
        --dart-define=WS_URL=$(WS_FULL_URL)

build-ios:
	@if [ -z "$(HOST_IP)" ]; then \
        echo "Could not determine HOST_IP automatically. Pass HOST_IP=x.x.x.x (your Mac IP)."; \
        exit 1; \
    fi
	cd $(APP_DIR) && \
    $(FLUTTER) build ios \
        --dart-define=API_BASE_URL=$(API_URL) \
        --dart-define=WS_URL=$(WS_FULL_URL)

# Backward-compat alias matching docs
start-backend: run

run-android:

infra-up:
	docker compose -f docker-compose.local.yml up -d

infra-down:
	docker compose -f docker-compose.local.yml down

clean:
	cd $(APP_DIR) && flutter clean

KILL_PORTS := 4000 6150

kill:
	@set -e; \
	for port in $(KILL_PORTS); do \
		pids=$$(lsof -ti tcp:$$port 2>/dev/null || true); \
		if [ -n "$$pids" ]; then \
			echo "Killing processes on port $$port: $$pids"; \
			kill $$pids 2>/dev/null || true; \
		else \
			echo "No processes listening on port $$port"; \
		fi; \
	done;

test-ws-port:
	npx wscat -c ws://localhost:4000/ws/agent
	npx wscat -c ws://localhost:4000/ws/app
