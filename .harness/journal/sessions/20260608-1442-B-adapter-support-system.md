# Adapter Support System

## Goal

Introduce a foundation for website and desktop-app adapters so TimeArc can
normalize high-frequency sites/apps into friendly metadata while keeping raw
usage capture unchanged.

## Service side

The service continues to emit the existing foreground/audio records only:
platform, source, app id/name, window/media title, path, start time, and
duration. No service schema change, no page body capture, no screenshots, no
IP-based identification, and no browser history reads are introduced in this
session.

## UI side

The UI read/aggregation layer resolves each raw record through local adapter
metadata. Adapter metadata is enhancement-only: display name, category,
source type, icon/fallback, domain, and confidence. If an adapter misses or
fails, existing raw app/title behavior remains the fallback.

## Rule files

Touches UI manager/QML/docs only, so relevant rules are architecture,
data-contract, and UI conventions. Frozen disk-contract files are not edited.
