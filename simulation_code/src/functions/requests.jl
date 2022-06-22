"""
random_pair(model) returns a random pickup and a random dropoff point (both in the form Tuple{Int,Int,Float64}) on the model's map.
"""
function random_trip(model::ABM)::Tuple{Tuple{Int,Int,Float64},Tuple{Int,Int,Float64},Array{Int,1}}
    success = false
    failcounter=0
    while !success
        #draw random pair
        (pickup, dropoff) = draw_pair(model)
        
        #calculate route
        route=plan_route(pickup,dropoff,model)
        
        #check if pickup and dropoff are too close to each other
        #distance=norm( cartesian_coords(pickup,model)-cartesian_coords(dropoff,model) )
        distance=route_length(pickup,route,dropoff,model)
        success = distance > model.min_requested_distance
        
        # return pickup+dropoff in case of sufficient distance OR after too many tries
        if success || (failcounter+=1) > 100000    #100000 is arbitrary.
            return (pickup, dropoff,route)
        end
    end 
end


function draw_pair(model::ABM)
    
    #figure out which subspace the request is coming FROM
    cumulative_prob=cumsum([space.weight for space in model.subspaces])
    index=findfirst(x->x>rand(),cumulative_prob)
    from_space=model.subspaces[index]
    
    #figure out where request is going TO
    cumulative_prob=cumsum(from_space.outflow)
    index=findfirst(x->x>rand(),cumulative_prob)
    to_space=model.subspaces[index]
    
    #draw pickup+dropoff from from_space and to_space independently)
    return (draw_from(from_space,model),draw_from(to_space,model))    #if 'space' is a set of nodes, these aren't actually ll's, but already Tuple{Int,Int,Float64}.
    
end


function draw_from(space::Subspace,model::ABM)::Tuple{Int,Int,Float64}
    
    if space.category==:nodes # content=Tuple of node ids (Integers)
        nodeid=rand(space.content)
        return (nodeid,nodeid,0.0)
        
    elseif space.category==:triplets # content=Tuple of position triplets
        return rand(space.content)
        
    elseif space.category==:edges #content[1]=list of edges, content[2]=list of weights
        edge=sample(space.content...)
        edge_length=model.space.m.w[edge...]
        return (edge...,rand()*edge_length) #random position on edge
    
    elseif space.category==:area_to_node   #content[1]= polygon with LatLon vertices given by 'shape' and we're drawing from its area
                                           #content[2]= polygon bounding rectangle
        random_point=point_in_polygon(space.content...)
        return closest_node_triplet(random_point,model)
        
    elseif space.category==:area_to_edge   #content[1]= polygon with LatLon vertices given by 'shape' and we're drawing from its area
                                           #content[2]= polygon bounding rectangle
        random_point=point_in_polygon(space.content...)
        return closest_edge_triplet(random_point,model)
    
    elseif space.category==:latlon_to_node   #content= Tuple of latlons
        random_point=rand(space.content)
        return closest_node_triplet(random_point,model)
        
    else space.category==:latlon_to_edge     #content= Tuple of latlons
        random_point=rand(space.content)
        return closest_edge_triplet(random_point,model)
        
    end
end

    
function point_in_polygon(polygon,bounds)
    while true
        failcounter=0

        #draw random point within map's boundaries
        random_point = (rand() * (bounds[2] - bounds[1]) + bounds[1],
                        rand() * (bounds[4] - bounds[3]) + bounds[3])

        #check if it is in desired polygon OR if subspace is a single point as indicated by its area being zero
        success=inpolygon(random_point, polygon)==1

        #return random_point if it's in the polygon
        if success || (failcounter+=1) > 100000
            return random_point
                
        #OR return error after too many tries
        elseif (failcounter+=1) > 10^5 #10^5 is arbitrary
            throw(error("10^5 tries couldn't find a point within polygon"))
        end
    end
end
    

"""
"""
function closest_edge_triplet(ll::Tuple{Float64,Float64},model::ABM)::Tuple{Int,Int,Float64}
    #idx = getindex(model.space.m.v, point_to_nodes((ll[2],ll[1]), model.space.m))
    #return (idx, idx, 0.0)
    
        throw(error("'closest_edge_triple' not implemented"))
            
    triple=osm_road((ll[2],ll[1]), model)
    edge_length=model.space.m.w[triple[1],triple[2]]
    return (triple[1:2]...,rand()*edge_length)
    #return osm_road((ll[2],ll[1]), model)   #this will allow requests to go to and from positions on a road, not necesarily at a node, too.
                                             #it requires some work, though: not sure if travel! function works properly in all cases,
                                             #and also route_time and route_length need to be fixed for the case where pos and target are on the same edge
end
    

"""
"""
function closest_node_triplet(ll::Tuple{Float64,Float64},model::ABM)::Tuple{Int,Int,Float64}
    id= getindex(model.space.m.v, point_to_nodes((ll[2],ll[1]), model.space.m))
    return (id,id,0.0)
end
    

"""
"""
function closest_node_triplet(ll::Vector{Float64},model::ABM)::Tuple{Int,Int,Float64}
    closest_node_triplet(Tuple(ll),model)
end
    

function sample(items, weights)
    index=findfirst(cumsum(weights)/sum(weights) .> rand())
    return items[index]
end