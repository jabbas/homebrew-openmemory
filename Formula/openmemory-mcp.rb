class OpenmemoryMcp < Formula
  desc "MCP server — Python/FastAPI backend with SQLite + Qdrant for OpenMemory"
  homepage "https://github.com/mem0ai/mem0"
  url "https://github.com/mem0ai/mem0/archive/refs/tags/v1.0.10.tar.gz"
  sha256 "a97a7dde9e3a410b42ae5b17e3afffa6394a0d7f9d3a48a69b08298486ddf171"
  license "Apache-2.0"

  head "https://github.com/mem0ai/mem0.git", branch: "main"

  depends_on "jabbas/openmemory/qdrant"
  depends_on "python@3.12"

  # Prevent Homebrew from relocating dylibs inside pip-installed packages
  # (e.g. cryptography's Rust-built .so uses @rpath which cannot be relocated).
  skip_clean "libexec"

  def install
    # Copy the API source tree into libexec
    libexec_app = libexec/"app"
    libexec_app.mkpath
    (buildpath/"openmemory/api").each_child do |f|
      cp_r f, libexec_app
    end

    # Comment out psycopg2-binary — it requires PostgreSQL headers;
    # OpenMemory uses SQLite and does not need it.
    inreplace libexec_app/"requirements.txt",
              /^(psycopg2-binary.*)$/, '#\1'

    # Also strip test-only deps that are not needed at runtime and can
    # cause build failures in constrained CI environments.
    inreplace libexec_app/"requirements.txt",
              /^(pytest.*)$/, '#\1'

    # Create a full virtual environment (with pip via ensurepip).
    # We avoid Homebrew's virtualenv_create because it creates the venv
    # with --without-pip, which prevents us from pip-installing a
    # requirements.txt with a large transitive dependency tree.
    python3 = Formula["python@3.12"].opt_bin/"python3.12"
    system python3, "-m", "venv", libexec/"venv"
    venv_pip = libexec/"venv/bin/pip"

    # Install Python dependencies into the venv
    system venv_pip, "install", "--no-cache-dir",
           "-r", libexec_app/"requirements.txt"

    # Write the main server wrapper
    (bin/"openmemory-mcp-server").write <<~EOS
      #!/bin/bash
      set -euo pipefail

      ENV_FILE="#{etc}/openmemory/openmemory.env"

      # Source configuration if it exists
      if [[ -f "${ENV_FILE}" ]]; then
        set -a
        # shellcheck disable=SC1090
        source "${ENV_FILE}"
        set +a
      fi

      # Validate API key
      if [[ -z "${OPENAI_API_KEY:-}" ]] || [[ "${OPENAI_API_KEY}" == "sk-replace-me" ]]; then
        echo "ERROR: OPENAI_API_KEY is not configured or still set to placeholder." >&2
        echo "  Edit ${ENV_FILE} and set a valid key." >&2
        exit 1
      fi

      # Ensure data directory exists
      DATA_DIR="${OPENMEMORY_DATA_DIR:-#{var}/openmemory}"
      mkdir -p "${DATA_DIR}"

      # Database URL (absolute path required for launchd)
      export DATABASE_URL="${DATABASE_URL:-sqlite:////${DATA_DIR}/openmemory.db}"

      # Qdrant connection
      export QDRANT_HOST="${QDRANT_HOST:-localhost}"
      export QDRANT_PORT="${QDRANT_PORT:-6333}"

      # Server bind settings
      HOST="${OPENMEMORY_HOST:-0.0.0.0}"
      PORT="${OPENMEMORY_PORT:-8765}"
      WORKERS="${OPENMEMORY_WORKERS:-1}"

      # alembic reads alembic.ini relative to CWD — must cd into app dir
      cd "#{libexec}/app"

      exec "#{libexec}/venv/bin/uvicorn" main:app \\
        --host "${HOST}" \\
        --port "${PORT}" \\
        --workers "${WORKERS}"
    EOS

    chmod 0755, bin/"openmemory-mcp-server"

    # Write the migration wrapper
    (bin/"openmemory-migrate").write <<~EOS
      #!/bin/bash
      set -euo pipefail

      ENV_FILE="#{etc}/openmemory/openmemory.env"

      if [[ -f "${ENV_FILE}" ]]; then
        set -a
        # shellcheck disable=SC1090
        source "${ENV_FILE}"
        set +a
      fi

      # Database URL (absolute path required for launchd)
      DATA_DIR="${OPENMEMORY_DATA_DIR:-#{var}/openmemory}"
      export DATABASE_URL="${DATABASE_URL:-sqlite:////${DATA_DIR}/openmemory.db}"

      echo "Running database migrations..."
      cd "#{libexec}/app"
      exec "#{libexec}/venv/bin/alembic" upgrade head
    EOS

    chmod 0755, bin/"openmemory-migrate"
  end

  def post_install
    (var/"openmemory").mkpath
    (var/"log/openmemory").mkpath

    env_file = etc/"openmemory/openmemory.env"

    if env_file.exist?
      system opt_bin/"openmemory-migrate"
    else
      opoo "openmemory.env not found — skipping database migration."
      opoo "After configuring #{etc}/openmemory/openmemory.env, run: openmemory-migrate"
    end
  end

  service do
    run [opt_bin/"openmemory-mcp-server"]
    keep_alive true
    working_dir var/"openmemory"
    log_path var/"log/openmemory/mcp.log"
    error_log_path var/"log/openmemory/mcp.error.log"
    environment_variables PATH: std_service_path_env
  end

  test do
    # Verify venv executables exist
    assert_predicate libexec/"venv/bin/python3.12", :executable?
    assert_predicate libexec/"venv/bin/uvicorn", :executable?
    assert_predicate libexec/"venv/bin/alembic", :executable?

    # Verify wrapper scripts exist
    assert_predicate bin/"openmemory-mcp-server", :executable?
    assert_predicate bin/"openmemory-migrate", :executable?

    # Verify Python packages are importable
    system libexec/"venv/bin/python3.12", "-c", "import fastapi; import uvicorn"
  end
end
