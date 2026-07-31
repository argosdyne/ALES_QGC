#include "RtcmStreamValidator.h"

#include <cstdint>

quint32 RtcmStreamValidator::crc24q(const char* data, int length)
{
    quint32 crc = 0;
    for (int i = 0; i < length; ++i) {
        crc ^= static_cast<quint32>(static_cast<uint8_t>(data[i])) << 16;
        for (int bit = 0; bit < 8; ++bit) {
            crc <<= 1;
            if (crc & 0x1000000) {
                crc ^= 0x1864CFB;
            }
        }
    }
    return crc & 0xFFFFFF;
}

QList<QByteArray> RtcmStreamValidator::appendAndExtractValidatedFrames(
    QByteArray& streamBuffer,
    const QByteArray& incoming,
    int* droppedBytesOut,
    bool* overflowGuardTriggered,
    CrcErrorHandler onCrcError)
{
    QList<QByteArray> validatedFrames;
    int droppedBytes = 0;

    streamBuffer.append(incoming);
    if (streamBuffer.size() > 65536) {
        if (overflowGuardTriggered) {
            *overflowGuardTriggered = true;
        }
        int removed = 0;
        const int lastPreamble = streamBuffer.lastIndexOf(static_cast<char>(0xD3));
        if (lastPreamble >= 0) {
            removed = lastPreamble;
            streamBuffer.remove(0, lastPreamble);
        } else {
            removed = streamBuffer.size();
            streamBuffer.clear();
        }
        droppedBytes += removed;
    }

    while (streamBuffer.size() >= 6) {
        const int preambleIndex = streamBuffer.indexOf(static_cast<char>(0xD3));
        if (preambleIndex < 0) {
            droppedBytes += streamBuffer.size();
            streamBuffer.clear();
            break;
        }
        if (preambleIndex > 0) {
            droppedBytes += preambleIndex;
            streamBuffer.remove(0, preambleIndex);
        }
        if (streamBuffer.size() < 3) {
            break;
        }

        const uint8_t b1 = static_cast<uint8_t>(streamBuffer.at(1));
        const uint8_t b2 = static_cast<uint8_t>(streamBuffer.at(2));
        const int payloadLen = ((b1 & 0x03) << 8) | b2;
        if (payloadLen <= 0 || payloadLen > 1023) {
            droppedBytes += 1;
            streamBuffer.remove(0, 1);
            continue;
        }

        const int frameLen = 3 + payloadLen + 3;
        if (streamBuffer.size() < frameLen) {
            break;
        }

        const QByteArray frame = streamBuffer.left(frameLen);
        const quint32 expectedCrc =
            (static_cast<quint32>(static_cast<uint8_t>(frame.at(frameLen - 3))) << 16) |
            (static_cast<quint32>(static_cast<uint8_t>(frame.at(frameLen - 2))) << 8) |
            static_cast<quint32>(static_cast<uint8_t>(frame.at(frameLen - 1)));
        const quint32 actualCrc = crc24q(frame.constData(), frameLen - 3);
        if (expectedCrc != actualCrc) {
            if (onCrcError) {
                onCrcError(frame, expectedCrc, actualCrc);
            }
            droppedBytes += 1;
            streamBuffer.remove(0, 1);
            continue;
        }

        streamBuffer.remove(0, frameLen);
        validatedFrames.append(frame);
    }

    if (droppedBytesOut) {
        *droppedBytesOut = droppedBytes;
    }
    return validatedFrames;
}
