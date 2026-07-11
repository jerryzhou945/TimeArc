# Change Proposal — <slug>

> Copy this file to `.harness/journal/sessions/YYYYMMDD-HHMM-<slug>.md` and
> fill it in **before** editing any frozen file or making a charter amendment.

## Metadata

- Author: <agent id or human name>
- Track: **B (Feature)** is expected; rarely **A** or **C**. Justify in §2 if
  not B. See `../tracks/README.md`.
- Date: YYYY-MM-DD HH:MM (local)
- Session goal (one sentence):
- Branch:
- Related error reports (if any):

## 1. Frozen files touched

List each frozen file being modified and briefly describe the modification.
If none, state "none" and note why this file is being filed anyway (e.g., a
charter amendment).

- `path/to/file` — <what is changing>

## 2. Motivation

Why is this change necessary? What breaks or remains wrong if we do not make
it? Be concrete. Cite the issue, the error report, or the user-visible
symptom.

## 3. Impact on the other process

TimeArc is two processes sharing files. For every frozen file you touch,
explain the effect on the producer (service) side and the consumer (UI) side.

| Side        | Effect                                          |
|-------------|-------------------------------------------------|
| Producer    |                                                 |
| Consumer    |                                                 |

## 4. Migration plan

If existing on-disk records (`timearc_service.db`, `usage_current.json`, or
legacy artifacts) are interpreted differently after this change, describe:

- What old records look like.
- What new records look like.
- How they coexist — or, if they cannot, the one-shot migrator's plan,
  backup strategy, and failure handling.

If no on-disk effect, state "no on-disk impact".

## 5. Rollback plan

How do we undo this change if a bug is discovered after release? Is a code
revert sufficient, or does data need to be restored from backup?

## 6. Test plan

- Pre-change reproduction (how to see the problem):
- Post-change verification (how to see it is fixed):
- New test artifacts (if any):

## 7. Sign-off

- [ ] `rules/*.md` updated to reflect new reality (list which).
- [ ] `CHARTER.md` version bumped (if charter amendment).
- [ ] `state/frozen-files.json` will be regenerated after the commit lands.
- [ ] Main `README.md` updated if user-visible.
