<#
.SYNOPSIS
    Copia um modelo de configuração (VS Code, EditorConfig, Git) para um projeto.

.DESCRIPTION
    Modelos disponíveis em templates\:
      python  -> Django, Flask ou FastAPI com uv, Ruff e pytest (debug pronto no F5)
      web     -> HTML/CSS/JS, React (Vite) ou Next.js com Prettier, ESLint e Tailwind

    Arquivos que já existem no destino NÃO são sobrescritos (use -Force para isso).

.PARAMETER Template
    python ou web.
.PARAMETER Path
    Pasta do projeto. É criada se não existir. Padrão: pasta atual.
.PARAMETER DevContainer
    Também copia um .devcontainer\ (Python + Node) para desenvolver dentro do Docker.
.PARAMETER Force
    Sobrescreve arquivos existentes.

.EXAMPLE
    .\scripts\new-project.ps1 -Template python -Path C:\dev\minha-api

.EXAMPLE
    npx create-next-app@latest C:\dev\meu-site
    .\scripts\new-project.ps1 -Template web -Path C:\dev\meu-site
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('python', 'web')][string]$Template,
    [string]$Path = '.',
    [switch]$DevContainer,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$TemplatesRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'templates'

New-Item -ItemType Directory -Force -Path $Path | Out-Null
$Target = (Resolve-Path $Path).Path
$ProjectName = ((Split-Path -Leaf $Target).ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
if (-not $ProjectName) { $ProjectName = 'meu-projeto' }

$script:Created = @()

function Copy-TemplateFolder([string]$Name) {
    $from = (Resolve-Path (Join-Path $TemplatesRoot $Name)).Path
    Get-ChildItem -Path $from -Recurse -File -Force | ForEach-Object {
        $relative = $_.FullName.Substring($from.Length).TrimStart('\', '/')
        $destination = Join-Path $Target $relative
        if ((Test-Path $destination) -and -not $Force) {
            Write-Host "  pulado (já existe): $relative" -ForegroundColor Yellow
            return
        }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        Copy-Item -Path $_.FullName -Destination $destination -Force
        $script:Created += $destination
        Write-Host "  criado: $relative" -ForegroundColor Green
    }
}

Write-Host "`n==> Aplicando o modelo '$Template' em $Target" -ForegroundColor Cyan
Copy-TemplateFolder $Template
Copy-TemplateFolder 'common'
if ($DevContainer) { Copy-TemplateFolder 'devcontainer' }

# Troca o nome genérico "meu-projeto" pelo nome da pasta nos arquivos recém-criados.
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
foreach ($file in $script:Created) {
    if ((Split-Path -Leaf $file) -notin @('pyproject.toml', 'devcontainer.json')) { continue }
    $text = [System.IO.File]::ReadAllText($file)
    [System.IO.File]::WriteAllText($file, $text.Replace('meu-projeto', $ProjectName), $utf8NoBom)
}

# Inicia um repositório Git se a pasta ainda não estiver dentro de um.
if (Get-Command git -ErrorAction SilentlyContinue) {
    Push-Location $Target
    try {
        $ErrorActionPreference = 'Continue'
        git rev-parse --is-inside-work-tree *> $null
        if ($LASTEXITCODE -ne 0) {
            git init --quiet
            Write-Host '  repositório Git criado' -ForegroundColor Green
        }
    }
    finally {
        $ErrorActionPreference = 'Stop'
        Pop-Location
    }
}

Write-Host "`nPronto! Abra o projeto com:  code `"$Target`"" -ForegroundColor Cyan
if ($Template -eq 'python') {
    Write-Host '  Depois, no terminal do VS Code:  uv sync   (cria o .venv e instala as dependências)'
}
else {
    Write-Host '  Depois, no terminal do VS Code:  npm install'
}
