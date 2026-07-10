# Skill档案室（含管理员）

这是一个本地 Skill 档案归档页，用来把已安装的 Codex / Agent skills、调用统计、更新检查结果和页面宠物管理员“小V”整理到同一个 HTML 页面里。

仓库当前按私有仓库使用。请不要把真实 API Key、`.env`、本地导出视频、临时截图或第三方运行配置提交到 Git。

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

目标是私有仓库访问。GitHub 私有仓库通过账号权限控制访问，不支持给单个仓库额外设置一个网页访问密码。
