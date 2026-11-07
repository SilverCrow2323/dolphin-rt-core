# Library server protocol

The portal (or `spdw-stream serve`) runs a small HTTP server, default port **8765**. It is intentionally tiny: anything
not listed here answers `404`.

## Public, read-only

| Request | Answer |
|---|---|
| `GET /` or `GET /library.tsv` | the game list |
| `GET /covers/<file>.png` | cover art (paths containing `..` are refused) |
| `GET /profiles.tsv` | controller profiles and the active ones |

### `library.tsv`
UTF-8, tab separated, `#` lines are comments.
```
# kind	title	app	cover	id	rom
gc	Star Racer	GC - Star Racer	covers/DEM001.png	DEM001	/games/Star_Racer.iso
```
| Column | Meaning |
|---|---|
| kind | `gc` or `wii` |
| title | display name (tabs and quotes removed) |
| app | Sunshine app name — passed to `moonlight stream -app` |
| cover | path relative to the server root, may be empty |
| id | 6-character game ID, may be empty |
| rom | (core only) PC path; the handheld ignores it |

### `profiles.tsv`
```
# profiles.tsv v1
@active	GCPad	muos
@active	Wiimote	muos
@active	Hotkeys	muos
GCPad	muos	Buttons/A	SOUTH
GCPad	muos	Main Stick/Up	`Axis 1-`
...
```
`@active<TAB>kind<TAB>name` lines first, then `kind<TAB>profile<TAB>key<TAB>value` rows. The `Device` key is omitted.

## Authenticated: `GET /ctl`

Query parameters: `token`, `op`, `kind`, `profile`, plus `key` and `value` for `op=set`.

| `op` | Effect |
|---|---|
| `set` | change one **existing** key of a `muos*` profile |
| `active` | make `profile` the active one of `kind` (any listed profile) |
| `reset` | restore a packaged `muos*` profile |

Answer: always HTTP 200 and a single text line starting with `OK` or `ERR`:
```
OK Buttons/Z: THUMBR -> TL (applies at the next game launch)
ERR bad token
ERR unknown key
ERR only muos* profiles can be edited
ERR bad value
```

### Validation
| Field | Rule |
|---|---|
| token | compared case-insensitively with a constant-time check; a wrong token costs the caller one second |
| kind | `GCPad`, `Wiimote` or `Hotkeys` |
| profile (for `set`/`reset`) | `^muos[A-Za-z0-9_-]{0,24}$` |
| key | `^[A-Za-z0-9 +\-/_.]{1,60}$` **and** already present in the profile — new keys cannot be created |
| value | `^[A-Za-z0-9 +\-&`._/=,]{1,80}$` — no newline, `$`, `;`, quotes |

## Security model

- Plain HTTP on the local network. Do not forward the port to the Internet; use Tailscale or WireGuard for remote play.
- Reading is open to anyone who can reach the port (game titles, cover art, mapping names). Writing needs the token.
- The token is 10 characters from a 32-letter alphabet (~50 bits). Rotate it from the portal (SYSTEM ▸ NEW TOKEN) or
  `spdw-stream token new`; the handheld stores it in `conf/stream.conf` (`TOKEN`).
- The server never serves `config.json`, ROM paths outside `library.tsv`, or anything outside `library.tsv`, `profiles.tsv`, `covers/`.
- Even with a valid token a client can only modify files of the `muos*` family inside Dolphin's `Profiles/` folder; the
  active-profile switch only stores a name in `config.json`. Dolphin's own ini files are written by `profiles apply`
  on the PC, right before a game launches.

## Handheld scripts

| Script | Calls |
|---|---|
| `tools/sync.sh` | `/library.tsv`, `/covers/*`, then `profiles.sh` |
| `tools/profiles.sh` | `/profiles.tsv` → `conf/profiles.tsv`, touches `conf/profiles.done` |
| `tools/ctl.sh "<query>"` | `/ctl?token=...&<query>` → `conf/ctl.result` |
| `tools/test.sh` | ping, `/library.tsv`, Sunshine `:47989/serverinfo`, pairing keys |
| `tools/pair.sh` | `moonlight pair` → `conf/pair.log` (PIN shown by the GUI) |
