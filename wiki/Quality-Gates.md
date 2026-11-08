# Quality Gates

- Run `git diff --check`.
- Run syntax checks and tests for the component changed.
- Run frontend smoke tests when dependencies are available.
- Capture and inspect affected UI screens.
- Test install/upgrade/uninstall using disposable fixtures.
- Verify target hardware separately from desktop/Xvfb checks.

The root README is authoritative for platform support status. Dry-run tests do not establish hardware support.
