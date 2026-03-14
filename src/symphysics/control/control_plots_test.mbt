///|
test "physics.control.control_plots: pole-zero numerical data" {
  let s = @symcore.symbol("s")
  let tf = (try! transfer_function(
    (s ^ @symcore.int(2)) + @symcore.int(1),
    (s ^ @symcore.int(2)) + s + @symcore.int(2),
    s,
  )).as_system()
  let data = try! pole_zero_numerical_data(tf)
  guard control_complex_array_close(
    data.0,
    [(0.0, -1.0), (0.0, 1.0)],
    tol=1.0e-5,
  ) else {
    fail("zeros")
  }
  guard control_complex_array_close(
    data.1,
    [(-0.5, -1.3228756555), (-0.5, 1.3228756555)],
    tol=1.0e-5,
  ) else {
    fail("poles")
  }

  let plot = try! pole_zero_plot(tf)
  guard plot.title.contains("Poles and Zeros") && plot.grid && plot.show_axes else {
    fail("plot metadata")
  }
}

///|
test "physics.control.control_plots: time responses" {
  let s = @symcore.symbol("s")
  let tf = (try! transfer_function(@symcore.int(1), s + @symcore.int(1), s)).as_system()

  let step = try! step_response_numerical_data(
    tf,
    lower_limit=0.0,
    upper_limit=2.0,
    n=3,
  )
  guard control_double_array_close(step.0, [0.0, 1.0, 2.0]) else {
    fail("step x")
  }
  guard control_double_array_close(
    step.1,
    [0.0, 1.0 - @math.exp(-1.0), 1.0 - @math.exp(-2.0)],
    tol=1.0e-4,
  ) else {
    fail("step y")
  }

  let impulse = try! impulse_response_numerical_data(
    tf,
    lower_limit=0.0,
    upper_limit=2.0,
    n=3,
  )
  guard control_double_array_close(
    impulse.1,
    [1.0, @math.exp(-1.0), @math.exp(-2.0)],
    tol=1.0e-4,
  ) else {
    fail("impulse y")
  }

  let ramp = try! ramp_response_numerical_data(
    tf,
    lower_limit=0.0,
    upper_limit=2.0,
    n=3,
  )
  guard control_double_array_close(
    ramp.1,
    [0.0, @math.exp(-1.0), 1.0 + @math.exp(-2.0)],
    tol=1.0e-4,
  ) else {
    fail("ramp y")
  }
}

///|
test "physics.control.control_plots: bode and parametric helpers" {
  let s = @symcore.symbol("s")
  let tf = (try! transfer_function(@symcore.int(1), s + @symcore.int(1), s)).as_system()

  let mag = try! bode_magnitude_numerical_data(
    tf,
    initial_exp=-1.0,
    final_exp=1.0,
    n=3,
  )
  guard control_double_array_close(mag.0, [0.1, 1.0, 10.0], tol=1.0e-10) else {
    fail("bode mag x")
  }
  guard control_test_double_close(mag.1[1], -3.0102999566, tol=1.0e-4) else {
    fail("bode mag mid")
  }

  let phase = try! bode_phase_numerical_data(
    tf,
    initial_exp=-1.0,
    final_exp=1.0,
    phase_unit="deg",
    n=3,
  )
  guard control_test_double_close(phase.1[1], -45.0, tol=1.0e-4) else {
    fail("bode phase mid")
  }

  let nyquist_expr = try! nyquist_plot_expr(tf)
  guard control_expr_eq(nyquist_expr.0, "1/(w**2 + 1)") else {
    fail("nyquist real expr")
  }
  guard control_expr_eq(nyquist_expr.1, "-w/(w**2 + 1)") else {
    fail("nyquist imag expr")
  }

  let nichols_expr = try! nichols_plot_expr(tf)
  guard control_expr_eq(nichols_expr.1, "180*arg(1/(I*w + 1))/pi") else {
    fail("nichols phase expr")
  }
}

///|
test "physics.control.control_plots: plot records" {
  let s = @symcore.symbol("s")
  let tf = (try! transfer_function(@symcore.int(1), s + @symcore.int(1), s)).as_system()

  let bode = try! bode_plot(tf, initial_exp=-1.0, final_exp=1.0, n=5)
  guard bode.magnitude.xscale == "log" && bode.phase.xscale == "log" else {
    fail("bode plot xscale")
  }

  let nyquist = try! nyquist_plot(tf, initial_omega=0.0, final_omega=2.0, n=5)
  guard nyquist.mirror_x is Some(_) && nyquist.mirror_y is Some(_) else {
    fail("nyquist mirror")
  }

  let nichols = try! nichols_plot(tf, initial_omega=0.1, final_omega=1.0, n=5)
  guard nichols.xlabel == "Phase [deg]" && nichols.ylabel == "Magnitude [dB]" else {
    fail("nichols labels")
  }
}
