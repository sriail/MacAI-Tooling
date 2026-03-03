# MacAI-Tooling

A collection of Docker-based tools for the MacAI project.

---

## SearXNG – Unlimited JSON Search API

This repository ships a ready-to-run [SearXNG](https://docs.searxng.org/) container configured for **unlimited, unauthenticated JSON API responses** so that AI agents and scripts can query the metasearch engine programmatically without hitting rate limits.

The container runs as a **single service on port 8080** — no Redis dependency, no cap manipulation — for maximum compatibility with CodeSandbox and other constrained hosting environments.

### Quick Start

```bash
# 1. Copy the example environment file and set your own secret key.
cp .env.example .env
# Edit .env and replace SEARXNG_SECRET_KEY with a random value:
#   openssl rand -hex 32

# 2. Make the wake-up script executable (one-time setup).
chmod +x wake.sh

# 3. Start SearXNG.
docker compose up -d

# 4. Verify it is running.
docker compose ps
```

SearXNG will be available at **http://localhost:8080** (or the port you set in `.env`).

---

### Wake-Up Ping (CodeSandbox Auto-Sleep)

CodeSandbox pauses idle servers to save credits. Use `wake.sh` to send a
single cheap `HEAD /healthz` request that wakes the sandbox up **before**
sending real search queries.  It backs off exponentially so the server is not
hammered while it starts, and exits as soon as it gets a `2xx/3xx` response.

```bash
# Wake up the default instance (http://localhost:8080).
./wake.sh

# Then fire your real search — the server is guaranteed to be ready.
curl "http://localhost:8080/search?q=openai&format=json"
```

**From inside another container on the same Docker network:**

```bash
SEARXNG_BASE_URL=http://searxng:8080/ ./wake.sh
```

**Environment variables:**

| Variable | Default | Purpose |
|---|---|---|
| `SEARXNG_BASE_URL` | `http://localhost:8080` | Base URL to ping |
| `WAKE_MAX_WAIT` | `60` | Maximum seconds to wait before giving up |

> **How it works:** The script sends a `HEAD /healthz` request (just response
> headers, no body) per attempt.  It starts with a 1-second delay and doubles
> on each failure up to a 10-second cap, so a sleeping CodeSandbox that takes
> ~20 s to resume costs only 3–4 tiny pings rather than a continuous poll.

---

### JSON API Usage

Append `format=json` to any search request:

```bash
# Basic JSON search
curl "http://localhost:8080/search?q=openai&format=json"

# Paginate results (page 2)
curl "http://localhost:8080/search?q=openai&format=json&pageno=2"

# Filter by category
curl "http://localhost:8080/search?q=openai&format=json&categories=general"

# Filter by language
curl "http://localhost:8080/search?q=openai&format=json&language=en-US"
```

**Example JSON response shape:**

```json
{
  "query": "openai",
  "number_of_results": 0,
  "results": [
    {
      "url": "https://openai.com",
      "title": "OpenAI",
      "content": "...",
      "engine": "google",
      "score": 1.0,
      "category": "general"
    }
  ],
  "suggestions": [],
  "infoboxes": []
}
```

---

### Configuration

| File | Purpose |
|---|---|
| `docker-compose.yml` | Single SearXNG service definition (port 8080) |
| `searxng/settings.yml` | SearXNG settings – JSON format enabled, rate limiter off, port 8080 |
| `searxng/limiter.toml` | Bot-detection / rate-limit rules (all disabled) |
| `searxng/uwsgi.ini` | uWSGI worker configuration (bound to :8080) |
| `wake.sh` | Ping script to wake SearXNG from CodeSandbox auto-sleep |
| `.env.example` | Environment variable template |

#### Key settings that enable unlimited JSON responses

```yaml
# searxng/settings.yml
server:
  limiter: false        # disables the built-in rate limiter
  port: 8080

search:
  formats:
    - html
    - json              # enables the ?format=json API endpoint
    - csv
```

```toml
# searxng/limiter.toml
[botdetection.ip_limit]
link_token = false      # disables link-token requirement for search requests
```

---

### Updating

```bash
docker compose pull
docker compose up -d
```

### Stopping

```bash
docker compose down
```
