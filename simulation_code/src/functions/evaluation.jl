export mean_relative_delay,
mean_delay,
mean_waiting_time,
mean_relative_waiting_time,
requested_distance,
requested_time,
mean_requested_distance,
mean_requested_time,
driven_distance,
driven_time,
mean_occupancy,
served_percentage,
delta,
p_busy



function mean_relative_delay(model::ABM)::Float64
    time=0.0
    Z=0
    for req in model.requests
        t_actual=req.t_dropoff-req.t_submit
        if req.t_dropoff > 0    #only dropped-off requests
            Z+=1
            time+=(t_actual-req.direct_time)/req.direct_time
        end
    end
    
    return time/Z
end


function mean_delay(model::ABM)::Float64
    time=0.0
    Z=0
    
    for req in model.requests
        if req.t_dropoff>0    #only dropped-off requests
            Z+=1
            t_actual=req.t_dropoff-req.t_submit
            time+=t_actual-req.direct_time
        end
    end
    
    return time/Z
end


function mean_waiting_time(model::ABM)::Float64
    time=0.0
    Z=0
    for req in model.requests
        if req.t_pickup>0    #only picked-up requests
            Z+=1
            time+=req.t_pickup-req.t_submit
        end
    end
    
    return time/Z
end


function mean_relative_waiting_time(model::ABM)::Float64
    time=0.0
    Z=0
    for req in model.requests
        if req.t_pickup>0    #only picked-up requests
            Z+=1
            time+=(req.t_pickup-req.t_submit)/req.direct_time
        end
    end
    
    return time/Z
end


function requested_distance(model::ABM)::Float64
    distance=0.0
    
    for req in model.requests
        if req.bus_id>0    #only non-rejected requests
            distance+=req.direct_length
        end
    end
    
    return distance
end


function mean_requested_distance(model::ABM)::Float64
    distance=0.0
    Z=0
    
    for req in model.requests
        if req.bus_id>0    #only non-rejected requests
            Z+=1
            distance+=req.direct_length
        end
    end
    
    return distance/Z
end


function requested_time(model::ABM)::Float64
    time=0.0
    
    for req in model.requests
        if req.bus_id>0    #only non-rejected requests
            time+=req.direct_time
        end
    end
    
    return time
end


function mean_requested_time(model::ABM)::Float64
    time=0.0
    Z=0
    
    for req in model.requests
        if req.bus_id>0    #only non-rejected requests
            Z+=1
            time+=req.direct_time
        end
    end
    
    return time/Z
end


function driven_distance(model::ABM)::Float64
    distance=0.0
    for bus_id in 1:length(model.agents), job in model.job_history[bus_id]   #all finished jobs
        distance+=job.length
    end
    
    return distance
end


function driven_time(model::ABM)::Float64
    time=0.0
    for bus_id in 1:length(model.agents), job in model.job_history[bus_id]   #all finished jobs
        time+=job.duration
    end
    
    return time
end


function mean_occupancy(model::ABM)::Tuple{Float64,Float64,Float64,Float64}
    bt=0.0      #non-idle average over time
    bt_star=0.0 #non-empty average over time
    t=0.0       #non-idle time
    t_star=0.0  #non-empty time
    
    bs=0.0      #non-idle average over distance
    bs_star=0.0 #non-empty average over distance
    s=0.0       #non-idle distance
    s_star=0.0  #non-empty distance
    
    #get occupancy
    for bus_id in 1:length(model.agents)
        passengers=0   #buses start empty at beginning of simulation
        for job in model.job_history[bus_id]
            if passengers == 0
                #contribution to non-idle time average
                bt+=passengers*job.duration
                t+=job.duration
                
                #contribution to non-idle distance average
                bs+=passengers*job.length
                s+=job.length
            else
                #contribution to non-idle time average
                bt+=passengers*job.duration
                t+=job.duration
                bt_star+=passengers*job.duration
                t_star+=job.duration
                
                #contribution to non-idle distance average
                bs+=passengers*job.length
                s+=job.length
                bs_star+=passengers*job.length
                s_star+=job.length
            end
            passengers+=job.Δ
        end
    end
    
    return (bs_star/s_star,bt_star/t_star,bs/s,bt/t)
end


function served_percentage(model;startindex=1)
    served=0
    total=0
    for req in model.requests[startindex:end-1]
        total+=1
        if req.bus_id>0
            served+=1
        end
    end
    
    return served/total
end


#detour in terms of TIME!
function delta(model::ABM)::Tuple{Float64,Float64}
    total_passenger_on_board_time=0.0
    total_requested_time=0.0
    delta_passengers=0.0
    Z=0
    
    for req in model.requests
        if req.t_dropoff>0    #only finished requests
            Z+=1
            total_passenger_on_board_time+=req.t_dropoff-req.t_pickup
            total_requested_time+=req.direct_time
            delta_passengers+=(req.t_dropoff-req.t_pickup)/req.direct_time
        end
    end
    
    delta_system=total_passenger_on_board_time/total_requested_time
    
    return (delta_system,delta_passengers/Z)
end


"""
p_busy(model::ABM)::Float64  returns the fraction of time that the busses were driving ('busy') instead of being idle.
For each bus, a time average is performed started when it first starts driving, ending when its last job was finished.
The resutls are averaged uniformly over all buses and returned.
"""
function p_busy(model::ABM)::Float64   
    
    
    #construct array with probabilities (one for each bus)
    ps=zeros(length(model.agents))
    
    #consider each bus individually
    for bus_id in 1:length(model.agents)
        #find the first time the bus started driving
        req_id=0
        job=model.job_history[bus_id][1]
        j=-1
        while req_id==0
            j+=1
            job=model.job_history[bus_id][1+j]
            req_id=job.req_id
        end
        req=model.requests[job.req_id]
        t_start=req.t_submit
        
        #find the last time the bus finished a job
        req_id=0
        job=model.job_history[bus_id][end]
        k=-1
        while req_id==0
            k+=1
            job=model.job_history[bus_id][end-k]
            req_id=job.req_id
        end
        req=model.requests[job.req_id]
        t_final=max(req.t_pickup,req.t_dropoff)
        
        #find the total time the bus spent driving for finished jobs
        t_drive=0
        for job in model.job_history[bus_id][1+j:end-k]
            t_drive+=job.duration
        end
        
        #combine into probability to be busy
        ps[bus_id]=t_drive/(t_final-t_start)
    end
    
    #return mean over all buses
    return sum(ps)/length(model.agents)
    
end
