#!/usr/bin/env python3
import argparse
import collections
import ipaddress
import os
import struct
import sys


def ones_complement_sum(data):
    if len(data) & 1:
        data += b"\x00"
    total = 0
    for i in range(0, len(data), 2):
        total += (data[i] << 8) | data[i + 1]
        total = (total & 0xffff) + (total >> 16)
    return total


def checksum_ok(data):
    return ones_complement_sum(data) == 0xffff


def read_pcap(path):
    with open(path, "rb") as f:
        header = f.read(24)
        if len(header) != 24:
            raise ValueError("pcap header too short")

        magic = header[:4]
        if magic == b"\xd4\xc3\xb2\xa1":
            endian = "<"
            ts_resolution = "us"
        elif magic == b"\xa1\xb2\xc3\xd4":
            endian = ">"
            ts_resolution = "us"
        elif magic == b"\x4d\x3c\xb2\xa1":
            endian = "<"
            ts_resolution = "ns"
        elif magic == b"\xa1\xb2\x3c\x4d":
            endian = ">"
            ts_resolution = "ns"
        else:
            raise ValueError(f"unsupported pcap magic {magic.hex()}")

        _magic, version_major, version_minor, _tz, _sigfigs, snaplen, network = struct.unpack(
            endian + "IHHIIII", header
        )
        if network != 1:
            raise ValueError(f"unsupported linktype {network}, expected Ethernet/linktype 1")

        index = 0
        while True:
            rec = f.read(16)
            if not rec:
                break
            if len(rec) != 16:
                raise ValueError("truncated packet record header")
            ts_sec, ts_frac, incl_len, orig_len = struct.unpack(endian + "IIII", rec)
            payload = f.read(incl_len)
            if len(payload) != incl_len:
                raise ValueError("truncated packet data")
            index += 1
            scale = 1_000_000_000 if ts_resolution == "ns" else 1_000_000
            timestamp = ts_sec + (ts_frac / scale)
            yield index, timestamp, orig_len, payload


def read_pcapng(path):
    with open(path, "rb") as f:
        first = f.read(12)
        if len(first) != 12:
            raise ValueError("pcapng header too short")
        block_type_le, block_len_le = struct.unpack("<II", first[:8])
        if block_type_le != 0x0A0D0D0A:
            raise ValueError("not a pcapng section header")

        body_start = f.read(block_len_le - 12)
        if len(body_start) != block_len_le - 12:
            raise ValueError("truncated pcapng section header")

        bom = first[8:12]
        if bom == b"\x4d\x3c\x2b\x1a":
            endian = "<"
        elif bom == b"\x1a\x2b\x3c\x4d":
            endian = ">"
        else:
            raise ValueError(f"unsupported pcapng byte-order magic {bom.hex()}")

        interfaces = []
        index = 0

        while True:
            hdr = f.read(8)
            if not hdr:
                break
            if len(hdr) != 8:
                raise ValueError("truncated pcapng block header")
            block_type, block_len = struct.unpack(endian + "II", hdr)
            if block_len < 12:
                raise ValueError(f"invalid pcapng block length {block_len}")
            body = f.read(block_len - 12)
            trailer = f.read(4)
            if len(body) != block_len - 12 or len(trailer) != 4:
                raise ValueError("truncated pcapng block")

            if block_type == 0x0A0D0D0A:
                bom = body[:4]
                if bom == b"\x4d\x3c\x2b\x1a":
                    endian = "<"
                elif bom == b"\x1a\x2b\x3c\x4d":
                    endian = ">"
                interfaces = []
                continue

            if block_type == 0x00000001:  # Interface Description Block
                if len(body) < 8:
                    continue
                linktype, _reserved, snaplen = struct.unpack(endian + "HHI", body[:8])
                ts_resolution = 1_000_000
                opt_offset = 8
                while opt_offset + 4 <= len(body):
                    code, length = struct.unpack(endian + "HH", body[opt_offset:opt_offset + 4])
                    opt_offset += 4
                    value = body[opt_offset:opt_offset + length]
                    opt_offset += (length + 3) & ~3
                    if code == 0:
                        break
                    if code == 9 and value:
                        raw = value[0]
                        if raw & 0x80:
                            ts_resolution = 2 ** (raw & 0x7f)
                        else:
                            ts_resolution = 10 ** raw
                interfaces.append({"linktype": linktype, "snaplen": snaplen, "ts_resolution": ts_resolution})
                continue

            if block_type == 0x00000006:  # Enhanced Packet Block
                if len(body) < 20:
                    continue
                interface_id, ts_high, ts_low, cap_len, orig_len = struct.unpack(endian + "IIIII", body[:20])
                if interface_id >= len(interfaces):
                    continue
                if interfaces[interface_id]["linktype"] != 1:
                    continue
                packet = body[20:20 + cap_len]
                if len(packet) != cap_len:
                    continue
                timestamp_raw = (ts_high << 32) | ts_low
                timestamp = timestamp_raw / interfaces[interface_id]["ts_resolution"]
                index += 1
                yield index, timestamp, orig_len, packet
                continue

            if block_type == 0x00000003:  # Simple Packet Block
                if len(body) < 4 or not interfaces or interfaces[0]["linktype"] != 1:
                    continue
                orig_len = struct.unpack(endian + "I", body[:4])[0]
                packet = body[4:4 + min(orig_len, len(body) - 4)]
                index += 1
                yield index, 0.0, orig_len, packet


def read_capture(path):
    with open(path, "rb") as f:
        magic = f.read(4)
    if magic == b"\x0a\x0d\x0d\x0a":
        yield from read_pcapng(path)
    else:
        yield from read_pcap(path)


def parse_ipv4_udp(frame):
    if len(frame) < 14:
        return None
    eth_type = struct.unpack("!H", frame[12:14])[0]
    offset = 14
    if eth_type == 0x8100 and len(frame) >= 18:
        eth_type = struct.unpack("!H", frame[16:18])[0]
        offset = 18
    if eth_type != 0x0800:
        return None
    if len(frame) < offset + 20:
        return None

    ip = frame[offset:]
    version_ihl = ip[0]
    version = version_ihl >> 4
    ihl = (version_ihl & 0x0f) * 4
    if version != 4 or ihl < 20 or len(ip) < ihl:
        return None

    total_len = struct.unpack("!H", ip[2:4])[0]
    if total_len < ihl or len(ip) < total_len:
        return None

    proto = ip[9]
    if proto != 17:
        return None

    src_ip = str(ipaddress.IPv4Address(ip[12:16]))
    dst_ip = str(ipaddress.IPv4Address(ip[16:20]))
    ip_header = ip[:ihl]
    udp = ip[ihl:total_len]
    if len(udp) < 8:
        return None

    src_port, dst_port, udp_len, udp_sum = struct.unpack("!HHHH", udp[:8])
    if udp_len < 8 or len(udp) < udp_len:
        return None

    udp_segment = udp[:udp_len]
    udp_payload = udp_segment[8:]
    pseudo = ip[12:16] + ip[16:20] + bytes([0, proto]) + struct.pack("!H", udp_len)

    return {
        "src_ip": src_ip,
        "dst_ip": dst_ip,
        "src_port": src_port,
        "dst_port": dst_port,
        "udp_len": udp_len,
        "udp_checksum": udp_sum,
        "udp_checksum_ok": True if udp_sum == 0 else checksum_ok(pseudo + udp_segment),
        "udp_checksum_zero": udp_sum == 0,
        "ip_checksum_ok": checksum_ok(ip_header),
        "payload": udp_payload,
    }


def parse_rtp(payload):
    if len(payload) < 12:
        return None
    b0 = payload[0]
    version = b0 >> 6
    if version != 2:
        return None
    cc = b0 & 0x0f
    header_len = 12 + cc * 4
    if len(payload) < header_len:
        return None
    b1 = payload[1]
    payload_type = b1 & 0x7f
    marker = (b1 >> 7) & 1
    seq = struct.unpack("!H", payload[2:4])[0]
    timestamp = struct.unpack("!I", payload[4:8])[0]
    ssrc = struct.unpack("!I", payload[8:12])[0]
    return {
        "payload_type": payload_type,
        "marker": marker,
        "seq": seq,
        "timestamp": timestamp,
        "ssrc": ssrc,
    }


def seq_delta(prev, current):
    return (current - prev) & 0xffff


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("pcap")
    parser.add_argument("--host", default="192.168.2.119")
    parser.add_argument("--out", default="")
    args = parser.parse_args()

    udp_packets = 0
    udp_bytes = 0
    udp_bad_checksum = 0
    udp_zero_checksum = 0
    ip_bad_checksum = 0
    host_udp_packets = 0
    host_udp_bad_checksum = 0
    first_ts = None
    last_ts = None
    flows = collections.Counter()
    bad_flows = collections.Counter()
    rtp_streams = {}
    rtp_streams_good_udp = {}

    for idx, ts, orig_len, frame in read_capture(args.pcap):
        if first_ts is None:
            first_ts = ts
        last_ts = ts
        udp = parse_ipv4_udp(frame)
        if udp is None:
            continue

        udp_packets += 1
        udp_bytes += udp["udp_len"]
        flow = (udp["src_ip"], udp["src_port"], udp["dst_ip"], udp["dst_port"])
        flows[flow] += 1
        host_match = udp["src_ip"] == args.host or udp["dst_ip"] == args.host
        if host_match:
            host_udp_packets += 1

        if not udp["ip_checksum_ok"]:
            ip_bad_checksum += 1
        if udp["udp_checksum_zero"]:
            udp_zero_checksum += 1
        elif not udp["udp_checksum_ok"]:
            udp_bad_checksum += 1
            bad_flows[flow] += 1
            if host_match:
                host_udp_bad_checksum += 1

        rtp = parse_rtp(udp["payload"])
        if rtp is None:
            continue

        key = (udp["src_ip"], udp["src_port"], udp["dst_ip"], udp["dst_port"], rtp["ssrc"], rtp["payload_type"])
        update_rtp_stream(rtp_streams, key, rtp, ts, not udp["udp_checksum_ok"] and not udp["udp_checksum_zero"])
        if udp["udp_checksum_ok"] or udp["udp_checksum_zero"]:
            update_rtp_stream(rtp_streams_good_udp, key, rtp, ts, False)

    duration = (last_ts - first_ts) if first_ts is not None and last_ts is not None else 0

    lines = []
    lines.append(f"PCAP: {os.path.abspath(args.pcap)}")
    lines.append(f"Host filter: {args.host}")
    lines.append(f"Duration seconds: {duration:.3f}")
    lines.append("")
    lines.append("UDP checksum summary:")
    lines.append(f"UDP packets: {udp_packets}")
    lines.append(f"UDP bytes including header: {udp_bytes}")
    lines.append(f"UDP bad checksum: {udp_bad_checksum}")
    lines.append(f"UDP zero checksum: {udp_zero_checksum}")
    lines.append(f"IPv4 bad header checksum: {ip_bad_checksum}")
    lines.append(f"Host UDP packets: {host_udp_packets}")
    lines.append(f"Host UDP bad checksum: {host_udp_bad_checksum}")
    lines.append("")
    lines.append("Top UDP flows:")
    for flow, count in flows.most_common(20):
        bad = bad_flows.get(flow, 0)
        lines.append(f"{flow[0]}:{flow[1]} -> {flow[2]}:{flow[3]} packets={count} bad_udp_checksum={bad}")
    lines.append("")
    lines.append("RTP streams, all captured packets:")
    append_rtp_stream_report(lines, rtp_streams)
    lines.append("")
    lines.append("RTP streams, UDP checksum OK packets only:")
    append_rtp_stream_report(lines, rtp_streams_good_udp)

    output = "\n".join(lines)
    print(output)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(output + "\n")


def update_rtp_stream(streams, key, rtp, ts, bad_udp_checksum):
    state = streams.setdefault(key, {
            "packets": 0,
            "bad_udp_checksum": 0,
            "seq_errors": 0,
            "lost_estimate": 0,
            "duplicates_or_reorder": 0,
            "first_seq": rtp["seq"],
            "last_seq": rtp["seq"],
            "first_ts": ts,
            "last_ts": ts,
            "markers": 0,
    })

    if state["packets"] > 0:
        delta = seq_delta(state["last_seq"], rtp["seq"])
        if delta == 0:
            state["seq_errors"] += 1
            state["duplicates_or_reorder"] += 1
        elif delta == 1:
            pass
        elif delta < 32768:
            state["seq_errors"] += 1
            state["lost_estimate"] += delta - 1
        else:
            state["seq_errors"] += 1
            state["duplicates_or_reorder"] += 1

    state["packets"] += 1
    state["last_seq"] = rtp["seq"]
    state["last_ts"] = ts
    state["markers"] += rtp["marker"]
    if bad_udp_checksum:
        state["bad_udp_checksum"] += 1


def append_rtp_stream_report(lines, rtp_streams):
    for key, state in sorted(rtp_streams.items(), key=lambda item: item[1]["packets"], reverse=True):
        stream_duration = max(0.001, state["last_ts"] - state["first_ts"])
        expected = state["packets"] + state["lost_estimate"]
        lost_pct = (state["lost_estimate"] / expected * 100.0) if expected else 0.0
        lines.append(
            f"{key[0]}:{key[1]} -> {key[2]}:{key[3]} "
            f"ssrc=0x{key[4]:08x} pt={key[5]} packets={state['packets']} "
            f"lost_estimate={state['lost_estimate']} lost_pct={lost_pct:.4f}% "
            f"seq_errors={state['seq_errors']} dup_or_reorder={state['duplicates_or_reorder']} "
            f"bad_udp_checksum={state['bad_udp_checksum']} markers={state['markers']} "
            f"duration={stream_duration:.3f}s"
        )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
