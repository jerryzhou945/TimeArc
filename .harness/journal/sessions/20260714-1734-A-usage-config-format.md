# 20260714-1734 A usage-config-format

Track: A Stabilize

Goal: Explain the existing `usage_config.json` disk-control format and its fallback behavior.

Plan:
- Read the authoritative data-contract rule and current config readers/writer.
- Summarize the three active keys, paths, validation, and startup semantics.
- Make no product source changes and do not build or run the app.

Outcome: Done. Confirmed the three-key JSON object, platform file locations,
per-key defaults and validation, atomic key-preserving UI writes, and startup-read
semantics. No product files were changed; no build or runtime check was needed.
