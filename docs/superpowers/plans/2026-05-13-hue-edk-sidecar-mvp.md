# Hue EDK Sidecar MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a private Hue EDK sidecar service MVP with a stable HTTP API that `nas-relay` can call for CS2 lighting.

**Architecture:** Start with a standalone sidecar repository at `/Users/charm/Documents/workspace/HueEdkSidecar`. The first implementation uses a tested in-memory backend that preserves the future EDK boundary; the backend can later be swapped for the native Hue EDK runtime without changing the relay contract. Hue EDK itself remains an external private checkout referenced by `HUE_EDK_ROOT`, so no EDK source is copied into either repository.

**Tech Stack:** Node.js ESM, built-in `node:http`, built-in `node:test`, no public EDK files in `SonosWidget`.

---

## File Structure

- Create `/Users/charm/Documents/workspace/HueEdkSidecar/package.json`: package scripts for `npm test` and `npm start`.
- Create `/Users/charm/Documents/workspace/HueEdkSidecar/src/contracts.js`: request validation and safe DTO shaping.
- Create `/Users/charm/Documents/workspace/HueEdkSidecar/src/backend.js`: backend interface plus memory implementation.
- Create `/Users/charm/Documents/workspace/HueEdkSidecar/src/edkBuildConfig.js`: EDK CMake build configuration and local compatibility patches.
- Create `/Users/charm/Documents/workspace/HueEdkSidecar/src/server.js`: HTTP router for health, configure, session, and CS2 MVP effects.
- Create `/Users/charm/Documents/workspace/HueEdkSidecar/src/index.js`: process entrypoint.
- Create `/Users/charm/Documents/workspace/HueEdkSidecar/scripts/build-edk.js`: private EDK build wrapper using `HUE_EDK_ROOT`.
- Create `/Users/charm/Documents/workspace/HueEdkSidecar/test/server.test.js`: black-box HTTP tests.
- Create `/Users/charm/Documents/workspace/HueEdkSidecar/test/edkBuildConfig.test.js`: CMake option and compatibility-patch tests.
- Create `/Users/charm/Documents/workspace/HueEdkSidecar/README.md`: private-repo usage and EDK integration boundary.

## Tasks

### Task 1: Sidecar API Skeleton

- [x] **Step 1: Write failing HTTP tests**

Expected coverage:

```js
test('health starts unconfigured and hides credentials', async () => {});
test('configure stores Hue runtime values without echoing secrets', async () => {});
test('effect routes require configuration', async () => {});
test('ambient and effects auto-start the session once configured', async () => {});
```

- [x] **Step 2: Run tests and verify failure**

Run:

```bash
npm test
```

Expected: tests fail because the sidecar files do not exist yet.

- [x] **Step 3: Implement minimal sidecar service**

Implement the HTTP routes:

```text
GET  /health
POST /configure
POST /session/start
POST /session/stop
POST /ambient/team
POST /effect/flash
POST /effect/kill
```

- [x] **Step 4: Run tests and verify pass**

Run:

```bash
npm test
```

Expected: all sidecar tests pass.

### Task 2: Native EDK Backend Adapter

- [x] **Step 1: Install build prerequisites**

Install or provide CMake for local native builds. The current Mac shell reports `cmake: command not found`.

- [x] **Step 2: Reference a private EDK checkout from the sidecar build**

Reference the Hue EDK repo through `HUE_EDK_ROOT`. Do not copy EDK source into `SonosWidget` or `HueEdkSidecar`.

Current local build command:

```bash
HUE_EDK_ROOT=/path/to/private/EDK npm run build:edk -- --build-dir ./build/edk --jobs 8
```

The wrapper follows the README build flow (`cmake ..`, then `cmake --build .`) and applies local compatibility patches needed by the current macOS/Xcode/CMake toolchain before building `huestream`.

- [x] **Step 2a: Verify the EDK build wrapper against a real private checkout**

Run:

```bash
HUE_EDK_ROOT=/tmp/hue-edk-sidecar-reference/EDK npm run build:edk -- --build-dir /tmp/hue-edk-sidecar-reference/build --clean --jobs 8
```

Expected: CMake builds `bin/libhuestream.a` and ends with `Built target huestream`.

- [x] **Step 3: Implement EDK backend behind the existing interface**

Map sidecar calls to EDK concepts:

```text
/configure      -> Config + bridge credentials + selected entertainment area
/session/start  -> HueStream Start
/session/stop   -> HueStream Stop
/ambient/team   -> low-layer AreaEffect
/effect/flash   -> high-layer white effect with quick attack and slow release
/effect/kill    -> short burst effect
```

- [x] **Step 3a: Build and smoke-test the native worker**

Run:

```bash
HUE_EDK_ROOT=/tmp/hue-edk-sidecar-reference/EDK npm run build:native -- --build-dir /tmp/hue-edk-sidecar-reference/native-build --jobs 8
printf 'start\n' | /tmp/hue-edk-sidecar-reference/native-build/hue-edk-worker
```

Expected: the native worker builds and protocol errors return `ERR ...` without terminating the process.

- [ ] **Step 4: Run fake backend tests plus manual bridge smoke test**

The HTTP contract tests stay backend-independent. Manual bridge tests verify the native backend.

### Task 3: Relay Integration

- [x] **Step 1: Add `nas-relay` sidecar client tests**

Verify renderer selection from:

```text
HUE_RENDERER=edk-sidecar
HUE_EDK_SIDECAR_URL=http://hue-edk-sidecar:8787
```

- [x] **Step 2: Implement sidecar renderer client**

`nas-relay` sends existing Hue config to `/configure`, starts the session when CS2 is active, and maps flash/kill/ambient decisions to sidecar commands.

- [x] **Step 3: Preserve current fallback behavior**

Music ambience continues using the built-in renderer. CS2 still refuses CLIP fallback.

- [x] **Step 4: Run focused relay tests**

Run:

```bash
cd /Users/charm/Documents/workspace/SonosWidget/nas-relay
npm test
```
