# Changelog

## v0.1.0-beta.1 — 2026-10-30

First public beta of the standalone Bigme frontlight compatibility patch.

- Connects normal KOReader/PowerD light controls, including OrbitUI callers,
  to the verified cold/warm driver requests and nonlinear 37-level OEM table.
- Reads existing settings without light writes during loading; synchronizes
  successful changes with Bigme's own stored channel values.
- Remembers both channels for off/on, with strict profile validation.
- Restricts activation to the verified `hibreak_eea` / `mt6877` / Android arm64
  profile with existing WRITE_SETTINGS access. No root or permission changes.
- Checks native/JNI failures, closes descriptors, cleans references/exceptions
  and prevents light/JNI calls from forked thumbnail workers.
- Includes English/Swedish instructions, warnings, MIT license and tests.
- The identical Lua file is distributed through Ereader Patch Manager's normal
  Ereader catalogue synchronization; no plugin update is needed.

Verification: 60 automated Lua/LuaJIT cases against pinned actual KOReader
PowerD/widget sources, plus four real-FFI cases against a harmless host C fixture.
No real hardware/JNI/user data is accessed by those tests. Earlier separate
device tests confirmed cold 12→26→12 and warm 13→30→13, including physical
restoration. **The integrated beta, full range and lifecycle still need physical
acceptance.** Keep Bigme's Android panel available; disable old diagnostics.

### Svenska

Första publika betan: vanliga ljusreglage, separata kall-/varmkanaler, synkade
OEM-värden och på/av med återställning. Begränsad till den verifierade profilen,
utan root eller ändrade behörigheter. Svensk/engelsk dokumentation och varningar.
Installeras också genom vanlig Ereader Patch Manager-synkronisering och omstart.
60 automatiska fall samt fyra FFI-fall passerar. Separata hårdvaruprov är godkända,
men **den färdiga betan behöver fortfarande testas på enheten**.
