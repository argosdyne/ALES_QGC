# Payload MAVLink Interface for MQTT Bridge

This document defines the MAVLink commands currently used by QGC to control the
Gremsy Lynx and NextVision DragonEye2 payloads. It is intended for a separate
team that receives MQTT commands and converts them to MAVLink over UDP.

The values below match the current implementation in:

- `src/Payload/GremsyLynxPayloadController.*`
- `src/Payload/NextVisionPayloadController.*`
- `src/Payload/PayloadController.*`

## Common conventions

### Normalized command input

Use this normalized payload-control model on the MQTT side:

```json
{
  "payload": "gremsy_lynx",
  "command": "gimbal_axis",
  "pan": 0.0,
  "tilt": 0.0
}
```

Field meanings:

| Field | Range | Meaning |
|---|---:|---|
| `pan` | `-1.0..+1.0` | `-1` left, `0` hold, `+1` right |
| `tilt` | `-1.0..+1.0` | `-1` down, `0` hold, `+1` up |
| `speed` | device-specific | Optional speed scale |
| `direction` | `-1.0..+1.0` | Zoom direction: `-1` wide, `0` stop, `+1` tele |

Clamp all MQTT numeric inputs before encoding MAVLink. Do not send NaN from MQTT
input; NaN is only used internally in specific MAVLink fields documented below.

### MAVLink framing

Use MAVLink v2 framing if available. All messages in this document are standard
MAVLink common messages.

Connection status should be based on inbound payload/autopilot traffic. QGC marks
the link connected only after it receives a valid MAVLink message and times out
the link after 3 seconds without inbound MAVLink.

## Gremsy Lynx

### Network

| Item | Value |
|---|---|
| Default IP | `192.168.2.240` |
| UDP target port | `14566` |
| Local bind port | Ephemeral is OK |
| RTSP URL | `rtsp://192.168.2.240:8554/payload` |

Gremsy is controlled directly over UDP. Do not route these commands through the
vehicle autopilot unless you intentionally use the legacy vehicle-link fallback.

### MAVLink identity

| Role | Value |
|---|---|
| Sender system id | `1` |
| Sender component id | `MAV_COMP_ID_ONBOARD_COMPUTER` = `191` |
| Default target system id | `1` |
| Default gimbal component id | `MAV_COMP_ID_GIMBAL` = `154` |
| Default camera component id | `MAV_COMP_ID_CAMERA2` = `101` |

The bridge should learn actual target ids from inbound MAVLink:

- If inbound component id is in `MAV_COMP_ID_GIMBAL..MAV_COMP_ID_GIMBAL6`,
  update `target_system` and gimbal component id from that message.
- If inbound component id is in `MAV_COMP_ID_CAMERA..MAV_COMP_ID_CAMERA6`,
  update camera component id from that message.

### Keepalive

Send `HEARTBEAT` (`msgid=0`) at 1 Hz.

| Field | Value |
|---|---|
| `type` | `MAV_TYPE_ONBOARD_CONTROLLER` |
| `autopilot` | `MAV_AUTOPILOT_INVALID` |
| `base_mode` | `0` |
| `custom_mode` | `0` |
| `system_status` | `MAV_STATE_ACTIVE` |

### Gimbal rate control

Send `GIMBAL_DEVICE_SET_ATTITUDE` (`msgid=284`) at 10 Hz while the link is
active. QGC resends the current setpoint every 100 ms.

MQTT input:

```json
{
  "payload": "gremsy_lynx",
  "command": "gimbal_axis",
  "pan": 0.5,
  "tilt": -0.25,
  "speed_deg_s": 50
}
```

Mapping:

```text
speed_deg_s = clamp(speed_deg_s or 50, 1, 90)
pitch_deg_s = clamp(tilt, -1, 1) * speed_deg_s
yaw_deg_s   = clamp(pan,  -1, 1) * speed_deg_s
roll_deg_s  = 0

angular_velocity_x = radians(roll_deg_s)
angular_velocity_y = radians(pitch_deg_s)
angular_velocity_z = radians(yaw_deg_s)
```

Message fields:

| Field | Value |
|---|---|
| `target_system` | Learned/default Gremsy system id |
| `target_component` | Learned/default gimbal component id |
| `flags` | Mirror latest `GIMBAL_DEVICE_ATTITUDE_STATUS.flags`; default `ROLL_LOCK | PITCH_LOCK` |
| `q[0..3]` | All `NaN` to command rate only |
| `angular_velocity_x` | Roll rate, rad/s |
| `angular_velocity_y` | Pitch rate, rad/s |
| `angular_velocity_z` | Yaw rate, rad/s |

Stop motion by sending the same message with all angular velocities set to `0`.
Keep sending zeros for at least several cycles so the payload receives the stop.

### Gimbal home

QGC homes the Gremsy by setting the Gremsy `GB_MODE` parameter.

Send `PARAM_EXT_SET` (`msgid=323`).

| Field | Value |
|---|---|
| `target_system` | Learned/default Gremsy system id |
| `target_component` | Learned/default camera component id (`101` by default) |
| `param_id` | `GB_MODE` |
| `param_value` | `uint32` little-endian value `4` |
| `param_type` | `MAV_PARAM_EXT_TYPE_UINT32` |

The value `4` is the Gremsy payload mode used by QGC for reset/home.

MQTT input:

```json
{
  "payload": "gremsy_lynx",
  "command": "gimbal_home"
}
```

### Zoom

Send `COMMAND_LONG` (`msgid=76`) with `MAV_CMD_SET_CAMERA_ZOOM` (`531`).

| Field | Value |
|---|---|
| `target_system` | Learned/default Gremsy system id |
| `target_component` | Learned/default camera component id |
| `command` | `MAV_CMD_SET_CAMERA_ZOOM` = `531` |
| `confirmation` | `0` |
| `param1` | `ZOOM_TYPE_CONTINUOUS` = `1` |
| `param2` | Direction: `-1.0` wide, `0.0` stop, `+1.0` tele |
| `param3..param7` | `0` |

MQTT input examples:

```json
{ "payload": "gremsy_lynx", "command": "zoom", "direction": 1.0 }
{ "payload": "gremsy_lynx", "command": "zoom", "direction": -1.0 }
{ "payload": "gremsy_lynx", "command": "zoom", "direction": 0.0 }
```

### Telemetry to consume

Use these inbound messages for status:

| Message | ID | Use |
|---|---:|---|
| `GIMBAL_DEVICE_ATTITUDE_STATUS` | `285` | Update connected state, mirror `flags`, decode quaternion to roll/pitch/yaw |
| `HEARTBEAT` | `0` | Component discovery / link activity |
| `COMMAND_ACK` | `77` | Optional command result logging |
| `PARAM_EXT_ACK` | `324` | Optional `GB_MODE` result logging |

## NextVision DragonEye2

### Network

| Item | Value |
|---|---|
| Default IP | `192.168.2.28` |
| UDP target port | `10038` |
| Local bind port | `10038` |
| RTSP URL | `rtsp://192.168.2.28:554/video0` |

NextVision pan/tilt is controlled through the ArduPilot interface by streaming
`RC_CHANNELS_OVERRIDE`.

### MAVLink identity

| Role | Value |
|---|---|
| Sender system id | `255` |
| Sender component id | `MAV_COMP_ID_MISSIONPLANNER` = `190` |
| Default target system id | `1` |
| Default target component id | `1` |

Important: sender system id must match ArduPilot `SYSID_MYGCS`. The current rig
uses `SYSID_MYGCS=255`, which is why QGC sends as system id `255`. If this does
not match, ArduPilot may silently ignore RC override messages.

Learn `target_system` and `target_component` from inbound `HEARTBEAT` messages
where `component_id != 190`.

### Keepalive and telemetry request

Send `HEARTBEAT` (`msgid=0`) at about 1 Hz.

| Field | Value |
|---|---|
| `type` | `MAV_TYPE_GCS` |
| `autopilot` | `MAV_AUTOPILOT_INVALID` |
| `base_mode` | `0` |
| `custom_mode` | `0` |
| `system_status` | `MAV_STATE_ACTIVE` |

Send `REQUEST_DATA_STREAM` (`msgid=66`) at about 0.5 Hz.

| Field | Value |
|---|---|
| `target_system` | Learned/default target system id |
| `target_component` | Learned/default target component id |
| `req_stream_id` | `0` (`MAV_DATA_STREAM_ALL`) |
| `req_message_rate` | `5` Hz |
| `start_stop` | `1` |

### Pan/tilt control

Send `RC_CHANNELS_OVERRIDE` (`msgid=70`) every 40 ms, about 25 Hz. ArduPilot
times out RC override if it is not streamed continuously.

MQTT input:

```json
{
  "payload": "nextvision",
  "command": "gimbal_axis",
  "pan": 0.5,
  "tilt": -0.25,
  "offset": 400
}
```

Mapping:

```text
offset = clamp(offset or 400, 50, 500)
ch1 = clamp(1500 + pan  * offset, 1000, 2000)  # pan/yaw
ch2 = clamp(1500 + tilt * offset, 1000, 2000)  # tilt/pitch
```

Message fields:

| RC channel field | Value |
|---|---|
| `chan1_raw` | Pan/yaw PWM |
| `chan2_raw` | Tilt/pitch PWM |
| `chan3_raw..chan8_raw` | `0xFFFF` (ignore) |
| `chan9_raw..chan18_raw` | `0` (ignore / unused in current QGC code) |

Idle behavior:

1. When both axes return to center, keep sending `1500,1500` for 12 ticks
   (about 480 ms at 25 Hz).
2. After that, set `chan1_raw=0xFFFF` and `chan2_raw=0xFFFF` so ArduPilot stops
   overriding those channels and the gimbal holds using its own stabilization.

Stop motion:

```json
{
  "payload": "nextvision",
  "command": "gimbal_axis",
  "pan": 0,
  "tilt": 0
}
```

### Telemetry to consume

Use these inbound messages for status:

| Message | ID | Use |
|---|---:|---|
| `HEARTBEAT` | `0` | Learn target system/component and mark link active |
| `ATTITUDE` | `30` | QGC treats `pitch` as elevation and `yaw` as LOS azimuth |

Decode `ATTITUDE.pitch` and `ATTITUDE.yaw` from radians to degrees.

## Suggested MQTT contract

The MQTT team can use different topics, but the payload command body should map
cleanly to the normalized commands below.

### Topics

```text
payload/{payload_id}/cmd
payload/{payload_id}/status
```

Where `payload_id` is:

- `gremsy_lynx`
- `nextvision`

### Command payloads

Connect/disconnect:

```json
{ "command": "connect", "ip": "192.168.2.240" }
{ "command": "disconnect" }
```

Gimbal axis:

```json
{ "command": "gimbal_axis", "pan": 0.0, "tilt": 0.0 }
```

Gimbal discrete move:

```json
{ "command": "gimbal_move", "pan": 1, "tilt": 0 }
```

The bridge should translate discrete move to axis values `-1`, `0`, or `+1`.

Gimbal home:

```json
{ "command": "gimbal_home" }
```

Currently implemented for Gremsy. For NextVision, treat as unsupported unless a
separate NextVision home command is added.

Zoom:

```json
{ "command": "zoom", "direction": 1.0 }
{ "command": "zoom", "direction": -1.0 }
{ "command": "zoom", "direction": 0.0 }
```

Currently implemented for Gremsy. For NextVision, zoom is not implemented in the
current `PayloadController` path.

### Status payload

Recommended status message:

```json
{
  "payload": "gremsy_lynx",
  "connected": true,
  "ip": "192.168.2.240",
  "rtsp_url": "rtsp://192.168.2.240:8554/payload",
  "pitch_deg": 0.0,
  "roll_deg": 0.0,
  "yaw_deg": 0.0
}
```

For NextVision, omit `roll_deg` because QGC only tracks pitch/yaw from
`ATTITUDE`.

## Implementation checklist

1. Create one MAVLink UDP session per active payload.
2. Clamp MQTT input before converting to MAVLink.
3. Send keepalive messages on timers independent of incoming MQTT.
4. Stream active gimbal setpoints at the required rate:
   - Gremsy: `GIMBAL_DEVICE_SET_ATTITUDE` at 10 Hz.
   - NextVision: `RC_CHANNELS_OVERRIDE` at 25 Hz.
5. Send explicit stop commands when MQTT axes return to zero.
6. Maintain target system/component ids from inbound MAVLink.
7. Report link down if no inbound MAVLink arrives for 3 seconds.
8. Never reuse Gremsy and NextVision identities or channel mappings; they are
   different protocols even though both use MAVLink framing.

## Legacy vehicle-link Gremsy fallback

There is also older code in `Vehicle::sendGremsyGimbalRate()` and
`Vehicle::sendGimbalRCOverrideThreadSafe()` that sends commands through the
vehicle link. This is not the primary payload bridge contract.

If that fallback is intentionally needed:

- `sendGremsyGimbalRate()` sends `COMMAND_LONG` with
  `MAV_CMD_DO_GIMBAL_MANAGER_PITCHYAW` to component `154`, rates in deg/s,
  pitch/yaw angles as `NaN`, and `device_id=1`.
- `sendGimbalRCOverrideThreadSafe()` maps normalized yaw to RC channel 6 and
  normalized pitch to RC channel 8 using `1500 + axis * 500`.

Prefer the direct `src/Payload/*PayloadController` behavior above for the MQTT
bridge unless the hardware topology explicitly requires autopilot routing.
