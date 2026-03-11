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
      guard ours == rhs[idx] else {
        fail("\{context}[\{idx}]: ours=\{ours}; oracle=\{rhs[idx]}")
      }
      idx = idx + 1
    }
  }
}

///|
test "physics.optics.polarization: parity" {
  try! optics_matrix_assert_expr_parity(
    try! jones_vector(@symcore.int(0), @symcore.int(0)),
    try! @sympy_physics.optics_polarization_matrix(
      "jones_vector",
      [@symcore.int(0), @symcore.int(0)],
    ),
    "jones_vector parity",
  )
  try! optics_matrix_assert_expr_parity(
    try! stokes_vector(@symcore.int(0), @symcore.int(0)),
    try! @sympy_physics.optics_polarization_matrix(
      "stokes_vector",
      [@symcore.int(0), @symcore.int(0)],
    ),
    "stokes_vector parity",
  )
}
