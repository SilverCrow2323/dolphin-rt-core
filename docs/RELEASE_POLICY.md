# Stable release policy

## Build is not publication

The native muOS Andromeda workflow may run on a main push or pull request to validate the H700/AArch64 executable, private runtime ABI, MUXUPD contents, Rt:UI smoke tests and related packaging. Successful CI artifacts are review material only.

## Explicit publication

The stable GitHub Release step runs only when all of the following are true:

1. the workflow was started manually with `workflow_dispatch`;
2. the operator explicitly selected `publish_release=true` (the default is `false`);
3. the run targets the canonical `SilverCrow2323/dolphin-rt-core` repository.

A main push, pull request, successful build, or uploaded CI artifact is never by itself permission to publish or overwrite a release.

## Hardware boundary

CI validates software builds and package structure. It does not establish performance, game compatibility, input feel, thermals, audio or stability on a physical H700 handheld. Stable release notes must not imply device testing that has not been recorded.
