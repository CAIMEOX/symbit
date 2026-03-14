///|
fn lagrange_matrix_entry_summary(matrix : @symphysics.ExplicitMatrix) -> String {
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
test "physics.mechanics lagrange: simple pendulum rhs" {
  let q = @symvector.dynamicsymbol("q")
  let n = try! @symvector.reference_frame("LN")
  let a = try! @symvector.reference_frame("LA")
  a.orient_axis(n, n.z(), q)
  a.set_ang_vel(
    n,
    n.z().scale(@symcalculus.diff(q, @symvector.dynamicsymbols_t)),
  )

  let o = try! @symvector.point("LO")
  o.set_vel(n, @symvector.vector_zero())
  let p = try! o.locatenew("LP", a.x().scale(@symcore.symbol("l")))
  ignore(try! p.v2pt_theory(o, n, a))
  let pa = try! particle("LPa", point=Some(p), mass=Some(@symcore.symbol("m")))
  pa.set_potential_energy(
    @symcore.int(-1) *
    @symcore.symbol("m") *
    @symcore.symbol("g") *
    @symcore.symbol("l") *
    @symelem.cos(q),
  )

  let lagr = try! lagrangian(n, [pa.as_bodylike()])
  let lm = try! lagranges_method(
    lagr,
    [q],
    bodies=[pa.as_bodylike()],
    frame=Some(n),
  )
  ignore(try! lm.form_lagranges_equations())
  let rhs = try! lm.rhs()
  inspect(lagrange_matrix_entry_summary(lm.mass_matrix()), content="[[l**2*m]]")
  guard (try! @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(try! rhs.get(1, 0)),
    "-g*sin(q(t))/l",
  )) else {
    fail("simple pendulum acceleration mismatch")
  }
}
