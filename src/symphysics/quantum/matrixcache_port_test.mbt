///|
test "physics.quantum.matrixcache: parity" {
  quantum_test_assert_matrix_expr_equal(
    quantum_matrix_cache.get_matrix("X"),
    @sympy_physics.quantum_matrixcache_matrix("X"),
    2,
    2,
    "matrixcache X parity",
  )
  quantum_test_assert_matrix_expr_equal(
    quantum_matrix_cache.get_matrix("H"),
    @sympy_physics.quantum_matrixcache_matrix("H"),
    2,
    2,
    "matrixcache H parity",
  )
  quantum_test_assert_matrix_expr_equal(
    quantum_matrix_cache.get_matrix("SWAP"),
    @sympy_physics.quantum_matrixcache_matrix("SWAP"),
    4,
    4,
    "matrixcache SWAP parity",
  )
}
