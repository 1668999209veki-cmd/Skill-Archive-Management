---
name: performance-optimization
description: Use when the user asks to make software, data pipelines, agent workflows, React/Next.js apps, LLM calls, scripts, builds, tests, APIs, queues, caches, or browser flows faster, cheaper, more concurrent, or more scalable. Trigger on English or Chinese phrases such as performance optimization, optimize latency, make it faster, speed up, reduce p95/p99, improve throughput, reduce cost, cache, parallelize, 性能优化, 加速, 提速, 降低延迟, 提高吞吐, 并发优化, 缓存优化, 成本优化. Always use this skill for measurable optimization work, especially when the task mentions benchmarks, p95 latency, throughput, cost/run, token usage, bundle size, or repeated optimization loops.
---

# Performance Optimization

## Purpose

Turn vague speed requests into measured, safe optimization work. Start with a
baseline, keep correctness visible, change one meaningful hypothesis at a time,
and finish with repeatable commands and numbers.

Upstream source and install reference: `https://github.com/affaan-m/ECC.git`.
This skill synthesizes ECC performance-related skills into one Codex-friendly
workflow. For source mapping, read `references/ecc-source-map.md`.

## First Decision

| Situation | Optimization lane |
|---|---|
| User asks "make this faster" without details | Run the baseline workflow first. |
| Hot path is request/response, streaming, queues, dashboards, or realtime state | Use latency workflow. |
| Bottleneck is backfill, ETL, import/export, synchronization, or large files | Use throughput workflow. |
| Speed comes from independent tasks, agents, tests, builds, or API calls | Use parallel execution workflow. |
| Repeated expensive file processing happens across runs | Use content-hash cache workflow. |
| React/Next.js UI is slow, heavy, or has Web Vitals regressions | Use frontend workflow. |
| LLM API usage is slow or expensive | Use LLM cost/latency workflow. |

## Baseline Workflow

Do not optimize until the work has these five facts:

1. Operation: the exact command, request, user flow, job, or function.
2. Correctness gate: tests, checksum, row counts, visual smoke, replay, or
   domain invariant that must stay true.
3. Metric: wall time, p50/p95/p99 latency, rows/sec, files/sec, cost/run,
   token usage, memory, bundle size, CPU, error rate, or queue depth.
4. Current baseline: at least one measured run, preferably two if noisy.
5. Budget: max variants, time, spend, data impact, and approval gates.

Use this compact ledger while working:

```text
Variant | Hypothesis | Command/Input | Metric | Correct? | Notes
baseline | current path | <command> | <value> | yes/no | observed issue
```

Promote a variant only when it passes the correctness gate and the performance
delta repeats or has a clear explanation.

## Latency Workflow

Map the hot path from input to visible result before editing:

```text
event -> API/provider -> worker -> queue -> cache/store -> route -> client render
```

Measure segments separately. Prefer this order:

1. Remove unnecessary round trips and sequential awaits.
2. Cache stable reads with freshness metadata.
3. Batch small calls and writes.
4. Move compute closer to the data or user.
5. Split hot paths from cold/background paths.
6. Add backpressure before queues grow unbounded.
7. Stream only when it improves freshness or user experience.

Never hide stale data behind a fast cache hit. Report freshness, retry behavior,
and degraded-provider behavior when they matter.

## Throughput Workflow

For ETL, backfills, imports, exports, and synchronization, separate:

- source extraction speed;
- network transfer speed;
- load/write speed;
- transform speed;
- manifest/checkpoint lag;
- live-tail growth while the job runs.

Prefer idempotent batches, manifests, partition-aware scans, warehouse-native
operations, and explicit raw/derived/serving accounting. Finish with hard
counts: discovered, processed, skipped, failed, remaining, runtime, and the
correctness gate.

## Parallel Execution Workflow

Use a dependency matrix before parallelizing:

```text
Lane | Can run in parallel? | Write surface | Risk | Verification
Repo scan | yes | none | low | rg/git status outputs
Unit tests | yes | none | low | test command result
Backend patch | maybe | src/api | medium | focused tests
```

Batch reads and checks freely. Keep writes isolated by file, worktree, branch,
service, table, or dataset. Do not parallelize destructive commands, migrations,
same-file edits, or customer-impacting deploys without an explicit gate.

## Cache Workflow

For repeated expensive file processing, prefer content-hash caching:

- Use SHA-256 of file contents, not path, as the key.
- Hash large files in chunks.
- Store cache entries as `{hash}.json` or another O(1) lookup format.
- Keep the processing function pure; put cache lookup/write in a wrapper.
- Treat corrupt cache entries as misses.
- Add `--cache` and `--no-cache` controls for CLI tools when useful.

Do not use this pattern for data that must always be fresh or results that
depend on hidden parameters not included in the cache key.

## Frontend Workflow

For React/Next.js:

1. Remove waterfalls: independent async work should start together.
2. Reduce first-load JavaScript: direct imports, dynamic imports, route splits,
   deferred third-party scripts.
3. Move stable work to the server or module scope when safe.
4. Deduplicate client fetches with SWR, TanStack Query, or local project
   patterns.
5. Reduce re-renders only where profiling or code shape shows churn.
6. Stabilize layout and long-list rendering before chasing micro-optimizations.

Map Web Vitals to causes: LCP often points at waterfalls/bundles/resources, INP
at re-renders/main-thread work, CLS at dimensions/suspense/layout shifts, and
TBT at bundle size or synchronous JavaScript.

## LLM Cost And Latency Workflow

For LLM-heavy systems:

- Route simple tasks to cheaper/faster models and reserve expensive models for
  complex work.
- Track cost per call and cumulative budget before batch runs.
- Use prompt caching for long repeated prompts when the provider supports it.
- Retry only transient errors such as rate limits, connection errors, or server
  errors; fail fast on auth, validation, and bad-request errors.
- Log model selection, token counts, latency, retries, and cache hits.

Treat "cheaper" as valid only if the quality gate still passes.

## Reporting Format

End with this shape when the user asked for implementation or diagnosis:

```text
Performance result:
- Baseline: <command/input> -> <metric>
- Winner: <variant> -> <metric>
- Delta: <absolute and percent change>
- Correctness gate: <passed/failed and evidence>
- Tradeoffs: <freshness/cost/memory/complexity>
- Follow-up: <next benchmark or guardrail>
```

If no safe improvement was found, say that plainly and preserve the benchmark
ledger so the next attempt starts from evidence instead of guesses.

## Safety Rules

- Do not skip validation, auth, retries, accounting, or data integrity checks to
  make metrics look better.
- Do not delete raw data, silently skip failed records, or call a live pipeline
  complete until source, manifest, and target agree.
- Do not run live orders, destructive migrations, production deploys, bulk
  messages, or customer-impacting writes without an explicit approval gate.
- Keep secrets and private payloads out of benchmark logs and artifacts.
- Prefer "best measured safe variant" over "optimal" unless the search was
  actually exhaustive.

## Completion Criteria

Before returning the final answer:

- The baseline and metric are stated.
- Correctness evidence is stated.
- Commands or reproduction steps are durable enough to rerun.
- Any skipped checks, noisy measurements, or untested tradeoffs are disclosed.
- The final recommendation is tied to measured evidence, not intuition alone.
