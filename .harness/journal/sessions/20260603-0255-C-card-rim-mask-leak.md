# Session - card-rim-mask-leak

## Track

C Debug

## Related error report

- [`../errors/20260602-193021-C-card-rim-leak-threshold.md`](../errors/20260602-193021-C-card-rim-leak-threshold.md)
  — L3: rim-inside-alone was insufficient; `maskThresholdMin` raise required.

## Motivation

Memory Lake selected-card front/back face leaks dark (`faceBg`) / cover-image
pixels *outside* the cyan edge-light rim at the rounded corners. Logged as
UNRESOLVED in `docs/memory-lake-fidelity-gaps.md` (2026-06-03 round). Prior
attempts (single rounded `MultiEffect` mask + `layer.samples:4`) did not fix it.

## Hypothesis (to verify with screenshots)

The rim (`border` Rectangle, radius 28) is drawn as a **sibling on top of** the
`MultiEffect` masked output. The masked content and the rim are two independent
edges (FBO-sampled mask AA vs native rounded-rect AA); the masked content's
anti-aliased edge overshoots the rim's outer edge by a sub-pixel, so near-black
bg / image shows beyond the rim. Fix direction: make the content mask and the
rim share **one** rounded clip (rim drawn inside the masked composite), and keep
the face in a multisampled layer so 3D rotation stays smooth. Rim may be widened
slightly per user allowance.

## Verification plan

Render a selected card over a saturated contrast background (magenta/white),
`grabToImage` at 3-4x, zoom each corner. Leak = dark/image pixels between the
magenta and the cyan rim. Loop fix -> grab -> inspect until corners are clean.
Per build-verify memory, confirm on a real render, not only a single screenshot.

## Data Safety

No storage-contract files touched. QML-only change under
`qml/desktop/memorylake/`. No IPC / disk-contract changes.

## Resolution (RESOLVED)

Confirmed root cause at the pixel level (magenta `#FF00FF` bg, 3x `grabToImage`,
per-corner diagonal scan): the rounded corners leak because the `MultiEffect`
mask's default `maskThresholdMin: 0` passes the AA alpha fringe straight through,
so the masked content's effective corner radius is ~2px larger than the rim;
the rim, being a sibling Rectangle drawn *on top of* the MultiEffect output
(outer edge fixed at radius 28), can never cover content that reaches past 28.
Straight edges were clean (rim covers the ~0.5px fringe there); only corners leaked.

Fix in `MemoryCard.qml`, both faces:
1. Rim moved **inside** the masked composite (topmost child of
   `faceContent`/`backArtSrc`) so rim + content share one clip — content can no
   longer exceed the rim. Rim is the upper layer of the face.
2. `maskThresholdMin: 0.5` + `maskSpreadAtMin: 0.28` — cut at the 50%-coverage
   contour (= geometric radius) instead of the alpha≈0 fringe. (Threshold must be
   > spread/2, else smoothstep straddles 0 and leaks the masked-out region.)
3. Rim widened 1px -> 2px (`rimWidth`, the user-permitted "widen the edge light").
4. Each face composited into one `layer.enabled: card.selected` MSAA layer so the
   Flipable rotates a single AA'd texture (kills rotation jaggies + texture/vector seam).

Verification: pixel-gate over 8 corners (front + 180deg back) = **0 faceBg pixels
beyond the rim** (vs a large leak at `threshold 0`). `build.py` clean; real-app
Memory Lake selected card renders with no regression. Diagnosis cross-checked by a
4-lens + synthesis subagent workflow. Empirically disproved one workflow claim
that "rim-inside alone" suffices — the threshold fix is required (tested t=0.0 still leaks).
