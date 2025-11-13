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

.PHONY: sdk-test backend-test test

sdk-test: deps-sdk
	PYTHONPATH=$(PWD)/sdk $(PYTEST) sdk/tests

backend-test: deps-backend
	npm --prefix $(BACKEND_DIR) test

test: backend-test sdk-test
