///|
test "physics.quantum.matrixcache: parity" {
  try! quantum_test_assert_matrix_expr_equal(
    try! quantum_matrix_cache.get_matrix("X"),
    try! @sympy_physics.quantum_matrixcache_matrix("X"),
    2,
    2,
    "matrixcache X parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! quantum_matrix_cache.get_matrix("H"),
    try! @sympy_physics.quantum_matrixcache_matrix("H"),
    2,
    2,
    "matrixcache H parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! quantum_matrix_cache.get_matrix("SWAP"),
    try! @sympy_physics.quantum_matrixcache_matrix("SWAP"),
    4,
    4,
    "matrixcache SWAP parity",
  )
}
