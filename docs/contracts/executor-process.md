# Process Executor Contract — P10

> CONTRACTS ONLY — No implementation, no process runner implementation, no package install, no system changes, repository-only.

## Purpose

Process Executor is preferred path when Shell semantics not needed. Executes executable with argv[] directly, no shell parsing, no bash -c, no sh -c, no shell syntax interpretation, ARGV MODE preferred, more secure than Shell Executor.

```
process.exec(["git","status"])  → Process Executor → CAP_PROCESS_EXEC → HIGH → EXPLICIT_APPROVAL → Result + Evidence
```

vs Shell Executor:

```bash
bash -lc "git status && ..."  → Shell Executor → CAP_PROCESS_EXEC → HIGH/CRITICAL → REQUIRE_APPROVAL → Output + Trace + Evidence
```

Process Executor ≠ Shell Executor. Shell interprets shell syntax, supports pipelines only if explicitly permitted, has shell-specific attack surface, MUST NOT receive arbitrary user-generated command text without Policy and explicit authorization. Process Executor does not interpret shell syntax, uses direct argv, safer.

## Capability

- CAP_PROCESS_EXEC (HIGH, EXPLICIT_APPROVAL, DRY_RUN may be required for host scope, network connect, privileged, production)
- Also may need CAP_FS_READ, CAP_FS_WRITE, CAP_NETWORK_READ, CAP_NETWORK_CONNECT depending on executable and resource and scope, but primary capability is CAP_PROCESS_EXEC

## Risk

- HIGH by default (process execution can cause side effects, resource usage, network, filesystem, etc.)
- CRITICAL if scope is host, network, production, or executable is privileged, or resource is /etc/sudoers, root filesystem, etc. → DENY CLASS-6 FORBIDDEN
- Risk depends on executable, argv, cwd, environment, scope, resource limits, timeout, etc.

## Input Schema

```json
{
  "executable": "string, e.g., 'git', 'make', 'gcc', 'pkg-config', must be validated, no path traversal, must be in allowlist or known, no /etc/sudoers, no root filesystem mutation unless explicit host scope + very strong auth + production evidence, no arbitrary command",
  "argv": ["string, array of args, e.g., ['status'], must be validated, no shell syntax, no ; && || $() `` | > < etc. unless explicitly via Shell Executor, no path traversal, no secret exfiltration, no command injection, no eval"],
  "cwd": "string, working directory, must be within allowed_roots, canonicalized, no path traversal, Unknown path scope → BLOCKED, must be workspace_root, repository_root, or project_root, not /etc, not /etc/sudoers, not root filesystem unless explicit host scope + very strong auth",
  "environment_allowlist": ["string, explicit allowlist of env vars, e.g., ['PATH','HOME','LANG'], no full environment auto-pass, no secrets, SECRET_REFERENCE only, no SECRET_VALUE, no stdout/stderr/event/result/evidence logging of secret"],
  "timeout": {
    "requested": "number, seconds, requested timeout",
    "enforced": "number, seconds, enforced timeout by Execution Authority, must be bounded"
  },
  "resource_limits": {
    "cpu": "number | null, design only, P10 no enforcement but required, missing → policy-defined, high-risk requires limits",
    "memory": "number | null, design only",
    "disk": "number | null, design only",
    "process_count": "number | null",
    "file_descriptors": "number | null",
    "network": "boolean",
    "execution_time": "number, seconds, max execution time, must be bounded",
    "output_size": "number, max bytes, max_output_size, truncation_policy"
  },
  "input": {
    "schema": "JSON Schema, validated, no secrets, invalid → DENY",
    "data": "actual input, no secrets, validated against schema"
  },
  "working_directory": "string, alias for cwd, must be within allowed_roots",
  "network_policy": {
    "mode": "allowlist | deny | unrestricted (only with CAP_NETWORK_CONNECT + explicit policy)",
    "allowed_domains": ["github.com", "..., allowlist"],
    "allowed_ips": ["..."],
    "allowed_ports": [443, 80, "..."],
    "protocols": ["https", "http", "..."],
    "max_bytes": "number, max payload",
    "timeout": "number, seconds",
    "audit": true
  },
  "filesystem_policy": {
    "workspace_root": "string, canonicalized",
    "repository_root": "string, canonicalized",
    "project_root": "string | null, canonicalized",
    "allowed_roots": ["workspace_root", "repository_root", "..., explicit, no /etc, no /etc/sudoers, no root filesystem unless explicit host scope + very strong auth"],
    "symlink_policy": "follow | no_follow | restricted",
    "path_traversal_defense": true
  },
  "evidence_requirements": {
    "required": true,
    "hash": "SHA256 required",
    "provenance": "who/when/how required",
    "attestation": "verifier_id required, not AI",
    "no_pass_without_evidence": true,
    "succeeded_not_verified": true
  },
  "correlation_id": "string, must be present",
  "idempotency_key": "string | null, for idempotency, prevents replay",
  "sandbox_level": "0 | 1 | 2 | 3 | 4 | 5 | 6, design only, current 0 Gate"
}
```

Rules:

- No bash -c, no sh -c, no shell parsing by default, ARGV MODE preferred, direct executable + argv[]
- No shell syntax in argv: no ; && || $() `` | > < $ * ? ! ~ # etc. unless explicitly via Shell Executor with Policy and explicit authorization
- Executable must be validated, no path traversal, must be in allowlist or known, no /etc/sudoers, no root filesystem mutation unless explicit host scope + very strong auth + production evidence
- Cwd must be within allowed_roots, canonicalized, no path traversal, Unknown path scope → BLOCKED
- Environment allowlist only, no full environment auto-pass, no secrets, SECRET_REFERENCE only, no SECRET_VALUE, no stdout/stderr/event/result/evidence logging of secret
- Timeout must be bounded, must terminate or quarantine per policy, no auto SUCCESS
- Resource limits design only P10 but required, missing → policy-defined behavior, high-risk requires limits
- Input schema validated, invalid → DENY, no secrets, no path traversal, no command injection, no secret exfiltration, no eval, no curl|bash executable
- Network policy must contain destination, protocol, port, domain/IP policy, allowlist, scope, timeout, rate limit, payload limit, audit, Unknown destination BLOCKED, no unrestricted Internet except capability + explicit policy
- Filesystem policy must contain workspace_root, repository_root, project_root, allowed_roots, symlink_policy, path traversal defense, Unknown path scope BLOCKED, no ../, no /etc/sudoers, no root filesystem mutation unless explicit host scope + very strong auth
- Evidence requirements required, hash SHA256, provenance who/when/how, attestation verifier_id, no_pass_without_evidence, succeeded_not_verified
- Correlation_id must be present, ties execution to workflow, task, run, action, events, results, evidence
- Idempotency_key for idempotency, prevents replay, especially network, package, external APIs, production
- Sandbox_level 0-6 design only current 0 Gate, P10 no isolation implementation, only contracts allow passing sandbox_level

## Output Schema

```json
{
  "execution_id": "string, reference",
  "status": "STARTED | SUCCEEDED | FAILED | BLOCKED | CANCELLED | TIMEOUT | RESOURCE_EXCEEDED | UNVERIFIED",
  "exit_code": "number | null, 0 for SUCCEEDED, non-zero for FAILED, null for BLOCKED/CANCELLED/TIMEOUT/RESOURCE_EXCEEDED",
  "stdout_reference": "string | null, reference to stdout artifact, not inline if large, with hash, no secrets, max_output_size, truncation_policy",
  "stderr_reference": "string | null, reference to stderr artifact, not inline if large, with hash, no secrets, max_output_size, truncation_policy",
  "output_metadata": {
    "stdout_size": "number, bytes",
    "stderr_size": "number, bytes",
    "stdout_hash": "string, SHA256 hash, no secrets",
    "stderr_hash": "string, SHA256 hash, no secrets",
    "truncated": "boolean, true if truncated due to max_output_size",
    "truncation_policy": "head+tail | head | hash_only"
  },
  "resource_usage": {
    "cpu": "number, actual",
    "memory": "number, actual",
    "disk": "number, actual",
    "process_count": "number, actual",
    "file_descriptors": "number, actual",
    "network": "boolean, used?",
    "execution_time": "number, seconds, actual",
    "output_size": "number, bytes, actual"
  },
  "duration": "number, seconds, actual",
  "started_at": "timestamp UTC",
  "completed_at": "timestamp UTC",
  "executor_id": "string, 'process-executor'",
  "executor_version": "string, version",
  "side_effects": {
    "classification": "READ_ONLY | NO_SIDE_EFFECT | REVERSIBLE_SIDE_EFFECT | IRREVERSIBLE_SIDE_EFFECT | EXTERNAL_SIDE_EFFECT | PRODUCTION_SIDE_EFFECT | SYSTEM_SIDE_EFFECT | DENY",
    "description": "string, what side effects, e.g., 'executed git status', no secrets",
    "reversible": "boolean",
    "external": "boolean",
    "production": "boolean"
  },
  "artifacts": ["artifact_id, list of artifacts produced, with owner, scope, hash SHA256, provenance, retention, no /tmp inside repo, no *.deb inside repo, no secrets"],
  "error": {
    "code": "string | null, e.g., 'execution.executor_failed', 'execution.timeout', 'execution.resource_exceeded', 'execution.input_invalid', etc.",
    "message": "string | null, human readable, no secrets",
    "details": "object | null, error details, no secrets"
  },
  "evidence_reference": "string | null, reference to Evidence, must be present for VERIFIED, no PASS without evidence",
  "correlation_id": "string"
}
```

## Execution Context

See execution-authority.md ExecutionContext, with identity, capabilities, scope, cwd, environment_policy ALLOWLISTED ENV only, filesystem_scope, network_scope, timeout, resource_limits, output_limits, secrets_policy REFERENCE ONLY, audit_context, correlation_id, workspace_root, repository_root, project_root, sandbox_level.

## DRY-RUN

Process Executor must support DRY_RUN if risk_class requires (CLASS-4..5 mandatory).

DRY-RUN must produce WOULD_EXECUTE but NO SIDE EFFECT and must mention executor, command/action abstraction (executable, argv, cwd), scope, capability, policy, authorization, resource limits, expected side effects, no expose secrets.

Example:

```
ACTION: process.exec
CLASS: CLASS-2
POLICY: ALLOW
DECISION: DRY_RUN (if required) or ALLOW
EXECUTION: WOULD_EXECUTE process.exec executable=git argv=["status"] cwd=/home/user/linex.os via Process Executor
EXIT_CODE: N/A (DRY_RUN)
TIMESTAMP: 2026-10-04T18:12:00Z
SYSTEM_SUDO: AVAILABLE_NOPASSWD (EXTERNAL)
PROJECT_POLICY: CONTROLLED
SCOPE: workspace
CAPABILITY: CAP_PROCESS_EXEC
AUTHORIZATION: AUTHORIZED
RESOURCE_LIMITS: cpu=null, memory=null, disk=null, process_count=null, fd=null, network=false, execution_time=60, output_size=1024
EXPECTED_SIDE_EFFECTS: READ_ONLY (git status)
EVIDENCE: evidence_id, hash SHA256, provenance, attestation, no secrets
```

## Side-Effect Classification

- READ_ONLY / NO_SIDE_EFFECT: e.g., git status, ls, cat workspace file, no mutation
- REVERSIBLE_SIDE_EFFECT: e.g., git commit (can be reverted), file write workspace (can be reverted)
- IRREVERSIBLE_SIDE_EFFECT: e.g., git push (may be irreversible), file delete
- EXTERNAL_SIDE_EFFECT: e.g., git push to remote, network upload
- PRODUCTION_SIDE_EFFECT: e.g., deploy to production, production DB write
- SYSTEM_SIDE_EFFECT: e.g., package install, system config change
- DENY: destructive system operation, e.g., rm -rf /, mkfs, modify /etc/sudoers, CLASS-6 FORBIDDEN

## Resource Limits, Timeout, Cancellation, Retry, Idempotency

See execution-authority.md: resource_limits design only P10 but required, timeout bounded must terminate or quarantine per policy no auto SUCCESS, cancellation CANCEL_REQUESTED/CANCELLING/CANCELLED no orphaned processes/mounts/open resources/temporary privileged state unless RECOVERY REQUIRED, retry does not retry automatically if Policy DENY/Authorization DENY/Capability DENY/Validation DENY/Security violation allowed future only transient failure but every retry re-does Policy validation/Authorization check/Resource allocation/Evidence bounded retry, idempotency_key prevents replay especially network/package/external APIs/production.

## Workspace Isolation, Filesystem Isolation Roadmap, Network Policy, Secrets, Output Handling, Health, Trust

See execution-authority.md: workspace_root/repository_root/project_root must know, workspace scope ≠ host scope elevation needs explicit authorization, filesystem isolation roadmap Level 0 Project Gate Level 1 Unprivileged process Level 2 Filesystem isolation Level 3 Network isolation Level 4 Container/sandbox Level 5 VM Level 6 Deeper OS integration P10 no isolation implementation only contracts allow passing sandbox_level, network policy context network_mode allowed_domains allowed_ips allowed_ports protocols max_bytes timeout audit No network policy BLOCKED for restricted operations, secrets SECRET_REFERENCE not SECRET_VALUE no stdout/stderr/event/result/evidence logging of secret, output handling stdout/stderr/structured_output with max_output_size truncation_policy hash artifact_reference OUTPUT_LIMIT_EXCEEDED does not fail system in uninterpretable way, executor health health() capabilities() version() status() but health does not grant authority, executor trust TRUSTED_EXECUTOR RESTRICTED_EXECUTOR UNTRUSTED_EXECUTOR currently Shell/Process/File/Network/Package all CONTROLLED/RESTRICTED BY POLICY even if trusted code MCP/Plugin future UNTRUSTED BY DEFAULT need Gateway/Sandbox.

## Events, Verification Hooks, Matrix, Mapping, Error Model, Security Invariants

See execution-authority.md and executor-matrix.md: execution events execution.proposed/validating/authorized/started/completed/failed/blocked/cancelled/timeout/resource_exceeded/verification_required all with event_id execution_id action_id task_id run_id actor executor capability resource scope result correlation_id timestamp no secrets, verification hooks before_execute/after_execute/on_block/on_fail/on_cancel/on_timeout/on_resource_exceeded but hook cannot authorize/bypass Policy/mark VERIFIED only provide evidence/context, executor contract matrix table Executor/Capability/Default Risk/Default Approval/Scope/DRY-RUN/Gate/Verifier, Action→Execution mapping Action Type→Executor→Capability→Risk→Approval→Verification, error model execution.invalid_request/policy_denied/authorization_denied/capability_denied/scope_denied/executor_unknown/input_invalid/timeout/resource_exceeded/network_blocked/filesystem_blocked/package_blocked/executor_failed/verification_failed, security invariants EA-01 to EA-20 and INV-EA-01 to INV-EA-20.

## Diagrams

```
Process Executor Flow:

Action (process.exec)
  ↓
Policy (ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN, UNKNOWN→DENY)
  ↓
Authorization (Actor, Capability CAP_PROCESS_EXEC, Resource executable, Scope workspace, Risk HIGH, Approval EXPLICIT_APPROVAL)
  ↓
Execution Authority (revalidate contract, bind capability/scope/resource limits, select Process Executor, establish ExecutionContext, enforce timeout/output limits)
  ↓
Process Executor (executable, argv[], cwd, environment_allowlist, timeout, resource_limits, no bash -c, no sh -c, no shell parsing, ARGV MODE preferred)
  ↓
Result (ExecutionResult STARTED/SUCCEEDED/FAILED/BLOCKED/CANCELLED/TIMEOUT/RESOURCE_EXCEEDED/UNVERIFIED, exit_code, stdout_reference/stderr_reference/output_metadata/resource_usage/duration/started_at/completed_at/executor_id/executor_version/side_effects/artifacts/error/evidence_reference/correlation_id, no secrets, SUCCEEDED≠VERIFIED)
  ↓
Verifier (no PASS without evidence, SUCCEEDED≠VERIFIED)
  ↓
Evidence (STATUS/RESULT/EVIDENCE/NEXT, hash, provenance, attestation, no secrets)
```

Mermaid:

```mermaid
flowchart TD
    A[Action: process.exec] --> B[Policy: ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN]
    B --> C[Authorization: Actor, CAP_PROCESS_EXEC, Resource, Scope, Risk, Approval]
    C --> D[Execution Authority: revalidate, bind capability/scope/limits, select Process Executor, establish context, enforce timeout/output]
    D --> E[Process Executor: executable, argv[], cwd, env allowlist, timeout, resource_limits, no bash -c, ARGV MODE]
    E --> F[ExecutionResult: STARTED/SUCCEEDED/FAILED/BLOCKED/CANCELLED/TIMEOUT/RESOURCE_EXCEEDED/UNVERIFIED, exit_code, stdout/stderr refs, resource_usage, side_effects, artifacts, error, evidence_ref]
    F --> G[Verifier: no PASS without evidence, SUCCEEDED != VERIFIED]
    G --> H[Evidence: STATUS/RESULT/EVIDENCE/NEXT, hash, provenance, attestation, no secrets]
```

```
Process vs Shell:

process.exec(["git","status"]) → Process Executor → direct argv → no shell parsing → safer → READ_ONLY → LOW/MEDIUM risk → AUTO/EXPLICIT depending scope → File Executor? No, Process Executor → ARGV MODE preferred

shell.exec("git status && ...") → Shell Executor → shell syntax → interprets pipelines, &&, ||, $(), ``, |, >, <, etc. → shell-specific attack surface → MUST NOT receive arbitrary user-generated command text without Policy and explicit authorization → HIGH/CRITICAL risk → REQUIRE_APPROVAL especially host scope, network connect, privileged, production → shell.command vs process.argv separated

Default: Process Executor preferred when no Shell semantics needed. Shell Executor capability separate and high risk.
```

## May Do

- Define Process Executor Contract with executable, argv[], cwd, environment_allowlist, timeout, resource_limits, input, working_directory, network_policy, filesystem_policy, evidence_requirements, correlation_id, idempotency_key, sandbox_level, no secrets, schemas validated, unknown field handling fail-closed UNKNOWN→DENY/BLOCKED, unknown capability denied, unknown executor blocked
- Execute via Process Executor only after Policy AUTHORIZED, Authorization AUTHORIZED, capability, resource, scope, risk, approval verified, resource limits bound, timeout enforced, ExecutionContext established
- Support DRY_RUN if risk_class requires, produce WOULD_EXECUTE but NO SIDE EFFECT, mention executor, command/action abstraction, scope, capability, policy, authorization, resource limits, expected side effects, no expose secrets
- Classify side effects READ_ONLY/NO_SIDE_EFFECT/REVERSIBLE/IRREVERSIBLE/EXTERNAL/PRODUCTION/SYSTEM/DENY and map to risk
- Enforce resource limits design only P10 but required, timeout bounded, cancellation no orphaned resources, retry bounded and reauthorized, idempotency prevents replay
- Know workspace_root/repository_root/project_root, workspace scope ≠ host scope, elevation needs explicit authorization, filesystem isolation roadmap Level 0-6 design only, network policy context, secrets REFERENCE ONLY no logging, output handling with max_output_size truncation_policy hash artifact_reference, health() capabilities() version() status() but health does not grant authority, trust CONTROLLED/RESTRICTED BY POLICY even if trusted code
- Emit execution events with event_id execution_id action_id task_id run_id actor executor capability resource scope result correlation_id timestamp no secrets, support verification hooks before_execute/after_execute/on_block/on_fail/on_cancel/on_timeout/on_resource_exceeded but hook cannot authorize/bypass Policy/mark VERIFIED only provide evidence/context
- Support executor contract matrix and Action→Execution mapping and error model and security invariants EA-01 to EA-20 and INV-EA-01 to INV-EA-20

## Must Never Do

- Choose implementation language, implement process runner (no product code), install packages, modify system, commit/print/log secrets, create /tmp inside repo, *.deb inside repo, allow LLM→Executor direct, Planner→Executor direct, Agent→Executor direct, UI→Executor direct, MCP Server→Executor direct, bypass Policy, allow unknown capability/tool/executor, allow missing auth, allow missing evidence as PASS, implicit state jumps, auto-success, SUCCEEDED=VERIFIED, LOCAL=PRODUCTION, MOCK=PRODUCTION, events with secrets, mutable events, no event_id/timestamp/actor/correlation_id, evidence without STATUS/RESULT/EVIDENCE/NEXT, PASS without evidence, arbitrary sudo, arbitrary shell, bash -c, sh -c, shell parsing by default for Process Executor, shell syntax in argv, path traversal, secret exfiltration, command injection, eval, curl|bash executable, /etc/sudoers modification, rm -rf /, retry on Policy DENY/Authorization DENY/Capability DENY/Validation DENY/Security violation, orphaned resources on cancellation, auto-success on recovery, choose vendor for storage, require paid API/cloud DB, require GPU/K8s, violate P8 frozen baseline without ADR, violate P9 contracts without ADR

## References

- docs/contracts/execution-authority.md (Execution Authority, ExecutionRequest, ExecutionResult, ExecutionContext, ExecutorRegistry, security invariants, etc.)
- docs/contracts/executor-matrix.md (matrix and mapping)
- docs/contracts/execution-lifecycle.md (state machine)
- docs/contracts/runtime.md, task.md, action.md, event.md, result.md, lifecycle.md (P9)
- docs/architecture/frozen-baseline.md (P8 freeze)
- docs/architecture/adr/0007-core-runtime-contracts.md (P9), 0008-execution-authority-contract.md (P10)
- docs/architecture/execution-model.md, security-boundaries.md, capability-model.md
- docs/agent-contract.md (AI PROPOSES→POLICY→EXECUTION→VERIFIER)
- ops/security/privilege-gate.sh (must not be bypassed)
