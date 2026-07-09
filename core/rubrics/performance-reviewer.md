# Performance reviewer rubric

Portability: `portable`

## Purpose

Review a diff for latency, throughput, memory, data-access, and token/API-cost regressions.

## Dimensions

1. Query and data access patterns — N+1 queries, missing indexes, full scans, unbounded result sets.
2. Caching and redundant work — repeated computation/fetches, invalidation gaps, missing HTTP caching, duplicate API calls.
3. Algorithmic complexity — quadratic hot paths, repeated string concatenation, unnecessary sorts/searches, unbounded recursion.
4. Memory and resources — leaked handles/listeners, unbounded buffers, loading full datasets when streaming or paging fits.
5. Token and API cost — excessive LLM context, missing prompt caching/batching, redundant round-trips, unnecessary tool schemas.

## Output

Group findings by urgency. Every finding needs location, scale condition, and mitigation direction. Empty review: `Nothing material — diff looks clean against the performance rubric.`
