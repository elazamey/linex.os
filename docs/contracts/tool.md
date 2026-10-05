# Tool Contract — P14

> **CONTRACT ONLY.** No Tool implementation, no Tool runtime, no executor, no sandbox, no DSL, no package installation, no system changes, and no implementation-language decision. P14 consumes—not redefines—the P9–P13 contracts. **Tools declare; P10 executes.**

## Purpose and authority

A **Tool** is a versioned, immutable declaration of one bounded operation that an Agent may propose through a P9 Action. A Tool never executes, never grants, and never widens authority: it names the P10 executor authority that would perform the side effect, the P12 capability reference the proposal must satisfy, the declared risk class, the limits, and the evidence a call must produce.

```
P9 Action (type: tool.call) → P11 Policy → P12 possession/scope → P10 Execution Authority → Executor → P9 Result → Verifier → P9 Evidence
                                                    ▲
                                    Tool descriptor: pinned version + pinned hash
```

`docs/architecture/adr/0007-core-runtime-contracts.md` already requires every Action type to have a Tool Contract with ID, Version, Input/Output schema, Capability required, Risk class, Execution authority, Timeout, Resource limits, and Evidence, and `docs/contracts/policy-matrix.md` already routes `tool.call` to that contract. P14 supplies that contract; it does not create a second authority model.

**A Tool descriptor is never a permission.** It is a declaration that P11, P12, and P10 independently evaluate and may deny.

## Boundaries

| Concept | Owner | What it is | What it must not become |
|---|---|---|---|
| Tool | P14 (this contract) | Versioned declaration of one bounded operation bound to one P10 executor authority | An executor, a permission, a sandbox, a package manager |
| Skill | P14 (`skill.md`) | Linear composition of pinned, separately authorized steps | A runtime, a DSL, an implicit grant, a privilege escalation path |
| Agent / Planner | P13 | Proposes typed P9 Actions | An executor, a policy engine, a verifier |
| Executor | P10 | Sole owner of side effects | Bypassed or wrapped by a Tool |
| Workflow | post-P18 | Branching/graph orchestration | A P14 construct — no branching before P18 |

A Tool is not a process, a container, or a privilege boundary. Losing the Tool layer must not grant anything: absence of a Tool descriptor means the Action cannot be proposed as `tool.call`, and **Unknown Tool → `BLOCKED`**.

## Tool descriptor

Immutable, versioned, secret-free. Schema: `tool-schema.yaml`. Example:

```json
{
  "tool_id": "tool.example.repo_status",
  "version": "1.0.0",
  "name": "Repository status reader",
  "description": "Reads repository status through the process executor with an explicit argument vector.",
  "source": {
    "kind": "repository",
    "locator": "tools/repo_status",
    "license": "Apache-2.0"
  },
  "integrity": {
    "algorithm": "sha256",
    "hash": "0000000000000000000000000000000000000000000000000000000000000000",
    "pinning": "IMMUTABLE"
  },
  "capability_refs": ["CAP_PROCESS_EXEC"],
  "risk_class": "CLASS-2",
  "execution_authority": "process",
  "action_type": "tool.call",
  "trust_level": "semi_trusted",
  "input_schema": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"], "additionalProperties": false},
  "output_schema": {"type": "object", "properties": {"status": {"type": "string"}}, "required": ["status"], "additionalProperties": false},
  "timeout_seconds": 30,
  "resource_limits": {
    "cpu_seconds": 10,
    "memory_mb": 256,
    "output_bytes": 65536,
    "process_count": 1,
    "file_descriptors": 32
  },
  "evidence_requirements": ["p9_action_id", "p9_result_hash", "executor_id", "exit_status"],
  "deterministic": true
}
```

The hash above is a placeholder that is structurally valid and semantically meaningless; it is not a claim about any real artifact.

Rules:

1. `tool_id`, `version`, `integrity.hash`, and the descriptor content together identify an immutable published Tool version. Republishing changed content under an existing `version` is forbidden; it requires a new version (see *Version immutability*).
2. `execution_authority` must be one of the five P10 executors: `shell`, `process`, `file`, `network`, `package`. `browser`, `computer`, `mcp`, `tool`, `skill`, and `workflow` are not P10 executors and are **not valid** in a P14 Tool descriptor; they remain reserved for P17 and post-P18 work.
3. `capability_refs` are descriptive references, not grants. P12 decides possession, scope, validity, expiry, and revocation; a reference that is absent, expired, revoked, or out of scope is denied by the authoritative layer.
4. `capability_refs` must use only capability identifiers that already exist in P12 (`CAP_FS_READ`, `CAP_FS_WRITE`, `CAP_PROCESS_EXEC`, `CAP_PROCESS_READ`, `CAP_NETWORK_READ`, `CAP_NETWORK_CONNECT`, `CAP_PACKAGE_INSTALL`, `CAP_SECRET_ACCESS`). P14 must not invent `CAP_*` identifiers. `CAP_PACKAGE_REMOVE` stays DEFERRED/RESTRICTED per P10 and is not selectable here; `CAP_BROWSER`, `CAP_COMPUTER`, and `CAP_MCP` belong to executors that do not exist yet.
5. `risk_class` uses the existing P11 classification `CLASS-0` … `CLASS-6`. No parallel scale exists. `CLASS-6` is `DENY Always`; a descriptor may not be used to lower a realized risk (`CLASS-5` → `CLASS-2` downgrade is forbidden).
6. `deterministic: true` is required. Non-deterministic, evaluative, or self-modifying tools cannot be declared.
7. `resource_limits` and `timeout_seconds` are mandatory, not optional. A missing or unbounded limit is invalid, and a high-risk (`CLASS-4`/`CLASS-5`) Tool without limits must be rejected rather than defaulted.
8. Authority/capability coupling is enforced structurally: a `shell` Tool requires `CAP_PROCESS_EXEC` and `CLASS-4`/`CLASS-5`; a `package` Tool requires `CAP_PACKAGE_INSTALL` and `CLASS-4`/`CLASS-5`; a `file` Tool requires `CAP_FS_READ` or `CAP_FS_WRITE`; a `network` Tool requires `CAP_NETWORK_READ` or `CAP_NETWORK_CONNECT`; a `process` Tool requires `CAP_PROCESS_EXEC` or `CAP_PROCESS_READ`.
9. An `untrusted` Tool may declare read-only capabilities only. A Tool cannot promote its own `trust_level`.

## Version immutability and pinning

```
descriptor(version V, hash H) --published--> immutable
any content change        --> new version required
same version, new hash    --> BLOCKED (no silent re-pin)
requested pin ≠ installed --> BLOCKED (no fallback to latest)
```

- A call proposal binds `tool_id`, `version`, and `integrity.hash` exactly. There is **no fallback to `latest`** and no automatic "nearest version" resolution.
- An installed artifact whose hash differs from the declared hash is `BLOCKED`. The Tool is not executed, not substituted, and not upgraded implicitly.
- **The hash is an integrity check, not a signature.** P14 claims no signer identity, no provenance cryptography, and no supply-chain attestation.

## Execution path and per-step authorization

Every Tool step is a separate P9 `tool.call` Action and requires all of the following, in order, for each step:

```
1. P9 Action is schema-valid (type tool.call, tool_id/version/hash pinned, inputs validated)
2. P11 decides ALLOW | DENY | REQUIRE_APPROVAL | DRY_RUN | BLOCKED  (fresh decision per step)
3. P12 confirms capability possession, scope, validity, expiry, revocation
4. P10 Execution Authority performs the side effect through a real executor
5. P9 Result, then Verifier evidence
```

- `ALLOW` is not `AUTHORIZED`; possession is not permission; approval is not authorization; DRY-RUN is not execution authority.
- An authorization for one step never transfers to another step, another task, another run, or another Tool version.
- No LLM, Planner, Agent, or Skill may call an executor directly, skip P11/P12, or execute on the strength of a Tool descriptor.
- Missing P11/P12 authorization for a step prevents that step from reaching P10; the run is `BLOCKED`, not partially authorized.

## Limits, timeout, and failure semantics

- `timeout_seconds` is a request; P10 enforces it. A timeout is never a success.
- Resource limits cover `cpu_seconds`, `memory_mb`, `output_bytes`, `process_count`, and `file_descriptors`. Limits are declared in the descriptor, bound by P10, and recorded in evidence.
- A P10 result that exceeds a declared limit is a failed call: it must be reported with limit evidence (`RESOURCE_EXCEEDED`) and must not be promoted to `SUCCEEDED` or `VERIFIED`.
- No automatic retry, no fallback Tool, no version substitution, no "best effort" continuation.

## Registry governance

- A Tool registry write (register, update, activate, suspend, revoke) requires an **explicit P12 delegation** that is valid and in scope, plus a **fresh P11 decision**. A Tool, Skill, Agent, or Planner cannot register, activate, or delegate itself.
- Registry provenance is required (source, version, hash, issuer/owner where applicable); missing or untrusted provenance is `DENY`/`BLOCKED`, following the P12 rules.
- An active published version is immutable. Suspension/revocation follows P12 semantics (`SUSPENDED` → `DENY`/`BLOCKED`, `REVOKED` → `DENY`, never "deleted therefore allowed").
- Registry failure fails closed: an unavailable registry is `BLOCKED`, never "no known restriction".

## Evidence chain

- P9 owns Events, Results, and Evidence. Each call produces its own Action reference, Result reference, event records, executor identity, exit status, and limit evidence.
- Evidence carries a hash for integrity. **The hash is an integrity check, not a signature** and must not be described as attestation of origin.
- Evidence storage belongs to P15; verification belongs to P16. P14 only states what must be recorded and never claims `PASS` on its own.
- `SUCCEEDED ≠ VERIFIED`; `EXECUTED ≠ SAFE`; no `PASS` without evidence; no secrets, secret values, or credentials in descriptors, bindings, events, results, or evidence (`SECRET_REFERENCE` only).

## Invariants

1. Tools declare; P10 executes. No Tool performs a side effect.
2. A Tool descriptor grants nothing: `capability_refs` are descriptive references, not grants.
3. Every step needs its own P9 Action, fresh P11 decision, and independent P12 check before P10.
4. Version and hash are pinned; unknown, mismatched, or unpinned Tools are `BLOCKED`, never resolved to `latest`.
5. Published versions are immutable; content changes require a new version.
6. `risk_class` reuses P11 `CLASS-0`…`CLASS-6`; `CLASS-6` is `DENY Always`; risk is never lowered by declaring it lower.
7. No new `CAP_*` identifier may be invented in P14; references resolve against P12.
8. Registry writes require explicit valid P12 delegation and a fresh P11 decision; no self-grant.
9. Evidence is produced per step; a hash is not a signature; storage is P15; verification is P16.
10. No DSL, runtime, or implementation language is introduced before P18.

## Acceptance

P14-Tool is contract-complete when `tool-schema.yaml` and `skill-schema.yaml` validate against the JSON Schema draft 2020-12 meta-schema and against the valid/invalid instances in `tool-skill-examples.yaml`; `tool-skill-acceptance-tests.yaml` covers per-step authorization, hash mismatch, resource limits, version immutability, risk bounds, registry governance, and the evidence chain; `tests/tool-skill.test.sh` and `ops/verify/verify-tool-skill.sh` pass; and ADR 0013 is accepted. These are contract checks, not simulations of an unimplemented Tool runtime.

## References

- `docs/architecture/roadmap.md` — authoritative phase order and P14 scope
- `docs/architecture/frozen-baseline.md` — P8 trust boundaries and freeze
- `docs/contracts/action.md` — P9 `tool.call` / `skill.exec` action types and `parent_action_id`
- `docs/contracts/result.md`, `event.md` — P9 results, events, evidence, `SUCCEEDED ≠ VERIFIED`
- `docs/contracts/execution-authority.md`, `executor-matrix.md` — P10 executors, limits, timeout, DRY-RUN
- `docs/contracts/policy.md`, `policy-matrix.md` — P11 decisions and `CLASS-0`…`CLASS-6`
- `docs/contracts/capability.md`, `capability-registry.md` — P12 definitions, grants, delegation
- `docs/contracts/agent-runtime.md` — P13 proposal boundary
- `docs/contracts/skill.md`, `tool-schema.yaml`, `skill-schema.yaml`, `tool-skill-examples.yaml`, `tool-skill-acceptance-tests.yaml`
- `docs/architecture/adr/0013-tool-skill-contract.md`
