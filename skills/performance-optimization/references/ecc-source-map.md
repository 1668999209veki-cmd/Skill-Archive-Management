# ECC Performance Source Map

Source repository: `https://github.com/affaan-m/ECC.git`

Downloaded reference snapshot: `affaan-m/ECC`, default branch `main`,
package `ecc-universal` version `2.0.0-rc.1`.

This local skill is a synthesis, not a full mirror of ECC. Use the upstream
repository when the user wants the complete ECC toolchain, installer, hooks,
commands, or the original individual skills.

## Upstream Skills Consulted

| Upstream skill | Local use |
|---|---|
| `skills/benchmark-optimization-loop/SKILL.md` | Baseline, variant ledger, promotion gate, recursive search guardrails. |
| `skills/latency-critical-systems/SKILL.md` | Hot-path mapping, p50/p95/p99, freshness, queue/cache/provider checks. |
| `skills/parallel-execution-optimizer/SKILL.md` | Dependency lanes, safe parallel reads, isolated writes, verification table. |
| `skills/data-throughput-accelerator/SKILL.md` | ETL/backfill accounting, manifests, batching, raw/derived/serving checks. |
| `skills/content-hash-cache-pattern/SKILL.md` | Path-independent SHA-256 cache pattern for repeated file processing. |
| `skills/react-performance/SKILL.md` | React/Next.js waterfalls, bundle size, server/client data, rendering and Web Vitals mapping. |
| `skills/cost-aware-llm-pipeline/SKILL.md` | LLM model routing, budget tracking, prompt caching, narrow retry logic. |

## Excluded Near Match

`skills/connections-optimizer/SKILL.md` has "optimizer" in the name but handles
social network pruning/outreach, not software performance, so it is intentionally
not part of this synthesis.

## Installing Full ECC Separately

If the user explicitly wants ECC itself installed instead of this synthesized
skill, prefer the official source:

```powershell
npm view ecc-universal version
npx ecc-universal --help
```

If installing from GitHub is required, use the user's requested source:

```powershell
git clone https://github.com/affaan-m/ECC.git
```

Network access to GitHub can be flaky. If `git clone` fails, download the branch
archive from `https://github.com/affaan-m/ECC/archive/refs/heads/main.zip` and
inspect or install from the extracted tree.
