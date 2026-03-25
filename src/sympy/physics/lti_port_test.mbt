///|
test "physics.control.lti: transfer function parity" {
  let s = @symcore.symbol("s")
  let expr = @symcore.int(2) +
    @symcore.int(3) *
    s *
    (((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1))
  let tf = TransferFunction::from_rational_expression(expr, variable=s)
  assert_true(
    control_expr_eq(
      tf.to_expr(),
      control_exec_stdout(
        "tf = TransferFunction.from_rational_expression(2 + 3*s/(s**2 + 1), s)\nprint(tf.to_expr())\n",
      ),
    ),
  )

  let simplified_tf = transfer_function(
    (s + @symcore.int(3)) * (s + @symcore.int(-1)),
    (s + @symcore.int(-1)) * (s + @symcore.int(5)),
    s,
  )
  let simplified = simplified_tf.simplify()
  assert_true(
    control_expr_eq(
      simplified.to_expr(),
      control_exec_stdout(
        "tf = TransferFunction((s + 3)*(s - 1), (s - 1)*(s + 5), s).simplify()\nprint(tf.to_expr())\n",
      ),
    ),
  )

  let eval_frequency = simplified.eval_frequency(
    @symcore.imag_unit() + @symcore.int(1),
  )
  assert_true(
    control_expr_eq(
      eval_frequency,
      control_exec_stdout(
        "tf = TransferFunction((s + 3)*(s - 1), (s - 1)*(s + 5), s).simplify()\nprint(tf.eval_frequency(1 + I))\n",
      ),
    ),
  )

  let dc_gain = simplified.dc_gain()
  assert_true(
    control_expr_eq(
      dc_gain,
      control_exec_stdout(
        "tf = TransferFunction((s + 3)*(s - 1), (s - 1)*(s + 5), s).simplify()\nprint(tf.dc_gain())\n",
      ),
    ),
  )
}

///|
test "physics.control.lti: interconnection parity" {
  let s = @symcore.symbol("s")
  let g = transfer_function(s + @symcore.int(1), s + @symcore.int(2), s).as_system()
  let h = transfer_function(@symcore.int(1), s + @symcore.int(4), s).as_system()

  assert_true(
    control_expr_eq(
      series([g, h]).doit().to_expr(),
      control_exec_stdout(
        "g = TransferFunction(s + 1, s + 2, s)\nh = TransferFunction(1, s + 4, s)\nprint(Series(g, h).doit().to_expr())\n",
      ),
    ),
  )
  assert_true(
    control_expr_eq(
      parallel([g, h]).doit().to_expr(),
      control_exec_stdout(
        "g = TransferFunction(s + 1, s + 2, s)\nh = TransferFunction(1, s + 4, s)\nprint(Parallel(g, h).doit().to_expr())\n",
      ),
    ),
  )
  assert_true(
    control_expr_eq(
      feedback(g).doit().to_expr(),
      control_exec_stdout(
        "g = TransferFunction(s + 1, s + 2, s)\nprint(Feedback(g).doit().to_expr())\n",
      ),
    ),
  )
}

///|
test "physics.control.lti: discretization parity" {
  let s = @symcore.symbol("s")
  let z = @symcore.symbol("z")
  let t = @symcore.rational_from_ints(1, 10)
  let cont = transfer_function(@symcore.int(1), s + @symcore.int(1), s)

  let bil = DiscreteTransferFunction::from_bilinear(cont, t, z)
  assert_true(
    control_expr_eq(
      bil.to_expr(),
      control_exec_stdout(
        "tf = TransferFunction(1, s + 1, s)\nprint(DiscreteTransferFunction.from_bilinear(tf, Rational(1, 10), z).to_expr())\n",
      ),
    ),
  )

  let forward = DiscreteTransferFunction::from_forward_diff(cont, t, z)
  assert_true(
    control_expr_eq(
      forward.to_expr(),
      control_exec_stdout(
        "tf = TransferFunction(1, s + 1, s)\nprint(DiscreteTransferFunction.from_forward_diff(tf, Rational(1, 10), z).to_expr())\n",
      ),
    ),
  )

  let backward = DiscreteTransferFunction::from_backward_diff(cont, t, z)
  assert_true(
    control_expr_eq(
      backward.to_expr(),
      control_exec_stdout(
        "tf = TransferFunction(1, s + 1, s)\nprint(DiscreteTransferFunction.from_backward_diff(tf, Rational(1, 10), z).to_expr())\n",
      ),
    ),
  )
}
