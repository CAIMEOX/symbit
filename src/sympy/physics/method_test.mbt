///|
fn method_matrix_summary(matrix : @symphysics.ExplicitMatrix) -> String {
  @symphysics.explicit_matrix_rows_string(matrix)
}

///|
test "physics.mechanics linearizer core semantics" {
  let x = @symvector.dynamicsymbol("x")
  let v = @symvector.dynamicsymbol("v")
  let f = @symvector.dynamicsymbol("F")
  let k = @symcore.Expr::Symbol("k")
  let c = @symcore.Expr::Symbol("c")
  let m = @symcore.Expr::Symbol("m")
  let lin = linearizer(
    [x, v],
    [v, (@symcore.int(-1) * (k * x + c * v) + f) * (m ^ @symcore.int(-1))],
    inputs=[f],
  )
  let (m_implicit, a_implicit) = lin.linearize()
  inspect(method_matrix_summary(m_implicit), content="[[1, 0], [0, 1]]")
  inspect(
    method_matrix_summary(a_implicit),
    content="[[0, 1], [-k*m**-1, -c*m**-1]]",
  )
  let (_, _, b_implicit) = lin.linearize_mab()
  inspect(method_matrix_summary(b_implicit), content="[[0], [m**-1]]")
  let (a_explicit, b_explicit) = lin.linearize(a_and_b=true)
  inspect(
    method_matrix_summary(a_explicit),
    content="[[0, 1], [-k*m**-1, -c*m**-1]]",
  )
  inspect(method_matrix_summary(b_explicit), content="[[0], [m**-1]]")
}

///|
test "physics.mechanics lagrange solve_multipliers parity-friendly semantics" {
  let x = @symvector.dynamicsymbol("x")
  let y = @symvector.dynamicsymbol("y")
  let n = @symvector.reference_frame("MLN")
  let o = @symvector.point("MLO")
  o.set_vel(n, @symvector.vector_zero())
  let p = o.locatenew("MLP", n.x().scale(x) + n.y().scale(y))
  p.set_vel(
    n,
    n.x().scale(@symcalculus.diff(x, @symvector.dynamicsymbols_t)) +
    n.y().scale(@symcalculus.diff(y, @symvector.dynamicsymbols_t)),
  )
  let pa = particle(
    "MLPa",
    point=Some(p),
    mass=Some(@symcore.Expr::Symbol("m")),
  )
  pa.set_potential_energy(
    @symcore.Expr::Symbol("g") * @symcore.Expr::Symbol("m") * y,
  )
  let lagr = lagrangian(n, [pa.as_bodylike()])
  let lm = lagranges_method(
    lagr,
    [x, y],
    bodies=[pa.as_bodylike()],
    frame=Some(n),
    hol_coneqs=[x * x + y * y - (@symcore.Expr::Symbol("l") ^ @symcore.int(2))],
  )
  ignore(lm.form_lagranges_equations())
  let lambdas = lm.solve_multipliers(op_point=[
    (x, @symcore.Expr::Symbol("l")),
    (y, @symcore.int(0)),
    (@symcalculus.diff(x, @symvector.dynamicsymbols_t), @symcore.int(0)),
    (@symcalculus.diff(y, @symvector.dynamicsymbols_t), @symcore.int(0)),
  ])
  assert_eq(lambdas.height(), 1)
  let oracle_lambda = mechanics_eval(
    [
      "x, y = dynamicsymbols('x y')", "m, g, l = symbols('m g l')", "N = ReferenceFrame('MLN')",
      "O = Point('MLO')", "O.set_vel(N, 0)", "P = O.locatenew('MLP', x*N.x + y*N.y)",
      "P.set_vel(N, x.diff(t)*N.x + y.diff(t)*N.y)", "Pa = Particle('MLPa', P, m)",
      "Pa.potential_energy = g*m*y", "Lag = Lagrangian(N, Pa)", "LM = LagrangesMethod(Lag, [x, y], hol_coneqs=[x**2 + y**2 - l**2], frame=N)",
      "LM.form_lagranges_equations()", "LM.solve_multipliers({x: l, y: 0, x.diff(t): 0, y.diff(t): 0}, sol_type='Matrix')[0]",
    ].join("; "),
  )
  assert_true(
    mechanics_expr_equal(@symprint.to_string(lambdas.get(0, 0)), oracle_lambda),
  )
}
