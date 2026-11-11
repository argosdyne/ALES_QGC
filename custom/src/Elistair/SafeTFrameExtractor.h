#pragma once
#include <cstddef>
#include <cstdint>
#include <limits>
#include <vector>

// Splits a SAFE-T byte stream (TCP stream or UDP datagrams) into validated frames.
// Same rules as the argosALES C# extractor. Frames from a real SAFE-T 2.3 carry NO
// trailing CR/LF; a CR/LF right after a frame is consumed when present. On a bad
// size/CRC one byte is dropped and parsing resyncs. No Qt dependency (unit testable).
class SafeTFrameExtractor {
public:
    enum Kind { Standard, ExtendedV0, ExtendedV1, ConfigRead, ConfigWrite };
    struct Frame {
        Kind kind;
        std::vector<std::uint8_t> bytes; // core frame, sync byte first, without CR/LF
        bool crlf;
        // Standard only: SAFE-T 2.3 variant (CRC over bytes 1..9, big-endian fields).
        // TENTATIVE: derived from a single captured frame (AA 09 00 00 00 7F 00 15 00 00 56).
        bool bigEndianStandard;
    };

    int crcErrors = 0;

    static std::uint8_t crc8(const std::uint8_t* data, std::size_t size) {
        std::uint8_t crc = 0;
        for (std::size_t i = 0; i < size; ++i) {
            crc ^= data[i];
            for (int bit = 0; bit < 8; ++bit) crc = (crc & 0x80) ? std::uint8_t((crc << 1) ^ 0xd5) : std::uint8_t(crc << 1);
        }
        return crc;
    }

    void clear() { _buffer.clear(); }

    std::vector<Frame> push(const std::uint8_t* data, std::size_t size, std::int64_t nowMs) {
        if (!_buffer.empty() && nowMs - _lastPushMs > 500) _buffer.clear(); // stale partial frame
        _lastPushMs = nowMs;
        _buffer.insert(_buffer.end(), data, data + size);
        std::vector<Frame> frames;
        std::size_t i = 0;
        while (i < _buffer.size()) {
            Kind kind; std::size_t sizeByte, core;
            if (!describe(_buffer[i], kind, sizeByte, core)) { ++i; continue; }
            if (_buffer.size() - i < 2) break;
            if (_buffer[i + 1] != sizeByte) { ++i; continue; }
            if (_buffer.size() - i < core) break; // wait for the rest
            const std::uint8_t* f = _buffer.data() + i;
            bool bigEndian = false;
            bool ok;
            if (kind == Standard) {
                ok = f[10] == crc8(f + 2, 8);                       // spec §4.1.2
                if (!ok && f[10] == crc8(f + 1, 9)) ok = bigEndian = true; // SAFE-T 2.3 variant (tentative)
            } else {
                ok = f[2] == crc8(f + 3, core - 3);                 // spec: CRC at byte 2 over payload
            }
            if (!ok) { ++crcErrors; ++i; continue; }
            Frame frame{kind, std::vector<std::uint8_t>(f, f + core), false, bigEndian};
            std::size_t consumed = core;
            if (_buffer.size() - i >= core + 2 && f[core] == '\r' && f[core + 1] == '\n') { frame.crlf = true; consumed += 2; }
            frames.push_back(std::move(frame));
            i += consumed;
        }
        _buffer.erase(_buffer.begin(), _buffer.begin() + std::ptrdiff_t(i));
        return frames;
    }

private:
    static bool describe(std::uint8_t sync, Kind& kind, std::size_t& sizeByte, std::size_t& core) {
        switch (sync) {
        case 0xaa: kind = Standard;    sizeByte = 9;  core = 11; return true;
        case 0x55: kind = ExtendedV0;  sizeByte = 14; core = 16; return true;
        case 0x56: kind = ExtendedV1;  sizeByte = 23; core = 25; return true;
        case 0xa5: kind = ConfigRead;  sizeByte = 79; core = 81; return true;
        case 0xd5: kind = ConfigWrite; sizeByte = 4;  core = 6;  return true;
        default: return false;
        }
    }
    std::vector<std::uint8_t> _buffer;
    std::int64_t _lastPushMs = std::numeric_limits<std::int64_t>::min() / 2;
};
