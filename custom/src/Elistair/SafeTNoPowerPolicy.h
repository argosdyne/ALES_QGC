#pragma once

// Pure safety predicates; no UI or transport side effects. Standard has no
// integrity alarm. Only documented ASCII '2' in validated Extended telemetry
// starts a no-power incident; zero watts and UDP loss are not substitutes.
namespace SafeTNoPowerPolicy {
inline int decodeIntegrity(char value) { return value >= '0' && value <= '2' ? value - '0' : -1; }
inline bool canDispatch(bool alarm, int integrity, bool sameIncident, bool alreadySent,
                        bool stationFresh, bool sameVehicle, bool armed, bool vehicleFresh,
                        bool guidedSupported) {
    return alarm && integrity == 2 && sameIncident && !alreadySent && stationFresh
        && sameVehicle && armed && vehicleFresh && guidedSupported;
}
}
