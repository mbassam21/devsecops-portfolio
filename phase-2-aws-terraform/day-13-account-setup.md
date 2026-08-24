# Day 13 — AWS Account Foundations & Detection

**Region:** `eu-central-1` (Frankfurt) · **Account plan:** PAID, 0 credits remaining
**Tag convention:** `project=devsecops90` on all resources

## Security thread
**Detection before infrastructure.** All three services only see forward — enable
them after building and they can tell you nothing about how anything got that way.
The Day-1 lesson at a new layer: *you cannot detect drift from a baseline you never
recorded.*

---

## 1. What an AWS account is

An account is a **self-contained building**: everything built inside is isolated
from other accounts unless a door is deliberately installed, and it is a single
billing boundary. That is why the programme requires a dedicated learning account —
a mistake in a shared building doesn't stay in its lane.

Account creation produces one identity that **owns the building outright**: the
**root user**.

> **What makes root different from any other admin:** every other identity can be
> restricted by policy. **Root cannot.** There is no rule that can be written to
> stop root doing anything, including closing the account. Root is *the deed to the
> building, not a key to the front door* — it goes in a safe and is not carried
> around.

Since *what root can do* cannot be limited, the only available lever is **making it
hard to get into**.

---

## 2. Root secured — two MFA devices

A password can be stolen without the owner noticing: phished, reused from a breach,
read off a note. The thief has a copy and the original still works, so nothing looks
wrong. A second factor fixes this only if it **cannot be copied remotely**.

| Device | Type | Registered |
|---|---|---|
| iPhone passkey | `u2f/root/iPhone-*` | 2026-08-14 |
| Google Authenticator | `mfa/GoogleAuth` | 2026-08-21 |

Both tested by signing out and back in.

### Why the passkey is the stronger factor
A six-digit code is **just a number — it doesn't know which website it's typed
into.** An attacker proxies a fake login page, relays the password *and* the code to
the real AWS in real time, and is in. The victim did everything correctly.

A passkey is a secret in the phone's secure chip that never leaves the device. When
a site asks it to authenticate, **the phone checks which domain is asking** and
refuses anything that isn't the real one. Nothing is typed, so there is nothing to
relay.

**Term: phishing-resistant MFA.** The passkey knows where it's being used; a code
does not.

### Recovery — and its dependency chain
Eight MFA devices are permitted on root; **two are registered so that losing one is
an annoyance rather than an incident.** Losing sole access to an identity nobody can
reset means a slow AWS support recovery process.

> **Documented dependency:** the Google Authenticator seed is backed up to Google
> Drive, so a lost phone is recoverable by signing in on a new device. This makes
> **AWS root access dependent on Google account security** — an accepted trade
> (lockout risk exchanged for a new dependency), but it means the Google account is
> now load-bearing and must be protected to the same standard.
>
> **Principle: a recovery path is only as strong as everything it depends on.** Map
> the whole chain, not just the last link.

---

## 3. Working identity

Doing daily work as root means one bad afternoon — stolen laptop, open session,
malicious dependency reading credentials — hands over the deed, with no damage
limitation possible.

| Property | IAM user (`devsecops90`) | Root |
|---|---|---|
| Can be restricted by policy | **Yes** | **No** |
| Can be deleted / disabled | **Yes** | **No** |
| Credentials revocable | **Yes** | Effectively no |

**Verified:** `aws sts get-caller-identity` → `arn:aws:iam::<acct>:user/devsecops90`

MFA enabled on the IAM user as well — an administrative identity is still a valuable
target. Account alias set so the sign-in URL is a name, not a twelve-digit number.

### Two documented compromises
1. **`AdministratorAccess` attached.** Broad by design, contradicting least
   privilege. Deliberate: the specific permissions needed aren't yet known, and
   guessing wrong means fighting permission errors instead of learning. **Narrowed
   on Days 14–15.** Logged as a known exception with a planned fix.
2. **Long-lived access key created** for CLI use — precisely the credential type
   that doesn't expire and that leaks into repositories. Kept deliberately for two
   days so the contrast lands: **Day 15 replaces it with temporary credentials via
   STS assume-role.** Mitigations meanwhile: MFA on the identity, one key only,
   never leaves the lab machine. Note that `aws configure` writes it in plaintext to
   `~/.aws/credentials`.

**Old way vs current way** — an IAM user with long-lived keys is simple but the keys
never expire; a key leaked in 2023 still works today. **IAM Identity Center** issues
**temporary credentials** that expire in hours — a hotel keycard that stops working
at checkout. If one leaks, it's worthless by tomorrow.

---

## 4. Detection enabled — before any infrastructure exists

Four things watch a building. **CloudTrail** is the logbook (on by default, 90 days
of history). The other three were enabled today.

| Service | Watches | Answers | Verified |
|---|---|---|---|
| **GuardDuty** | **Behaviour** | "Is something acting maliciously right now?" | `list-detectors` → detector ID returned |
| **AWS Config** | **State + history** | "What is this, and what was it last Tuesday?" | `describe-configuration-recorder-status` → `"recording": true`, `lastStatus: SUCCESS` |
| **Security Hub CSPM** | **Compliance** | "Where does this fall short of the standard?" | `get-enabled-standards` → FSBP v1.0.0 + CIS v1.2.0, both `READY` |

> **Behaviour, state, standard — three different questions.** That is why running
> all three is not redundancy. GuardDuty never says "non-compliant with FSBP S3.8."
> Config records that a bucket is public without any opinion on whether that's
> acceptable. Security Hub holds the rulebook and has no memory.

### Config: recording vs rules
Two separate things share the name.
- The **recorder** photographs every resource on every change. Judges nothing.
  Requires **no rules** to function.
- A **Config rule** is an evaluation layered on top, answering one question per rule.

**No rules were added manually.** Security Hub CSPM creates *service-linked* Config
rules automatically, and customers are not charged separately for them. Config still
bills for the **configuration items** those rules read.

### The `recordingScope: PAID` decision
Two options existed: allow Security Hub to create a free service-linked recorder
scoped only to what its controls need, or create an independent recorder covering
all resource types plus global resources.

- **Gained:** complete resource history, including resources no security control
  asks about — enabling questions nobody anticipated.
- **Paid:** per-item charges for recording items no check will read.

A deliberate purchase of coverage with money. Recorded rather than defaulted into.

### Delivery channel — configured, not yet proven
```
"s3BucketName": "config-bucket-<acct>"
"configSnapshotDeliveryInfo": {},
"configHistoryDeliveryInfo": {},
"configStreamDeliveryInfo": { "lastStatus": "NOT_APPLICABLE" }
```
Empty delivery objects mean **nothing has been written to the bucket yet**. The
channel exists; the delivery path is unproven. Re-check for a `SUCCESS` with a
timestamp.

> Same class as the fail2ban jail whose filter matched but whose ban action was never
> exercised: **configured and working are different claims, and only one is currently
> evidenced.**

### CIS closes a Day-11 objection
`CIS AWS Foundations Benchmark v1.2.0` enabled itself as a default standard. On
Day 11 the hand-written `cis-audit.sh` scored 12/12, and the objection was **"who
picked the 12?"** — the assessor did, making the score weak evidence. Here the
checks were chosen by the Center for Internet Security: published, versioned,
consensus-built. **That is what a benchmark buys — a checklist that isn't yours, so
the score means something to a third party.**

*(v1.2.0 dates from 2018; v3.0.0 and v5.0.0 are available. Revisit at Day 30.)*

`AutoEnableControls: true` — new controls activate as AWS publishes them. Good
coverage; on a client account it is a cost-governance conversation.

---

## 5. Cost posture

**Zero credits remaining — every resource bills at on-demand rates from the first
cent.** There is no cushion and no automatic shutdown. The **$50/month Budgets
alarm** (thresholds 50%, 80%, 100%) is the only backstop.

| Item | Cost |
|---|---|
| GuardDuty | 30-day free trial from enablement (≈ Day 43 programme time) |
| Security Hub CSPM | 30-day free trial; then ≈ **$0.25/month** at 1 account / 1 region / ~250 checks |
| AWS Config | **Billing from today** — per configuration item |
| **Phase 2 estimate, all three** | **≈ $2–8**, mostly Config |

**The cost model:** security checks = *resources × applicable controls*. An empty
account costs pennies; the number rises through Days 19–24. Identical controls shared
across standards are charged once, so the duplicate CIS/FSBP overlap is not doubled.

> **Perspective:** a forgotten NAT Gateway (~$33/month) costs over 130× what Security
> Hub does. **Compute left running, not security tooling, is what destroys a budget.**

**Phase 2 cost traps:** NAT Gateway (~$33/mo just for existing) · unattached Elastic
IPs (bill continuously — release, don't detach) · RDS left running (~$12–15/mo) ·
`config-bucket-*` persists after teardown.

---

## SOC 2 mapping
| Control | Criterion |
|---|---|
| Root MFA, two devices, phishing-resistant primary | **CC6.1** (authentication) |
| Separate named working identity; root reserved | **CC6.1 / CC6.3** (least privilege, segregation) |
| CloudTrail activity logging | **CC7.2** (audit trail) |
| GuardDuty continuous threat detection | **CC7.1 / CC7.2** (anomaly detection) |
| Config recorder — resource state history | **CC7.1 / CC8.1** (change detection, change management) |
| Security Hub CSPM vs FSBP and CIS benchmarks | **CC4.1** (control monitoring and evaluation) |
| Budgets alarm with graduated thresholds | **A1.1** (capacity and resource management) |

## Verification commands
```bash
aws sts get-caller-identity
aws guardduty list-detectors
aws configservice describe-configuration-recorder-status
aws configservice describe-delivery-channel-status
aws securityhub get-enabled-standards
aws freetier get-account-plan-state
```

## Open items
- [ ] Confirm Config delivery to S3 shows `SUCCESS` (currently unproven)
- [ ] Consider CIS v1.2.0 → v3.0.0/v5.0.0 at Day 30 findings review
- [ ] Review GuardDuty / Security Hub charges at trial expiry (~Day 43)
- [ ] Narrow `AdministratorAccess` — Days 14–15
- [ ] Replace long-lived access key with STS temporary credentials — Day 15