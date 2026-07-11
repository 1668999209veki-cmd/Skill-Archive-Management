# Open Source Security Audit

Date: 2026-07-11

## Module 1: Decrypted Source Sanitization

Scope reviewed: tracked project files, generated archive files, scripts, README, Git ignore rules, and recent Git history metadata.

Sanitization changes applied:

- `scripts/generate-skill-archive.ps1`
  - Replaced hardcoded local roots such as `{{LOCAL_USER_HOME}}\...` with environment-configurable paths:
    - `SKILL_ARCHIVE_PROJECT_SKILLS_DIR`
    - `SKILL_ARCHIVE_CODEX_SKILLS_DIR`
    - `SKILL_ARCHIVE_AGENTS_SKILLS_DIR`
  - Added public path placeholders in generated data:
    - `{{PROJECT_SKILLS_DIR}}`
    - `{{CODEX_SKILLS_DIR}}`
    - `{{AGENTS_SKILLS_DIR}}`
    - `{{LOCAL_PATH}}`
  - Replaced local `file:///...` fallback links with `#local-skill-file`.
  - Added a risk note before browser-side model API calls, because those calls can consume paid API quota.

- `pet-secrets.example.js`
  - Replaced the blank API key with `{{YOUR_MODEL_API_KEY}}`.
  - Added an inline comment telling users to put real values only in `pet-secrets.local.js`.

- `.env.example`
  - Added blank/example configuration for all user-controlled local paths and optional model settings.

- `.gitignore`
  - Added explicit ignore coverage for env files, key/cert files, logs, caches, generated media, model weights, IDE metadata, and third-party runtime config.

Scan result:

- No OpenAI/Codex key, GitHub token, AWS AK, Google API key, Slack token, JWT, or PEM private key pattern was found in tracked content by the local regex scan.
- Local absolute paths were found and remediated in the generation script. Regenerated public HTML/JSON should use placeholders instead of machine paths.
- High-risk automation logic is limited to optional model API calls in the browser page pet; it now has a risk comment and requires local, uncommitted credentials.

Remaining note:

- Generated archive content describes installed Skills. Before publishing a generated snapshot, review whether any installed Skill descriptions themselves contain private business context.

## Module 2: Open Source Repository Files

Generated or updated:

- `.env.example`
  - Documents `SKILL_ARCHIVE_PROJECT_SKILLS_DIR`, `SKILL_ARCHIVE_CODEX_SKILLS_DIR`, `SKILL_ARCHIVE_AGENTS_SKILLS_DIR`, and optional page-pet model settings.

- `.gitignore`
  - Covers `.env`, local secret files, private key/cert formats, logs, caches, IDE config, generated media, model weights, and `MoneyPrinterTurbo/config.toml`.

- `LICENSE`
  - MIT License is present.

## Module 3: Standard Open Source README

README now includes:

- Project function summary.
- Page usage notes for `skill-archive.html`.
- Local deployment flow.
- Environment variable and `.env.example` usage.
- Secret handling and desensitization rules.
- Compliance statement: the project was assisted by OpenAI Codex and users should follow OpenAI service terms.
- Security warnings against committing real credentials.
- Usage constraints against malicious scraping, abusive batch generation, and model API misuse.
- Incident response steps for accidental secret leakage.
- MIT license notice.

## Module 4: Git History Security Review and Repair Plan

Risk rating:

- High risk: Any credential that ever appeared in Git history, including encrypted archives that could later be decrypted by others.
- Medium risk: Historical generated files containing local absolute paths or machine-specific metadata.
- Low risk: Public example placeholders such as `{{YOUR_MODEL_API_KEY}}`, empty env variables, and documented sample paths.
- Current scan status: no high-risk key pattern was detected by regex scan; local path leakage was detected and remediated in source generation logic.

Recommended remediation checklist:

1. Rotate all API keys, database passwords, webhook tokens, and cloud credentials that were ever written into local source files, even if the repository previously stored them encrypted.
2. Regenerate `skill-archive.html` after sanitization.
3. Re-run secret scans on the working tree and Git history.
4. If any sensitive file existed in history, rewrite history with `git filter-repo`.
5. Force-push the cleaned history only after making a backup and confirming collaborators are ready to reclone.

Backup before history rewrite:

```powershell
cd .\Skill-Archive-with-Admin
git bundle create ..\Skill-Archive-with-Admin-before-filter.bundle --all
git clone --mirror https://github.com/1668999209veki-cmd/Skill-Archive-Management.git ..\Skill-Archive-Management-mirror.git
```

Install `git-filter-repo` if missing:

```powershell
python -m pip install --user git-filter-repo
git filter-repo --help
```

Remove known sensitive files from all history:

```powershell
cd ..\Skill-Archive-Management-mirror.git
git filter-repo --force `
  --path .env --invert-paths `
  --path-glob ".env.*" --invert-paths `
  --path pet-secrets.local.js --invert-paths `
  --path skill-archive.local.js --invert-paths `
  --path MoneyPrinterTurbo/config.toml --invert-paths `
  --path-glob "*.pem" --invert-paths `
  --path-glob "*.key" --invert-paths `
  --path-glob "*.p12" --invert-paths `
  --path-glob "*.pfx" --invert-paths `
  --path-glob "*.enc" --invert-paths `
  --path-glob "*.gpg" --invert-paths `
  --path-glob "*.age" --invert-paths
```

Optional text replacement for leaked literals:

```powershell
@"
literal:{{LOCAL_USER_HOME}}==>{{LOCAL_USER_HOME}}
regex:sk-[A-Za-z0-9_-]{10,}==>{{OPENAI_API_KEY}}
regex:github_pat_[A-Za-z0-9_]{20,}==>{{GITHUB_TOKEN}}
regex:gh[pousr]_[A-Za-z0-9_]{20,}==>{{GITHUB_TOKEN}}
regex:AKIA[0-9A-Z]{16}==>{{AWS_ACCESS_KEY_ID}}
"@ | Set-Content -Encoding UTF8 ..\filter-replacements.txt

git filter-repo --force --replace-text ..\filter-replacements.txt
```

Verify cleaned mirror:

```powershell
git grep -n -I -E "sk-[A-Za-z0-9_-]{10,}|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----" $(git rev-list --all)
git log --all --name-only --pretty=format: | sort | uniq
```

Force-push after verification:

```powershell
git remote -v
git push --force --mirror origin
```

After force-push:

- Rotate all credentials again if there is any doubt.
- Ask collaborators to delete old clones and reclone.
- Clear local caches, CI caches, release assets, and GitHub Actions artifacts if they contained sensitive data.
