///|
fn waves_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  context : String,
) -> Unit raise {
  let lhs_txt = @symprint.to_string(lhs)
  guard (try! @sympy_physics.physics_expr_equivalent(lhs, rhs)) else {
    fail("\{context}: ours=\{lhs_txt}; oracle=\{rhs}")
  }
}

///|
test "physics.optics.waves: twave properties and rewrites" {
  let amp = @symcore.symbol("A")
  let phi = @symcore.symbol("phi")
  let freq = @symcore.symbol("f")
  let wave = try! t_wave(amp, frequency=Some(freq), phase=phi)

  guard wave.to_string() == "TWave(A, f, phi, 1/f, n)" else {
    fail("twave repr")
  }
  guard wave.frequency == freq else { fail("twave frequency") }
  guard wave.phase == phi else { fail("twave phase") }
  guard wave.time_period == (freq ^ @symcore.int(-1)) else {
    fail("twave period")
  }
  guard @symprint.to_string(wave.rewrite_as_cos()).contains("cos(") else {
    fail("twave rewrite cos")
  }
  guard @symprint.to_string(wave.rewrite_as_sin()).contains("sin(") else {
    fail("twave rewrite sin")
  }
  guard @symprint.to_string(wave.rewrite_as_exp()).contains("exp(") else {
    fail("twave rewrite exp")
  }
}

///|
test "physics.optics.waves: superposition and scaling" {
  let amp1 = @symcore.symbol("A1")
  let amp2 = @symcore.symbol("A2")
  let phi1 = @symcore.symbol("phi1")
  let phi2 = @symcore.symbol("phi2")
  let freq = @symcore.symbol("f")
  let w1 = try! t_wave(amp1, frequency=Some(freq), phase=phi1)
  let w2 = try! t_wave(amp2, frequency=Some(freq), phase=phi2)
  let summed = try! w1.superpose(w2)

  waves_assert_expr_equal(
    summed.amplitude,
    "sqrt(A1**2 + 2*A1*A2*cos(phi1 - phi2) + A2**2)",
    "twave superpose amplitude",
  )
  waves_assert_expr_equal(
    summed.phase,
    "atan2(A1*sin(phi1) + A2*sin(phi2), A1*cos(phi1) + A2*cos(phi2))",
    "twave superpose phase",
  )
  waves_assert_expr_equal(
    (try! w1.scale(@symcore.int(3))).amplitude,
    "3*A1",
    "twave scale",
  )
  guard (try? t_wave(amp1, phase=phi1)) is Err(_) else {
    fail("twave missing frequency/time_period should fail")
  }
}
