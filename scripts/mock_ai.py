#!/usr/bin/env python3
"""
Mock AI Script — VinBus SafeWatch
Giả lập AI service gửi fake alert đến backend Fastify.
Chạy: python scripts/mock_ai.py
"""

import requests
import time
import random
import datetime
import sys

API_URL = "http://localhost:3001/api/events/detect"

BUSES = ["BUS-101", "BUS-102", "BUS-103", "BUS-047", "BUS-213", "BUS-088", "BUS-174"]
ROUTES = {
    "BUS-101": "32", "BUS-102": "32", "BUS-103": "15",
    "BUS-047": "15", "BUS-213": "09", "BUS-088": "27", "BUS-174": "18",
}

# ANSI colors
RED    = "\033[91m"
YELLOW = "\033[93m"
GRAY   = "\033[90m"
GREEN  = "\033[92m"
RESET  = "\033[0m"
BOLD   = "\033[1m"


def confidence_tier(c: float) -> tuple[str, str]:
    """Returns (label, color) based on confidence zone (ADR-004)."""
    if c >= 0.70:
        return "🔴 ALERT    ", RED
    elif c >= 0.40:
        return "🟡 uncertain", YELLOW
    else:
        return "⚫ ignored  ", GRAY


def send_event() -> None:
    bus_id = random.choice(BUSES)
    confidence = round(random.uniform(0.28, 0.97), 2)
    event_type = random.choice(["fall", "fight"])

    payload = {
        "event_type": event_type,
        "confidence": confidence,
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
        "bus_id": bus_id,
        "route_id": ROUTES.get(bus_id),
        "ai_model_version": "mock-v0.1",
    }

    tier_label, color = confidence_tier(confidence)

    try:
        r = requests.post(API_URL, json=payload, timeout=5)
        status_code = r.status_code
        response_status = r.json().get("status", "?") if status_code == 201 else "error"
        print(
            f"{color}{tier_label}{RESET} "
            f"{BOLD}{bus_id}{RESET} "
            f"{event_type:<5} "
            f"conf={confidence:.2f} "
            f"-> {GREEN if status_code == 201 else RED}{status_code} {response_status}{RESET}"
        )
    except requests.exceptions.ConnectionError:
        print(f"{RED}[ERROR] Cannot connect to {API_URL}{RESET}")
        print("        Dam bao backend dang chay: cd backend && npm run dev")
    except Exception as e:
        print(f"{RED}[ERROR] {e}{RESET}")


def main() -> None:
    print(f"\n{BOLD}Mock AI Script - VinBus SafeWatch{RESET}")
    print(f"   Target: {API_URL}")
    print(f"   Interval: 15-30s moi event")
    print(f"   Ctrl+C de dung\n")
    print(f"   {'ZONE':<14} {'BUS':<10} {'TYPE':<6} {'CONF':<10} {'RESULT'}")
    print("   " + "-" * 55)

    while True:
        send_event()
        delay = random.uniform(15, 30)
        time.sleep(delay)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n{GRAY}Mock AI stopped.{RESET}\n")
        sys.exit(0)
