map_specs=(:star_grid_map,(64,16))

#map
speed_dict=Dict(1=>3.6)
map=RP.get_map(map_specs)
RM=RP.get_route_matrix("../maps/stargrid_64_16/")
t0=45.339190347724944

mapfactor=2.6/1.6;