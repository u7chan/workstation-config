#!/usr/bin/env python3
"""Render a compact status line from JSON input."""

from __future__ import annotations

import json
import sys
import time
from datetime import datetime
from typing import Any, Callable


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

RESET = "\033[0m"
MODEL_COLOR = "\033[0;35m"
DIVIDER_COLOR = "\033[38;2;150;150;150m"

EFFORT_COLORS = {
    "low": "\033[38;2;100;200;100m",
    "medium": "\033[38;2;220;200;60m",
    "high": "\033[38;2;255;150;50m",
    "xhigh": "\033[38;2;255;90;60m",
    "max": "\033[38;2;255;60;120m",
}

BLOCKS = " ▏▎▍▌▋▊▉█"
BAR_WIDTH = 5
DEFAULT_MODEL = "Claude"

RATE_LIMITS: tuple[
    tuple[str, str, Callable[[Any], str]],
    ...,
] = (
    ("5h", "five_hour", lambda value: format_time_left(value)),
    ("7d", "seven_day", lambda value: format_weekday(value)),
)


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

def get_dict(data: Any, key: str) -> dict[str, Any]:
    """Return data[key] when it is a dict, otherwise an empty dict."""
    if not isinstance(data, dict):
        return {}

    value = data.get(key)
    return value if isinstance(value, dict) else {}


def parse_percent(value: Any) -> float | None:
    """Convert a value to a percentage between 0 and 100."""
    if isinstance(value, bool):
        return None

    try:
        percent = float(value)
    except (TypeError, ValueError):
        return None

    if percent != percent:  # NaN
        return None

    return max(0.0, min(percent, 100.0))


def parse_epoch(value: Any) -> float | None:
    """Parse epoch seconds, numeric strings, or ISO 8601 timestamps."""
    if isinstance(value, bool) or value is None:
        return None

    if isinstance(value, (int, float)):
        return float(value)

    if not isinstance(value, str):
        return None

    value = value.strip()
    if not value:
        return None

    try:
        return float(value)
    except ValueError:
        pass

    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


# ---------------------------------------------------------------------------
# Formatting
# ---------------------------------------------------------------------------

def gradient_color(percent: float) -> str:
    """Return a green -> yellow -> red true-color ANSI sequence."""
    if percent < 50:
        red = int(percent * 5.1)
        return f"\033[38;2;{red};200;80m"

    green = max(int(200 - (percent - 50) * 4), 0)
    return f"\033[38;2;255;{green};60m"


def progress_bar(percent: float, width: int = BAR_WIDTH) -> str:
    """Render a fractional block progress bar."""
    filled = percent * width / 100
    full_blocks = int(filled)
    fraction = int((filled - full_blocks) * 8)

    result = "█" * full_blocks

    if full_blocks < width:
        result += BLOCKS[fraction]
        result += "░" * (width - full_blocks - 1)

    return result


def format_metric(label: str, percent: float) -> str:
    color = gradient_color(percent)
    return (
        f"{label} "
        f"{color}{progress_bar(percent)} {round(percent)}%{RESET}"
    )


def format_time_left(value: Any) -> str:
    epoch = parse_epoch(value)
    if epoch is None:
        return ""

    remaining_minutes = int(epoch - time.time()) // 60
    if remaining_minutes <= 0:
        return ""

    hours, minutes = divmod(remaining_minutes, 60)
    return f"{hours}h{minutes}m" if hours else f"{minutes}m"


def format_weekday(value: Any) -> str:
    epoch = parse_epoch(value)
    if epoch is None:
        return ""

    try:
        return time.strftime("%a", time.localtime(epoch))
    except (OverflowError, OSError, ValueError):
        return ""


# ---------------------------------------------------------------------------
# Components
# ---------------------------------------------------------------------------

def render_model(data: dict[str, Any]) -> str:
    model = get_dict(data, "model").get("display_name") or DEFAULT_MODEL
    result = f"{MODEL_COLOR}{model}{RESET}"

    effort = get_dict(data, "effort").get("level")
    if isinstance(effort, str) and effort:
        color = EFFORT_COLORS.get(effort, MODEL_COLOR)
        result += f" {color}{effort}{RESET}"

    return result


def render_context(data: dict[str, Any]) -> str | None:
    percent = parse_percent(
        get_dict(data, "context_window").get("used_percentage")
    )
    return format_metric("ctx", percent) if percent is not None else None


def render_rate_limit(
    label: str,
    data: dict[str, Any],
    suffix_formatter: Callable[[Any], str],
) -> str | None:
    percent = parse_percent(data.get("used_percentage"))
    if percent is None:
        return None

    result = format_metric(label, percent)

    suffix = suffix_formatter(data.get("resets_at"))
    if suffix:
        result += f" {MODEL_COLOR}({suffix}){RESET}"

    return result


# ---------------------------------------------------------------------------
# Status line
# ---------------------------------------------------------------------------

def build_status_line(data: Any) -> str:
    if not isinstance(data, dict):
        data = {}

    parts = [render_model(data)]

    context = render_context(data)
    if context:
        parts.append(context)

    rate_limits = get_dict(data, "rate_limits")

    for label, key, suffix_formatter in RATE_LIMITS:
        part = render_rate_limit(
            label,
            get_dict(rate_limits, key),
            suffix_formatter,
        )
        if part:
            parts.append(part)

    divider = f" {DIVIDER_COLOR}│{RESET} "
    return divider.join(parts)


def configure_stdout() -> None:
    if sys.platform != "win32":
        return

    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, OSError):
        pass


def main() -> None:
    configure_stdout()

    try:
        data = json.load(sys.stdin)
        line = build_status_line(data)
    except (json.JSONDecodeError, TypeError, ValueError):
        line = f"{MODEL_COLOR}{DEFAULT_MODEL}{RESET}"

    print(line, end="")


if __name__ == "__main__":
    main()
