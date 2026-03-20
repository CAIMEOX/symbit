///|
fn py_matrix_list_text2(code : String) -> String raise {
  @sympy_utilities.utilities_eval_str(
    "'[' + ', '.join('[' + ', '.join(sympy.sstr(v) for v in row) + ']' for row in (" +
    code +
    ").tolist()) + ']'",
  )
}

///|
fn py_list_text2(code : String) -> String raise {
  @sympy_utilities.utilities_eval_str(code)
}

///|
fn local_matrix_list_text2(m : Matrix) -> String {
  let rows : Array[String] = []
  for row in m.to_list() {
    rows.push("[" + row.map(@symprint.to_string).join(", ") + "]")
  }
  "[" + rows.join(", ") + "]"
}

///|
fn normalize_matrix_text(text : String) -> String {
  text.replace(old="-1*", new="-")
}

///|
test "matrices parity jordan and rotation helpers" {
  let lam = @symcore.symbol("lam")
  let theta = @symcore.symbol("theta")
  let local_jordan = jordan_cell(lam, 3)
  let local_rot = rot_axis3(theta)
  assert_eq(
    local_matrix_list_text2(local_jordan),
    py_matrix_list_text2("sympy.Matrix.jordan_block(3, sympy.Symbol('lam'))"),
  )
  assert_eq(
    normalize_matrix_text(local_matrix_list_text2(local_rot)),
    normalize_matrix_text(
      py_matrix_list_text2("sympy.rot_axis3(sympy.Symbol('theta'))"),
    ),
  )
}

///|
test "matrices parity hessian and wronskian" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let f = (x ^ @symcore.int(2)) + x * y + (y ^ @symcore.int(2))
  assert_eq(
    local_matrix_list_text2(hessian(f, [x, y])),
    py_matrix_list_text2(
      "(lambda x, y: sympy.hessian(x**2 + x*y + y**2, (x, y)))(sympy.Symbol('x'), sympy.Symbol('y'))",
    ),
  )
  assert_eq(
    @symprint.to_string(wronskian([x, x ^ @symcore.int(2)], x)),
    py_list_text2(
      "(lambda x: sympy.sstr(sympy.wronskian([x, x**2], x)))(sympy.Symbol('x'))",
    ),
  )
}
