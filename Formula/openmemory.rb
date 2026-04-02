class Openmemory < Formula
  desc "Self-hosted memory layer for AI — Qdrant + FastAPI backend + Next.js UI"
  homepage "https://github.com/mem0ai/mem0"
  url "https://github.com/mem0ai/mem0/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "PLACEHOLDER"
  license "Apache-2.0"

  head "https://github.com/mem0ai/mem0.git", branch: "main"

  depends_on "gdziegielewski/openmemory/qdrant"
  depends_on "gdziegielewski/openmemory/openmemory-mcp"
  depends_on "gdziegielewski/openmemory/openmemory-ui"

  def install
    # Install example config
    (etc/"openmemory").mkpath
    etc.install "config/openmemory.env.example" => "openmemory/openmemory.env.example"

    # Write the openmemory wrapper script
    (bin/"openmemory").write <<~EOS
      #!/bin/bash
      set -euo pipefail

      SERVICES=(qdrant openmemory-mcp openmemory-ui)
      ENV_FILE="#{etc}/openmemory/openmemory.env"
      ENV_EXAMPLE="#{etc}/openmemory/openmemory.env.example"

      usage() {
        echo "Usage: openmemory <command>"
        echo ""
        echo "Commands:"
        echo "  start    Start all OpenMemory services (qdrant, openmemory-mcp, openmemory-ui)"
        echo "  stop     Stop all OpenMemory services"
        echo "  restart  Restart all OpenMemory services"
        echo "  status   Show status of all OpenMemory services"
        echo ""
        echo "Configuration:"
        echo "  Edit ${ENV_FILE}"
        echo "  Required: set OPENAI_API_KEY to your key"
        exit 1
      }

      check_config() {
        if [[ ! -f "${ENV_FILE}" ]]; then
          echo "ERROR: Configuration file not found: ${ENV_FILE}"
          echo "  Copy the example: cp ${ENV_EXAMPLE} ${ENV_FILE}"
          echo "  Then edit it and set your OPENAI_API_KEY."
          exit 1
        fi

        # Source the env file to read OPENAI_API_KEY
        set -a
        # shellcheck disable=SC1090
        source "${ENV_FILE}"
        set +a

        if [[ -z "${OPENAI_API_KEY:-}" ]] || [[ "${OPENAI_API_KEY}" == "sk-replace-me" ]]; then
          echo "ERROR: OPENAI_API_KEY is not configured."
          echo "  Edit ${ENV_FILE} and replace 'sk-replace-me' with your actual key."
          exit 1
        fi
      }

      cmd_start() {
        check_config
        echo "Starting OpenMemory services..."
        for svc in "${SERVICES[@]}"; do
          echo "  → brew services start ${svc}"
          brew services start "${svc}"
        done
        echo "OpenMemory started."
        echo "  MCP API: http://localhost:${OPENMEMORY_PORT:-8765}"
        echo "  UI:      http://localhost:${OPENMEMORY_UI_PORT:-3000}"
      }

      cmd_stop() {
        echo "Stopping OpenMemory services..."
        for svc in "${SERVICES[@]}"; do
          echo "  → brew services stop ${svc}"
          brew services stop "${svc}" || true
        done
        echo "OpenMemory stopped."
      }

      cmd_restart() {
        check_config
        echo "Restarting OpenMemory services..."
        for svc in "${SERVICES[@]}"; do
          echo "  → brew services restart ${svc}"
          brew services restart "${svc}"
        done
        echo "OpenMemory restarted."
      }

      cmd_status() {
        brew services list | grep -E "(^Name|qdrant|openmemory)" || true
      }

      if [[ $# -lt 1 ]]; then
        usage
      fi

      case "$1" in
        start)   cmd_start ;;
        stop)    cmd_stop ;;
        restart) cmd_restart ;;
        status)  cmd_status ;;
        *)       usage ;;
      esac
    EOS

    chmod 0755, bin/"openmemory"
  end

  def post_install
    (var/"openmemory").mkpath
    (var/"log/openmemory").mkpath

    env_file    = etc/"openmemory/openmemory.env"
    env_example = etc/"openmemory/openmemory.env.example"

    unless env_file.exist?
      FileUtils.cp env_example, env_file
      env_file.chmod 0600
    end
  end

  def caveats
    s = <<~EOS
      OpenMemory has been installed.

      1. Configure your API key:
           #{etc}/openmemory/openmemory.env

         Edit that file and replace 'sk-replace-me' with your actual OpenAI API key:
           OPENAI_API_KEY=sk-...

      2. Start all services:
           openmemory start

         Or start individual services:
           brew services start qdrant
           brew services start openmemory-mcp
           brew services start openmemory-ui

      3. Once running:
           MCP API: http://localhost:8765
           UI:      http://localhost:3000

      To check status:
           openmemory status
    EOS
    s
  end

  test do
    assert_predicate bin/"openmemory", :executable?
    output = shell_output("#{bin}/openmemory bad-cmd 2>&1 || true")
    assert_match "Usage: openmemory", output
  end
end
