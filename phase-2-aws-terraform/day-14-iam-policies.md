# Day 14 — IAM I: Policy Anatomy & Evaluation Logic

**Artifact:** `AdwenAssessorReadOnly` — a customer-managed policy granting security
assessors read access to configuration while explicitly denying all data access.
This is the access an external assessor requests from a client, and the access
Agent 5 will use on Day 75.

## Security thread
**IAM is the real perimeter.** Network controls protect what sits inside a boundary;
IAM decides who may act at all. A misconfigured policy is reachable from anywhere
credentials work.

---

## 1. What a policy is

A written rule stating who may do what — in AWS, a JSON document with four parts:

| Part | Meaning | Example |
|---|---|---|
| **Effect** | Allow or Deny | `"Effect": "Deny"` |
| **Action** | The operation, as `service:Operation` | `s3:GetObject` |
| **Resource** | What it applies to, as an ARN | `arn:aws:s3:::bucket/*` |
| **Condition** *(optional)* | Extra requirements | MFA present; source IP range |

Read as: **allow or deny / this operation / on this thing / under these
circumstances.**

`"Version": "2012-10-17"` is a **policy language version**, not a date to choose.
It is the current one and enables features (policy variables) the older
`2008-10-17` lacks. Always use it.

`Sid` (statement ID) is a human-facing label with no functional effect — but in a
fifteen-statement policy it is how a statement gets discussed.

---

## 2. Evaluation logic — a bouncer with three lists

| Order | Check | AWS term |
|---|---|---|
| 1 | **The ban list.** On it? Not coming in — regardless of any invitation | **Explicit deny** — beats everything, no override exists |
| 2 | **The guest list.** Not invited? Still not coming in. No benefit of the doubt | **Implicit deny** — the default state of every action |
| 3 | **The capacity limit.** Applies no matter who invited you | **Permission boundary** — caps what any policy can grant |

**Why designed this way.**
- **Deny beating allow** lets one team write a rule nobody can accidentally undo —
  *"nobody deletes CloudTrail logs, ever"* holds even when a later, over-generous
  policy is attached.
- **Default deny** means a service AWS launches next year is automatically forbidden
  until someone decides otherwise. **New capabilities arrive locked, not open.**

Both principles already met at other layers: UFW default-deny inbound (Day 11), and
`other: ---` on the `3770` shared directory (Day 2).

---

## 3. The "read-only" trap

The intuitive move is to allow `Get*` and `List*` because Get sounds like reading.
**AWS's naming does not distinguish reading configuration from reading data.**

| Action | Actually returns |
|---|---|
| `s3:GetObject` | The file's contents |
| `secretsmanager:GetSecretValue` | The secret itself |
| `ssm:GetParameter` | Parameter values, decrypted |
| `lambda:GetFunction` | A download link to the source code |
| `dynamodb:GetItem` / `Query` / `Scan` | Table rows |
| `kms:Decrypt` | Plaintext of anything encrypted |

So "read-only" splits in two:
- **Configuration** — *"this bucket exists, it's encrypted, it's not public"*
- **Contents** — *"here is what is inside the bucket"*

**An assessor needs the first. A client would be alarmed to learn they granted the
second.**

Matching trap on the write side: `Put`, `Update`, `Attach`, `Set` and `Tag` all
modify without containing the word "write." `iam:PutUserPolicy` and
`iam:AttachUserPolicy` both grant permissions.

*(Note: `iam:GetCredentialReport` returns credential **metadata** — MFA status, key
rotation age — not credentials. Sensitive, but legitimate and necessary for audit.)*

---

## 4. The policy

Built after reading AWS's managed `SecurityAudit` policy for reference —
worth noting that AWS's own version contains **no deny statements at all**, which is
the gap this one closes.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSecurityConfigurationRead",
      "Effect": "Allow",
      "Action": [
        "iam:Get*", "iam:List*",
        "iam:GenerateCredentialReport", "iam:GenerateServiceLastAccessedDetails",
        "s3:GetBucketPolicy", "s3:GetBucketAcl", "s3:GetBucketPublicAccessBlock",
        "s3:GetBucketVersioning", "s3:GetEncryptionConfiguration", "s3:GetBucketLogging",
        "s3:ListAllMyBuckets",
        "ec2:Describe*",
        "cloudtrail:Describe*", "cloudtrail:Get*", "cloudtrail:LookupEvents",
        "config:Describe*", "config:Get*",
        "guardduty:Get*", "guardduty:List*",
        "securityhub:Get*", "securityhub:Describe*",
        "kms:DescribeKey", "kms:GetKeyPolicy", "kms:GetKeyRotationStatus", "kms:ListKeys"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DenyDataPlaneAccess",
      "Effect": "Deny",
      "Action": [
        "s3:GetObject", "s3:GetObjectVersion",
        "secretsmanager:GetSecretValue",
        "ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath",
        "lambda:GetFunction",
        "dynamodb:GetItem", "dynamodb:BatchGetItem", "dynamodb:Query", "dynamodb:Scan",
        "kms:Decrypt"
      ],
      "Resource": "*"
    }
  ]
}
```

### The deliberate asymmetry in wildcard use
`iam:Get*` and `iam:List*` are wildcards — every IAM Get/List action is metadata, so
breadth is acceptable and maintenance drops.

**`s3:Get*` is deliberately NOT used**, because it would sweep in `s3:GetObject` and
hand over file contents. Where a wildcard would capture something dangerous, actions
are enumerated individually.

> **The rule: wildcard where the whole namespace is safe; enumerate where it isn't.**

`"Resource": "*"` is correct here — an assessor must see the entire account. In most
other policies, `*` in the resource field is itself a finding.

---

## 5. Proof — both halves

```
+--------------------------------+----------------+
|  s3:ListAllMyBuckets           |  allowed       |
|  iam:ListUsers                 |  allowed       |
|  ec2:DescribeInstances         |  allowed       |
|  guardduty:ListDetectors       |  allowed       |
|  s3:GetObject                  |  explicitDeny  |
|  secretsmanager:GetSecretValue |  explicitDeny  |
|  lambda:GetFunction            |  explicitDeny  |
|  iam:CreateUser                |  implicitDeny  |
|  ec2:TerminateInstances        |  implicitDeny  |
+--------------------------------+----------------+
```

`aws iam list-attached-user-policies --user-name assessor-test` confirmed **only**
this policy attached — a test with other policies present proves nothing about this
one.

### explicitDeny vs implicitDeny — same outcome, different mechanism

| | `iam:CreateUser` | `s3:GetObject` |
|---|---|---|
| Decision | `implicitDeny` | `explicitDeny` |
| Cause | Nothing granted it | A rule forbids it |
| Is it a default? | **Yes** | **No** |
| Survives a new permissive policy? | **No** | **Yes** |

> **Why write denies when implicit deny already covers those actions?**
> **Implicit deny is fragile; explicit deny is permanent.** Six months from now
> someone attaches `AmazonS3ReadOnlyAccess` to this user for an unrelated reason.
> Without the deny block, the assessor can suddenly read every object in every
> bucket, and nobody notices because the change looked innocuous. With it, the deny
> wins.
>
> **A deny statement is a guarantee that survives other people's decisions.** This is
> why organisations place denies in Service Control Policies at the org level, where
> no account-level policy can undo them.

### Limitation — configured, not exercised
`simulate-principal-policy` proves what AWS **would** decide. It does not prove
behaviour under a real call. Testing for real requires an access key for the test
user, which contradicts the day's other lesson. **Day 15's assume-role provides a
way to test as another identity without long-lived credentials.** Recorded rather
than resolved.

*(Same class as Day 13's delivery channel: configured and working are separate
claims.)*

### Stretch not yet applied — MFA condition
```json
"Condition": { "Bool": { "aws:MultiFactorAuthPresent": "true" } }
```
On the Allow statement, this grants nothing unless the assessor authenticated with
MFA. **Costs:** a more annoying login; automation needs MFA-aware session handling.
**Buys:** a leaked assessor credential is useless alone. For an external party
holding a complete map of the client's security configuration, the trade is clearly
worth it.

---

## 6. Identity-based vs resource-based policies

Both authorize. They differ in **where they attach**.

| | Identity-based | Resource-based |
|---|---|---|
| Attached to | User, group, role | The resource (bucket, KMS key, SQS queue) |
| Reads as | *"This identity may do X to those things"* | *"These principals may do X to me"* |
| Has a `Principal` field | No | **Yes** |

> **What only a resource-based policy can do: grant access to a principal in another
> AWS account.** An identity policy in your account cannot authorize someone else's
> identity — you don't control it. A bucket policy names their account directly.
> This is the mechanism behind all cross-account access.

---

## SOC 2 mapping
| Control | Criterion |
|---|---|
| Least-privilege assessor policy, enumerated actions | **CC6.1** (logical access) |
| Explicit deny on data-plane reads, survives future grants | **CC6.1 / CC6.3** |
| Denials proven per-action, not assumed | **CC6.1** (access controls evidenced) |
| Separation of configuration read from data read | **CC6.7** (confidentiality) |
| Test user with single attached policy, verified | **CC6.2** (access provisioning) |

## Adwen application
`AdwenAssessorReadOnly` is the access request template for a client security
assessment. It is defensible in a client conversation precisely because of the deny
block: *"we can see how your account is configured; we are structurally incapable of
reading your data."* That is a commercial differentiator, not just a control.

## Certification relevance
IAM policy evaluation is among the most-tested topics on both **SCS-C03** (AWS
Certified Security – Specialty) and **SAA-C03** (Solutions Architect – Associate).
Specifically examinable and covered today: explicit vs implicit deny, permission
boundaries as a cap, identity-based vs resource-based policies, cross-account access
via resource policies, and service prefixes (`sts:GetSessionToken` is not
`iam:GetSessionToken`).

## Open items
- [ ] Add the MFA condition and re-simulate (stretch)
- [ ] Test the policy with real credentials via assume-role — **Day 15**
- [ ] Delete `assessor-test` user when Phase 2 IAM work concludes