///|
fn quantum_scalar_repr(
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
test "physics.quantum.cartesian: local qapply, overlaps, and basis representation" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let px = @symcore.Expr::Symbol("px")
  let py = @symcore.Expr::Symbol("py")
  let ket_x = x_ket(position=x)
  let ket_px = px_ket(momentum=px)

  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([x_op(), ket_x])),
    "x*XKet(x)",
    "XOp acts on position ket",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([px_op(), ket_px])),
    "px*PxKet(px)",
    "PxOp acts on momentum ket",
  )
  quantum_test_assert_expr_equal(
    inner_product(x_bra(position=y), ket_x),
    "DiracDelta(x - y)",
    "<y|x>",
  )
  quantum_test_assert_expr_equal(
    inner_product(px_bra(momentum=py), ket_px),
    "DiracDelta(px - py)",
    "<py|px>",
  )
  quantum_test_assert_expr_equal(
    inner_product(px_bra(momentum=px), ket_x),
    "exp(-I*x*px/hbar)/sqrt(2*pi*hbar)",
    "<px|x>",
  )

  let pos3 = position_ket_3d(x~, y=@symcore.Expr::Symbol("y"), z=@symcore.Expr::Symbol("z"))
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([x_op(), pos3])),
    "x*PositionKet3D(x, y, z)",
    "XOp acts on 3d position ket",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([y_op(), pos3])),
    "y*PositionKet3D(x, y, z)",
    "YOp acts on 3d position ket",
  )

  quantum_test_assert_expr_equal(
    quantum_scalar_repr(represent(x_ket(position=y)), "represent XKet"),
    "DiracDelta(x_1 - y)",
    "represent XKet in x basis",
  )
  quantum_test_assert_expr_equal(
    quantum_scalar_repr(
      represent(px_ket(momentum=py), basis=Some(x_op())),
      "represent PxKet",
    ),
    "exp(I*x_1*py/hbar)/sqrt(2*pi*hbar)",
    "represent PxKet in x basis",
  )
  quantum_test_assert_expr_equal(
    quantum_scalar_repr(
      represent(px_op(), basis=Some(x_op())),
      "represent PxOp",
    ),
    "-I*hbar*DiracDelta(x_1 - x_2)*x_1",
    "represent PxOp in x basis",
  )
}
