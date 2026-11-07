# Security

Dolphin Rt:Stream runs a small HTTP server on the PC (the *library server*) and can optionally write Dolphin controller
profiles on request of the handheld. Read [docs/PROTOCOL.md](docs/PROTOCOL.md) for the exact surface.

Short version:
- Only `library.tsv`, `profiles.tsv` and `covers/*` are readable without authentication.
- Anything that **writes** (`/ctl`) needs the 10-character token shown in the portal. Wrong tokens are delayed by one
  second. Profile names must start with `muos`, keys must already exist in the profile and values are restricted to a
  small safe character set, so no ini/shell injection is possible through the API.
- The server speaks plain HTTP: run it on your LAN or over Tailscale/WireGuard, never expose the port to the Internet.
- Rotate the token (portal > SYSTEM > NEW TOKEN) if you ever share a screenshot of it.

## Handheld side

- The handheld app only writes to `launch.txt`, `launch.env` and the state files under `conf/`. `launch.txt` is
  validated on the app side (`^[%w_%.%-]+$`, max 64 chars) and again on the shell side before being passed to
  Moonlight, so a malicious entry in `library.tsv` cannot inject a shell command through it.
- The **Diagnostics export** tool writes to `conf/diagnostics.txt` only. It dumps `stream.conf`, `ui.cfg`, the last
  stream log and the library count. **The edit token is masked** (only the first 4 characters are kept).
- The **health check** LEDs (`SUNSHINE`, `LIBRARY`) only perform unauthenticated GET requests to `/serverinfo` and
  `/library.tsv` on the configured host and port. They do not send the token.
- The handheld app does not store credentials outside `conf/stream.conf`. If you back up that file, treat it as
  sensitive.

## Reporting a vulnerability
Open a private security advisory on GitHub (Security > Advisories) or contact the maintainers. Please do not file a
public issue for anything that lets a third party change files on the PC.