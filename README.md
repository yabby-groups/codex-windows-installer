# Windows Codex CLI 安装脚本

通过 PowerShell 安装 Codex CLI，并交互配置自定义 Responses API 服务。

## 环境要求

- Windows，支持 Windows PowerShell 5.1。
- 可连接 npm 仓库和所使用的 API 服务。
- 准备好 API Key，以及服务支持的模型名称。
- 如果尚未安装 Node.js，需要 `winget`（Windows App Installer 提供）；也可以提前手动安装 Node.js LTS。

## 快速开始

下载 `Install-Codex-Windows-v2.ps1`，在脚本所在目录打开 PowerShell，运行：

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Codex-Windows-v2.ps1
```

执行策略设置为当前用户的 `RemoteSigned`；出现确认提示时按 `Y` 确认。安装脚本也会执行此设置。

按提示填写配置：

| 输入项 | 默认值 / 说明 |
| --- | --- |
| API Base URL | `https://huabot.com/v1`；必须以 `http://` 或 `https://` 开头 |
| 模型名称 | `gpt-6-luna`；请确认 API 服务支持该模型 |
| API Key | 必填，输入时不会显示在屏幕上 |

安装完成后，正常退出已经打开的 Codex，再在 PowerShell 中启动：

```powershell
codex.cmd
```

如果是在另一个已经打开的终端中运行，请先重新打开终端，以读取新保存的环境变量。

## 脚本执行内容

1. 检查 Node.js；缺少时使用 `winget` 安装 Node.js LTS。已有 Node.js 时直接使用，不检查或升级其版本。
2. 检查 `npm.cmd`，执行 `npm install --global @openai/codex`。
3. 收集 API 地址、模型名称和 API Key。
4. 将 API Key 保存到当前 Windows 用户的 `MYNA_API_KEY` 环境变量，并设置到脚本进程中。
5. 备份已有的 `config.toml`，写入最小配置，最后显示 Codex 版本。

## 配置文件与备份

默认配置文件位于：

```text
%USERPROFILE%\.codex\config.toml
```

如果设置了 `CODEX_HOME` 环境变量，则写入该目录下的 `config.toml`。生成的配置如下（地址和模型以实际输入为准）：

```toml
model_provider = "myna"
model = "gpt-6-luna"

[model_providers.myna]
name = "Myna Provider"
base_url = "https://huabot.com/v1"
wire_api = "responses"
env_key = "MYNA_API_KEY"
supports_websockets = false
```

**脚本会替换整个 `config.toml`**，原文件备份为同目录下的 `config.toml.backup-yyyyMMdd-HHmmss`。原有的其他自定义配置需要从备份中手动合并。恢复配置时，退出 Codex，将所需备份复制回 `config.toml`。

API Key 不写入 TOML 文件，但会以普通用户环境变量持久保存；隐藏输入并不代表加密存储。再次运行脚本会覆盖该用户环境变量，配置备份不包含旧 Key。

## 常见问题

| 问题 | 处理方式 |
| --- | --- |
| 找不到 `winget` | 安装 Windows App Installer，或手动安装 Node.js LTS 后重试 |
| 找不到 `node.exe` 或 `npm.cmd` | 安装或修复 Node.js LTS，重新打开 PowerShell 后重试 |
| npm 安装失败 | 根据 npm 输出检查网络、仓库连接及全局安装目录权限 |
| 安装后找不到 `codex.cmd` | 重新打开 PowerShell，确认 npm 全局命令目录已加入 PATH |
| API 认证或模型调用失败 | 检查 API 地址、Key、模型名称，以及服务是否支持 Responses API |

脚本完成表示安装和配置步骤完成；脚本不会发送 API 请求验证凭据或模型可用性。
