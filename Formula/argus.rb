class Argus < Formula
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
  # fórmula pra manter `brew install argus` leve pra quem só usa web. Veja
  # os caveats e `scripts/bootstrap.sh` no pacote instalado.

  def install
    libexec.install Dir["*"]
    system formula_opt_bin("uv")/"uv", "sync", "--project", libexec, "--frozen"
    system formula_opt_bin("uv")/"uv", "run", "--project", libexec, "playwright", "install", "chromium"

    %w[argus argus-worker argus-doctor].each do |cmd|
      (bin/cmd).write <<~SH
        #!/usr/bin/env bash
        exec "#{formula_opt_bin("uv")}/uv" run --project "#{libexec}" #{cmd} "$@"
      SH
    end
  end

  def post_install
    env_file = libexec/".env"
    unless env_file.exist?
      cp libexec/".env.example", env_file
      secret = Utils.safe_popen_read(
        formula_opt_bin("uv")/"uv", "run", "--project", libexec, "python3", "-c",
        "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
      ).strip
      inreplace env_file, /^ARGUS_SECRET_KEY=.*$/, "ARGUS_SECRET_KEY=#{secret}"
    end
    system formula_opt_bin("uv")/"uv", "run", "--project", libexec, "alembic", "upgrade", "head"
  end

  def caveats
    <<~EOS
      Repositório privado — este tap e os assets de release exigem
      HOMEBREW_GITHUB_API_TOKEN com acesso de leitura ao repo.

      Rodar:
        argus            # API + UI em http://127.0.0.1:8765
        argus-worker     # processa execuções (em outro terminal)

      Pra subir sozinho no login via LaunchAgents:
        ARGUS_INSTALL_DIR="#{opt_libexec}" "#{opt_libexec}/scripts/launchd/install.sh"

      Testes Android/iOS exigem Android Studio/Xcode + Appium configurados à
      parte — rode "#{opt_libexec}/scripts/bootstrap.sh" pra checar o que falta
      (ele instrui em vez de baixar SDKs/runtimes sozinho).

      Banco, artefatos e logs ficam em ~/.argus/ — nunca em #{opt_libexec}.
    EOS
  end

  test do
    output = shell_output(
      "#{formula_opt_bin("uv")}/uv run --project #{libexec} python3 -c " \
      "'from src.settings import VERSION; print(VERSION)'",
    )
    assert_match version.to_s, output
  end
end
