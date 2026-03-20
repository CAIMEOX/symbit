///|
fn py_expr(expr : Expr) -> String {
  @symprint.to_string(expr)
}

///|
fn py_matrix_expr(m : Matrix) -> String {
  let rows : Array[String] = []
  for row in m.to_list() {
    rows.push("[" + row.map(py_expr).join(", ") + "]")
  }
  "sympy.Matrix([" + rows.join(", ") + "])"
}

///|
fn py_matrix_list_text(code : String) -> String raise {
  @sympy_utilities.utilities_eval_str(
    "'[' + ', '.join('[' + ', '.join(sympy.sstr(v) for v in row) + ']' for row in (" +
    code +
    ").tolist()) + ']'",
  )
}

///|
fn py_list_text(code : String) -> String raise {
  @sympy_utilities.utilities_eval_str(code)
}

///|
fn local_matrix_list_text(m : Matrix) -> String {
  let rows : Array[String] = []
  for row in m.to_list() {
    rows.push("[" + row.map(@symprint.to_string).join(", ") + "]")
  }
  "[" + rows.join(", ") + "]"
}

///|
test "matrices parity basic arithmetic" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ])
  let b = matrix([
    [@symcore.int(5), @symcore.int(6)],
    [@symcore.int(7), @symcore.int(8)],
  ])
  assert_eq(
    local_matrix_list_text(a + b),
    py_matrix_list_text(py_matrix_expr(a) + " + " + py_matrix_expr(b)),
  )
  assert_eq(
    local_matrix_list_text(a * b),
    py_matrix_list_text(py_matrix_expr(a) + " * " + py_matrix_expr(b)),
  )
  assert_eq(
    local_matrix_list_text(a.transpose()),
    py_matrix_list_text(py_matrix_expr(a) + ".T"),
  )
}

///|
test "matrices parity determinant inverse rref" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ])
  assert_eq(
    @symprint.to_string(a.det()),
    py_list_text("sympy.sstr(" + py_matrix_expr(a) + ".det())"),
  )
  assert_eq(
    local_matrix_list_text(a.inv()),
    py_matrix_list_text(py_matrix_expr(a) + ".inv()"),
  )
  let b = matrix([
    [@symcore.int(1), @symcore.int(2), @symcore.int(3)],
    [@symcore.int(2), @symcore.int(4), @symcore.int(6)],
  ])
  assert_eq(
    local_matrix_list_text(b.rref().0),
    py_matrix_list_text(py_matrix_expr(b) + ".rref()[0]"),
  )
}

///|
test "matrices parity structural helpers" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ])
  let row = matrix([[@symcore.int(9), @symcore.int(8)]])
  let col = matrix([[@symcore.int(7)], [@symcore.int(6)]])
  assert_eq(
    local_matrix_list_text(a.row_join(row.transpose())),
    py_matrix_list_text(
      py_matrix_expr(a) + ".row_join(" + py_matrix_expr(row.transpose()) + ")",
    ),
  )
  assert_eq(
    local_matrix_list_text(a.col_join(row)),
    py_matrix_list_text(
      py_matrix_expr(a) + ".col_join(" + py_matrix_expr(row) + ")",
    ),
  )
  assert_eq(
    local_matrix_list_text(a.row_insert(1, row)),
    py_matrix_list_text(
      py_matrix_expr(a) + ".row_insert(1, " + py_matrix_expr(row) + ")",
    ),
  )
  assert_eq(
    local_matrix_list_text(a.col_insert(1, col)),
    py_matrix_list_text(
      py_matrix_expr(a) + ".col_insert(1, " + py_matrix_expr(col) + ")",
    ),
  )
}

///|
test "matrices parity adjugate and echelon" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(2), @symcore.int(3)],
    [@symcore.int(0), @symcore.int(4), @symcore.int(5)],
    [@symcore.int(1), @symcore.int(0), @symcore.int(6)],
  ])
  assert_eq(
    local_matrix_list_text(a.adjugate()),
    py_matrix_list_text(py_matrix_expr(a) + ".adjugate()"),
  )
  assert_eq(
    local_matrix_list_text(a.echelon_form()),
    py_matrix_list_text(py_matrix_expr(a) + ".echelon_form()"),
  )
}
