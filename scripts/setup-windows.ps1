<#
.SYNOPSIS
    Prepara o Windows para desenvolvimento Python e Web com VS Code.

.DESCRIPTION
    1. Instala os programas via winget: Git, VS Code, PowerShell 7, Windows Terminal,
       Python, uv, Node.js LTS e GitHub CLI (e, opcionalmente, WSL e Docker Desktop).
    2. Ajusta o Git globalmente, sem sobrescrever o que você já configurou.
    3. Instala as extensões listadas em vscode\extensions.txt.
    4. Faz backup do seu settings.json do VS Code e aplica vscode\settings.json.

    Pode ser executado quantas vezes quiser: o que já está instalado é pulado.
    Não precisa abrir como administrador; o Windows pede permissão quando necessário.

.PARAMETER SkipApps
    Não instala nem verifica programas.
.PARAMETER SkipGit
    Não altera a configuração global do Git.
.PARAMETER SkipExtensions
    Não instala extensões do VS Code.
.PARAMETER SkipSettings
    Não mexe no settings.json do VS Code.
.PARAMETER WithWSL
    Instala o WSL2 com Ubuntu (Linux dentro do Windows). Exige reiniciar o PC.
.PARAMETER WithDocker
    Instala o Docker Desktop (necessário para Dev Containers). Exige WSL2.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1

.EXAMPLE
    .\scripts\setup-windows.ps1 -SkipApps -SkipGit
    Só reinstala extensões e reaplica as configurações do VS Code.
#>
[CmdletBinding()]
param(
    [switch]$SkipApps,
    [switch]$SkipGit,
    [switch]$SkipExtensions,
    [switch]$SkipSettings,
    [switch]$WithWSL,
    [switch]$WithDocker
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$script:Failures = @()

# Códigos do winget que significam "já está instalado / nada a atualizar".
$WingetAlreadyInstalled = @(-1978335189, -1978335135)
$WingetRebootRequired = -1978334967

function Write-Step([string]$Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "  [ok] $Message" -ForegroundColor Green }
function Write-Note([string]$Message) { Write-Host "  [!]  $Message" -ForegroundColor Yellow }

function Add-Failure([string]$Message) {
    Write-Host "  [x]  $Message" -ForegroundColor Red
    $script:Failures += $Message
}

# Roda um comando externo em silêncio e diz se ele terminou com sucesso.
# (No Windows PowerShell 5.1, redirecionar o stderr com ErrorAction=Stop gera exceção.)
function Test-NativeSuccess([scriptblock]$Command) {
    $ErrorActionPreference = 'Continue'
    & $Command *> $null
    return ($LASTEXITCODE -eq 0)
}

# Recarrega o PATH para enxergar programas recém-instalados sem abrir outro terminal.
function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $paths = @($machine, $user) | Where-Object { $_ }
    if ($paths) { $env:Path = $paths -join ';' }
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name,
        [string[]]$ExtraArgs = @()
    )
    if (Test-NativeSuccess { winget list --id $Id --exact --accept-source-agreements }) {
        Write-Ok "$Name já instalado"
        return
    }
    Write-Host "  instalando $Name..."
    $wingetArgs = @('install', '--id', $Id, '--exact', '--silent',
        '--accept-package-agreements', '--accept-source-agreements') + $ExtraArgs
    & winget @wingetArgs
    if ($LASTEXITCODE -eq 0 -or $WingetAlreadyInstalled -contains $LASTEXITCODE) {
        Write-Ok "$Name instalado"
    }
    elseif ($LASTEXITCODE -eq $WingetRebootRequired) {
        Write-Note "$Name instalado; reinicie o computador para concluir"
    }
    else {
        Add-Failure "falha ao instalar $Name (winget retornou $LASTEXITCODE)"
    }
}

function Set-GitConfigIfMissing([string]$Key, [string]$Value, [string]$Why) {
    $current = git config --global --get $Key
    if ($current) {
        Write-Ok "$Key já definido ($current), mantido"
        return
    }
    git config --global $Key $Value
    Write-Ok "$Key = $Value  ($Why)"
}

function Get-CodeCli {
    $cmd = Get-Command code.cmd -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'),
        (Join-Path $env:ProgramFiles 'Microsoft VS Code\bin\code.cmd')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Programas
# ─────────────────────────────────────────────────────────────────────────────
if (-not $SkipApps) {
    Write-Step 'Instalando programas (winget)'

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget não encontrado. Instale/atualize o 'Instalador de Aplicativo' (App Installer) pela Microsoft Store e rode o script de novo."
    }

    Install-WingetPackage -Id 'Git.Git' -Name 'Git'
    # Adiciona "Abrir com o Code" no menu de contexto do Explorer e o comando `code` no PATH.
    Install-WingetPackage -Id 'Microsoft.VisualStudioCode' -Name 'Visual Studio Code' -ExtraArgs @(
        '--override', '/VERYSILENT /SP- /MERGETASKS=!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath'
    )
    Install-WingetPackage -Id 'Microsoft.PowerShell' -Name 'PowerShell 7'
    Install-WingetPackage -Id 'Microsoft.WindowsTerminal' -Name 'Windows Terminal'
    # PrependPath=1 coloca o Python no PATH (evita abrir a Microsoft Store ao digitar "python").
    Install-WingetPackage -Id 'Python.Python.3.13' -Name 'Python 3.13' -ExtraArgs @(
        '--scope', 'user', '--override', '/quiet InstallAllUsers=0 PrependPath=1 Include_launcher=1 Include_test=0'
    )
    Install-WingetPackage -Id 'astral-sh.uv' -Name 'uv (gerenciador de projetos Python)'
    Install-WingetPackage -Id 'OpenJS.NodeJS.LTS' -Name 'Node.js LTS'
    Install-WingetPackage -Id 'GitHub.cli' -Name 'GitHub CLI'

    if ($WithDocker) {
        Install-WingetPackage -Id 'Docker.DockerDesktop' -Name 'Docker Desktop'
    }

    if ($WithWSL) {
        if (Test-NativeSuccess { wsl.exe --status }) {
            Write-Ok 'WSL já instalado'
        }
        else {
            Write-Host '  instalando WSL2 + Ubuntu (vai pedir permissão de administrador)...'
            $wsl = Start-Process -FilePath 'wsl.exe' -ArgumentList '--install' -Verb RunAs -Wait -PassThru
            if ($wsl.ExitCode -eq 0) { Write-Note 'WSL instalado. Reinicie o computador para concluir.' }
            else { Add-Failure "falha ao instalar o WSL (código $($wsl.ExitCode))" }
        }
    }

    Update-SessionPath
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. Git
# ─────────────────────────────────────────────────────────────────────────────
if (-not $SkipGit) {
    Write-Step 'Configurando o Git (global)'
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Add-Failure 'git não encontrado no PATH; abra um novo terminal e rode com -SkipApps'
    }
    else {
        Set-GitConfigIfMissing 'init.defaultBranch' 'main' 'nome padrão da branch inicial'
        Set-GitConfigIfMissing 'core.autocrlf' 'input' 'mantém LF nos arquivos, igual ao VS Code configurado'
        Set-GitConfigIfMissing 'core.editor' 'code --wait' 'usa o VS Code para mensagens de commit'
        Set-GitConfigIfMissing 'pull.rebase' 'false' 'git pull faz merge; evita erro de branches divergentes'
        Set-GitConfigIfMissing 'fetch.prune' 'true' 'remove referências a branches apagadas no remoto'

        if (-not (git config --global --get user.name) -or -not (git config --global --get user.email)) {
            Write-Note 'Defina seu nome e e-mail do Git (aparecem nos commits):'
            Write-Note '  git config --global user.name  "Seu Nome"'
            Write-Note '  git config --global user.email "voce@exemplo.com"'
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Extensões do VS Code
# ─────────────────────────────────────────────────────────────────────────────
if (-not $SkipExtensions) {
    Write-Step 'Instalando extensões do VS Code'
    $code = Get-CodeCli
    if (-not $code) {
        Add-Failure 'comando "code" não encontrado; instale o VS Code e rode com -SkipApps -SkipGit'
    }
    else {
        $listFile = Join-Path $RepoRoot 'vscode\extensions.txt'
        $wanted = Get-Content -Path $listFile -Encoding UTF8 |
            ForEach-Object { ($_ -replace '#.*$', '').Trim() } |
            Where-Object { $_ }
        $installed = @(& $code --list-extensions) | ForEach-Object { $_.ToLowerInvariant() }

        foreach ($id in $wanted) {
            if ($installed -contains $id.ToLowerInvariant()) {
                Write-Ok "$id"
                continue
            }
            & $code --install-extension $id | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Ok "$id (nova)" }
            else { Add-Failure "falha ao instalar a extensão $id" }
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. settings.json do VS Code
# ─────────────────────────────────────────────────────────────────────────────
if (-not $SkipSettings) {
    Write-Step 'Aplicando configurações do VS Code'
    $userDir = Join-Path $env:APPDATA 'Code\User'
    $target = Join-Path $userDir 'settings.json'
    $source = Join-Path $RepoRoot 'vscode\settings.json'
    New-Item -ItemType Directory -Force -Path $userDir | Out-Null

    if ((Test-Path $target) -and (Get-FileHash $target).Hash -eq (Get-FileHash $source).Hash) {
        Write-Ok 'settings.json já está atualizado'
    }
    else {
        if (Test-Path $target) {
            $backup = Join-Path $userDir ('settings.backup-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
            Copy-Item -Path $target -Destination $backup
            Write-Note "backup do settings.json anterior: $backup"
        }
        Copy-Item -Path $source -Destination $target -Force
        Write-Ok "settings.json aplicado em $target"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Resumo
# ─────────────────────────────────────────────────────────────────────────────
Write-Step 'Resumo'
if ($script:Failures.Count -eq 0) {
    Write-Ok 'Tudo pronto!'
}
else {
    Write-Host "  $($script:Failures.Count) problema(s):" -ForegroundColor Red
    $script:Failures | ForEach-Object { Write-Host "   - $_" -ForegroundColor Red }
}
Write-Host ''
Write-Host '  Próximos passos:'
Write-Host '   1. Feche e abra o terminal/VS Code para carregar o novo PATH.'
Write-Host '   2. Confira as versões: git --version; python --version; uv --version; node --version'
if ($WithWSL -or $WithDocker) {
    Write-Host '   3. Reinicie o computador para concluir a instalação do WSL/Docker.'
}
if ($script:Failures.Count -gt 0) { exit 1 }
