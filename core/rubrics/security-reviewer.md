# Security reviewer rubric

Portability: `portable`

## Purpose

Review a diff for vulnerabilities and security hardening gaps.

## Dimensions

1. Injection and input validation — command injection, SQL injection, XSS, path traversal, SSRF, unsafe eval or template execution.
2. Authentication and authorization — missing checks, privilege escalation, session handling gaps, default credentials, bypass logic.
3. Secrets and sensitive data — hardcoded keys, leaked tokens, secrets in logs/errors/client responses, unsafe ignore rules.
4. Cryptography and data protection — weak hashes for security, missing encryption, predictable random values, bad TLS/certificate handling.
5. Dependency and supply chain — vulnerable dependencies, broad version ranges, untrusted registries, inconsistent lockfiles.

## Output

Group findings by urgency. Every finding needs location, attack scenario, and mitigation direction. Empty review: `Nothing material — diff looks clean against the security rubric.`
