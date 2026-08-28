# Error Report - reset-button-gate-unverified-claim

## Metadata

- Level: **L3**
- Track: **B**
- Topic: reset-button-gate-unverified-claim
- Recorded: 2026-08-25T12:45:27Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Reported the Reset-to-defaults visibility gate as removed two passes ago, but the scripted replacement had not matched after an intervening card rewrite and the gate was still present. The claim went out unverified. Compounded by the later seeding change setting customized=false, which hid the button in the common case. Fixed, and covered by a static assertion that was itself proven to fail when the gate is reintroduced.

## 2. Evidence

```
(paste relevant log excerpt here)
```

## 3. Root cause

- Immediate cause:
- Underlying cause:
- Why the harness/checklists did not prevent it:

## 4. Fix

- Files changed:
- Short description:
- Commit:

## 5. Prevention

Concrete harness upgrade, or 'one-off, no harness change'.

## 6. Lessons for agents (L3)

- Wrong assumption:
- Earlier signal available:
- Rule file to update:
