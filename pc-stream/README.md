# Dolphin Rt:Stream PC Companion

Dolphin Rt:Stream is the PC-side companion for streaming GameCube and Wii games to a muOS handheld.

## Architecture

The PC application has three deliberately separate channels:

1. **Game streaming — Sunshine / Moonlight.** Sunshine runs on the PC and streams the Dolphin game plus controller input.
2. **Library sync — existing Rt:Stream HTTP service.** The handheld downloads the generated \`library.tsv\` manifest and cover art from the PC sync server.
3. **Remote files — optional SFTP.** The new PC Companion can connect to a handheld's SSH/SFTP service to inspect a configured directory and explicitly upload a ROM.

The web control panel is a local PC interface. It binds to \`127.0.0.1\`; it is not exposed to the LAN. The existing library sync service remains the separately configured endpoint used by the handheld.

## Launch

The package command \`spdw-stream-portal\` opens the browser-based PC Companion. The previous Tkinter interface remains available as:

\`\`\`sh
spdw-stream-portal --legacy
\`\`\`

The CLI \`spdw-stream\` continues to provide library building, sync-server management, Sunshine helpers, controller profiles and diagnostics.

## First setup

1. Open **Game Library** and configure one or more existing GameCube and Wii ROM directories (one absolute path per line).
2. Save the source folders and scan the library. The existing scanner, Game ID detection, cover pipeline and Sunshine app registration are reused.
3. Open **Streaming** and start Sunshine. Pair Moonlight from the handheld using the existing Rt:Stream flow.
4. The handheld library sync server remains on the configured sync port (8765 by default); this is not the web control panel port (8766 by default).

## Optional device SFTP

SFTP is optional and requires a working SSH/SFTP server on the handheld. Configure its actual host, port, SSH username and remote ROM directory in **Device & SFTP**.

- Authentication uses OpenSSH keys or an existing SSH agent. Rt:Stream does not store passwords or private keys.
- The device SSH host key must already be trusted in the system \`known_hosts\` file.
- Host-key verification is strict and is never disabled by the portal.
- Remote paths must be absolute and cannot contain parent-directory traversal.
- Upload is limited to ROM files inside the configured PC library roots.
- Existing remote files require a second explicit overwrite confirmation.

Do not assume a remote ROM path or enable an SSH service without checking the actual firmware/device configuration. A failed SFTP test may mean that SSH/SFTP is not enabled on the handheld, the username/port is different, the host key is not trusted, or the device is not reachable.

## Security boundary

- Web control API listens on loopback only.
- Mutating API requests require a random per-process session token.
- Cross-origin mutation requests are rejected.
- Static file routes are allowlisted.
- SFTP is invoked with OpenSSH strict host-key checking and batch mode.
- No password, private key, arbitrary local file browser or unrestricted remote shell is exposed.

## Validation

Repository CI runs static contract tests for the local-only bind, session token, SFTP host-key policy, safe ROM-root restriction, overwrite confirmation, editable source directories and responsive UI.

CI cannot validate a real handheld connection. SFTP, Moonlight pairing, Sunshine streaming and ROM transfer still require end-to-end tests against the actual muOS device and its enabled services.
