///|
fn control_split_sections(lines : Array[String]) -> Array[Array[String]] {
  let sections : Array[Array[String]] = [[]]
  for line in lines {
    if line == "---" {
      sections.push([])
    } else {
      sections[sections.length() - 1].push(line)
    }
  }
  sections
}

///|
fn control_py(parts : Array[String]) -> String {
  parts.join("")
}

///|
test "physics.control.control_plots: pole-zero parity" {
  let s = @symcore.symbol("s")
  let tf = transfer_function(
    (s ^ @symcore.int(2)) + @symcore.int(1),
    (s ^ @symcore.int(2)) + s + @symcore.int(2),
    s,
  ).as_system()
  let ours = pole_zero_numerical_data(tf)
  let sections = control_split_sections(
    control_oracle_lines(
      control_py([
        "from sympy.physics.control.control_plots import *\n", "tf = TransferFunction(s**2 + 1, s**2 + s + 2, s)\n",
        "zeros, poles = pole_zero_numerical_data(tf)\n", "for value in zeros:\n",
        "    print(f'{float(re(N(value, 30))):.12f},{float(im(N(value, 30))):.12f}')\n",
        "print('---')\n", "for value in poles:\n", "    print(f'{float(re(N(value, 30))):.12f},{float(im(N(value, 30))):.12f}')\n",
      ]),
    ),
  )
  guard sections.length() == 2 else { fail("oracle section count") }
  guard control_complex_array_close(
    ours.0,
    control_parse_complex_lines(sections[0]),
    tol=1.0e-5,
  ) else {
    fail("zero parity")
  }
  guard control_complex_array_close(
    ours.1,
    control_parse_complex_lines(sections[1]),
    tol=1.0e-5,
  ) else {
    fail("pole parity")
  }
}

///|
test "physics.control.control_plots: response parity" {
  let s = @symcore.symbol("s")
  let tf = transfer_function(@symcore.int(1), s + @symcore.int(1), s).as_system()

  let step = step_response_numerical_data(
    tf,
    lower_limit=0.0,
    upper_limit=2.0,
    n=5,
  )
  let step_sections = control_split_sections(
    control_oracle_lines(
      control_py([
        "from sympy.physics.control.control_plots import *\n", "tf = TransferFunction(1, s + 1, s)\n",
        "x, y = step_response_numerical_data(tf, lower_limit=0, upper_limit=2, adaptive=False, n=5)\n",
        "for value in x: print(float(value))\n", "print('---')\n", "for value in y: print(float(value))\n",
      ]),
    ),
  )
  guard control_double_array_close(
    step.0,
    control_parse_double_lines(step_sections[0]),
    tol=1.0e-8,
  ) else {
    fail("step x parity")
  }
  guard control_double_array_close(
    step.1,
    control_parse_double_lines(step_sections[1]),
    tol=1.0e-4,
  ) else {
    fail("step y parity")
  }

  let impulse = impulse_response_numerical_data(
    tf,
    lower_limit=0.0,
    upper_limit=2.0,
    n=5,
  )
  let impulse_sections = control_split_sections(
    control_oracle_lines(
      control_py([
        "from sympy.physics.control.control_plots import *\n", "tf = TransferFunction(1, s + 1, s)\n",
        "x, y = impulse_response_numerical_data(tf, lower_limit=0, upper_limit=2, adaptive=False, n=5)\n",
        "for value in x: print(float(value))\n", "print('---')\n", "for value in y: print(float(value))\n",
      ]),
    ),
  )
  guard control_double_array_close(
    impulse.1,
    control_parse_double_lines(impulse_sections[1]),
    tol=1.0e-4,
  ) else {
    fail("impulse y parity")
  }

  let ramp = ramp_response_numerical_data(
    tf,
    lower_limit=0.0,
    upper_limit=2.0,
    n=5,
  )
  let ramp_sections = control_split_sections(
    control_oracle_lines(
      control_py([
        "from sympy.physics.control.control_plots import *\n", "tf = TransferFunction(1, s + 1, s)\n",
        "x, y = ramp_response_numerical_data(tf, lower_limit=0, upper_limit=2, adaptive=False, n=5)\n",
        "for value in x: print(float(value))\n", "print('---')\n", "for value in y: print(float(value))\n",
      ]),
    ),
  )
  guard control_double_array_close(
    ramp.1,
    control_parse_double_lines(ramp_sections[1]),
    tol=1.0e-4,
  ) else {
    fail("ramp y parity")
  }
}

///|
test "physics.control.control_plots: bode parity" {
  let s = @symcore.symbol("s")
  let tf = transfer_function(@symcore.int(1), s + @symcore.int(1), s).as_system()

  let mag = bode_magnitude_numerical_data(
    tf,
    initial_exp=-1.0,
    final_exp=1.0,
    n=5,
  )
  let mag_sections = control_split_sections(
    control_oracle_lines(
      control_py([
        "from sympy.physics.control.control_plots import *\n", "tf = TransferFunction(1, s + 1, s)\n",
        "x, y = bode_magnitude_numerical_data(tf, initial_exp=-1, final_exp=1, n=5)\n",
        "for value in x: print(float(value))\n", "print('---')\n", "for value in y: print(float(value))\n",
      ]),
    ),
  )
  guard control_double_array_close(
    mag.0,
    control_parse_double_lines(mag_sections[0]),
    tol=1.0e-8,
  ) else {
    fail("bode mag x parity")
  }
  guard control_double_array_close(
    mag.1,
    control_parse_double_lines(mag_sections[1]),
    tol=1.0e-4,
  ) else {
    fail("bode mag y parity")
  }

  let phase = bode_phase_numerical_data(
    tf,
    initial_exp=-1.0,
    final_exp=1.0,
    phase_unit="deg",
    n=5,
  )
  let phase_sections = control_split_sections(
    control_oracle_lines(
      control_py([
        "from sympy.physics.control.control_plots import *\n", "tf = TransferFunction(1, s + 1, s)\n",
        "x, y = bode_phase_numerical_data(tf, initial_exp=-1, final_exp=1, phase_unit='deg', n=5)\n",
        "for value in x: print(float(value))\n", "print('---')\n", "for value in y: print(float(value))\n",
      ]),
    ),
  )
  guard control_double_array_close(
    phase.1,
    control_parse_double_lines(phase_sections[1]),
    tol=1.0e-4,
  ) else {
    fail("bode phase y parity")
  }
}

///|
test "physics.control.control_plots: expr parity" {
  let s = @symcore.symbol("s")
  let tf = transfer_function(@symcore.int(1), s + @symcore.int(1), s).as_system()

  let nyquist = nyquist_plot_expr(tf)
  let nyquist_lines = control_oracle_lines(
    control_py([
      "from sympy.physics.control.control_plots import *\n", "tf = TransferFunction(1, s + 1, s)\n",
      "real_expr, imag_expr, w = nyquist_plot_expr(tf)\n", "ww = symbols('w')\n",
      "print(real_expr.xreplace({w: ww}))\n", "print(imag_expr.xreplace({w: ww}))\n",
    ]),
  )
  guard control_expr_eq(nyquist.0, nyquist_lines[0]) else {
    fail("nyquist real parity")
  }
  guard control_expr_eq(nyquist.1, nyquist_lines[1]) else {
    fail("nyquist imag parity")
  }

  let nichols = nichols_plot_expr(tf)
  let nichols_lines = control_oracle_lines(
    control_py([
      "from sympy.physics.control.control_plots import *\n", "tf = TransferFunction(1, s + 1, s)\n",
      "mag_expr, phase_expr, w = nichols_plot_expr(tf)\n", "ww = symbols('w')\n",
      "print(mag_expr.xreplace({w: ww}))\n", "print(phase_expr.xreplace({w: ww}))\n",
    ]),
  )
  guard control_expr_eq(nichols.0, nichols_lines[0]) else {
    fail("nichols mag parity")
  }
  guard control_expr_eq(nichols.1, nichols_lines[1]) else {
    fail("nichols phase parity")
  }
}
