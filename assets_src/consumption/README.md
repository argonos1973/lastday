# Eating motion

Source: CMU Graphics Lab motion capture, subject 80, take 24, **eating**.
Original: <https://mocap.cs.cmu.edu/search.php?subjectnumber=80>.
BVH conversion by Bruce Hahne, cgspeed, Daz-friendly hip-corrected release
(2010-07-28), obtained from:
<https://outworldz.com/Secondlife/Posts/CMU/cmuconvert-daz-76-80.zip>.

CMU permits inclusion in commercially sold products, but not resale of the
motion data itself. See <https://mocap.cs.cmu.edu/>.

The data used in this project was obtained from mocap.cs.cmu.edu.
The database was created with funding from NSF EIA-0196217.

Source BVH SHA-256: `f4b225de6d88f063cc75116a15df113f982d508a429977cd7a2e41b9748c59fb`.

`tools/blender/import_eating_motion.py` retargets seconds 2.45–4.45 of the
right-hand bite onto the existing character skeleton, including an offline
arm reach adjustment for its proportions. The runtime asset contains rotations only: no
character mesh, textures, or root motion. The source BVH is excluded from
Godot imports and exports.
