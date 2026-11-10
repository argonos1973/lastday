#!/usr/bin/env python3
"""Demonio STT local para Last Day (faster-whisper, CPU).

El servidor Godot escribe frases PCM 8-bit/12 kHz como WAV en el directorio
de trabajos (<user://>/voice_jobs, gestionado por SurvivorBotManager). Este
demonio las transcribe a <base>.txt y borra el WAV. El juego recoge el texto
y lo procesa como chat/ordenes/ensenanzas del bot.

Uso:
    python3 stt_daemon.py [JOBS_DIR]

Dependencias:  pip3 install faster-whisper
Modelo por defecto "base" (~150 MB, int8) — suficiente para frases cortas en
espanol; STT_MODEL=tiny|small para ajustar calidad/latencia.
"""

import os
import sys
import time

JOBS = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/.local/share/godot/app_userdata/Un dia mas/voice_jobs")
MODEL = os.environ.get("STT_MODEL", "base")
POLL = float(os.environ.get("STT_POLL", "0.30"))


def main() -> int:
    os.makedirs(JOBS, exist_ok=True)
    from faster_whisper import WhisperModel
    model = WhisperModel(MODEL, device="cpu", compute_type="int8")
    print(f"[stt] demonio listo — dir={JOBS} modelo={MODEL}", flush=True)

    while True:
        try:
            for fn in sorted(os.listdir(JOBS)):
                if not fn.endswith(".wav"):
                    continue
                wav = os.path.join(JOBS, fn)
                out = wav[:-4] + ".txt"
                if os.path.exists(out):
                    continue
                # WAV aun abierto por el juego: esperar a que crezca pare
                try:
                    s1 = os.path.getsize(wav)
                    time.sleep(0.05)
                    if os.path.getsize(wav) != s1:
                        continue
                    segs, _ = model.transcribe(
                        wav, language="es", beam_size=1, vad_filter=True)
                    text = " ".join(s.text.strip() for s in segs).strip()
                except Exception as e:  # noqa: BLE001
                    print(f"[stt] {fn}: {e}", flush=True)
                    text = ""
                with open(out, "w", encoding="utf-8") as f:
                    f.write(text)
                try:
                    os.remove(wav)
                except OSError:
                    pass
                if text:
                    print(f"[stt] {fn}: {text[:90]}", flush=True)
        except FileNotFoundError:
            os.makedirs(JOBS, exist_ok=True)
        except Exception as e:  # noqa: BLE001
            print(f"[stt] error: {e}", flush=True)
        time.sleep(POLL)


if __name__ == "__main__":
    sys.exit(main())
