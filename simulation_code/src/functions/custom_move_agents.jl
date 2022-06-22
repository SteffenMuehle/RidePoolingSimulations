#system-wide time step
function move_agents_by_time!(time,model)
    for id in model.scheduler(model)
        move_agent_by_time!(model[id],time,model)
    end
end


# we use the predefined function move_agent!(.., .., distance),
# but trick it by changing the network's edge's weights from travel distance to travel times first.
# The move-step has thus to be wrapped with firstly translating current position agent.pos[3] into a time and then back.
# 'sparse_times' are precalculated edge weights = travel times.
# It's a sparse matrix in the same form as model.space.m.w is.
function move_agent_by_time!(
    agent::Bus,
    time::Real,
    model::ABM,
)
    
    
    # turn pos[3] into time increment rather than distance increment
    distance_to_time!(agent,model) 
    
    # switch to "time mode"
    model.space.m.w=model.sparse_times
    
    # perform move with time-weights instead of distance-weights between nodes
    my_move_agent!(agent,time,model)
    
    # switch back to "distance mode"
    model.space.m.w=model.sparse_distances
    
    # make pos[3] a distance again
    time_to_distance!(agent,model) 
    
    return nothing
end


function my_move_agent!(
    agent::Bus,
    distance::Float64,
    model::ABM,
)

    if osm_is_stationary(agent)
        return nothing
    end

    dist_to_intersection = osm_road_length(agent.pos, model) - agent.pos[3]

    if isempty(agent.route) && agent.pos[1:2] == agent.destination[1:2]
        # Last one or two moves before destination
        to_travel = agent.destination[3] - agent.pos[3]
        if distance >= abs(to_travel)
            pos = agent.destination
        else
            pos = (agent.destination[1:2]..., agent.pos[3] + sign(to_travel)*distance)
        end
    elseif distance >= dist_to_intersection
        if !isempty(agent.route)
            pos = my_travel!(
                agent.pos[2],
                popfirst!(agent.route),
                distance - dist_to_intersection,
                agent,
                model,
            )
        else
            # Now moving to the final destination
            pos = my_park(distance - dist_to_intersection, agent, model)
        end
    else
        # move up current path
        pos = (agent.pos[1], agent.pos[2], agent.pos[3] + distance)
    end

    move_agent!(agent, pos, model)
end


function my_travel!(start, finish, distance, agent, model)
    # Assumes we have just reached the intersection of `start` and `finish`,
    # and have `distance` left to travel.
    edge_distance = osm_road_length(start, finish, model)
    if edge_distance <= distance
        if !isempty(agent.route)
            return my_travel!(
                finish,
                popfirst!(agent.route),
                distance - edge_distance,
                agent,
                model,
            )
        else
            # alright, so here we're in a situation where the agent is imagined to be at 'start' with 'distance left to travel.
            # the route is empty, but (start,finish) does not equal agent.destination[1:2]
            # what follows is the srouce code of the function "park", but the 'virtual' agent in it has position
            # pos=(start,finish,distance-edge_distance)
            # so I replaced that and nothing else.
            distance-=edge_distance
            if finish != agent.destination[1]
                # At the end of the route, we must travel
                last_distance = osm_road_length(finish, agent.destination[1], model)
                if distance >= last_distance + agent.destination[3]
                    # We reach the destination
                    return agent.destination
                elseif distance >= last_distance
                    # We reach the final road, but not the destination
                    return (agent.destination[1:2]..., distance - last_distance)
                else
                    # We travel the final leg
                    return (finish, agent.destination[1], distance)
                end
            else
                # Reached final road
                if distance >= agent.destination[3]
                    return agent.destination
                else
                    return (agent.destination[1:2]..., distance)
                end
            end
            #######################################
            
        end
    else
        return (start, finish, distance)
    end
end


function my_park(distance, agent, model)
    # We have no route left but have not quite yet arrived at our destination.
    # Assumes that when this is called, we have just completed the current leg
    # in `agent.pos`, and we have `distance` left to travel.
    if agent.pos[2] != agent.destination[1]
        # At the end of the route, we must travel
        last_distance = osm_road_length(agent.pos[2], agent.destination[1], model)
        if distance >= last_distance + agent.destination[3]
            # We reach the destination
            return agent.destination
        elseif distance >= last_distance
            # We reach the final road, but not the destination
            return (agent.destination[1:2]..., distance - last_distance)
        else
            # We travel the final leg
            return (agent.pos[2], agent.destination[1], distance)
        end
    else
        # Reached final road
        if distance >= agent.destination[3]
            return agent.destination
        else
            return (agent.destination[1:2]..., distance)
        end
    end
end


# create sparse matrix that contains travel times of network
function get_travel_times(m::MapData, class_speeds::Dict{Int,Float64} = OpenStreetMapX.SPEED_ROADS_URBAN)
    sparse_times=copy(m.w)
    @assert length(m.e) == length(m.w.nzval)
    indices = [(m.v[i],m.v[j]) for (i,j) in m.e]
    for i = 1:length(m.e)
        sparse_times[indices[i]...] = 3.6 * (m.w[indices[i]]/class_speeds[m.class[i]])
    end
    return sparse_times
end


#translate progress between nodes (agent.pos[3]) from distance into time
function distance_to_time!(agent::Bus,model::ABM)::Tuple{Int,Int,Float64}
    #pos
    distance_since_node=agent.pos[3]
    edge_length=model.space.m.w[agent.pos[1:2]]
    edge_time=model.sparse_times[agent.pos[1:2]]
    time_since_node= edge_length != 0.0 ? distance_since_node*edge_time/edge_length : 0.0  
    agent.pos=(agent.pos[1:2]...,time_since_node)
    
    #destination
    distance_since_node=agent.destination[3]
    edge_length=model.space.m.w[agent.destination[1:2]]
    edge_time=model.sparse_times[agent.destination[1:2]]
    time_since_node= edge_length != 0.0 ? distance_since_node*edge_time/edge_length : 0.0  
    agent.destination=(agent.destination[1:2]...,time_since_node)
end


#translate progress between nodes (agent.pos[3]) from distance into time
function distance_to_time(pos::Tuple{Int,Int,Float64},model::ABM)::Tuple{Int,Int,Float64}
    distance_since_node=pos[3]
    edge_length=model.space.m.w[pos[1:2]]
    edge_time=model.sparse_times[pos[1:2]]
    time_since_node= edge_length != 0.0 ? distance_since_node*edge_time/edge_length : 0.0 
    return (pos[1:2]...,time_since_node)
end


#translate progress between nodes (agent.pos[3]) from time into distance
function time_to_distance!(agent::Bus,model::ABM)::Tuple{Int,Int,Float64}
    #pos
    time_since_node=agent.pos[3]
    edge_length=model.space.m.w[agent.pos[1:2]]
    edge_time=model.sparse_times[agent.pos[1:2]]
    distance_since_node= edge_time != 0.0 ? time_since_node*edge_length/edge_time : 0.0
    agent.pos=(agent.pos[1:2]...,distance_since_node)
    
    #destination
    time_since_node=agent.destination[3]
    edge_length=model.space.m.w[agent.destination[1:2]]
    edge_time=model.sparse_times[agent.destination[1:2]]
    distance_since_node= edge_time != 0.0 ? time_since_node*edge_length/edge_time : 0.0
    agent.destination=(agent.destination[1:2]...,distance_since_node)
end


#translate progress between nodes (agent.pos[3]) from distance into time
function time_to_distance(pos::Tuple{Int,Int,Float64},model::ABM)::Tuple{Int,Int,Float64}
    time_since_node=pos[3]
    edge_length=model.space.m.w[pos[1:2]]
    edge_time=model.sparse_times[pos[1:2]]
    distance_since_node= edge_time != 0.0 ? time_since_node*edge_length/edge_time : 0.0
    return (pos[1:2]...,distance_since_node)
end