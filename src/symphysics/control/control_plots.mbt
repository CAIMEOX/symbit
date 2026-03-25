///|
/// Pure-data plotting helpers aligned with the computational surface of
/// `sympy.physics.control.control_plots`.
///
/// SymPy returns matplotlib objects. In MoonBit we keep the same algorithms
/// and public entry points, but the `*_plot` functions return sampled plot
/// records so the data can be inspected or rendered by any frontend.

///|
pub struct PoleZeroPlot {
  zeros : Array[ControlComplex]
  poles : Array[ControlComplex]
  pole_color : String
  pole_markersize : Double
  zero_color : String
  zero_markersize : Double
  grid : Bool
  show_axes : Bool
  title : String
}

///|
pub struct SampledLinePlot {
  x : Array[Double]
  y : Array[Double]
  color : String
  xlabel : String
  ylabel : String
  title : String
  grid : Bool
  show_axes : Bool
  xscale : String
}

///|
pub struct ParametricPlot {
  x : Array[Double]
  y : Array[Double]
  mirror_x : Array[Double]?
  mirror_y : Array[Double]?
  color : String
  xlabel : String
  ylabel : String
  title : String
  grid : Bool
}

///|
pub struct BodePlot {
  magnitude : SampledLinePlot
  phase : SampledLinePlot
}

///|
fn control_expr_has_delay(expr : @symcore.Expr, variable_name : String) -> Bool {
  match expr {
    @symcore.Expr::Add(args)
    | @symcore.Expr::Mul(args)
    | @symcore.Expr::Function(_, args) =>
      match expr {
        @symcore.Expr::Function("exp", [arg]) =>
          control_expr_depends_on_symbol(arg, variable_name)
        _ => args.any(arg => control_expr_has_delay(arg, variable_name))
      }
    @symcore.Expr::Pow(base, exp) =>
      control_expr_has_delay(base, variable_name) ||
      control_expr_has_delay(exp, variable_name)
    _ => false
  }
}

///|
fn control_require_plot_range(
  lower_limit : Double,
  upper_limit : Double,
) -> Unit raise ControlError {
  guard lower_limit >= 0.0 else {
    raise ControlError::ValueError(
      "lower time limit must be greater than or equal to zero",
    )
  }
  guard upper_limit >= lower_limit else {
    raise ControlError::ValueError(
      "upper time limit must be greater than or equal to lower time limit",
    )
  }
}

///|
fn control_plot_label(
  system : SISOLinearTimeInvariant,
) -> String raise ControlError {
  let expr = system.doit().to_expr()
  @symprint.to_string(expr)
}

///|
fn control_as_continuous_tf(
  system : SISOLinearTimeInvariant,
) -> TransferFunction raise ControlError {
  let resolved = system.doit()
  let tf = match resolved {
    SISOLinearTimeInvariant::TF(value) => value
    SISOLinearTimeInvariant::DTF(_) =>
      raise ControlError::TypeError(
        "control plots currently support only continuous-time systems",
      )
    _ =>
      raise ControlError::NotImplemented("unexpected non-base control system")
  }
  let variable_name = control_var_name(tf.var_)
  let expr = tf.to_expr()
  if control_has_extra_free_symbols(expr, variable_name) {
    raise ControlError::ValueError(
      "extra degree of freedom found in the control system",
    )
  }
  if control_expr_has_delay(expr, variable_name) {
    raise ControlError::NotImplemented("time delay terms are not supported")
  }
  tf
}

///|
fn control_numeric_poly_coeffs(
  expr : @symcore.Expr,
  variable_name : String,
  context : String,
) -> Array[Double] raise ControlError {
  try control_poly_coeffs_as_doubles(expr, variable_name) catch {
    _ => raise ControlError::NotImplemented(context)
  } noraise {
    value =>
      match value {
        Some(coeffs) => coeffs
        None => raise ControlError::NotImplemented(context)
      }
  }
}

///|
fn control_logspace(
  initial_exp : Double,
  final_exp : Double,
  n : Int,
) -> Array[Double] {
  if n <= 1 {
    return [@math.pow(10.0, initial_exp)]
  }
  let step = (final_exp - initial_exp) / (n - 1).to_double()
  let out : Array[Double] = []
  for i in 0..<n {
    out.push(@math.pow(10.0, initial_exp + step * i.to_double()))
  }
  out
}

///|
fn control_frequency_value(
  expr : @symcore.Expr,
  variable_name : String,
  omega : Double,
  freq_unit : String,
) -> ControlComplex raise ControlError {
  let env : Map[String, ControlComplex] = {}
  let value = if freq_unit == "Hz" {
    (0.0, 2.0 * @math.PI * omega)
  } else {
    (0.0, omega)
  }
  env[variable_name] = value
  match control_expr_complex_double(expr, env) {
    Some(result) => result
    None =>
      raise ControlError::NotImplemented(
        "frequency evaluation requires numeric coefficients",
      )
  }
}

///|
fn control_conjugate_i(expr : @symcore.Expr) -> @symcore.Expr {
  match @symcore.number_symbol_kind(expr) {
    Some(@symcore.NumberSymbolKind::ImaginaryUnit) =>
      @symcore.int(-1) * @symcore.imag_unit()
    _ =>
      match expr {
        @symcore.Expr::Add(args) =>
          control_normalize(@symcore.add(args.map(control_conjugate_i)))
        @symcore.Expr::Mul(args) =>
          control_normalize(@symcore.mul(args.map(control_conjugate_i)))
        @symcore.Expr::Pow(base, exp) =>
          control_normalize(
            @symcore.pow(control_conjugate_i(base), control_conjugate_i(exp)),
          )
        @symcore.Expr::Function(name, args) =>
          @symcore.function(name, args.map(control_conjugate_i))
        _ => expr
      }
  }
}

///|
fn control_time_response_numerical_data(
  system : SISOLinearTimeInvariant,
  input_power : Int,
  scale : Double,
  lower_limit : Double,
  upper_limit : Double,
  n : Int,
) -> (Array[Double], Array[Double]) raise ControlError {
  control_require_plot_range(lower_limit, upper_limit)
  guard n > 0 else {
    raise ControlError::ValueError("sample count should be positive")
  }
  let tf = control_as_continuous_tf(system)
  let variable_name = control_var_name(tf.var_)
  let num_coeffs = control_numeric_poly_coeffs(
    tf.num_,
    variable_name,
    "response generation requires a polynomial numerator with numeric coefficients",
  ).map(coeff => coeff * scale)
  let den_expr = control_normalize(
    tf.den_ * (tf.var_ ^ @symcore.int(input_power)),
  )
  let den_coeffs = control_numeric_poly_coeffs(
    den_expr, variable_name, "response generation requires a polynomial denominator with numeric coefficients",
  )
  let times = control_response_grid(lower_limit, upper_limit, n)
  let values = match
    control_response_samples_from_coeffs(num_coeffs, den_coeffs, times) {
    Some(result) => result
    None =>
      raise ControlError::NotImplemented(
        "response generation failed for this transfer function",
      )
  }
  (times, values)
}

///|
pub fn pole_zero_numerical_data(
  system : SISOLinearTimeInvariant,
) -> (Array[ControlComplex], Array[ControlComplex]) raise ControlError {
  let tf = control_as_continuous_tf(system)
  let variable_name = control_var_name(tf.var_)
  let zeros = if control_expr_is_zero(tf.num_) {
    []
  } else {
    match
      control_poly_numeric_roots(
        control_numeric_poly_coeffs(
          tf.num_,
          variable_name,
          "pole-zero data requires numeric polynomial coefficients",
        ),
      ) {
      Some(result) => result
      None =>
        raise ControlError::NotImplemented(
          "zero finding failed for this transfer function",
        )
    }
  }
  let poles = match
    control_poly_numeric_roots(
      control_numeric_poly_coeffs(
        tf.den_,
        variable_name,
        "pole-zero data requires numeric polynomial coefficients",
      ),
    ) {
    Some(result) => result
    None =>
      raise ControlError::NotImplemented(
        "pole finding failed for this transfer function",
      )
  }
  (zeros, poles)
}

///|
pub fn pole_zero_plot(
  system : SISOLinearTimeInvariant,
  pole_color? : String = "blue",
  pole_markersize? : Double = 10.0,
  zero_color? : String = "orange",
  zero_markersize? : Double = 7.0,
  grid? : Bool = true,
  show_axes? : Bool = true,
) -> PoleZeroPlot raise ControlError {
  let data = pole_zero_numerical_data(system)
  PoleZeroPlot::{
    zeros: data.0,
    poles: data.1,
    pole_color,
    pole_markersize,
    zero_color,
    zero_markersize,
    grid,
    show_axes,
    title: "Poles and Zeros of $\{control_plot_label(system)}$",
  }
}

///|
pub fn step_response_numerical_data(
  system : SISOLinearTimeInvariant,
  _prec? : Int = 8,
  lower_limit? : Double = 0.0,
  upper_limit? : Double = 10.0,
  n? : Int = 200,
) -> (Array[Double], Array[Double]) raise ControlError {
  control_time_response_numerical_data(
    system, 1, 1.0, lower_limit, upper_limit, n,
  )
}

///|
pub fn step_response_plot(
  system : SISOLinearTimeInvariant,
  color? : String = "b",
  prec? : Int = 8,
  lower_limit? : Double = 0.0,
  upper_limit? : Double = 10.0,
  show_axes? : Bool = false,
  grid? : Bool = true,
  n? : Int = 200,
) -> SampledLinePlot raise ControlError {
  let data = step_response_numerical_data(
    system,
    _prec=prec,
    lower_limit~,
    upper_limit~,
    n~,
  )
  SampledLinePlot::{
    x: data.0,
    y: data.1,
    color,
    xlabel: "Time (s)",
    ylabel: "Amplitude",
    title: "Unit Step Response of $\{control_plot_label(system)}$",
    grid,
    show_axes,
    xscale: "linear",
  }
}

///|
pub fn impulse_response_numerical_data(
  system : SISOLinearTimeInvariant,
  _prec? : Int = 8,
  lower_limit? : Double = 0.0,
  upper_limit? : Double = 10.0,
  n? : Int = 200,
) -> (Array[Double], Array[Double]) raise ControlError {
  control_time_response_numerical_data(
    system, 0, 1.0, lower_limit, upper_limit, n,
  )
}

///|
pub fn impulse_response_plot(
  system : SISOLinearTimeInvariant,
  color? : String = "b",
  prec? : Int = 8,
  lower_limit? : Double = 0.0,
  upper_limit? : Double = 10.0,
  show_axes? : Bool = false,
  grid? : Bool = true,
  n? : Int = 200,
) -> SampledLinePlot raise ControlError {
  let data = impulse_response_numerical_data(
    system,
    _prec=prec,
    lower_limit~,
    upper_limit~,
    n~,
  )
  SampledLinePlot::{
    x: data.0,
    y: data.1,
    color,
    xlabel: "Time (s)",
    ylabel: "Amplitude",
    title: "Impulse Response of $\{control_plot_label(system)}$",
    grid,
    show_axes,
    xscale: "linear",
  }
}

///|
pub fn ramp_response_numerical_data(
  system : SISOLinearTimeInvariant,
  slope? : Double = 1.0,
  _prec? : Int = 8,
  lower_limit? : Double = 0.0,
  upper_limit? : Double = 10.0,
  n? : Int = 200,
) -> (Array[Double], Array[Double]) raise ControlError {
  guard slope >= 0.0 else {
    raise ControlError::ValueError(
      "slope must be greater than or equal to zero",
    )
  }
  control_time_response_numerical_data(
    system, 2, slope, lower_limit, upper_limit, n,
  )
}

///|
pub fn ramp_response_plot(
  system : SISOLinearTimeInvariant,
  slope? : Double = 1.0,
  color? : String = "b",
  prec? : Int = 8,
  lower_limit? : Double = 0.0,
  upper_limit? : Double = 10.0,
  show_axes? : Bool = false,
  grid? : Bool = true,
  n? : Int = 200,
) -> SampledLinePlot raise ControlError {
  let data = ramp_response_numerical_data(
    system,
    slope~,
    _prec=prec,
    lower_limit~,
    upper_limit~,
    n~,
  )
  SampledLinePlot::{
    x: data.0,
    y: data.1,
    color,
    xlabel: "Time (s)",
    ylabel: "Amplitude",
    title: "Ramp Response of $\{control_plot_label(system)}$ [Slope = \{slope}]",
    grid,
    show_axes,
    xscale: "linear",
  }
}

///|
pub fn bode_magnitude_numerical_data(
  system : SISOLinearTimeInvariant,
  initial_exp? : Double = -5.0,
  final_exp? : Double = 5.0,
  freq_unit? : String = "rad/sec",
  n? : Int = 200,
) -> (Array[Double], Array[Double]) raise ControlError {
  guard freq_unit == "rad/sec" || freq_unit == "Hz" else {
    raise ControlError::ValueError(
      "Only \"rad/sec\" and \"Hz\" are accepted frequency units.",
    )
  }
  let tf = control_as_continuous_tf(system)
  let variable_name = control_var_name(tf.var_)
  let expr = tf.to_expr()
  let freqs = control_logspace(initial_exp, final_exp, n)
  let values : Array[Double] = []
  for freq in freqs {
    let point = control_frequency_value(expr, variable_name, freq, freq_unit)
    let mag = control_complex_abs(point)
    values.push(20.0 * @math.ln(mag) / @math.ln(10.0))
  }
  (freqs, values)
}

///|
pub fn bode_magnitude_plot(
  system : SISOLinearTimeInvariant,
  initial_exp? : Double = -5.0,
  final_exp? : Double = 5.0,
  color? : String = "b",
  show_axes? : Bool = false,
  grid? : Bool = true,
  freq_unit? : String = "rad/sec",
  n? : Int = 200,
) -> SampledLinePlot raise ControlError {
  let data = bode_magnitude_numerical_data(
    system,
    initial_exp~,
    final_exp~,
    freq_unit~,
    n~,
  )
  SampledLinePlot::{
    x: data.0,
    y: data.1,
    color,
    xlabel: "Frequency (\{freq_unit}) [Log Scale]",
    ylabel: "Magnitude (dB)",
    title: "Bode Plot (Magnitude) of $\{control_plot_label(system)}$",
    grid,
    show_axes,
    xscale: "log",
  }
}

///|
pub fn bode_phase_numerical_data(
  system : SISOLinearTimeInvariant,
  initial_exp? : Double = -5.0,
  final_exp? : Double = 5.0,
  freq_unit? : String = "rad/sec",
  phase_unit? : String = "rad",
  phase_unwrap? : Bool = true,
  n? : Int = 200,
) -> (Array[Double], Array[Double]) raise ControlError {
  guard freq_unit == "rad/sec" || freq_unit == "Hz" else {
    raise ControlError::ValueError(
      "Only \"rad/sec\" and \"Hz\" are accepted frequency units.",
    )
  }
  guard phase_unit == "rad" || phase_unit == "deg" else {
    raise ControlError::ValueError(
      "Only \"rad\" and \"deg\" are accepted phase units.",
    )
  }
  let tf = control_as_continuous_tf(system)
  let variable_name = control_var_name(tf.var_)
  let expr = tf.to_expr()
  let freqs = control_logspace(initial_exp, final_exp, n)
  let values : Array[Double] = []
  for freq in freqs {
    let point = control_frequency_value(expr, variable_name, freq, freq_unit)
    let base = control_complex_arg(point)
    values.push(
      if phase_unit == "deg" {
        base * 180.0 / @math.PI
      } else {
        base
      },
    )
  }
  if phase_unwrap && values.length() > 1 {
    let half = if phase_unit == "deg" { 180.0 } else { @math.PI }
    let unit = 2.0 * half
    for i in 1..<values.length() {
      let diff = values[i] - values[i - 1]
      if diff > half {
        values[i] = values[i] - unit
      } else if diff < -half {
        values[i] = values[i] + unit
      }
    }
  }
  (freqs, values)
}

///|
pub fn bode_phase_plot(
  system : SISOLinearTimeInvariant,
  initial_exp? : Double = -5.0,
  final_exp? : Double = 5.0,
  color? : String = "b",
  show_axes? : Bool = false,
  grid? : Bool = true,
  freq_unit? : String = "rad/sec",
  phase_unit? : String = "rad",
  phase_unwrap? : Bool = true,
  n? : Int = 200,
) -> SampledLinePlot raise ControlError {
  let data = bode_phase_numerical_data(
    system,
    initial_exp~,
    final_exp~,
    freq_unit~,
    phase_unit~,
    phase_unwrap~,
    n~,
  )
  SampledLinePlot::{
    x: data.0,
    y: data.1,
    color,
    xlabel: "Frequency (\{freq_unit}) [Log Scale]",
    ylabel: "Phase (\{phase_unit})",
    title: "Bode Plot (Phase) of $\{control_plot_label(system)}$",
    grid,
    show_axes,
    xscale: "log",
  }
}

///|
pub fn bode_plot(
  system : SISOLinearTimeInvariant,
  initial_exp? : Double = -5.0,
  final_exp? : Double = 5.0,
  grid? : Bool = true,
  show_axes? : Bool = false,
  freq_unit? : String = "rad/sec",
  phase_unit? : String = "rad",
  phase_unwrap? : Bool = true,
  n? : Int = 200,
) -> BodePlot raise ControlError {
  BodePlot::{
    magnitude: bode_magnitude_plot(
      system,
      initial_exp~,
      final_exp~,
      show_axes~,
      grid~,
      freq_unit~,
      n~,
    ),
    phase: bode_phase_plot(
      system,
      initial_exp~,
      final_exp~,
      show_axes~,
      grid~,
      freq_unit~,
      phase_unit~,
      phase_unwrap~,
      n~,
    ),
  }
}

///|
pub fn nyquist_plot_expr(
  system : SISOLinearTimeInvariant,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr) raise ControlError {
  let tf = control_as_continuous_tf(system)
  let w = @symcore.symbol("w")
  let env : Map[String, @symcore.Expr] = {}
  env[control_var_name(tf.var_)] = @symcore.imag_unit() * w
  let value = control_normalize(@symcore.subst(tf.to_expr(), env))
  let conj_value = control_conjugate_i(value)
  let real = control_normalize(
    (value + conj_value) * @symcore.pow(@symcore.int(2), @symcore.int(-1)),
  )
  let imag = control_normalize(
    (value - conj_value) *
    @symcore.pow(@symcore.int(2) * @symcore.imag_unit(), @symcore.int(-1)),
  )
  (real, imag, w)
}

///|
pub fn nichols_plot_expr(
  system : SISOLinearTimeInvariant,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr) raise ControlError {
  let tf = control_as_continuous_tf(system)
  let w = @symcore.symbol("w")
  let env : Map[String, @symcore.Expr] = {}
  env[control_var_name(tf.var_)] = @symcore.imag_unit() * w
  let value = control_normalize(@symcore.subst(tf.to_expr(), env))
  let conj_value = control_conjugate_i(value)
  let mag_sq = control_normalize(value * conj_value)
  let mag_abs = match mag_sq {
    @symcore.Expr::Pow(base, @symcore.Expr::Number(n)) if n.is_integral() &&
      n.numerator().to_int() == -1 &&
      n.denominator().to_int() == 1 =>
      control_normalize(@symcore.pow(@symelem.sqrt(base), @symcore.int(-1)))
    _ => @symelem.sqrt(mag_sq)
  }
  let magnitude = @symcore.int(20) *
    @symelem.log(mag_abs) *
    (@symelem.log(@symcore.int(10)) ^ @symcore.int(-1))
  let phase = @symcore.int(180) *
    @symelem.arg(value) *
    (@symcore.pi() ^ @symcore.int(-1))
  (magnitude, phase, w)
}

///|
pub fn nyquist_plot(
  system : SISOLinearTimeInvariant,
  initial_omega? : Double = 0.01,
  final_omega? : Double = 100.0,
  color? : String = "b",
  grid? : Bool = false,
  n? : Int = 200,
) -> ParametricPlot raise ControlError {
  guard final_omega >= initial_omega else {
    raise ControlError::ValueError(
      "final frequency should be greater than or equal to initial frequency",
    )
  }
  let tf = control_as_continuous_tf(system)
  let variable_name = control_var_name(tf.var_)
  let expr = tf.to_expr()
  let omega = control_response_grid(initial_omega, final_omega, n)
  let x : Array[Double] = []
  let y : Array[Double] = []
  let mx : Array[Double] = []
  let my : Array[Double] = []
  for w in omega {
    let value = control_frequency_value(expr, variable_name, w, "rad/sec")
    x.push(value.0)
    y.push(value.1)
    mx.push(value.0)
    my.push(-value.1)
  }
  ParametricPlot::{
    x,
    y,
    mirror_x: Some(mx),
    mirror_y: Some(my),
    color,
    xlabel: "Real Axis",
    ylabel: "Imaginary Axis",
    title: "Nyquist Plot of $\{control_plot_label(system)}$",
    grid,
  }
}

///|
pub fn nichols_plot(
  system : SISOLinearTimeInvariant,
  initial_omega? : Double = 0.01,
  final_omega? : Double = 100.0,
  color? : String = "b",
  grid? : Bool = false,
  n? : Int = 200,
) -> ParametricPlot raise ControlError {
  guard final_omega >= initial_omega else {
    raise ControlError::ValueError(
      "final frequency should be greater than or equal to initial frequency",
    )
  }
  let tf = control_as_continuous_tf(system)
  let variable_name = control_var_name(tf.var_)
  let expr = tf.to_expr()
  let omega = control_response_grid(initial_omega, final_omega, n)
  let x : Array[Double] = []
  let y : Array[Double] = []
  for w in omega {
    let value = control_frequency_value(expr, variable_name, w, "rad/sec")
    x.push(control_complex_arg(value) * 180.0 / @math.PI)
    y.push(20.0 * @math.ln(control_complex_abs(value)) / @math.ln(10.0))
  }
  ParametricPlot::{
    x,
    y,
    mirror_x: None,
    mirror_y: None,
    color,
    xlabel: "Phase [deg]",
    ylabel: "Magnitude [dB]",
    title: "Nichols Plot of $\{control_plot_label(system)}$",
    grid,
  }
}
