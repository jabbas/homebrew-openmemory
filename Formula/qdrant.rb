class Qdrant < Formula
  desc "Vector database for high-performance similarity search"
  homepage "https://qdrant.tech"
  version "1.17.1"
  license "Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/qdrant/qdrant/releases/download/v1.17.1/qdrant-aarch64-apple-darwin.tar.gz"
      sha256 "adf795d7c2ac9d93677517fd58b119e9bb5bc8fc5143ac9b581a6f8264def8da"
    end
    on_intel do
      url "https://github.com/qdrant/qdrant/releases/download/v1.17.1/qdrant-x86_64-apple-darwin.tar.gz"
      sha256 "d7308c504afa58eb4aa2bd0c655252c324aea04891ac079b6b8764b33fa7dc15"
    end
  end

  def install
    bin.install "qdrant"

    # Write a default config file
    (etc/"qdrant").mkpath
    (etc/"qdrant/config.yaml").write <<~YAML unless (etc/"qdrant/config.yaml").exist?
      storage:
        storage_path: #{var}/qdrant/storage

      service:
        host: 0.0.0.0
        http_port: 6333
        grpc_port: 6334

      log_level: INFO
    YAML
  end

  def post_install
    (var/"qdrant/storage").mkpath
    (var/"log/openmemory").mkpath
  end

  service do
    run [opt_bin/"qdrant", "--config-path", etc/"qdrant/config.yaml"]
    keep_alive true
    working_dir var/"qdrant"
    log_path var/"log/openmemory/qdrant.log"
    error_log_path var/"log/openmemory/qdrant.error.log"
    environment_variables PATH: std_service_path_env
  end

  test do
    assert_predicate bin/"qdrant", :executable?
    # Verify the binary runs and prints version info
    assert_match version.to_s.delete("v"), shell_output("#{bin}/qdrant --version 2>&1")
  end
end
