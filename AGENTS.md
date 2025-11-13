# Repository Guidelines

## Project Structure & Module Organization
- `backend/` holds the NestJS service (`src/` modules/services, `test/` Jest specs, `dist/` build output).
- `app/conductor_app/` is the Flutter client; keep feature widgets under `lib/` and tests under `test/`, platform folders are flutter-managed.
- `sdk/` contains the Python helper library in `sdk/conductor` plus `sdk/tests`.
- `docs/`, `docker-compose.local.yml`, and the root `Makefile` provide reference material and orchestration scripts.

## Build, Test, and Development Commands
- `make deps` boots the Python venv and installs backend Node modules; run once per machine.
- `make backend-build && make start-backend` compiles TypeScript and serves the API on `http://localhost:4000`.
- `make start-app` launches the Flutter web runner pointed at the local API.
- `make test` runs backend Jest plus SDK pytest; `make test-app` executes `flutter test`.
- Tight loop helpers: `npm --prefix backend run test:watch`, `flutter analyze`, and `PYTHONPATH=$PWD/sdk pytest sdk/tests -k <pattern>`.

## Coding Style & Naming Conventions
- TypeScript: 2-space indent, `PascalCase` modules/providers, `camelCase` members, suffix files with `.service.ts`, `.controller.ts`, `.spec.ts`; keep DTOs validated via `class-validator`.
- Dart: run `dart format` and `flutter analyze`, group widgets by feature in `lib/` and name files `feature_widget.dart`.
- Python SDK: follow PEP 8, type-annotate new APIs, and expose entry points through `sdk/conductor/__init__.py`.

## Testing Guidelines
- Backend specs live in `backend/test/<domain>/*.spec.ts`; reuse helpers from `backend/test/setup-env.ts` and seed via factories when touching TypeORM entities.
- Flutter tests belong in `app/conductor_app/test` and should stub HTTP clients rather than call the live backend.
- SDK tests stay in `sdk/tests`, named `test_*.py`, and must import modules through `PYTHONPATH=$PWD/sdk`.
- Every feature needs at least one backend spec plus either a widget or SDK case to guard the end-to-end path.

## Commit & Pull Request Guidelines
- Follow the existing imperative, one-line commit style (`update app`, `add sdk`); keep the subject ≤72 chars and describe *what* changed.
- PRs must summarize intent, list the commands run (e.g., `make test`, `flutter test`), link issues, and attach screenshots/logs for UI or infra work.
- Flag schema changes or new env vars so reviewers can stage infra with `make infra-up`/`make infra-down`.

## Security & Configuration Tips
- Copy `backend/.env.example` to `.env`; set `DB_DIALECT=sqlite` for file-backed dev or rely on `make infra-up` for Postgres/Redis.
- Never commit secrets; manage CORS by editing `CORS_ORIGINS` before `make start-backend`, and restrict access to `conductor.db` when using SQLite.

## Develop

- test: make test
- deploy backend: make start-backend
- deploy app in web: make start-app
