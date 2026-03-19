///|
fn control_test_rat(num : Int, den : Int) -> @symcore.Expr {
  try! @symcore.rational_from_ints(num, den)
}

///|
test "physics.control.lti: transfer function surface" {
  let s = @symcore.symbol("s")
  let expr = @symcore.int(2) +
    @symcore.int(3) *
    s *
    (((s ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(-1))
  let tf = TransferFunction::from_rational_expression(expr, var=s)
  let expected_tf = transfer_function(
    @symcore.int(2) * (s ^ @symcore.int(2)) +
    @symcore.int(3) * s +
    @symcore.int(2),
    (s ^ @symcore.int(2)) + @symcore.int(1),
    s,
  )
  guard tf == expected_tf else { fail("from_rational_expression") }

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
  guard simplified == simplified_expected else { fail("simplify") }
  let dc_gain = simplified.dc_gain()
  guard dc_gain == control_test_rat(3, 5) else { fail("dc_gain") }
  guard simplified.poles() == [@symcore.int(-5)] else { fail("poles") }
  guard simplified.zeros() == [@symcore.int(-3)] else { fail("zeros") }
  let is_proper = simplified.is_proper()
  let is_strictly_proper = simplified.is_strictly_proper()
  let is_biproper = simplified.is_biproper()
  guard is_proper && !is_strictly_proper && is_biproper else {
    fail("properness/biproperness")
  }
}

///|
test "physics.control.lti: series parallel and feedback" {
  let s = @symcore.symbol("s")
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
  guard ser == ser_expected.as_system() else { fail("series.doit") }

  let par = parallel([g, h]).doit()
  let par_expected = transfer_function(
    (s + @symcore.int(1)) * (s + @symcore.int(4)) + (s + @symcore.int(2)),
    (s + @symcore.int(2)) * (s + @symcore.int(4)),
    s,
  )
  guard par == par_expected.as_system() else { fail("parallel.doit") }

  let fb = feedback(g).doit()
  let fb_expected = transfer_function(
    s + @symcore.int(1),
    s + @symcore.int(2) + (s + @symcore.int(1)),
    s,
  )
  guard fb == fb_expected.as_system() else { fail("feedback.doit") }
}

///|
test "physics.control.lti: discrete transforms and stability" {
  let s = @symcore.symbol("s")
  let z = @symcore.symbol("z")
  let t = control_test_rat(1, 10)
  let cont = transfer_function(@symcore.int(1), s + @symcore.int(1), s)

  let fd = DiscreteTransferFunction::from_forward_diff(cont, t, z)
  let fd_gbt = DiscreteTransferFunction::from_gbt(cont, t, @symcore.int(0), z)
  guard fd == fd_gbt else { fail("forward diff == gbt(alpha=0)") }
  let fd_dc_gain = fd.dc_gain()
  guard fd_dc_gain == @symcore.int(1) else { fail("discrete dc_gain") }

  let stable = discrete_transfer_function(
    @symcore.int(1),
    z + @symcore.int(-1) * control_test_rat(1, 2),
    z,
    sampling_time=t,
  )
  guard stable.is_stable() == Some(true) else { fail("stable dtf") }

  let unstable = discrete_transfer_function(
    @symcore.int(1),
    z + @symcore.int(2),
    z,
    sampling_time=t,
  )
  guard unstable.is_stable() == Some(false) else { fail("unstable dtf") }
}

///|
test "physics.control.lti: pid and create_transfer_function" {
  let s = @symcore.symbol("s")
  let z = @symcore.symbol("z")
  let kp = @symcore.symbol("kp")
  let ki = @symcore.symbol("ki")
  let kd = @symcore.symbol("kd")
  let tfilt = @symcore.symbol("tf")
  let pid = pid_controller(kp~, ki~, kd~, tf=tfilt, var=s)
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
  guard pid_doit == pid_expected else { fail("pid.doit") }

  let continuous = create_transfer_function(
    @symcore.int(1),
    s + @symcore.int(1),
    s,
  )
  guard continuous is SISOLinearTimeInvariant::TF(_) else {
    fail("create continuous tf")
  }
  let discrete = create_transfer_function(
    @symcore.int(1),
    z + @symcore.int(1),
    z,
    sampling_time=control_test_rat(1, 5),
  )
  guard discrete is SISOLinearTimeInvariant::DTF(_) else {
    fail("create discrete tf")
  }
}
