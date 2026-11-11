#pragma once

// Pure safety predicates; no UI or transport side effects. Standard has no
// integrity alarm. Only cable integrity 2 in validated Extended telemetry
// starts a no-power incident; zero watts and link loss are not substitutes.
namespace SafeTNoPowerPolicy {
// The spec documents ASCII '0'..'5'; a real SAFE-T 2.3 sends raw bytes 0x00..
// Accept both. Anything else is unknown (-1).
inline int decodeAlarm(char value) {
    const unsigned char byte = static_cast<unsigned char>(value);
    if (byte <= 9) return byte;
    return byte >= '0' && byte <= '9' ? byte - '0' : -1;
}
inline int decodeIntegrity(char value) { const int alarm = decodeAlarm(value); return alarm >= 0 && alarm <= 2 ? alarm : -1; }
inline bool canDispatch(bool alarm, int integrity, bool sameIncident, bool alreadySent,
                        bool stationFresh, bool sameVehicle, bool armed, bool vehicleFresh,
                        bool guidedSupported) {
    return alarm && integrity == 2 && sameIncident && !alreadySent && stationFresh
        && sameVehicle && armed && vehicleFresh && guidedSupported;
}
}
