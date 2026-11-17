# Rt:System Status Center

The **Rt:System Status Center** expands from the Rt:UI header. Press **M** to open it; press **M** or **B** to close it.

It replaces the old compact notification drawer with a scrollable dashboard. The panel refreshes its local snapshots while open and keeps the notification history below the operational status.

## What it reports

### Device and network

- Wi-Fi link state comes from the wireless interface carrier / operstate.
- Signal quality and SSID are displayed when the device exposes them.
- Battery percentage and charging state are read from the Linux power-supply interface.

A connected Wi-Fi link does not, by itself, prove that the PC or the wider internet is reachable. Rt:Stream health checks are shown separately.

### Rt:Stream and server

When a host is configured, the panel checks the PC portal's library endpoint and Sunshine's server-info endpoint. It distinguishes:

- **ONLINE** — the endpoint responded successfully.
- **OFFLINE** — the endpoint check failed.
- **CHECKING** — the health request is still running.
- **NOT CONFIGURED** — no Rt:Stream host is configured.
- **UNKNOWN** — no trustworthy result is available yet.

The panel does not invent an online state when the host has not been configured.

### Data Center

The local state of these downloaded databases is shown separately:

| Entry | Local data |
|---|---|
| Compatibility Database | `data/games_data.json` |
| GameSettings Database | `data/gamesettings.json` |
| Cheats & Boost Data | `data/rtcheats_db.json` |

Possible labels include **UPDATED** (downloaded this boot), **CACHED** (a local copy exists), **PREVIOUS COPY** (the latest update failed but an earlier local copy was retained), **DOWNLOADING**, **MISSING** and **NOT CHECKED**.

The GameSettings deployment status and indexed Games Library count are shown as separate steps. A downloaded database is not the same thing as deployed presets.

### Operations and notifications

Background operations can publish a name, detail and progress bar. The notification history is listed newest first.

| Control | Action |
|---|---|
| **↑ / ↓** | Move through selectable entries |
| **← / →** | Scroll by a page |
| **A** | Remove the selected notification from history |
| **X** | Clear active toasts and the notification history |
| **M / B** | Close the panel |

Only notification entries have an action on **A**. Status rows are informational.

## Reading the status correctly

- **CACHED** is healthy when the local copy is valid; it does not claim that the remote copy was checked successfully this boot.
- **PREVIOUS COPY** means Rt:Core retained the local file after an update failure.
- **OFFLINE** for Portal or Sunshine is a remote service check, not a statement about Wi-Fi carrier.
- A blank or unavailable battery reading means the kernel did not expose a supported power-supply device.

When reporting an issue, include the exact device, muOS version, Rt:Core package version and relevant log excerpts. Redact SSIDs, hostnames, IP addresses, tokens and device identifiers when they are private.
