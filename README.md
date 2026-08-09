# homebrew-argus

Tap Homebrew privado do [Argus Agent](https://github.com/andersontizaias/argus-agent).

```bash
export HOMEBREW_GITHUB_API_TOKEN=ghp_xxx   # token de leitura do argus-agent (repo privado)
brew tap andersontizaias/argus
brew install andersontizaias/argus/argus-agent
```

Use o **nome totalmente qualificado** (`andersontizaias/argus/argus-agent`) — o homebrew-core já tem uma fórmula sem relação nenhuma chamada `argus` (ferramenta de auditoria de rede, `openargus.org`), e a checagem de confiança de tap do Homebrew cai silenciosamente pra ela em vez de dar erro se você usar só `argus`. Qualificado, também já confia na fórmula automaticamente (sem precisar de `brew trust`).

A fórmula só copia os arquivos no `install` — `uv sync` + `playwright install chromium` + `.env` + `alembic upgrade head` rodam na **primeira chamada real** de `argus`/`argus-worker`/`argus-doctor` (venv em `~/.argus/venv`, fora do Cellar), não durante o `brew install`. Isso é proposital: `install`/`post_install` do Homebrew rodam com `$HOME` sandboxado num diretório temporário descartável, e pacotes Python compilados dentro do Cellar quebram o passo de "fix install linkage" do Homebrew. Ver os comentários em `Formula/argus-agent.rb` pros detalhes.

O download usa o endpoint de asset da API do GitHub (`/releases/assets/:id`) com `Authorization: token` — a antiga `GitHubPrivateRepositoryReleaseDownloadStrategy` foi removida do Homebrew.

Pra atualizar a fórmula numa nova versão do argus-agent: pegue o novo `asset_id` (`gh api repos/andersontizaias/argus-agent/releases/tags/vX.Y.Z --jq '.assets[] | select(.name | endswith(".tar.gz"))'`), mude `url`/`version`, e recalcule o `sha256` do tarball baixado.
