///|
fn list_string(items : Array[String]) -> String {
  if items.is_empty() {
    return "[]"
  }
  let joined = items.join(", ")
  "[\{joined}]"
}

///|
test "liealgebras weyl_group A3 parity" {
  let wg = weyl_group_from_string("A3")
  assert_eq(
    list_string(wg.generators()),
    @sympy_lie.weyl_group_generators_list_str("A3"),
  )
  assert_eq(
    wg.group_order().to_string(),
    @sympy_lie.weyl_group_group_order_str("A3"),
  )
  assert_eq(wg.group_name(), @sympy_lie.weyl_group_group_name_str("A3"))
  assert_eq(
    wg.coxeter_diagram(),
    @sympy_lie.weyl_group_coxeter_diagram_str("A3"),
  )
  assert_eq(
    wg.element_order("r1*r2*r3").to_string(),
    @sympy_lie.weyl_group_element_order_str("A3", "r1*r2*r3"),
  )
  assert_eq(
    wg.element_order("r1*r3*r2*r3").to_string(),
    @sympy_lie.weyl_group_element_order_str("A3", "r1*r3*r2*r3"),
  )
  assert_eq(
    matrix_rows_string(wg.matrix_form("r1*r2")),
    @sympy_lie.weyl_group_matrix_form_list_str("A3", "r1*r2"),
  )
}

///|
test "liealgebras weyl_group B5 parity" {
  let wg = weyl_group_from_string("B5")
  assert_eq(
    wg.group_order().to_string(),
    @sympy_lie.weyl_group_group_order_str("B5"),
  )
  assert_eq(
    wg.element_order("r1*r2*r4*r5").to_string(),
    @sympy_lie.weyl_group_element_order_str("B5", "r1*r2*r4*r5"),
  )
  assert_eq(
    wg.element_order("r1*r2*r1*r3*r5").to_string(),
    @sympy_lie.weyl_group_element_order_str("B5", "r1*r2*r1*r3*r5"),
  )
  assert_eq(
    matrix_rows_string(wg.matrix_form("r2*r3")),
    @sympy_lie.weyl_group_matrix_form_list_str("B5", "r2*r3"),
  )
}

///|
test "liealgebras weyl_group D5 parity" {
  let wg = weyl_group_from_string("D5")
  assert_eq(
    wg.element_order("r2*r3*r5").to_string(),
    @sympy_lie.weyl_group_element_order_str("D5", "r2*r3*r5"),
  )
  assert_eq(
    matrix_rows_string(wg.matrix_form("r2*r3*r5")),
    @sympy_lie.weyl_group_matrix_form_list_str("D5", "r2*r3*r5"),
  )
}

///|
test "liealgebras weyl_group G2 parity" {
  let wg = weyl_group_from_string("G2")
  assert_eq(
    wg.element_order("r1*r2*r1*r2").to_string(),
    @sympy_lie.weyl_group_element_order_str("G2", "r1*r2*r1*r2"),
  )
  assert_eq(
    wg.element_order("r2*r1*r1*r2").to_string(),
    @sympy_lie.weyl_group_element_order_str("G2", "r2*r1*r1*r2"),
  )
  assert_eq(
    matrix_rows_string(wg.matrix_form("r1*r2*r1*r2")),
    @sympy_lie.weyl_group_matrix_form_list_str("G2", "r1*r2*r1*r2"),
  )
}

///|
test "liealgebras weyl_group F4 parity" {
  let wg = weyl_group_from_string("F4")
  assert_eq(
    wg.element_order("r2*r3").to_string(),
    @sympy_lie.weyl_group_element_order_str("F4", "r2*r3"),
  )
  assert_eq(
    matrix_rows_string(wg.matrix_form("r2*r3")),
    @sympy_lie.weyl_group_matrix_form_list_str("F4", "r2*r3"),
  )
}

///|
test "liealgebras weyl_group E6 parity" {
  let wg = weyl_group_from_string("E6")
  assert_eq(
    wg.group_order().to_string(),
    @sympy_lie.weyl_group_group_order_str("E6"),
  )
}
