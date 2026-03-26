///|
fn control_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  _context : String,
) -> Unit raise {
  let equal = control_expr_equivalent(lhs, rhs)
  assert_true(equal)
}

///|
fn control_assert_matrix_expr_equal(
  lhs : @symphysics.ExplicitMatrix,
  rhs : Array[String],
  rows : Int,
  cols : Int,
  _context : String,
) -> Unit raise {
  assert_eq(lhs.height(), rows)
  assert_eq(lhs.width(), cols)
  let mut idx = 0
  for i in 0..<rows {
    for j in 0..<cols {
      control_assert_expr_equal(lhs.get(i, j), rhs[idx], "\{_context}[\{idx}]")
      idx += 1
    }
  }
}

///|
test "physics.control.routh_table: parity" {
  let z = @symcore.Expr::Symbol("z")
  let b0 = @symcore.Expr::Symbol("b0")
  let b1 = @symcore.Expr::Symbol("b1")
  let b2 = @symcore.Expr::Symbol("b2")
  let b3 = @symcore.Expr::Symbol("b3")
  let b4 = @symcore.Expr::Symbol("b4")
  let p1 = b4 * (z ^ @symcore.int(4)) +
    b3 * (z ^ @symcore.int(3)) +
    b2 * (z ^ @symcore.int(2)) +
    b1 * z +
    b0
  let t1 = routh_hurwitz(p1, z)
  control_assert_matrix_expr_equal(
    t1.matrix(),
    control_routh_table_matrix(p1, z),
    5,
    3,
    "generic table parity",
  )
  assert_true(t1.zero_col_infos().is_empty())

  let p2 = (z ^ @symcore.int(4)) +
    (z ^ @symcore.int(3)) +
    @symcore.int(3) * (z ^ @symcore.int(2)) +
    @symcore.int(3) * z +
    @symcore.int(3)
  let t2 = routh_hurwitz(p2, z)
  control_assert_matrix_expr_equal(
    t2.matrix(),
    control_routh_table_matrix(p2, z),
    5,
    3,
    "zero-column parity",
  )
  assert_true(
    t2.zero_col_infos().to_string() == control_routh_zero_col_infos(p2, z),
  )

  let p3 = (z ^ @symcore.int(6)) +
    @symcore.int(2) * (z ^ @symcore.int(5)) +
    @symcore.int(8) * (z ^ @symcore.int(4)) +
    @symcore.int(12) * (z ^ @symcore.int(3)) +
    @symcore.int(20) * (z ^ @symcore.int(2)) +
    @symcore.int(16) * z +
    @symcore.int(16)
  let t3 = routh_hurwitz(p3, z)
  control_assert_matrix_expr_equal(
    t3.matrix(),
    control_routh_table_matrix(p3, z),
    7,
    4,
    "zero-row parity",
  )
  assert_true(
    t3.zero_row_case() == (control_routh_zero_row_case(p3, z) == "True"),
  )
  control_assert_expr_equal(
    t3.auxiliary_polynomials()[0],
    control_routh_auxiliary_expr(p3, z, 0),
    "auxiliary polynomial parity",
  )
}
