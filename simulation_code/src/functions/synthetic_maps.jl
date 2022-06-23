function make_subspace(map,subspace)
    if subspace==:all_area_to_node
        bounds=(map.m.bounds.min_x,map.m.bounds.max_x,map.m.bounds.min_y,map.m.bounds.max_y)
        polygon=( [bounds[1],bounds[3]], [bounds[1],bounds[4]], [bounds[2],bounds[4]], [bounds[2],bounds[3]], [bounds[1],bounds[3]] )
        return ( Subspace(1.0,[1.0],:area_to_node,(polygon,bounds)) ,)
        
    elseif subspace==:all_area_to_edge
        bounds=(map.m.bounds.min_x,map.m.bounds.max_x,map.m.bounds.min_y,map.m.bounds.max_y)
        polygon=( [bounds[1],bounds[3]], [bounds[1],bounds[4]], [bounds[2],bounds[4]], [bounds[2],bounds[3]], [bounds[1],bounds[3]] )
        return ( Subspace(1.0,[1.0],:area_to_edge,(polygon,bounds)) ,)
        
    elseif subspace==:all_nodes
        all_nodes=Tuple(1:length(map.m.n))
        return ( Subspace(1.0,[1.0],:nodes,all_nodes) ,)
        
    elseif subspace==:all_edges
        I, J, V = findnz(map.m.w);
        edge_indices = collect(zip(I,J))
        edge_probabilities = [map.m.w[pair...] for pair in edge_indices]
        return ( Subspace(1.0,[1.0],:edges,(edge_indices,edge_probabilities)) ,)
    end
end


function grid_map(N,M)

    #make grid map, NxM

    #dummies
    roadways=OpenStreetMapX.Way[]
    intersections=Dict{Int,Set{Int}}()
    bounds=OpenStreetMapX.Bounds{OpenStreetMapX.LLA}(1,N,1,M)

    #list of OSM-node-ids that are actual graph-nodes
    n=collect(1:(N*M))

    #dict with Cartesian positions (ENU) of all nodes
    nodes=Dict{Int,OpenStreetMapX.ENU}()
    for nid in n
        x=(nid-1)%M + 1
        y=Integer(ceil(nid/M))
        nodes[nid]=OpenStreetMapX.ENU(x*1.0,y)
    end

    #what's the graph-node-id of that OSM-node-id?
    v=Dict{Int,Int}()
    for nid in n
        v[nid]=nid
    end

    #edges
    neighbours=Vector{Int}[]
    for nid in n
        list=Int[]
        x,y=(nodes[nid].east,nodes[nid].north)
        #left
        x>1 ? push!(list,nid-1) : nothing
        #right
        x<M ? push!(list,nid+1) : nothing
        #down
        y>1 ? push!(list,nid-M) : nothing
        #up
        y<N ? push!(list,nid+M) : nothing
        push!(neighbours,list)
    end
    e=[(i,j) for i in n for j in neighbours[i]]

    #edge weights
    mat=zeros(N*M,N*M)
    for edge in e
        mat[edge...]=1.0
    end
    w=sparse(mat)

    #edge classes
    class=[1 for _ in 1:length(e)]
    
    #LightGraphs graph for a_star route finding
    g = OpenStreetMapX.LightGraphs.DiGraph(length(v))
	for edge in e
		OpenStreetMapX.add_edge!(g,v[edge[1]], v[edge[2]])
	end
    
    return OpenStreetMapX.MapData(bounds,nodes,roadways,intersections,g,v,n,e,w,class)
end


function star_grid_map(N,M)

    #make grid map, NxM

    #dummies
    roadways=OpenStreetMapX.Way[]
    intersections=Dict{Int,Set{Int}}()
    bounds=OpenStreetMapX.Bounds{OpenStreetMapX.LLA}(1,N,1,M)

    #list of OSM-node-ids that are actual graph-nodes
    n=collect(1:(N*M))

    #dict with Cartesian positions (ENU) of all nodes
    nodes=Dict{Int,OpenStreetMapX.ENU}()
    for nid in n
        x=(nid-1)%M + 1
        y=Integer(ceil(nid/M))
        nodes[nid]=OpenStreetMapX.ENU(x*1.0,y)
    end

    #what's the graph-node-id of that OSM-node-id?
    v=Dict{Int,Int}()
    for nid in n
        v[nid]=nid
    end

    #edges
    neighbours=Vector{Int}[]
    for nid in n
        list=Int[]
        x,y=(nodes[nid].east,nodes[nid].north)
        #up
        y<N ? push!(list,nid+M) : nothing
        #up-right
        (y<N && x<M) ? push!(list,nid+M+1) : nothing
        #right
        x<M ? push!(list,nid+1) : nothing
        #right-down
        (y>1 && x<M) ? push!(list,nid-M+1) : nothing
        #down
        y>1 ? push!(list,nid-M) : nothing
        #down-left
        (y>1 && x>1) ? push!(list,nid-M-1) : nothing
        #left
        x>1 ? push!(list,nid-1) : nothing
        #left-up
        (y<N && x>1) ? push!(list,nid+M-1) : nothing
        push!(neighbours,list)
    end
    e=[(i,j) for i in n for j in neighbours[i]]

    #edge weights
    mat=zeros(N*M,N*M)
    for edge in e
        mat[edge...]=1.0
    end
    w=sparse(mat)

    #edge classes
    class=[1 for _ in 1:length(e)]
    
    #LightGraphs graph for a_star route finding
    g = OpenStreetMapX.LightGraphs.DiGraph(length(v))
	for edge in e
		OpenStreetMapX.add_edge!(g,v[edge[1]], v[edge[2]])
	end
    
    return OpenStreetMapX.MapData(bounds,nodes,roadways,intersections,g,v,n,e,w,class)
end




function grid_highway_map(N,M,(p,q),weight)

    #make grid map, NxM with one additional edge (p,q) with length 'weight'.

    #dummies
    roadways=OpenStreetMapX.Way[]
    intersections=Dict{Int,Set{Int}}()
    bounds=OpenStreetMapX.Bounds{OpenStreetMapX.LLA}(1,N,1,M)

    #list of OSM-node-ids that are actual graph-nodes
    n=collect(1:(N*M))

    #dict with Cartesian positions (ENU) of all nodes
    nodes=Dict{Int,OpenStreetMapX.ENU}()
    for nid in n
        x=(nid-1)%M + 1
        y=Integer(ceil(nid/M))
        nodes[nid]=OpenStreetMapX.ENU(x*1.0,y)
    end

    #what's the graph-node-id of that OSM-node-id?
    v=Dict{Int,Int}()
    for nid in n
        v[nid]=nid
    end

    #edges
    neighbours=Vector{Int}[]
    for nid in n
        list=Int[]
        x,y=(nodes[nid].east,nodes[nid].north)
        #left
        x>1 ? push!(list,nid-1) : nothing
        #right
        x<M ? push!(list,nid+1) : nothing
        #down
        y>1 ? push!(list,nid-M) : nothing
        #up
        y<N ? push!(list,nid+M) : nothing
        push!(neighbours,list)
    end
    e=[(i,j) for i in n for j in neighbours[i]]

    #edge weights
    mat=zeros(N*M,N*M)
    for edge in e
        mat[edge...]=1.0
    end
    w=sparse(mat)

    #edge classes
    class=[1 for _ in 1:length(e)]
    
    #add highway
    push!(e,(p,q))
    push!(class,1.0)
    w[p,q]=weight
    
    #LightGraphs graph for a_star route finding
    g = OpenStreetMapX.LightGraphs.DiGraph(length(v))
	for edge in e
		OpenStreetMapX.add_edge!(g,v[edge[1]], v[edge[2]])
	end
    
    return OpenStreetMapX.MapData(bounds,nodes,roadways,intersections,g,v,n,e,w,class)
end


function htree4()

    #make 4 layers of an h-tree graph.
    #this is going to be ugly brute-force, sorry.

    #dummies
    roadways=OpenStreetMapX.Way[]
    intersections=Dict{Int,Set{Int}}()

    #list of OSM-node-ids that are actual graph-nodes
    N=80
    n=collect(1:N)

    #node positions
    nodes=Dict{Int,OpenStreetMapX.ENU}()
    # level 1
    for nid in 1:8
        x=nid-1
        y=0
        nodes[nid]=OpenStreetMapX.ENU(x*1.0,y)
    end

    # level 2
    for nid in 9:16
        x= nid<13 ? 0 : 7
        y= [2,1,-1,-2][(nid-9)%4+1]
        nodes[nid]=OpenStreetMapX.ENU(x*1.0,y)
    end

    # level 3
    for nid in 17:32
        x=[-2,-1,1,2,5,6,8,9][(nid-17)%8+1]
        y= nid<25 ? 2 : -2
        nodes[nid]=OpenStreetMapX.ENU(x*1.0,y)
    end

    # level 4
    for nid in 33:80
        x=[-3,-2,-1,1,2,3,4,5,6,8,9,10][(nid-33)%12+1]
        y=[3,1,-1,-3][ Integer(ceil((nid-32)/12)) ]
        nodes[nid]=OpenStreetMapX.ENU(x*1.0,y)
    end

    #edges
    #horizontal lines
    lines=[1:8,]
    append!(lines,[k:k+2 for k in 33:3:78])
    lines=collect.(lines)
    append!(lines,[[17,18,9,19,20],[21,22,13,23,24],[25,26,12,27,28],[29,30,16,31,32]])
    #vertical lines
    push!(lines,[9,10,1,11,12])
    push!(lines,[13,14,8,15,16])
    append!(lines,[[34,17,46],[37,20,49],[40,21,52],[43,24,55],[58,25,70],[61,28,73],[64,29,76],[67,32,79]])

    #construct edge tuples from line array
    e=Tuple{Int,Int}[]
    for line in lines
        for k in 1:length(line)-1
            push!(e,(line[k],line[k+1]))
            push!(e,(line[k+1],line[k]))
        end
    end
            
    

    #what's the graph-node-id of that OSM-node-id?
    v=Dict{Int,Int}()
    for nid in n
        v[nid]=nid
    end

    #edge weights
    mat=zeros(N,N)
    for edge in e
        mat[edge...]=1.0
    end
    w=sparse(mat)

    #edge classes
    class=[1 for _ in 1:length(e)]
    
    #LightGraphs graph for a_star route finding
    g = OpenStreetMapX.LightGraphs.DiGraph(length(v))
	for edge in e
		OpenStreetMapX.add_edge!(g,v[edge[1]], v[edge[2]])
	end
    
    #
    minx=-2
    maxx=10
    miny=-3
    maxy=3
    bounds=OpenStreetMapX.Bounds{OpenStreetMapX.LLA}(miny,maxy,minx,maxx)

    return OpenStreetMapX.MapData(bounds,nodes,roadways,intersections,g,v,n,e,w,class)
end
