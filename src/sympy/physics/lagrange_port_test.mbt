///|
fn lagrange_port_matrix_entry_summary(
  matrix : @symphysics.ExplicitMatrix,
) -> String {
  let entries = matrix.rows_copy()
  let rows : Array[String] = []
  for i in 0..<matrix.height() {
    let row : Array[String] = []
    for j in 0..<matrix.width() {
      row.push(@symprint.pretty_string(entries[i][j]))
    }
    rows.push("[" + row.join(", ") + "]")
  }
  "[" + rows.join(", ") + "]"
}

///|
test "physics.mechanics parity lagrange simple pendulum" {
  let q = @symvector.dynamicsymbol("q")
  let n = @symvector.reference_frame("PLN")
  let a = @symvector.reference_frame("PLA")
  a.orient_axis(n, n.z(), q)
  a.set_ang_vel(
    n,
    n.z().scale(@symcalculus.diff(q, @symvector.dynamicsymbols_t)),
  )
  let o = @symvector.point("PLO")
  o.set_vel(n, @symvector.vector_zero())
  let p = o.locatenew("PLP", a.x().scale(@symcore.Expr::Symbol("l")))
  ignore(p.v2pt_theory(o, n, a))
  let pa = particle(
    "PLPa",
    point=Some(p),
    mass=Some(@symcore.Expr::Symbol("m")),
  )
  pa.set_potential_energy(
    @symcore.int(-1) *
    @symcore.Expr::Symbol("m") *
    @symcore.Expr::Symbol("g") *
    @symcore.Expr::Symbol("l") *
    @symelem.cos(q),
  )
  let lagr = lagrangian(n, [pa.as_bodylike()])
  let lm = lagranges_method(lagr, [q], bodies=[pa.as_bodylike()], frame=Some(n))
  ignore(lm.form_lagranges_equations())
  let prefix = "q=dynamicsymbols('q'); N=ReferenceFrame('PLN'); A=N.orientnew('PLA','Axis',[q,N.z]); A.set_ang_vel(N, q.diff(t)*N.z); O=Point('PLO'); O.set_vel(N,0); P=O.locatenew('PLP', symbols('l')*A.x); P.v2pt_theory(O,N,A); Pa=Particle('PLPa', P, symbols('m')); Pa.potential_energy=-symbols('m')*symbols('g')*symbols('l')*cos(q); L=Lagrangian(N, Pa); LM=LagrangesMethod(L, [q], bodies=[Pa], frame=N); LM.form_lagranges_equations(); "
  let oracle_mass = mechanics_summary(
    prefix + "[[str(x) for x in row] for row in LM.mass_matrix.tolist()]",
  )
  let oracle_rhs = mechanics_summary(
    prefix + "[[str(x) for x in row] for row in LM.rhs().tolist()]",
  )
  assert_eq(
    lagrange_port_matrix_entry_summary(lm.mass_matrix()).replace(
      old=" ",
      new="",
    ),
    oracle_mass.replace(old=" ", new=""),
  )
  let rhs = lm.rhs()
  assert_true(
    mechanics_expr_equal(
      @symprint.pretty_string(rhs.get(0, 0)),
      "Derivative(q(t), t)",
    ),
  )
  assert_true(
    oracle_rhs.contains("-g*sin(q(t))/l") &&
    mechanics_expr_equal(
      @symprint.pretty_string(rhs.get(1, 0)),
      "-g*sin(q(t))/l",
    ),
  )
}
