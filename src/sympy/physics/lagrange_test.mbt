///|
fn lagrange_matrix_entry_summary(matrix : @symphysics.ExplicitMatrix) -> String {
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
test "physics.mechanics lagrange: simple pendulum rhs" {
  let q = @symvector.dynamicsymbol("q")
  let n = @symvector.reference_frame("LN")
  let a = @symvector.reference_frame("LA")
  a.orient_axis(n, n.z(), q)
  a.set_ang_vel(
    n,
    n.z().scale(@symcalculus.diff(q, @symvector.dynamicsymbols_t)),
  )

  let o = @symvector.point("LO")
  o.set_vel(n, @symvector.vector_zero())
  let p = o.locatenew("LP", a.x().scale(Symbol("l")))
  ignore(p.v2pt_theory(o, n, a))
  let pa = particle("LPa", point=Some(p), mass=Some(Symbol("m")))
  pa.set_potential_energy(
    @symcore.int(-1) * Symbol("m") * Symbol("g") * Symbol("l") * @symelem.cos(q),
  )

  let lagr = lagrangian(n, [pa.as_bodylike()])
  let lm = lagranges_method(lagr, [q], bodies=[pa.as_bodylike()], frame=Some(n))
  ignore(lm.form_lagranges_equations())
  let rhs = lm.rhs()
  inspect(lagrange_matrix_entry_summary(lm.mass_matrix()), content="[[l**2*m]]")
  assert_true(
    mechanics_expr_equal(
      @symprint.pretty_string(rhs.get(1, 0)),
      "-g*sin(q(t))/l",
    ),
  )
}
