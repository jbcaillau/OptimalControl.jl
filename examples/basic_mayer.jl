using OptimalControl, NLPModelsIpopt, ADNLPModels
using Plots

# Module

mutable struct direct_sol3
  time::Vector{<:Real}
  X::Matrix{<:Real}
  U::Matrix{<:Real}
  P::Matrix{<:Real}
  n::Int
  m::Int
  N::Int
  #stats::SolverCore.GenericExecutionStats
end




function solve(ocp,N)
  """
    Solve the optimal control problem

    Input : 
    ocp : functional description of the optimal control problem (cf. ocp.jl)
    N   : number of time steps for the discretization
          Int
    
    Output
    sol : solution of the discretized problem
          (time, X, U, n, m, N)
  """
  # transcription ocp -> NLP
  n = ocp.state_dimension
  m = ocp.control_dimension
  f = ocp.dynamics
  L = ocp.lagrange 

  function get_state_at_time_step(xu,i)
    """
      return
      x(t_i)
    """
    if i > N
      error("trying to access at x(t_i) for i > N")
    end  
    return xu[1+i*(n+1):(i+1)*(n+1)]
  end

  function get_control_at_time_step(xu,i)
    """
      return
      u(t_i)
    """
    if i > N-1
      error("trying to access at (t_i) for i > N-1")
    end
    return xu[1+(N+1)*(n+1)+i*m:m+(N+1)*(n+1)+i*m]
  end

  function parse_sol(stats)
    """
      return
        X : matrix(N+1,n+1)
        U : matrix(N,m)
        P : matrix(N,n+1)
    """
      # states and controls
      xu = stats.solution
      X = zeros(N+1,n+1)
      U = zeros(N,m)
      for i in 1:N
        X[i,:] =  get_state_at_time_step(xu,i-1)
        U[i,:] = get_control_at_time_step(xu,i-1)
      end
      X[N+1,:] = get_state_at_time_step(xu,N)

      # adjoints
      P = zeros(N,n+1)
      lambda = stats.multipliers
      for i in 1:N
        P[i,:] = lambda[1+(i-1)*(n+1):i*(n+1)]
      end
    return X, U, P
  end

  # Mayer formulation
  # use an additional state for the Lagrangian cost
  #
  # remark : we pass u[1] because in our case ocp.dynamics and ocp.lagrange are defined with a scalar u
  # and we consider vectors for x and u in the discretized problem. Note that the same would apply for a scalar x.
  # question : how determine if u and x are scalar or vector ?
  # second member of the ode for the Mayer formulation
  f_Mayer(x,u) = [f(x[1:n],u[1]); L(x[1:n],u[1])]
  # if isnothing(ocp.lagrange)
  #   n = ocp.state_dimension
  #   f_Mayer(x,u) = f(x,u[1])
  # else
  #   n = ocp.state_dimension + 1
  #   f_Mayer(x,u) = [f(x[1:n],u[1]); L(x[1:n],u[1])]
  # end

  nc = N*(n+1)+2*n+1               # dimension of the constraints
  # layout of the nlp unknown xu for Euler discretization 
  # additional state variable x_{n+1}(t) for the objective (Lagrange to Mayer formulation)
  # [x_1(t_0), ... , x_{n+1}(t_0),
  #  ... , 
  #  x_{1}(t_N), ... , x_{n+1}(t_N),
  #  u_1(t_0), ... , u_m(t_0), 
  #  ... , 
  #  u_m(t_{N-1}), ..., u_m(t_{N-1})]



                                #




  objective(xu) = xu[(N+1)*(n+1)]

  #function constraint(ocp, xu::Vector{<:Real},N)::Vector{<:Real}
  function constraint(ocp, xu, N)
    """
    compute the constraints for the NLP : 
      - discretization of the dynamics via the Euler method
      - boundary conditions
    inputs
    ocp :: ocp model
    xu :: 
      layout of the nlp unknown xu for Euler discretization 
      additional state variable x_{n+1}(t) for the objective (Lagrange to Mayer formulation)
      [x_1(t_0), ... , x_{n+1}(t_0),
      ... , 
      x_{1}(t_N), ... , x_{n+1}(t_N),
      u_1(t_0), ... , u_m(t_0), 
      ... , 
      u_m(t_{N-1}), ..., u_m(t_{N-1})]
    return
    c :: 
    """
      t0 = ocp.initial_time
      tf = ocp.final_time
      n = ocp.state_dimension
      m = ocp.control_dimension
      nc = N*(n+1)+2*n+1               # dimension of the constraints

      #x0 = ocp.initial_condition
      #xf = ocp.final_condition                                                   
      x0 = [-1., 0.]
      xf = [0., 0.]

      h = (tf-t0)/N
      c = zeros(eltype(xu),nc)
      for i in 0:N-1
        xi = get_state_at_time_step(xu,i)
        xip1 = get_state_at_time_step(xu,i+1)
        ui = get_control_at_time_step(xu,i)
        c[1+i*(n+1):(i+1)*(n+1)] = xip1 - (xi + h*f_Mayer(xi, ui))
      end
      c[1+N*(n+1):n+1+N*(n+1)] = xu[1:n+1] - [x0 ; 0]
      c[n+2+N*(n+1):2*n+1+N*(n+1)] = xu[1+N*(n+1):(N+1)*(n+1)-1] - xf
  
      return c
  end




  # bounds for the constraints
  lb = zeros(nc)
  ub = zeros(nc)

  constraint_Ipopt(xu) = constraint(ocp,xu,N)
  xu0 = zeros((N+1)*(n+1)+N*m)  
  #println(get_state_at_time_step(xu0,1))

  #nlp = ADNLPModel(objective, xu0, constraint_Ipopt,lb,ub)
  nlp = ADNLPModel(objective, xu0, xu -> constraint(ocp,xu,N),lb,ub)
  stats = ipopt(nlp, print_level=3)
  X, U, P = parse_sol(stats)
  time = collect(t0:(tf-t0)/N:tf)
  sol  = direct_sol3(time,X,U,P,n,m,N)
return sol
end



function plot_sol(sol::direct_sol3)
  """
     Plot the solution

     input
       sol : direct_sol
  """
  time = sol.time
  X = sol.X
  U = sol.U
  P = sol.P
  n = sol.n
  m = sol.m
  N = sol.N
  px = plot(time, X,layout = (n+1,1))
  plot!(px[1],title="state")
  plot!(px[n+1], xlabel="t")
  for i in 1:n+1
    plot!(px[i],ylabel = string("x_",i))
  end

  pp = plot(time[1:N], P,layout = (n+1,1))
  plot!(pp[1],title="costate")
  plot!(pp[n+1], xlabel="t")
  for i in 1:n+1
    plot!(pp[i],ylabel = string("p_",i))
  end

  pu = plot(time[1:N],U,lc=:red,layout = (m,1))
  for i in 1:m
    plot!(pu[i],ylabel = string("u_",i))
  end
  plot!(pu[1],title = "control")
  plot!(pu[m],xlabel = "t")

  plot(px,pp,pu,layout = (1,3),legend = false)
end


