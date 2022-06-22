# How to add new cost function?
# 1. export it here (above)
# 2. write it here (below)
# 3. add an 'elseif' to 'cost' function in dispatcher.jl
# Then use it by initiate(;cost=:my_funcy_func)



"""
'delays(bus,model)' returns a bus' cost function value.
This value is the sum of delays of all passengers scheduled (both already-on-board and to-be-picked-up!) for that bus.
A customer's delay is the time difference between ride-shared dropoff time and arrival time, had they taken their own car in the first place.
"""
function delays(bus::Bus,model::ABM)::Float64
    
    cost=0.0
    
    #loop over scheduled passengers
    for p in scheduled_passengers(bus)
        req=model.requests[p]
        
        #calculate passenger's projected dropoff time based on current todo list
        arrival_time=model.time
        dropped_off=false
        k=0
        while !dropped_off
            k+=1
            job=bus.todo[k]
            arrival_time+=job.duration
            if job.req_id == req.id && job.Δ==-1
                dropped_off=true
            end
        end
        
        #calculate time when passenger would arrive, had they taken their private car
        ideal_time=req.t_submit+req.direct_time
        
        #calculate total delay customer experiences because of using our system
        delay=arrival_time-ideal_time
        
        #add delay to cost function. We square it to avoid outlayers (single customers shouldn't get delayed over and over).
        cost+=delay
    end
    
    return cost
end



"""
'squared_delays(bus,model)' returns a bus' cost function value.
This value is the sum of squared delays of all passengers scheduled (both already-on-board and to-be-picked-up!) for that bus.
A customer's delay is the time difference between ride-shared dropoff time and arrival time, had they taken their own car in the first place.
"""
function squared_delays(bus::Bus,model::ABM)::Float64
    
    cost=0.0
    
    #loop over scheduled passengers
    for p in scheduled_passengers(bus)
        req=model.requests[p]
        
        #calculate passenger's projected dropoff time based on current todo list
        arrival_time=model.time
        dropped_off=false
        k=0
        while !dropped_off
            k+=1
            job=bus.todo[k]
            arrival_time+=job.duration
            if job.req_id == req.id && job.Δ==-1
                dropped_off=true
            end
        end
        
        #calculate time when passenger would arrive, had they taken their private car
        ideal_time=req.t_submit+req.direct_time
        
        #calculate total delay customer experiences because of using our system
        delay=arrival_time-ideal_time
        
        #add delay to cost function. We square it to avoid outlayers (single customers shouldn't get delayed over and over).
        cost+=delay^2
    end
    
    return cost
end



"""
'trajectory_length(bus,model)' returns a bus' cost function value.
This value is the bus' trajectory length as dictated by its todo list, taking into account that the first job is already partly done.
"""
function trajectory_length(bus::Bus,model::ABM)::Float64
    
    #if bus is idle, return 0
    if length(bus.todo)==0
        return 0.0
    end
    
    #first job manually
    #RARE CASE WHEN CALLED FROM what_if_cost: first job just got replaced
    if bus.destination != bus.todo[1].destination
        cost=bus.todo[1].length
        
    #COMMON CASE: first job is partly done
    else
        cost=route_length(bus.pos,bus.route,bus.destination,model)
    end
        
    #loop over remaining "regular" jobs on todo list
    for job in bus.todo[2:end]
        cost+=job.length
    end
    
    return cost
end



"""
'trajectory_time(bus,model)' returns a bus' cost function value.
This value is the bus' trajectory time as dictated by its todo list, taking into account that the first job is already partly done.
"""
function trajectory_time(bus::Bus,model::ABM)::Float64
    
    #if bus is idle, return 0
    if length(bus.todo)==0
        return 0.0
    end
    
    #first job manually
    #RARE CASE WHEN CALLED FROM what_if_cost: first job just got replaced
    if bus.destination != bus.todo[1].destination
        cost=bus.todo[1].duration
        
    #COMMON CASE: first job is partly done
    else
        cost=route_time(bus.pos,bus.route,bus.destination,model)
    end
    
    #loop over jobs on todo list
    for job in bus.todo[2:end]
        cost+=job.duration
    end
    
    return cost
end


function custom_cost(bus::Bus,model::ABM)
    return rand()
end