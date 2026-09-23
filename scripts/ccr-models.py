#!/usr/bin/env python3
"""Point the CCR Codex profile at every OpenCode Zen model that is free today.

Data sources
------------
* https://models.dev/api.json -- the catalogue OpenCode itself consumes.  We
  read this endpoint directly instead of ~/.cache/opencode/models.json, which
  is only a local copy of it.
* https://opencode.ai/zen/v1/models -- what the Zen endpoint currently serves.
  Availability is decided here rather than by models.dev's ``status`` field,
  which lags badly: ``mimo-v2.5-free`` is marked deprecated yet still works,
  while other deprecated models have been withdrawn.  A model is selected when
  models.dev prices it at zero AND the live endpoint still lists it.

What it writes
--------------
Only ``~/.claude-code-router/config.sqlite`` (table ``app_config``, key
``default``) is written: the OpenCode Zen provider's model list and per-model
metadata, plus the single Codex profile.  The metadata matters because CCR
builds Codex's ``supported_reasoning_levels`` from
``Providers[].modelMetadata``; without it Codex has no reasoning picker.  CCR
regenerates ``gateway.config.json`` and the Codex model catalogue from that on
the next start, so CCR is stopped first when applying.  Every other CCR
profile (the old Claude Code ones) is removed.

The command is a no-op when nothing changed.  Use ``--dry-run`` to preview.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import urllib.error
import urllib.request

MODELS_DEV_URL = "https://models.dev/api.json"
ZEN_MODELS_URL = "https://opencode.ai/zen/v1/models"

# models.dev provider key and the CCR provider name / base URL it corresponds to.
MODELS_DEV_PROVIDER = "opencode"
CCR_PROVIDER_NAME = "OpenCode Zen"
CCR_PROVIDER_HOST = "opencode.ai"

CODEX_AGENT = "codex"
CODEX_PROFILE_ID = "default-codex"

CCR_DIR = os.path.join(
    os.environ.get("HOME") or os.path.expanduser("~"), ".claude-code-router"
)
CONFIG_DB = os.path.join(CCR_DIR, "config.sqlite")
PROFILES_DIR = os.path.join(CCR_DIR, "profiles")


# Cloudflare in front of both endpoints rejects the default Python user-agent.
USER_AGENT = "ccr-models/1.0 (+https://github.com/lexi/nixway)"


def fetch_json(url: str, headers: dict | None = None, timeout: int = 30):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, **(headers or {})})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.load(response)


def load_config(conn: sqlite3.Connection) -> dict:
    row = conn.execute(
        "SELECT value_json FROM app_config WHERE key = 'default' LIMIT 1"
    ).fetchone()
    if not row or not row[0]:
        raise SystemExit("ccr-models: no 'default' config found in config.sqlite")
    return json.loads(row[0])


def find_provider(config: dict) -> dict:
    for provider in config.get("Providers") or []:
        name = provider.get("name") or ""
        base = provider.get("api_base_url") or ""
        if name == CCR_PROVIDER_NAME or CCR_PROVIDER_HOST in base:
            return provider
    raise SystemExit("ccr-models: no OpenCode Zen provider configured in CCR")


def select_free_models(models_dev: dict, zen_ids: set[str]) -> list[tuple[str, int]]:
    """Return (model_id, context_window) for every free, currently-served model."""
    models = (models_dev.get(MODELS_DEV_PROVIDER) or {}).get("models") or {}
    selected: list[tuple[str, int]] = []
    for model_id, meta in models.items():
        cost = meta.get("cost") or {}
        if cost.get("input") != 0 or cost.get("output") != 0:
            continue
        if model_id not in zen_ids:
            continue
        context = (meta.get("limit") or {}).get("context") or 0
        selected.append((model_id, int(context)))
    selected.sort()
    return selected


# CCR keeps only these effort names when building Codex's reasoning picker.
REASONING_EFFORTS = ("low", "medium", "high", "xhigh", "max", "ultra")
DEFAULT_EFFORTS = ("low", "medium", "high")


def reasoning_description(effort: str) -> str:
    if effort == "xhigh":
        return "Extra high"
    if effort == "ultra":
        return "Maximum"
    return effort.capitalize()


def model_metadata(models_dev: dict, model_id: str) -> dict | None:
    """Per-model CCR metadata, mainly the Codex reasoning picker options.

    Uses models.dev's explicit effort values when it declares them.  Models
    that only advertise ``reasoning: true`` (no effort list) still get the
    low/medium/high picker CCR has always shown for them; CCR's gateway
    normalises the chosen effort anyway.
    """
    models = (models_dev.get(MODELS_DEV_PROVIDER) or {}).get("models") or {}
    meta = models.get(model_id) or {}
    efforts: list[str] = []
    for option in meta.get("reasoning_options") or []:
        if not isinstance(option, dict):
            continue
        if str(option.get("type", "")).lower() != "effort":
            continue
        for value in option.get("values") or []:
            effort = str(value).lower()
            if effort in REASONING_EFFORTS and effort not in efforts:
                efforts.append(effort)
    if not efforts and meta.get("reasoning"):
        efforts = list(DEFAULT_EFFORTS)
    if not efforts:
        return None

    entry: dict = {
        "supportedReasoningLevels": [
            {"description": reasoning_description(effort), "effort": effort}
            for effort in efforts
        ],
        "defaultReasoningLevel": "medium" if "medium" in efforts else efforts[0],
        "supportsReasoningSummaries": bool(meta.get("reasoning")),
    }
    context = (meta.get("limit") or {}).get("context")
    if context:
        entry["contextWindow"] = entry["maxContextWindow"] = int(context)
    return entry


def choose_default(free: list[tuple[str, int]], current_id: str) -> str:
    """Keep the current model when it is still free, else take the widest one."""
    model_ids = [model_id for model_id, _ in free]
    if current_id in model_ids:
        return current_id
    if not free:
        raise SystemExit("ccr-models: no free OpenCode Zen models found")
    # Widest context first, then alphabetical for a stable choice.
    return sorted(free, key=lambda item: (-item[1], item[0]))[0][0]


def bare_model_id(model: str) -> str:
    return model.split("/", 1)[1] if "/" in model else model


def utc_now() -> str:
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%S.%f"
    )
    return f"{stamp[:-3]}Z"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run", action="store_true", help="preview changes without writing"
    )
    parser.add_argument(
        "--no-stop", action="store_true", help="do not stop CCR before writing"
    )
    args = parser.parse_args(argv)

    if not os.path.exists(CONFIG_DB):
        print(f"ccr-models: {CONFIG_DB} not found", file=sys.stderr)
        return 1

    conn = sqlite3.connect(CONFIG_DB)
    config = load_config(conn)
    provider = find_provider(config)

    api_key = provider.get("api_key") or ""
    headers = {"Authorization": f"Bearer {api_key}"} if api_key else {}
    try:
        models_dev = fetch_json(MODELS_DEV_URL)
        zen = fetch_json(ZEN_MODELS_URL, headers=headers)
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        print(f"ccr-models: could not fetch model lists: {exc}", file=sys.stderr)
        return 1

    zen_ids = {entry.get("id") for entry in zen.get("data") or [] if entry.get("id")}
    free = select_free_models(models_dev, zen_ids)
    if not free:
        print("ccr-models: no free OpenCode Zen models found", file=sys.stderr)
        return 1

    new_models = [model_id for model_id, _ in free]
    old_models = list(provider.get("models") or [])

    profiles = (config.get("profile") or {}).get("profiles") or []
    kept = [p for p in profiles if p.get("agent") == CODEX_AGENT]
    removed = [p for p in profiles if p.get("agent") != CODEX_AGENT]

    # Claude Code directories that have no config entry left (e.g. a
    # half-removed default-claude-code) still need deleting.
    kept_ids = {str(p.get("id") or "") for p in kept}
    removed_ids = {str(p.get("id") or "") for p in removed}
    stray_claude_dirs = []
    if os.path.isdir(PROFILES_DIR):
        stray_claude_dirs = sorted(
            name
            for name in os.listdir(PROFILES_DIR)
            if name not in kept_ids
            and name not in removed_ids
            and "claude" in name.lower()
            and os.path.isdir(os.path.join(PROFILES_DIR, name))
        )

    codex = kept[0] if kept else None
    current_model = (codex or {}).get("model") or ""
    default_id = choose_default(free, bare_model_id(current_model))
    default_model = f"{CCR_PROVIDER_NAME}/{default_id}"

    metadata = {}
    for model_id, _ in free:
        entry = model_metadata(models_dev, model_id)
        if entry:
            metadata[model_id] = entry
    old_metadata = provider.get("modelMetadata") or {}

    print(f"models.dev: {MODELS_DEV_URL}")
    print(f"availability: {ZEN_MODELS_URL}")
    print(f"free & served ({len(new_models)}):")
    for model_id, context in free:
        marker = " *" if model_id == default_id else ""
        entry = metadata.get(model_id) or {}
        levels = [l["effort"] for l in entry.get("supportedReasoningLevels") or []]
        shown = ",".join(levels) if levels else "-"
        print(f"  {model_id:<34} ctx={context:>8} reasoning={shown}{marker}")
    print()
    print(f"provider models: {len(old_models)} -> {len(new_models)}")
    print(f"codex default: {current_model or '(unset)'} -> {default_model}")
    if removed:
        print(f"profiles removed: {', '.join(p.get('id', '?') for p in removed)}")
    if stray_claude_dirs:
        print(f"stale claude dirs removed: {', '.join(stray_claude_dirs)}")

    unchanged = (
        old_models == new_models
        and old_metadata == metadata
        and not removed
        and not stray_claude_dirs
        and codex is not None
        and current_model == default_model
    )
    if unchanged:
        print("\nNothing to update.")
        return 0

    if args.dry_run:
        print("\nDry run: nothing written.")
        return 0

    if not args.no_stop:
        subprocess.run(["ccr", "stop"], check=False, capture_output=True)

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = f"{CONFIG_DB}.bak-{stamp}"
    backup = sqlite3.connect(backup_path)
    with backup:
        conn.backup(backup)
    backup.close()

    provider["models"] = new_models
    provider["modelMetadata"] = metadata
    if codex is None:
        codex = {
            "agent": CODEX_AGENT,
            "scope": "ccr",
            "enabled": True,
            "env": {},
        }
        kept.append(codex)
    codex["id"] = codex.get("id") or CODEX_PROFILE_ID
    codex["name"] = codex.get("name") or "Codex"
    codex["model"] = default_model
    if not codex.get("scope"):
        codex["scope"] = "ccr"

    config.setdefault("profile", {})["profiles"] = kept
    claude = (config.get("profile") or {}).get("claudeCode")
    if isinstance(claude, dict):
        claude["enabled"] = False

    conn.execute(
        "UPDATE app_config SET value_json = ?, updated_at = ? WHERE key = 'default'",
        (json.dumps(config), utc_now()),
    )
    conn.commit()
    conn.close()

    for profile in removed:
        path = os.path.join(PROFILES_DIR, str(profile.get("id") or ""))
        if os.path.isdir(path):
            shutil.rmtree(path)
    for name in stray_claude_dirs:
        path = os.path.join(PROFILES_DIR, name)
        if os.path.isdir(path):
            shutil.rmtree(path)

    print(f"\nBackup: {backup_path}")
    print("Applied. Run 'ccr codex' to launch the Codex profile.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
