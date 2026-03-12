///|
test "physics.optics.waves: parity" {
  let amp = @symcore.symbol("A")
  let phi = @symcore.symbol("phi")
  let freq = @symcore.symbol("f")
  let amp1 = @symcore.symbol("A1")
  let amp2 = @symcore.symbol("A2")
  let phi1 = @symcore.symbol("phi1")
  let phi2 = @symcore.symbol("phi2")
  let wave = try! t_wave(amp, frequency=Some(freq), phase=phi)
  let sum_wave = try! (try! t_wave(amp1, frequency=Some(freq), phase=phi1)).superpose(
    try! t_wave(amp2, frequency=Some(freq), phase=phi2),
  )

  guard wave.to_string() ==
    (try! @sympy_physics.optics_waves_eval("TWave(A, f, phi)")) else {
    fail("twave repr parity")
  }
  waves_assert_expr_equal(
    wave.wavelength(),
    try! @sympy_physics.optics_waves_eval("TWave(A, f, phi).wavelength"),
    "twave wavelength parity",
  )
  waves_assert_expr_equal(
    wave.speed(),
    try! @sympy_physics.optics_waves_eval("TWave(A, f, phi).speed"),
    "twave speed parity",
  )
  waves_assert_expr_equal(
    wave.angular_velocity(),
    try! @sympy_physics.optics_waves_eval("TWave(A, f, phi).angular_velocity"),
    "twave omega parity",
  )
  waves_assert_expr_equal(
    wave.wavenumber(),
    try! @sympy_physics.optics_waves_eval("TWave(A, f, phi).wavenumber"),
    "twave k parity",
  )
  waves_assert_expr_equal(
    sum_wave.amplitude,
    try! @sympy_physics.optics_waves_eval(
      "(TWave(A1, f, phi1) + TWave(A2, f, phi2)).amplitude",
    ),
    "twave add amplitude parity",
  )
  waves_assert_expr_equal(
    sum_wave.phase,
    try! @sympy_physics.optics_waves_eval(
      "(TWave(A1, f, phi1) + TWave(A2, f, phi2)).phase",
    ),
    "twave add phase parity",
  )
}
