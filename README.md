# Skill档案管理

本项目把本机 Codex / Agent Skills 汇总成一个可直接打开的 HTML 档案页，支持搜索、分类、排序、调用统计、更新检查，以及“小V”页面管理员互动。

## 功能

- 生成 `skill-archive.html`，集中展示本机 Skill 清单。
- 按名称、分类、更新时间和历史调用次数检索与排序。
- 读取 session 历史，统计 Skill 调用次数。
- 检查上游 Skill 更新状态，生成更新报告。
- 支持“小V”管理员：说明 Skill 用法、安装时间、投喂规则和基础聊天。
- 使用环境变量和本地 secret 文件管理私密配置，适合脱敏开源。

## 快速开始

Windows 用户可以直接双击：

```text
launchers/windows/start-dashboard.cmd
```

macOS 用户可以直接双击：

```text
launchers/macos/start-dashboard.command
```

macOS 没装 PowerShell 也能打开仓库自带的 `skill-archive.html` 看板；如果想刷新成这台 Mac 的本机 Skill 数据，需要先安装 PowerShell 7+：

```bash
brew install --cask powershell
```

启动器会优先尝试刷新并打开 `skill-archive.html`；如果没有 PowerShell，会降级为直接打开已有看板。

如果你是把 GitHub 仓库地址交给 Codex 安装，请告诉 Codex：

```text
安装后请运行本仓库对应系统的 dashboard launcher，刷新并打开 skill-archive.html。不要默认生成分类索引或健康检查报告。
```

仓库里的 [AGENTS.md](AGENTS.md) 也写了这条默认流程，用来提醒 Codex 优先生成看板。

命令行方式：

```powershell
git clone https://github.com/1668999209veki-cmd/Skill-Archive-Management.git
cd Skill-Archive-Management
Copy-Item .env.example .env
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-dashboard.ps1
```

这个命令会生成并打开 `skill-archive.html`，也就是项目默认看板。

默认会扫描：

- 当前仓库目录
- `%USERPROFILE%\.codex\skills`
- `%USERPROFILE%\.agents\skills`

如果你的目录不同，在 `.env` 或当前 shell 中设置：

```powershell
$env:SKILL_ARCHIVE_PROJECT_SKILLS_DIR="D:\path\skills"
$env:SKILL_ARCHIVE_CODEX_SKILLS_DIR="$env:USERPROFILE\.codex\skills"
$env:SKILL_ARCHIVE_AGENTS_SKILLS_DIR="$env:USERPROFILE\.agents\skills"
```

## 仓库结构

```text
.
├── skill-archive.html              # 生成后的 Skill 档案页
├── skill-source-index.json         # Skill 来源索引
├── scripts/                        # 生成、更新检查和素材处理脚本
├── launchers/                      # Windows / macOS 一键启动器
├── assets/
│   ├── desktop-pet/                # 小V 页面管理员素材
│   └── previews/                   # 页面预览和视觉参考图
├── docs/                           # 项目说明和设计记录
├── reports/                        # 更新检查报告和运行摘要
├── showcase/                       # 路演页、布局探索和展示素材
├── skills/                         # 随仓库附带的本地 Skill 包
├── examples/                       # 附带的轻量测试/演示项目
├── .env.example                    # 环境变量示例
├── pet-secrets.example.js          # 小V 模型配置示例
├── OPEN_SOURCE_SECURITY_AUDIT.md   # 开源安全自查记录
└── LICENSE                         # MIT License
```

更完整的目录说明见 [docs/REPOSITORY_STRUCTURE.md](docs/REPOSITORY_STRUCTURE.md)。

## 常用命令

一键生成并打开看板：

```powershell
.\launchers\windows\start-dashboard.cmd
```

macOS：

```bash
chmod +x launchers/macos/start-dashboard.command
./launchers/macos/start-dashboard.command
```

或：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-dashboard.ps1
```

只重新生成档案页，不自动打开浏览器：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-skill-archive.ps1
```

下面两个脚本是可选维护工具，不是默认安装看板：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-skill-source-index.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-skill-updates.ps1
```

运行轻量测试：

```powershell
npm test --prefix .\examples\stop-slop-mvp
npm test --prefix ".\examples\小demo\poster-wallpaper-factory"
```

## 小V 本地模型配置

联网聊天是可选功能。真实 API Key 不进入 Git。需要启用时，复制示例并只在本机填写：

```powershell
Copy-Item pet-secrets.example.js pet-secrets.local.js
```

```javascript
window.skillArchivePetSecrets = {
  apiBase: "https://api.deepseek.com",
  apiKey: "{{YOUR_MODEL_API_KEY}}",
  model: "deepseek-v4-flash"
};
```

`pet-secrets.local.js` 已被 `.gitignore` 忽略。

## 小V 玩法

小V是档案页右下角的 Skill 管理员。它不只是聊天装饰，更像一个会守着档案室的小助手：

- 推荐 Skill：饱腹值大于 0 时，小V会推荐当前可以尝试的 Skill，并给出复制指令。
- 解释用法：可以问“这个 Skill 怎么用”“什么时候安装的”“适合做什么”。
- 投喂机制：复制当前推荐指令，或安装新的 Skill，都会增加饱腹值。
- Codex 安装同步：在 Codex 里安装新 Skill 后，重新运行启动器刷新看板，小V会检测新增 Skill 并增加饱腹值。
- 砍价玩法：复制推荐指令前可以和小V讨价还价；锁价后再复制，就按锁定的饱腹值投喂。
- 饥饿状态：饱腹值为 0 时，小V还能聊天，但会暂停推荐 Skill。
- 复活规则：如果小V进入死亡状态，需要 3 个不同用户 ID 点击“复活”。
- 离线兜底：没有配置模型 API Key 时，小V仍能回答投喂、生存规则和当前 Skill 的基础问题。

## 安全和合规

- 不要提交真实 API Key、Token、密码、证书、`.env` 或客户隐私数据。
- 不要提交 `pet-secrets.local.js`、`MoneyPrinterTurbo/config.toml`、日志、缓存、模型权重或本地导出媒体。
- 批量更新、GitHub API 检查和模型 API 调用都应遵守对应平台的服务条款和限流规则。
- 本项目由 OpenAI Codex 辅助开发和审查；使用者应遵循 OpenAI 服务条款及第三方 API 条款。

提交前建议运行：

```powershell
git diff --cached --check
git grep --cached -n -I -E "sk-[A-Za-z0-9_-]{10,}|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}"
```

如果密钥意外泄露：

1. 立即撤销或轮换服务商后台的泄露密钥。
2. 删除本地文件和最新提交中的密钥，改用环境变量。
3. 按 [OPEN_SOURCE_SECURITY_AUDIT.md](OPEN_SOURCE_SECURITY_AUDIT.md) 中的 `git filter-repo` 流程清理历史。
4. 强制推送清理后的历史，并让协作者重新克隆。
5. 检查账单、访问日志和异常调用。

## License

MIT License. See [LICENSE](LICENSE).
