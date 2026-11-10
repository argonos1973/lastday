#!/usr/bin/env python3
"""Demonio STT para Last Day: Groq whisper-large-v3 (rapido + calidad) con
fallback local a faster-whisper (CPU int8) si la API no responde.

El servidor Godot escribe frases PCM 8-bit/12 kHz como WAV en el directorio
de trabajos (<user://>/voice_jobs, gestionado por SurvivorBotManager). Este
demonio las transcribe a <base>.txt y borra el WAV. El juego recoge el texto
y lo procesa como chat/ordenes/ensenanzas del bot.

Uso:
    python3 stt_daemon.py [JOBS_DIR]

Entorno:
    GROQ_API_KEY   -> si existe, transcribe via API (whisper-large-v3, ~0.5 s)
    STT_MODEL      -> modelo local de reserva (defecto "small")
    STT_POLL       -> segundos entre barridos (defecto 0.30)

Dependencias:  pip3 install faster-whisper  (solo para el fallback local)
Nota: faster-whisper 1.2.x + av>=15 rompe por `metadata_errors`; si se
reinstala, parchear audio.py quitando ese kwarg de av.open().
"""

import json
import os
import sys
import time
import uuid
import urllib.request
import urllib.error

JOBS = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/.local/share/godot/app_userdata/Un dia mas/voice_jobs")
MODEL = os.environ.get("STT_MODEL", "small")
POLL = float(os.environ.get("STT_POLL", "0.30"))
GROQ_KEY = os.environ.get("GROQ_API_KEY", "").strip()
GROQ_MODEL = os.environ.get("GROQ_STT_MODEL", "whisper-large-v3")
GROQ_URL = "https://api.groq.com/openai/v1/audio/transcriptions"
GROQ_TIMEOUT = 10.0

_model = None
_model_failed = False


def _groq_transcribe(wav_path):
    """Transcribe via Groq API (whisper-large-v3). Devuelve texto o None."""
    if not GROQ_KEY:
        return None
    boundary = "----ldstt%s" % uuid.uuid4().hex
    try:
        with open(wav_path, "rb") as f:
            audio = f.read()
        body = bytearray()

        def field(name, value):
            body.extend(("--%s\r\nContent-Disposition: form-data; "
                         'name="%s"\r\n\r\n%s\r\n'
                         % (boundary, name, value)).encode())

        field("model", GROQ_MODEL)
        field("language", "es")
        field("response_format", "json")
        body.extend(("--%s\r\nContent-Disposition: form-data; name=\"file\"; "
                     "filename=\"clip.wav\"\r\nContent-Type: audio/wav\r\n\r\n"
                     % boundary).encode())
        body.extend(audio)
        body.extend(("\r\n--%s--\r\n" % boundary).encode())

        req = urllib.request.Request(
            GROQ_URL, data=bytes(body),
            headers={
                "Authorization": "Bearer " + GROQ_KEY,
                "Content-Type": "multipart/form-data; boundary=" + boundary,
                # Cloudflare rechaza el UA por defecto de urllib (403)
                "User-Agent": "lastday-stt/1.0",
            }, method="POST")
        with urllib.request.urlopen(req, timeout=GROQ_TIMEOUT) as r:
            data = json.loads(r.read().decode("utf-8", "replace"))
        return str(data.get("text", "")).strip()
    except Exception as e:  # noqa: BLE001
        print("[stt] groq fallo (%s)" % e, flush=True)
        return None


def _local_model():
    global _model, _model_failed
    if _model is None and not _model_failed:
        try:
            from faster_whisper import WhisperModel
            _model = WhisperModel(MODEL, device="cpu", compute_type="int8")
            print("[stt] fallback local listo (modelo=%s)" % MODEL, flush=True)
        except Exception as e:  # noqa: BLE001
            _model_failed = True
            print("[stt] fallback local indisponible: %s" % e, flush=True)
    return _model


def _local_transcribe(wav_path):
    m = _local_model()
    if m is None:
        return ""
    try:
        segs, _ = m.transcribe(wav_path, language="es", beam_size=1,
                               vad_filter=True)
        return " ".join(s.text.strip() for s in segs).strip()
    except Exception as e:  # noqa: BLE001
        print("[stt] local fallo: %s" % e, flush=True)
        return ""


def transcribe(wav_path):
    t0 = time.time()
    text = _groq_transcribe(wav_path)
    backend = "groq" if text is not None else "local"
    if text is None:
        text = _local_transcribe(wav_path)
    return text or "", backend, time.time() - t0


def main():
    os.makedirs(JOBS, exist_ok=True)
    mode = "groq(%s)+local(%s)" % (GROQ_MODEL, MODEL) if GROQ_KEY \
        else "local(%s)" % MODEL
    print("[stt] demonio listo — dir=%s backend=%s" % (JOBS, mode), flush=True)

    while True:
        try:
            for fn in sorted(os.listdir(JOBS)):
                if not fn.endswith(".wav"):
                    continue
                wav = os.path.join(JOBS, fn)
                out = wav[:-4] + ".txt"
                if os.path.exists(out):
                    continue
                try:
                    s1 = os.path.getsize(wav)
                    time.sleep(0.05)
                    if os.path.getsize(wav) != s1:
                        continue  # el juego aun esta escribiendo
                    text, backend, dt = transcribe(wav)
                except Exception as e:  # noqa: BLE001
                    print("[stt] %s: %s" % (fn, e), flush=True)
                    text = ""
                with open(out, "w", encoding="utf-8") as f:
                    f.write(text)
                try:
                    os.remove(wav)
                except OSError:
                    pass
                if text:
                    print("[stt] %s [%s %.2fs]: %s"
                          % (fn, backend, dt, text[:90]), flush=True)
        except FileNotFoundError:
            os.makedirs(JOBS, exist_ok=True)
        except Exception as e:  # noqa: BLE001
            print("[stt] error: %s" % e, flush=True)
        time.sleep(POLL)


if __name__ == "__main__":
    sys.exit(main())
