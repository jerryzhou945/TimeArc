# Token-Cost Optimization Notes

How a Codex session should minimize context spent on the harness while
still satisfying every MUST in `AGENTS.md`. Ordered by ROI.

## 1. Read on demand, not up front

`AGENTS.md` §3 is intentionally a router. Codex MUST read `CHARTER.md`
and `AGENTS.md`; everything else is pulled only when the diff touches
that area. Do NOT grep-read `rules/*.md` wholesale at session start.

Typical session reads: `AGENTS.md` (89 L), `CHARTER.md` (83 L), one
track file (~70 L), one or two rules (~80 L each). Budget: ~400 lines.

## 2. Let the tools do the parsing

`harness_check.py` outputs one line per pass and one per DRIFT. Parse
stderr for `DRIFT:` — do not re-read source to decide if something is
broken. Example: `grep '^  DRIFT:'` is sufficient signal.

## 3. build.py tails, not heads

`build.py` stores full build output under `journal/build-logs/`. The
L1 report auto-attaches only the last 80 lines via `record_error.py
--file`. Never cat a multi-megabyte build log into context; read the
last 80 lines with `tail -n 80` if a deeper dive is needed.

## 4. Session logs stay lean

A session log is three paragraphs: **goal**, **what happened**,
**outcome**. No running commentary. Next Codex reads only goal +
outcome unless it is debugging your session.

## 5. Error reports template is already minimal

`templates/error-report.md` has §1–5 with one-line prompts. Fill them;
do not expand them. L3 reports add §6 with three questions; answer in
single sentences.

## 6. Do not echo rule text

When citing a rule, reference the anchor: `rules/03-data-contract.md
§D2`. Do NOT paste the rule's body.

## 7. Hash mismatches print short

Pass 2 prints `hash mismatch` without hex pairs. If Codex wants the
actual hashes, it is a sign to look at `state/frozen-files.json`
directly; do not ask the audit for verbose hex.

## 8. Prefer `--fast` during coding, full audit only pre-commit

`preflight.py` already uses `--fast`. Passes 3–7 are cheap; still,
avoid re-running the full audit on every file save.

## 9. One tool invocation = one journal side effect

`record_error.py` is atomic: one call = one report + one jsonl row +
one INDEX row. Avoid hand-editing the journal files when the tool
will do it in one shot.

## 10. Keep `state/open-issues.md` as the cache

`open-issues.md` is the single place to look up known pain points.
Do not rediscover issues by grepping the codebase; consult that file
first, and strike items as they resolve.

## Red flags

- Reading `journal/errors/` in bulk: almost never the right move.
  Use `journal/errors.jsonl` (machine-readable) and only open the
  specific report the jsonl row points to.
- Re-reading `CHARTER.md` §3 after every edit: its hash is in pass 2;
  if it changed, audit will tell you.
