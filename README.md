# homebrew-argus

Tap Homebrew privado do [Argus Agent](https://github.com/andersontizaias/argus-agent).

```bash
export HOMEBREW_GITHUB_API_TOKEN=ghp_xxx   # token de leitura do argus-agent (repo privado)
brew tap andersontizaias/argus
brew install argus
```

A fórmula baixa o tarball da release mais recente do `argus-agent` (via
`GitHubPrivateRepositoryReleaseDownloadStrategy`, por isso o token) e roda
`uv sync` + `playwright install chromium` + `alembic upgrade head` — ao
final, `argus`/`argus-worker`/`argus-doctor` já estão no PATH e prontos.

Pra atualizar a fórmula numa nova versão do argus-agent: mude `url`/`version`
pro novo tag e recalcule o `sha256` do tarball da release.
