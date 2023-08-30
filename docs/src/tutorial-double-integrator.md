# [Double integrator: time minimisation 2](@id DIT2)

The time minimisation double integrator problem consists in minimising

```math
    tf 
```

subject to the constraints

```math
    \dot x_1(t) = x_2(t), \quad \dot x_2(t) = u(t), \quad u(t) \in [-1,1], \quad x_1(t) \in [0,5], \quad x_2(t) \in [-2,3]
```

and the limit conditions

```math
    x(0) = (1,2), \quad x(t_f) = (0,0)
```


First, we need to import the `OptimalControl.jl` package:

```@example main
using OptimalControl
```

Then, we can define the problem

```@example main
@def ocp begin
    tf ∈ R, variable
    t ∈ [ 0, tf ], time
    x ∈ R², state
    u ∈ R, control
    tf ≥ 0
    -1 ≤ u(t) ≤ 1
    q = x₁
    v = x₂
    q(0) == 1
    v(0) == 2
    q(tf) == 0
    v(tf) == 0
    0 ≤ q(t) ≤ 5,       (1)
    -2 ≤ v(t) ≤ 3,      (2)
    ẋ(t) == [ v(t), u(t) ]
    tf → min
end
nothing # hide
```

Solve it

```@example main
sol = solve(ocp)
nothing # hide
```

and plot the solution

```@example main
plot(sol, size=(600, 450))
```