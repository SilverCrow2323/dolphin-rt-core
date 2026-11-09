# Rt:Stream

Rt:Stream is the PC-assisted streaming component of the Dolphin Rt ecosystem. Dolphin runs on the PC; Sunshine captures and streams the video; Moonlight on the handheld decodes the stream and forwards controller input.

## Components

- `portal/` — PC-side Python/Tk portal and services.
- `portal/muos/Dolphin RtStream/` — handheld LÖVE client.
- Sunshine — host streaming service.
- Moonlight — client streaming application.

## Basic checks

1. Install and start the PC portal and Sunshine as described in `portal/docs/INSTALL.md`.
2. Confirm the portal library endpoint and configured sync port are reachable from the handheld.
3. Complete Sunshine pairing using the UI flow.
4. Configure the host address and local edit token on the handheld; never paste the token into a public issue.
5. Run the portal preflight and handheld connection tests before launching a game.

## Troubleshooting

Check `portal/docs/TROUBLESHOOTING.md`, portal logs and handheld diagnostics. Network reachability, pairing state, firewall policy, host display setup and Moonlight dependencies are separate failure points.

Rt:Stream is not a handheld emulator. The PC performs emulation and rendering.
