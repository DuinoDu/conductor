.PHONY: sdk-test sdk-integration-test backend-test test run backend-build backend-start infra-up infra-down

PYTHON ?= python3
VENV ?= .venv
STAMP := $(VENV)/.installed
PIP := $(VENV)/bin/pip
PYTEST := $(VENV)/bin/pytest
BACKEND_DIR := backend
BACKEND_NODE_MODULES := $(BACKEND_DIR)/node_modules
APP_DIR := app/conductor_app

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
	cd $(APP_DIR); flutter test

test: test-backend test-sdk test-app

backend-build: deps-backend
	npm --prefix $(BACKEND_DIR) run build

run: backend-build
	cd $(BACKEND_DIR) && PORT=4000 HOST=0.0.0.0 npm start

run-web:
	cd $(APP_DIR) && \
	flutter run -d chrome --web-hostname=0.0.0.0 --web-port=6150 --dart-define=API_BASE_URL=http://0.0.0.0:4000

# >> xcrun simctl list
SIMULATOR=8887531C-E1FB-4AF9-A96F-FBD41773E39C
IPHONE11=00008030-001C48211E28802E

start-simulator:
	xcrun simctl boot $(SIMULATOR)

run-ios:
	cd $(APP_DIR) && \
	flutter run --device-id $(SIMULATOR)

run-android:

infra-up:
	docker compose -f docker-compose.local.yml up -d

infra-down:
	docker compose -f docker-compose.local.yml down

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
