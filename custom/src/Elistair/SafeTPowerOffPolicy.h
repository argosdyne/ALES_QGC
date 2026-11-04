#pragma once

// No UI/transport dependency, so the flight fallback and stale-link gate can
// be tested without a vehicle or issuing a power command.
namespace SafeTPowerOffPolicy {
inline bool needsConfirmation(bool fcAvailable, bool armed, bool flying, int stationWatts, double lengthMeters)
{
    if (armed || flying) return true; // A stale Armed state must not bypass confirmation.
    return !fcAvailable && stationWatts > 200 && lengthMeters > 1.0;
}
inline bool canControl(bool hasMonitoring, bool linkLost, bool powerRemote, long long ageMsecs)
{
    return hasMonitoring && !linkLost && powerRemote && ageMsecs >= 0 && ageMsecs < 5000;
}
}
