#ifndef RTCMSTREAMVALIDATOR_H
#define RTCMSTREAMVALIDATOR_H

#include <QByteArray>
#include <QList>
#include <functional>

class RtcmStreamValidator
{
public:
    using CrcErrorHandler = std::function<void(const QByteArray& frame, quint32 expectedCrc, quint32 actualCrc)>;

    static quint32 crc24q(const char* data, int length);

    // EG-SEC-DOS-001: sync on 0xD3, bound payload length, verify CRC-24Q before forwarding.
    static QList<QByteArray> appendAndExtractValidatedFrames(
        QByteArray& streamBuffer,
        const QByteArray& incoming,
        int* droppedBytesOut = nullptr,
        bool* overflowGuardTriggered = nullptr,
        CrcErrorHandler onCrcError = CrcErrorHandler());
};

#endif // RTCMSTREAMVALIDATOR_H
