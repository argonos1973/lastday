src = open('/Volumes/copia/lastday2/tools/blender/make_shelter_camo_net.py').read()
head = src.rsplit('\nbuild_shelter_drape()', 1)[0]
exec(compile(head, 'make_shelter_camo_net.py', 'exec'))
build_shelter_drape()
