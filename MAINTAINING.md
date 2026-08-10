# Maintaining this tap

Internal notes for maintainers — not relevant to end users, kept out of the README.

## Bumping the formula to a new version

1. Wait for the `argus-agent` release workflow to publish `argus-agent-vX.Y.Z.tar.gz` on the [releases page](https://github.com/andersontizaias/argus-agent/releases).
2. Download it and compute its checksum: `shasum -a 256 argus-agent-vX.Y.Z.tar.gz`.
3. In `Formula/argus-agent.rb`, update `url`, `version`, and `sha256` to match.
4. Sanity-check locally before pushing: `brew style Formula/argus-agent.rb`, then `brew upgrade argus-agent` (or `brew install` if not already installed) and `brew test argus-agent`.
5. Commit and push to `main` — the tap has no CI, so this local check is the only gate.

## Why the fully-qualified name matters

`homebrew-core` already ships an unrelated formula named `argus` (a network audit tool, openargus.org). Homebrew's tap-trust check silently falls back to that one instead of erroring if a user runs `brew install argus` or `brew upgrade argus` — this is why the README always shows the fully-qualified `andersontizaias/argus/argus-agent`. The qualified name also auto-trusts the tap without needing `brew trust`.

## Why `install` doesn't run `uv sync`/Playwright/migrations

Homebrew's `install`/`post_install` phases sandbox `$HOME` to a throwaway temp directory (correct default — it stops the build from touching the real machine), and compiled Python packages placed inside the Cellar break Homebrew's post-install "fix install linkage" step. Both problems have the same fix: all of that setup is deferred to the first real invocation of `argus`/`argus-worker`/`argus-doctor`, run by the user with their real `$HOME` — so the venv (`uv sync`) lands in `~/.argus/venv`, next to the database and artifacts, never inside the Cellar. See the comments in `Formula/argus-agent.rb` for the implementation.
