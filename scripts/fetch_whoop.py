"""
Pulls yesterday's + today's WHOOP data (recovery, sleep, workouts, cycle/strain)
and writes it into data/<date>.json, merging with any existing notes/photos
added via admin.html. Also refreshes the OAuth token and writes the new
rotating refresh token back into the repo's GitHub Actions secret.

Run by .github/workflows/daily.yml. Requires these environment variables:
  WHOOP_CLIENT_ID, WHOOP_CLIENT_SECRET, WHOOP_REFRESH_TOKEN   (WHOOP OAuth app)
  GH_PAT                                                       (fine-grained PAT, Secrets: write, this repo only)
  GITHUB_REPOSITORY                                            (auto-set by Actions, "owner/repo")
"""
import base64
import json
import os
import sys
import time
from datetime import datetime, timedelta, timezone

import requests
from nacl import encoding, public

WHOOP_TOKEN_URL = "https://api.prod.whoop.com/oauth/oauth2/token"
WHOOP_API_BASE = "https://api.prod.whoop.com/developer/v2"
DATA_DIR = "data"
MANIFEST_PATH = os.path.join(DATA_DIR, "manifest.json")
INDEX_PATH = os.path.join(DATA_DIR, "index.json")


def env(name):
    val = os.environ.get(name)
    if not val:
        print(f"::error::Missing required environment variable {name}")
        sys.exit(1)
    return val


def refresh_token():
    resp = requests.post(WHOOP_TOKEN_URL, data={
        "grant_type": "refresh_token",
        "refresh_token": env("WHOOP_REFRESH_TOKEN"),
        "client_id": env("WHOOP_CLIENT_ID"),
        "client_secret": env("WHOOP_CLIENT_SECRET"),
        "scope": "offline",
    })
    resp.raise_for_status()
    payload = resp.json()
    return payload["access_token"], payload["refresh_token"]


def write_back_refresh_token(new_refresh_token):
    """Encrypts and stores the new (rotated) refresh token as a repo secret,
    so the next scheduled run can use it."""
    repo = env("GITHUB_REPOSITORY")
    gh_pat = env("GH_PAT")
    headers = {"Authorization": f"Bearer {gh_pat}", "Accept": "application/vnd.github+json"}

    key_resp = requests.get(f"https://api.github.com/repos/{repo}/actions/secrets/public-key", headers=headers)
    key_resp.raise_for_status()
    key_data = key_resp.json()

    public_key = public.PublicKey(key_data["key"].encode("utf-8"), encoding.Base64Encoder())
    sealed_box = public.SealedBox(public_key)
    encrypted = sealed_box.encrypt(new_refresh_token.encode("utf-8"))
    encrypted_b64 = base64.b64encode(encrypted).decode("utf-8")

    put_resp = requests.put(
        f"https://api.github.com/repos/{repo}/actions/secrets/WHOOP_REFRESH_TOKEN",
        headers=headers,
        json={"encrypted_value": encrypted_b64, "key_id": key_data["key_id"]},
    )
    put_resp.raise_for_status()
    print("Refresh token rotated and stored.")


def whoop_get(path, token, params=None):
    resp = requests.get(f"{WHOOP_API_BASE}{path}", headers={"Authorization": f"Bearer {token}"}, params=params or {})
    resp.raise_for_status()
    return resp.json()


def whoop_get_all(path, token, start, max_pages=40):
    """Fetches every page of a WHOOP collection endpoint.

    The v2 API caps `limit` at 25 and paginates with `next_token`, so a long
    backfill needs to follow the chain rather than take the first page only.
    """
    records = []
    params = {"start": start, "limit": 25}
    for page in range(max_pages):
        data = whoop_get(path, token, params)
        records.extend(data.get("records", []))
        token_next = data.get("next_token")
        if not token_next:
            break
        params = {"start": start, "limit": 25, "nextToken": token_next}
        time.sleep(0.15)   # stay comfortably inside 100 req/min
    else:
        print(f"::warning::{path}: se alcanzó el máximo de {max_pages} páginas")
    return records


def decide_days_back():
    """First run backfills history; afterwards only the last couple of days.

    Override with the DAYS_BACK environment variable if ever needed.
    """
    override = os.environ.get("DAYS_BACK")
    if override:
        return int(override)
    existing = [f for f in os.listdir(DATA_DIR)
                if f.endswith(".json") and f not in ("index.json", "manifest.json")] \
        if os.path.isdir(DATA_DIR) else []
    if len(existing) < 30:
        print(f"Solo hay {len(existing)} días guardados: recuperando historial de 180 días.")
        return 180
    return 2


def fetch_window(token, days_back=2):
    start = (datetime.now(timezone.utc) - timedelta(days=days_back)).isoformat()
    recovery = whoop_get_all("/recovery", token, start)
    sleep = whoop_get_all("/activity/sleep", token, start)
    workouts = whoop_get_all("/activity/workout", token, start)
    cycles = whoop_get_all("/cycle", token, start)
    print(f"Descargado: {len(recovery)} recuperaciones, {len(sleep)} sueños, "
          f"{len(workouts)} entrenos, {len(cycles)} ciclos")
    return recovery, sleep, workouts, cycles


def date_key(iso_str):
    return iso_str[:10]


def load_json(path, default):
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    return default


def save_json(path, obj):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)


def merge_day(date, recovery_rec, sleep_rec, cycle_rec, workout_recs):
    path = os.path.join(DATA_DIR, f"{date}.json")
    day = load_json(path, {"date": date, "notes": "", "photos": [], "tipo": None, "etiquetas": []})
    # never clobber fields the user authored in admin.html
    day.setdefault("notes", "")
    day.setdefault("photos", [])
    day.setdefault("etiquetas", [])

    if cycle_rec:
        day["day_strain"] = round(cycle_rec.get("score", {}).get("strain", 0), 1) if cycle_rec.get("score") else day.get("day_strain")
    if recovery_rec and recovery_rec.get("score"):
        s = recovery_rec["score"]
        day["recovery_score"] = s.get("recovery_score")
        day["hrv_rmssd_milli"] = round(s.get("hrv_rmssd_milli", 0), 1) if s.get("hrv_rmssd_milli") else None
        day["resting_heart_rate"] = s.get("resting_heart_rate")
    if sleep_rec and sleep_rec.get("score"):
        s = sleep_rec["score"]
        day["sleep_performance_percentage"] = s.get("sleep_performance_percentage")
        day["sleep_efficiency_percentage"] = s.get("sleep_efficiency_percentage")

    if workout_recs:
        day["workouts"] = [{
            "sport_name": w.get("sport_name"),
            "strain": round(w["score"]["strain"], 1) if w.get("score", {}).get("strain") else None,
            "average_heart_rate": w.get("score", {}).get("average_heart_rate"),
            "duration_min": round((
                (datetime.fromisoformat(w["end"].replace("Z", "+00:00")) -
                 datetime.fromisoformat(w["start"].replace("Z", "+00:00"))).total_seconds() / 60
            )) if w.get("start") and w.get("end") else None,
        } for w in workout_recs]

    save_json(path, day)
    return date


def rebuild_index():
    """Consolidates every data/YYYY-MM-DD.json into a single data/index.json so
    the dashboard loads in one request instead of one per day."""
    days = []
    for name in os.listdir(DATA_DIR):
        if not name.endswith(".json") or name in ("index.json", "manifest.json"):
            continue
        try:
            days.append(load_json(os.path.join(DATA_DIR, name), None))
        except Exception as e:
            print(f"::warning::No se pudo leer {name}: {e}")
    days = [d for d in days if d and d.get("date")]
    days.sort(key=lambda d: d["date"], reverse=True)
    save_json(INDEX_PATH, days)
    save_json(MANIFEST_PATH, [d["date"] for d in days])
    return len(days)


def main():
    access_token, new_refresh_token = refresh_token()
    write_back_refresh_token(new_refresh_token)

    recovery, sleep, workouts, cycles = fetch_window(access_token, days_back=decide_days_back())

    by_date_recovery = {date_key(r["created_at"]): r for r in recovery} if recovery else {}
    by_date_sleep = {date_key(s["start"]): s for s in sleep} if sleep else {}
    by_date_cycle = {date_key(c["start"]): c for c in cycles} if cycles else {}
    by_date_workouts = {}
    for w in workouts or []:
        by_date_workouts.setdefault(date_key(w["start"]), []).append(w)

    all_dates = set(by_date_recovery) | set(by_date_sleep) | set(by_date_cycle) | set(by_date_workouts)
    touched = []
    for d in sorted(all_dates):
        merge_day(d, by_date_recovery.get(d), by_date_sleep.get(d), by_date_cycle.get(d), by_date_workouts.get(d))
        touched.append(d)

    total = rebuild_index()
    print(f"Días actualizados: {touched}")
    print(f"Índice reconstruido: {total} días en total")


if __name__ == "__main__":
    main()
