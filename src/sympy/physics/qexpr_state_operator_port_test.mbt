///|
test "physics.quantum.qexpr/state/operator: parity" {
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.pretty_string(qexpr([@symcore.int(0)]).as_expr()),
    ),
    "0",
    "QExpr str",
  )
  quantum_test_assert_string_equal(
    quantum_srepr_str(
      @symprint.pretty_string(
        qexpr([@symcore.int(0), @symcore.int(1)]).as_expr(),
      ),
    ),
    quantum_srepr_str("QExpr(0, 1)"),
    "QExpr srepr",
  )

  let k = ket([@symcore.Expr::Symbol("k")])
  let b = bra([@symcore.Expr::Symbol("b")])
  let t = time_dep_ket([@symcore.int(0)], time=@symcore.Expr::Symbol("t"))
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.pretty_string(k.as_expr())),
    "|k>",
    "Ket str",
  )
  quantum_test_assert_string_equal(
    quantum_srepr_str(@symprint.pretty_string(b.as_expr())),
    quantum_srepr_str("Bra(b)"),
    "Bra srepr",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.pretty_string(t.as_expr())),
    "|0;t>",
    "TimeDepKet str",
  )

  let a = operator([@symcore.Expr::Symbol("A")])
  let h = hermitian_operator([@symcore.Expr::Symbol("Hh")])
  let u = unitary_operator([@symcore.Expr::Symbol("Uu")])
  let id = identity_operator(dimension=@symcore.int(3))
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.pretty_string(a.as_expr())),
    "A",
    "Operator str",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.pretty_string(dagger(h.as_expr()))),
    "Hh",
    "Hermitian dagger",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.pretty_string(dagger(a.as_expr()))),
    quantum_eval_str("Dagger(Operator(A))"),
    "Operator dagger",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.pretty_string(dagger(u.as_expr()))),
    "Uu**(-1)",
    "Unitary dagger",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.pretty_string(id.as_expr())),
    "I",
    "IdentityOperator str",
  )
}

///|
test "physics.quantum.operator/state: default constructors parity" {
  quantum_test_assert_string_equal(
    operator([]).to_string(),
    quantum_eval_str("Operator()"),
    "Operator() default parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.pretty_string(ket([]).as_expr())),
    quantum_eval_str("Ket()"),
    "Ket() default parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.pretty_string(bra([]).as_expr())),
    quantum_eval_str("Bra()"),
    "Bra() default parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.pretty_string(time_dep_ket([]).as_expr())),
    quantum_eval_str("TimeDepKet()"),
    "TimeDepKet() default parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.pretty_string(time_dep_bra([]).as_expr())),
    quantum_eval_str("TimeDepBra()"),
    "TimeDepBra() default parity",
  )
}

///|
test "physics.quantum.operator/state: outer product parity" {
  let k1 = ket([@symcore.Expr::Symbol("k1")]).as_expr()
  let k2 = ket([@symcore.Expr::Symbol("k2")]).as_expr()
  let b1 = bra([@symcore.Expr::Symbol("b1")]).as_expr()
  let b2 = bra([@symcore.Expr::Symbol("b2")]).as_expr()

  quantum_test_assert_expr_equal(
    outer_product(@symcore.int(2) * k1, b1),
    "OuterProduct(2*Ket(k1), Bra(b1))",
    "outer product ket scalar parity",
  )
  quantum_test_assert_expr_equal(
    outer_product(k1, @symcore.int(3) * b1),
    "OuterProduct(Ket(k1), 3*Bra(b1))",
    "outer product bra scalar parity",
  )
  quantum_test_assert_expr_equal(
    outer_product(k1 + k2, b1),
    "OuterProduct(Ket(k1) + Ket(k2), Bra(b1))",
    "outer product ket sum parity",
  )
  quantum_test_assert_expr_equal(
    outer_product(k1, b1 + b2),
    "OuterProduct(Ket(k1), Bra(b1) + Bra(b2))",
    "outer product bra sum parity",
  )
  quantum_test_assert_expr_equal(
    outer_product(
      k1 + @symcore.int(2) * k2,
      @symcore.int(3) * b1 + @symcore.int(4) * b2,
    ),
    "OuterProduct(Ket(k1) + 2*Ket(k2), 3*Bra(b1) + 4*Bra(b2))",
    "outer product bilinear parity",
  )
}

///|
test "physics.quantum.operator/state: operator simplification parity" {
  let a = operator([@symcore.Expr::Symbol("A")]).as_expr()
  let u = unitary_operator([@symcore.Expr::Symbol("U")]).as_expr()
  let id3 = identity_operator(dimension=@symcore.int(3)).as_expr()

  quantum_test_assert_expr_equal(
    quantum_canonical_mul(
      @symcore.raw_mul([a, @symcore.raw_pow(a, @symcore.int(-1))]),
    ),
    "Operator(A)*Operator(A).inv()",
    "inverse cancellation parity",
  )
  quantum_test_assert_expr_equal(
    quantum_canonical_mul(@symcore.raw_mul([u, dagger(u)])),
    "UnitaryOperator(U)*Dagger(UnitaryOperator(U))",
    "unitary cancellation parity",
  )
  quantum_test_assert_string_equal(
    quantum_qapply_str("IdentityOperator(3)*Operator(A)"),
    quantum_eval_str(
      @symprint.pretty_string(qapply(@symcore.raw_mul([id3, a]))),
    ),
    "qapply left identity parity",
  )
  quantum_test_assert_string_equal(
    quantum_qapply_str("Operator(A)*IdentityOperator(3)"),
    quantum_eval_str(
      @symprint.pretty_string(qapply(@symcore.raw_mul([a, id3]))),
    ),
    "qapply right identity parity",
  )
  let represented_id = represent(id3)
  match represented_id {
    MatrixScalarValue::Matrix(matrix) =>
      quantum_test_assert_matrix_expr_equal(
        matrix,
        physics_eval_matrix("represent(IdentityOperator(3))"),
        3,
        3,
        "represent identity parity",
      )
    MatrixScalarValue::Scalar(value) =>
      fail(
        "represent identity parity: expected matrix, got \{@symprint.pretty_string(value)}",
      )
  }
}

///|
test "physics.quantum.operator/state: outer product trace parity" {
  let one = @symcore.int(1)
  let op = outer_product(jz_ket(one, one).as_expr(), jz_bra(one, one).as_expr())
  quantum_test_assert_string_equal(
    quantum_doit_str("Tr(OuterProduct(JzKet(1, 1), JzBra(1, 1)))"),
    quantum_eval_str(@symprint.pretty_string(tr_doit(tr(op)))),
    "trace outer product parity",
  )
}
