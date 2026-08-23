# The Answer Spine — structuring technical explanation

> Remediation artifact from Checkpoint 1. Built because the checkpoint measured a
> clean split: artifacts 87%, every component requiring explanation 45–55%.
> The work was there; the narration wasn't.

---

## The diagnosis

**Answering from recall instead of from structure.** A question arrives → retrieve
the true thing you know → say it → stop. The shape of the answer is never planned
before speaking.

That single habit produces three distinct failure modes:

| Symptom | What's actually happening |
|---|---|
| **Partial answers** — 2 of 3 parts | Retrieval is satisfied after the first part; nothing prompts you to continue |
| **Remedy instead of mechanism** | The fix is easier to recall than the reason |
| **Conclusion without "because"** | The conclusion *is* the recalled item; support was never retrieved |

Not a knowledge problem. Not a confidence problem. **A missing template.**

---

## The spine

### Step 0 — Count the parts, out loud

> *"You asked me three things: what it solved, how I verified it, and what it
> doesn't cover."*

Costs three seconds. Makes a partial answer structurally impossible. Buys thinking
time. Reads as disciplined, not hesitant.

### Then, per part — three beats

**1. CLAIM** — the direct answer, one sentence. Not context. Not background. The
answer.

**2. BECAUSE** — the mechanism, **at the layer the question was asked**:
- *Why is this dangerous?* → what the attacker does, step by step
- *Why is this design better?* → the property that differs between the options
- *Why did this break?* → what the system did, not what you did about it

**3. BOUNDARY** — where it stops, what it costs, or how you'd prove it.

> Deliver all three and you cannot give a partial answer, and you cannot state a
> conclusion without support.

---

## Worked contrast

**Question:** *"Walk me through a security control you implemented. What problem
it solved, how you verified it, and what it doesn't protect against."*

### Recall-driven (what was said — 4/8)
> "The last control I implemented was setgid and a default group ACL for team
> collaboration. I created the directory, set it 3770 with the development group,
> added `setfacl -d -m g::rwx`. This prevents non-members accessing it and only
> file owners can delete. I proved it by checking the mode and testing with user
> credentials."

Accurate. Two of three parts. No problem framing, no boundary.

### Spine-driven (same knowledge, planned)
> "You asked three things — the problem, how I verified it, and what it doesn't
> protect against.
>
> **Problem:** a shared team directory where files created by one member weren't
> editable by the others, so people were emailing files around instead of working
> in place.
>
> **Build and verification:** `3770` — setgid so new files inherit the team group,
> sticky so a user can only delete their own files, `other` gets nothing. Plus a
> default ACL, *because* setgid gives group **ownership** but not group **write** —
> without it files land at 644 and I'd have solved half the problem. Verified with
> paired tests: alice, a member, writes successfully; bob, a non-member, is denied.
> Both halves — a fix that only proves the positive case is how a 777 ships as
> 'fixed'.
>
> **What it doesn't cover:** permissions answer *'who may touch this'*, never
> *'should this person be doing this right now'*. If alice is phished, every
> permission check says yes — correctly. The attacker can't delete other people's
> work, thanks to sticky, but they can rewrite it, and the team consumes poisoned
> code. Permissions are the floor; above them you need detection — file integrity
> monitoring, signed commits, code review."

Same facts. Planned before spoken.

---

## Question-type → spine mapping

| Question shape | CLAIM | BECAUSE | BOUNDARY |
|---|---|---|---|
| "Is X secure / is this junior right?" | Yes / no / partly | What an attacker can and cannot do, mechanically | The condition that would change the answer |
| "Why is A better than B?" | A is better | The **property** that differs | What A costs |
| "Explain this finding" | What it is + severity | Attacker's concrete steps | How to prove it's closed |
| "Why did this break?" | The cause | What the *system* did | How you verified the fix |
| "Talk me out of this design" | Don't do it | The specific attack path, named | What to build instead |

---

## Standing rules

1. **Answer the layer that was asked.** *"How does an attacker exploit this?"*
   wants attacker steps, not the remediation. If you're describing the fix, you've
   changed the question.
2. **Never assert without "because."** *"This is insecure"* scores near zero.
   *"An attacker does X, because the system does Y"* scores full marks.
3. **Name the mechanism.** Not "the agent could go rogue" — **prompt injection**.
   Not "root ownership is safer" — the attacker **cannot `chmod`** the directory.
   Named mechanisms are checkable; vague ones aren't.
4. **Severity is a judgment you're paid for.** Everything marked critical means
   nothing is. A service down is not a data breach.
5. **"I don't know" + reasoning beats bluffing.** *"I don't know the term, but the
   mechanism is X"* reads as senior. Interviewers can always tell.

---

## Drill protocol

**Before every session (5 min).** Open `career/resume-bullets-day06.md`. Read one
bullet, then say its defence line **aloud**, in the spine. Out loud matters — the
gap is between knowing and *saying*.

**During every session.** When a question comes: count the parts aloud first.
Every time, including when it feels unnecessary.

**After every lab.** One paragraph in the day-doc: what you built, the mechanism
in one "because" sentence, and one thing it doesn't cover.

**Weekly.** Take one artifact and explain it to an imagined non-expert stakeholder
— the finance director who signs off on the audit. Different audience, same spine.
Forces the claim ahead of the detail.