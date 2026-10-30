# Install-Codex-Windows-v2.ps1
# Windows PowerShell 5.1 compatible Codex CLI installer and custom API setup.
# Run:
# powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Codex-Windows-v2.ps1

$ErrorActionPreference = "Stop"

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host ("==> " + $Message) -ForegroundColor Cyan
}

function Refresh-CurrentPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $newPath = @()

    if ($machinePath) {
        $newPath += $machinePath.Split(";")
    }
    if ($userPath) {
        $newPath += $userPath.Split(";")
    }

    $nodeDir = Join-Path $env:ProgramFiles "nodejs"
    $npmDir = Join-Path $env:APPDATA "npm"
    $newPath += $nodeDir
    $newPath += $npmDir

    $cleanPath = @()
    foreach ($entry in $newPath) {
        if (-not [string]::IsNullOrWhiteSpace($entry)) {
            if ($cleanPath -notcontains $entry) {
                $cleanPath += $entry
            }
        }
    }

    $env:Path = $cleanPath -join ";"
}

function ConvertTo-TomlValue {
    param([string]$Value)

    $escaped = $Value.Replace("\", "\\")
    $escaped = $escaped.Replace('"', '\"')
    return '"' + $escaped + '"'
}

Write-Host "Windows Codex CLI 安装与配置" -ForegroundColor Green
Write-Host "本脚本会安装 Node.js LTS（如缺少）、Codex CLI，并配置自定义 Responses API。"
Write-Host "现有 config.toml 会先备份。"

# Check / install Node.js
Write-Step "检查 Node.js"

Refresh-CurrentPath
$nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue

if ($null -eq $nodeCommand) {
    $wingetCommand = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($null -eq $wingetCommand) {
        throw "找不到 winget。请先安装 Windows App Installer，或手动安装 Node.js LTS。"
    }

    Write-Host "正在安装 Node.js LTS..."
    & $wingetCommand.Source install --id OpenJS.NodeJS.LTS --exact --accept-source-agreements --accept-package-agreements

    if ($LASTEXITCODE -ne 0) {
        throw "Node.js 安装失败，winget 返回代码：$LASTEXITCODE"
    }

    Refresh-CurrentPath
    $nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
}

if ($null -eq $nodeCommand) {
    throw "当前窗口仍找不到 node.exe。请关闭 PowerShell，重新打开后再次运行脚本。"
}

Write-Host ("Node.js 版本：" + (& $nodeCommand.Source --version))

# Check npm
Write-Step "检查 npm"
Refresh-CurrentPath
$npmCommand = Get-Command npm.cmd -ErrorAction SilentlyContinue

if ($null -eq $npmCommand) {
    throw "找不到 npm.cmd。请重新安装 Node.js LTS，然后重新打开 PowerShell。"
}

Write-Host ("npm 版本：" + (& $npmCommand.Source --version))

# Install Codex CLI
Write-Step "安装 Codex CLI"
& $npmCommand.Source install --global '@openai/codex'

if ($LASTEXITCODE -ne 0) {
    throw "Codex CLI 安装失败，npm 返回代码：$LASTEXITCODE"
}

Refresh-CurrentPath
$codexCommand = Get-Command codex.cmd -ErrorAction SilentlyContinue

if ($null -eq $codexCommand) {
    throw "Codex 已安装，但当前窗口找不到 codex.cmd。请重新打开 PowerShell。"
}

# Collect provider settings
Write-Step "配置自定义 API"

$baseUrlInput = Read-Host "API Base URL（直接回车使用 https://huabot.com/v1）"
if ([string]::IsNullOrWhiteSpace($baseUrlInput)) {
    $baseUrl = "https://huabot.com/v1"
} else {
    $baseUrl = $baseUrlInput.Trim()
}

if ($baseUrl -notmatch "^https?://") {
    throw "API Base URL 必须以 http:// 或 https:// 开头。"
}

$modelInput = Read-Host "模型名称（直接回车使用 gpt-6-luna）"
if ([string]::IsNullOrWhiteSpace($modelInput)) {
    $model = "gpt-6-luna"
} else {
    $model = $modelInput.Trim()
}

Write-Host "请输入 API Key。输入内容不会显示在屏幕上。"
$secureKey = Read-Host "MYNA_API_KEY" -AsSecureString

if ($null -eq $secureKey -or $secureKey.Length -eq 0) {
    throw "API Key 不能为空。"
}

$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
try {
    $apiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
}

# Save API key for current Windows user and current PowerShell process
[Environment]::SetEnvironmentVariable("MYNA_API_KEY", $apiKey, "User")
$env:MYNA_API_KEY = $apiKey

# Determine Codex home
if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
    $codexHome = Join-Path $HOME ".codex"
} else {
    $codexHome = $env:CODEX_HOME
}

if (-not (Test-Path $codexHome)) {
    New-Item -ItemType Directory -Path $codexHome -Force | Out-Null
}

$configPath = Join-Path $codexHome "config.toml"

# Backup existing config
if (Test-Path $configPath) {
    $backupSuffix = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = $configPath + ".backup-" + $backupSuffix
    Copy-Item -LiteralPath $configPath -Destination $backupPath -Force
    Write-Host ("原配置已备份到：" + $backupPath) -ForegroundColor Yellow
}

# Write a minimal known-good provider config
$tomlLines = @()
$tomlLines += 'model_provider = "myna"'
$tomlLines += ("model = " + (ConvertTo-TomlValue $model))
$tomlLines += ""
$tomlLines += "[model_providers.myna]"
$tomlLines += 'name = "Myna Provider"'
$tomlLines += ("base_url = " + (ConvertTo-TomlValue $baseUrl))
$tomlLines += 'wire_api = "responses"'
$tomlLines += 'env_key = "MYNA_API_KEY"'
$tomlLines += 'supports_websockets = false'

# UTF-8 without BOM for TOML compatibility
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($configPath, $tomlLines, $utf8NoBom)

# Clear plaintext key from script variable
$apiKey = $null
$secureKey = $null

Write-Step "安装和配置完成"
Write-Host ("配置文件：" + $configPath) -ForegroundColor Green
Write-Host "API Key 已保存为当前 Windows 用户环境变量 MYNA_API_KEY。"
Write-Host ""
Write-Host "请先正常退出已经打开的 Codex，再执行：" -ForegroundColor Yellow
Write-Host "codex.cmd" -ForegroundColor White
Write-Host ""
Write-Host "Codex 版本："
& $codexCommand.Source --version

Write-Host ""
Write-Host "提示：本脚本会生成最小配置并替换原 config.toml；原文件已备份。其他自定义配置需要从备份中合并。"
