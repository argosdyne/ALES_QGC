#!/usr/bin/env python3
"""
Stress-test QGC message handling by spamming STATUSTEXT messages into the same
vehicle sysid that QGC is already tracking from SITL.

Typical usage:
    python tools/sitl_statustext_spam.py --target udpout:127.0.0.1:14550 --pattern mixed

Notes:
    - Start SITL and connect QGC first.
    - Keep Fly View open.
    - Open the message popup while the script is running.
    - If QGC is listening on 14551 instead of 14550, change --target.
"""

import argparse
import itertools
import sys
import time

from pymavlink import mavutil


PATTERNS = {
    "failsafe": [
        (mavutil.mavlink.MAV_SEVERITY_WARNING, "Radio Failsafe"),
        (mavutil.mavlink.MAV_SEVERITY_WARNING, "Radio Failsafe Cleared"),
        (mavutil.mavlink.MAV_SEVERITY_WARNING, "Radio Failsafe - Disarming"),
        (mavutil.mavlink.MAV_SEVERITY_CRITICAL, "PreArm: Radio failsafe on"),
    ],
    "precland": [
        (mavutil.mavlink.MAV_SEVERITY_CRITICAL, "PrecLand0: Nactive"),
        (mavutil.mavlink.MAV_SEVERITY_CRITICAL, "PrecLand1: Nactive"),
    ],
    "mixed": [
        (mavutil.mavlink.MAV_SEVERITY_WARNING, "Radio Failsafe"),
        (mavutil.mavlink.MAV_SEVERITY_WARNING, "Radio Failsafe Cleared"),
        (mavutil.mavlink.MAV_SEVERITY_WARNING, "Radio Failsafe - Disarming"),
        (mavutil.mavlink.MAV_SEVERITY_CRITICAL, "PreArm: Radio failsafe on"),
        (mavutil.mavlink.MAV_SEVERITY_CRITICAL, "PrecLand0: Nactive"),
        (mavutil.mavlink.MAV_SEVERITY_CRITICAL, "PrecLand1: Nactive"),
    ],
}


def parse_args():
    parser = argparse.ArgumentParser(description="Spam MAVLink STATUSTEXT into QGC during SITL.")
    parser.add_argument(
        "--target",
        default="udpout:127.0.0.1:14550",
        help="MAVLink endpoint QGC is listening on, for example udpout:127.0.0.1:14550",
    )
    parser.add_argument("--sysid", type=int, default=1, help="Vehicle sysid seen by QGC. SITL default is 1.")
    parser.add_argument(
        "--compid",
        type=int,
        default=mavutil.mavlink.MAV_COMP_ID_AUTOPILOT1,
        help="Component id to send as. Default is autopilot component.",
    )
    parser.add_argument(
        "--pattern",
        choices=sorted(PATTERNS.keys()),
        default="mixed",
        help="Which status-text pattern to spam.",
    )
    parser.add_argument("--rate", type=float, default=20.0, help="STATUSTEXT messages per second.")
    parser.add_argument("--duration", type=float, default=30.0, help="How long to run the spam test, in seconds.")
    parser.add_argument(
        "--heartbeat-rate",
        type=float,
        default=1.0,
        help="Heartbeat rate per second while spamming, to keep endpoint active in logs.",
    )
    return parser.parse_args()


def send_heartbeat(master):
    master.mav.heartbeat_send(
        mavutil.mavlink.MAV_TYPE_QUADROTOR,
        mavutil.mavlink.MAV_AUTOPILOT_ARDUPILOTMEGA,
        0,
        0,
        0,
    )


def send_statustext(master, severity, text):
    encoded = text.encode("utf-8")[:50]
    encoded += b"\0" * (50 - len(encoded))
    master.mav.statustext_send(severity, encoded)


def main():
    args = parse_args()
    if args.rate <= 0 or args.duration <= 0 or args.heartbeat_rate <= 0:
        print("rate, duration, and heartbeat-rate must be positive", file=sys.stderr)
        return 2

    master = mavutil.mavlink_connection(
        args.target,
        source_system=args.sysid,
        source_component=args.compid,
    )

    spam_messages = PATTERNS[args.pattern]
    spam_period = 1.0 / args.rate
    heartbeat_period = 1.0 / args.heartbeat_rate
    next_heartbeat = time.monotonic()
    end_time = time.monotonic() + args.duration
    message_iter = itertools.cycle(spam_messages)

    print("Sending STATUSTEXT spam to {}".format(args.target))
    print(
        "sysid={} compid={} pattern={} rate={}/s duration={}s".format(
            args.sysid, args.compid, args.pattern, args.rate, args.duration
        )
    )
    print("Open QGC Fly View and keep the message popup visible during the run.")

    sent_count = 0
    while time.monotonic() < end_time:
        now = time.monotonic()
        if now >= next_heartbeat:
            send_heartbeat(master)
            next_heartbeat = now + heartbeat_period

        severity, text = next(message_iter)
        send_statustext(master, severity, text)
        sent_count += 1
        time.sleep(spam_period)

    print("Done. Sent {} STATUSTEXT messages.".format(sent_count))
    print("Pass criteria: UI stays responsive, popup updates are controlled, and no long freeze occurs.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
