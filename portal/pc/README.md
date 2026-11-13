# Dolphin Rt:Stream PC Companion

The PC Companion is the desktop control panel for the Rt:Stream handheld client.

## What it manages

- Sunshine installation and service state.
- The Rt:Stream library server and its refresh status.
- Controller profiles and the existing profile-sync endpoint.
- The PC's routable LAN IPv4 addresses and Tailscale IPv4 address, when Tailscale is installed and connected.

## Pairing the handheld

1. Connect the PC and handheld to the same LAN, or connect both to the same Tailscale network.
2. Start Sunshine on the PC from the Companion's Services panel.
3. Start the library server if you want library sync in addition to game streaming.
4. On the handheld open Rt:Stream Settings and choose **Scan LAN + Tailscale**.
5. When Sunshine is found, the handheld stores the host address and starts the Moonlight pairing flow.
6. Complete the normal PIN confirmation in Sunshine on the PC.

The PIN step is intentionally retained: network discovery can find the PC and prepare pairing, but it does not bypass Sunshine's trust confirmation.

## Network indicators

The Companion's lower status strip reports Sunshine, library-server, LAN and Tailscale state. The handheld's RTUI header separately reports its own LAN/Tailscale addresses and the reachability of the configured PC services.

The existing spdw-stream-portal launcher and package identifier remain compatible; the desktop application is presented as **Dolphin Rt:Stream PC Companion**.
