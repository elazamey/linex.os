# LINEX.OS — Networking Architecture (P8)

## Network Architecture

### Inbound

- API requests from UI (CLI, Web client only)
- External requests (if API exposed, future)
- Must have: auth (Identity/Auth), rate limiting, capability check (CAP_NETWORK_CONNECT if needed), input validation, audit
- Must not: allow unauthenticated privileged operations, allow UI to directly control privileged execution

### Outbound

- Tool calls to external APIs (GitHub, Microsoft, Debian mirrors, etc.)
- Must have: CAP_NETWORK_READ or CAP_NETWORK_CONNECT + policy, allowlist official sources only, network state check AVAILABLE/PARTIALLY/BLOCKED, evidence PASS/BLOCKED with curl -v output
- Must not: auto redirect to random mirror, undocumented proxy, third-party download, untrusted binary, Agent→Internet unrestricted without capability + policy

### Internal

- Event Bus (action.proposed, etc.)
- Service-to-Service (Policy Engine → Authorization → Execution Authority → Verification)
- Must have: auth (service identity), no secrets in events, audit
- Must not: allow internal bypass of policy

### External

- Internet
- Must be via Network Service with policy, capability, allowlist
- No unrestricted without CAP_NETWORK_CONNECT + EXPLICIT_APPROVAL

## Zones

- Trusted: Control Plane (Policy Engine, Authorization, Execution Authority, Verification Engine, Substrate, Core Runtime) — but still verified, not blindly trusted
- Restricted: Agent Runtime, Tool Runtime, Skill Runtime, MCP Gateway, Configuration Service, UI/API — semi-trusted, must be validated, must pass policy
- Untrusted: LLM, User input, External APIs, MCP servers, Plugins, Browser/Computer executors — must be validated, must have capability, must be isolated

```
Trusted Zone (Control, Policy, Execution, Verification)
  ↑
Restricted Zone (Agent, Tool, Skill, MCP Gateway, Config, UI/API)
  ↑
Untrusted Zone (LLM, User Input, External APIs, MCP Servers, Plugins, Browser/Computer)
  ↓
Host OS (Trusted but not modified)
  ↓
Hardware
```

## Arena Network Snapshot (P0 Audit at `a71643a`; Recheck Live)

- github.com → PASS (HTTP/2 200 via E2B proxy O=E2B CN=github.com)
- api.github.com → PASS (HTTP/2 200, returns v7.6.6)
- packages.microsoft.com → BLOCKED (SSL_ERROR_SYSCALL, 13.107.213.70:443, Arena sandbox blocks)
- release-assets.githubusercontent.com → BLOCKED (SSL_ERROR_SYSCALL, 185.199.111.133:443, where GitHub release binaries hosted)
- objects.githubusercontent.com → BLOCKED
- deb.debian.org → BLOCKED (Empty reply, 151.101.66.132:80)
- ftp.de.debian.org, mirror.hetzner.com, etc. → BLOCKED (Empty reply or SSL_ERROR_SYSCALL)
- google.com → BLOCKED (SSL_ERROR_SYSCALL)

Documented as known limitations in docs/operations.md, not design failure. No workaround with third-party, snap, unofficial mirror.

Official sources only for PowerShell (P4):

- SOURCE-1: packages.microsoft.com
- SOURCE-2: github.com/PowerShell/PowerShell

Any other source → BLOCKED.

For Debian toolchain (P3):

- Debian mirrors are BLOCKED in Arena. The official `pkgconf/pkgconf` source is reachable; during the P0 audit, commit `d908d63634c13b9a4f88d2fe4578d95048a6b13c` was built as a temporary `pkgconf-lite` 3.0.0 under `/tmp` for verification only. No system package was installed and the default PATH still lacks `pkg-config`; see `docs/reports/baseline-audit-a71643a.md`.

## Network Policy

- NETWORK_AVAILABLE: github.com PASS
- NETWORK_PARTIALLY_AVAILABLE: Some PASS, some BLOCKED (the P0 audit snapshot is recorded above; recheck live)
- NETWORK_BLOCKED: All or critical BLOCKED
- No auto redirect to random mirror, undocumented proxy, third-party download, untrusted binary
- When BLOCKED → BLOCKED with evidence (curl -v output showing SSL_ERROR_SYSCALL or Empty reply), then mention official alternatives only
- P3 audit result: `pkg-config` is missing from the default PATH, P3 is 43/44, and `scripts/doctor.sh` exits 3. A pinned official `pkgconf/pkgconf` build under `/tmp` was used for verification only; it did not install a system package or repair the default PATH. See `docs/reports/baseline-audit-a71643a.md`.
- P4 audit result: both official PowerShell download paths were BLOCKED by the measured network restrictions → RESULT BLOCKED, no third-party, no snap, no source build, no unofficial mirror. Recheck the network before treating this as current.

## Capability Mapping for Network

- CAP_NETWORK_READ: LOW risk for official allowlisted read-only, AUTO approval if network PASS and official source, BLOCKED if network BLOCKED must be documented
- CAP_NETWORK_CONNECT: MEDIUM for allowlisted domains, HIGH for unrestricted, CRITICAL for production, EXPLICIT_APPROVAL for unrestricted/production

## CI Network Checks

- CI must not fail due to network availability unless network is essential part of test
- No ping 8.8.8.8 as security or CI requirement
- Can use GitHub APIs only if purpose verified repository operation (e.g., checkout, upload-artifact)
- PowerShell policy tests can verify logic without making absence of pwsh in CI fake PASS — if runner contains pwsh, real syntax/smoke test, if not, NOT VERIFIED/CONDITIONAL but not PASS without real execution

## P4 Blocker in CI vs Arena

- ARENA_P4_STATUS = BLOCKED (packages.microsoft.com and release-assets blocked in Arena)
- REMOTE_CI_P4_STATUS = NOT VERIFIED UNTIL REAL RUN (GitHub Actions runner may differ, may have network to packages.microsoft.com and release-assets, may have pwsh preinstalled)
- Do not assume Arena = GitHub, don't mix

## Future Network Isolation Roadmap

- Level 2: Filesystem isolation (current Level 0 Gate)
- Level 3: Network isolation — network namespace, allowlist domains only (e.g., only github.com, api.github.com, packages.microsoft.com, etc. allowlisted)
- Level 4: Container/sandbox with network policy
- Level 5: VM with stronger network isolation
- Level 6: Optional deeper OS integration with network control

No implementation in P8, only roadmap.

## References

- docs/operations.md (network limits table, P4 blocker table)
- execution-model.md (network executor)
- security-boundaries.md (network boundaries)
- capability-model.md (CAP_NETWORK_READ, CAP_NETWORK_CONNECT)
- AGENTS.md (Network Rules NETWORK_AVAILABLE/PARTIALLY/BLOCKED)
- ARENA.md (Network Rules)
