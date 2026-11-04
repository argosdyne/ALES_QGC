#pragma once
#include <cstdint>

// Same ST-04 state transitions as the C# negotiator. No Qt/vehicle dependency.
class SafeTFrameNegotiator {
public:
    enum Version { Auto, V1, V0, Standard };
    explicit SafeTFrameNegotiator(int version = Auto, std::int64_t now = 0) : configured(version) { restart(now); }
    int active = V1;
    bool confirmed = false, configPending = false, configAttempted = false;
    std::int64_t lastReply = -1;
    bool tick(std::int64_t now, bool safeGround) {
        if (confirmed && lastReply >= 0 && now - lastReply >= 5000) restart(now);
        if (configured != Auto) return false;
        if (configPending) {
            if (!safeGround || now - configStarted >= 1000) {
                configPending = false; active = V1; probeStarted = now; recheckedLower = lastReply >= 0;
            } else return false;
        }
        if (!configAttempted && safeGround) {
            configAttempted = configPending = true; confirmed = false; configStarted = now; return true;
        }
        if (!confirmed && now - probeStarted >= 1000) {
            active = active == V1 ? V0 : active == V0 ? Standard : V1; probeStarted = now;
        }
        return false;
    }
    void monitoring(std::int64_t now, bool safeGround) {
        lastReply = now;
        if (configured != Auto) { confirmed = true; return; }
        if (configPending || (!configAttempted && safeGround)) return;
        if (active != V1 && !recheckedLower) { recheckedLower = true; active = V1; probeStarted = now; return; }
        confirmed = true;
    }
    bool configuration(int major, int minor, std::int64_t now, bool safeGround) {
        if (!configPending || !safeGround) return false;
        configPending = confirmed = false; recheckedLower = true;
        active = major > 0 || minor >= 12 ? V1 : V0; probeStarted = now; return true;
    }
private:
    int configured;
    std::int64_t probeStarted = 0, configStarted = 0;
    bool recheckedLower = false;
    void restart(std::int64_t now) {
        active = configured == Auto ? V1 : configured;
        confirmed = configPending = configAttempted = recheckedLower = false;
        probeStarted = now; lastReply = -1;
    }
};
