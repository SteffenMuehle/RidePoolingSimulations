map_specs=(:star_grid_map,(32,32))

#map
speed_dict=Dict(1=>3.6)
map=RP.get_map(map_specs)
RM=RP.get_route_matrix("../maps/stargrid_32_32/")
t0=31.179049489898734

mapfactor=1.0;