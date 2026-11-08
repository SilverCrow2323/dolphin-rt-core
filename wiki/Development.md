# Development

Install the tools needed by the component: Git, Python 3, LuaJIT/Lua, LÖVE 11.5 and (for headless rendering) Xvfb/Mesa. Pillow is optional for image contact sheets.

Clone the repository:

```sh
git clone https://github.com/SilverCrow2323/dolphin-rt-core.git
cd dolphin-rt-core
```

Read the target platform's README, changelog and build scripts before editing. Use disposable HOME/data directories for tests; never run destructive tests against a real SD card or Dolphin configuration.

For details see [docs/DEVELOPMENT.md](https://github.com/SilverCrow2323/dolphin-rt-core/blob/main/docs/DEVELOPMENT.md).
