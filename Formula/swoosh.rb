# Homebrew formula for swoosh.
#
# ── Payloads are resources, not host executables ────────────────────────────
# The tarball (produced by scripts/release.sh in the swoosh source tree)
# contains FIVE binaries as flat siblings:
#
#   swoosh                              — the main TUI/agent binary (macOS native)
#   swoosh-host-shim-linux-{arch}       — musl static binary (container-side)
#   swoosh-relay-linux-{arch}           — musl static binary (relay/forwarder)
#   swoosh-mcp-shim-linux-{arch}        — musl static binary (claude-wrapper MCP)
#   swoosh-fs-linux-{arch}              — musl static binary (CORE in-container file ops)
#
# Only `swoosh` is a real HOST executable (Mach-O); it goes in bin/. The four
# musl payloads are RESOURCES: they are bind-mounted read-only into Linux
# containers (src/sandbox/compose.rs) where the container's kernel exec's them,
# and are NEVER exec'd on the host. They go in libexec/ — NOT bin/ — because
# Homebrew resets non-Mach-O files in bin/ to mode 0444 and audits them as
# "non-executables". libexec/ is not audited, so they keep the 0755 mode the
# tarball ships (which the container needs via the :ro bind mount). The proxy
# resolves them at <swoosh_dir>/../libexec/<name> (resolve_payload_path in
# src/sandbox/proxy.rs). See "Architecture: command execution" in AGENTS.md.
#
# ── Tarball source ──────────────────────────────────────────────────────────
# The macOS tarballs are built and published by scripts/release.sh:
#   swoosh-{version}-aarch64-apple-darwin.tar.gz   (Apple Silicon)
#   swoosh-{version}-x86_64-apple-darwin.tar.gz    (Intel)
# Each extracts to `swoosh-{version}-{triple}/` with the five binaries inside.
# Fill in the `url`/`sha256` placeholders below once a release is published.

class Swoosh < Formula
  desc "TUI coding agent"
  homepage "https://github.com/bitsurgery/swoosh"
  license "MIT"

  on_macos do
    on_arm do
      # TODO: replace url/sha256 with the real aarch64 tarball from release.sh output.
      url "https://github.com/bitsurgery/swoosh/releases/download/v0.2.13/swoosh-0.2.13-aarch64-apple-darwin.tar.gz"
      sha256 "ac7f09fa92f9c33da841714e83260b11d0203e8830b6f829a17a21bb89004dbb"
    end

    on_intel do
      # TODO: replace url/sha256 with the real x86_64 tarball from release.sh output.
      url "https://github.com/bitsurgery/swoosh/releases/download/v0.1.0/swoosh-0.1.0-x86_64-apple-darwin.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  def install
    # The tarball contains the five binaries as siblings (swoosh + the four
    # musl payloads). release.sh packages them under a `swoosh-{version}-{triple}/`
    # dir, but be robust to the exact extraction layout (a wrapper dir from the
    # upload process, or flat at the root): find the dir that actually contains
    # the `swoosh` binary.
    pkg = ["swoosh-*", "*", "."].each do |glob|
      found = Dir[glob].find { |d| File.file?(File.join(d, "swoosh")) }
      break found if found
    end
    odie "Tarball did not extract a directory containing the swoosh binary" if pkg.nil?

    # The real host binary goes in bin/. The four musl payloads are RESOURCES,
    # not host executables — they are bind-mounted read-only into Linux
    # containers, where the container's kernel exec's them; they are never
    # exec'd on the host. Install them into libexec/ (Homebrew's convention
    # for internal/non-user-facing files), NOT bin/: Homebrew resets non-Mach-O
    # files in bin/ to mode 0444 and audits them as "non-executables". libexec/
    # is not audited, so they keep the 0755 mode the tarball ships (which the
    # container needs). The proxy resolves them at
    # <swoosh_dir>/../libexec/<name> (see resolve_payload_path in proxy.rs).
    bin.install "#{pkg}/swoosh"
    libexec.install Dir["#{pkg}/swoosh-host-shim-linux-*"]
    libexec.install Dir["#{pkg}/swoosh-relay-linux-*"]
    libexec.install Dir["#{pkg}/swoosh-mcp-shim-linux-*"]
    libexec.install Dir["#{pkg}/swoosh-fs-linux-*"]
  end

  def caveats
    <<~EOS
      swoosh runs its commands inside a hardened Docker container and uses the
      gVisor `runsc` runtime by default. It FAILS CLOSED if `runsc` is not
      installed rather than silently degrading to the weaker `runc` runtime.

      Before using swoosh you must:
        1. Have Docker installed and running.
        2. Install the gVisor `runsc` runtime and register it in
           /etc/docker/daemon.json (or explicitly opt out per-project).

      For a step-by-step gVisor install guide on macOS (Docker Desktop), see:
        https://github.com/bitsurgery/swoosh/blob/main/docs/gvisor-macos.md

      To opt out of gVisor for a session, set:
        SWOOSH_SANDBOX_RUNTIME=runc swoosh
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/swoosh --version")
  end
end
