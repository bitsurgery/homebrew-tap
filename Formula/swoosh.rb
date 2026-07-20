# Homebrew formula for swoosh.
#
# ── Sibling-payload invariant ───────────────────────────────────────────────
# swoosh is distributed as a single tarball (produced by scripts/release.sh in
# the swoosh source tree) containing THREE binaries as siblings:
#
#   swoosh                              — the main TUI/agent binary (macOS native)
#   swoosh-host-shim-linux-{arch}       — musl static binary (container-side)
#   swoosh-relay-linux-{arch}           — musl static binary (relay/forwarder)
#
# The build proxy (src/sandbox/proxy.rs) resolves the two musl payloads as
# SIBLINGS of the running swoosh binary via `current_exe().parent()`. On macOS,
# Rust's `current_exe()` dereferences symlinks to the real binary, so the three
# files MUST all live in the SAME directory. This formula therefore installs all
# three flat into `bin/` and deliberately does NOT use the libexec + symlink
# split that Homebrew commonly uses for "internal" helper binaries. See the
# "Architecture: command execution" section of AGENTS.md.
#
# ── Tarball source ──────────────────────────────────────────────────────────
# The macOS tarballs are built and published by scripts/release.sh:
#   swoosh-{version}-aarch64-apple-darwin.tar.gz   (Apple Silicon)
#   swoosh-{version}-x86_64-apple-darwin.tar.gz    (Intel)
# Each extracts to `swoosh-{version}-{triple}/` with the three binaries inside.
# Fill in the `url`/`sha256` placeholders below once a release is published.

class Swoosh < Formula
  desc "TUI coding agent"
  homepage "https://github.com/bitsurgery/swoosh"
  license "MIT"

  on_macos do
    on_arm do
      # TODO: replace url/sha256 with the real aarch64 tarball from release.sh output.
      url "https://github.com/bitsurgery/swoosh/releases/download/v0.1.0/swoosh-0.1.0-aarch64-apple-darwin.tar.gz"
      sha256 "b78e6bbb7005eca89a03aa573486a314fbd5417dfb9d7ec0f75493b10c73413b"
    end

    on_intel do
      # TODO: replace url/sha256 with the real x86_64 tarball from release.sh output.
      url "https://github.com/bitsurgery/swoosh/releases/download/v0.1.0/swoosh-0.1.0-x86_64-apple-darwin.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  def install
    # The tarball extracts to a single top-level dir
    # `swoosh-{version}-{triple}/` containing the three binaries as siblings.
    # Locate that dir explicitly (don't rely on the install cwd) and install all
    # three binaries flat into bin/ as siblings. CRITICAL: the proxy resolves the
    # two musl payloads via current_exe().parent(), so they MUST sit next to the
    # swoosh binary in the same directory — do NOT split into libexec + symlink.
    pkg = Dir["swoosh-*"].find { |d| File.directory?(d) }
    odie "Tarball did not extract a swoosh-* directory" if pkg.nil?

    bin.install "#{pkg}/swoosh"
    bin.install Dir["#{pkg}/swoosh-host-shim-linux-*"]
    bin.install Dir["#{pkg}/swoosh-relay-linux-*"]
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
