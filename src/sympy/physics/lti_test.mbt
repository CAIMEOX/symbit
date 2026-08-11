///|
fn control_test_rat(num : Int, den : Int) -> @symcore.Expr {
  @symcore.rational_from_ints(num, den) catch {
    _ => @symcore.function("Rational", [@symcore.int(num), @symcore.int(den)])
  }
}

///|
test "physics.control.lti: transfer function surface" {
  let s = @symcore.Expr::Symbol("s")
  let expr = @symcore.int(2) +
    @symcore.int(3) *
    s *
    (((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1))
  let tf = TransferFunction::from_rational_expression(expr, variable=s)
  let expected_tf = transfer_function(
    @symcore.int(2) * (s ^ @symcore.int(2)) +
    @symcore.int(3) * s +
    @symcore.int(2),
    (s ^ @symcore.int(2)) + @symcore.int(1),
    s,
  )
  assert_true(tf == expected_tf)

  let unsimplified = transfer_function(
    (s + @symcore.int(3)) * (s + @symcore.int(-1)),
    (s + @symcore.int(-1)) * (s + @symcore.int(5)),
    s,
  )
  let simplified = unsimplified.simplify()
  let simplified_expected = transfer_function(
    s + @symcore.int(3),
    s + @symcore.int(5),
    s,
  )
  assert_true(simplified == simplified_expected)
  let dc_gain = simplified.dc_gain()
  assert_true(dc_gain == control_test_rat(3, 5))
  assert_true(simplified.poles() == [@symcore.int(-5)])
  assert_true(simplified.zeros() == [@symcore.int(-3)])
  let is_proper = simplified.is_proper()
  let is_strictly_proper = simplified.is_strictly_proper()
  let is_biproper = simplified.is_biproper()
  assert_true(is_proper && !is_strictly_proper && is_biproper)
}

///|
test "physics.control.lti: series parallel and feedback" {
  let s = @symcore.Expr::Symbol("s")
  let g_tf = transfer_function(s + @symcore.int(1), s + @symcore.int(2), s)
  let h_tf = transfer_function(@symcore.int(1), s + @symcore.int(4), s)
  let g = g_tf.as_system()
  let h = h_tf.as_system()

  let ser = series([g, h]).doit()
  let ser_expected = transfer_function(
    s + @symcore.int(1),
    (s + @symcore.int(2)) * (s + @symcore.int(4)),
    s,
  )
  assert_true(ser == ser_expected.as_system())

  let par = parallel([g, h]).doit()
  let par_expected = transfer_function(
    (s + @symcore.int(1)) * (s + @symcore.int(4)) + (s + @symcore.int(2)),
    (s + @symcore.int(2)) * (s + @symcore.int(4)),
    s,
  )
  assert_true(par == par_expected.as_system())

  let fb = feedback(g).doit()
  let fb_expected = transfer_function(
    s + @symcore.int(1),
    s + @symcore.int(2) + (s + @symcore.int(1)),
    s,
  )
  assert_true(fb == fb_expected.as_system())
}

///|
test "physics.control.lti: discrete transforms and stability" {
  let s = @symcore.Expr::Symbol("s")
  let z = @symcore.Expr::Symbol("z")
  let t = control_test_rat(1, 10)
  let cont = transfer_function(@symcore.int(1), s + @symcore.int(1), s)

  let fd = DiscreteTransferFunction::from_forward_diff(cont, t, z)
  let fd_gbt = DiscreteTransferFunction::from_gbt(cont, t, @symcore.int(0), z)
  assert_true(fd == fd_gbt)
  let fd_dc_gain = fd.dc_gain()
  assert_true(fd_dc_gain == @symcore.int(1))

  let stable = discrete_transfer_function(
    @symcore.int(1),
    z + @symcore.int(-1) * control_test_rat(1, 2),
    z,
    sampling_time=t,
  )
  assert_eq(stable.is_stable(), Some(true))

  let unstable = discrete_transfer_function(
    @symcore.int(1),
    z + @symcore.int(2),
    z,
    sampling_time=t,
  )
  assert_eq(unstable.is_stable(), Some(false))
}

///|
test "physics.control.lti: pid and create_transfer_function" {
  let s = @symcore.Expr::Symbol("s")
  let z = @symcore.Expr::Symbol("z")
  let kp = @symcore.Expr::Symbol("kp")
  let ki = @symcore.Expr::Symbol("ki")
  let kd = @symcore.Expr::Symbol("kd")
  let tfilt = @symcore.Expr::Symbol("tf")
  let pid = pid_controller(kp~, ki~, kd~, tf=tfilt, variable=s)
  let pid_doit = pid.doit()
  let pid_expected = transfer_function(
    kp * tfilt * (s ^ @symcore.int(2)) +
    kp * s +
    ki * tfilt * s +
    ki +
    kd * (s ^ @symcore.int(2)),
    tfilt * (s ^ @symcore.int(2)) + s,
    s,
  )
  assert_true(pid_doit == pid_expected)

  let continuous = create_transfer_function(
    @symcore.int(1),
    s + @symcore.int(1),
    s,
  )
  assert_true(continuous is TF(_))
  let discrete = create_transfer_function(
    @symcore.int(1),
    z + @symcore.int(1),
    z,
    sampling_time=control_test_rat(1, 5),
  )
  assert_true(discrete is DTF(_))
}
