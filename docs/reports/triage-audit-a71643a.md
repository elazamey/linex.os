# LINEX.OS — تقرير فرز وتصنيف (Triage Audit)

> **الالتزام المقيس:** `a71643a` (رأس `main`، دمج PR #3) — قياس لقطة ثابتة، لا ادعاء حالة حيّة.
> **بيئة القياس:** Arena sandbox — Debian GNU/Linux 12 (bookworm) x86_64، النواة 6.1.158+،
> مستخدم `user` مع `sudo NOPASSWD` (سياسة نظام خارجية غير محكومة بالمستودع).
> **زمن القياس:** 2026-10-05 (UTC).
> **نوع التغيير:** مستندات فقط. لا كود منتج، لا تثبيت حزم، لا تعديل سياسة، لا تغيير في أي اختبار قائم.
> **القاعدة الحاكمة لهذا التقرير:** `docs/reports/README.md` (R1–R6) و`ADR 0011`.

هذا التقرير **فرز قبل أن يكون تحليلاً**: يصنّف كل أصل في المستودع إلى حاوية واحدة واضحة،
ويقرن كل رقم بالأمر الذي أنتجه (R1)، ويفصل حالة المستودع عن حالة البيئة عن حالة CI البعيد (R3).

الملف المرافق: `docs/reports/triage-register-a71643a.csv` — سجل قابل للترشيح والترتيب (105 صفوف).

---

## 1. الملخص التنفيذي

| السؤال | الجواب المقيس | الدليل |
|---|---|---|
| هل المستودع سليم ومتسق؟ | **نعم** — 9 مجموعات، 255/256 نجحت | `bash <كل مجموعة>` → `TOTAL: 256 PASSED: 255 FAILED: 1` |
| هل الحالة المُعلنة في الوثائق صادقة؟ | **نعم في الجوهر، لا في التفاصيل** — الفشل الوحيد مُعلن ولم يُجمَّل | `./scripts/doctor.sh` → `exit 3`, `FOUNDATION STATUS: FAIL` |
| هل البيئة الحالية كاملة؟ | **لا** — نقص أداة واحدة + حجب شبكي | `command -v pkg-config` → غائب؛ `curl -I https://deb.debian.org` → exit 35 |
| هل CI البعيد أخضر؟ | **نعم** عند `a71643a` و`d349f92` | `gh run list` → `37246010719 success` و`37233042304 success` |
| هل يوجد منتج (كود)؟ | **لا، إطلاقاً** — 0 ملف | `find . -name '*.py' -o -name '*.c' -o -name '*.ts' -o -name '*.go' -o -name '*.rs' -o -name '*.js'` → 0 |
| ما أكبر مخاطرة حقيقية؟ | انحراف السياسة عن الكود وضعف الفحص الدلالي | القسم 5: W1، W4، W6 |

**الحكم بجملة واحدة:** هذا مستودع **تأسيس وحُكم (governance) ناضج ومُختبَر بصدق**، لكن قيمته
الحالية **وثائقية وإجرائية بالكامل**؛ "COMPLETE" فيه تعني *«العقد مكتوب ومتسق ومفحوص آلياً»*
ولا تعني *«مُنفَّذ»* — وهذا مُعلن صراحةً في `README.md` و`docs/architecture/roadmap.md`.

**أهم ثلاث نتائج جديدة كشفها هذا الفرز (غير مذكورة في وثائق المشروع):**

1. **انحراف سرد الحزم:** البوابة تسمح بـ20 حزمة، ووثيقة السياسة `ops/security/privilege-policy.md` §5 تسرد 15 فقط. الفرق: `gcc`، `g++`، `make`، `pkg-config`، `build-essential`. لا يوجد أي فحص يكتشف هذا الانحراف (W1).
2. **CI يتجاوز البوابة:** `.github/workflows/ci.yml` (خطوة CI-H4) يثبّت أساس P3 بـ`sudo apt-get install` مباشرة، أي أن خط الأنابيب الرسمي لا يمر عبر `privilege-gate.sh` الذي يدّعي المشروع أنه المسار الوحيد للتثبيت (W2).
3. **طبقة PowerShell وهم قابل للتحقق:** 4 ملفات `.ps1` (516 سطراً) لا تُنفَّذ ولا تُفحَص نحوياً في أي بيئة، لأن `pwsh` محجوب — أي أن مخرجات P1/P4 الخاصة بـPowerShell هي `NOT VERIFIED` فعلياً رغم وجودها في المستودع (W3).

---

## 2. لوحة القياس (كل رقم مع أمره)

### 2.1 مجموعات الاختبار التسع

```
$ bash ops/security/tests/privilege-policy.test.sh          → TOTAL 28  PASSED 28  FAILED 0  exit 0
$ bash ops/linux/tests/toolchain.test.sh                    → TOTAL 44  PASSED 43  FAILED 1  exit 1
$ bash ops/powershell/tests/powershell-install.test.sh      → TOTAL 18  PASSED 18  FAILED 0  exit 0
$ bash ops/security/tests/agent-contract.test.sh            → TOTAL 15  PASSED 15  FAILED 0  exit 0
$ bash tests/architecture.test.sh                           → TOTAL 15  PASSED 15  FAILED 0  exit 0
$ bash tests/contracts.test.sh                              → TOTAL 15  PASSED 15  FAILED 0  exit 0
$ bash tests/execution-authority.test.sh                    → TOTAL 36  PASSED 36  FAILED 0  exit 0
$ bash tests/policy.test.sh                                 → TOTAL 40  PASSED 40  FAILED 0  exit 0
$ bash tests/capability.test.sh                             → TOTAL 45  PASSED 45  FAILED 0  exit 0
                                                              ────────────────────────────────────
                                                              TOTAL 256 PASSED 255 FAILED 1
```

الفشل الوحيد: `version succeeds: pkg-config → FAIL (MISSING)`.

### 2.2 سكربتات التحقق الخمسة

```
$ bash ops/verify/verify-architecture.sh        → 37  PASS / 0 FAIL   exit 0
$ bash ops/verify/verify-contracts.sh           → 46  PASS / 0 FAIL   exit 0
$ bash ops/verify/verify-execution-authority.sh → 67  PASS / 0 FAIL   exit 0
$ bash ops/verify/verify-policy.sh              → 104 PASS / 0 FAIL   exit 0
$ bash ops/verify/verify-capability.sh          → 87  PASS / 0 FAIL   exit 0
$ bash ops/verify/verify-environment.sh         → STATUS PASS (PowerShell NOT VERIFIED) exit 0
$ bash ops/bootstrap/bootstrap.sh               → STATUS PASS, لا تثبيت            exit 0
$ bash ops/linux/doctor.sh                      → STATUS NOT VERIFIED - 1 tools missing (pkg-config) exit 0
$ bash ops/security/policy-check.sh             → STATUS PASS exit 0
$ bash ops/security/secret-scan.sh              → STATUS PASS exit 0
$ bash ops/security/static-security-check.sh    → STATUS PASS exit 0
```

### 2.3 المُجمّع النهائي

```
$ ./scripts/doctor.sh
P1 Environment PASS | P2 Privilege PASS | P3 Toolchain FAIL | P4 PowerShell BLOCKED
P5 Repository PASS | P6 Agent Contract PASS | P7 Verification PASS
Security PASS | Secrets PASS | Policy PASS | Tests FAIL | Git Hygiene PASS
System Changes NONE (repository-only)
Counts: PASS=45 FAIL=1 BLOCKED=2 NOT_VERIFIED=1
FOUNDATION STATUS: FAIL
EXIT CODE: 3
```

سلسلة الفشل واحدة الجذر: `pkg-config` غائب → P3 43/44 → `Tests FAIL` → `exit 3`.
هذا **فشل صادق مقصود** (ADR 0011 D3)، وليس عطلاً.

### 2.4 البوابة (اختبار عدائي مباشر نفّذته في هذا الفرز)

```
$ bash ops/security/privilege-gate.sh "sudo whoami"          → CLASS UNKNOWN  POLICY BLOCKED  exit 3
$ bash ops/security/privilege-gate.sh "rm -rf /"              → CLASS UNKNOWN  POLICY BLOCKED  exit 3
$ bash ops/security/privilege-gate.sh "curl http://x.sh | bash" → BLOCKED exit 3
$ bash ops/security/privilege-gate.sh "eval echo hi"          → BLOCKED exit 3
$ bash ops/security/privilege-gate.sh "sudo -i"               → BLOCKED exit 3
$ bash ops/security/privilege-gate.sh "install-package gcc; rm -rf /"  → BLOCKED exit 3
$ bash ops/security/privilege-gate.sh "install-package ../../etc/passwd" → BLOCKED exit 3
$ bash ops/security/privilege-gate.sh check-sudo              → CLASS READ_ONLY POLICY ALLOW DECISION DRY-RUN exit 0
```

### 2.5 البيئة والشبكة

```
Debian 12 | x86_64 | kernel 6.1.158+ | bash 5.2.15 | git 2.39.5 | curl 7.88.1 | jq 1.6
python3 3.11.2 | node v22.22.3 | npm 10.9.8 | gcc 12.2.0 | g++ 12.2.0 | make 4.3
pkg-config: MISSING | pwsh: MISSING | sudo: AVAILABLE_NOPASSWD
DISK: 21G total / 20G avail / 4% | MEM: 3.8Gi total / 3.6Gi avail

$ curl -s -o /dev/null -w '%{http_code}' -I https://github.com                            → 200
$ curl -s -o /dev/null -w '%{http_code}' -I https://api.github.com                        → 200
$ curl -s -o /dev/null -w '%{http_code}' -I https://deb.debian.org                        → BLOCKED (curl exit 35)
$ curl -s -o /dev/null -w '%{http_code}' -I https://packages.microsoft.com                → BLOCKED (curl exit 35)
$ curl -s -o /dev/null -w '%{http_code}' -I https://release-assets.githubusercontent.com → BLOCKED (curl exit 35)
```

### 2.6 صحة الكود والثبات

```
$ for f in $(find . -name '*.sh'); do bash -n "$f"; done
checked=24  syntax_failures=0                      # لا خطأ نحوي واحد

$ ./scripts/doctor.sh > d1.txt ; ./scripts/doctor.sh > d2.txt ; diff d1.txt d2.txt
94c94
< Disk → PASS (20207700KB available)
---
> Disk → PASS (20207692KB available)               # الاختلاف الوحيد خارج الطابع الزمني
```

### 2.7 حالة Git/CI البعيد (عبر `gh` — وليس من البيئة المحلية)

```
$ git ls-remote origin main        → a71643aba21202a75021b45757d774ca2cc27aaa (= HEAD المحلي)
$ gh run view 37233042304 --json conclusion,headSha,status
  → {"conclusion":"success","headSha":"d349f92...","status":"completed","event":"push"}
$ gh run list --limit 5 → 37246010719 (main, push) success
                          37249355578 / 37249367785 / 37249771959 / 37249775566 (فرع PR #4) success
$ gh pr list --state all → #1 MERGED | #2 MERGED | #3 MERGED | #4 OPEN
```

**تنبيه مهم:** الاستنساخ المحلي **ضحل** (`git rev-parse --is-shallow-repository` → `true`، كائن واحد مُعبّأ)،
لذلك لا يمكن التحقق محلياً من أي ادعاء تاريخي (مثل `d349f92`)؛ التحقق التاريخي في هذا التقرير جاء من
واجهة GitHub عبر `gh`، وهذا مسجّل كقيد في القسم 8.

**PR #4 مفتوح** (`Phase 0: reconcile baseline evidence and active roadmap`، 24 ملفاً، +701/−350،
إضافات أبرزها `docs/reports/baseline-audit-a71643a.md`). لم يُدمج بعد، لذا كل ما في هذا التقرير
يقيس `main` عند `a71643a` كما هو. هذا التقرير لا يعدّل أي ملف لمسه PR #4 — ملفاته جديدة كلياً.

---

## 3. الفرز الكامل (Triage)

السجل الكامل القابل للترشيح: `docs/reports/triage-register-a71643a.csv` (105 صفوف، أعمدة:
`area, artifact, kind, bucket, status, auto_check, evidence, weakness_id, note_ar`).

### الحاوية A — مكتمل ومُتحقَّق آلياً (77 أصلاً)

كل ما يوجد له فحص آلي عابر في هذه البيئة. أمثلة تمثيلية:

| العنصر | الفاحص | الدليل |
|---|---|---|
| `ops/security/privilege-gate.sh` | `privilege-policy.test.sh` (سلوكي) | 28/28 |
| `docs/contracts/*.md` (20 ملفاً) | `policy/contracts/execution-authority/capability` | 40 + 15 + 36 + 45 نجاح |
| 14 وثيقة معمارية + 10 ADRs | `architecture.test.sh` + `verify-architecture.sh` | 15/15 + 37/0 |
| `scripts/doctor.sh` | CI Job 6 + تشغيل محلي | exit 3 (متوقع) |
| `.github/workflows/ci.yml` | تشغيل بعيد | 6/6 وظائف success |
| `AGENTS.md` / `ARENA.md` | `agent-contract.test.sh` | 15/15 |

> **تحذير على هذه الحاوية:** «مُتحقَّق آلياً» هنا تعني في الأغلب **وجود نص بعينه** (grep)، لا
> تحقّقاً دلالياً من الاتساق. التفصيل في W4.

### الحاوية B — مكتمل مكتوباً لكن بلا فحص آلي (9 أصول)

| العنصر | لماذا لا فحص |
|---|---|
| `docs/vision.md`, `docs/security.md`, `docs/development.md` | لا فاحص يقرأ محتواها |
| `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE`, `.gitignore` (محتوى) | وجود فقط |
| `config/README.md` | وجود فقط؛ ويشير إلى ملف غير موجود |
| `README.md` | لا فحص لمحتواه ولا لشهادة الحالة في ذيله |
| `docs/architecture/adr/0011-*.md` | **لا مرجع له في أي فاحص** — وهو سلطة الحالة نفسها (W5) |
| `verification-summary.txt` | لقطة يدوية عند `d349f92` (R6) |
| `docs/reports/baseline-audit-d349f92.md` | لقطة قياس، بلا فحص (طبيعي للأدلة) |

### الحاوية C — موجود لكنه غير مُنفَّذ في أي بيئة (5 أصول)

| العنصر | الحجم | الحالة |
|---|---|---|
| `scripts/doctor.ps1` | 4 ملفات `.ps1` = **516 سطراً** | `command -v pwsh` → MISSING؛ لا خطوة تحليل نحوي في `ci.yml` |
| `ops/bootstrap/bootstrap.ps1` | | نفس السبب |
| `ops/verify/verify-environment.ps1` | | نفس السبب |
| `ops/powershell/doctor.ps1` | | نفس السبب |
| `.github/workflows/ci-debug.yml` | 1 وظيفة | `workflow_dispatch` فقط؛ `gh run list` → لا تشغيل مسجّل |

هذه الحاوية هي **أكبر فجوة «تحقّق»** في المستودع: كود مكتوب لا يمكن إثبات حتى سلامته النحوية.

### الحاوية D — محجوب بيئياً (3 أصول)

| العنصر | المحجوز | الدليل | التصنيف الصحيح |
|---|---|---|---|
| PowerShell 7.6.6 (P4) | `packages.microsoft.com` و`release-assets.githubusercontent.com` | curl exit 35 | `BLOCKED` — منطق التثبيت مُختبَر 18/18 |
| `pkg-config` (P3) | مرايا apt غير قابلة للوصول | `apt-get -s install pkg-config` → Unable to locate | `ENVIRONMENT-DEPENDENT` |
| سجلات Runner | مضيف GitHub للأرشيف غير قابل للوصول | `gh run view --log` → EOF | `NOT VERIFIED` — الأحكام بمستوى الوظيفة فقط |

### الحاوية E — لم يبدأ (8 أصول)

`P13` عقد وقت تشغيل الوكيل · `P14` عقد الأدوات والمهارات · `P15` الذاكرة/الحالة/الأحداث ·
`P16` محرّك التحقق · `P17` عقد MCP · `P18` اختيار التقنية · ما بعده: الخدمات/API/UI/الرصد ·
وأخيراً **كود المنتج: 0 ملف**.

### الحاوية F — متقاعد (1 أصل)

`P14 Control Plane MVP` (حزمة `control/`، CLI، 181 اختبار pytest، git bundle) — **لا أثر له**
في المستودع ولا على GitHub؛ موسوم كمُتقاعد في ADR 0011. هذا **تصحيح ذاتي موثّق** يُحسب للمشروع.

---

## 4. نقاط القوة (بالدليل)

| # | القوة | الدليل المقيس |
|---|---|---|
| S1 | **اختبار سلوكي حقيقي للبوابة، لا توثيق فقط** | `privilege-policy.test.sh` ينفّذ البوابة فعلاً بحجج عدائية (TEST 2–8c: فعل مجهول، `rm -rf /`، `curl;rm -rf /`، `curl&&echo hacked`، `curl$(whoami)`، `` curl`whoami` ``، `/etc/passwd`، `../../etc`)، وأضفت 7 أوامر عدائية يدوياً (`sudo whoami`، `sudo -i`، `eval echo hi` …) → كلها `BLOCKED exit 3`، 28/28 |
| S2 | **فشل صادق بدل تجميل النتائج** | `doctor.sh` يخرج بـ`exit 3` ويعلن `FOUNDATION STATUS: FAIL` بسبب أداة ناقصة واحدة، والإصلاح مُرجأ عن قصد إلى طبقة الأدلة (ADR 0011 D3) |
| S3 | **فصل البيئة عن الحكم** | مفردات `ARENA_*` مقابل `REMOTE_CI_*`، وتصنيف `ENVIRONMENT-DEPENDENT` بدل `VERIFIED`؛ طُبِّق فعلاً في `toolchain-manifest.txt` |
| S4 | **سلطة مرحلة واحدة** | `docs/architecture/roadmap.md` هو السجل المرجّح بعد ADR 0011، مع سجل تسميات متقاعدة ومُعلَنة |
| S5 | **اتفاقية أدلة صارمة** | `docs/reports/README.md` (R1–R6): كل رقم مع أمره، منع القياس الذاتي، التقارير append-only |
| S6 | **تصلّب CI جيد** | `permissions: contents: read`، تثبيت الأكشن بـSHA `3d3c42e5…` (v7.0.1)، لا `pull_request_target`، لا أسرار، مسح أسرار شامل بلا استثناء مجلدات |
| S7 | **اختبارات تكامل لا وجود فقط** | `toolchain.test.sh` يترجم ويشغّل C وC++ فعلياً (TEST 11/12) ويتحقق من الإصدارات |
| S8 | **مسح أمني بحدّية موثّقة** | `secret-scan.sh` (مستودع كامل) و`static-security-check.sh` مع «Test/Policy Boundary» مفسّرة سطراً بسطر |
| S9 | **مُجمّع شبه حتمي** | تشغيلان متتاليان مختلفان في سطر `Disk` فقط (20207700 مقابل 20207692 KB) |
| S10 | **أدلة موحّدة بلا أسرار** | كل قرار بوابة يطبع ACTION/CLASS/POLICY/DECISION/EXECUTION/EXIT_CODE/TIMESTAMP/SYSTEM_SUDO/PROJECT_POLICY |
| S11 | **حاجز ضد البناء غير المحكوم** | 0 سطر كود منتج + قاعدة صريحة: لا لغة تنفيذ قبل P18، ولا مسار `LLM → Shell` مباشر |
| S12 | **إعادة إنتاجية في بيئة نظيفة** | `bootstrap.sh` و`verify-environment.sh` و`doctor.sh` تعمل بلا أي تغيير نظام |
| S13 | **نزاهة مع الحاجز الخارجي** | P4 موثّق `BLOCKED` بأدلة شبكية، مع رفض صريح لأي مرآة أو مصدر غير رسمي |
| S14 | **نظافة Git** | فرع لكل جلسة + PR + لا force push + لا كتابة على `main` مباشرة؛ `git status --short` نظيف عند القياس |

---

## 5. نقاط الضعف (مرتبة بالأثر)

### W1 — انحراف سرد الحزم بين السياسة والكود · **عالية** · مُثبت

- **الكود:** `ops/security/privilege-gate.sh` → `ALLOWED_PACKAGES` = **20** حزمة (تشمل `gcc`، `g++`، `make`، `pkg-config`، `build-essential`).
- **الوثيقة:** `ops/security/privilege-policy.md` §5 «Package Allowlist (P2)» = **15** حزمة، وتنصّ: *«No package outside this list is allowed in P2»*.
- **الفرق:** 5 حزم مُوسَّعة في الكود بلا تحديث للوثيقة الحاكمة.
- **الأثر:** الوثيقة التي يُفترض أن تكون مرجع المراجعة تُخالف السلوك الفعلي؛ مدقّق خارجي سيعتمد السرد الأدقّ فيُخطئ.
- **العلاج:** إمّا تحديث §5 (مع قسم صريح لتوسيع P3/P4) أو تضييق الكود — ثم إضافة فحص تطابق آلي.

### W2 — CI يثبّت الحزم خارج البوابة · **عالية** · مُثبت

- **الدليل:** `.github/workflows/ci.yml` (خطوة «Ensure P3 toolchain baseline»):
  `sudo apt-get update -y` ثم `sudo apt-get install -y --no-install-recommends $P3_PKGS` مباشرة.
- **الأثر:** المشروع يبيع نموذج «لا تثبيت مُمتاز خارج `privilege-gate.sh`»، لكن خط أنابيبه الرسمي لا يمر بها.
  كما أن الوظيفة **تثبّت ثم تتحقق**، فتنجح دائماً بالسبب الذي وُجدت لقياسه (Tautology معلنة في CI-H4).
- **العلاج:** تمرير المرور عبر `install-base.sh`/البوابة، أو تدوين استثناء CI صريحاً في `privilege-policy.md` كمستوى مسموح.

### W3 — طبقة PowerShell غير قابلة للتحقق · **متوسطة‑عالية** · مُثبت

- 4 ملفات `.ps1` (516 سطراً) لا تُنفَّذ ولا تُفحَص نحوياً؛ `command -v pwsh` → MISSING، و`ci.yml`
  يقتصر على تسجيل وجود `pwsh` كدليل عند فشل P4. لا خطوة `pwsh -NoProfile -Command` ولا محلل نحوي.
- **الأثر:** مخرجات P1/P4 «PowerShell» في الجداول تبدو مغطّاة، وهي فعلياً `NOT VERIFIED`.
- **العلاج:** خطوة تحليل نحوي/`PSScriptAnalyzer` على الـrunner (متاح هناك حتى لو كان محجوباً هنا).

### W4 — «مُتحقَّق آلياً» = فحص وجود نص · **متوسطة** · مُثبت بأرقام

- إحصاء الفحوصات في مجموعات العقود: `agent-contract` 12 (9 نصية) · `architecture` 14 (12) ·
  `contracts` 15 (14) · `execution-authority` 36 (33) · `policy` 40 (39) · `capability` 45 (43).
  المجموع: **150 من 162 فحصاً (≈93%) تحقق من وجود نص** بـ`grep`، لا من دلالة العقد.
- **الأثر:** 151/151 نجاحاً في مجموعات P8–P12 يثبت التماسك النصي، لا الاتساق الدلالي بين العقود.
- **العلاج:** اختبارات تقاطعية بسيطة: استخراج معرفات (`CAP_*`، أسماء الأفعال، قيم الحالة) من وثيقة
  ومطابقتها مع الوثائق الأخرى ومع كود البوابة (W1 مثال حي على ما سيفوته هذا الفحص).

### W5 — فجوة الحكم الذاتي: ADR 0011 غير مفحوصة · **متوسطة** · مُثبت

- `grep -rl '0011' tests/ ops/verify/ ops/*/tests/` → **0** إشارات فاحصة (تظهر إشارات `ADR 0011` فقط داخل تعليقات تفسيرية في `ci.yml` و`ci-debug.yml` و`powershell-install.test.sh`،
  تفسيري وفي اختبار P4). الوثيقة التي تُعرّف سلطة الحالة ومفردات التصنيف (`VERIFIED` مقابل
  `ENVIRONMENT-DEPENDENT`) وقاعدة القياس ليست محمية بأي فحص.
- **الأثر:** يمكن كسر قواعد الأدلة دون أن يشتكي أي فاحص.

### W6 — ادعاءات حالة متقادمة داخل «المجمَّد» · **متوسطة** · مُثبت

- `docs/architecture.md:884` و`docs/architecture/frozen-baseline.md:10,207` تنصّ:
  *«REMOTE CI = NOT VERIFIED — branch not pushed, main still at 768bf39»*.
- الحقيقة المقيسة الآن: `gh run view 37233042304` → success، و`main` = `a71643a`، وPR #1–#3 مدموجة.
- **الأثر:** مرجع «المجمَّد» يحمل تناقضاً دائماً مع الحالة المُتحقَّقة؛ لا فاحص يكشف النص المتقادم.
- **العلاج:** تصحيح النص + فحص نمطي يرفض وجود ادعاءات حالة قديمة غير موسومة كتاريخ.

### W7 — شهادة حالة قديمة في `README.md` · **منخفضة** · مُثبت

- الذيل: *«Status: P5 Repository Foundation … Next: P6 Agent Contract»* بينما السجل المرجّح يقول `P13 NEXT`.
- **الأثر:** أول ملف يقرأه الزائر يعطي انطباعاً بمرحلتين متأخرتين؛ لا فحص لمحتوى README.

### W8 — `install-base.sh`: الافتراضي الفعلي تنفيذ لا استعراض · **متوسطة** · مُثبت سلوكياً

- السكربت يبرّر بأنه «DRY-RUN → GATE → INSTALL»، لكنه يستدعي البوابة بـ`--execute` مباشرة في السطر 229
  دون أي علم `--dry-run` أو تأكيد.
- **الدليل (نُفِّذ في هذا الفرز):** `bash ops/linux/install-base.sh` → `apt-get update` فشل شبكياً،
  ثم `Executing Gate --execute for package: pkg-config` → `sudo apt-get install -y pkg-config` →
  `E: Unable to locate package pkg-config` → `exit 5`. **لم تُثبَّت أي حزمة** (`dpkg-query -s pkg-config`
  → not installed)، لكن المحاولة كانت حقيقية وامتيازية.
- **الأثر:** مبدأ «DRY-RUN افتراضياً» سليم في البوابة، لكن الأمر المركّب الذي يوصي به المشروع
  (`install-base.sh`) يتجاوزه؛ أي مشغّل يستدعي أمر التثبيت يعدّل النظام فوراً.
- **العلاج:** علم `--execute`/`--dry-run` صريح في السكربت، أو حدّ أدنى: تأكيد تفاعلي عند غياب TTY.

### W9 — مخرج المُجمّع ليس متطابقاً بايت-بايت · **منخفضة**

- `diff` بين تشغيلين: سطر واحد فقط `Disk (20207700KB)` مقابل `(20207692KB)`. ادعاء «deterministic»
  صحيح لترتيب الصفوف (CI-H6) لا لتطابق المخرج. يُستحسن وسم القيمة كقياس لحظي.

### W10 — مراجع معلّقة · **منخفضة**

- `config/README.md` يذكر `config/allowed-packages.json` كمستقبلي → غير موجود (والتوثيق يقرّ بذلك).
- `docs/reports/baseline-audit-d349f92.md` يذكر `HANDOFF.md`، `docs/reports/P14-pr-body.md`، `*.bundle`
  **كنفي أدلة** على أنها غير موجودة — استخدام سليم، لكنه ضجيج يحتاج قارئاً منتبهاً.

### W11 — حدّية فحص `eval` · **منخفضة**

- `static-security-check.sh` يبحث عن `eval` **كأمر تنفيذي في بداية السطر** داخل `ops/` و`scripts/` فقط.
- مجموعات الاختبار في `tests/` تستخدم `eval "$cmd"` في الإطار (`run_check`)، مسموحاً بموجب
  «Test/Policy Boundary». الخطر: إذا انتقل منطق حقيقي (لا بيانات اختبار) إلى `tests/`، فلن يفحصه المسح.
- **العلاج:** فحص إضافي يعتمد على تحليل بنيوي (لا موضع السطر) بدل الاعتماد على الموقع.

### W12 — الاستنساخ ضحل · **منخفضة (قيود قياس)**

- `git rev-parse --is-shallow-repository` → `true`؛ سجل واحد وكائن واحد مُعبّأ (117 كائناً).
- **الأثر:** لا تحقق محلي من ادعاءات تاريخية (مثل `d349f92`، PR #1/#2)، وتحايلٌ إلزامي على GitHub API.

### W13 — الترخيص معلّق · **متوسطة قانونياً**

- `LICENSE` = «LICENSE PENDING OWNER DECISION … All rights reserved until owner decides».
- **الأثر:** لا يمكن لأي طرف خارجي استخدام أو إسهام أو إعادة استخدام بثقة قانونية؛ وهذا يعوق هدف P5 (تأسيس مستودع).

### W14 — غياب طبقة تحقق أدلة إضافية · **منخفضة (معلنة كفجوة)**

- لا checksums/توقيعات لأي ملف، ولا قياس تغطية للفحوص، ولا فحص أن «كل ملف سياسة مذكور في اختبار».
  هذه موثّقة كـ«تفاصيل سلسلة توريد مستقبلية» في `docs/architecture/extensibility.md`، لكنها فجوة قائمة اليوم.

---

## 6. ما اكتمل وما لم يكتمل

**تعريف «COMPLETE» في هذا المستودع (نقلاً عن `docs/architecture/roadmap.md`):**
> «the phase's documents exist, are self-consistent and are machine-checked by a shipped suite that passes — it never means "implemented"».

| المرحلة | الحالة المقيسة | ما يعنيه فعلاً |
|---|---|---|
| P0 اكتشاف البيئة | ✅ مُثبت | لقطة بيئة مطابقة للوثيقة (تحققت من كل قيمة) |
| P1 التأسيس | ✅ مُثبت (bash) / ⚠️ PowerShell غير مُنفَّذ | `bootstrap.sh`, `verify-environment.sh`, `doctor.sh` تعمل |
| P2 سياسة الامتياز والبوابة | ✅ مُثبت سلوكياً | 28/28 اختباراً حقيقيّاً + 8 أوامر عدائية إضافية منّي → BLOCKED |
| P3 أدوات لينكس | ⚠️ 43/44 | `pkg-config` بيئي؛ 44/44 في CI |
| P4 PowerShell 7 | ⛔ محجوب | المنطق 18/18، التنزيل محجوب، 4 ملفات ps1 غير مُنفَّذة |
| P5 أساس المستودع | ✅ مُثبت (وجود) | لكن محتوى نصف الوثائق غير مفحوص، والترخيص معلّق |
| P6 عقد الوكيل | ✅ مُثبت | 15/15 (نصي) |
| P7 الطبيب وتقوية CI | ✅ مُثبت | 6/6 وظائف CI بعيدة |
| P8 المعمارية | ✅ مُثبت + مجمَّد | 14 وثيقة + ADRs 0001–0006؛ يحمل ادعاءات حالة قديمة (W6) |
| P9–P12 العقود | ✅ مكتملة (عقود فقط) | 151/151 فحصاً؛ 93% منها نصي (W4) |
| CI-H1…CI-H6 | ✅ مكتملة | تسميات متقاعدة مُصححة، لا «P13 FIX» |
| P13 عقد وقت تشغيل الوكيل | ⬜ لم يبدأ | التالي |
| P14–P17 (أدوات، ذاكرة، تحقق، MCP) | ⬜ لم يبدأ | عقود فقط عند التنفيذ |
| P18 اختيار التقنية | ⬜ لم يبدأ | هنا تُختار لغة التنفيذ |
| كود المنتج | ⬜ 0 ملف | مقصود حتى P18 |

**ما اكتمل حقاً:** الأساس الإجرائي (P1–P2)، سلسلة العقود (P8–P12)، حكم CI والأمان (P7).
**ما لم يكتمل:** كل ما يلمسه المستخدم (API/UI/خدمات/رصد)، وكل تنفيذ فعلي، وطبقة PowerShell، والترخيص.

---

## 7. خطة تصحيح مرتّبة بالأولوية

| الأولوية | الإجراء | الملف المستهدف | يزيل |
|---|---|---|---|
| P1 | فحص تطابق `ALLOWED_PACKAGES` بين الكود والوثيقة | `ops/security/policy-check.sh` أو `verify-policy.sh` | W1 |
| P1 | تحديث سرد §5 (أو تضييق الكود) وتسجيل توسيع P3/P4 صراحةً | `ops/security/privilege-policy.md` | W1 |
| P1 | تصحيح ادعاءات `REMOTE CI` المتقادمة | `docs/architecture.md`, `frozen-baseline.md` | W6, W7 |
| P1 | تغطية ADR 0011 بفحص (المفردات + قواعد R1–R6 + قائمة المراحل) | `tests/` مجموعة جديدة أو توسيع `architecture.test.sh` | W5 |
| P2 | توحيد مسار تثبيت CI (بوابة أو استثناء موثّق) | `.github/workflows/ci.yml`, `privilege-policy.md` | W2 |
| P2 | خطوة تحقق نحوي PowerShell على الـrunner | `.github/workflows/ci.yml` | W3 |
| P2 | علم `--execute`/`--dry-run` صريح | `ops/linux/install-base.sh` | W8 |
| P2 | فحص تقاطعي دلالي للمعرفات عبر العقود | `tests/` | W4 |
| P2 | حسم الترخيص | `LICENSE` | W13 |
| P3 | وسم `Disk` كقياس لحظي أو تثبيته | `scripts/doctor.sh` | W9 |
| P3 | فحص `eval` بنيوي لا موضعي | `ops/security/static-security-check.sh` | W11 |
| P3 | تنظيف المراجع المعلّقة | `config/README.md` | W10 |

---

## 8. حدود هذا التقرير والإفصاح

**إفصاح عن تغييرات النظام:** لم يُطبَّق أي تثبيت أو تعديل نظام. الاستثناء الوحيد المسجّل:
تشغيل `bash ops/linux/install-base.sh` بغرض استعراض المسار، فحاول تثبيت `pkg-config` عبر البوابة
بـ`--execute`؛ فشل عند الشبكة (`E: Unable to locate package pkg-config`) وانتهى بـ`exit 5`.
التحقق اللاحق: `command -v pkg-config` → MISSING، `dpkg-query -s pkg-config` → not installed،
`sudo -n true` → ما زال متاحاً كما كان. **لا تغيير صافٍ في النظام.**

**حدود القياس:**
1. استنساخ ضحل → لا تحقق محلي من التاريخ؛ ما يتعلق بـ`d349f92` وPR #1–#3 جاء من `gh` (GitHub API) وهو `NOT VERIFIED` بمستوى «جسم السجل» (ADR 0011 D7).
2. بيئة واحدة (Arena) → كل حكم هنا `ARENA`-scoped؛ النتائج قد تختلف على runner أو على جهاز آخر (R3).
3. لا `pwsh` → كل ما يتعلق بـPowerShell هو `NOT VERIFIED` تنفيذياً.
4. لا مرآة apt → تعذّر التحقق من قابلية التثبيت الفعلية للحزم المسموح بها.
5. PR #4 مفتوح ولم يُدمج → قد تُصلح بعض بنود القسم 5 عند دمجه؛ القياس هنا يقيس `main` عند `a71643a` فقط.
6. لم يُجرَ أي اختبار حمل/أداء/اختراق؛ المستودع لا يحتوي كوداً قابلاً لذلك بعد.

---

## 9. المراجع

- `docs/reports/README.md` — اتفاقية الأدلة R1–R6 (حاكمة على هذا التقرير)
- `docs/architecture/adr/0011-baseline-reconciliation-and-phase-numbering.md` — سلطة الحالة والترقيم
- `docs/architecture/roadmap.md` — السجل المرجّح للمراحل
- `docs/reports/baseline-audit-d349f92.md` — القياس السابق المرجعي
- `ops/security/privilege-policy.md` — سياسة الامتياز (موضع W1)
- `ops/security/privilege-gate.sh` — البوابة (السلوك المقيس في 2.4)
- `docs/reports/triage-register-a71643a.csv` — سجل الفرز الكامل (105 صفوف)
- `AGENTS.md` / `ARENA.md` — عقد الوكيل وقواعد Git

---

**خلاصة التصنيف:** 77 أصلاً مكتملاً ومُتحقَّقاً آلياً · 9 مكتملة بلا فحص · 5 موجودة وغير مُنفَّذة ·
2 محجوبان بيئياً · 8 لم تبدأ · 1 متقاعد · 14 نقطة ضعف موثّقة بالأدلة (منها 3 عالية الأثر).
