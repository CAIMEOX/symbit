///|
test "matrices expressions shape and render" {
  let a = matrix_symbol("A", 2, 2)
  let b = matrix_symbol("B", 2, 2)
  let expr = matrix_expr_transpose(matrix_expr_mul([a, matrix_expr_inverse(b)]))
  assert_eq(expr.shape(), (2, 2))
  inspect(expr.to_string(), content="(B^-1.T * A.T)")
}

///|
test "matrices expressions evaluate with environment" {
  let a = matrix_symbol("A", 2, 2)
  let b = matrix_symbol("B", 2, 2)
  let expr = matrix_expr_add([
    matrix_expr_mul([a, b]),
    matrix_expr_pow(matrix_expr(eye(2)), 2),
  ])
  let env : Map[String, Matrix] = {}
  env["A"] = matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(0), @symcore.int(1)],
  ])
  env["B"] = matrix([
    [@symcore.int(2), @symcore.int(0)],
    [@symcore.int(1), @symcore.int(3)],
  ])
  inspect(expr.eval(env).to_string(), content="Matrix([[5, 6], [1, 4]])")
}

///|
test "matrices expressions power and transpose evaluation" {
  let a = matrix_symbol("A", 2, 2)
  let expr = matrix_expr_transpose(matrix_expr_pow(a, 2))
  let env : Map[String, Matrix] = {}
  env["A"] = matrix([
    [@symcore.int(1), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(1)],
  ])
  inspect(expr.eval(env).to_string(), content="Matrix([[1, 0], [2, 1]])")
}

///|
test "matrices expressions block helpers" {
  let a = matrix_symbol("A", 1, 2)
  let b = matrix_symbol("B", 2, 1)
  let expr = matrix_expr_block_diag([a, b])
  assert_eq(expr.shape(), (3, 3))
  let env : Map[String, Matrix] = {}
  env["A"] = matrix([[@symcore.int(1), @symcore.int(2)]])
  env["B"] = matrix([[@symcore.int(3)], [@symcore.int(4)]])
  inspect(
    expr.eval(env).to_string(),
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
  assert_eq(expr.shape(), (2, 2))
  let env : Map[String, Matrix] = {}
  env["A"] = matrix([[@symcore.int(5)]])
  inspect(expr.eval(env).to_string(), content="Matrix([[1, 0], [5, 5]])")
}

///|
test "matrices expressions matadd matmul and collapse helpers" {
  let a = matrix_symbol("A", 1, 1)
  let expr = mat_mul([identity_expr(1), mat_add([a, zero_matrix_expr(1, 1)])]).block_collapse()
  inspect(expr.to_string(), content="A")
  let block = block_diag_matrix_expr([
    identity_expr(1),
    block_diag_matrix_expr([a]),
  ]).block_collapse()
  inspect(block.to_string(), content="BlockDiag(Identity(1), A)")
  let env : Map[String, Matrix] = {}
  env["A"] = matrix([[@symcore.int(9)]])
  inspect(
    block.as_explicit(env).to_string(),
    content="Matrix([[1, 0], [0, 9]])",
  )
}

///|
test "matrices expressions symbolic block multiply collapse" {
  let a = matrix_symbol("A", 1, 1)
  let b = matrix_symbol("B", 1, 1)
  let c = matrix_symbol("C", 1, 1)
  let d = matrix_symbol("D", 1, 1)
  let left = block_matrix_expr([[a, b]])
  let right = block_matrix_expr([[c], [d]])
  let collapsed = mat_mul([left, right]).block_collapse()
  inspect(collapsed.to_string(), content="((A * C) + (B * D))")
}

///|
test "matrices expressions inverse and transpose simplify block forms" {
  let a = matrix_symbol("A", 1, 1)
  let b = matrix_symbol("B", 1, 1)
  inspect(
    matrix_expr_inverse(block_diag_matrix_expr([a, b])).to_string(),
    content="BlockDiag(A^-1, B^-1)",
  )
  inspect(
    matrix_expr_transpose(block_matrix_expr([[a, b]])).to_string(),
    content="Block([A.T], [B.T])",
  )
}

///|
test "matrices expressions collapse identity into block structures" {
  let a = matrix_symbol("A", 1, 1)
  let b = matrix_symbol("B", 2, 2)
  inspect(
    mat_add([identity_expr(3), block_diag_matrix_expr([a, b])])
    .block_collapse()
    .to_string(),
    content="BlockDiag((Identity(1) + A), (Identity(2) + B))",
  )
}

///|
test "matrices expressions collapse blockdiag and block multiplication symbolically" {
  let a = matrix_symbol("A", 1, 1)
  let b = matrix_symbol("B", 2, 2)
  let c = matrix_symbol("C", 1, 1)
  let d = matrix_symbol("D", 1, 2)
  let e = matrix_symbol("E", 2, 1)
  let f = matrix_symbol("F", 2, 2)
  inspect(
    mat_mul([
      block_diag_matrix_expr([a, b]),
      block_matrix_expr([[c, d], [e, f]]),
    ])
    .block_collapse()
    .to_string(),
    content="Block([(A * C), (A * D)], [(B * E), (B * F)])",
  )
  inspect(
    mat_mul([
      block_matrix_expr([[c, d], [e, f]]),
      block_diag_matrix_expr([a, b]),
    ])
    .block_collapse()
    .to_string(),
    content="Block([(C * A), (D * B)], [(E * A), (F * B)])",
  )
}

///|
test "matrices expressions rewrite inverse zero and power without explicit evaluation" {
  let a = matrix_symbol("A", 2, 2)
  let b = matrix_symbol("B", 2, 2)
  inspect(matrix_expr_pow(a, 0).to_string(), content="Identity(2)")
  inspect(
    matrix_expr_inverse(matrix_expr_transpose(mat_mul([a, b]))).to_string(),
    content="(A^-1.T * B^-1.T)",
  )
  inspect(
    mat_mul([a, zero_matrix_expr(2, 3)]).to_string(),
    content="ZeroMatrix(2, 3)",
  )
}

///|
test "matrices expressions matmul combines inverse pairs and powers" {
  let a = matrix_symbol("A", 2, 2)
  inspect(
    mat_mul([a, matrix_expr_inverse(a)]).to_string(),
    content="Identity(2)",
  )
  inspect(mat_mul([a, a]).to_string(), content="A^2")
  inspect(mat_mul([matrix_expr_pow(a, 2), a]).to_string(), content="A^3")
}

///|
test "matrices expressions matadd collapses blockdiag operands immediately" {
  let a = matrix_symbol("A", 1, 1)
  let b = matrix_symbol("B", 2, 2)
  inspect(
    mat_add([
      block_diag_matrix_expr([a, b]),
      block_diag_matrix_expr([identity_expr(1), identity_expr(2)]),
    ]).to_string(),
    content="BlockDiag((A + Identity(1)), (B + Identity(2)))",
  )
}
