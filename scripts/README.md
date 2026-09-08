# Scripts

Cross-ecosystem automation belongs here. JavaScript orchestration must not replace native Swift or Rust tooling.

- `deploy-production.sh` builds, migrates, deploys, verifies, and rolls back the API on failure.
- `rollback-production.sh <release>` restores a retained API image.
- `verify-production.sh` polls the dependency-aware readiness endpoint.
- `backup-postgres.sh` produces a checksummed PostgreSQL custom-format dump.

Production setup and operational commands are in [`infrastructure/production/README.md`](../infrastructure/production/README.md).
# App Store archive

On a Mac with Xcode 26+ and signing configured, run `bash scripts/archive-ios.sh VERSION BUILD` from the repo root. Choose a matching App Store version and an unused build number. This creates a signed archive without uploading or publishing. Follow [the release checklist](../docs/APP_STORE_RELEASE.md) before submitting.
