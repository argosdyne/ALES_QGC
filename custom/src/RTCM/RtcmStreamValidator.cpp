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
        if (lastPreamble > 0) {
            removed = lastPreamble;
            streamBuffer.remove(0, lastPreamble);
        } else if (lastPreamble < 0) {
            removed = streamBuffer.size();
            streamBuffer.clear();
        }

        if (streamBuffer.size() > 65536) {
            const int excess = streamBuffer.size() - 65536;
            streamBuffer.remove(0, excess);
            removed += excess;
        }

        droppedBytes += removed;
    }

    int offset = 0;
    const int bufferSize = streamBuffer.size();

    while (bufferSize - offset >= 6) {
        const int preambleIndex = streamBuffer.indexOf(static_cast<char>(0xD3), offset);
        if (preambleIndex < 0) {
            droppedBytes += bufferSize - offset;
            offset = bufferSize;
            break;
        }
        if (preambleIndex > offset) {
            droppedBytes += preambleIndex - offset;
            offset = preambleIndex;
        }
        if (bufferSize - offset < 3) {
            break;
        }

        const uint8_t b1 = static_cast<uint8_t>(streamBuffer.at(offset + 1));
        const uint8_t b2 = static_cast<uint8_t>(streamBuffer.at(offset + 2));
        const int payloadLen = ((b1 & 0x03) << 8) | b2;
        if (payloadLen <= 0 || payloadLen > 1023) {
            droppedBytes += 1;
            offset += 1;
            continue;
        }

        const int frameLen = 3 + payloadLen + 3;
        if (bufferSize - offset < frameLen) {
            break;
        }

        const QByteArray frame = streamBuffer.mid(offset, frameLen);
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
            offset += 1;
            continue;
        }

        validatedFrames.append(frame);
        offset += frameLen;
    }

    if (offset > 0) {
        streamBuffer.remove(0, offset);
    }

    if (droppedBytesOut) {
        *droppedBytesOut = droppedBytes;
    }
    return validatedFrames;
}
