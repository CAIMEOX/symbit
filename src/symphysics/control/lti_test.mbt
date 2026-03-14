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
  let tf = try! TransferFunction::from_rational_expression(expr, var=s)
  let expected_tf = try! transfer_function(
    @symcore.int(2) * (s ^ @symcore.int(2)) +
    @symcore.int(3) * s +
    @symcore.int(2),
    (s ^ @symcore.int(2)) + @symcore.int(1),
    s,
  )
  guard tf == expected_tf else { fail("from_rational_expression") }

  let unsimplified = try! transfer_function(
    (s + @symcore.int(3)) * (s + @symcore.int(-1)),
    (s + @symcore.int(-1)) * (s + @symcore.int(5)),
    s,
  )
  let simplified = try! unsimplified.simplify()
  let simplified_expected = try! transfer_function(
    s + @symcore.int(3),
    s + @symcore.int(5),
    s,
  )
  guard simplified == simplified_expected else { fail("simplify") }
  let dc_gain = try! simplified.dc_gain()
  guard dc_gain == control_test_rat(3, 5) else { fail("dc_gain") }
  guard (try! simplified.poles()) == [@symcore.int(-5)] else { fail("poles") }
  guard (try! simplified.zeros()) == [@symcore.int(-3)] else { fail("zeros") }
  let is_proper = try! simplified.is_proper()
  let is_strictly_proper = try! simplified.is_strictly_proper()
  let is_biproper = try! simplified.is_biproper()
  guard is_proper && !is_strictly_proper && is_biproper else {
    fail("properness/biproperness")
  }
}

///|
test "physics.control.lti: series parallel and feedback" {
  let s = @symcore.symbol("s")
  let g_tf = try! transfer_function(s + @symcore.int(1), s + @symcore.int(2), s)
  let h_tf = try! transfer_function(@symcore.int(1), s + @symcore.int(4), s)
  let g = g_tf.as_system()
  let h = h_tf.as_system()

  let ser = try! series([g, h]).doit()
  let ser_expected = try! transfer_function(
    s + @symcore.int(1),
    (s + @symcore.int(2)) * (s + @symcore.int(4)),
    s,
  )
  guard ser == ser_expected.as_system() else { fail("series.doit") }

  let par = try! parallel([g, h]).doit()
  let par_expected = try! transfer_function(
    (s + @symcore.int(1)) * (s + @symcore.int(4)) + (s + @symcore.int(2)),
    (s + @symcore.int(2)) * (s + @symcore.int(4)),
    s,
  )
  guard par == par_expected.as_system() else { fail("parallel.doit") }

  let fb = try! feedback(g).doit()
  let fb_expected = try! transfer_function(
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
  let cont = try! transfer_function(@symcore.int(1), s + @symcore.int(1), s)

  let fd = try! DiscreteTransferFunction::from_forward_diff(cont, t, z)
  let fd_gbt = try! DiscreteTransferFunction::from_gbt(
    cont,
    t,
    @symcore.int(0),
    z,
  )
  guard fd == fd_gbt else { fail("forward diff == gbt(alpha=0)") }
  let fd_dc_gain = try! fd.dc_gain()
  guard fd_dc_gain == @symcore.int(1) else { fail("discrete dc_gain") }

  let stable = try! discrete_transfer_function(
    @symcore.int(1),
    z + @symcore.int(-1) * control_test_rat(1, 2),
    z,
    sampling_time=t,
  )
  guard stable.is_stable() == Some(true) else { fail("stable dtf") }

  let unstable = try! discrete_transfer_function(
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
  let pid = try! pid_controller(kp~, ki~, kd~, tf=tfilt, var=s)
  let pid_doit = try! pid.doit()
  let pid_expected = try! transfer_function(
    kp * tfilt * (s ^ @symcore.int(2)) +
    kp * s +
    ki * tfilt * s +
    ki +
    kd * (s ^ @symcore.int(2)),
    tfilt * (s ^ @symcore.int(2)) + s,
    s,
  )
  guard pid_doit == pid_expected else { fail("pid.doit") }

  let continuous = try! create_transfer_function(
    @symcore.int(1),
    s + @symcore.int(1),
    s,
  )
  guard continuous is SISOLinearTimeInvariant::TF(_) else {
    fail("create continuous tf")
  }
  let discrete = try! create_transfer_function(
    @symcore.int(1),
    z + @symcore.int(1),
    z,
    sampling_time=control_test_rat(1, 5),
  )
  guard discrete is SISOLinearTimeInvariant::DTF(_) else {
    fail("create discrete tf")
  }
}
