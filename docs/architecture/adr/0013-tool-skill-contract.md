# ADR 0013 — Tool + Skill Contract (P14)

- Status: ACCEPTED
- Date: 2026-10-05
- Phase: P14 — Tool + Skill Contract ONLY; contracts, JSON Schemas, acceptance vectors, fixtures, tests, verifier; no product implementation
- Baseline: `5304e16eb59c81120639c959f4e4c014a5319b29` (main after PR #9, before P14 changes)
- Related: ADRs 0001–0012; `docs/architecture/frozen-baseline.md`; P9 Action/Result/Event contracts; P10 Execution Authority; P11 Policy; P12 Capability Registry; P13 Agent Runtime

## Context

P13 completed the Agent Runtime contract. The next authoritative phase is P14 Tool + Skill Contract (ADR 0011 D4). P9 already reserved the action types `tool.call` and `skill.exec` and the `parent_action_id` link, and ADR 0007 already requires every action type to have a Tool Contract with ID, Version, Input/Output schema, Capability required, Risk class, Execution authority, Timeout, Resource limits, and Evidence. P14 supplies exactly that contract; it does not create a second authority model, a runtime, or a DSL.

Three risks motivated the constraints below: a Tool or Skill becoming a *de facto* permission (capability laundering), a pinned Tool silently drifting to a floating version, and a Skill becoming a hidden orchestration engine that runs steps without their own P11/P12 checks.

## Decision

1. **Tools declare; P10 executes.** A Tool is a versioned, immutable declaration bound to exactly one P10 executor authority (`shell`, `process`, `file`, `network`, `package`). `browser`, `computer`, `mcp`, `tool`, `skill`, and `workflow` are not P10 executors and are invalid in a P14 Tool descriptor. A Tool never performs a side effect.
2. **Capability references are descriptive, not grants.** `capability_refs` are references that P12 resolves (possession, scope, validity, expiry, revocation) and P11 evaluates. Reusing P12 semantics is mandatory; P14 must not invent `CAP_*` identifiers, and the schemas accept only the existing eight P10-bound identifiers. `CAP_PACKAGE_REMOVE` remains DEFERRED/RESTRICTED and `CAP_BROWSER`/`CAP_COMPUTER`/`CAP_MCP`/`CAP_DB_WRITE` remain future; none are selectable.
3. **Every step is separately authorized.** A Skill step is a distinct P9 `tool.call` Action linked by `parent_action_id`. Each step requires its own fresh P11 decision and an independent P12 check before P10. `ALLOW` for one step never authorizes another; the parent `skill.exec` Action is plan admission only and cannot mark a child `AUTHORIZED`.
4. **Versions and hashes are pinned and immutable.** Versions are semver; `latest` is not a version. A hash mismatch is `BLOCKED` with no fallback, no silent re-pin, and no version substitution. Published content cannot change under an existing version; changed content requires a new version. A hash is an integrity check, **not** a signature, and no attestation or signer identity is claimed.
5. **Risk reuses P11 `CLASS-0` … `CLASS-6`.** No parallel scale exists. `CLASS-6` is `DENY Always`. A Skill's `risk_class` must be greater than or equal to the highest step `risk_class`, and no declaration lowers realized risk.
6. **Limits are mandatory.** `cpu_seconds`, `memory_mb`, `output_bytes`, `process_count`, and `file_descriptors` are required in every Tool descriptor and every Skill budget, with a mandatory timeout. A limit breach yields `RESOURCE_EXCEEDED` plus limit evidence and is never promoted to `SUCCEEDED`/`VERIFIED`.
7. **Skills are linear, pinned, typed, and fail-closed.** Ordered steps only; no branching, loops, DSL, expression evaluation, templates, or orchestration engine before P18. Bindings are explicit and typed, and may reference only earlier steps in the same run. `on_step_failure = BLOCKED`, `fallback = NONE`, `retry = NONE`: no skip, continue, fallback, or automatic retry, and no rollback claim. A blocked step stops the run.
8. **Registry governance.** Any registry write requires an explicit, valid, in-scope P12 delegation plus a **fresh** P11 decision. No Tool, Skill, Agent, or Planner can self-register, self-activate, or self-delegate; missing or untrusted provenance is `DENY`/`BLOCKED`; registry failure fails closed.
9. **Evidence stays P9's.** Each step produces its own Action/Result/event references, executor identity, exit status, and limit evidence. Storage belongs to P15 and verification to P16; P14 issues no `PASS`, claims no cryptographic audit, and never treats `SUCCEEDED` as `VERIFIED`.
10. **Deliverables live in the canonical trees.** `docs/contracts/` (contracts, schemas, vectors, fixtures), `docs/architecture/adr/`, `tests/tool-skill.test.sh`, `ops/verify/verify-tool-skill.sh`. No new `docs/phases/P14` hierarchy and no product code.

## JSON Schema validation dependency (evaluated; adoption gated on explicit approval)

P14 introduces real JSON Schema validation instead of P13's jq-only structural vectors. Because the repository forbids product code (`.py`/`.js`/`.ts`/`.go`/`.rs`), the validator must be an **external CLI**, pinned by version and hash, driven from bash. Verified in the Arena environment on 2026-10-05 (read-only probes; nothing installed):

| Candidate | Source / license | Version | Artifact digest (sha256, computed locally and compared to the published one) | Weight | Meta-schema check |
|---|---|---|---|---|---|
| `jsonschema` (recommended) | PyPI, MIT | 4.26.0 | `d489f15263b8d200f8387e64b4c3a75f06629559fb73deb8fdfb525f2dab50ce` (wheel) | 5 dependencies (`attrs`, `jsonschema-specifications`, `referencing`, `rpds-py`, `typing-extensions`) | CLI calls `Validator.check_schema`; explicit check against the bundled draft 2020-12 meta-schema |
| `check-jsonschema` | PyPI, Apache-2.0 | 0.38.2 | `8edefe154b7117962f2e88318f315fc4bb9615827f932b37cb676a8d42a3a286` (wheel) | larger tree (`click`, `requests`, `ruamel.yaml`, `regress`, `jsonschema`, …) | `--check-metaschema` built in |
| `jv` (Go binary) | GitHub release, MIT | 6.0.3 | `36e9ab8481cc8e2cb27c8336decc9abdcbd606b05792ca88d6188e01ec28766b` (linux-amd64) | single static binary | supported | 
| no new dependency | — | — | — | zero | none; meta-validation stays BLOCKED |

Environment facts recorded as evidence: `pypi.org` and `registry.npmjs.org` respond (HTTP 200) and the two wheels were fetched and hash-verified; `json-schema.org` and `release-assets.githubusercontent.com` are **BLOCKED** from Arena, so the Go binary cannot be fetched locally and an official meta-schema copy cannot be downloaded here. `jq` 1.6 is present and remains the only required JSON tool for the static checks.

**Approved and adopted (owner approval recorded for P14):** `jsonschema==4.26.0`, **tests only**, installed into a temporary virtual environment outside the repository from the fully hash-pinned `ops/ci/requirements-p14-jsonschema.txt` (`pip install --require-hashes`). The repository adds no Python source and no system package changes. Evidence recorded on 2026-10-05:

- all six artifacts resolved by exact version and verified against the published sha256 digests before install;
- installed versions: `jsonschema 4.26.0`, `attrs 26.1.0`, `jsonschema-specifications 2025.9.1`, `referencing 0.37.0`, `rpds-py 2026.9.1`, `typing-extensions 4.16.0`;
- both P14 schemas validate against the official draft 2020-12 meta-schema bundled with the pinned package (`jsonschema_specifications/schemas/draft202012/metaschema.json`, `$id` `https://json-schema.org/draft/2020-12/schema`, sha256 `41da76f5afb7ce062d248f762463a92f7ca47e4e0f905b224ba6afeef91ded0f`) — offline, because `json-schema.org` is blocked in Arena;
- fixture results: 8/8 valid instances accepted, 33/33 invalid instances rejected, 9/9 non-schema invariant fixtures behave as declared; `tests/tool-skill.test.sh` 40/40 PASS and `ops/verify/verify-tool-skill.sh` 17/17 PASS (exit 0) locally.

Note: the upstream `jsonschema` CLI is **deprecated** in favour of `check-jsonschema` and warns on stderr. The exact version pin makes the behaviour reproducible, and the warning is tolerated by the suite; moving to `check-jsonschema` later is a new ADR-level decision with new pinned hashes, not an in-place edit.

CI wiring: `ops/ci/requirements-p14-jsonschema.txt` is installed in Job 5 (P14 step) and in Job 6 (final verification) before the P14 suite and verifier run; `LINEX_JSONSCHEMA_BIN` selects the validator. Where no validator is installed the schema group still reports **BLOCKED** and `ops/verify/verify-tool-skill.sh` exits 2 — it is never reported as PASS without performing the validation.

## Alternatives considered

- **A parallel Tool/Skill risk scale.** Rejected: P11 owns `CLASS-0`…`CLASS-6`; a second scale would create a downgrade path.
- **Letting `capability_refs` imply possession.** Rejected: possession is P12's decision and authorization is P11's; a declaration would become a permission.
- **Allowing a Skill to run all steps under one approval.** Rejected: it removes the per-step P11/P12 check and turns approval into a blanket grant.
- **Resolving a missing pin to `latest` or the nearest version.** Rejected: it defeats immutability and makes behaviour dependent on registry state at run time.
- **Treating a descriptor hash as a signature or attestation.** Rejected: no signer identity or key material exists, and P13/P16 own evidence and verification.
- **Introducing a Skill DSL, expression evaluator, or orchestration runtime now.** Rejected: implementation language and runtime technology are reserved for P18; linear typed steps cover the P14 scope.
- **Writing the validator as repository code (`.py`/`.js`).** Rejected: it would add product code and a language choice before P18, and would violate the existing no-product-code verifiers.
- **Vendoring an upstream meta-schema copy fetched from `json-schema.org`.** Not possible in Arena today (host BLOCKED), and unnecessary while a validator can perform the check itself.

## Consequences

- Positive: Tools and Skills become declarative, version-pinned, hash-checked, limit-bounded, and per-step authorized; the acceptance vectors make the three highest-risk behaviours (missing step authorization, hash mismatch, limit breach) machine-checkable without any runtime.
- Negative: P14 proves contract presence and schema validity, not the existence of a Tool runtime, sandbox, executor, or production behaviour. The remaining proof obligations belong to P15/P16 and to post-P18 implementation.
- Neutral: JSON Schema validation adds a test-only dependency; the repository itself stays language-free. Any later change of validator is a new ADR-level decision with new pinned hashes.

## Status

ACCEPTED — P14 Tool + Skill Contract is contracts-only. No Tool or Skill runtime, executor, registry, orchestration engine, DSL, package installation, system change, or implementation-language choice is authorized by this ADR.

P14 is not COMPLETE until: the approved validator is installed with pinned hashes and the schemas pass meta-schema and valid/invalid instance validation (DONE locally 2026-10-05); `tests/tool-skill.test.sh` passes fully (DONE: 40/40); `ops/verify/verify-tool-skill.sh` returns PASS, exit 0 (DONE: 17/17); CI runs both on the remote runner and the run is green (PENDING); and the roadmap records the completed state (pending the green run). Until then the roadmap marks P14 as in progress, never COMPLETE.

## References

- `docs/architecture/roadmap.md` — P14 scope and phase order
- `docs/architecture/adr/0011-baseline-reconciliation-and-phase-numbering.md` — D4 numbering, D5 implementation gate
- `docs/contracts/tool.md`, `skill.md`, `tool-schema.yaml`, `skill-schema.yaml`, `tool-skill-examples.yaml`, `tool-skill-acceptance-tests.yaml`
- `docs/contracts/{action,result,event,execution-authority,policy,capability-registry,agent-runtime}.md`
- `tests/tool-skill.test.sh`, `ops/verify/verify-tool-skill.sh`
