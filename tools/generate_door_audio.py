"""Original deterministic wooden-door Foley: latch, hinge friction and closing thud."""
import math, random, struct, wave
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'assets/audio/doors'
out.mkdir(parents=True,exist_ok=True)
rate=44100
for opening in [True,False]:
 rng=random.Random(170 if opening else 171)
 samples=[]; smooth=0.; phase=0.
 for i in range(int(rate*.7)):
  t=i/rate; noise=rng.uniform(-1,1); smooth=.88*smooth+.12*noise
  env=max(0,math.sin(math.pi*min(1,t/.42)))**1.5 if t<.42 else 0
  phase+=2*math.pi*(165+40*math.sin(t*16)+18*math.sin(t*47))/rate
  squeak=env*(.07*math.sin(phase)+.025*math.sin(phase*2.03)+.09*smooth)
  hit_t=.015 if opening else .28
  dt=t-hit_t
  hit=0 if dt<0 else math.exp(-dt*(38 if opening else 22))*(.35*smooth+.22*math.sin(2*math.pi*(430 if opening else 92)*dt)+.12*math.sin(2*math.pi*181*dt))
  click=0 if dt<0 else .22*noise*math.exp(-dt*180)
  samples.append(max(-.95,min(.95,squeak+hit+click)))
 with wave.open(str(out/('door_open.wav' if opening else 'door_close.wav')),'wb') as w:
  w.setparams((1,2,rate,0,'NONE','not compressed'))
  w.writeframes(b''.join(struct.pack('<h',int(x*32767)) for x in samples))
