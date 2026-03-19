///|
fn optics_matrix_assert_expr_parity(
  lhs : ExplicitMatrix,
  rhs : Array[String],
  context : String,
) -> Unit raise {
  let mut idx = 0
  for i in 0..<lhs.height() {
    for j in 0..<lhs.width() {
      let ours = @symprint.to_string(try! lhs.get(i, j))
      assert_true((try! @sympy_physics.expr_equal(ours, rhs[idx])))
      idx = idx + 1
    }
  }
}

///|
test "physics.optics.polarization: parity" {
  optics_matrix_assert_expr_parity(
    jones_vector(@symcore.int(0), @symcore.int(0)),
    @sympy_physics.optics_polarization_matrix("jones_vector", [
      @symcore.int(0),
      @symcore.int(0),
    ]),
    "jones_vector parity",
  )
  optics_matrix_assert_expr_parity(
    stokes_vector(@symcore.int(0), @symcore.int(0)),
    @sympy_physics.optics_polarization_matrix("stokes_vector", [
      @symcore.int(0),
      @symcore.int(0),
    ]),
    "stokes_vector parity",
  )
  optics_matrix_assert_expr_parity(
    mueller_matrix(linear_polarizer(theta=@symcore.symbol("theta"))),
    @sympy_physics.physics_eval_matrix(
      "mueller_matrix(linear_polarizer(theta))",
    ),
    "mueller_matrix parity",
  )
}
