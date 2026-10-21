# APM 4.5 3D Geofence Support in QGC

## Source Specification

This implementation follows `ArduPilot_3D_GeoFence_Implementation_APM4.5_EN.docx`,
revision 2, dated 2026-08-01. It supersedes the earlier private implementation
that used command IDs 5015/5016 and altitude values in param2/param3.

## MAVLink Contract

The commands are ArduPilot-dialect commands:

| Command | ID | param1 | param2 | param3 | param4 |
| --- | ---: | --- | --- | --- | --- |
| `MAV_CMD_NAV_FENCE_POLYGON_VERTEX_INCLUSION_3D` | 42800 | Vertex count | Inclusion group | Altitude min | Altitude max |
| `MAV_CMD_NAV_FENCE_POLYGON_VERTEX_EXCLUSION_3D` | 42801 | Vertex count | Reserved | Altitude min | Altitude max |
| `MAV_CMD_NAV_FENCE_CIRCLE_INCLUSION_3D` | 42802 | Radius | Inclusion group | Altitude min | Altitude max |
| `MAV_CMD_NAV_FENCE_CIRCLE_EXCLUSION_3D` | 42803 | Radius | Reserved | Altitude min | Altitude max |

Latitude and longitude are carried by the `x` and `y` fields of
`MISSION_ITEM_INT`. `param7` is reserved. Every vertex of one polygon carries
identical group, altitude, and frame values.

The definitions belong in `message_definitions/ardupilotmega.xml`. QGC keeps
the four IDs as typed `MAV_CMD` constants because this repository cannot push
changes to the upstream `c_library_v2` submodule. They must not be added to
`common.xml` while using the dialect-phase IDs above.

## Data Model and Plan Files

`QGCFencePolygon` and `QGCFenceCircle` store:

- `altitudeBandEnabled`
- `altitudeMin`
- `altitudeMax`
- `altitudeFrame`
- `inclusionGroup`

The same fields are saved with each zone in a QGC `.plan` file. They are
optional when loading, so existing 2D plan files remain compatible.

QGC stores one of these normalized altitude frames:

- `MAV_FRAME_GLOBAL_RELATIVE_ALT` (relative to Home, default)
- `MAV_FRAME_GLOBAL` (AMSL)
- `MAV_FRAME_GLOBAL_TERRAIN_ALT` (above terrain)

Upload maps these to the corresponding `_INT` frame. Download accepts both
the `_INT` and non-`_INT` variants because `PlanManager` normalizes some frames
internally.

## Upload

When `altitudeBandEnabled` is false, QGC sends the existing 2D command. When it
is true, QGC sends the matching 3D command with `param3=altitudeMin` and
`param4=altitudeMax`.

QGC rejects an upload before sending when:

- altitude max is not greater than altitude min; or
- a 3D zone is being sent to a non-ArduPilot vehicle.

There is no standard capability bit for these private commands. ArduPilot
firmware without the implementation will reject the mission command, and QGC
will surface the mission protocol error.

## Download

QGC parses all four 3D commands and reconstructs the corresponding polygon or
circle. Polygon download validates that command, vertex count, inclusion group,
altitude bounds, and altitude frame remain identical for every vertex.

Both 2D and 3D zones can be downloaded in one fence mission. Unknown commands,
invalid frames, invalid altitude bands, and incomplete polygons fail the load
instead of silently changing fence semantics.

## User Interface

Polygon and circular fence editors provide:

- a per-zone 3D enable checkbox;
- altitude min and max inputs; and
- an altitude frame selector for Relative Home, AMSL, or Above Terrain.

Circle radius remains independent from its optional altitude band.

## Firmware Dependency

QGC support alone does not create altitude-aware behavior. The connected APM
4.5 firmware must implement IDs 42800-42803, preserve the altitude frame and
band in fence storage, gate breach checks by altitude, and define avoidance
behavior for inactive 3D zones. QGC and APM must use matching MAVLink dialect
definitions.

## Verification

Required interoperability checks:

1. Upload and download each of the four 3D zone types.
2. Confirm command IDs 42800-42803 and param3/param4 in packet capture.
3. Confirm altitude values and frame survive upload, reboot, and download.
4. Load and save mixed 2D/3D `.plan` files.
5. Verify below-band, inside-band, and above-band behavior in APM SITL.
6. Verify avoidance behavior does not contradict breach checking.
