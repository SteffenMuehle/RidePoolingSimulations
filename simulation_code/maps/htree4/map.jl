map_specs=(:htree4,)

#map
speed_dict=Dict(1=>3.6)
map=RP.get_map(map_specs)
RM=RP.get_route_matrix("../maps/htree4/")
t0=22.295737992256377

mapfactor= N<160 ? (0.9/1.6)*N^0.24 : (0.037/1.6)*N^0.86;