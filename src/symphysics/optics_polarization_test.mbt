///|
fn optics_matrix_assert_expr_equal(
  lhs : ExplicitMatrix,
  rhs : Array[String],
  context : String,
) -> Unit raise {
  let mut idx = 0
  for i in 0..<lhs.height() {
    for j in 0..<lhs.width() {
      let ours = @symprint.to_string(try! lhs.get(i, j))
      guard ours == rhs[idx] else {
        fail("\{context}[\{idx}]: ours=\{ours}; oracle=\{rhs[idx]}")
      }
      idx = idx + 1
    }
  }
}

///|
test "physics.optics.polarization: core constructors" {
  try! optics_matrix_assert_expr_equal(try! jones_vector(@symcore.int(0), @symcore.int(0)), ["1", "0"], "H")
  try! optics_matrix_assert_expr_equal(try! stokes_vector(@symcore.int(0), @symcore.int(0)), ["1", "1", "0", "0"], "stokes H")
  try! optics_matrix_assert_expr_equal(try! transmissive_filter(@symcore.int(1)), ["1", "0", "0", "1"], "transmissive")
  try! optics_matrix_assert_expr_equal(try! reflective_filter(@symcore.int(1)), ["1", "0", "0", "-1"], "reflective")
}
