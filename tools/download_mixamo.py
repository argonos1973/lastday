#!/usr/bin/env python3
"""Download the selected animations from Mixamo using its open Chrome session.

The Adobe token stays inside the browser. Export requests use the same API and
preferences as Mixamo's web client. --metadata-only needs no Adobe session.
Sources are kept outside Godot's import scan; integrate reviewed clips separately.
"""

import argparse
import concurrent.futures
import csv
import hashlib
import json
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request


ROOT = Path(__file__).resolve().parents[1]
API = "https://www.mixamo.com/api/v1"
PUBLIC_HEADERS = {"X-Api-Key": "mixamo2", "Accept": "application/json"}
X_BOT = "2dee24f8-3b49-48af-b735-c6377509eaac"
PREFERENCES = {"format": "fbx7_2019", "skin": "false", "fps": "30", "reducekf": "0"}
SKIP = {"alternative_fast_family", "requires_crawl_gameplay_and_armed_review", "cause_specific"}
GENERAL = [
    ("throw_object", "Throw", "c9cb09fa-b96c-11e4-a802-0aaa78deedf9"),
    ("dig", "Digging", "c9c6cd3e-b96c-11e4-a802-0aaa78deedf9"),
    ("pick_fruit", "Pick Fruit", "c9cda6af-b96c-11e4-a802-0aaa78deedf9"),
    ("injured_walk", "Injured Walk", "c9cdc569-b96c-11e4-a802-0aaa78deedf9"),
    ("injured_idle", "Injured Idle", "c9ce52f6-b96c-11e4-a802-0aaa78deedf9"),
]


def selection(roles):
    with (ROOT / "docs/MIXAMO_RIFLE_CANDIDATES.csv").open() as stream:
        rows = list(csv.DictReader(stream))
    rows += [
        {"role": role, "mixamo_name": name, "motion_id": motion_id,
         "selection_status": "review_general"}
        for role, name, motion_id in GENERAL
    ]
    if roles:
        wanted = set(roles.split(","))
        missing = wanted - {row["role"] for row in rows}
        if missing:
            raise RuntimeError("Roles desconocidos: " + ", ".join(sorted(missing)))
        return [row for row in rows if row["role"] in wanted]
    return [row for row in rows if row["selection_status"] not in SKIP]


def official_metadata(row):
    request = urllib.request.Request(API + "/products/" + row["motion_id"], headers=PUBLIC_HEADERS)
    with urllib.request.urlopen(request, timeout=40) as response:
        product = json.load(response)
    if product.get("id") != row["motion_id"] or product.get("name") != row["mixamo_name"]:
        raise RuntimeError("El catálogo oficial no coincide con " + row["role"])
    details = product.get("details") or {}
    if not details.get("gms_hash"):
        raise RuntimeError("Sin datos de exportación para " + row["role"])
    clip = dict(details["gms_hash"])
    # Mixamo's gmsifySequence serializes slider values as a comma-separated string.
    clip["params"] = ",".join(str(param[1]) for param in clip.get("params", []))
    if details.get("supports_inplace"):
        clip["inplace"] = True
    return {
        **row,
        "description": product.get("description", ""),
        "duration": details.get("duration"),
        "loopable": details.get("loopable"),
        "supports_inplace": details.get("supports_inplace"),
        "gms_hash": [clip],
    }


class Browser:
    """A bounded asynchronous fetch in the existing Mixamo tab, without token extraction."""

    KEY = "__lastdayMixamoDownload"

    @staticmethod
    def execute(javascript):
        literal = json.dumps(javascript.replace("\n", " "))
        script = f"""
tell application "Google Chrome"
 repeat with browserWindow in windows
  repeat with browserTab in tabs of browserWindow
   if URL of browserTab starts with "https://www.mixamo.com/" then
    return execute browserTab javascript {literal}
   end if
  end repeat
 end repeat
 error "Abre Mixamo e inicia sesion en Adobe."
end tell
"""
        result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True, timeout=30)
        if result.returncode:
            raise RuntimeError(
                "Chrome no permite controlar Mixamo. Activa Ver > Opciones para desarrolladores > "
                "Permitir JavaScript desde Eventos de Apple, y abre una sesion Adobe en Mixamo."
            )
        return result.stdout.strip()

    def fetch(self, path, payload=None):
        # Only the browser sets Authorization. Never return or log the token.
        config = {"path": path, "method": "GET" if payload is None else "POST", "body": payload}
        setup = f"""
(() => {{
 const key={json.dumps(self.KEY)}, cfg={json.dumps(config)};
 if (window[key] && !window[key].done) return 'BUSY';
 const token=localStorage.getItem('access_token');
 if (!token) return 'LOGIN_REQUIRED';
 window[key]={{done:false}};
 (async () => {{
  let status=0;
  try {{
   const response=await fetch('/api/v1'+cfg.path, {{
    method:cfg.method,
    headers:{{'X-Api-Key':'mixamo2','Authorization':'Bearer '+token,'Content-Type':'application/json'}},
    body:cfg.body===null?undefined:JSON.stringify(cfg.body),
    signal:AbortSignal.timeout(45000)
   }});
   status=response.status;
   const data=await response.json();
   window[key]={{done:true,status:response.status,data:{{
    uuid:data.uuid,status:data.status,job_result:data.job_result,
    character_id:data.character_id
   }}}};
  }} catch (error) {{ window[key]={{done:true,status:status,error:error.name}}; }}
 }})();
 return 'STARTED';
}})()
"""
        started = self.execute(setup)
        if started != "STARTED":
            raise RuntimeError("Mixamo: " + started)
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            state = json.loads(self.execute(f"JSON.stringify(window[{json.dumps(self.KEY)}] || {{}})"))
            if state.get("done"):
                self.execute(f"delete window[{json.dumps(self.KEY)}]; 'CLEARED'")
                if state.get("error"):
                    raise RuntimeError("Mixamo: %s (HTTP %s). Reintenta para reanudar." % (
                        state["error"], state.get("status")))
                if not 200 <= state.get("status", 0) < 300:
                    raise RuntimeError(
                        "Mixamo HTTP %s. Comprueba la sesion Adobe en Chrome." % state.get("status")
                    )
                return state["data"]
            time.sleep(0.4)
        raise RuntimeError("Mixamo no respondio dentro del tiempo limite.")

    def export(self, motion, character_id):
        payload = {
            "character_id": character_id, "type": "Motion",
            "product_name": motion["mixamo_name"],
            "gms_hash": motion["gms_hash"], "preferences": PREFERENCES,
        }
        job = self.fetch("/animations/export", payload)
        job_id = job.get("uuid")
        if not job_id:
            raise RuntimeError("Mixamo no ha creado el trabajo de exportacion.")
        deadline = time.monotonic() + 240
        while time.monotonic() < deadline:
            time.sleep(3)
            result = self.fetch("/characters/" + urllib.parse.quote(job_id, safe="") + "/monitor")
            if result.get("status") == "completed":
                url = result.get("job_result")
                if not isinstance(url, str) or urllib.parse.urlparse(url).scheme != "https":
                    raise RuntimeError("Mixamo no ha devuelto una descarga HTTPS.")
                return url
            if result.get("status") == "failed":
                raise RuntimeError("Mixamo no ha podido generar " + motion["role"])
        raise RuntimeError("La exportacion ha superado el tiempo limite: " + motion["role"])


def download_fbx(url, destination):
    # Signed download URLs stay in memory and never enter logs or provenance files.
    try:
        with urllib.request.urlopen(url, timeout=90) as response:
            content = response.read(32 * 1024 * 1024 + 1)
    except urllib.error.URLError:
        raise RuntimeError("No se pudo descargar el FBX generado por Mixamo.") from None
    if len(content) > 32 * 1024 * 1024:
        raise RuntimeError("FBX mayor de 32 MiB: revisar la exportacion sin skin.")
    if not content.startswith(b"Kaydara FBX Binary  \x00\x1a\x00"):
        raise RuntimeError("La respuesta no contiene un FBX binario.")
    temporary = destination.with_suffix(".part")
    temporary.write_bytes(content)
    temporary.replace(destination)
    return {"file": destination.name, "bytes": len(content), "sha256": hashlib.sha256(content).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--roles", help="Roles separados por comas; por defecto selecciona una familia rapida.")
    parser.add_argument("--metadata-only", action="store_true", help="Consulta el catalogo publico sin usar Chrome.")
    parser.add_argument("--out", type=Path, default=ROOT / "assets_src/mixamo")
    args = parser.parse_args()
    rows = selection(args.roles)
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        motions = list(pool.map(official_metadata, rows))
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / ".gdignore").touch()
    catalog = {"source": "https://www.mixamo.com/", "character_id": X_BOT,
               "preferences": PREFERENCES, "motions": motions}
    catalog_path = args.out / "catalog.json"
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
    print("Catalogo oficial: %d variantes verificadas." % len(motions), flush=True)
    if args.metadata_only:
        return
    browser = Browser()
    character = browser.fetch("/characters/" + X_BOT)
    character_id = character.get("character_id") or X_BOT
    manifest_path = args.out / "downloads.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    for number, motion in enumerate(motions, 1):
        role = motion["role"]
        target = args.out / (role + ".fbx")
        previous = manifest.get(role, {})
        if target.exists():
            digest = hashlib.sha256(target.read_bytes()).hexdigest()
            if (previous.get("motion_id") == motion["motion_id"]
                    and previous.get("character_id") == character_id
                    and previous.get("preferences") == PREFERENCES
                    and previous.get("gms_hash") == motion["gms_hash"]
                    and previous.get("sha256") == digest):
                print("[%d/%d] Ya descargado: %s" % (number, len(motions), role), flush=True)
                continue
            raise RuntimeError("Existe un archivo sin procedencia coincidente: " + str(target))
        url = browser.export(motion, character_id)
        receipt = download_fbx(url, target)
        manifest[role] = {**motion, "character_id": character_id,
                          "preferences": PREFERENCES, **receipt}
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        print("[%d/%d] %s: %d bytes" % (number, len(motions), role, receipt["bytes"]), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, urllib.error.URLError, subprocess.TimeoutExpired) as error:
        raise SystemExit(str(error)) from None
