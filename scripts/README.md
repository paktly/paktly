# Scripts

Cross-ecosystem automation belongs here. JavaScript orchestration must not replace native Swift or Rust tooling.

- `deploy-production.sh` builds, migrates, deploys, verifies, and rolls back the API on failure.
- `rollback-production.sh <release>` restores a retained API image.
- `verify-production.sh` polls the dependency-aware readiness endpoint.
- `backup-postgres.sh` produces a checksummed PostgreSQL custom-format dump.

Production setup and operational commands are in [`infrastructure/production/README.md`](../infrastructure/production/README.md).
