///|
fn add_as_roots_string(result : Result[RootVector, String]) -> String {
  match result {
    Ok(root) => vec_string(root)
    Err(msg) => msg
  }
}

///|
test "liealgebras root_system parity" {
  let rs = root_system_from_string("A3")
  assert_eq(
    roots_map_string(rs.simple_roots()),
    @sympy_lie.root_system_simple_roots_map_str("A3"),
  )
  assert_eq(rs.root_space(), @sympy_lie.root_system_root_space_str("A3"))
  assert_eq(
    matrix_rows_string(rs.cartan_matrix()),
    @sympy_lie.cartan_matrix_list_str("A3"),
  )
  assert_eq(rs.dynkin_diagram(), @sympy_lie.dynkin_diagram_str("A3"))
  assert_eq(
    vec_string(rs.add_simple_roots(1, 2)),
    @sympy_lie.root_system_add_simple_roots_list_str("A3", 1, 2),
  )
  assert_eq(
    roots_map_string(rs.all_roots()),
    @sympy_lie.root_system_all_roots_map_str("A3"),
  )
  let ours_add = add_as_roots_string(
    rs.add_as_roots(vec_from_ints([1, 0, -1, 0]), vec_from_ints([0, 0, 1, -1])),
  )
  let oracle_add = @sympy_lie.root_system_add_as_roots_str(
    "A3",
    [1, 0, -1, 0],
    [0, 0, 1, -1],
  )
  assert_eq(ours_add, oracle_add)
  let ours_fail = add_as_roots_string(
    rs.add_as_roots(vec_from_ints([1, -1, 0, 0]), vec_from_ints([0, 0, -1, 1])),
  )
  let oracle_fail = @sympy_lie.root_system_add_as_roots_str(
    "A3",
    [1, -1, 0, 0],
    [0, 0, -1, 1],
  )
  assert_eq(ours_fail, oracle_fail)
}
