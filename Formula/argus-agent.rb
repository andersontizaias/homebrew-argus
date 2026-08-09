class ArgusAgent < Formula
  desc "Agente de QA autônomo (web, Android, iOS) com LangGraph, Playwright e Appium"
  homepage "https://github.com/andersontizaias/argus-agent"
  # GitHubPrivateRepositoryReleaseDownloadStrategy foi removida do Homebrew —
  # o substituto suportado é baixar direto do endpoint de asset da API (que
  # aceita Authorization: token e responde com Content-Disposition, então o
  # CurlDownloadStrategy padrão já reconhece o .tar.gz certinho). O token é
  # lido via ENV.clear_sensitive_environment_for_eval! pra não vazar o
  # segredo pro cache/log de specs do Homebrew — só é expandido na hora do
  # download de verdade.
  url "https://api.github.com/repos/andersontizaias/argus-agent/releases/assets/506716103",
      headers: [
        "Accept: application/octet-stream",
        ENV.clear_sensitive_environment_for_eval! do
          "Authorization: token #{ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", nil)}"
        end,
      ]
  version "0.1.1"
  sha256 "4db1def40138ea3d5e3d43a70aee52a249af6b565c5c2d6cb83140b3ffa123d9"
  license "UNLICENSED"

  depends_on "uv"

  # node@22 e Appium (npm install -g appium + drivers uiautomator2/xcuitest)
  # só são necessários pra testes Android/iOS — não são dependência da
  # fórmula pra manter `brew install argus-agent` leve pra quem só usa web. Veja
  # os caveats e `scripts/bootstrap.sh` no pacote instalado.

  # `uv sync`/Playwright NÃO rodam em `install`/`post_install`: essas fases
  # do Homebrew sandboxam $HOME pra um diretório temporário (correto, evita
  # que a build mexa na máquina de verdade) — qualquer coisa escrita em
  # "~/.argus" ali vira lixo descartado no fim do build, e além disso
  # pacotes Python compilados (.so) instalados DENTRO do Cellar quebram o
  # passo de "fix install linkage" que o Homebrew roda depois do `install`
  # (o binário não tem padding de header pra ser relinkado pro caminho
  # longo do Cellar). A solução pras duas coisas é a mesma: adiar todo esse
  # setup pra primeira execução real de `argus`/`argus-worker`/
  # `argus-doctor`, feita pelo usuário com o $HOME de verdade — daí o venv
  # (uv sync) cai em ~/.argus/venv, ao lado do banco e dos artefatos, nunca
  # dentro do Cellar.
  def install
    # Lista explícita (em vez de Dir["*"]) — só o que o app precisa em
    # runtime (uv sync/build do frontend/migrações), sem depender de como o
    # Homebrew decide limpar arquivos soltos na raiz do keg depois do
    # install (observado apagando um README.md copiado via glob).
    libexec.install "src", "migrations", "scripts", "frontend", "alembic.ini", "pyproject.toml", "uv.lock",
                     ".env.example"

    (libexec/".brew-run.sh").write <<~SH
      #!/usr/bin/env bash
      # Gerado pela fórmula Homebrew — não editar. Faz o setup do venv (só na
      # primeira execução desta versão) e então executa o comando pedido.
      set -euo pipefail
      LIBEXEC="#{libexec}"
      UV="#{formula_opt_bin("uv")}/uv"
      export UV_PROJECT_ENVIRONMENT="${HOME}/.argus/venv"
      MARKER="${UV_PROJECT_ENVIRONMENT}/.synced-#{version}"

      if [[ ! -f "${MARKER}" ]]; then
        echo "== Argus Agent: preparando dependências (só na primeira vez desta versão) ==" >&2
        "${UV}" sync --project "${LIBEXEC}" --frozen
        "${UV}" run --project "${LIBEXEC}" playwright install chromium

        if [[ ! -f "${LIBEXEC}/.env" ]]; then
          cp "${LIBEXEC}/.env.example" "${LIBEXEC}/.env"
          SECRET="$("${UV}" run --project "${LIBEXEC}" python3 -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())')"
          python3 -c "
      import re
      path = '${LIBEXEC}/.env'
      key = '''${SECRET}'''
      text = open(path).read()
      text = re.sub(r'^ARGUS_SECRET_KEY=.*$', f'ARGUS_SECRET_KEY={key}', text, flags=re.M)
      open(path, 'w').write(text)
      "
        fi

        "${UV}" run --project "${LIBEXEC}" alembic upgrade head
        mkdir -p "${UV_PROJECT_ENVIRONMENT}"
        touch "${MARKER}"
      fi

      exec "${UV}" run --project "${LIBEXEC}" "$@"
    SH
    (libexec/".brew-run.sh").chmod 0755

    %w[argus argus-worker argus-doctor].each do |cmd|
      (bin/cmd).write <<~SH
        #!/usr/bin/env bash
        exec "#{libexec}/.brew-run.sh" #{cmd} "$@"
      SH
    end
  end

  def caveats
    <<~EOS
      Repositório privado — este tap e os assets de release exigem
      HOMEBREW_GITHUB_API_TOKEN com acesso de leitura ao repo.

      A primeira chamada de `argus`/`argus-worker`/`argus-doctor` faz o setup
      (uv sync + Playwright Chromium — leva alguns minutos e baixa ~200 MB);
      as próximas são instantâneas.

      Rodar:
        argus            # API + UI em http://127.0.0.1:8765
        argus-worker     # processa execuções (em outro terminal)

      Pra subir sozinho no login via LaunchAgents:
        ARGUS_INSTALL_DIR="#{opt_libexec}" "#{opt_libexec}/scripts/launchd/install.sh"

      Testes Android/iOS exigem Android Studio/Xcode + Appium configurados à
      parte — rode "#{opt_libexec}/scripts/bootstrap.sh" pra checar o que falta
      (ele instrui em vez de baixar SDKs/runtimes sozinho).

      Banco, artefatos, logs e o venv Python ficam em ~/.argus/ — nunca em
      #{opt_libexec}.
    EOS
  end

  test do
    assert_path_exists bin/"argus"
    assert_path_exists libexec/"src/main.py"
  end
end
