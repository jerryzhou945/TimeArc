# TimeArc Background Service

TimeArc uses separate service implementations per platform, but both write the
same usage event protocol.

- `shared/`: shared protocol, app snapshots, environment interfaces, and path helpers.
- `windows/`: Windows implementation in C using Windows API.
- `macos/`: macOS implementation scaffold in Swift.

The Qt app should consume the JSONL records described in
`shared/usage_record.md` and validated by `shared/usage_record.schema.json`.
