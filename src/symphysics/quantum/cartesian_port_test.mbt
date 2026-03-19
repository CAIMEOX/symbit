///|
fn quantum_port_scalar_repr(
  value : MatrixScalarValue,
  context : String,
) -> @symcore.Expr raise {
  match value {
    MatrixScalarValue::Scalar(expr) => expr
    MatrixScalarValue::Matrix(_) =>
      fail("\{context}: expected scalar representation")
  }
}

///|
test "physics.quantum.cartesian: parity" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let px = @symcore.symbol("px")
  let py = @symcore.symbol("py")

  quantum_test_assert_string_equal(
    @sympy_physics.quantum_qapply_str("XOp()*XKet(x)"),
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(qapply(@symcore.raw_mul([x_op(), x_ket(position=x)]))),
    ),
    "XOp qapply parity",
  )
  quantum_test_assert_expr_equal(
    inner_product(x_bra(position=y), x_ket(position=x)),
    @sympy_physics.quantum_doit_str("XBra(y)*XKet(x)"),
    "XBra/XKet parity",
  )
  quantum_test_assert_expr_equal(
    inner_product(px_bra(momentum=px), x_ket(position=x)),
    @sympy_physics.quantum_doit_str("PxBra(px)*XKet(x)"),
    "PxBra/XKet parity",
  )
  quantum_test_assert_expr_equal(
    quantum_port_scalar_repr(
      represent(px_ket(momentum=py), basis=Some(x_op())),
      "represent PxKet",
    ),
    @sympy_physics.quantum_represent_str("PxKet(py)", basis=Some("XOp()")),
    "represent PxKet parity",
  )
  quantum_test_assert_expr_equal(
    quantum_port_scalar_repr(
      represent(px_op(), basis=Some(x_op())),
      "represent PxOp",
    ),
    @sympy_physics.quantum_represent_str("PxOp()", basis=Some("XOp()")),
    "represent PxOp parity",
  )
}
