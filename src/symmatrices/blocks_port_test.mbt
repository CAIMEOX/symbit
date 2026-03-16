///|
test "matrices parity block helpers" {
  let a = try! matrix([[@symcore.int(1), @symcore.int(2)]])
  let b = try! matrix([[@symcore.int(3)], [@symcore.int(4)]])
  assert_eq(
    local_matrix_list_text(try! block_diag([a, b])),
    try! py_matrix_list_text(
      "sympy.diag(" + py_matrix_expr(a) + ", " + py_matrix_expr(b) + ")",
    ),
  )
  let c = try! matrix([[@symcore.int(5), @symcore.int(6)]])
  let d = try! matrix([[@symcore.int(3)]])
  let e = try! matrix([[@symcore.int(7)]])
  assert_eq(
    local_matrix_list_text(try! block_matrix([[a, d], [c, e]])),
    try! py_matrix_list_text(
      "sympy.BlockMatrix([[" +
      py_matrix_expr(a) +
      ", " +
      py_matrix_expr(d) +
      "], [" +
      py_matrix_expr(c) +
      ", " +
      py_matrix_expr(e) +
      "]]).as_explicit()",
    ),
  )
}
