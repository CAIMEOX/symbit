///|
test "liealgebras dynkin_diagram wrappers parity" {
  assert_eq(
    dynkin_diagram_from_string("A3"),
    dynkin_diagram_str("A3"),
  )
  assert_eq(
    dynkin_diagram_from_parts("B", 3),
    dynkin_diagram_str("B3"),
  )
  let ct = cartan_type_from_string("C3")
  assert_eq(dynkin_diagram(ct), dynkin_diagram_str("C3"))
}
