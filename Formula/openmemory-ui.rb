class OpenmemoryUi < Formula
  desc "OpenMemory UI — Next.js 15 frontend for the OpenMemory MCP server"
  homepage "https://github.com/mem0ai/mem0"
  url "https://github.com/mem0ai/mem0/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "PLACEHOLDER"
  license "Apache-2.0"

  head "https://github.com/mem0ai/mem0.git", branch: "main"

  depends_on "node"
  depends_on "pnpm" => :build

  def install
    libexec_ui = libexec/"ui"
    libexec_ui.mkpath

    # Copy the UI source tree (including dotfiles such as .env.example)
    (buildpath/"openmemory/ui").each_child do |f|
      cp_r f, libexec_ui
    end

    # Build the Next.js app
    Dir.chdir(libexec_ui) do
      system "pnpm", "install", "--frozen-lockfile"

      # NEXT_PUBLIC_API_URL is baked at build time.
      # NEXT_PUBLIC_USER_ID is intentionally NOT set here — it is fetched
      # from /api/v1/me at runtime so each user sees their own identity.
      ENV["NEXT_PUBLIC_API_URL"] = "http://localhost:8765"

      system "pnpm", "build"
    end

    # Write the server wrapper
    (bin/"openmemory-ui-server").write <<~EOS
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

      PORT="${OPENMEMORY_UI_PORT:-3000}"
      HOST="${OPENMEMORY_UI_HOST:-0.0.0.0}"

      cd "#{libexec}/ui"
      exec "#{HOMEBREW_PREFIX}/bin/node" node_modules/.bin/next start \
        -p "${PORT}" \
        -H "${HOST}"
    EOS

    chmod 0755, bin/"openmemory-ui-server"
  end

  service do
    run [opt_bin/"openmemory-ui-server"]
    keep_alive true
    working_dir var/"openmemory"
    log_path var/"log/openmemory/ui.log"
    error_log_path var/"log/openmemory/ui.error.log"
    environment_variables PATH: std_service_path_env
  end

  def caveats
    <<~EOS
      The Next.js UI has been built with:
        NEXT_PUBLIC_API_URL=http://localhost:8765

      This value is baked into the compiled bundle. If your MCP API server
      runs on a different host or port, you must rebuild the UI:

        cd #{opt_libexec}/ui
        NEXT_PUBLIC_API_URL=http://<your-host>:<port> pnpm build

      NEXT_PUBLIC_USER_ID is NOT baked in — it is fetched from the API at
      runtime via /api/v1/me.

      Access the UI at: http://localhost:3000
    EOS
  end

  test do
    # Wrapper must be executable
    assert_predicate bin/"openmemory-ui-server", :executable?

    # Build output directory must exist
    assert_predicate libexec/"ui/.next", :directory?

    # Next.js CLI must be available
    assert_predicate libexec/"ui/node_modules/.bin/next", :executable?
  end
end
