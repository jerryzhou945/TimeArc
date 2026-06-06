# card-rim-leak-threshold

- Timestamp: 2026-06-02T19:30:21Z
- Level: L3
- Track: C
- Platform: n-a

## Summary

Wrong premise (mine + a diagnosis subagent): moving the card edge-light rim INSIDE the MultiEffect-masked composite ALONE would stop the rounded-corner content leak. Empirically it did NOT (t=0.0 still leaked ~11px faceBg at corners); maskThresholdMin must also be raised to ~0.5 to cut at the 50% contour, and threshold must be > spread/2 or smoothstep leaks the masked-out region. Caught only by a magenta high-contrast 3x grab + per-pixel diagonal gate; plain dark-bg screenshots give false positives for this defect.

## Notes

Backfilled from `.harness/journal/errors.jsonl` because the D drive checkout referenced this report but the markdown file was absent.
