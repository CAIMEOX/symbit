///|
test "liealgebras type A parity" {
  let ct = cartan_type_from_string("A3")
  assert_eq(ct.dimension().to_string(), cartan_type_dimension_str("A3"))
  assert_eq(ct.basis().to_string(), cartan_type_basis_str("A3"))
  assert_eq(ct.roots().to_string(), cartan_type_roots_str("A3"))
  assert_eq(
    vec_string(ct.simple_root(1)),
    cartan_type_simple_root_list_str("A3", 1),
  )
  assert_eq(
    vec_string(ct.highest_root()),
    cartan_type_highest_root_list_str("A3"),
  )
  assert_eq(ct.lie_algebra(), cartan_type_lie_algebra_str("A3"))
  assert_eq(ct.dynkin_diagram(), dynkin_diagram_str("A3"))
  assert_eq(
    roots_map_string(ct.positive_roots()),
    cartan_type_positive_roots_map_str("A3"),
  )
}

///|
test "liealgebras type B parity" {
  let ct = cartan_type_from_string("B3")
  assert_eq(ct.dimension().to_string(), cartan_type_dimension_str("B3"))
  assert_eq(ct.basis().to_string(), cartan_type_basis_str("B3"))
  assert_eq(ct.roots().to_string(), cartan_type_roots_str("B3"))
  assert_eq(
    vec_string(ct.simple_root(3)),
    cartan_type_simple_root_list_str("B3", 3),
  )
  assert_eq(ct.lie_algebra(), cartan_type_lie_algebra_str("B3"))
  assert_eq(ct.dynkin_diagram(), dynkin_diagram_str("B3"))
  assert_eq(
    roots_map_string(ct.positive_roots()),
    cartan_type_positive_roots_map_str("B3"),
  )
}

///|
test "liealgebras type C parity" {
  let ct = cartan_type_from_string("C4")
  assert_eq(ct.dimension().to_string(), cartan_type_dimension_str("C4"))
  assert_eq(ct.basis().to_string(), cartan_type_basis_str("C4"))
  assert_eq(ct.roots().to_string(), cartan_type_roots_str("C4"))
  assert_eq(
    vec_string(ct.simple_root(4)),
    cartan_type_simple_root_list_str("C4", 4),
  )
  assert_eq(ct.lie_algebra(), cartan_type_lie_algebra_str("C4"))
  assert_eq(ct.dynkin_diagram(), dynkin_diagram_str("C4"))
  assert_eq(
    roots_map_string(ct.positive_roots()),
    cartan_type_positive_roots_map_str("C4"),
  )
}

///|
test "liealgebras type D parity" {
  let ct = cartan_type_from_string("D4")
  assert_eq(ct.basis().to_string(), cartan_type_basis_str("D4"))
  assert_eq(ct.roots().to_string(), cartan_type_roots_str("D4"))
  assert_eq(
    vec_string(ct.simple_root(3)),
    cartan_type_simple_root_list_str("D4", 3),
  )
  assert_eq(ct.lie_algebra(), cartan_type_lie_algebra_str("D4"))
  assert_eq(ct.dynkin_diagram(), dynkin_diagram_str("D4"))
  assert_eq(
    roots_map_string(ct.positive_roots()),
    cartan_type_positive_roots_map_str("D4"),
  )
}

///|
test "liealgebras type E parity" {
  let ct = cartan_type_from_string("E6")
  assert_eq(ct.dimension().to_string(), cartan_type_dimension_str("E6"))
  assert_eq(ct.basis().to_string(), cartan_type_basis_str("E6"))
  assert_eq(ct.roots().to_string(), cartan_type_roots_str("E6"))
  assert_eq(
    vec_string(ct.simple_root(6)),
    cartan_type_simple_root_list_str("E6", 6),
  )
  assert_eq(ct.dynkin_diagram(), dynkin_diagram_str("E6"))
  assert_eq(
    roots_map_string(ct.positive_roots()),
    cartan_type_positive_roots_map_str("E6"),
  )
}

///|
test "liealgebras type F parity" {
  let ct = cartan_type_from_string("F4")
  assert_eq(ct.dimension().to_string(), cartan_type_dimension_str("F4"))
  assert_eq(ct.basis().to_string(), cartan_type_basis_str("F4"))
  assert_eq(ct.roots().to_string(), cartan_type_roots_str("F4"))
  assert_eq(
    vec_string(ct.simple_root(4)),
    cartan_type_simple_root_list_str("F4", 4),
  )
  assert_eq(ct.dynkin_diagram(), dynkin_diagram_str("F4"))
  assert_eq(
    roots_map_string(ct.positive_roots()),
    cartan_type_positive_roots_map_str("F4"),
  )
}

///|
test "liealgebras type G parity" {
  let ct = cartan_type_from_string("G2")
  assert_eq(ct.dimension().to_string(), cartan_type_dimension_str("G2"))
  assert_eq(ct.basis().to_string(), cartan_type_basis_str("G2"))
  assert_eq(ct.roots().to_string(), cartan_type_roots_str("G2"))
  assert_eq(
    vec_string(ct.simple_root(2)),
    cartan_type_simple_root_list_str("G2", 2),
  )
  assert_eq(ct.dynkin_diagram(), dynkin_diagram_str("G2"))
  assert_eq(
    roots_map_string(ct.positive_roots()),
    cartan_type_positive_roots_map_str("G2"),
  )
}
