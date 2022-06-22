export pYslot_agent!,
    plot_agents!,
    plot_todo!,
    plot_todos!,
    plot_route!,
    plot_routes!,
    plot_destination!,
    plot_destinations!,
    plot_request!,
    plot_model!,
    plot_background,
    plot_subspaces!



#plot position of one agent in model
function plot_agent!(agent,model;flip=false)
    point=cartesian_coords(agent.pos,model;flip=flip)
    plot!([point[1]],[point[2]],color=:black,marker=:circle,markersize=11)
end


#plot all agents at once
function plot_agents!(model,p;flip=false)
    for id in model.scheduler(model)
        plot_agent!(model[id],model;flip=flip)
    end
    p
end


function plot_request!(req,model,p;flip=false)
    
    if req.bus_id < 0
        return p
    end
    
    if req.t_pickup==0.0
        point=cartesian_coords(req.pickup,model;flip=flip)
        scatter!([point[1]],[point[2]],color=req.plotcolor,marker=:star5,markersize=8)
    end
    
    if req.t_dropoff==0.0
        point=cartesian_coords(req.dropoff,model;flip=flip)
        scatter!([point[1]],[point[2]],color=req.plotcolor,marker=:utriangle,markersize=8)
    end
    
    p
end


function plot_model!(model,p;flip=false)
    plot_agents!(model,p;flip=flip)    
    for req in model.requests[1:end-1]
        #pickup=diamond
        #dropoff = square
        plot_request!(req,model,p;flip=flip)
    end
    
    p
end


function plot_background(model;zoom=1.0,width=800)
y_max=model.space.m.bounds.max_y*6371000*2*pi/360
y_min=model.space.m.bounds.min_y*6371000*2*pi/360
x_max=model.space.m.bounds.max_x*6371000*sin(model.space.m.bounds.min_y*2*pi/360)*2*pi/360
x_min=model.space.m.bounds.min_x*6371000*sin(model.space.m.bounds.min_y*2*pi/360)*2*pi/360

Δx=x_max-x_min;x=0.5*(x_max+x_min)
Δy=y_max-y_min;y=0.5*(y_max+y_min)

plotmap(model.space.m);plot!(size=[width,width*Δy/Δx],xlim=[-0.5*Δx,0.5*Δx]./zoom,ylim=[-0.5*Δy,0.5*Δy]./zoom,framestyle=:box,margin=5mm)
end


function plot_subspaces!(model,p;flip=false)
colors = cgrad(:rainbow,max(3,length(model.subspaces)),categorical=true,rev=true)
fillalpha=0.15
linewidth=1.5
marker=:square
markersize=8

k=0
for space in model.subspaces
    k+=1
    if space.category in (:triplets,:nodes,:latlon_to_node,:latlon_to_edge)        #points
        Xs=[cartesian_coords(point,model;flip=flip)[1] for point in space.content]
        Ys=[cartesian_coords(point,model;flip=flip)[2] for point in space.content]
        scatter!(Xs,Ys,marker=marker,markercolor=colors[k],markersize=markersize)  #polygon
    elseif space.category in (:area_to_node,:area_to_edge)
        Xs=[cartesian_coords(point,model;flip=flip)[1] for point in space.content[1]]
        Ys=[cartesian_coords(point,model;flip=flip)[2] for point in space.content[1]]
        plot!(Xs,Ys,fillrange = 0,fillalpha = fillalpha,fillcolor = colors[k],linecolor=:black,linewidth=linewidth)
    elseif space.category == :edges
        for ids in space.content[1]
            Xs=[cartesian_coords(ids[1],model;flip=flip)[1],cartesian_coords(ids[2],model;flip=flip)[1]]
            Ys=[cartesian_coords(ids[1],model;flip=flip)[2],cartesian_coords(ids[2],model;flip=flip)[2]]
            plot!(Xs,Ys,color=colors[k],linewidth=linewidth*0.4)
        end
    end
end
p
end