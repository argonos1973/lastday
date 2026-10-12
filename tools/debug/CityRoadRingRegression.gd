extends SceneTree
const CITY := preload("res://scripts/CityExpansion.gd")
func _initialize(): call_deferred("run")
func run():
 var C := CITY.CENTER
 # Perimeter strips: each center point must be road; midpoints and houses must not.
 var cases := [
  [C+Vector3(-40,0,0),true,"west strip"],[C+Vector3(104,0,0),true,"east strip"],
  [C+Vector3(0,0,-40),true,"north strip"],[C+Vector3(0,0,136),true,"south strip"],
  [C+Vector3(-40,0,136),true,"corner"],[C+Vector3(104,0,-40),true,"corner2"],
  [C+Vector3(-48,0,0),false,"outside west"],[C+Vector3(20,0,30),false,"inside district"],
  [C+Vector3(-16,0,-17),false,"house city_01"],[C+Vector3(32,0,48),false,"plaza"],
  [C+Vector3(0,0,-10),true,"main street"],[C+Vector3(64,0,96),true,"cross street"],
 ]
 var fails:=0
 for c in cases:
  var got:bool=CITY.on_road(c[0])
  if got!=c[1]:
   fails+=1;print("FAIL %s -> %s (wanted %s)"%[c[2],got,c[1]])
  else: print("PASS %s"%c[2])
 print("ONROAD failures=%d"%fails)
 quit(1 if fails else 0)
