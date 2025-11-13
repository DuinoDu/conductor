PYTHON ?= python3
VENV ?= .venv
STAMP := $(VENV)/.installed
PIP := $(VENV)/bin/pip
PYTEST := $(VENV)/bin/pytest
BACKEND_DIR := backend
BACKEND_NODE_MODULES := $(BACKEND_DIR)/node_modules

.PHONY: deps deps-sdk deps-backend
deps: deps-sdk deps-backend

deps-sdk: $(STAMP)

$(STAMP): requirements-dev.txt
	$(PYTHON) -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements-dev.txt
	touch $(STAMP)

deps-backend: $(BACKEND_NODE_MODULES)

$(BACKEND_NODE_MODULES): $(BACKEND_DIR)/package.json $(BACKEND_DIR)/package-lock.json
	npm --prefix $(BACKEND_DIR) install

.PHONY: sdk-test sdk-integration-test backend-test test run backend-build backend-start infra-up infra-down

test-sdk: deps-sdk
	PYTHONPATH=$(PWD)/sdk $(PYTEST) sdk/tests

test-sdk-integration: deps-sdk
	BACKEND_EVENTS_URL=http://127.0.0.1:4000/events PYTHONPATH=$(PWD)/sdk $(PYTEST) sdk/tests/test_mcp_integration.py

test-backend: deps-backend
	npm --prefix $(BACKEND_DIR) test

test-app:
	cd app/conductor_app; flutter test

test: backend-test sdk-test

backend-build: deps-backend
	npm --prefix $(BACKEND_DIR) run build

backend-start: backend-build
	cd $(BACKEND_DIR) && PORT=4000 npm start

run: backend-start

infra-up:
	docker compose -f docker-compose.local.yml up -d

infra-down:
	docker compose -f docker-compose.local.yml down

KILL_PORTS := 4000 

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
