///|
test "matrices expressions shape and render" {
  let a = matrix_symbol("A", 2, 2)
  let b = matrix_symbol("B", 2, 2)
  let expr = matrix_expr_transpose(matrix_expr_mul([a, matrix_expr_inverse(b)]))
  assert_eq(try! expr.shape(), (2, 2))
  inspect(expr.to_string(), content="(A * B^-1).T")
}

///|
test "matrices expressions evaluate with environment" {
  let a = matrix_symbol("A", 2, 2)
  let b = matrix_symbol("B", 2, 2)
  let expr = matrix_expr_add([
    matrix_expr_mul([a, b]),
    matrix_expr_pow(matrix_expr(try! eye(2)), 2),
  ])
  let env : Map[String, Matrix] = {}
  env["A"] = try! matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(0), @symcore.int(1)],
  ])
  env["B"] = try! matrix([
    [@symcore.int(2), @symcore.int(0)],
    [@symcore.int(1), @symcore.int(3)],
  ])
  inspect((try! expr.eval(env)).to_string(), content="Matrix([[5, 6], [1, 4]])")
}

///|
test "matrices expressions power and transpose evaluation" {
  let a = matrix_symbol("A", 2, 2)
  let expr = matrix_expr_transpose(matrix_expr_pow(a, 2))
  let env : Map[String, Matrix] = {}
  env["A"] = try! matrix([
    [@symcore.int(1), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(1)],
  ])
  inspect((try! expr.eval(env)).to_string(), content="Matrix([[1, 0], [2, 1]])")
}
