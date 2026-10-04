# ADR 0008 — Execution Authority Contract (P10)

- Status: ACCEPTED
- Date: 2026-10-04T19:00:00Z
- Branch: arena/01a107fc-linex-os
- Commit: 768bf39 (main), P8 frozen baseline preserved, P9 Core Runtime Contracts COMPLETE
- Phase: P10 — Execution Authority Contracts ONLY (CONTRACTS ONLY, no executor implementation, no shell framework, no process runner, no file service, no network client, no package installer, no browser, no computer-use, no Docker, no PowerShell install, no package install, no system changes, no production deployment, only contracts/schemas/state machines/invariants/ADRs/test specs/architecture documentation)
- Related: ADR 0001 Scope Model C hybrid, ADR 0002 Execution Boundary, ADR 0003 Capability Security Model, ADR 0004 Policy vs Execution Separation, ADR 0005 Storage Abstraction, ADR 0006 Extensibility Model, ADR 0007 Core Runtime Contracts, P8 frozen-baseline.md, P9 docs/contracts/

## Context

P8 Architecture Design COMPLETE and FROZEN with 14 architecture docs, 6 ADRs, frozen-baseline.md, tests 15/15 PASS, verify-architecture PASS, doctor PASS WITH KNOWN BLOCKER P4, no product code, no package install, no system changes, repository-only, Remote CI NOT VERIFIED per spec no push.

P8 defined What is LINEX.OS (AI-native Execution Operating Environment above Linux, not kernel replacement v1, Model C hybrid: execution environment first, deeper OS integration later), system boundary Inside/Outside Trusted/Semi-trusted/Untrusted, 23 core components with Purpose/Inputs/Outputs/Trust/Dependencies/May Do/Must Never Do, trust boundary LLM→Planner→Policy→Authorization→Execution Authority→Verifier→Evidence with forbidden direct paths BLOCKED, capability model CAP_* with Risk/Scope/Approval/Executor/Verifier DEFAULT DENY UNKNOWN→DENY, resource scoping workspace/repository/project/user/host/network/production explicit elevation, Agent/Tool/Skill/MCP models, Execution Authority independent via Policy, sandboxing roadmap Level 0 Gate current → Level 6 deeper OS integration, Policy Engine inputs Actor/Action/Capability/Resource/Scope/Risk/Env/Context/Approval/Network decisions ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN UNKNOWN→DENY, state lifecycle PROPOSED→VERIFIED SUCCEEDED≠VERIFIED, event model append-only immutable no secrets, memory Ephemeral/Session/Project/User/System, artifact Source/Build/Execution/Evidence/User, storage abstraction interfaces local/optional remote/replaceable no vendor free-first vendor-neutral self-hostable local-capable, network zones Trusted/Restricted/Untrusted with current Arena network PASS/BLOCKED evidence, identity boundaries, observability DEBUG LOG vs AUDIT vs SECURITY vs VERIFICATION distinction no secrets no mixing, failure classes, fail-closed, resource limits design only, threat model 16 threats, supply chain provenance hashes version pinning full SHA signature roadmap, multi-tenancy readiness, API/UI boundaries conceptual, dependency direction fixed UI→API→Application Services→Runtime→Policy/Authorization→Execution→Host/External no cycles, modularity replaceable via interfaces, free-first, low-resource CORE/STANDARD/HEAVY no GPU/K8s, open decisions PENDING (Programming Language, Runtime tech, DB, Event bus, Sandbox, UI/API framework, Browser engine, MCP transport, Deployment topology) with criteria no fill gap.

P9 Core Runtime Contracts COMPLETE with Contract First → Implementation Later, no implementation language chosen, no product code, no package install, no system changes, repository-only, only contracts/schemas/state machines/invariants/tests diagrams-as-text ASCII/Mermaid, respects P8 frozen baseline, any violation requires ADR, defines 5 core contracts Runtime Contract (lifecycle, task execution, state transitions, cancellation, recovery, configuration, health, events, verification hooks), Task/Run Contract (unit of work, execution instance, inputs/outputs, capabilities, risk, retry, timeout), Action Contract (proposed by Agent/Planner, validated by Policy, authorized, executed by Execution Authority, verified), Event Contract (append-only immutable, no secrets, correlation), Result/Evidence Contract (output, error, metrics, evidence, attestation, SUCCEEDED≠VERIFIED), plus lifecycle state machines for Runtime, Task/Run, Action, Event, Result with Mermaid diagrams, ADR 0007 ACCEPTED, tests 15/15 PASS, verify-contracts PASS, doctor still PASS WITH KNOWN BLOCKER.

Now P9 says Task → Action → Event → Result → Evidence has independent contract before execution. Next is P10 — Execution Authority Contracts, with critical separation:

```
Planner / Agent
      ↓
Action
      ↓
Policy
      ↓
Authorization
      ↓
Execution Authority   ← the ONLY component that owns Side Effects
      ↓
Executor
      ↓
Result
      ↓
Verifier
```

And important decision in P10:

```
Shell Executor    ≠ Process Executor
```

Because process.exec(["git","status"]) differs security-wise from:

```bash
bash -lc "git status && ..."
```

Direct argv should be default, Shell Executor capability separate and high risk.

User prompt P10 for Arena: Execute now P10 — Execution Authority Contracts ONLY inside elazamey/linex.os, with current state P1 COMPLETE, P2 COMPLETE, P3 COMPLETE, P4 BLOCKED Arena network restriction, P5 COMPLETE, P6 COMPLETE, P7 COMPLETE, P8 ARCHITECTURE FROZEN, P9 COMPLETE Core Runtime Contracts, REMOTE CI NOT VERIFIED, scope CONTRACTS ONLY, forbidden executor implementation, shell execution framework, process runner implementation, file service implementation, network client implementation, package installer implementation, browser implementation, computer-use implementation, Docker, PowerShell installation, package installation, system changes, production deployment, only contracts/schemas/state machines/invariants/ADRs/test specs/architecture documentation.

Purpose: define EXECUTION AUTHORITY as independent component from LLM, Planner, Agent, Policy, Authorization, Verifier, Execution Authority is the ONLY component architecturally allowed to transform AUTHORIZED ACTION into REAL SIDE EFFECT, mandatory path Action→Policy→Authorization→Execution Authority→Executor→Result→Verifier→Evidence.

Core security principle INV-EA-01 to INV-EA-20 and security invariants EA-01 to EA-20, Execution Authority boundary responsibilities and must NOT, ExecutionRequest contract fields, ExecutionResult contract fields and statuses, ExecutionContext with identity, capabilities, scope, cwd, environment_policy ALLOWLISTED ENV, filesystem_scope, network_scope, timeout, resource_limits, output_limits, secrets_policy, audit_context, correlation_id, secrets REFERENCE ONLY, ExecutorRegistry, 5 Executor types Shell, Process, File, Network, Package no implementation, Shell Executor capability CAP_PROCESS_EXEC HIGH/CRITICAL per scope interprets shell syntax supports pipelines only if explicitly permitted MUST NOT receive arbitrary user-generated command text without Policy and explicit authorization separate shell.command vs process.argv Shell default REQUIRE_APPROVAL especially host scope network connect privileged production, Process Executor preferred when no Shell semantics needed Input executable argv[] cwd environment_allowlist timeout resource_limits no bash -c no sh -c no shell parsing by default ARGV MODE preferred, File Executor CAP_FS_READ/CAP_FS_WRITE operations read/write/list/stat/copy/move/delete but delete/move/write host scope need Policy/Approval per risk path normalization canonicalization workspace root allowed roots scope enforcement symlink policy path traversal defense Unknown path scope BLOCKED no ../ /etc /etc/sudoers root filesystem mutation, Network Executor CAP_NETWORK_READ/CONNECT request/connect/download/upload must contain destination protocol port domain/IP policy allowlist scope timeout rate limit payload limit audit Unknown destination BLOCKED no unrestricted Internet except capability + explicit policy, Package Executor CAP_PACKAGE_INSTALL future CAP_PACKAGE_REMOVE but P10 package-remove DEFERRED/RESTRICTED must use LINEX.OS Privilege Gate no arbitrary apt no sudo apt "$USER_INPUT" path Package Action→Policy→Authorization→Package Executor→Privilege Gate→Package Manager→Result→Verification, Privileged execution must contain SYSTEM_SUDO_POLICY PROJECT_POLICY CAPABILITY AUTHORIZATION EXECUTOR SCOPE APPROVAL EVIDENCE and forbid sudo <arbitrary> sudo bash sudo sh sudo -i sudo su sudo env and any Executor cannot bypass privilege-gate.sh, DRY-RUN contract every Executor must support DRY_RUN if risk_class requires DRY_RUN must produce WOULD_EXECUTE but NO SIDE EFFECT and must mention executor command/action abstraction scope capability policy authorization resource limits expected side effects no expose secrets, Side-effect classification READ_ONLY NO_SIDE_EFFECT REVERSIBLE_SIDE_EFFECT IRREVERSIBLE_SIDE_EFFECT EXTERNAL_SIDE_EFFECT PRODUCTION_SIDE_EFFECT SYSTEM_SIDE_EFFECT DENY and mapping to risk examples, Resource limits cpu/memory/disk/process_count/file_descriptors/network/execution_time/output_size no enforcement in P10 but missing → policy-defined behavior and for high-risk require limits, Timeout timeout_requested timeout_enforced timeout_result statuses TIMEOUT principle Timeout must not automatically become SUCCESS, Cancellation CANCEL_REQUESTED CANCELLING CANCELLED Executor must not leave orphaned processes/mounts/open resources/temporary privileged state unless documented RECOVERY REQUIRED, Retry Execution Authority does not retry automatically if Policy DENY Authorization DENY Capability DENY Validation DENY Security violation allowed future only transient failure but every retry re-does Policy validation Authorization check Resource allocation Evidence and does not consider retry continuation of old permission without review bounded retry, Idempotency idempotency_key separate same logical execution vs new execution especially network package external APIs production goal prevent replay, Workspace isolation ExecutionContext must know workspace_root repository_root project_root and not equal workspace scope = host scope any elevation needs explicit authorization, Filesystem isolation roadmap keep P8 Level 0-6 P10 no isolation implementation only contracts must allow passing sandbox_level, Network policy context ExecutionContext contains network_mode allowed_domains allowed_ips allowed_ports protocols max_bytes timeout audit No network policy BLOCKED for restricted operations, Secrets Execution Authority must never receive raw secrets unless explicitly authorized by future secret capability origin SECRET_REFERENCE not SECRET_VALUE no stdout/stderr/event/result/evidence logging of secret, Output handling stdout stderr structured_output with max_output_size truncation_policy hash artifact_reference Output larger than limit OUTPUT_LIMIT_EXCEEDED and does not fail system in uninterpretable way, Executor health each Executor Contract must have health() capabilities() version() status() but health does not grant authority, Executor trust TRUSTED_EXECUTOR RESTRICTED_EXECUTOR UNTRUSTED_EXECUTOR currently Shell/Process/File/Network/Package all CONTROLLED/RESTRICTED BY POLICY even if trusted code MCP/Plugin future executors UNTRUSTED BY DEFAULT and need Gateway/Sandbox, Execution events execution.proposed validating authorized started completed failed blocked cancelled timeout resource_exceeded verification_required all with event_id execution_id action_id task_id run_id actor executor capability resource scope result correlation_id timestamp no secrets, Verification hooks Execution Authority must support hooks before_execute after_execute on_block on_fail on_cancel on_timeout on_resource_exceeded but hook cannot authorize/bypass Policy/mark VERIFIED only provide evidence/context, Executor contract matrix table Executor Capability Default Risk Default Approval Scope DRY-RUN Gate Verifier for Shell Process File Network Package, Action → Execution mapping Action Type → Executor → Capability → Risk → Approval → Verification, Error model execution.invalid_request etc., Security invariants EA-01 to EA-20, Contract files docs/contracts/execution-authority.md docs/contracts/executor-shell.md docs/contracts/executor-process.md docs/contracts/executor-file.md docs/contracts/executor-network.md docs/contracts/executor-package.md and docs/contracts/executor-matrix.md, State machine docs/contracts/execution-lifecycle.md with states PROPOSED VALIDATING AUTHORIZED DRY_RUN STARTING RUNNING SUCCEEDED FAILED BLOCKED CANCEL_REQUESTED CANCELLING CANCELLED TIMEOUT RESOURCE_EXCEEDED VERIFICATION_PENDING VERIFIED UNVERIFIED rules no implicit transitions invalid transition → BLOCKED unknown state → BLOCKED policy denial → DENIED/BLOCKED path success must go through verification before VERIFIED, Diagrams ASCII + Mermaid System Execution Flow Action→Policy→Authorization→Execution Authority→Executor→Result→Verifier→Evidence and Process Executor vs Shell Executor and Capability/Scope flow, ADR docs/architecture/adr/0008-execution-authority-contract.md Status ACCEPTED includes Context Decision Alternatives Consequences Risks Future Work Decision Execution Authority becomes sole architectural boundary for host/external side effects, Tests tests/execution-authority.test.sh 36 tests, Verify script ops/verify/verify-execution-authority.sh, P9 compatibility check P10 does not conflict with runtime.md task.md action.md event.md result.md lifecycle.md especially Action Contract Event Contract Result Contract must be ExecutionRequest extension of Action Contract and ExecutionResult extension of Result Contract without duplicate authority models, P8 compatibility must keep Model C Trust Boundaries Capability Model Fail-Closed AI/Policy/Execution separation Storage abstraction Low-resource modes P4 blocker, Open decisions no Rust Go Python Node Docker Firecracker gVisor Playwright any concrete executor framework in P10 use DECISION PENDING with criteria, No implementation even if can write Executor now no src/ runtime/ executor implementation Contracts only, No system changes forbidden apt sudo execution systemctl PowerShell installation Docker installation filesystem changes outside repository network configuration user/group changes, Git no commit push merge reset clean branch deletion show git status --short git diff --stat, Final report with STATUS RESULT EXECUTION_AUTHORITY EXECUTOR_CONTRACTS EXECUTOR_MATRIX SHELL PROCESS FILE NETWORK PACKAGE ACTION_MAPPING EXECUTION_LIFECYCLE CAPABILITY SCOPE AUTHORIZATION DRY_RUN TIMEOUT RESOURCE_LIMITS CANCELLATION RETRY IDEMPOTENCY SECURITY_INVARIANTS EVENTS VERIFICATION_HOOKS ADR TESTS P8_COMPATIBILITY P9_COMPATIBILITY P4_BLOCKER REMOTE_CI SYSTEM_CHANGES GIT BLOCKERS NEXT P10 COMPLETE YES/NO and why this phase is precise because now we move from Action = what we want to do? to Execution Authority = who owns right to transform to real effect? and we get critical separation process.exec argv[] → Process Executor vs shell.exec shell command → Shell Executor and second is much more dangerous even if both are "execute command" After P10 sequence P8 Architecture ✅ P9 Core Contracts ✅ P10 Execution Contracts ▶ P11 Policy Contract P12 Capability Contract P13 Agent Runtime Contract P14 Tool + Skill Contract P15 Memory/State/Event P16 Verification/Eval P17 MCP P18 Technology Selection ↓ IMPLEMENTATION decision here intentional no execution language chosen yet we have now specs that can later be implemented in Rust or Go or Python or Node and core LINEX.OS remains independent of this decision Execute P10 only with this prompt.

## Decision

- ACCEPTED: P10 Execution Authority Contracts ONLY, CONTRACTS ONLY, no executor implementation, no shell execution framework, no process runner implementation, no file service implementation, no network client implementation, no package installer implementation, no browser implementation, no computer-use implementation, no Docker, no PowerShell installation, no package installation, no system changes, no production deployment, only contracts/schemas/state machines/invariants/ADRs/test specs/architecture documentation, respects P8 Architecture Freeze and P9 Core Runtime Contracts, any violation requires ADR.

- P10 defines Execution Authority as sole architectural boundary for host/external side effects, with mandatory path Planner/Agent → Action → Policy → Authorization → Execution Authority ← ONLY component that owns Side Effects → Executor → Result → Verifier → Evidence, with core security principle INV-EA-01 to INV-EA-20 and security invariants EA-01 to EA-20.

- Execution Authority boundary responsibilities: receive authorized Action, revalidate execution contract, bind capability, bind scope, bind resource limits, select approved Executor, establish execution context, enforce timeout, enforce output limits, collect execution result, emit execution events, provide Result to Verifier; Must NOT create authorization, modify policy, infer permission from natural language, grant capabilities, bypass Gate, alter security policy, silently retry denied actions, turn BLOCKED into success.

- ExecutionRequest contract with fields execution_id, version, action_id, task_id, run_id, actor, executor_id, executor_type, capability_required, resource, scope, risk_class, policy_decision, authorization, approval, dry_run, timeout (requested/enforced/result), resource_limits (cpu/memory/disk/process_count/file_descriptors/network/execution_time/output_size), input (schema/data no secrets), environment (policy ALLOWLISTED ENV only, allowlist, secrets_policy REFERENCE ONLY), working_directory (within allowed_roots canonicalized), network_policy (mode allowlist/deny/unrestricted only with CAP_NETWORK_CONNECT + explicit policy, allowed_domains allowlist official only no random mirror, allowed_ips, allowed_ports, protocols, max_bytes, timeout, audit), filesystem_policy (workspace_root, repository_root, project_root, allowed_roots, symlink_policy, path traversal defense), evidence_requirements (required, hash SHA256, provenance who/when/how, attestation verifier_id, no_pass_without_evidence, succeeded_not_verified), correlation_id, idempotency_key (prevents replay especially network/package/external APIs/production), sandbox_level 0-6 design only current 0 Gate, created_at, created_by, immutable after acceptance, no secrets, schemas validated, unknown field handling fail-closed UNKNOWN→DENY/BLOCKED, unknown capability denied, unknown executor blocked.

- ExecutionResult contract with fields execution_id, status STARTED/SUCCEEDED/FAILED/BLOCKED/CANCELLED/TIMEOUT/RESOURCE_EXCEEDED/UNVERIFIED, exit_code, stdout_reference, stderr_reference, output_metadata (stdout_size, stderr_size, stdout_hash SHA256, stderr_hash, truncated, truncation_policy), resource_usage (cpu/memory/disk/process_count/file_descriptors/network/execution_time/output_size actual), duration, started_at, completed_at, executor_id, executor_version, side_effects classification READ_ONLY/NO_SIDE_EFFECT/REVERSIBLE_SIDE_EFFECT/IRREVERSIBLE_SIDE_EFFECT/EXTERNAL_SIDE_EFFECT/PRODUCTION_SIDE_EFFECT/SYSTEM_SIDE_EFFECT/DENY description reversible external production, artifacts list artifact_id with owner/scope/hash/provenance/retention no /tmp inside repo no *.deb inside repo no secrets, error code/message/details no secrets, evidence_reference, correlation_id, no secrets, SUCCEEDED≠VERIFIED.

- ExecutionContext with identity, capabilities, scope, cwd, environment_policy ALLOWLISTED ENV only, filesystem_scope, network_scope, timeout, resource_limits, output_limits, secrets_policy REFERENCE ONLY, audit_context, correlation_id, workspace_root, repository_root, project_root, sandbox_level, no full environment auto-pass, no SECRET_VALUE, no stdout/stderr/event/result/evidence logging of secret.

- ExecutorRegistry with executor_id, type, version, capabilities, risk_class, supported_platforms, input_schema, output_schema, resource_limits, sandbox_level, policy_requirements, verification_requirements, status active/deprecated/blocked, unknown executor BLOCKED.

- 5 Executor Contracts:

  1. Shell Executor — Capability CAP_PROCESS_EXEC Risk HIGH/CRITICAL per scope interprets shell syntax supports pipelines only if explicitly permitted has shell-specific attack surface MUST NOT receive arbitrary user-generated command text without Policy and explicit authorization separate shell.command vs process.argv Shell default REQUIRE_APPROVAL especially host scope network connect privileged production, Input shell_command, shell_type, cwd, environment_allowlist, timeout, resource_limits, input, working_directory, network_policy, filesystem_policy, evidence_requirements, correlation_id, idempotency_key, sandbox_level, no secrets, schemas validated, Output ExecutionResult with status exit_code stdout_reference/stderr_reference/output_metadata/resource_usage/duration/started_at/completed_at/executor_id/executor_version/side_effects/artifacts/error/evidence_reference/correlation_id no secrets SUCCEEDED≠VERIFIED, DRY-RUN required where policy says so must produce WOULD_EXECUTE but NO SIDE EFFECT, Side-effect classification READ_ONLY/NO_SIDE_EFFECT/REVERSIBLE/IRREVERSIBLE/EXTERNAL/PRODUCTION/SYSTEM/DENY, etc.

  2. Process Executor — preferred when no Shell semantics needed Input executable argv[] cwd environment_allowlist timeout resource_limits no bash -c no sh -c no shell parsing by default ARGV MODE preferred, Capability CAP_PROCESS_EXEC Risk HIGH/CRITICAL per scope, Output ExecutionResult, DRY-RUN, etc., safer than Shell Executor, direct argv, no shell parsing, ARGV MODE preferred.

  3. File Executor — Capabilities CAP_FS_READ CAP_FS_WRITE operations read/write/list/stat/copy/move/delete but delete/move/write host scope need Policy/Approval per risk path normalization canonicalization workspace root allowed roots scope enforcement symlink policy path traversal defense Unknown path scope BLOCKED no ../ ../../ /etc /etc/sudoers root filesystem mutation, Input operation path source_path destination_path content cwd environment_allowlist timeout resource_limits input working_directory network_policy filesystem_policy evidence_requirements correlation_id idempotency_key sandbox_level no secrets, Output ExecutionResult, DRY-RUN, side-effect classification READ_ONLY workspace READ_ONLY REVERSIBLE_SIDE_EFFECT workspace etc.

  4. Network Executor — Capabilities CAP_NETWORK_READ CAP_NETWORK_CONNECT operations request/connect/download/upload must contain destination protocol port domain/IP policy allowlist scope timeout rate limit payload limit audit Unknown destination BLOCKED no unrestricted Internet except capability + explicit policy, Input operation destination protocol port domain ip method headers body file_path cwd environment_allowlist timeout resource_limits rate_limit payload_limit input working_directory network_policy filesystem_policy evidence_requirements correlation_id idempotency_key sandbox_level no secrets, Output ExecutionResult, DRY-RUN, side-effect classification READ_ONLY official allowlisted EXTERNAL_SIDE_EFFECT unrestricted etc.

  5. Package Executor — Capability CAP_PACKAGE_INSTALL future CAP_PACKAGE_REMOVE but P10 package-remove DEFERRED/RESTRICTED must use LINEX.OS Privilege Gate no arbitrary apt no sudo apt "$USER_INPUT" path Package Action→Policy→Authorization→Package Executor→Privilege Gate→Package Manager→Result→Verification, Input operation install/remove remove DEFERRED/RESTRICTED in P10 package_name package_version package_source allowlist official only no third-party no snap no unofficial mirror cwd environment_allowlist timeout resource_limits input working_directory network_policy filesystem_policy evidence_requirements correlation_id idempotency_key sandbox_level privilege_gate required gate_path ops/security/privilege-gate.sh must not be bypassed dry_run_first true execute_explicit true evidence ACTION/CLASS/POLICY/DECISION/EXECUTION/EXIT_CODE/TIMESTAMP/SYSTEM_SUDO/PROJECT_POLICY required, Output ExecutionResult with side_effects SYSTEM_SIDE_EFFECT, DRY-RUN mandatory, etc.

- Privileged execution must contain SYSTEM_SUDO_POLICY PROJECT_POLICY CAPABILITY AUTHORIZATION EXECUTOR SCOPE APPROVAL EVIDENCE and forbid sudo <arbitrary> sudo bash sudo sh sudo -i sudo su sudo env and any Executor cannot bypass privilege-gate.sh.

- DRY-RUN contract every Executor must support DRY_RUN if risk_class requires CLASS-4..5 mandatory DRY-RUN must produce WOULD_EXECUTE but NO SIDE EFFECT and must mention executor command/action abstraction scope capability policy authorization resource limits expected side effects no expose secrets must use Privilege Gate if Package Executor must show Gate would execute.

- Side-effect classification READ_ONLY/NO_SIDE_EFFECT REVERSIBLE_SIDE_EFFECT IRREVERSIBLE_SIDE_EFFECT EXTERNAL_SIDE_EFFECT PRODUCTION_SIDE_EFFECT SYSTEM_SIDE_EFFECT DENY and mapping to risk examples fs.read workspace READ_ONLY fs.write workspace REVERSIBLE_SIDE_EFFECT package.install SYSTEM_SIDE_EFFECT network.upload EXTERNAL_SIDE_EFFECT production database write PRODUCTION_SIDE_EFFECT rm -rf / DENY CLASS-6 FORBIDDEN.

- Resource limits cpu/memory/disk/process_count/file_descriptors/network/execution_time/output_size design only enforcement P10 but required missing → policy-defined behavior high-risk requires limits.

- Timeout timeout_requested timeout_enforced timeout_result statuses TIMEOUT principle Timeout must not automatically become SUCCESS must terminate or quarantine per policy.

- Cancellation CANCEL_REQUESTED CANCELLING CANCELLED Executor must not leave orphaned processes/mounts/open resources/temporary privileged state unless documented RECOVERY REQUIRED.

- Retry Execution Authority does not retry automatically if Policy DENY Authorization DENY Capability DENY Validation DENY Security violation allowed future only transient failure but every retry re-does Policy validation Authorization check Resource allocation Evidence and does not consider retry continuation of old permission without review bounded retry.

- Idempotency idempotency_key separate same logical execution vs new execution especially network package external APIs production goal prevent replay.

- Workspace isolation ExecutionContext must know workspace_root repository_root project_root and not equal workspace scope = host scope any elevation needs explicit authorization.

- Filesystem isolation roadmap keep P8 Level 0 Project Gate Level 1 Unprivileged process Level 2 Filesystem isolation Level 3 Network isolation Level 4 Container/sandbox Level 5 VM Level 6 Deeper OS integration P10 does not implement isolation only contracts must allow passing sandbox_level.

- Network policy context ExecutionContext contains network_mode allowed_domains allowed_ips allowed_ports protocols max_bytes timeout audit No network policy BLOCKED for restricted operations.

- Secrets Execution Authority must never receive raw secrets unless explicitly authorized by future secret capability origin SECRET_REFERENCE not SECRET_VALUE no stdout/stderr/event/result/evidence logging of secret.

- Output handling stdout stderr structured_output with max_output_size truncation_policy hash artifact_reference Output larger than limit OUTPUT_LIMIT_EXCEEDED and does not fail system in uninterpretable way.

- Executor health each Executor Contract must have health() capabilities() version() status() but health does not grant authority.

- Executor trust TRUSTED_EXECUTOR RESTRICTED_EXECUTOR UNTRUSTED_EXECUTOR currently Shell/Process/File/Network/Package all CONTROLLED/RESTRICTED BY POLICY even if trusted code MCP/Plugin future executors UNTRUSTED BY DEFAULT and need Gateway/Sandbox.

- Execution events execution.proposed validating authorized started completed failed blocked cancelled timeout resource_exceeded verification_required all with event_id execution_id action_id task_id run_id actor executor capability resource scope result correlation_id timestamp no secrets Event Bus append-only immutable no secrets.

- Verification hooks Execution Authority must support hooks before_execute after_execute on_block on_fail on_cancel on_timeout on_resource_exceeded but hook cannot authorize/bypass Policy/mark VERIFIED only provide evidence/context.

- Executor contract matrix table Executor Capability Default Risk Default Approval Scope DRY-RUN Gate Verifier for Shell Process File Network Package.

- Action → Execution mapping Action Type → Executor → Capability → Risk → Approval → Verification e.g., process.exec → Process Executor → CAP_PROCESS_EXEC → HIGH → EXPLICIT_APPROVAL → execution result + evidence.

- Error model execution.invalid_request execution.policy_denied execution.authorization_denied execution.capability_denied execution.scope_denied execution.executor_unknown execution.input_invalid execution.timeout execution.resource_exceeded execution.network_blocked execution.filesystem_blocked execution.package_blocked execution.executor_failed execution.verification_failed.

- Security invariants EA-01 to EA-20 and INV-EA-01 to INV-EA-20.

- Contract files docs/contracts/execution-authority.md docs/contracts/executor-shell.md docs/contracts/executor-process.md docs/contracts/executor-file.md docs/contracts/executor-network.md docs/contracts/executor-package.md and docs/contracts/executor-matrix.md.

- State machine docs/contracts/execution-lifecycle.md with states PROPOSED VALIDATING AUTHORIZED DRY_RUN STARTING RUNNING SUCCEEDED FAILED BLOCKED CANCEL_REQUESTED CANCELLING CANCELLED TIMEOUT RESOURCE_EXCEEDED VERIFICATION_PENDING VERIFIED UNVERIFIED rules no implicit transitions invalid transition → BLOCKED unknown state → BLOCKED policy denial → DENIED/BLOCKED path success must go through verification before VERIFIED.

- Diagrams ASCII + Mermaid System Execution Flow Action→Policy→Authorization→Execution Authority→Executor→Result→Verifier→Evidence and Process Executor vs Shell Executor and Capability/Scope flow.

- ADR docs/architecture/adr/0008-execution-authority-contract.md Status ACCEPTED includes Context Decision Alternatives Consequences Risks Future Work Decision Execution Authority becomes sole architectural boundary for host/external side effects.

- Tests tests/execution-authority.test.sh 36 tests.

- Verify script ops/verify/verify-execution-authority.sh.

- P9 compatibility check P10 does not conflict with runtime.md task.md action.md event.md result.md lifecycle.md especially Action Contract Event Contract Result Contract must be ExecutionRequest extension of Action Contract and ExecutionResult extension of Result Contract without duplicate authority models.

- P8 compatibility must keep Model C Trust Boundaries Capability Model Fail-Closed AI/Policy/Execution separation Storage abstraction Low-resource modes P4 blocker.

- Open decisions no Rust Go Python Node Docker Firecracker gVisor Playwright any concrete executor framework in P10 use DECISION PENDING with criteria.

- No implementation even if can write Executor now no src/ runtime/ executor implementation Contracts only.

- No system changes forbidden apt sudo execution systemctl PowerShell installation Docker installation filesystem changes outside repository network configuration user/group changes.

- Git no commit push merge reset clean branch deletion show git status --short git diff --stat.

## Alternatives Considered

- Alternative A: Implement Executors directly with assumed language (Python/Node/Rust) and assumed framework — Rejected because P8 open decisions PENDING with criteria, no technologies chosen merely to fill gap, P10 must be vendor-neutral free-first self-hostable local-capable no mandatory paid API/cloud DB, implementation language decision belongs to P18 Technology Selection ADRs after all contracts P9-P17, not now, also would violate CONTRACTS ONLY scope, would introduce product code, package install, system changes, not allowed in P10.

- Alternative B: Treat Shell Executor and Process Executor as same — Rejected because process.exec(["git","status"]) differs security-wise from bash -lc "git status && ...", Shell interprets shell syntax, supports pipelines only if explicitly permitted, has shell-specific attack surface, MUST NOT receive arbitrary user-generated command text without Policy and explicit authorization, Shell default REQUIRE_APPROVAL especially host scope, network connect, privileged, production, Process Executor preferred when no Shell semantics needed, ARGV MODE preferred, no bash -c, no sh -c, no shell parsing by default, safer, separation is critical security boundary.

- Alternative C: Allow direct Agent→Executor, LLM→Executor, UI→Executor, MCP Server→Executor — Rejected because violates P8 trust boundary LLM→Planner→Policy→Authorization→Execution Authority→Verifier→Evidence, forbidden direct paths BLOCKED, Execution Authority is sole architectural boundary for host/external side effects, must have Action Contract, Policy Decision, Authorization, Capability, Scope, Approval, Evidence, fail-closed UNKNOWN→DENY/BLOCKED, no arbitrary sudo, no arbitrary shell, no bypass Gate.

- Chosen: Alternative D: Contract First → Implementation Later with Execution Authority as sole boundary, 5 Executor Contracts with explicit separation Shell vs Process, capabilities, risk, approval, scope, DRY-RUN, Gate, Verifier, side-effect classification, resource limits, timeout, cancellation, retry, idempotency, workspace isolation, filesystem isolation roadmap, network policy, secrets REFERENCE ONLY, output handling, health, trust, events, verification hooks, matrix, mapping, error model, security invariants, diagrams ASCII/Mermaid, no implementation, no package install, no system changes, repository-only, respects P8 frozen baseline and P9 contracts, any violation requires ADR, enables platform architecture, not big monolithic app, core LINEX.OS remains independent of implementation language decision, can later be implemented in Rust or Go or Python or Node.

## Consequences

- Positive: LINEX.OS now has explicit Execution Authority as sole architectural boundary for host/external side effects, with mandatory path Action→Policy→Authorization→Execution Authority→Executor→Result→Verifier→Evidence, with core security principle INV-EA-01 to INV-EA-20 and security invariants EA-01 to EA-20, with ExecutionRequest and ExecutionResult and ExecutionContext and ExecutorRegistry contracts, with 5 Executor Contracts Shell, Process, File, Network, Package with explicit separation Shell vs Process, capabilities, risk, approval, scope, DRY-RUN, Gate, Verifier, side-effect classification, resource limits, timeout, cancellation, retry, idempotency, workspace isolation, filesystem isolation roadmap, network policy, secrets REFERENCE ONLY, output handling, health, trust, events, verification hooks, matrix, mapping, error model, diagrams, no implementation, no package install, no system changes, repository-only, respects P8 frozen baseline and P9 contracts, any violation requires ADR, enables platform architecture, not big monolithic app, core LINEX.OS remains independent of implementation language decision, can later be implemented in Rust or Go or Python or Node, ready for P11 Policy Contract.

- Negative: More documentation before implementation, but necessary for platform architecture, not waste, prevents monolithic app, prevents vendor lock-in, prevents assumptions about language/framework, prevents security bypass, prevents arbitrary sudo/shell, prevents secret logging, prevents orphaned resources, prevents auto SUCCESS on timeout, prevents retry bypass.

- Neutral: Open decisions remain PENDING, technology selection deferred to P18 after all contracts P9-P17, implementation deferred until after P18, consistent with P8 roadmap P9→P10→...→P18→Implementation.

## Status

ACCEPTED — P10 Execution Authority Contracts defined, CONTRACTS ONLY, no executor implementation, no shell framework, no process runner, no file service, no network client, no package installer, no browser, no computer-use, no Docker, no PowerShell install, no package install, no system changes, no production deployment, only contracts/schemas/state machines/invariants/ADRs/test specs/architecture documentation, respects P8 Architecture Freeze and P9 Core Runtime Contracts, any violation requires ADR, Execution Authority becomes sole architectural boundary for host/external side effects, Shell Executor ≠ Process Executor, direct argv default, Shell capability separate and high risk, ready for P11 Policy Contract.

## References

- docs/architecture/frozen-baseline.md (P8 freeze)
- docs/architecture/roadmap.md (P8→P9→P10→...→Implementation)
- docs/architecture/components.md (23 components)
- docs/architecture/execution-model.md (LLM→Planner→Policy→Execution→Verifier)
- docs/architecture/security-boundaries.md (trust boundaries, Test/Policy Boundary)
- docs/architecture/capability-model.md (CAP_*)
- docs/contracts/README.md (P9 overview, Contract First)
- docs/contracts/runtime.md, task.md, action.md, event.md, result.md, lifecycle.md (P9)
- docs/contracts/execution-authority.md, executor-shell.md, executor-process.md, executor-file.md, executor-network.md, executor-package.md, executor-matrix.md, execution-lifecycle.md (P10)
- docs/agent-contract.md (AI PROPOSES→POLICY→EXECUTION→VERIFIER, evidence model)
- ops/security/privilege-gate.sh (Gate, must not be bypassed)
- ADR 0001-0007 (P8/P9)
- AGENTS.md, ARENA.md, privilege-policy.md, security.md
