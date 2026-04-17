///|
fn kane_port_matrix_entry_summary(
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
test "physics.mechanics parity kane spring mass damper" {
  let q = @symvector.dynamicsymbol("q")
  let u = @symvector.dynamicsymbol("u")
  let n = @symvector.reference_frame("PKN")
  let p = @symvector.point("PKP")
  p.set_vel(n, n.x().scale(u))
  let pa = particle(
    "PKPa",
    point=Some(p),
    mass=Some(@symcore.Expr::Symbol("m")),
  )
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
          (@symcore.Expr::Symbol("k") * q + @symcore.Expr::Symbol("c") * u),
        ),
      ),
    ]),
  )
  let prefix = "q,u=dynamicsymbols('q u'); N=ReferenceFrame('PKN'); P=Point('PKP'); P.set_vel(N, u*N.x); pa=Particle('PKPa', P, symbols('m')); KM=KanesMethod(N, [q], [u], [q.diff(t)-u]); KM.kanes_equations([pa], [(P, (-symbols('k')*q - symbols('c')*u)*N.x)]); "
  let oracle_mass = mechanics_summary(
    prefix + "[[str(x) for x in row] for row in KM.mass_matrix.tolist()]",
  )
  assert_eq(
    kane_port_matrix_entry_summary(km.mass_matrix()).replace(old=" ", new=""),
    oracle_mass.replace(old=" ", new=""),
  )
  assert_true(
    mechanics_expr_equal(
      @symprint.pretty_string(km.forcing().get(0, 0)),
      "-c*u(t) - k*q(t)",
    ),
  )
  let rhs = km.rhs()
  assert_true(
    mechanics_expr_equal(@symprint.pretty_string(rhs.get(0, 0)), "u(t)"),
  )
  assert_true(
    mechanics_expr_equal(
      @symprint.pretty_string(rhs.get(1, 0)),
      "-(k*q(t) + c*u(t))/m",
    ),
  )
  assert_true(
    mechanics_matrix_equal(
      @symphysics.explicit_matrix_rows_string(km.linearize(a_and_b=true).0),
      prefix + "KM.linearize(A_and_B=True)[0]",
    ),
  )
}
