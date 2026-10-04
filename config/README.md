# LINEX.OS — Config

This directory is for **non-sensitive configuration** only.

## Purpose

- Store repository configuration that is safe to commit
- Examples: toolchain manifest, package allowlist documentation, environment detection defaults, CI configuration snippets, non-sensitive defaults

## What is ALLOWED

- Toolchain manifest (toolchain-manifest.txt already in ops/linux/ but config can have additional)
- Package allowlist documentation (explicit lists)
- Default configuration values (e.g., default package manager, OS support list)
- CI configuration that is not secret
- Documentation about configuration

## What is FORBIDDEN

- API keys
- Tokens (GITHUB_TOKEN, API tokens, etc.)
- Passwords
- Private credentials (SSH keys, certificates private keys)
- .env files with secrets
- Any credential material
- Secrets manager references that contain actual secrets

**No secrets in repository — ever.**

## Differentiation

### Repository Config (this directory)

- Safe to commit
- Reviewable
- Versioned
- Example: `toolchain-manifest.txt` documents Tool|Command|Package|Required|Status

### Environment Variables (not in repo)

- Set via `export VAR=value` in shell or via CI environment
- Not committed
- Example: `PATH`, `HOME`, `USER` — safe, but secrets like `API_KEY` must not be in repo

### Secrets Manager (external)

- For production: use external secrets manager (e.g., GitHub Secrets, Vault, etc.)
- Never copy secrets into repository
- CI must use `GITHUB_TOKEN` with least privilege (`permissions: contents: read`) and no secrets unless explicitly needed and documented

## Current Config

- No sensitive config yet in P5
- Future: may add `config/allowed-packages.json` or similar that mirrors Gate allowlist for documentation, but not as execution source (Gate's hardcoded allowlist is primary control)

## Verification

- `policy-check.sh` checks for no secrets in `ops/security/` and should also check `config/` for no secrets
- `.gitignore` excludes `.env`, `.env.*`, `secrets`, `credentials`

---

**Status:** P5 Config foundation — README only, no sensitive config, no secrets.

**Next:** May add non-sensitive config files with justification, but never secrets.
