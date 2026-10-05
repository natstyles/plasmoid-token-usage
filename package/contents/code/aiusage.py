#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Steven <richardsarizandieta@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
"""AI Usage plasmoid backend."""
import fcntl
import glob
import json
import os
import re
import ssl
import subprocess
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

HOME = os.path.expanduser("~")
TIMEOUT = 10
DATA_DIR = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local", "share"), "aiusage")
HISTORY_DAYS = 8
HISTORY_MIN_GAP = 240      # Minimum seconds between samples
HISTORY_MAX_POINTS = 300   # Maximum points per series


class ProviderError(Exception):
    def __init__(self, error_id, message, error_args=None):
        super().__init__(message)
        self.error_id = error_id
        self.message = message
        # Not "self.args": Exception.args is special and would turn the dict into a tuple of its keys.
        self.error_args = error_args or {}


def http_json(url, headers=None, data=None, context=None):
    req = urllib.request.Request(url, data=data, headers=headers or {})
    with urllib.request.urlopen(req, timeout=TIMEOUT, context=context) as resp:
        return json.load(resp)


def to_epoch(value):
    """Converts ISO 8601 or epoch to seconds."""
    if value is None or value == "":
        return None
    if isinstance(value, (int, float)):
        return value / 1000 if value > 1e12 else float(value)
    text = re.sub(r"\.\d+", "", str(value)).replace("Z", "+00:00")
    dt = datetime.fromisoformat(text)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.timestamp()


def window(key, label_id, label_args, label, kind, percent, resets_at):
    return {
        "key": key,
        "label_id": label_id,
        "label_args": label_args,
        "label": label,
        "kind": kind,
        "percent": None if percent is None else round(float(percent), 1),
        "resets_at": to_epoch(resets_at),
    }


def window_label(minutes, fallback_kind):
    if minutes:
        if minutes >= 7 * 24 * 60:
            return "weekly", "weekly", {}, "Weekly", "weekly"
        if minutes >= 24 * 60:
            return "daily", "daily", {}, "Daily", "daily"
        hours = minutes / 60
        return "session", "session", {"hours": hours}, f"Session ({hours:g} h)", "session"
    if fallback_kind == "weekly":
        return "weekly", "weekly", {}, "Weekly", "weekly"
    return "session", "session", {}, "Session", "session"


# --- Claude ---

CLAUDE_TOKEN_URL = "https://platform.claude.com/v1/oauth/token"
CLAUDE_CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"


def _claude_code_running():
    for pid in filter(str.isdigit, os.listdir("/proc")):
        try:
            with open(f"/proc/{pid}/comm") as f:
                if f.read().strip() == "claude":
                    return True
        except OSError:
            continue
    return False


def _write_json_atomic(path, data):
    tmp = path + ".aiusage.tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(data, f)
    os.replace(tmp, path)


def _refresh_claude_token(path, oauth):
    """Refreshes the token the way Claude Code does and saves it to Claude Code's credentials file.

    The refresh token rotates on every refresh, so the new one must be written to the same file
    Claude Code reads; otherwise Claude Code would keep an invalid token and log the user out.
    """
    if oauth.get("refreshTokenExpiresAt") and oauth["refreshTokenExpiresAt"] / 1000 < time.time():
        raise ProviderError("claude_session_expired", "Claude Code session has expired: log in again")
    if not oauth.get("refreshToken"):
        raise ProviderError("claude_no_refresh_token", "Token expired and no refresh token available")
    # If Claude Code is running, let it refresh: two processes must never rotate the token at once.
    if _claude_code_running():
        raise ProviderError("claude_token_expired_running", "Token expired: Claude Code is running and will refresh it")

    body = {"grant_type": "refresh_token", "refresh_token": oauth["refreshToken"], "client_id": CLAUDE_CLIENT_ID}
    if oauth.get("scopes"):
        body["scope"] = " ".join(oauth["scopes"])
    data = http_json(CLAUDE_TOKEN_URL, {"Content-Type": "application/json", "User-Agent": "claude-code/2.0"},
                     json.dumps(body).encode())
    if not data.get("access_token"):
        raise ProviderError("claude_refresh_failed", "Failed to refresh Claude token")

    with open(path + ".aiusage.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        with open(path) as f:
            creds = json.load(f)
        current = creds.get("claudeAiOauth") or {}
        if current.get("refreshToken") != oauth["refreshToken"]:
            # Another process refreshed it meanwhile: its version is the valid one.
            return current
        current["accessToken"] = data["access_token"]
        if data.get("refresh_token"):
            current["refreshToken"] = data["refresh_token"]
        current["expiresAt"] = int((time.time() + data.get("expires_in", 3600)) * 1000)
        creds["claudeAiOauth"] = current
        _write_json_atomic(path, creds)
    return current


def claude():
    path = os.path.join(HOME, ".claude", ".credentials.json")
    if not os.path.exists(path):
        raise ProviderError("claude_not_logged_in", "Log in to Claude Code (no ~/.claude/.credentials.json found)")
    with open(path) as f:
        oauth = json.load(f).get("claudeAiOauth") or {}
    if not oauth.get("accessToken"):
        raise ProviderError("claude_no_oauth", "Claude Code does not have an OAuth token")
    if oauth.get("expiresAt", 0) / 1000 < time.time() + 60:
        oauth = _refresh_claude_token(path, oauth)

    data = http_json(
        "https://api.anthropic.com/api/oauth/usage",
        {
            "Authorization": "Bearer " + oauth["accessToken"],
            "anthropic-beta": "oauth-2025-04-20",
            "User-Agent": "claude-code/2.0",
        },
    )
    windows = []
    for source_key, key, label_id, label_args, label, kind in (
        ("five_hour", "session", "session", {"hours": 5}, "Session (5 h)", "session"),
        ("seven_day", "weekly", "weekly", {}, "Weekly", "weekly"),
        ("seven_day_opus", "weekly_opus", "weekly_model", {"model": "Opus"}, "Weekly · Opus", "weekly"),
        ("seven_day_sonnet", "weekly_sonnet", "weekly_model", {"model": "Sonnet"}, "Weekly · Sonnet", "weekly"),
    ):
        w = data.get(source_key)
        if w:
            windows.append(window(key, label_id, label_args, label, kind, w.get("utilization"), w.get("resets_at")))
    return {"plan": oauth.get("subscriptionType"), "windows": windows,
            "breakdown": _claude_breakdown(data.get("seven_day_breakdown"))}


def _claude_breakdown(data):
    """Groups Claude weekly usage by categories."""
    if not data or not data.get("rows"):
        return None
    groups = {"claude_code": ("Claude Code", 0.0, []), "chat": ("Chats", 0.0, []), "other": ("Other", 0.0, [])}
    for row in data["rows"]:
        key = row.get("key") if row.get("key") in ("claude_code", "chat") else "other"
        label, total, parts = groups[key]
        percent = float(row.get("percent") or 0)
        if key == "other" and percent > 0:
            parts.append(f"{row.get('display_name') or row.get('key')} {percent:g} %")
        groups[key] = (label, total + percent, parts)
    rows = [{"key": k, "label": label, "percent": round(total, 1), "parts": parts}
            for k, (label, total, parts) in groups.items()]
    if not any(r["percent"] > 0 for r in rows):
        return None
    return {"rows": rows, "since": to_epoch(data.get("window_started_at"))}


# --- ChatGPT ---

def _codex_reset(w, event_ts=None):
    if w.get("reset_at") or w.get("resets_at"):
        return to_epoch(w.get("reset_at") or w.get("resets_at"))
    secs = w.get("reset_after_seconds", w.get("resets_in_seconds"))
    if secs is not None:
        return (event_ts or time.time()) + secs
    return None


def _codex_from_api(base):
    with open(os.path.join(base, "auth.json")) as f:
        tokens = json.load(f).get("tokens") or {}
    if not tokens.get("access_token"):
        raise ProviderError("codex_not_logged_in", "Codex is not logged into ChatGPT")
    headers = {"Authorization": "Bearer " + tokens["access_token"], "User-Agent": "codex-cli"}
    if tokens.get("account_id"):
        headers["ChatGPT-Account-Id"] = tokens["account_id"]
    data = http_json("https://chatgpt.com/backend-api/wham/usage", headers)
    limits = data.get("rate_limit") or {}
    windows = []
    for key, kind in (("primary_window", "session"), ("secondary_window", "weekly")):
        w = limits.get(key)
        if w:
            secs = w.get("limit_window_seconds")
            key, label_id, label_args, label, kind = window_label(secs / 60 if secs else None, kind)
            windows.append(window(key, label_id, label_args, label, kind, w.get("used_percent"), _codex_reset(w)))
    return {"plan": data.get("plan_type"), "windows": windows}


def _codex_from_sessions(base):
    """Reads saved limits from Codex session logs."""
    files = glob.glob(os.path.join(base, "sessions", "**", "*.jsonl"), recursive=True)
    for path in sorted(files, key=os.path.getmtime, reverse=True)[:5]:
        with open(path, errors="replace") as f:
            lines = f.readlines()
        for line in reversed(lines):
            if '"rate_limits"' not in line:
                continue
            try:
                event = json.loads(line)
            except ValueError:
                continue
            limits = (event.get("payload") or {}).get("rate_limits")
            if not limits:
                continue
            event_ts = to_epoch(event.get("timestamp"))
            windows = []
            for key, kind in (("primary", "session"), ("secondary", "weekly")):
                w = limits.get(key)
                if w:
                    key, label_id, label_args, label, kind = window_label(w.get("window_minutes"), kind)
                    windows.append(window(key, label_id, label_args, label, kind, w.get("used_percent"), _codex_reset(w, event_ts)))
            if windows:
                return {"plan": limits.get("plan_type"), "windows": windows, "stale_since": event_ts}
    return None


def chatgpt():
    base = os.environ.get("CODEX_HOME", os.path.join(HOME, ".codex"))
    if not os.path.exists(os.path.join(base, "auth.json")):
        raise ProviderError("codex_not_installed", "Install Codex CLI and log in with your ChatGPT account")
    try:
        result = _codex_from_api(base)
        if result["windows"]:
            return result
        api_error = "the API returned no limits"
    except Exception as e:  # Fallback to local logs if API fails
        api_error = str(e)
    result = _codex_from_sessions(base)
    if result:
        return result
    raise ProviderError("codex_no_data", f"No ChatGPT data ({api_error}). Use Codex once to generate it", {"detail": api_error})


# --- Gemini ---

def _antigravity_server():
    for pid in filter(str.isdigit, os.listdir("/proc")):
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                args = f.read().decode(errors="replace").split("\0")
        except OSError:
            continue
        if args and "language_server" in os.path.basename(args[0]) and "--csrf_token" in args:
            return pid, args[args.index("--csrf_token") + 1]
    return None, None


def _listening_ports(pid):
    out = subprocess.run(["ss", "-tlnpH"], capture_output=True, text=True, timeout=5).stdout
    return sorted(set(re.findall(r"127\.0\.0\.1:(\d+)\s.*pid=" + pid + r",", out)), key=int)


def gemini():
    pid, csrf = _antigravity_server()
    if not pid:
        raise ProviderError("antigravity_not_running", "Open Antigravity to read Gemini quota")
    body = json.dumps({"metadata": {"ideName": "antigravity", "extensionName": "antigravity", "locale": "es"}}).encode()
    headers = {"Content-Type": "application/json", "Connect-Protocol-Version": "1", "X-Codeium-Csrf-Token": csrf}
    insecure = ssl._create_unverified_context()  # SSL localhost
    data = None
    for port in _listening_ports(pid):
        for scheme in ("https", "http"):
            url = f"{scheme}://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/GetUserStatus"
            try:
                data = http_json(url, headers, body, insecure if scheme == "https" else None)
                break
            except Exception:
                continue
        if data:
            break
    if not data:
        raise ProviderError("antigravity_no_response", "Antigravity server did not respond")

    status = data.get("userStatus") or {}
    # Group models that share quota
    groups = {}
    configs = (status.get("cascadeModelConfigData") or {}).get("clientModelConfigs") or []
    for model in configs:
        quota = model.get("quotaInfo")
        if not quota:
            continue
        percent = round((1 - quota.get("remainingFraction", 0)) * 100, 1)
        resets_at = to_epoch(quota.get("resetTime"))
        label = model.get("label") or "Model"
        groups.setdefault((percent, resets_at), []).append(label)
    windows = []
    for (percent, resets_at), labels in sorted(groups.items(), key=lambda g: -g[0][0]):
        families = list(dict.fromkeys(label.split()[0] for label in labels))
        families_str = "+".join(families)
        w = window("group:" + families_str, "model_group", {"families": families}, "Session · " + " / ".join(families), "session", percent, resets_at)
        w["models"] = labels
        windows.append(w)
    plan = ((status.get("planStatus") or {}).get("planInfo") or {}).get("planName")
    if not windows:
        raise ProviderError("antigravity_no_quotas", "Antigravity returned no model quotas")
    return {"plan": plan, "windows": windows}


# --- Storage and history ---

class Store:
    """JSON storage with file locking."""

    def __init__(self, name):
        os.makedirs(DATA_DIR, exist_ok=True)
        self.path = os.path.join(DATA_DIR, name)

    def __enter__(self):
        self.lock = open(self.path + ".lock", "w")
        fcntl.flock(self.lock, fcntl.LOCK_EX)
        try:
            with open(self.path) as f:
                self.data = json.load(f)
        except (OSError, ValueError):
            self.data = {}
        return self

    def save(self):
        tmp = self.path + ".tmp"
        with open(tmp, "w") as f:
            json.dump(self.data, f, ensure_ascii=False)
        os.replace(tmp, self.path)

    def __exit__(self, *exc):
        self.lock.close()


def from_cache(entry, cached):
    """Loads the last saved state for non-responding providers."""
    now = time.time()
    windows = []
    for w in cached["windows"]:
        if "key" not in w:
            continue
        w = dict(w)
        if w.get("resets_at") and w["resets_at"] <= now:
            w["percent"] = 0.0
            w["resets_at"] = None
        windows.append(w)
    entry.update(ok=True, plan=cached.get("plan"), windows=windows,
                 stale_since=cached["saved_at"], notice=entry.get("error"),
                 notice_id=entry.get("error_id"), notice_args=entry.get("error_args"),
                 error=None, error_id=None, error_args=None)


def record_history(providers, hours):
    now = time.time()
    with Store("history.json") as store:
        series = store.data
        for p in providers:
            if not p["ok"] or p.get("stale_since"):
                continue
            for w in p["windows"]:
                if w["percent"] is None:
                    continue
                points = series.setdefault(p["id"] + "|" + w["key"], [])
                if not points or now - points[-1][0] >= HISTORY_MIN_GAP or points[-1][1] != w["percent"]:
                    points.append([round(now), w["percent"]])
        cutoff = now - HISTORY_DAYS * 86400
        for key in list(series):
            suffix = key.split("|", 1)[1] if "|" in key else ""
            if not (re.match(r"^[a-z_]+$", suffix) or suffix.startswith("group:")):
                del series[key]
                continue
            series[key] = [pt for pt in series[key] if pt[0] >= cutoff]
            if not series[key]:
                del series[key]
        store.save()

    since = now - hours * 3600
    for p in providers:
        p["history"] = []
        for w in p["windows"]:
            points = [pt for pt in series.get(p["id"] + "|" + w["key"], []) if pt[0] >= since]
            step = max(1, len(points) // HISTORY_MAX_POINTS)
            sampled = points[::step]
            if points and sampled[-1] is not points[-1]:
                sampled.append(points[-1])
            p["history"].append({"key": w["key"], "label_id": w["label_id"], "label_args": w["label_args"], "label": w["label"], "kind": w["kind"], "points": sampled})


PROVIDERS = {
    "claude": ("Claude", claude),
    "chatgpt": ("ChatGPT", chatgpt),
    "gemini": ("Gemini", gemini),
}


def run(provider_id):
    name, fetch = PROVIDERS[provider_id]
    entry = {"id": provider_id, "name": name, "ok": False, "plan": None, "windows": [], "error": None, "error_id": None, "error_args": None}
    try:
        entry.update(fetch())
        entry["ok"] = True
    except ProviderError as e:
        entry["error"] = e.message
        entry["error_id"] = e.error_id
        entry["error_args"] = e.error_args
    except Exception as e:
        entry["error"] = f"{type(e).__name__}: {e}"
        entry["error_id"] = "unexpected"
        entry["error_args"] = {"detail": f"{type(e).__name__}: {e}"}
    return entry


def main():
    args = sys.argv[1:]
    hours = 168
    if "--hours" in args:
        i = args.index("--hours")
        hours = float(args[i + 1])
        del args[i:i + 2]
    ids = [a for a in args if a in PROVIDERS] or list(PROVIDERS)
    with ThreadPoolExecutor(len(ids)) as pool:
        providers = list(pool.map(run, ids))

    with Store("last.json") as store:
        for p in providers:
            if p["ok"] and not p.get("stale_since"):
                store.data[p["id"]] = {"plan": p["plan"], "windows": p["windows"], "saved_at": time.time()}
            elif not p["ok"] and p["id"] in store.data:
                from_cache(p, store.data[p["id"]])
        store.save()
    record_history(providers, hours)

    json.dump({"generated_at": time.time(), "providers": providers}, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
