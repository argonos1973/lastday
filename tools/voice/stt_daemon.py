#!/usr/bin/env python3
"""Demonio de Voz (STT + TTS realista 24 kHz) para Last Day:
- STT: Groq whisper-large-v3 (~0.3 s, calidad alta) + fallback faster-whisper.
  Convierte v_*.wav -> v_*.txt.
- TTS: Microsoft Edge Neural TTS (edge-tts) a 24 kHz 16-bit wideband MP3:
    * 901 Elena  -> es-ES-XimenaNeural (+0%, +0Hz, voz femenina conversacional)
    * 902 Carlos -> es-ES-AlvaroNeural (+0%, -1Hz, voz masculina natural)
    * 903 Kael   -> es-MX-JorgeNeural  (-2%, -4Hz, voz grave de bandido)
  Incluye restaurador automatico de tildes espanolas para pronunciacion natural,
  ecualizacion calida + recorte de silencio inicial con ffmpeg, cache en disco
  precalentada (<1 ms) y fallback offline a espeak-ng.
  Convierte tts_*.json -> tts_*.mp3 (leido por AudioStreamMP3 en Godot).
"""

import asyncio
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
import re
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid

JOBS = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/.local/share/godot/app_userdata/Un dia mas/voice_jobs")
CACHE_DIR = os.environ.get(
    "TTS_CACHE_DIR", os.path.expanduser("~/lastday-stt/tts_cache"))
MODEL = os.environ.get("STT_MODEL", "small")
POLL = float(os.environ.get("STT_POLL", "0.05"))
GROQ_KEY = os.environ.get("GROQ_API_KEY", "").strip()
GROQ_MODEL = os.environ.get("GROQ_STT_MODEL", "whisper-large-v3")
GROQ_URL = "https://api.groq.com/openai/v1/audio/transcriptions"
GROQ_TIMEOUT = 10.0
STT_PROMPT = (
    "Conversación en español en juego de supervivencia con Elena, Carlos y Kael. "
    "Órdenes: sígueme, quédate quieto, ven aquí, espera, vete, dame agua, dame comida, "
    "ataca, equípate. Enseñanzas: aquí hay agua, puedes beber de esta fuente, "
    "cuidado hay lobos, en esa casa hay loot, recuerda este sitio."
)
HALLUCINATIONS = (
    "subtitulos realizados", "subtítulos realizados", "amara.org",
    "gracias por ver", "suscribete", "suscríbete", "andre valls", "andré valls",
)

BOT_VOICES = {
    901: ("es-ES-XimenaNeural", "+0%", "+0Hz", "es+f3"),
    902: ("es-ES-AlvaroNeural", "+0%", "-1Hz", "es"),
    903: ("es-MX-JorgeNeural", "-2%", "-4Hz", "es+m3"),
}

ACCENT_MAP = {
    "aqui": "aquí", "ahi": "ahí", "alli": "allí", "alla": "allá",
    "tambien": "también", "ademas": "además", "despues": "después",
    "detras": "detrás", "algun": "algún", "ningun": "ningún",
    "sigueme": "sígueme", "quedate": "quédate", "esperame": "espérame",
    "cubreme": "cúbreme", "pasame": "pásame", "dejame": "déjame",
    "olvidate": "olvídate", "cuidate": "cuídate", "marcame": "márcame",
    "pideselo": "pídeselo", "buscate": "búscate", "largate": "lárgate",
    "ordenes": "órdenes", "ire": "iré", "pasare": "pasaré",
    "tendre": "tendré", "andare": "andaré", "estare": "estaré",
    "fio": "fío", "frio": "frío", "rio": "río", "mio": "mío",
    "botiquin": "botiquín", "municion": "munición", "arbol": "árbol",
    "cadaver": "cadáver", "plastico": "plástico", "rapido": "rápido",
    "util": "útil", "facil": "fácil", "dificil": "difícil",
}

PREWARM_LINES = [
    (901, "Vale, voy contigo... tú mandas."),
    (901, "Vale, me quedo aquí vigilando, tranquila."),
    (901, "Voy para allá, espérame un segundo."),
    (901, "Genial, así ya sé dónde venir a beber. Muchas gracias."),
    (901, "Vale, gracias por avisar... tendré cuidado por esta zona."),
    (901, "Perfecto, luego me acerco a echar un vistazo."),
    (901, "Sí, parece buen sitio para descansar... gracias."),
    (901, "Claro, toma... te lo dejo aquí en el suelo."),
    (901, "¡Aguanta ahí, que voy corriendo!"),
    (901, "Buenas, ¿todo bien?"),
    (902, "Vale, voy contigo... tú mandas."),
    (902, "Vale, me quedo aquí vigilando, tranquilo."),
    (902, "Voy para allá, espérame un segundo."),
    (902, "Genial, así ya sé dónde venir a beber. Muchas gracias."),
    (902, "Vale, gracias por avisar... tendré cuidado por esta zona."),
    (902, "Claro, toma... te lo dejo aquí en el suelo."),
    (902, "¡Aguanta ahí, que voy corriendo!"),
    (903, "¿Órdenes? A mí no me mandas."),
    (903, "Pídeselo a otro, tú y yo no somos amigos."),
    (903, "Vale, me quedo con que aquí hay agua."),
]

_model = None
_model_failed = False
_model_lock = threading.Lock()
_in_flight = set()
_in_flight_lock = threading.Lock()


def _restore_spanish_accents(text: str) -> str:
    def repl(m):
        w = m.group(0)
        low = w.lower()
        if low not in ACCENT_MAP:
            return w
        rep = ACCENT_MAP[low]
        if w[0].isupper():
            return rep[0].upper() + rep[1:]
        return rep

    return re.sub(r"\b[A-Za-zÁÉÍÓÚáéíóúñÑ]+\b", repl, text)


def _is_hallucination(text: str) -> bool:
    low = text.strip().lower()
    if not low or low in (".", "...", ",", "!", "?", "¿?", "¡!"):
        return True
    for h in HALLUCINATIONS:
        if h in low:
            return True
    return False


def _groq_transcribe(wav_path: str):
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
                         % (boundary, name, value)).encode("utf-8"))

        field("model", GROQ_MODEL)
        field("language", "es")
        field("temperature", "0")
        field("prompt", STT_PROMPT)
        field("response_format", "json")
        body.extend(("--%s\r\nContent-Disposition: form-data; name=\"file\"; "
                     "filename=\"clip.wav\"\r\nContent-Type: audio/wav\r\n\r\n"
                     % boundary).encode("utf-8"))
        body.extend(audio)
        body.extend(("\r\n--%s--\r\n" % boundary).encode("utf-8"))

        req = urllib.request.Request(
            GROQ_URL, data=bytes(body),
            headers={
                "Authorization": "Bearer " + GROQ_KEY,
                "Content-Type": "multipart/form-data; boundary=" + boundary,
                "User-Agent": "lastday-stt/1.2",
            }, method="POST")
        with urllib.request.urlopen(req, timeout=GROQ_TIMEOUT) as r:
            data = json.loads(r.read().decode("utf-8", "replace"))
        return str(data.get("text", "")).strip()
    except Exception as e:  # noqa: BLE001
        print("[stt] groq fallo (%s)" % e, flush=True)
        return None


def _local_model():
    global _model, _model_failed
    with _model_lock:
        if _model is None and not _model_failed:
            try:
                from faster_whisper import WhisperModel
                _model = WhisperModel(MODEL, device="cpu", compute_type="int8")
                print("[stt] fallback local listo (modelo=%s)" % MODEL, flush=True)
            except Exception as e:  # noqa: BLE001
                _model_failed = True
                print("[stt] fallback local indisponible: %s" % e, flush=True)
        return _model


def _local_transcribe(wav_path: str) -> str:
    m = _local_model()
    if m is None:
        return ""
    try:
        with _model_lock:
            segs, _ = m.transcribe(
                wav_path, language="es", beam_size=1, vad_filter=True,
                initial_prompt=STT_PROMPT)
            return " ".join(s.text.strip() for s in segs).strip()
    except Exception as e:  # noqa: BLE001
        print("[stt] local fallo: %s" % e, flush=True)
        return ""


def transcribe(wav_path: str):
    t0 = time.time()
    text = _groq_transcribe(wav_path)
    backend = "groq" if text is not None else "local"
    if text is None:
        text = _local_transcribe(wav_path)
    text = text or ""
    if _is_hallucination(text):
        text = ""
    return text, backend, time.time() - t0


def _voice_for_bot(bot_id: int, bot_name: str = ""):
    if bot_id in BOT_VOICES:
        return BOT_VOICES[bot_id]
    low = bot_name.lower()
    if "elena" in low:
        return BOT_VOICES[901]
    if "kael" in low:
        return BOT_VOICES[903]
    return BOT_VOICES[902]


async def _edge_tts_mp3(text: str, voice: str, rate: str, pitch: str) -> bytes:
    import edge_tts
    comm = edge_tts.Communicate(text, voice, rate=rate, pitch=pitch)
    out = bytearray()
    async for chunk in comm.stream():
        if chunk.get("type") == "audio":
            out.extend(chunk["data"])
    return bytes(out)


def synthesize_mp3(bot_id: int, bot_name: str, text: str):
    t0 = time.time()
    clean = _restore_spanish_accents(" ".join(text.strip().split()))
    if not clean:
        return b"", "empty", 0.0
    voice, rate, pitch, espeak_v = _voice_for_bot(bot_id, bot_name)
    os.makedirs(CACHE_DIR, exist_ok=True)
    key = hashlib.sha1(
        f"v2_mp3|{voice}|{rate}|{pitch}|{clean.lower()}".encode("utf-8")
    ).hexdigest()
    cpath = os.path.join(CACHE_DIR, key + ".mp3")
    if os.path.exists(cpath) and os.path.getsize(cpath) > 800:
        with open(cpath, "rb") as f:
            return f.read(), "cache", time.time() - t0

    mp3_out = b""
    backend = "edge"
    try:
        raw_mp3 = asyncio.run(_edge_tts_mp3(clean, voice, rate, pitch))
        if raw_mp3:
            p = subprocess.run(
                ["ffmpeg", "-loglevel", "error", "-i", "pipe:0",
                 "-af", "silenceremove=start_periods=1:start_threshold=-48dB,equalizer=f=210:width_type=o:width=1.2:g=1.4,lowpass=f=10500,alimiter=limit=0.96",
                 "-ar", "24000", "-ac", "1", "-b:a", "64k", "-f", "mp3", "pipe:1"],
                input=raw_mp3, capture_output=True, check=True, timeout=8.0)
            mp3_out = p.stdout
    except Exception as e:  # noqa: BLE001
        print("[tts] edge fallo (%s), usando espeak-ng" % e, flush=True)

    if not mp3_out:
        backend = "espeak"
        try:
            eproc = subprocess.run(
                ["espeak-ng", "-v", espeak_v, "-s", "162", "--stdout", clean],
                capture_output=True, check=True, timeout=5.0)
            p2 = subprocess.run(
                ["ffmpeg", "-loglevel", "error", "-i", "pipe:0",
                 "-ar", "24000", "-ac", "1", "-b:a", "64k", "-f", "mp3", "pipe:1"],
                input=eproc.stdout, capture_output=True, check=True, timeout=5.0)
            mp3_out = p2.stdout
        except Exception as e2:  # noqa: BLE001
            print("[tts] espeak fallo: %s" % e2, flush=True)

    if mp3_out and backend == "edge":
        try:
            tmp = cpath + ".tmp"
            with open(tmp, "wb") as f:
                f.write(mp3_out)
            os.replace(tmp, cpath)
        except OSError:
            pass
    return mp3_out, backend, time.time() - t0


def _handle_stt(fn: str):
    wav = os.path.join(JOBS, fn)
    out = wav[:-4] + ".txt"
    tmp = out + ".tmp"
    try:
        if not os.path.exists(wav):
            return
        s1 = os.path.getsize(wav)
        time.sleep(0.025)
        if not os.path.exists(wav) or os.path.getsize(wav) != s1:
            return
        text, backend, dt = transcribe(wav)
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(text)
        os.replace(tmp, out)
        try:
            os.remove(wav)
        except OSError:
            pass
        if text:
            print("[stt] %s [%s %.2fs]: %s" % (fn, backend, dt, text[:90]), flush=True)
    except Exception as e:  # noqa: BLE001
        print("[stt] %s error: %s" % (fn, e), flush=True)
    finally:
        with _in_flight_lock:
            _in_flight.discard(fn)


def _handle_tts(fn: str):
    jpath = os.path.join(JOBS, fn)
    out = jpath[:-5] + ".mp3"
    tmp = out + ".tmp"
    try:
        if not os.path.exists(jpath):
            return
        s1 = os.path.getsize(jpath)
        if s1 == 0:
            time.sleep(0.02)
            if not os.path.exists(jpath) or os.path.getsize(jpath) == 0:
                return
        with open(jpath, "r", encoding="utf-8") as f:
            req = json.load(f)
        bid = int(req.get("bot_id", 902))
        bname = str(req.get("bot_name", "Bot"))
        text = str(req.get("text", "")).strip()
        mp3, backend, dt = synthesize_mp3(bid, bname, text)
        if mp3:
            with open(tmp, "wb") as f:
                f.write(mp3)
            os.replace(tmp, out)
        try:
            os.remove(jpath)
        except OSError:
            pass
        if mp3:
            print("[tts] %s (%s) [%s %.2fs %dB mp3]: %s"
                  % (fn, bname, backend, dt, len(mp3), text[:80]), flush=True)
    except Exception as e:  # noqa: BLE001
        print("[tts] %s error: %s" % (fn, e), flush=True)
    finally:
        with _in_flight_lock:
            _in_flight.discard(fn)


def _prewarm_cache():
    for bid, line in PREWARM_LINES:
        try:
            synthesize_mp3(bid, "", line)
        except Exception:  # noqa: BLE001
            pass
    print("[tts] cache 24kHz precalentada (%d frases)" % len(PREWARM_LINES), flush=True)


def main() -> int:
    os.makedirs(JOBS, exist_ok=True)
    os.makedirs(CACHE_DIR, exist_ok=True)
    mode = "groq(%s)+local(%s)" % (GROQ_MODEL, MODEL) if GROQ_KEY \
        else "local(%s)" % MODEL
    print("[voice] demonio listo — dir=%s stt=%s tts=edge-24kHz-mp3+cache"
          % (JOBS, mode), flush=True)
    threading.Thread(target=_prewarm_cache, daemon=True).start()

    pool = ThreadPoolExecutor(max_workers=4)
    while True:
        try:
            for fn in sorted(os.listdir(JOBS)):
                if fn.endswith(".wav"):
                    out = os.path.join(JOBS, fn[:-4] + ".txt")
                    if os.path.exists(out):
                        continue
                    with _in_flight_lock:
                        if fn in _in_flight:
                            continue
                        _in_flight.add(fn)
                    pool.submit(_handle_stt, fn)
                elif fn.endswith(".json") and fn.startswith("tts_"):
                    out_mp3 = os.path.join(JOBS, fn[:-5] + ".mp3")
                    out_pcm = os.path.join(JOBS, fn[:-5] + ".pcm")
                    if os.path.exists(out_mp3) or os.path.exists(out_pcm):
                        continue
                    with _in_flight_lock:
                        if fn in _in_flight:
                            continue
                        _in_flight.add(fn)
                    pool.submit(_handle_tts, fn)
        except FileNotFoundError:
            os.makedirs(JOBS, exist_ok=True)
        except Exception as e:  # noqa: BLE001
            print("[voice] error: %s" % e, flush=True)
        time.sleep(POLL)


if __name__ == "__main__":
    sys.exit(main())
