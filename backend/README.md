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

## HTTPS (development)
Enable HTTPS by setting environment flags and providing a key/cert:

```bash
# Generate a local dev cert (recommended: mkcert)
# mkcert -cert-file backend/certs/dev.crt -key-file backend/certs/dev.key localhost 127.0.0.1 ::1 192.168.x.x

# Run over HTTPS on port 4443
make run-https

# Or manually
cd backend \\
  && PORT=4443 HTTPS=1 \\
  HTTPS_KEY_PATH=certs/dev.key HTTPS_CERT_PATH=certs/dev.crt \\
  npm start
```

When HTTPS is enabled, WebSocket endpoints remain available at `/ws/app` and `/ws/agent` over `wss://`.

## HTTPS via ngrok (no local certs)
Expose the local HTTP backend over a trusted public HTTPS domain using ngrok:

```bash
brew install ngrok/ngrok/ngrok
export NGROK_AUTHTOKEN=<your_token>

# Start backend (HTTP 4000)
make run

# Start ngrok tunnel and get URLs
make tunnel-ngrok
# Use the printed NGROK_HTTPS_URL and NGROK_WSS_URL in your client
```

ngrok automatically supports WebSocket upgrades; point the client to `wss://<ngrok-domain>/ws/app`.
