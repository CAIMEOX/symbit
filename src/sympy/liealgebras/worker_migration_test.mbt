///|
test "liealgebras worker preserves formatted and structured results" {
  assert_eq(cartan_type_rank_str("A2"), "2")
  assert_eq(cartan_matrix_list_str("A2"), "[[2, -1], [-1, 2]]")
  assert_eq(
    cartan_type_positive_roots_map_str("A2"),
    "{1: [1, -1, 0], 2: [1, 0, -1], 3: [0, 1, -1]}",
  )
  assert_eq(
    root_system_add_as_roots_str("A3", [1, 0, -1, 0], [0, 0, 1, -1]),
    "[1, 0, 0, -1]",
  )
  assert_eq(weyl_group_element_order_str("A3", "r1*r2"), "3")
}

///|
test "liealgebras worker treats quoted input as data and recovers after errors" {
  let rejected_type = try {
    cartan_type_rank_str("A2'); __import__('os').environ['X']='bad'; ('A2")
    |> ignore
    false
  } catch {
    _ => true
  }
  let rejected_element = try {
    weyl_group_element_order_str("A3", "r1*'quoted\\nvalue'") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected_type)
  assert_true(rejected_element)
  assert_eq(cartan_type_rank_str("A2"), "2")
  assert_eq(weyl_group_element_order_str("A3", "r1*r2"), "3")
}
