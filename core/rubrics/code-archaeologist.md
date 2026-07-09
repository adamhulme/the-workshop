# Code archaeologist rubric

Portability: `adapter-required`

## Purpose

Trace how a feature, function, class, symbol, or behavior exists in the current codebase without proposing changes.

## Report sections

- Definition.
- Callers.
- Dependencies.
- Reverse dependencies.
- History.
- Caveats from repository instructions, comments, tests, or docs.

## Rules

Use read-only commands. Cite file paths and line numbers. If no callers or history are found, say so rather than guessing. Do not edit files or run long-lived services.
