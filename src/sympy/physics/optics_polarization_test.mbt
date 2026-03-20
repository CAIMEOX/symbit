///|
fn optics_matrix_assert_expr_equal(
  lhs : ExplicitMatrix,
  rhs : Array[String],
  _context : String,
) -> Unit raise {
  let mut idx = 0
  for i in 0..<lhs.height() {
    for j in 0..<lhs.width() {
      let ours = @symprint.to_string(lhs.get(i, j))
      assert_true((expr_equal(ours, rhs[idx])))
      idx = idx + 1
    }
  }
}

///|
test "physics.optics.polarization: core constructors" {
  optics_matrix_assert_expr_equal(
    jones_vector(@symcore.int(0), @symcore.int(0)),
    ["1", "0"],
    "H",
  )
  optics_matrix_assert_expr_equal(
    stokes_vector(@symcore.int(0), @symcore.int(0)),
    ["1", "1", "0", "0"],
    "stokes H",
  )
  optics_matrix_assert_expr_equal(
    transmissive_filter(@symcore.int(1)),
    ["1", "0", "0", "1"],
    "transmissive",
  )
  optics_matrix_assert_expr_equal(
    reflective_filter(@symcore.int(1)),
    ["1", "0", "0", "-1"],
    "reflective",
  )
  optics_matrix_assert_expr_equal(
    mueller_matrix(linear_polarizer()),
    [
      "1/2", "1/2", "0", "0", "1/2", "1/2", "0", "0", "0", "0", "0", "0", "0", "0",
      "0", "0",
    ],
    "mueller linear polarizer theta=0",
  )
}
