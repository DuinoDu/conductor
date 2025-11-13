# Conductor Backend

## Local prerequisites
- Node.js 18+
- npm
- Docker (for Postgres/Redis)

## Configuration
Copy `.env.example` to `.env` and adjust values as needed. `CORS_ORIGINS` accepts a comma‑separated list of allowed web origins (e.g., `http://localhost:61331` for Flutter web dev server).

## Quick start
```bash
cp backend/.env.example backend/.env
make infra-up            # starts Postgres + Redis
make run                 # builds TypeScript and boots backend
```

By default `make run` expects Postgres/Redis at the values in `.env`. To run without external services, set `DB_DIALECT=sqlite` in `.env` (or environment) and the backend will use a local SQLite file.

Stop infrastructure: `make infra-down`.
