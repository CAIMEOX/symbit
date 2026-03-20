///|
test "physics.control.control_plots: pole-zero numerical data" {
  let s = @symcore.symbol("s")
  let tf = transfer_function(
    (s ^ @symcore.int(2)) + @symcore.int(1),
    (s ^ @symcore.int(2)) + s + @symcore.int(2),
    s,
  ).as_system()
  let data = pole_zero_numerical_data(tf)
  assert_true(control_complex_array_close(data.0, [(0.0, -1.0), (0.0, 1.0)], tol=1.0e-5),)
  assert_true(
    control_complex_array_close(
      data.1,
      [(-0.5, -1.3228756555), (-0.5, 1.3228756555)],
      tol=1.0e-5,
    ),
  )

  let plot = pole_zero_plot(tf)
  assert_true(plot.title.contains("Poles and Zeros") && plot.grid && plot.show_axes,)
}

///|
test "physics.control.control_plots: time responses" {
  let s = @symcore.symbol("s")
  let tf = transfer_function(@symcore.int(1), s + @symcore.int(1), s).as_system()

  let step = step_response_numerical_data(
    tf,
    lower_limit=0.0,
    upper_limit=2.0,
    n=3,
  )
  assert_true(control_double_array_close(step.0, [0.0, 1.0, 2.0]))
  assert_true(
    control_double_array_close(
      step.1,
      [0.0, 1.0 - @math.exp(-1.0), 1.0 - @math.exp(-2.0)],
      tol=1.0e-4,
    ),
  )

  let impulse = impulse_response_numerical_data(
    tf,
    lower_limit=0.0,
    upper_limit=2.0,
    n=3,
  )
  assert_true(
    control_double_array_close(
      impulse.1,
      [1.0, @math.exp(-1.0), @math.exp(-2.0)],
      tol=1.0e-4,
    ),
  )

  let ramp = ramp_response_numerical_data(
    tf,
    lower_limit=0.0,
    upper_limit=2.0,
    n=3,
  )
  assert_true(
    control_double_array_close(
      ramp.1,
      [0.0, @math.exp(-1.0), 1.0 + @math.exp(-2.0)],
      tol=1.0e-4,
    ),
  )
}

///|
test "physics.control.control_plots: bode and parametric helpers" {
  let s = @symcore.symbol("s")
  let tf = transfer_function(@symcore.int(1), s + @symcore.int(1), s).as_system()

  let mag = bode_magnitude_numerical_data(
    tf,
    initial_exp=-1.0,
    final_exp=1.0,
    n=3,
  )
  assert_true(control_double_array_close(mag.0, [0.1, 1.0, 10.0], tol=1.0e-10))
  assert_true(control_test_double_close(mag.1[1], -3.0102999566, tol=1.0e-4))

  let phase = bode_phase_numerical_data(
    tf,
    initial_exp=-1.0,
    final_exp=1.0,
    phase_unit="deg",
    n=3,
  )
  assert_true(control_test_double_close(phase.1[1], -45.0, tol=1.0e-4))

  let nyquist_expr = nyquist_plot_expr(tf)
  assert_true(control_expr_eq(nyquist_expr.0, "1/(w**2 + 1)"))
  assert_true(control_expr_eq(nyquist_expr.1, "-w/(w**2 + 1)"))

  let nichols_expr = nichols_plot_expr(tf)
  assert_true(control_expr_eq(nichols_expr.1, "180*arg(1/(I*w + 1))/pi"))
}

///|
test "physics.control.control_plots: plot records" {
  let s = @symcore.symbol("s")
  let tf = transfer_function(@symcore.int(1), s + @symcore.int(1), s).as_system()

  let bode = bode_plot(tf, initial_exp=-1.0, final_exp=1.0, n=5)
  assert_true(bode.magnitude.xscale == "log" && bode.phase.xscale == "log")

  let nyquist = nyquist_plot(tf, initial_omega=0.0, final_omega=2.0, n=5)
  assert_true(nyquist.mirror_x is Some(_) && nyquist.mirror_y is Some(_))

  let nichols = nichols_plot(tf, initial_omega=0.1, final_omega=1.0, n=5)
  assert_true(nichols.xlabel == "Phase [deg]" && nichols.ylabel == "Magnitude [dB]",)
}
