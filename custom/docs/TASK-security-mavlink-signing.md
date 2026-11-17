# Task: MAVLink 2 signing in alesQGC (+ the other CE RED / EN 18031 items)

**Status 2026-11-17:** MAVLink signing done (commits 53681aca4 core, 9b72e32ac Simple UI; see CLAUDE.md for the
SITL facts). Open: S67 "Delete my data" calls `linkSecurity.forgetLocalKey()` (exists, no UI yet), S65 security log
row, Android Keystore for the key, and "Other CE RED items" 3-5 below.
Done 2026-11-17: item 1 (3851bb2e8, the user changes the account password at the provider: it stays in git history),
`src/Utilities/SecureStore` (DPAPI, 65ba15a6d), item 2 (a8bd0f21d: TOFU certificate pin `doodlePin/<ip>`, own radio
password via ubus `rpc-sys password_set` kept in SecureStore `doodle/<ip>`, S66 radio rows; not tested on a radio).

Hand-off note for a Claude Code session (written 2026-11-16 by the claude.ai session that drew the Figma screens).
Read `CLAUDE.md` first. Reply to the user in Korean. **Figma is the source of truth**; if this note and Figma disagree,
ask the user.

## Why

CE RED Art. 3.3(d)(e) (Delegated Reg. 2022/30, harmonised standards EN 18031-1/-2) applies to radio equipment placed on
the EU market from 2025-08-01 until 2027-12-10; the Cyber Resilience Act takes over on 2027-12-11. EN 18031 asks for
protected communication with the drone (SCM), authenticated access to network/security assets (AUM/ACM), protected
storage of secrets (SSM), secure updates (SUM), logging (LGM) and deletion of personal data (DLM, part 2).
Today alesQGC has **no MAVLink signing**: anyone on the radio/UDP network can inject commands. The user asked
(2026-11-16): "현재 alesQGC에는 MAVLink 서명 기능이 없습니다 → 기능을 넣어 주세요".

## Figma (file AQGC-simpler, key `p7d3GuBZaJNSj8zpBUlaSj`, page `01 Screens`)

| Screen | What it needs from this task |
|---|---|
| **S66** Settings › Connection › Link security (node `119:39331`) | Row "Drone control link · MAVLink": status chip (Protected / Not protected / Key mismatch), key fingerprint and date, button "Change key" (set / change / remove). Other rows: see "Other items" below. UX note `119:39506`. |
| **S22** Connection (node `20:16374`) | New card "Link security" (node `119:39692`): one-line summary + link to S66. |
| **S27** Link details (panel `23:20564`) | Row "Link protection" (node `119:39696`): "Signed (MAVLink)" / orange "Not protected" / red "Key mismatch". |
| **S65** Security & privacy (node `118:39104`) | "Accounts and keys" includes the link key; "Security log" lists key set / changed / removed. |
| **S67** Delete my data (node `118:39319`) | Deleting "Accounts and keys" also deletes the link key (warn: drone link must be paired again). |
| 00 Overview **§10** (node `120:2`) | Security UI rules (masking, no skip-password, colours, logging). |

Colour rule (§10): green = protected, orange = action needed, blue = information that cannot be changed.
Status colours only on chips / icons / backgrounds, text uses `text/link` or `text/danger`.

## Behaviour (decided here; confirm with the user only if something cannot be built this way)

1. **One app key** (32 random bytes from `QRandomGenerator::system()`), shared by all drones paired with this app.
   Show only a fingerprint: first 4 + last 4 hex of SHA-256(key), e.g. `4F2A…9C1D`, and the date it was set.
   Never show, log or export the key itself.
2. **Pairing only over USB** (a `SerialLink` on a USB port), drone disarmed. Over the radio the key would travel in clear,
   so on any other link the button explains "Connect the drone with a USB cable to set the key" (update the S66 UX note,
   which still says "USB or radio"). Send `SETUP_SIGNING` (msg 256) to the vehicle with the key and
   `initial_timestamp` = now in MAVLink signing units (10 µs since 2015-01-01 00:00 UTC). Then turn signing on for
   every open channel. Confirm success by receiving signed messages from that vehicle within a few seconds; otherwise show
   the S66 row in orange "Drone did not accept the key".
3. **Remove key**: send `SETUP_SIGNING` with an all-zero key and timestamp 0 (ArduPilot disables signing), then delete the
   local key. Also over USB only. "Delete my data › Accounts and keys" (S67) deletes the local key only and warns.
4. **Outgoing**: when a key exists, every channel signs outgoing MAVLink 2 packets
   (`MAVLINK_SIGNING_FLAG_SIGN_OUTGOING`). A drone without a key ignores the signature, so this is safe for unpaired drones.
   MAVLink 1 links are not signed (library behaviour) → show "Not protected".
5. **Incoming** (per channel):
   - Until the first correctly signed packet arrives, accept unsigned packets (unpaired drone) → state **Not protected**.
   - After the first correctly signed packet from the vehicle, reject unsigned packets on that channel
     (`accept_unsigned_callback` returns false) except `RADIO_STATUS` (109) and `RADIO` (166), which radios insert unsigned
     → state **Protected**.
   - Bad signature / bad timestamp (`mavlink_signing_t.last_status`) → state **Key mismatch** (red), keep rejecting.
6. Status is per link; the UI shows the active vehicle's primary link. Fly screen: the link chip gets an orange dot when
   the link is not protected **and** a key exists (paired fleet, wrong/unpaired drone). Without any key: no fly-screen
   warning, only S66 / S27 say "Not protected" (do not alarm users who never paired).
7. **Key storage**: Windows = DPAPI (`CryptProtectData`, current user) → base64 in QSettings; Android = Android Keystore
   (wrap the key with a Keystore AES key via JNI) — if that is too large for this task, store in the app-private
   QSettings and add a TODO + tell the user (Android app storage is per-app private, but not a keystore). Linux/debug:
   QSettings with a warning in the log. Never in the exported settings or the app log.
8. **Security log** (S65): write one line per event (key set / changed / removed / drone refused key / key mismatch seen,
   with time and vehicle id, never the key) to a rotating file next to the app log, e.g. `<app data>/security.log`.
   The S65 "Security log" row can come later; the file must exist now.
9. Simple and Advanced mode both use this (it is not a UI-mode feature). Classic Advanced screens need no change.

## Where to hook in (paths in this repo)

- `src/comm/QGCMAVLink.h` — `MAVLINK_EXTERNAL_RX_STATUS`; status array `m_mavlink_status[]` lives in `src/QGCApplication.cc:170`.
  The bundled `libs/mavlink/include/mavlink/v2.0/mavlink_helpers.h` already has signing (`mavlink_sign_packet`,
  `mavlink_signature_check`, `accept_unsigned_callback`); `MAVLINK_NO_SIGN_PACKET` / `MAVLINK_NO_SIGNATURE_CHECK` are not
  defined, keep it so. `common/mavlink_msg_setup_signing.h` exists.
- New core helper, e.g. `src/comm/MAVLinkSigning.h/.cc` (small, no UI): static `mavlink_signing_t` per channel + one shared
  `mavlink_signing_streams_t`; `initChannel(chan, key)`, `clearChannel(chan)`, `channelState(chan)`, the accept-unsigned
  callback, timestamp helper, SETUP_SIGNING packing. Add to `qgroundcontrol.pro` (and CMakeLists if kept in sync).
- `src/comm/LinkManager.cc` `allocateMavlinkChannel()` (~line 899): after `mavlink_reset_channel_status`, call
  `initChannel` when a key exists (`reset` clears `status->signing`, so do it after). `freeMavlinkChannel` → `clearChannel`.
- `src/comm/MAVLinkProtocol.cc` `receiveBytes()` (~line 196): after a packet is decoded check
  `_message.incompat_flags & MAVLINK_IFLAG_SIGNED` to move the channel to Protected; after the loop read
  `signing->last_status` to detect Key mismatch. Emit a signal (or let the helper emit) so QML updates.
- Outgoing: QGC packs with `mavlink_msg_*_pack_chan(..., link->mavlinkChannel(), ...)`, which signs through the channel
  status. **Grep for packs that do not use the link's channel** (`_pack(` without `_chan`, or a fixed channel) and fix them,
  or those messages go out unsigned and a protected drone drops them. Also check MAVLink forwarding (`forwardMavlink`) and
  log replay (must not sign / must not require signatures).
- QML access: expose a small QObject (key present, fingerprint, set date, per-link state, `pair()`, `remove()`,
  `canPair` + reason) the same way the custom plugin exposes others (`custom/src/CustomPlugin.cc` uses
  `qmlRegisterSingletonInstance` / context property `CustomQmlInterface`).
- UI: S66 page in `custom/res/Simple/SimpleSettings.qml` (Connection category; it already has the S22 cards),
  S27 row in the link chip detail (`SimpleChipDetail.qml`), fly-screen chip dot in `SimpleTopBar.qml`.
  New QML files → `custom/custom.qrc` (prefix `/simple`) **and** `custom/res/Simple/qmldir`.

## ArduPilot facts to verify on SITL before relying on them

ArduPilot (company firmware Z01.07.00EASA, SITL in WSL per CLAUDE.md) supports MAVLink 2 signing:
`SETUP_SIGNING` stores the key in FRAM/flash and activates it on all links; an all-zero key disables signing; once a key
is set, unsigned packets are rejected except on the first serial port (USB) and some radio messages.
**Verify each of these on SITL** (which SITL port counts as "USB", whether `SETUP_SIGNING` itself must be signed once a
key exists, what happens to `RADIO_STATUS`) and write the results into CLAUDE.md "Gotchas".

## Tests

1. Unit test for the helper (key → fingerprint, timestamp units, accept-unsigned rules, state changes), next to the
   existing Simple tests (`custom/tests/simple/README.md`).
2. SITL: unpaired → "Not protected", commands work. Pair over the USB-equivalent port → "Protected" on all links,
   take off / RTL / mission upload still work (all outgoing packets signed). Inject an unsigned COMMAND_LONG from a
   second tool on the UDP link → drone ignores it. Remove key → back to "Not protected". Wrong key in the app →
   "Key mismatch" red, no control.
3. MockLink: does not sign; must still connect (state Not protected), no crash.
4. Restart the app → key loaded, channels signed again, timestamps keep increasing (no "bad timestamp" after restart).
5. Classic Advanced screens still connect and fly.

Done = S66 MAVLink row, S22 card, S27 row and the fly-screen dot work as in Figma; tests above pass; CLAUDE.md updated
(decision + gotchas); PR #311 description updated; CI green.

## Other CE RED items found in the code (separate commits, after signing — or before, they are small)

1. **Hard-coded NTRIP caster account** in `custom/src/RTCM/NTRIPRTCMSource.cpp` (`get_caster_xml`, Basic auth header).
   Remove it; fetch the caster table without credentials or with the user's own NTRIP account. Do not copy the value
   anywhere (commit message, logs, docs). Tell the user so the account password can be changed at the provider.
2. **Doodle Labs radio** (`custom/src/ARLink/ARManager.cpp`): logs in with the factory account and turns TLS peer
   verification off. Design (S66 "Radio password"): orange "Change needed" while the factory password works, Change button
   (ground only), per-device password in secure storage, pin the radio certificate instead of `VerifyNone`, no "skip".
3. **Secrets in plain QSettings**: NTRIP `passwd`, Altitude Angel key and other keys → same secure storage as the link
   key; mask in UI (STextField `password: true` already exists); never log them.
4. **NTRIP over plain TCP + Basic auth**: S66 shows "Not encrypted"; add the TLS switch only if the caster supports it.
5. **S69 Devices** (open services, defaults off), **S65/S67** (data list, delete my data, location sharing off by
   default, security log), **S68** (firmware: signed files only, no downgrade). Values on the S65 mock (support period,
   security contact) are examples: ask the user for the real ones.

## Also pending (same branch, coordinate)

- No PIN for Advanced mode (user 2026-11-16): remove the S12 PIN dialog, `SimplePinHash.h` use and the Change PIN row;
  the Advanced mode state is kept over restarts. Full list of files: `TASK-advanced-mode-redesign.md` › Decisions.
- Advanced mode redesign S44, S58–S80: confirmed for code by the user 2026-11-17 ("인계 문서대로 모두"), after this task.
