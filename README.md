# Skill档案管理

这是一个本地 Skill 档案归档页，用来把已安装的 Codex / Agent skills、调用统计、更新检查结果和页面宠物管理员“小V”整理到同一个 HTML 页面里。

仓库已按开源项目整理。请不要把真实 API Key、`.env`、本地导出视频、临时截图或第三方运行配置提交到 Git。

## 页面说明

打开 `skill-archive.html` 后，可以直接浏览本机归档出来的 Skill 清单。页面会展示每个 Skill 的来源、分类、安装/更新时间、历史调用统计和推荐信息。

页面顶部提供搜索、分类筛选和排序：

- `count`：按历史调用次数排序。
- `date`：按归档或更新时间排序。
- `name`：按 Skill 名称排序。
- `category`：按分类排序。

每张卡片都会带有 `data-history-count` 字段，方便脚本或浏览器调试时读取调用统计。页面里的“小V”管理员可以回答当前推荐 Skill 的用途、安装时间、投喂规则和基础闲聊；如果没有配置本地模型密钥，小V仍会保留本地规则回答。

## 主要内容

- `skill-archive.html`：可直接打开的 Skill 档案页面。
- `scripts/generate-skill-archive.ps1`：重新生成档案页的主脚本。
- `skill-source-index.json`：Skill 来源索引。
- `assets/desktop-pet/`：小V 的静态和动态素材。
- `pet-secrets.example.js`：页面宠物模型接入的本地密钥示例，不含真实 key。
- `pet-secrets.local.js`：本地真实密钥文件，已被 `.gitignore` 排除，不会上传。

## 重新生成档案页

在项目根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-skill-archive.ps1
```

生成成功后会更新 `skill-archive.html`。常规检查项：

- 页面里有 `skill-card`。
- 排序按钮 `count`、`date`、`name`、`category` 存在。
- 卡片包含 `data-history-count` 字段。

## 本地部署流程

1. 克隆仓库：

```powershell
git clone https://github.com/1668999209veki-cmd/Skill-Archive-Management.git
cd Skill-Archive-Management
```

2. 按需复制配置示例：

```powershell
Copy-Item .env.example .env
```

3. 根据本机目录填写 `.env` 中的 `SKILL_ARCHIVE_*_DIR`。如果不填写，脚本会使用当前项目目录、`%USERPROFILE%\.codex\skills` 和 `%USERPROFILE%\.agents\skills`。

4. 重新生成页面：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-skill-archive.ps1
```

5. 用浏览器打开 `skill-archive.html`。

## 本地模型密钥

仓库不会保存真实 API Key。需要让小V联网对话时，在本地创建 `pet-secrets.local.js`，格式参考：

```javascript
window.skillArchivePetSecrets = {
  apiBase: "https://api.deepseek.com",
  apiKey: "你的本地 API Key",
  model: "deepseek-v4-flash"
};
```

这个文件只留在本机，已被 `.gitignore` 忽略。

`.env.example` 只放空白示例或 `{{YOUR_MODEL_API_KEY}}` 这类占位符。真实密钥只能写入本机 `.env`、`pet-secrets.local.js` 或部署平台的 Secret 管理界面，不能提交到 Git。

## 小V管理员规则

小V是页面里的 Skill 档案管理员，可以正常聊天，也会回答投喂、生存规则、当前推荐 Skill 的用途和安装时间。

投喂只有两种方式：

- 复制当前推荐的指令。
- 安装新的 skill。

复制前可以讨价还价；一旦砍价后再复制口令，只增加砍价后的饱腹值，不能反悔。饱腹值为 0 时仍可聊天，但推荐区域会暂停推荐。

复活需要 3 个不同 ID 的用户在页面点击“复活”。

## 安全约定

不要提交以下内容：

- API Key、Token、密码和 `.env` 文件。
- `pet-secrets.local.js`。
- `MoneyPrinterTurbo/config.toml` 等可能写入第三方密钥的配置。
- `node_modules/`、构建输出、日志、截图检查产物和本地导出视频/音频。

本项目由 OpenAI Codex 辅助开发和审查。使用者应遵循 OpenAI 服务条款、第三方 API 服务条款，以及所归档 Skill 的各自许可证和使用边界。

禁止用途：

- 提交真实密钥、证书、Token、数据库密码或客户隐私数据。
- 违规批量生成内容、恶意爬虫、自动化撞库或绕过平台限流。
- 滥用大模型 API 进行垃圾内容生成、未授权数据采集或侵犯第三方权益。

如果密钥意外泄露：

1. 立即在服务商后台撤销或轮换泄露密钥。
2. 从本地文件和最新提交中删除密钥，改用环境变量。
3. 使用 `git filter-repo` 或 BFG 清理 Git 历史。
4. 强制推送清理后的历史，并通知所有协作者重新克隆。
5. 检查服务商账单、访问日志和异常调用。

提交前建议运行：

```powershell
git diff --cached --check
git grep --cached -n -I -E "sk-[A-Za-z0-9_-]{10,}|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}"
```

## 测试

当前仓库里有两个轻量测试入口：

```powershell
npm test --prefix .\stop-slop-mvp
npm test --prefix ".\小demo\poster-wallpaper-factory"
```

## GitHub

开源仓库地址：

https://github.com/1668999209veki-cmd/Skill-Archive-Management

## License

MIT License. See `LICENSE`.
