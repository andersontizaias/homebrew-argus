<p align="center">
  <img src="img/logo.png" alt="Argus Agent" width="180">
</p>

# Argus Agent — Homebrew Tap

Official Homebrew tap for [Argus Agent](https://github.com/andersontizaias/argus-agent), an autonomous QA testing agent for web, Android, and iOS apps, powered by LangGraph.

## Installation

```bash
brew tap andersontizaias/argus
brew install andersontizaias/argus/argus-agent
```

## Usage

```bash
argus            # starts the API + web UI at http://127.0.0.1:8765
argus-worker     # processes queued test runs (run in a separate terminal)
argus-doctor     # checks your environment (Playwright, Appium, Android/iOS toolchains)
```

The first run sets up its dependencies (Python packages and a Chromium browser, ~200 MB) — this takes a few minutes. Subsequent runs start instantly.

To start Argus automatically on login instead of running it manually, `brew info argus-agent` shows the exact command for your install.

Testing Android/iOS apps requires Android Studio/Xcode and Appium set up separately; run `argus-doctor` to check what's missing.

For full documentation — configuration, BDD scripts, providers, and more — see the [main repository](https://github.com/andersontizaias/argus-agent).

## License

[MIT](./LICENSE)
