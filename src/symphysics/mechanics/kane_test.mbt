///|
fn kane_matrix_entry_summary(matrix : @symphysics.ExplicitMatrix) -> String {
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
test "physics.mechanics kane: spring mass damper" {
  let q = @symvector.dynamicsymbol("q")
  let u = @symvector.dynamicsymbol("u")
  let n = try! @symvector.reference_frame("KN")
  let p = try! @symvector.point("KP")
  p.set_vel(n, n.x().scale(u))
  let pa = try! particle("KPa", point=Some(p), mass=Some(@symcore.symbol("m")))
  let km = try! kanes_method(n, [q], [u], [
    @symcalculus.diff(q, @symvector.dynamicsymbols_t) - u,
  ])
  ignore(
    try! km.kanes_equations([pa.as_bodylike()], [
      force_load(
        p,
        n
        .x()
        .scale(
          @symcore.int(-1) *
          (@symcore.symbol("k") * q + @symcore.symbol("c") * u),
        ),
      ),
    ]),
  )
  inspect(kane_matrix_entry_summary(km.mass_matrix()), content="[[m]]")
  let rhs = try! km.rhs()
  guard (try! @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(try! rhs.get(1, 0)),
    "-(k*q(t) + c*u(t))/m",
  )) else {
    fail("kane acceleration mismatch")
  }
  let a = (try! km.linearize(a_and_b=true)).0
  inspect(@symprint.to_string(try! a.get(0, 0)), content="0")
  inspect(@symprint.to_string(try! a.get(0, 1)), content="1")
  guard (try! @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(try! a.get(1, 0)),
    "-k/m",
  )) else {
    fail("kane linearized A(1,0) mismatch")
  }
  guard (try! @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(try! a.get(1, 1)),
    "-c/m",
  )) else {
    fail("kane linearized A(1,1) mismatch")
  }
}
