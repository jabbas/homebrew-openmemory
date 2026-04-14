# AGENTS.md — AI Coding Agent Instructions

This file provides guidance for AI coding agents (Claude Code, GitHub Copilot, Codex, Gemini, etc.) working on the `homebrew-openmemory` repository.

---

## Project Overview

This is a **Homebrew tap** that packages [OpenMemory](https://github.com/mem0ai/mem0) (a self-hosted AI memory layer) for macOS. The repository contains four Ruby formula files and a CI workflow — nothing else. There is no application code here; the formulas fetch, build, and configure the upstream source.

**Tap name:** `gdziegielewski/openmemory`  
**Install command:** `brew tap gdziegielewski/openmemory && brew install openmemory`  
**Upstream source:** <https://github.com/mem0ai/mem0> (Apache-2.0)

---

## File Layout

```
Formula/
  openmemory.rb        Meta-formula: depends on all 3 services, installs the
                       `openmemory` CLI wrapper (start/stop/restart/status).
                       Also installs the example config to etc/openmemory/.

  openmemory-mcp.rb    Python/FastAPI MCP backend.
                       - Copies openmemory/api/ into libexec/app/
                       - Creates a Python 3.12 virtualenv in libexec/venv/
                       - Installs pip dependencies from requirements.txt
                       - Installs `openmemory-mcp-server` and `openmemory-migrate` wrappers
                       - Runs `alembic upgrade head` in post_install
                       - Service: uvicorn on port 8765

  openmemory-ui.rb     Next.js 15 frontend.
                       - Copies openmemory/ui/ into libexec/ui/
                       - Builds with pnpm (NEXT_PUBLIC_API_URL baked in at build time)
                       - Installs `openmemory-ui-server` wrapper
                       - Service: `next start` on port 3000

  qdrant.rb            Pre-built Qdrant binary (separate arm64 + x86_64 downloads).
                       - Writes a default config to etc/qdrant/config.yaml
                       - Service: qdrant on ports 6333 (HTTP) and 6334 (gRPC)

config/
  openmemory.env.example   Template env file installed to etc/openmemory/

.github/workflows/
  bottles.yml          CI workflow: builds Homebrew bottles on tag push (tag format: v*)
```

---

## Development Guidelines

### Passing `brew audit`

All formulas must pass:

```bash
brew audit --strict gdziegielewski/openmemory/<formula-name>
# e.g.
brew audit --strict gdziegielewski/openmemory/openmemory
brew audit --strict gdziegielewski/openmemory/openmemory-mcp
brew audit --strict gdziegielewski/openmemory/openmemory-ui
brew audit --strict gdziegielewski/openmemory/qdrant
```

Known audit rules to observe (active issues in this tap as of v1.0.10):

| Rule | Detail |
|---|---|
| **Alphabetical dependency ordering** | `depends_on` lines must be sorted alphabetically within each block |
| **No formula name in description** | `desc` must not start with the formula class name or its derived string |
| **No redundant version if parseable from URL** | If the version string can be parsed from the `url`, the explicit `version` line is redundant and should be removed (affects `qdrant.rb`) |
| **No useless variable assignments** | Variables assigned but only used in a single `return` expression should be inlined |
| **No `FileUtils.` prefix** | Use bare `cp`, `rm`, `mkdir`, etc. — Homebrew DSL provides these without the `FileUtils::` namespace |
| **No redundant assignment before return in `caveats`** | Don't assign to `s` and then return `s`; return the heredoc directly |

### SHA256 Checksums

- Each formula's `sha256` must exactly match the downloaded tarball.
- Verify with: `curl -fsSL <url> | shasum -a 256`
- Never guess or copy a hash from an unverified source.

### Test Blocks

Tests run with `brew test <formula>`. They should:

- Verify that expected executables exist and are executable (`assert_predicate ..., :executable?`)
- Verify that key paths/directories exist (`assert_predicate ..., :directory?`)
- Run the binary with a safe flag (e.g., `--version`, `--help`) and assert expected output
- Import Python packages in the virtualenv to confirm a working install (for `openmemory-mcp`)

### Service Blocks

Service definitions must:

- Use `opt_bin/` paths for the `run` array (not hardcoded `bin/` paths)
- Set `keep_alive true`
- Specify both `log_path` and `error_log_path` under `var/"log/openmemory/"`
- Include `environment_variables PATH: std_service_path_env`

Example:
```ruby
service do
  run [opt_bin/"openmemory-mcp-server"]
  keep_alive true
  working_dir var/"openmemory"
  log_path var/"log/openmemory/mcp.log"
  error_log_path var/"log/openmemory/mcp.error.log"
  environment_variables PATH: std_service_path_env
end
```

### General Ruby/Formula Style

- Use `cp_r` (not `FileUtils.cp_r`) for directory copies inside formula install blocks.
- Use `inreplace` for patching source files before build.
- Use `libexec` for vendored/built assets that should not be on `PATH` directly.
- Wrapper scripts in `bin/` should source `etc/openmemory/openmemory.env` and use `exec` (not subshell) for the final command.

---

## How to Test

### Audit (lint)
```bash
brew audit --strict gdziegielewski/openmemory/openmemory
brew audit --strict gdziegielewski/openmemory/openmemory-mcp
brew audit --strict gdziegielewski/openmemory/openmemory-ui
brew audit --strict gdziegielewski/openmemory/qdrant
```

### Install from source
```bash
brew install --build-from-source gdziegielewski/openmemory/openmemory
```

### Run formula tests
```bash
brew test gdziegielewski/openmemory/openmemory
brew test gdziegielewski/openmemory/openmemory-mcp
brew test gdziegielewski/openmemory/openmemory-ui
brew test gdziegielewski/openmemory/qdrant
```

### Quick style check
```bash
brew style gdziegielewski/openmemory
```

---

## Versioning — Bumping Releases

Three formulas share the same upstream source tarball from mem0:

- `openmemory.rb`
- `openmemory-mcp.rb`
- `openmemory-ui.rb`

When a new mem0 release is published, **all three** must be updated together:

1. Update `url` to the new tag, e.g.:
   ```ruby
   url "https://github.com/mem0ai/mem0/archive/refs/tags/v1.0.11.tar.gz"
   ```
2. Compute the new SHA256:
   ```bash
   curl -fsSL https://github.com/mem0ai/mem0/archive/refs/tags/v1.0.11.tar.gz | shasum -a 256
   ```
3. Update `sha256` in all three formulas to the new value.
4. Check `openmemory-mcp.rb` for any `requirements.txt` changes that might affect patching (the `psycopg2-binary` comment-out).
5. Check `openmemory-ui.rb` for any `pnpm-lock.yaml` changes that might break `--frozen-lockfile`.

`qdrant.rb` uses a separate upstream (qdrant/qdrant) and is versioned independently — update its `url` and both `sha256` entries (arm64 + x86_64) separately.

---

## CI — Bottles

Bottles (pre-built binary packages) are built automatically by `.github/workflows/bottles.yml` when a tag matching `v*` is pushed.

- **Triggers on:** `git push origin v1.0.11` (or any `v*` tag)
- **Builds on:** `macos-14` (arm64, `arm64_sonoma`) and `macos-13` (Intel, `ventura`)
- **Formulas bottled:** `openmemory-mcp` and `openmemory-ui` (the ones with build-time work: virtualenv, pnpm build)
- **`qdrant` and `openmemory`** are not bottled (binary-only / trivial installs)
- After both platform builds succeed, a second job merges the bottle JSON manifests back into the formula files and commits the updated SHA256 hashes

To release a new version:
```bash
git tag v1.0.11
git push origin v1.0.11
```

The CI workflow handles the rest — uploading bottle tarballs to the GitHub Release and committing the updated bottle hashes into `Formula/*.rb`.
