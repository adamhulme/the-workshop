# Core workflows

Each workflow file is the portable contract for one workshop activity. Runtime adapters may add native interaction mechanics, but they should preserve these contracts: inputs, artifact paths, gates, output shape, and verification expectations.

## Portability classes

| Class | Meaning |
|-------|---------|
| `portable` | Can be implemented directly in any agent harness with normal file and shell access. |
| `adapter-required` | Workflow is portable, but one or more steps need harness-specific I/O, MCP, browser, or sub-agent mechanics. |
| `native-rewrite` | The goal is portable, but orchestration is so harness-specific that each runtime needs its own implementation. |
| `personal-template` | The file is useful as a template, but should be parameterised before becoming a shared runtime skill. |
