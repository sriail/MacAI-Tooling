# MacAI-Tooling

A collection of Docker-based tools for the MacAI project.

---

## SearXNG – Unlimited JSON Search API

This repository ships a ready-to-run [SearXNG](https://docs.searxng.org/) container configured for **unlimited, unauthenticated JSON API responses** so that AI agents and scripts can query the metasearch engine programmatically without hitting rate limits.

### Quick Start

```bash
# 1. Copy the example environment file and set your own secret key.
cp .env.example .env
# Edit .env and replace SEARXNG_SECRET_KEY with a random value:
#   openssl rand -hex 32

# 2. Start SearXNG (and the companion Redis cache).
docker compose up -d

# 3. Verify it is running.
docker compose ps
```

SearXNG will be available at **http://localhost:8080** (or the port you set in `.env`).

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
| `docker-compose.yml` | Service definitions (SearXNG + Redis) |
| `searxng/settings.yml` | SearXNG settings – JSON format enabled, rate limiter off |
| `searxng/limiter.toml` | Bot-detection / rate-limit rules (all disabled) |
| `searxng/uwsgi.ini` | uWSGI worker configuration |
| `.env.example` | Environment variable template |

#### Key settings that enable unlimited JSON responses

```yaml
# searxng/settings.yml
server:
  limiter: false        # disables the built-in rate limiter

search:
  formats:
    - html
    - json              # enables the ?format=json API endpoint
    - csv
```

```toml
# searxng/limiter.toml
[botdetection.ip_limit]
enabled = false         # disables per-IP request throttling

[botdetection.ip_lists]
enabled = false         # disables IP block-list enforcement
```

---

### Sharing the Docker Network with Other Containers

All services on the same VM can reach SearXNG via the shared `macai-net` bridge network.  Add your existing services to the same network in their own `docker-compose.yml`:

```yaml
# In another service's docker-compose.yml
services:
  my-service:
    image: my-image
    networks:
      - macai-net

networks:
  macai-net:
    external: true      # reuse the network created by this repo
    name: macai-net
```

Then call SearXNG by its container name from within the network:

```
http://searxng:8080/search?q=hello&format=json
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
