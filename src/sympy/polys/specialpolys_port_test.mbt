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
fn special_port_poly_exprs(items : Array[Poly]) -> Array[String] {
  items.map(item => @symprint.pretty_string(item.to_expr()))
}

///|
fn special_port_dense_repr(p : DensePoly) -> String {
  match p {
    DensePoly::Coef(c) => c.to_string()
    DensePoly::Poly(items) => {
      let parts : Array[String] = Array::new()
      for item in items {
        parts.push(special_port_dense_repr(item))
      }
      let joined = parts.join(",")
      "[\{joined}]"
    }
  }
}

///|
fn special_port_dense_tuple_repr(
  item : (DensePoly, DensePoly, DensePoly),
) -> String {
  "(\{special_port_dense_repr(item.0)},\{special_port_dense_repr(item.1)},\{special_port_dense_repr(item.2)})"
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

///|
test "specialpolys: dense Fateman benchmark triples oracle parity" {
  assert_eq(
    special_port_dense_tuple_repr(
      @sympolys.dmp_fateman_poly_F_1(1, @sympolys.Domain::ZZ),
    ),
    dmp_fateman_poly_F_1(1),
  )
  assert_eq(
    special_port_dense_tuple_repr(
      @sympolys.dmp_fateman_poly_F_2(2, @sympolys.Domain::ZZ),
    ),
    dmp_fateman_poly_F_2(2),
  )
  assert_eq(
    special_port_dense_tuple_repr(
      @sympolys.dmp_fateman_poly_F_3(2, @sympolys.Domain::ZZ),
    ),
    dmp_fateman_poly_F_3(2),
  )
}

///|
test "specialpolys: Wang benchmark polynomial tuples oracle parity" {
  special_port_assert_tuple(
    special_port_poly_exprs(@sympolys.f_polys()),
    f_polys(),
  )
  special_port_assert_tuple(
    special_port_poly_exprs(@sympolys.w_polys()),
    w_polys(),
  )
}
