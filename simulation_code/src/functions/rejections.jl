# How to add new rejection criterion?
# 1. write it here (below)
# 2. add an 'elseif' to 'rejection' function in dispatcher.jl
# Then use it by initiate(;rejection_criterion=((:my_rejection_crit,threshold),))



"""
rejection_max_delay(bus::Bus,model::ABM)::Bool
"""
function rejection_delay(bus::Bus,model::ABM,threshold::Float64)::Bool

    req=model.requests[end]
        
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
    
    return delay > threshold
end


"""
rejection_max_relative_delay(bus::Bus,model::ABM)::Bool
"""
function rejection_relative_delay(bus::Bus,model::ABM,threshold::Float64)::Bool

    req=model.requests[end]
        
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
    
    return delay/req.direct_time > threshold
end


"""
rejection_max_delay(bus::Bus,model::ABM)::Bool
"""
function rejection_any_delay(bus::Bus,model::ABM,threshold::Float64)::Bool

    maxdelay=0.0
    
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
        
        maxdelay=max(maxdelay,delay)
    end
    
    return maxdelay > threshold
end


"""
rejection_max_relative_delay(bus::Bus,model::ABM)::Bool
"""
function rejection_any_relative_delay(bus::Bus,model::ABM,threshold::Float64)::Bool

    maxdelay=0.0
    
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
        
        maxdelay=max(maxdelay,delay/req.direct_time)
    end
    
    return maxdelay > threshold
end


"""
rejection_max_relative_delay(bus::Bus,model::ABM)::Bool
"""
function rejection_any_relative_detour(bus::Bus,model::ABM,threshold::Float64)::Bool

    maxdetour=0.0
    
    for p in scheduled_passengers(bus)
        req=model.requests[p]
        
        #figure out if passenger has already been picked up
        picked_up= (req.t_pickup != 0)
        
        #set pickup+dropoff time
        pickup_time = picked_up ? req.t_pickup : model.time
        dropoff_time=model.time
        
        #if user had been dropped off, they wouldnt be scheduled anymore :)
        dropped_off=false
        
        #calculate passenger's projected dropoff time based on current todo list
        k=0
        while !( picked_up && dropped_off)
            k+=1
            job=bus.todo[k]
            
            #add to pick_up time if not picked up yet
            if !picked_up
                pickup_time+=job.duration
            end
            
            #add to dropoff time
            dropoff_time+=job.duration
            
            #chkeck if user is picked up or dropped off by this job
            if job.req_id == req.id
                if job.Δ==1
                    picked_up=true
                else
                    dropped_off=true
                end
            end
        end

        #calculate total delay customer experiences because of using our system
        detour=(dropoff_time-pickup_time-req.direct_time)/req.direct_time
        
        #update max-found detour so far
        maxdetour=max(maxdetour,detour)
    end
    
    return maxdetour > threshold
end


"""
rejection_max_relative_delay(bus::Bus,model::ABM)::Bool
"""
function rejection_any_detour(bus::Bus,model::ABM,threshold::Float64)::Bool

    maxdetour=0.0
    
    for p in scheduled_passengers(bus)
        req=model.requests[p]
        
        #figure out if passenger has already been picked up
        picked_up= (req.t_pickup != 0)
        
        #set pickup+dropoff time
        pickup_time = picked_up ? req.t_pickup : model.time
        dropoff_time=model.time
        
        #if user had been dropped off, they wouldnt be scheduled anymore :)
        dropped_off=false
        
        #calculate passenger's projected dropoff time based on current todo list
        k=0
        while !( picked_up && dropped_off)
            k+=1
            job=bus.todo[k]
            
            #add to pick_up time if not picked up yet
            if !picked_up
                pickup_time+=job.duration
            end
            
            #add to dropoff time
            dropoff_time+=job.duration
            
            #chkeck if user is picked up or dropped off by this job
            if job.req_id == req.id
                if job.Δ==1
                    picked_up=true
                else
                    dropped_off=true
                end
            end
        end

        #calculate total delay customer experiences because of using our system
        detour=dropoff_time-pickup_time-req.direct_time
        
        #update max-found detour so far
        maxdetour=max(maxdetour,detour)
    end
    
    return maxdetour > threshold
end


"""
rejection_max_relative_delay(bus::Bus,model::ABM)::Bool
"""
function rejection_detour(bus::Bus,model::ABM,threshold::Float64)::Bool
    
    req=model.requests[end]

    #figure out if passenger has already been picked up
    picked_up= (req.t_pickup != 0)

    #set pickup+dropoff time
    pickup_time = picked_up ? req.t_pickup : model.time
    dropoff_time=model.time

    #if user had been dropped off, they wouldnt be scheduled anymore :)
    dropped_off=false

    #calculate passenger's projected dropoff time based on current todo list
    k=0
    while !( picked_up && dropped_off)
        k+=1
        job=bus.todo[k]

        #add to pick_up time if not picked up yet
        if !picked_up
            pickup_time+=job.duration
        end

        #add to dropoff time
        dropoff_time+=job.duration

        #chkeck if user is picked up or dropped off by this job
        if job.req_id == req.id
            if job.Δ==1
                picked_up=true
            else
                dropped_off=true
            end
        end
    end

    #calculate total delay customer experiences because of using our system
    detour=dropoff_time-pickup_time-req.direct_time
    
    return detour > threshold
end


"""
rejection_max_relative_delay(bus::Bus,model::ABM)::Bool
"""
function rejection_relative_detour(bus::Bus,model::ABM,threshold::Float64)::Bool
    
    req=model.requests[end]

    #figure out if passenger has already been picked up
    picked_up= (req.t_pickup != 0)

    #set pickup+dropoff time
    pickup_time = picked_up ? req.t_pickup : model.time
    dropoff_time=model.time

    #if user had been dropped off, they wouldnt be scheduled anymore :)
    dropped_off=false

    #calculate passenger's projected dropoff time based on current todo list
    k=0
    while !( picked_up && dropped_off)
        k+=1
        job=bus.todo[k]

        #add to pick_up time if not picked up yet
        if !picked_up
            pickup_time+=job.duration
        end

        #add to dropoff time
        dropoff_time+=job.duration

        #chkeck if user is picked up or dropped off by this job
        if job.req_id == req.id
            if job.Δ==1
                picked_up=true
            else
                dropped_off=true
            end
        end
    end

    #calculate total delay customer experiences because of using our system
    detour=(dropoff_time-pickup_time-req.direct_time)/req.direct_time
    
    return detour > threshold
end


"""
rejection_max_relative_delay(bus::Bus,model::ABM)::Bool
"""
function rejection_any_waiting_time(bus::Bus,model::ABM,threshold::Float64)::Bool

    maxwait=0.0
    
    for p in scheduled_passengers(bus)
        req=model.requests[p]
        
        #figure out if passenger has already been picked up
        picked_up= (req.t_pickup != 0)
        
        #set pickup time
        pickup_time = picked_up ? req.t_pickup : model.time
        
        #calculate passenger's projected dropoff time based on current todo list
        k=0
        while !picked_up
            k+=1
            job=bus.todo[k]
            
            #add to pick_up time
            pickup_time+=job.duration
            
            #chkeck if user is picked up or dropped off by this job
            if job.req_id == req.id && job.Δ==1
                picked_up=true
            end
        end

        #calculate total delay customer experiences because of using our system
        wait=pickup_time-req.t_submit
        
        #update max-found detour so far
        maxwait=max(maxwait,wait)
    end
    
    return maxwait > threshold
end


"""
rejection_max_relative_delay(bus::Bus,model::ABM)::Bool
"""
function rejection_any_relative_waiting_time(bus::Bus,model::ABM,threshold::Float64)::Bool

    maxwait=0.0
    
    for p in scheduled_passengers(bus)
        req=model.requests[p]
        
        #figure out if passenger has already been picked up
        picked_up= (req.t_pickup != 0)
        
        #set pickup time
        pickup_time = picked_up ? req.t_pickup : model.time
        
        #calculate passenger's projected dropoff time based on current todo list
        k=0
        while !picked_up
            k+=1
            job=bus.todo[k]
            
            #add to pick_up time
            pickup_time+=job.duration
            
            #chkeck if user is picked up or dropped off by this job
            if job.req_id == req.id && job.Δ==1
                picked_up=true
            end
        end

        #calculate total delay customer experiences because of using our system
        wait=(pickup_time-req.t_submit)/req.direct_time
        
        #update max-found detour so far
        maxwait=max(maxwait,wait)
    end
    
    return maxwait > threshold
end


"""
rejection_max_relative_delay(bus::Bus,model::ABM)::Bool
"""
function rejection_waiting_time(bus::Bus,model::ABM,threshold::Float64)::Bool
    
    req=model.requests[end]
        
    #figure out if passenger has already been picked up
    picked_up= (req.t_pickup != 0)

    #set pickup time
    pickup_time = picked_up ? req.t_pickup : model.time

    #calculate passenger's projected dropoff time based on current todo list
    k=0
    while !picked_up
        k+=1
        job=bus.todo[k]

        #add to pick_up time
        pickup_time+=job.duration

        #chkeck if user is picked up or dropped off by this job
        if job.req_id == req.id && job.Δ==1
            picked_up=true
        end
    end

    #calculate total delay customer experiences because of using our system
    wait=pickup_time-req.t_submit
    
    return wait > threshold
end


"""
rejection_max_relative_delay(bus::Bus,model::ABM)::Bool
"""
function rejection_relative_waiting_time(bus::Bus,model::ABM,threshold::Float64)::Bool
    
    req=model.requests[end]
        
    #figure out if passenger has already been picked up
    picked_up= (req.t_pickup != 0)

    #set pickup time
    pickup_time = picked_up ? req.t_pickup : model.time

    #calculate passenger's projected dropoff time based on current todo list
    k=0
    while !picked_up
        k+=1
        job=bus.todo[k]

        #add to pick_up time
        pickup_time+=job.duration

        #chkeck if user is picked up or dropped off by this job
        if job.req_id == req.id && job.Δ==1
            picked_up=true
        end
    end

    #calculate total delay customer experiences because of using our system
    wait=(pickup_time-req.t_submit)/req.direct_time
    
    return wait > threshold
end





##############






"""
rejection_max_relative_delay(bus::Bus,model::ABM)::Bool
"""
function rejection_any_relative_detour_plus_offset(bus::Bus,model::ABM,threshold::Tuple{Float64,Float64})::Bool

    maxdetour=0.0
    
    for p in scheduled_passengers(bus)
        req=model.requests[p]
        
        #figure out if passenger has already been picked up
        picked_up= (req.t_pickup != 0)
        
        #set pickup+dropoff time
        pickup_time = picked_up ? req.t_pickup : model.time
        dropoff_time=model.time
        
        #if user had been dropped off, they wouldnt be scheduled anymore :)
        dropped_off=false
        
        #calculate passenger's projected dropoff time based on current todo list
        k=0
        while !( picked_up && dropped_off)
            k+=1
            job=bus.todo[k]
            
            #add to pick_up time if not picked up yet
            if !picked_up
                pickup_time+=job.duration
            end
            
            #add to dropoff time
            dropoff_time+=job.duration
            
            #chkeck if user is picked up or dropped off by this job
            if job.req_id == req.id
                if job.Δ==1
                    picked_up=true
                else
                    dropped_off=true
                end
            end
        end

        #calculate total delay customer experiences because of using our system
        detour=(dropoff_time-pickup_time-threshold[1]-req.direct_time)/req.direct_time
        
        #update max-found detour so far
        maxdetour=max(maxdetour,detour)
    end
    
    return maxdetour > threshold[2]
end