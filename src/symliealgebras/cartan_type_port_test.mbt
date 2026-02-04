///|
test "liealgebras cartan_type and cartan_matrix parity" {
  let ct_a2 = cartan_type_from_string("A2")
  assert_eq(ct_a2.rank().to_string(), @sympy_lie.cartan_type_rank_str("A2"))
  assert_eq(ct_a2.series(), @sympy_lie.cartan_type_series_str("A2"))
  let mat_a2 = cartan_matrix_from_string("A2")
  let ours_a2 = matrix_rows_string(mat_a2)
  let oracle_a2 = @sympy_lie.cartan_matrix_list_str("A2")
  assert_eq(ours_a2, oracle_a2)
  let mat_c3 = cartan_matrix_from_string("C3")
  let ours_c3 = matrix_rows_string(mat_c3)
  let oracle_c3 = @sympy_lie.cartan_matrix_list_str("C3")
  assert_eq(ours_c3, oracle_c3)
}
