///|
fn control_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  context : String,
) -> Unit raise {
  let ours = @symprint.to_string(lhs)
  let equal = try! @sympy_physics.control_expr_equivalent(lhs, rhs)
  guard equal else { fail("\{context}: ours=\{ours}; oracle=\{rhs}") }
}

///|
fn control_assert_matrix_expr_equal(
  lhs : @symphysics.ExplicitMatrix,
  rhs : Array[String],
  rows : Int,
  cols : Int,
  context : String,
) -> Unit raise {
  guard lhs.height() == rows else {
    fail("\{context}: row mismatch ours=\{lhs.height()} oracle=\{rows}")
  }
  guard lhs.width() == cols else {
    fail("\{context}: col mismatch ours=\{lhs.width()} oracle=\{cols}")
  }
  let mut idx = 0
  for i in 0..<rows {
    for j in 0..<cols {
      try! control_assert_expr_equal(
        lhs.get(i, j),
        rhs[idx],
        "\{context}[\{idx}]",
      )
      idx += 1
    }
  }
}

///|
test "physics.control.routh_table: parity" {
  let z = @symcore.symbol("z")
  let b0 = @symcore.symbol("b0")
  let b1 = @symcore.symbol("b1")
  let b2 = @symcore.symbol("b2")
  let b3 = @symcore.symbol("b3")
  let b4 = @symcore.symbol("b4")
  let p1 = b4 * (z ^ @symcore.int(4)) +
    b3 * (z ^ @symcore.int(3)) +
    b2 * (z ^ @symcore.int(2)) +
    b1 * z +
    b0
  let t1 = routh_hurwitz(p1, z)
  control_assert_matrix_expr_equal(
    t1.matrix(),
    @sympy_physics.control_routh_table_matrix(p1, z),
    5,
    3,
    "generic table parity",
  )
  guard t1.zero_col_infos().is_empty() else {
    fail("generic zero_col_infos parity")
  }

  let p2 = (z ^ @symcore.int(4)) +
    (z ^ @symcore.int(3)) +
    @symcore.int(3) * (z ^ @symcore.int(2)) +
    @symcore.int(3) * z +
    @symcore.int(3)
  let t2 = routh_hurwitz(p2, z)
  control_assert_matrix_expr_equal(
    t2.matrix(),
    @sympy_physics.control_routh_table_matrix(p2, z),
    5,
    3,
    "zero-column parity",
  )
  guard t2.zero_col_infos().to_string() ==
    @sympy_physics.control_routh_zero_col_infos(p2, z) else {
    fail("zero_col_infos parity")
  }

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
    @sympy_physics.control_routh_table_matrix(p3, z),
    7,
    4,
    "zero-row parity",
  )
  guard t3.zero_row_case() ==
    (@sympy_physics.control_routh_zero_row_case(p3, z) == "True") else {
    fail("zero_row_case parity")
  }
  control_assert_expr_equal(
    t3.auxiliary_polynomials()[0],
    @sympy_physics.control_routh_auxiliary_expr(p3, z, 0),
    "auxiliary polynomial parity",
  )
}
