map_folder="../maps/broitzem/"
map_specs=(:osm,map_folder)
t0=202.3007288200514

#map
speed_dict=Dict(
    1=>100.0,
    2=>70.0,
    3=>50.0,
    4=>50.0,
    5=>50.0,
    6=>30.0,
    7=>30.0,
    8=>30.0
    );
road_classes=[1,2,3,4,5,6,8]
map=RP.get_map(map_specs,road_classes)
RM=RP.get_route_matrix(map_folder);

mapfactor=1.0;