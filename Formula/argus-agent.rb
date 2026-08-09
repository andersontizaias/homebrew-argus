class ArgusAgent < Formula
  desc "Autonomous QA agent (web, Android, iOS) built with LangGraph"
  homepage "https://github.com/andersontizaias/argus-agent"
  # Repositório público — URL direta de release, sem headers/token. Pra
  # bumpar versão: só troca a tag no url/version e recalcula o sha256.
  url "https://github.com/andersontizaias/argus-agent/releases/download/v0.1.6/argus-agent-v0.1.6.tar.gz"
  version "0.1.6"
  sha256 "8bb836129ac7159d08949497e5006204fe1ad8dc3265ec93a445724017114a26"
  license "MIT"

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
        echo "== Argus Agent: setting up dependencies (first run of this version only) ==" >&2
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

        "${UV}" run --project "${LIBEXEC}" alembic -c "${LIBEXEC}/alembic.ini" upgrade head
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
      The first call to `argus`/`argus-worker`/`argus-doctor` does the setup
      (uv sync + Playwright Chromium — takes a few minutes and downloads
      ~200 MB); later calls are instant.

      Run it:
        argus            # API + UI at http://127.0.0.1:8765
        argus-worker     # processes runs (separate terminal)

      To start automatically on login via LaunchAgents:
        ARGUS_INSTALL_DIR="#{opt_libexec}" "#{opt_libexec}/scripts/launchd/install.sh"

      Android/iOS testing needs Android Studio/Xcode + Appium set up
      separately — run "#{opt_libexec}/scripts/bootstrap.sh" to check what's
      missing (it instructs instead of downloading SDKs/runtimes on its own).

      Database, artifacts, logs and the Python venv live in ~/.argus/ — never
      in #{opt_libexec}.
    EOS
  end

  test do
    assert_path_exists bin/"argus"
    assert_path_exists libexec/"src/main.py"
  end
end
