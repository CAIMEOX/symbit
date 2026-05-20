///|
fn special_port_tuple_exprs(item : (Poly, Poly, Poly)) -> Array[String] {
  [
    @symprint.pretty_string(item.0.to_expr()),
    @symprint.pretty_string(item.1.to_expr()),
    @symprint.pretty_string(item.2.to_expr()),
  ]
}

///|
fn special_port_assert_tuple(
  ours : Array[String],
  oracle : Array[String],
) -> Unit raise {
  assert_eq(ours.length(), oracle.length())
  for i in 0..<ours.length() {
    assert_true(expr_equal(ours[i], oracle[i]))
  }
}

///|
test "specialpolys: Fateman benchmark polynomial triples oracle parity" {
  special_port_assert_tuple(
    special_port_tuple_exprs(@sympolys.fateman_poly_F_1(1)),
    fateman_poly_F_1(1),
  )
  special_port_assert_tuple(
    special_port_tuple_exprs(@sympolys.fateman_poly_F_2(2)),
    fateman_poly_F_2(2),
  )
  special_port_assert_tuple(
    special_port_tuple_exprs(@sympolys.fateman_poly_F_3(2)),
    fateman_poly_F_3(2),
  )
}
