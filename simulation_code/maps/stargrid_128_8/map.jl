map_specs=(:star_grid_map,(128,8))

#map
speed_dict=Dict(1=>3.6)
map=RP.get_map(map_specs)
RM=RP.get_route_matrix("../maps/stargrid_128_8/")
t0=86.9623813106492

mapfactor=5.5/1.6;