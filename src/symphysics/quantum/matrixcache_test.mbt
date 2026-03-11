///|
test "physics.quantum.matrixcache: local cache contents" {
  try! quantum_test_assert_matrix_expr_equal(
    try! quantum_matrix_cache.get_matrix("X"),
    ["0", "1", "1", "0"],
    2,
    2,
    "matrixcache X",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! quantum_matrix_cache.get_matrix("H"),
    ["2**(-1/2)", "2**(-1/2)", "2**(-1/2)", "-2**(-1/2)"],
    2,
    2,
    "matrixcache H",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! quantum_matrix_cache.get_matrix("SWAP"),
    ["1", "0", "0", "0", "0", "0", "1", "0", "0", "1", "0", "0", "0", "0", "0", "1"],
    4,
    4,
    "matrixcache SWAP",
  )

  let cache = matrix_cache()
  cache.cache_matrix("custom", @symphysics.explicit_matrix_from_rows([
    [@symcore.int(2)],
  ]))
  try! quantum_test_assert_matrix_expr_equal(
    try! cache.get_matrix("custom"),
    ["2"],
    1,
    1,
    "matrixcache custom",
  )
}
