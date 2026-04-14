# homebrew-openmemory

> A Homebrew tap that installs [OpenMemory](https://github.com/mem0ai/mem0) — a self-hosted memory layer for AI — as three managed macOS services plus a convenience CLI.

OpenMemory gives your AI tools persistent, searchable memory backed by a vector database. This tap packages the full stack:

| Component | Formula | What it is |
|---|---|---|
| **Qdrant** | `qdrant` | Vector database for similarity search (pre-built binary) |
| **MCP backend** | `openmemory-mcp` | FastAPI/Python server, SQLite database, Alembic migrations |
| **UI** | `openmemory-ui` | Next.js 15 web dashboard |
| **CLI wrapper** | _(installed by `openmemory`)_ | `openmemory start/stop/restart/status` |

---

## Prerequisites

- **macOS** (Apple Silicon or Intel)
- **Homebrew** — [brew.sh](https://brew.sh)
- **OpenAI API key** (or a compatible alternative — see [Configuration](#configuration))

---

## Quick Start

```bash
# 1. Add the tap
brew tap gdziegielewski/openmemory

# 2. Install the full stack
brew install openmemory

# 3. Set your API key
#    The config file was created automatically at install time:
nano "$(brew --prefix)/etc/openmemory/openmemory.env"
#    Replace 'sk-replace-me' with your actual key:
#    OPENAI_API_KEY=sk-...

# 4. Start all services
openmemory start
```

Once running:

- **MCP API:** <http://localhost:8765>
- **UI:** <http://localhost:3000>

---

## CLI Usage

The `openmemory` command manages all three services together via `brew services`.

```
openmemory <command>

Commands:
  start    Start all OpenMemory services (qdrant, openmemory-mcp, openmemory-ui)
  stop     Stop all OpenMemory services
  restart  Restart all OpenMemory services
  status   Show status of all OpenMemory services
```

Examples:

```bash
openmemory start
openmemory status
openmemory restart
openmemory stop
```

---

## Configuration

The config file lives at:

```
$(brew --prefix)/etc/openmemory/openmemory.env
```

It is created automatically from `openmemory.env.example` on first install. Edit it before starting services.

### Available Options

```bash
# ── Required ──────────────────────────────────────────────────────────────────
OPENAI_API_KEY=sk-replace-me

# ── Data storage ──────────────────────────────────────────────────────────────
# OPENMEMORY_DATA_DIR=/opt/homebrew/var/openmemory
# DATABASE_URL=sqlite:////opt/homebrew/var/openmemory/openmemory.db

# ── Qdrant ────────────────────────────────────────────────────────────────────
QDRANT_HOST=localhost
QDRANT_PORT=6333

# ── MCP API server ────────────────────────────────────────────────────────────
OPENMEMORY_HOST=0.0.0.0
OPENMEMORY_PORT=8765
# OPENMEMORY_WORKERS=4

# ── UI server ─────────────────────────────────────────────────────────────────
# OPENMEMORY_UI_PORT=3000
# OPENMEMORY_UI_HOST=0.0.0.0

# ── Optional: LLM provider overrides (defaults to OpenAI) ─────────────────────
# LLM_PROVIDER=ollama
# LLM_MODEL=llama3.1:latest
# LLM_API_KEY=
# LLM_BASE_URL=
# OLLAMA_BASE_URL=http://localhost:11434

# ── Optional: Embedder overrides ──────────────────────────────────────────────
# EMBEDDER_PROVIDER=ollama
# EMBEDDER_MODEL=nomic-embed-text
```

### Ports

| Service | Default port | Override env var |
|---|---|---|
| Qdrant HTTP | 6333 | `QDRANT_PORT` (also update `etc/qdrant/config.yaml`) |
| Qdrant gRPC | 6334 | _(edit `etc/qdrant/config.yaml`)_ |
| MCP API | 8765 | `OPENMEMORY_PORT` |
| UI | 3000 | `OPENMEMORY_UI_PORT` |

> **Note:** `NEXT_PUBLIC_API_URL` is baked into the UI bundle at build time (default: `http://localhost:8765`). If you change the MCP API port, you must rebuild the UI:
> ```bash
> cd "$(brew --prefix)/opt/openmemory-ui/libexec/ui"
> NEXT_PUBLIC_API_URL=http://localhost:<new-port> pnpm build
> ```

---

## Individual Formula Install

For advanced users who only need specific components:

```bash
# Vector database only
brew install gdziegielewski/openmemory/qdrant

# MCP backend only (requires qdrant)
brew install gdziegielewski/openmemory/openmemory-mcp

# UI only (requires openmemory-mcp running somewhere)
brew install gdziegielewski/openmemory/openmemory-ui
```

Start individual services:

```bash
brew services start qdrant
brew services start openmemory-mcp
brew services start openmemory-ui
```

---

## Troubleshooting

### Check service status

```bash
openmemory status
# or
brew services list | grep -E "qdrant|openmemory"
```

### View logs

All logs are written to `$(brew --prefix)/var/log/openmemory/`:

| File | Service |
|---|---|
| `qdrant.log` / `qdrant.error.log` | Qdrant |
| `mcp.log` / `mcp.error.log` | MCP backend |
| `ui.log` / `ui.error.log` | Next.js UI |

```bash
# Tail MCP backend logs
tail -f "$(brew --prefix)/var/log/openmemory/mcp.log"
tail -f "$(brew --prefix)/var/log/openmemory/mcp.error.log"
```

### Common issues

**Services won't start / `OPENAI_API_KEY` error**
Edit your config file and ensure `OPENAI_API_KEY` is set to a real key (not `sk-replace-me`):
```bash
nano "$(brew --prefix)/etc/openmemory/openmemory.env"
```

**Database not initialized**
Run migrations manually:
```bash
openmemory-migrate
```

**UI shows "cannot connect to API"**
Ensure `openmemory-mcp` is running and `NEXT_PUBLIC_API_URL` matches the MCP port. The URL is baked in at build time — see the note in [Configuration](#configuration).

**Port conflict**
Change the relevant port in `openmemory.env` and restart:
```bash
openmemory restart
```

**Reinstall / reset data**
```bash
openmemory stop
rm -rf "$(brew --prefix)/var/openmemory"
openmemory start   # migrations run automatically on restart
```

---

## Upstream Project

- **mem0** — <https://github.com/mem0ai/mem0>
- Documentation — <https://docs.mem0.ai>

---

## License

[Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) — same as the upstream mem0 project.
