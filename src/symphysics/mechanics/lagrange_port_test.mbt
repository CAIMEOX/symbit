///|
fn lagrange_port_matrix_entry_summary(
  matrix : @symphysics.ExplicitMatrix,
) -> String {
  let rows : Array[String] = []
  for i in 0..<matrix.height() {
    let row : Array[String] = []
    for j in 0..<matrix.width() {
      row.push(@symprint.to_string(try! matrix.get(i, j)))
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
  let p = o.locatenew("PLP", a.x().scale(@symcore.symbol("l")))
  ignore(p.v2pt_theory(o, n, a))
  let pa = particle("PLPa", point=Some(p), mass=Some(@symcore.symbol("m")))
  pa.set_potential_energy(
    @symcore.int(-1) *
    @symcore.symbol("m") *
    @symcore.symbol("g") *
    @symcore.symbol("l") *
    @symelem.cos(q),
  )
  let lagr = lagrangian(n, [pa.as_bodylike()])
  let lm = lagranges_method(lagr, [q], bodies=[pa.as_bodylike()], frame=Some(n))
  ignore(lm.form_lagranges_equations())
  let prefix = "q=dynamicsymbols('q'); N=ReferenceFrame('PLN'); A=N.orientnew('PLA','Axis',[q,N.z]); A.set_ang_vel(N, q.diff(t)*N.z); O=Point('PLO'); O.set_vel(N,0); P=O.locatenew('PLP', symbols('l')*A.x); P.v2pt_theory(O,N,A); Pa=Particle('PLPa', P, symbols('m')); Pa.potential_energy=-symbols('m')*symbols('g')*symbols('l')*cos(q); L=Lagrangian(N, Pa); LM=LagrangesMethod(L, [q], bodies=[Pa], frame=N); LM.form_lagranges_equations(); "
  let oracle_mass = @sympy_physics.mechanics_summary(
    prefix + "[[str(x) for x in row] for row in LM.mass_matrix.tolist()]",
  )
  let oracle_rhs = @sympy_physics.mechanics_summary(
    prefix + "[[str(x) for x in row] for row in LM.rhs().tolist()]",
  )
  guard lagrange_port_matrix_entry_summary(lm.mass_matrix()).replace(
      old=" ",
      new="",
    ) ==
    oracle_mass.replace(old=" ", new="") else {
    fail("lagrange mass matrix parity mismatch")
  }
  let rhs = lm.rhs()
  guard @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(rhs.get(0, 0)),
    "Derivative(q(t), t)",
  ) else {
    fail("lagrange rhs first entry mismatch")
  }
  guard oracle_rhs.contains("-g*sin(q(t))/l") &&
    @sympy_physics.mechanics_expr_equal(
      @symprint.to_string(rhs.get(1, 0)),
      "-g*sin(q(t))/l",
    ) else {
    fail("lagrange rhs acceleration mismatch")
  }
}
