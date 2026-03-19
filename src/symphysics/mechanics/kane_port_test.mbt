///|
fn kane_port_matrix_entry_summary(
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
test "physics.mechanics parity kane spring mass damper" {
  let q = @symvector.dynamicsymbol("q")
  let u = @symvector.dynamicsymbol("u")
  let n = @symvector.reference_frame("PKN")
  let p = @symvector.point("PKP")
  p.set_vel(n, n.x().scale(u))
  let pa = particle("PKPa", point=Some(p), mass=Some(@symcore.symbol("m")))
  let km = kanes_method(n, [q], [u], [
    @symcalculus.diff(q, @symvector.dynamicsymbols_t) - u,
  ])
  ignore(
    km.kanes_equations([pa.as_bodylike()], [
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
  let prefix = "q,u=dynamicsymbols('q u'); N=ReferenceFrame('PKN'); P=Point('PKP'); P.set_vel(N, u*N.x); pa=Particle('PKPa', P, symbols('m')); KM=KanesMethod(N, [q], [u], [q.diff(t)-u]); KM.kanes_equations([pa], [(P, (-symbols('k')*q - symbols('c')*u)*N.x)]); "
  let oracle_mass = @sympy_physics.mechanics_summary(
    prefix + "[[str(x) for x in row] for row in KM.mass_matrix.tolist()]",
  )
  guard kane_port_matrix_entry_summary(km.mass_matrix()).replace(
      old=" ",
      new="",
    ) ==
    oracle_mass.replace(old=" ", new="") else {
    fail("kane mass matrix parity mismatch")
  }
  guard @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(km.forcing().get(0, 0)),
    "-c*u(t) - k*q(t)",
  ) else {
    fail("kane forcing parity mismatch")
  }
  let rhs = km.rhs()
  guard @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(rhs.get(0, 0)),
    "u(t)",
  ) else {
    fail("kane rhs first entry mismatch")
  }
  guard @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(rhs.get(1, 0)),
    "-(k*q(t) + c*u(t))/m",
  ) else {
    fail("kane rhs acceleration mismatch")
  }
  guard @sympy_physics.mechanics_matrix_equal(
    @symphysics.explicit_matrix_rows_string(km.linearize(a_and_b=true).0),
    prefix + "KM.linearize(A_and_B=True)[0]",
  ) else {
    fail("kane linearize parity mismatch")
  }
}
