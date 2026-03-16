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

///|
test "matrices expressions block helpers" {
  let a = matrix_symbol("A", 1, 2)
  let b = matrix_symbol("B", 2, 1)
  let expr = matrix_expr_block_diag([a, b])
  assert_eq(try! expr.shape(), (3, 3))
  let env : Map[String, Matrix] = {}
  env["A"] = try! matrix([[@symcore.int(1), @symcore.int(2)]])
  env["B"] = try! matrix([[@symcore.int(3)], [@symcore.int(4)]])
  inspect(
    (try! expr.eval(env)).to_string(),
    content="Matrix([[1, 2, 0], [0, 0, 3], [0, 0, 4]])",
  )
}

///|
test "matrices expressions identity zero and block evaluation" {
  let a = matrix_symbol("A", 1, 1)
  let expr = matrix_expr_add([
    matrix_expr_block([[identity_expr(1), zero_matrix_expr(1, 1)], [a, a]]),
    zero_matrix_expr(2, 2),
  ])
  assert_eq(try! expr.shape(), (2, 2))
  let env : Map[String, Matrix] = {}
  env["A"] = try! matrix([[@symcore.int(5)]])
  inspect((try! expr.eval(env)).to_string(), content="Matrix([[1, 0], [5, 5]])")
}
