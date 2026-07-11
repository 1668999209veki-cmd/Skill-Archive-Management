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

```powershell
git clone https://github.com/1668999209veki-cmd/Skill-Archive-Management.git
cd Skill-Archive-Management
Copy-Item .env.example .env
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-skill-archive.ps1
```

生成完成后，用浏览器打开 `skill-archive.html`。

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
├── skill-update-report.*           # 更新检查报告
├── scripts/                        # 生成、更新检查和素材处理脚本
├── assets/
│   ├── desktop-pet/                # 小V 页面管理员素材
│   └── previews/                   # 页面预览和视觉参考图
├── docs/                           # 项目说明和设计记录
├── stop-slop-mvp/                  # 附带的轻量测试项目
├── 小demo/poster-wallpaper-factory/ # 附带的海报生成测试项目
├── .env.example                    # 环境变量示例
├── pet-secrets.example.js          # 小V 模型配置示例
├── OPEN_SOURCE_SECURITY_AUDIT.md   # 开源安全自查记录
└── LICENSE                         # MIT License
```

更完整的目录说明见 [docs/REPOSITORY_STRUCTURE.md](docs/REPOSITORY_STRUCTURE.md)。

## 常用命令

重新生成档案页：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-skill-archive.ps1
```

构建 Skill 来源索引：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-skill-source-index.ps1
```

检查 Skill 更新：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-skill-updates.ps1
```

运行轻量测试：

```powershell
npm test --prefix .\stop-slop-mvp
npm test --prefix ".\小demo\poster-wallpaper-factory"
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
