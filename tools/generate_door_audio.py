"""Original deterministic wooden-door Foley: latch, hinge friction and closing thud."""
import math, random, struct, wave
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'assets/audio/doors'
out.mkdir(parents=True,exist_ok=True)
rate=44100
for opening in [True,False]:
 rng=random.Random(170 if opening else 171)
 samples=[]; smooth=0.; low=0.; phase=0.
 for i in range(int(rate*.75)):
  t=i/rate; noise=rng.uniform(-1,1); smooth=.86*smooth+.14*noise; low=.96*low+.04*noise
  env=max(0,math.sin(math.pi*min(1,t/.52)))**1.15 if t<.52 else 0
  phase+=2*math.pi*(175+48*math.sin(t*15)+22*math.sin(t*43))/rate
  squeak=env*(.32*math.sin(phase)+.16*math.sin(phase*2.02)+.08*math.sin(phase*3.05)+.28*smooth+.22*low)
  hit_t=.015 if opening else .32
  dt=t-hit_t
  hit=0 if dt<0 else math.exp(-dt*(18 if opening else 12))*(.65*low+.52*smooth+.48*math.sin(2*math.pi*(360 if opening else 88)*dt)+.34*math.sin(2*math.pi*(168 if opening else 134)*dt))
  click=0 if dt<0 else (.55*noise+.35*math.sin(2*math.pi*1150*dt))*math.exp(-dt*95)
  raw=squeak+hit+click
  samples.append(math.tanh(raw*1.65)*0.96)
 with wave.open(str(out/('door_open.wav' if opening else 'door_close.wav')),'wb') as w:
  w.setparams((1,2,rate,0,'NONE','not compressed'))
  w.writeframes(b''.join(struct.pack('<h',int(x*32767)) for x in samples))
