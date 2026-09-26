# Ambiente de desenvolvimento: VS Code + Python + Web (Windows)

Kit para deixar o VS Code no Windows pronto para **Python (Django, Flask, FastAPI)** e
**Web (HTML/CSS/JS, React, Next.js)**, com espaço para outras stacks via WSL e Dev Containers.

```
vscode/
  settings.json        configurações globais do VS Code (fonte, formatação ao salvar, Python, Web, Git...)
  extensions.txt       extensões instaladas pelo script (comente/adicione à vontade)
scripts/
  setup-windows.ps1    instala programas + extensões e aplica as configurações
  new-project.ps1      copia um modelo de configuração para um projeto
templates/
  python/              .vscode (debug F5 p/ Django, Flask, FastAPI; testes), pyproject.toml, .gitignore
  web/                 .vscode (debug Next.js/Vite/HTML no Edge; Tailwind; TS), .gitignore
  common/              .editorconfig e .gitattributes (mesmo estilo e fim de linha em todo lugar)
  devcontainer/        .devcontainer com Python + Node para rodar o projeto dentro do Docker
```

## 1. Instalação (uma vez)

Abra o **PowerShell** (não precisa ser como administrador):

```powershell
# Se ainda não tiver o Git:
winget install --id Git.Git -e

# Feche e abra o PowerShell, depois:
git clone https://github.com/IXIstefano/claude.git $HOME\dev-env
cd $HOME\dev-env

# Permite rodar scripts locais (só na sua conta; pede confirmação)
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

.\scripts\setup-windows.ps1
```

O script instala o que faltar (**Git, VS Code, PowerShell 7, Windows Terminal, Python 3.13,
uv, Node.js LTS, GitHub CLI**), ajusta o Git, instala as extensões e aplica o `settings.json`.
Seu `settings.json` antigo é salvo como `settings.backup-<data>.json` na mesma pasta
(`%APPDATA%\Code\User`). Pode rodar de novo quando quiser: o que já existe é pulado.

| Opção             | O que faz                                                            |
| ----------------- | -------------------------------------------------------------------- |
| `-WithWSL`        | instala o WSL2 + Ubuntu (Linux no Windows). Reinicie o PC depois.    |
| `-WithDocker`     | instala o Docker Desktop (necessário para Dev Containers).           |
| `-SkipApps`       | não instala programas                                                |
| `-SkipGit`        | não mexe no `git config --global`                                    |
| `-SkipExtensions` | não instala extensões                                                |
| `-SkipSettings`   | não substitui o `settings.json`                                      |

Depois, **feche e abra o terminal** e configure sua identidade no Git:

```powershell
git config --global user.name  "Seu Nome"
git config --global user.email "voce@exemplo.com"
```

## 2. O que muda no VS Code

- **Formata ao salvar** (Ctrl+S): Ruff no Python, Prettier em JS/TS/HTML/CSS/JSON/Markdown.
  Também corrige lint (ESLint/Ruff) e organiza imports no Python.
- **Erros na própria linha** (Error Lens) e checagem de tipos do Python no modo `standard`.
- **Fim de linha LF** em arquivos novos e no Git: nada de diffs com CRLF entre Windows, WSL e Docker.
- **Abas com nome da pasta** quando o arquivo se repete: `dashboard/page`, `blog/views`.
- **Arquivos agrupados** no Explorer: `package-lock.json` dentro de `package.json`, `uv.lock` dentro de `pyproject.toml`...
- Caches (`__pycache__`, `.ruff_cache`...) escondidos; `.venv`, `.next` e `dist` fora da busca.
- Corretor ortográfico em **português e inglês** (Markdown, textos e mensagens de commit).
- **Claude Code** integrado ao editor.

Tudo está comentado em [`vscode/settings.json`](vscode/settings.json); mude o que quiser e rode
`.\scripts\setup-windows.ps1 -SkipApps -SkipGit -SkipExtensions` para reaplicar.

## 3. Criando projetos

O `new-project.ps1` copia o modelo sem sobrescrever arquivos existentes (use `-Force` para
sobrescrever) e inicia um repositório Git se precisar. Nos exemplos abaixo, o kit está em
`$HOME\dev-env`.

### FastAPI

```powershell
& $HOME\dev-env\scripts\new-project.ps1 -Template python -Path C:\dev\minha-api
cd C:\dev\minha-api
uv add "fastapi[standard]"
code .
```

Crie `app/__init__.py` (vazio) e `app/main.py`, depois **F5 → "FastAPI (uvicorn)"**.

### Django

```powershell
& $HOME\dev-env\scripts\new-project.ps1 -Template python -Path C:\dev\meu-site
cd C:\dev\meu-site
uv add django
uv run django-admin startproject config .
code .
```

Em `.vscode/settings.json`, descomente a linha `"django-html"`. **F5 → "Django (runserver)"**.

### Flask

```powershell
& $HOME\dev-env\scripts\new-project.ps1 -Template python -Path C:\dev\meu-app
cd C:\dev\meu-app
uv add flask
code .
```

Crie `app.py`, descomente a linha `"jinja-html"` no `.vscode/settings.json`. **F5 → "Flask (flask run)"**.

> Dica Python: `uv sync` cria o `.venv` e o VS Code o detecta sozinho. Rode comandos com
> `uv run ...` (ex.: `uv run pytest`). Os testes aparecem na aba **Testes** (ícone de frasco).

### Next.js / React

```powershell
npx create-next-app@latest C:\dev\meu-next     # ou: npm create vite@latest
& $HOME\dev-env\scripts\new-project.ps1 -Template web -Path C:\dev\meu-next
code C:\dev\meu-next
```

**F5 → "Next.js: full stack"** abre o Edge com breakpoints no servidor e no navegador.
Para Vite: rode `npm run dev` e use **"Edge: localhost:5173 (Vite)"**.

### HTML/CSS/JS puro

Abra a pasta no VS Code, clique com o botão direito no `index.html` → **Show Preview**
(Live Preview). A página recarrega sozinha ao salvar. Digite `!` + Tab num HTML vazio para o
esqueleto da página (Emmet).

## 4. Outras stacks no futuro

- **Dev Container** (recomendado para experimentar stacks sem instalar nada no Windows):
  rode o setup com `-WithDocker`, crie o projeto com `-DevContainer` e, no VS Code,
  `Ctrl+Shift+P` → **Dev Containers: Reopen in Container**. Para Go, Java, PHP, Rust etc.,
  troque a imagem ou adicione [features](https://containers.dev/features) em
  `.devcontainer/devcontainer.json`.
- **WSL** (Linux de verdade, mais rápido para ferramentas Unix): rode com `-WithWSL`, depois
  no VS Code `Ctrl+Shift+P` → **WSL: Connect to WSL**. Guarde os projetos dentro do Linux
  (`~/projetos`), não em `/mnt/c`, para ter desempenho bom.
- Nova extensão para todo mundo: adicione o ID em `vscode/extensions.txt` e rode
  `.\scripts\setup-windows.ps1 -SkipApps -SkipGit -SkipSettings`.

## 5. Atalhos que valem a pena decorar

| Atalho               | Ação                                        |
| -------------------- | ------------------------------------------- |
| `Ctrl+Shift+P`       | Paleta de comandos (tudo está aqui)         |
| `Ctrl+P`             | Abrir arquivo pelo nome                     |
| `Ctrl+Shift+F`       | Buscar em todo o projeto                    |
| `` Ctrl+` ``         | Mostrar/ocultar terminal                    |
| `F5` / `Shift+F5`    | Iniciar / parar debug                       |
| `F9`                 | Colocar/tirar breakpoint                    |
| `F12` / `Alt+←`      | Ir para a definição / voltar                |
| `F2`                 | Renomear símbolo em todo o projeto          |
| `Ctrl+.`             | Correções rápidas (imports, lint...)        |
| `Alt+↑` / `Alt+↓`    | Mover linha                                 |
| `Ctrl+D`             | Selecionar próxima ocorrência (multicursor) |
| `Ctrl+Shift+K`       | Apagar linha                                |
| `Ctrl+/`             | Comentar/descomentar                        |

## Desfazer

- Configurações: copie o `settings.backup-<data>.json` de volta para `settings.json` em
  `%APPDATA%\Code\User`.
- Extensões: `code --uninstall-extension <id>`.
- Programas: `winget uninstall --id <id>`.
