///|
fn waves_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  _context : String,
) -> Unit raise {
  assert_true(physics_expr_equivalent(lhs, rhs))
}

///|
test "physics.optics.waves: twave properties and rewrites" {
  let amp = @symcore.Expr::Symbol("A")
  let phi = @symcore.Expr::Symbol("phi")
  let freq = @symcore.Expr::Symbol("f")
  let wave = t_wave(amp, frequency=Some(freq), phase=phi)

  assert_eq(wave.to_string(), "TWave(A, f, phi, 1/f, n)")
  assert_true(wave.amplitude_expr() == amp)
  assert_true(wave.frequency == freq)
  assert_true(wave.phase == phi)
  assert_true(wave.time_period == (freq ^ @symcore.int(-1)))
  assert_true(wave.refractive_index_expr() == @symcore.Expr::Symbol("n"))
  assert_true(@symprint.to_string(wave.rewrite_as_cos()).contains("cos("))
  assert_true(@symprint.to_string(wave.rewrite_as_sin()).contains("sin("))
  assert_true(@symprint.to_string(wave.rewrite_as_exp()).contains("exp("))
}

///|
test "physics.optics.waves: superposition and scaling" {
  let amp1 = @symcore.Expr::Symbol("A1")
  let amp2 = @symcore.Expr::Symbol("A2")
  let phi1 = @symcore.Expr::Symbol("phi1")
  let phi2 = @symcore.Expr::Symbol("phi2")
  let freq = @symcore.Expr::Symbol("f")
  let w1 = t_wave(amp1, frequency=Some(freq), phase=phi1)
  let w2 = t_wave(amp2, frequency=Some(freq), phase=phi2)
  let summed = w1.superpose(w2)

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
    w1.scale(@symcore.int(3)).amplitude,
    "3*A1",
    "twave scale",
  )
  assert_true((try? t_wave(amp1, phase=phi1)) is Err(_))
}
