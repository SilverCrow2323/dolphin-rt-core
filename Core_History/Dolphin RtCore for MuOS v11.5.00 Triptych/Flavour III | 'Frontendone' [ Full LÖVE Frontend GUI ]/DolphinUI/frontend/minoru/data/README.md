# Minoru⁶ — data directory

This folder holds Minoru's runtime state. It is written to from
`persona.lua`, `history.lua` and `workspace.lua`. Deleting any file
here resets the corresponding layer to factory defaults; the module
regenerates them on next boot.

| File             | Written by       | Purpose                                         |
|------------------|------------------|-------------------------------------------------|
| persona.json     | persona.lua      | Learned traits (sarcasm, patience, curiosity…)  |
| history.json     | history.lua      | Sessions + last N events (bounded at 250)       |
| workspace.json   | workspace.lua    | Persisted focus / progress of virtual tasks     |

Nothing here is required to be present. A brand new install boots
Minoru with default traits, empty history and a freshly seeded
workspace. He "grows into" the install over sessions.