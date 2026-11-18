#!/usr/bin/env python3
"""Build short wildlife foley from CC0 sources. All downloads stay on copia.
Usage: python3 tools/audio/build_wildlife_audio.py
Requires ffmpeg; generated WAVs are mono 24 kHz/16-bit, never runtime DSP.
"""
import hashlib
import array
import json
import math
import pathlib
import re
import shutil
import subprocess
import urllib.request
import wave

ROOT = pathlib.Path(__file__).resolve().parents[2]
CACHE = ROOT / 'build/tmp/animal_audio_source'
DEST = ROOT / 'assets/audio/wildlife'
FFMPEG = shutil.which('ffmpeg') or '/opt/homebrew/bin/ffmpeg'
SOURCES = {
    'animal_foley': ('IENBA', 'Animal Footsteps', 'https://freesound.org/people/IENBA/sounds/658429/'),
    'hooves': ('craigsmith', 'R13-16-Soft Hoof Sounds.wav', 'https://freesound.org/people/craigsmith/sounds/479688/'),
    'bear_growl': ('celldroid', 'Bear Angry Growl', 'https://freesound.org/people/celldroid/sounds/763026/'),
}

def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = {'license': 'CC0-1.0', 'sources': {}, 'clips': {}}
    for key, (author, title, url) in SOURCES.items():
        src = CACHE / (key + '.mp3')
        if not src.exists():
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            html = urllib.request.urlopen(req, timeout=20).read().decode()
            media = re.search(r'https://cdn.freesound.org/previews/[^"\s]+-hq\.mp3', html).group(0)
            src.write_bytes(urllib.request.urlopen(media, timeout=30).read())
        manifest['sources'][key] = dict(author=author, title=title, url=url, sha256=hashlib.sha256(src.read_bytes()).hexdigest())
    specs = []
    for i, (start, length) in enumerate([(0.075,.18),(.50,.13),(.99,.18)]):
        specs.append((f'paw_soft_{i+1}', 'animal_foley', start, length, 'highpass=f=75,lowpass=f=3400', 5))
        specs.append((f'paw_hard_{i+1}', 'animal_foley', start, length, 'highpass=f=170,lowpass=f=6500', 5))
    for i, start in enumerate([1.29,2.56,3.14]):
        specs.append((f'hoof_{i+1}', 'hooves', start,.19,'highpass=f=200,lowpass=f=4400,afftdn=nf=-26',0))
    specs += [('bear_growl','bear_growl',1.50,3.8,'highpass=f=65,lowpass=f=7500',0),
              ('bear_attack','bear_growl',2.0,1.25,'highpass=f=65,lowpass=f=7500',0)]
    for name, source, start, length, filters, gain in specs:
        chain = f'{filters},volume={gain}dB,afade=t=in:d=0.004,afade=t=out:st={length-.035}:d=0.035,alimiter=limit=0.8:level=false'
        dest = DEST / (name+'.wav')
        subprocess.run([FFMPEG,'-v','error','-y','-ss',str(start),'-i',str(CACHE/(source+'.mp3')),'-t',str(length),'-af',chain,'-ar','24000','-ac','1','-c:a','pcm_s16le',str(dest)],check=True)
        # Source previews have very different levels. Normalize offline so
        # runtime species gains mean the same thing, with 6 dB of headroom.
        with wave.open(str(dest), 'rb') as wav:
            params = wav.getparams()
            samples = array.array('h', wav.readframes(wav.getnframes()))
        peak = max(abs(v) for v in samples)
        scale = (32767 * 10 ** (-6 / 20)) / max(1, peak)
        normalized = array.array('h', (round(v * scale) for v in samples))
        with wave.open(str(dest), 'wb') as wav:
            wav.setparams(params)
            wav.writeframes(normalized.tobytes())
        manifest['clips'][dest.name] = dict(source=source, start=start, duration=length, filters=chain, peak_dbfs=-6, normalization_db=round(20*math.log10(scale), 3))
    (DEST/'SOURCES.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('Built',len(specs),'wildlife clips')
if __name__ == '__main__': main()
