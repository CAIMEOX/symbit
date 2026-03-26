///|
test "physics.optics.waves: parity" {
  let amp = @symcore.Expr::Symbol("A")
  let phi = @symcore.Expr::Symbol("phi")
  let freq = @symcore.Expr::Symbol("f")
  let amp1 = @symcore.Expr::Symbol("A1")
  let amp2 = @symcore.Expr::Symbol("A2")
  let phi1 = @symcore.Expr::Symbol("phi1")
  let phi2 = @symcore.Expr::Symbol("phi2")
  let wave = t_wave(amp, frequency=Some(freq), phase=phi)
  let sum_wave = t_wave(amp1, frequency=Some(freq), phase=phi1).superpose(
    t_wave(amp2, frequency=Some(freq), phase=phi2),
  )

  assert_eq(wave.to_string(), optics_waves_eval("TWave(A, f, phi)"))
  waves_assert_expr_equal(
    wave.amplitude_expr(),
    optics_waves_eval("TWave(A, f, phi).amplitude"),
    "twave amplitude parity",
  )
  waves_assert_expr_equal(
    wave.frequency_expr(),
    optics_waves_eval("TWave(A, f, phi).frequency"),
    "twave frequency parity",
  )
  waves_assert_expr_equal(
    wave.phase_expr(),
    optics_waves_eval("TWave(A, f, phi).phase"),
    "twave phase parity",
  )
  waves_assert_expr_equal(
    wave.time_period_expr(),
    optics_waves_eval("TWave(A, f, phi).time_period"),
    "twave time_period parity",
  )
  waves_assert_expr_equal(
    wave.refractive_index_expr(),
    optics_waves_eval("TWave(A, f, phi).n"),
    "twave n parity",
  )
  waves_assert_expr_equal(
    wave.wavelength(),
    optics_waves_eval("TWave(A, f, phi).wavelength"),
    "twave wavelength parity",
  )
  waves_assert_expr_equal(
    wave.speed(),
    optics_waves_eval("TWave(A, f, phi).speed"),
    "twave speed parity",
  )
  waves_assert_expr_equal(
    wave.angular_velocity(),
    optics_waves_eval("TWave(A, f, phi).angular_velocity"),
    "twave omega parity",
  )
  waves_assert_expr_equal(
    wave.wavenumber(),
    optics_waves_eval("TWave(A, f, phi).wavenumber"),
    "twave k parity",
  )
  waves_assert_expr_equal(
    sum_wave.amplitude,
    optics_waves_eval("(TWave(A1, f, phi1) + TWave(A2, f, phi2)).amplitude"),
    "twave add amplitude parity",
  )
  waves_assert_expr_equal(
    sum_wave.phase,
    optics_waves_eval("(TWave(A1, f, phi1) + TWave(A2, f, phi2)).phase"),
    "twave add phase parity",
  )
}
