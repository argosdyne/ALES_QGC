# Report: UI Hang During RTL/Land Followed by Burst of Warning Messages

## Summary

During flight, when the vehicle transitions into `RTL` or `Land`, the ground control app can become unresponsive for about 30 seconds. After the UI recovers, a large number of warning and critical messages are displayed in a burst, and the app resumes normal operation.

This does not look like a full application crash. It looks like a temporary UI stall caused by a backlog of repeated vehicle status messages being processed on the main UI thread.

## Observed Symptoms

- App becomes unresponsive for approximately 30 seconds during flight.
- Freeze is typically observed when the vehicle enters `RTL` or `Land`.
- After the freeze, many popup/status messages appear at once.
- Typical repeated messages observed:
  - `WARNING: Radio Failsafe`
  - `WARNING: Radio Failsafe Cleared`
  - `WARNING: Radio Failsafe - Disarming`
  - `CRITICAL: PreArm: Radio failsafe on`
  - `CRITICAL: PrecLand0: Nactive`
  - `CRITICAL: PrecLand1: Nactive`
- After the message burst, the app becomes responsive again.

## Flight Log Evidence

Observed sequence from the vehicle log:

- `1958.136s`: `Radio Failsafe`
- `1959.656s`: `Radio Failsafe Cleared`
- `1962.906s`: `Radio Failsafe`
- `1962.936s`: `Radio Failsafe Cleared`
- `1966.126s`: `Radio Failsafe`
- `1968.109s`: `Crash: Disarming`

This shows the vehicle is generating repeated failsafe transitions in a short time window. The app screenshots also show that multiple repeated messages are queued and then rendered together after the UI becomes responsive again.

## Technical Analysis

The current message pipeline in the app is vulnerable to message storms:

1. `STATUSTEXT` messages from the vehicle are forwarded without rate limiting for messages such as `Radio Failsafe` and `PrecLand...`.
2. Each incoming message is converted into a new `UASMessage` object and appended to the internal message list.
3. The UI popup/message area appends each formatted message to a QML `TextEdit` using rich text rendering.
4. Critical/error messages can also trigger additional popup handling.

Relevant code paths:

- [Vehicle.cc](c:\Hien\ALES_QGC\src\Vehicle\Vehicle.cc)
  - repeated status text is emitted through `textMessageReceived`
  - `PreArm` has limited suppression, but `Radio Failsafe` and `PrecLand...` do not
- [UASMessageHandler.cc](c:\Hien\ALES_QGC\src\uas\UASMessageHandler.cc)
  - each message is appended into `_messages` with no effective cap
- [MessageIndicator.qml](c:\Hien\ALES_QGC\src\ui\toolbar\MessageIndicator.qml)
  - each new message is appended into a rich text `TextEdit`
- [MainRootWindow.qml](c:\Hien\ALES_QGC\src\ui\MainRootWindow.qml)
  - critical messages are also pushed through popup handling

## Probable Root Cause

The most likely root cause is:

`RTL`/`Land` is occurring while the vehicle is repeatedly toggling radio failsafe and related status conditions, causing a burst of repeated `STATUSTEXT` warnings. The app does not deduplicate or throttle these repeated messages, so they accumulate and overload the UI thread. Once the event backlog is drained, the UI becomes responsive again and all queued messages are displayed at once.

## Why It Looks Like "Freeze Then Recover"

This behavior is consistent with a blocked or overloaded UI event loop:

- messages continue arriving while the UI is stalled
- the app cannot render or respond immediately
- queued messages accumulate internally
- once the UI thread catches up, all pending messages are rendered in a burst

So the application is not necessarily crashing at that moment. It is more likely entering a temporary UI stall caused by excessive repeated message processing.

## Impact

- Temporary loss of UI responsiveness during critical flight phases
- Delayed operator awareness because warnings are shown late
- Increased risk during failsafe, `RTL`, and landing operations
- Possible secondary memory/performance pressure if the message burst is large enough

## Conclusion

The current evidence points to a message-flood handling issue in the app, not a single isolated bad message.

Primary trigger:

- repeated vehicle warning/critical messages during `RTL`/`Land`, especially `Radio Failsafe` and `PrecLand...`

Primary application weakness:

- no throttling/deduplication for repeated status text messages
- unbounded or weakly bounded message accumulation
- expensive rich-text UI updates on the main thread for every incoming message

## Recommended Fix Direction

1. Add throttling/deduplication for repeated status messages such as:
   - `Radio Failsafe`
   - `Radio Failsafe Cleared`
   - `PrecLand0: Nactive`
   - `PrecLand1: Nactive`
2. Cap the number of stored vehicle messages in `UASMessageHandler`.
3. Reduce popup churn for repeated critical/warning messages.
4. Avoid appending every incoming warning directly to rich text UI components during message storms.

## Short Version For Internal Reporting

When the vehicle enters `RTL` or `Land`, the app can hang for about 30 seconds and then recover. After recovery, many repeated warnings are shown at once, including `Radio Failsafe`, `Radio Failsafe Cleared`, `PreArm: Radio failsafe on`, and `PrecLand0/1: Nactive`. The likely cause is a burst of repeated `STATUSTEXT` messages from the vehicle combined with missing throttling/deduplication in the app's message pipeline, which overloads the UI thread. This results in a temporary freeze, followed by delayed rendering of all queued messages.
