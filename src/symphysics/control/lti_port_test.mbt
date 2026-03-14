///|
test "physics.control.lti: transfer function parity" {
  let s = @symcore.symbol("s")
  let expr = @symcore.int(2) +
    @symcore.int(3) *
    s *
    (((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1))
  let tf = try! TransferFunction::from_rational_expression(expr, var=s)
  guard control_expr_eq(
    tf.to_expr(),
    try! @sympy_physics.control_exec_stdout(
      "tf = TransferFunction.from_rational_expression(2 + 3*s/(s**2 + 1), s)\nprint(tf.to_expr())\n",
    ),
  ) else {
    fail("from_rational_expression parity")
  }

  let simplified_tf = try! transfer_function(
    (s + @symcore.int(3)) * (s + @symcore.int(-1)),
    (s + @symcore.int(-1)) * (s + @symcore.int(5)),
    s,
  )
  let simplified = try! simplified_tf.simplify()
  guard control_expr_eq(
    simplified.to_expr(),
    try! @sympy_physics.control_exec_stdout(
      "tf = TransferFunction((s + 3)*(s - 1), (s - 1)*(s + 5), s).simplify()\nprint(tf.to_expr())\n",
    ),
  ) else {
    fail("simplify parity")
  }

  let eval_frequency = try! simplified.eval_frequency(
    @symcore.symbol("I") + @symcore.int(1),
  )
  guard control_expr_eq(
    eval_frequency,
    try! @sympy_physics.control_exec_stdout(
      "tf = TransferFunction((s + 3)*(s - 1), (s - 1)*(s + 5), s).simplify()\nprint(tf.eval_frequency(1 + I))\n",
    ),
  ) else {
    fail("eval_frequency parity")
  }

  let dc_gain = try! simplified.dc_gain()
  guard control_expr_eq(
    dc_gain,
    try! @sympy_physics.control_exec_stdout(
      "tf = TransferFunction((s + 3)*(s - 1), (s - 1)*(s + 5), s).simplify()\nprint(tf.dc_gain())\n",
    ),
  ) else {
    fail("dc_gain parity")
  }
}

///|
test "physics.control.lti: interconnection parity" {
  let s = @symcore.symbol("s")
  let g = (try! transfer_function(s + @symcore.int(1), s + @symcore.int(2), s)).as_system()
  let h = (try! transfer_function(@symcore.int(1), s + @symcore.int(4), s)).as_system()

  guard control_expr_eq(
    (try! series([g, h]).doit()).to_expr(),
    try! @sympy_physics.control_exec_stdout(
      "g = TransferFunction(s + 1, s + 2, s)\nh = TransferFunction(1, s + 4, s)\nprint(Series(g, h).doit().to_expr())\n",
    ),
  ) else {
    fail("series parity")
  }
  guard control_expr_eq(
    (try! parallel([g, h]).doit()).to_expr(),
    try! @sympy_physics.control_exec_stdout(
      "g = TransferFunction(s + 1, s + 2, s)\nh = TransferFunction(1, s + 4, s)\nprint(Parallel(g, h).doit().to_expr())\n",
    ),
  ) else {
    fail("parallel parity")
  }
  guard control_expr_eq(
    (try! feedback(g).doit()).to_expr(),
    try! @sympy_physics.control_exec_stdout(
      "g = TransferFunction(s + 1, s + 2, s)\nprint(Feedback(g).doit().to_expr())\n",
    ),
  ) else {
    fail("feedback parity")
  }
}

///|
test "physics.control.lti: discretization parity" {
  let s = @symcore.symbol("s")
  let z = @symcore.symbol("z")
  let t = try! @symcore.rational_from_ints(1, 10)
  let cont = try! transfer_function(@symcore.int(1), s + @symcore.int(1), s)

  let bil = try! DiscreteTransferFunction::from_bilinear(cont, t, z)
  guard control_expr_eq(
    bil.to_expr(),
    try! @sympy_physics.control_exec_stdout(
      "tf = TransferFunction(1, s + 1, s)\nprint(DiscreteTransferFunction.from_bilinear(tf, Rational(1, 10), z).to_expr())\n",
    ),
  ) else {
    fail("bilinear parity")
  }

  let forward = try! DiscreteTransferFunction::from_forward_diff(cont, t, z)
  guard control_expr_eq(
    forward.to_expr(),
    try! @sympy_physics.control_exec_stdout(
      "tf = TransferFunction(1, s + 1, s)\nprint(DiscreteTransferFunction.from_forward_diff(tf, Rational(1, 10), z).to_expr())\n",
    ),
  ) else {
    fail("forward diff parity")
  }

  let backward = try! DiscreteTransferFunction::from_backward_diff(cont, t, z)
  guard control_expr_eq(
    backward.to_expr(),
    try! @sympy_physics.control_exec_stdout(
      "tf = TransferFunction(1, s + 1, s)\nprint(DiscreteTransferFunction.from_backward_diff(tf, Rational(1, 10), z).to_expr())\n",
    ),
  ) else {
    fail("backward diff parity")
  }
}
