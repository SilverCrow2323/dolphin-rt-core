# Dolphin Rt:Stream PC Companion

Dolphin Rt:Stream is the PC-side companion for streaming GameCube and Wii games to a muOS handheld.

## Architecture

The PC application uses three independent channels:

1. **Game streaming — Sunshine / Moonlight.** Sunshine runs on the PC and streams Dolphin video plus controller input.
2. **Library sync — Rt:Stream HTTP service.** The handheld downloads \`library.tsv\` and cover art from the PC sync server. ROM images are not exposed by this service.
3. **Remote files — optional SFTP.** The Companion can inspect the device's configured ROM directory, upload PC ROMs and download/delete remote ROMs with explicit confirmation.

The browser control panel is a local PC interface bound to \`127.0.0.1\`; it is not exposed to the LAN. The handheld library-sync server remains a separate service and port.

## Launch and first setup

The package command \`spdw-stream-portal\` opens the browser Companion. The previous Tkinter interface remains available with \`spdw-stream-portal --legacy\`.

1. In **Game Library**, add absolute GameCube and Wii ROM source directories, one per line, then scan.
2. In **Streaming**, start Sunshine and the separate library-sync server as needed. Pair Moonlight through the existing handheld Rt:Stream flow.
3. The library sync server defaults to port 8765. The local browser control panel defaults to port 8766.
4. Optionally refresh the canonical Rt:Core compatibility dataset in Game Library. Reports are matched by Game ID and system; the Companion never creates synthetic ratings.

## Device discovery and optional SFTP

Discovery only checks devices already visible in the operating system's neighbor table and online Tailscale peers. It does not sweep IP subnets. A listed peer is only a candidate; **Test SFTP** must still succeed.

SFTP requires a working SSH/SFTP server on the handheld. Configure its actual host, SSH port, username and ROM destination path in **Device & SFTP**.

- Authentication uses OpenSSH keys or an existing SSH agent. Passwords and private keys are never stored by Rt:Stream.
- The device SSH host key must already be trusted in the system \`known_hosts\`.
- Host-key verification is strict and is never disabled.
- Browsing and destructive actions are restricted to the configured remote ROM directory.
- Upload is limited to supported ROM files within configured PC library roots.
- Remote downloads are placed in the PC library's \`received/\` folder.
- Existing files require an explicit Resume, Restart or Overwrite choice. Interrupted uploads/downloads keep a partial file for OpenSSH SFTP's resume mode.

The actual device path, SSH account and SFTP service state must be verified on the target firmware. Do not assume an SSH server is enabled by default.

## Dolphin profiles and display settings

The Companion exposes the existing GCPad, Wiimote and Hotkeys Dolphin profiles. Selecting a profile changes the active profile used by the existing game launcher. **Apply now** writes the active profiles to Dolphin configuration only when Dolphin is closed and creates backups.

Display options update the existing Rt:Stream launch entries in Sunshine. Bitrate, codec and FPS remain Moonlight/handheld streaming preferences.

## Security boundary

- Web control API listens on loopback only and uses a random per-process session token.
- Cross-origin mutations are rejected; static routes are allowlisted.
- SFTP uses OpenSSH BatchMode and strict known-host verification.
- Remote path traversal is rejected; browsing/deletion remain under the configured ROM root.
- No unrestricted local filesystem browser, arbitrary remote shell, saved password or saved private key is exposed.

## Validation

CI tests the web API security contract, discovery paths, remote path boundaries, parsed SFTP listings, resume endpoints, responsive UI and compatibility integration. CI cannot certify a real handheld SFTP connection, Moonlight pairing, Sunshine stream or physical muOS storage layout; those still need an end-to-end device test.
