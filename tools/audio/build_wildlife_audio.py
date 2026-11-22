#!/usr/bin/env python3
"""Build short wildlife foley from credited and user-supplied sources.
All downloads and temporary files stay on copia.
Usage: python3 tools/audio/build_wildlife_audio.py
       python3 tools/audio/build_wildlife_audio.py --wolves-only
Requires ffmpeg; generated WAVs are mono 24 kHz/16-bit, never runtime DSP.
"""
import argparse
import hashlib
import array
import json
import math
import pathlib
import re
import shutil
import subprocess
import urllib.request
import unicodedata
import wave

ROOT = pathlib.Path(__file__).resolve().parents[2]
CACHE = ROOT / 'build/tmp/animal_audio_source'
DEST = ROOT / 'assets/audio/wildlife'
FFMPEG = shutil.which('ffmpeg') or '/opt/homebrew/bin/ffmpeg'
SOURCES = {
    'animal_foley': ('IENBA', 'Animal Footsteps', 'https://freesound.org/people/IENBA/sounds/658429/'),
    'hooves': ('craigsmith', 'R13-16-Soft Hoof Sounds.wav', 'https://freesound.org/people/craigsmith/sounds/479688/'),
    'bear_growl': ('celldroid', 'Bear Angry Growl', 'https://freesound.org/people/celldroid/sounds/763026/'),
    'wolf_run_gallop': ('qubodup', 'Dog Running Past', 'https://freesound.org/people/qubodup/sounds/827320/'),
}

def _ensure_freesound_source(manifest, key):
    author, title, url = SOURCES[key]
    src = CACHE / (key + '.mp3')
    if not src.exists():
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        html = urllib.request.urlopen(req, timeout=20).read().decode()
        media = re.search(r'https://cdn.freesound.org/previews/[^"\s]+-hq\.mp3', html).group(0)
        src.write_bytes(urllib.request.urlopen(media, timeout=30).read())
    manifest['sources'][key] = dict(
        author=author, title=title, url=url, license='CC0-1.0',
        sha256=hashlib.sha256(src.read_bytes()).hexdigest())
    return src

def build_wolves(manifest):
    """Keep original MP3s untouched; edit isolated contacts/phrases offline."""
    supplied = {
        'wolf_walk_supplied': 'LOBO_ANDANDO',
        'wolf_eat_supplied': 'LOBO_COMIENDO',
        'wolf_growl_supplied': 'LOBO_GRUÑENDO',
    }
    inputs = {}
    for key, stem in supplied.items():
        matches = [p for p in (ROOT / 'LOBOS').glob('*.mp3')
                   if unicodedata.normalize('NFC', p.stem) == stem]
        if len(matches) != 1:
            raise RuntimeError(f'Expected one recording for {stem}: {matches}')
        src = inputs[key] = matches[0]
        manifest['sources'][key] = dict(
            author='supplied by project owner', title=src.name,
            path=src.relative_to(ROOT).as_posix(),
            license='User-supplied recording; original license unspecified',
            sha256=hashlib.sha256(src.read_bytes()).hexdigest())
    inputs['wolf_run_gallop'] = _ensure_freesound_source(manifest, 'wolf_run_gallop')
    specs = []
    for i, start in enumerate([4.16, 6.25, 10.65], 1):
        specs.append((f'wolf_walk_{i}', 'wolf_walk_supplied', start, .20, 'highpass=f=65,lowpass=f=4800', .004, .035))
    # LOBO_CORRIENDO.mp3 was broadband foliage/snow hiss (-38 dB, ZCR ~7 kHz) with
    # almost no paw thud; use isolated turf gallop strikes from wolf_run_gallop
    # pitched 8% lower offline for heavier adult-wolf weight.
    for i, (start, duration) in enumerate([(3.825, .175), (4.195, .160), (3.460, .165)], 1):
        specs.append((f'wolf_run_{i}', 'wolf_run_gallop', start, duration,
                      'asetrate=44100*0.92,aresample=24000,asetpts=N/SR/TB,highpass=f=55,lowpass=f=3400', .005, .055))
    for i, (start, duration) in enumerate([(0.04, 1.25), (3.33, 1.42), (5.75, 1.50)], 1):
        specs.append((f'wolf_eat_{i}', 'wolf_eat_supplied', start, duration, 'highpass=f=65,lowpass=f=7500', .02, .08))
    for i, (start, duration) in enumerate([(2.25, 1.48), (3.73, 1.50), (5.23, 2.05), (7.28, 2.11)], 1):
        specs.append((f'wolf_growl_{i}', 'wolf_growl_supplied', start, duration, 'highpass=f=65,lowpass=f=7500', .03, .10))
    for name, key, start, length, base_filter, fade_in, fade_out in specs:
        chain = f'{base_filter},afade=t=in:d={fade_in},afade=t=out:st={length-fade_out}:d={fade_out}'
        dest = DEST / (name + '.wav')
        subprocess.run([FFMPEG, '-v', 'error', '-y', '-ss', str(start),
                        '-i', str(inputs[key]), '-t', str(length), '-af', chain,
                        '-ar', '24000', '-ac', '1', '-c:a', 'pcm_s16le', str(dest)], check=True)
        with wave.open(str(dest), 'rb') as wav:
            params = wav.getparams()
            samples = array.array('h', wav.readframes(wav.getnframes()))
        peak = max(abs(v) for v in samples)
        if peak == 0:
            raise RuntimeError(f'Silent cut: {name}')
        scale = (32767 * 10 ** (-6 / 20)) / peak
        normalized = array.array('h', (round(v * scale) for v in samples))
        with wave.open(str(dest), 'wb') as wav:
            wav.setparams(params)
            wav.writeframes(normalized.tobytes())
        manifest['clips'][dest.name] = dict(
            source=key, start=start, duration=length, filters=chain,
            rate='24000 Hz mono s16', peak_dbfs=-6,
            normalization_db=round(20 * math.log10(scale), 3))
    print('Built', len(specs), 'wolf clips from LOBOS')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--wolves-only', action='store_true',
                        help='Use LOBOS locally, preserving other species and attack samples')
    args = parser.parse_args()
    CACHE.mkdir(parents=True, exist_ok=True)
    DEST.mkdir(parents=True, exist_ok=True)
    manifest_path = DEST / 'SOURCES.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {'sources': {}, 'clips': {}}
    manifest['license'] = 'Mixed; see each source'
    for key in SOURCES:
        if key in manifest['sources']:
            manifest['sources'][key]['license'] = 'CC0-1.0'
    for key in ({} if args.wolves_only else SOURCES):
        _ensure_freesound_source(manifest, key)
    specs = []
    for i, (start, length) in enumerate([(0.075,.18),(.50,.13),(.99,.18)]):
        specs.append((f'paw_soft_{i+1}', 'animal_foley', start, length, 'highpass=f=75,lowpass=f=3400', 5))
        specs.append((f'paw_hard_{i+1}', 'animal_foley', start, length, 'highpass=f=170,lowpass=f=6500', 5))
    for i, start in enumerate([1.29,2.56,3.14]):
        specs.append((f'hoof_{i+1}', 'hooves', start,.19,'highpass=f=200,lowpass=f=4400,afftdn=nf=-26',0))
    specs += [('bear_growl','bear_growl',1.50,3.8,'highpass=f=65,lowpass=f=7500',0),
              ('bear_attack','bear_growl',2.0,1.25,'highpass=f=65,lowpass=f=7500',0)]
    for name, source, start, length, filters, gain in ([] if args.wolves_only else specs):
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
    build_wolves(manifest)
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    if not args.wolves_only:
        print('Built',len(specs),'shared wildlife clips')
if __name__ == '__main__': main()
