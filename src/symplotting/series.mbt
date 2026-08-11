///|
fn plot_symbol_like(expr : @symcore.Expr) -> Bool {
  match expr {
    Symbol(_) | Dummy(_, _) => true
    _ => false
  }
}

///|
/// - Does: Checks whether one expression has the structural shape of a plotting range tuple.
/// - Input: One `Expr`.
/// - Returns: `Bool`.
/// - Limits: This is a structural check only; numeric validity is enforced later by series constructors.
pub fn is_plot_range(expr : @symcore.Expr) -> Bool {
  match expr {
    Tuple([symbol, _, _]) => plot_symbol_like(symbol)
    _ => false
  }
}

///|
/// - Does: Stores one Cartesian 1D line-series specification and its sampling options.
/// - Input: Constructed from one expression, one variable range, and sampling metadata.
/// - Returns: One `LineOver1DRangeSeries` value.
/// - Limits: Numeric range validation happens when sampling methods are called or through the constructor front door.
pub struct LineOver1DRangeSeries {
  expr : @symcore.Expr
  variable : @symcore.Expr
  start : @symcore.Expr
  end : @symcore.Expr
  label : String?
  rendering_kw : Map[String, String]?
  adaptive : Bool
  depth : Int
  only_integers : Bool
  n : Int
  return_mode : String?
  xscale : String
}

///|
/// - Does: Formats the 1D line series for diagnostics.
/// - Input: One `LineOver1DRangeSeries`.
/// - Returns: `String`.
/// - Limits: Output is intended for inspection and tests, so string format changes can break assertions.
pub fn LineOver1DRangeSeries::to_string(self : LineOver1DRangeSeries) -> String {
  "cartesian line: " +
  @symprint.pretty_string(self.expr) +
  " for " +
  @symprint.pretty_string(self.variable) +
  " over (" +
  @symprint.pretty_string(self.start) +
  ", " +
  @symprint.pretty_string(self.end) +
  ")"
}

///|
/// - Does: Returns the plotted variable of one 1D line series.
/// - Input: One `LineOver1DRangeSeries`.
/// - Returns: `Expr`.
/// - Limits: This is a shallow accessor.
pub fn LineOver1DRangeSeries::plot_var(
  self : LineOver1DRangeSeries,
) -> @symcore.Expr {
  self.variable
}

///|
/// - Does: Returns the configured point count of one 1D line series.
/// - Input: One `LineOver1DRangeSeries`.
/// - Returns: `Int`.
/// - Limits: Adaptive sampling can produce a different effective number of samples.
pub fn LineOver1DRangeSeries::nb_of_points(self : LineOver1DRangeSeries) -> Int {
  self.n
}

///|
fn plot_expr_to_complex_parts(expr : @symcore.Expr) -> (Double, Double)? {
  match @symcore.evalf(expr, prec=80) {
    Float(value) => Some((value.to_double(), 0.0)) catch { _ => None }
    ComplexFloat(value) =>
      Some((value.real_part().to_double(), value.imag_part().to_double())) catch {
        _ => None
      }
    _ => None
  }
}

///|
fn plot_numeric_sample_expr(
  sample_real : Double,
  sample_imag : Double,
) -> @symcore.Expr {
  let to_plot_float = fn(value : Double) {
    @symcore.Float::from_str(value.to_string(), prec=80) catch {
      _ => @symcore.Float::from_double(value, prec=80)
    }
  }
  if sample_imag.abs() <= 1.0e-8 {
    Float(to_plot_float(sample_real))
  } else {
    ComplexFloat(
      @symcore.ComplexFloat::from_real(
        to_plot_float(sample_real),
        imag=to_plot_float(sample_imag),
      ),
    )
  }
}

///|
fn plot_raw_xreplace_impl(
  expr : @symcore.Expr,
  rules : Array[(@symcore.Expr, @symcore.Expr)],
) -> @symcore.Expr {
  let expr = @symcore.normalize_legacy_expr(expr)
  for rule in rules {
    let (old_expr, new_expr) = rule
    if expr == old_expr {
      return new_expr
    }
  }
  match expr {
    Add(args) =>
      @symcore.raw_add(args.map(arg => plot_raw_xreplace_impl(arg, rules)))
    Mul(args) =>
      @symcore.raw_mul(args.map(arg => plot_raw_xreplace_impl(arg, rules)))
    Pow(base, exp) =>
      @symcore.raw_pow(
        plot_raw_xreplace_impl(base, rules),
        plot_raw_xreplace_impl(exp, rules),
      )
    Mod(lhs, rhs) =>
      @symcore.raw_mod_expr(
        plot_raw_xreplace_impl(lhs, rules),
        plot_raw_xreplace_impl(rhs, rules),
      )
    Tuple(args) => Tuple(args.map(arg => plot_raw_xreplace_impl(arg, rules)))
    Dict(items) => {
      let out : Array[(@symcore.Expr, @symcore.Expr)] = []
      for item in items {
        let (key, value) = item
        out.push(
          (
            plot_raw_xreplace_impl(key, rules),
            plot_raw_xreplace_impl(value, rules),
          ),
        )
      }
      Dict(out)
    }
    Relational(op, lhs, rhs) =>
      Relational(
        op,
        plot_raw_xreplace_impl(lhs, rules),
        plot_raw_xreplace_impl(rhs, rules),
      )
    Derivative(inner, deriv_args) => {
      let out : Array[@symcore.Expr] = []
      for arg in deriv_args {
        out.push(plot_raw_xreplace_impl(arg, rules))
      }
      Derivative(plot_raw_xreplace_impl(inner, rules), out)
    }
    Subs(inner, variable, value) =>
      Subs(
        plot_raw_xreplace_impl(inner, rules),
        plot_raw_xreplace_impl(variable, rules),
        plot_raw_xreplace_impl(value, rules),
      )
    Lambda(vars, body) =>
      Lambda(
        plot_raw_xreplace_impl(vars, rules),
        plot_raw_xreplace_impl(body, rules),
      )
    Apply(head, args) => {
      let rewritten_head = plot_raw_xreplace_impl(head, rules)
      let rewritten_args = args.map(arg => plot_raw_xreplace_impl(arg, rules))
      match @symcore.raw_apply(rewritten_head, rewritten_args) {
        Some(applied) => applied
        None => Apply(rewritten_head, rewritten_args)
      }
    }
    _ => expr
  }
}

///|
fn plot_raw_xreplace(
  expr : @symcore.Expr,
  rules : Array[(@symcore.Expr, @symcore.Expr)],
) -> @symcore.Expr {
  let normalized_rules = rules.map(rule => {
    let (old_expr, new_expr) = rule
    (
      @symcore.normalize_legacy_expr(old_expr),
      @symcore.normalize_legacy_expr(new_expr),
    )
  })
  plot_raw_xreplace_impl(expr, normalized_rules)
}

///|
fn plot_eval_numeric(
  expr : @symcore.Expr,
  variable : @symcore.Expr,
  sample_real : Double,
  sample_imag : Double,
) -> (Double, Double)? {
  let sample_expr = plot_numeric_sample_expr(sample_real, sample_imag)
  let substituted = plot_raw_xreplace(expr, [(variable, sample_expr)])
  let evaluated = @symcore.evalf(substituted, prec=80)
  match evaluated {
    Float(value) => Some((value.to_double(), 0.0)) catch { _ => None }
    ComplexFloat(value) =>
      Some((value.real_part().to_double(), value.imag_part().to_double())) catch {
        _ => None
      }
    _ => None
  }
}

///|
fn plot_output_value(
  return_mode : String?,
  real : Double,
  imag : Double,
) -> Double? raise PlottingError {
  match return_mode {
    None => if imag.abs() <= 1.0e-8 { Some(real) } else { None }
    Some("real") => Some(real)
    Some("imag") => Some(imag)
    Some("abs") => Some((real * real + imag * imag).sqrt())
    Some("arg") => Some(@math.atan2(imag, real))
    Some(other) =>
      raise ValueError("`_return` not recognized. Received: " + other)
  }
}

///|
fn plot_geomspace(
  start : Double,
  end : Double,
  count : Int,
) -> Array[Double] raise PlottingError {
  if start == 0.0 || end == 0.0 {
    raise ValueError("log scale requires non-zero range bounds")
  }
  if (start > 0.0 && end < 0.0) || (start < 0.0 && end > 0.0) {
    raise ValueError("log scale requires start and end to have the same sign")
  }
  let sign = if start < 0.0 { -1.0 } else { 1.0 }
  let log_start = @math.ln(start.abs())
  let log_end = @math.ln(end.abs())
  let out : Array[Double] = []
  if count <= 1 {
    out.push(start)
    return out
  }
  let denom = (count - 1).to_double()
  for i in 0..<count {
    let t = i.to_double() / denom
    out.push(sign * @math.exp(log_start + (log_end - log_start) * t))
  }
  out
}

///|
fn plot_discretize(
  start : Double,
  end : Double,
  count : Int,
  scale : String,
  only_integers : Bool,
) -> Array[Double] raise PlottingError {
  if only_integers {
    let lo = @math.ceil(start).to_int()
    let hi = @math.floor(end).to_int()
    let out : Array[Double] = []
    for i in lo..<=hi {
      out.push(i.to_double())
    }
    return out
  }
  if scale == "linear" {
    return linspace(start, end, count)
  }
  if scale == "log" {
    return plot_geomspace(start, end, count)
  }
  raise ValueError("unknown plotting scale: " + scale)
}

///|
fn plot_adaptive_midpoint(
  left : Double,
  right : Double,
  scale : String,
) -> Double {
  if scale == "log" {
    let sign = if left < 0.0 { -1.0 } else { 1.0 }
    @math.exp((@math.ln(left.abs()) + @math.ln(right.abs())) / 2.0) * sign
  } else {
    (left + right) / 2.0
  }
}

///|
fn plot_points_flat(
  px : Double,
  py : Double,
  qx : Double,
  qy : Double,
  rx : Double,
  ry : Double,
  eps? : Double = 1.0e-3,
) -> Bool {
  let ax = px - qx
  let ay = py - qy
  let bx = rx - qx
  let by = ry - qy
  let norm_a = (ax * ax + ay * ay).sqrt()
  let norm_b = (bx * bx + by * by).sqrt()
  if norm_a <= 1.0e-12 || norm_b <= 1.0e-12 {
    return true
  }
  let cos_theta = (ax * bx + ay * by) / (norm_a * norm_b)
  (cos_theta + 1.0).abs() < eps
}

///|
fn plot_eval_output(
  expr : @symcore.Expr,
  variable : @symcore.Expr,
  sample_real : Double,
  sample_imag : Double,
  return_mode : String?,
) -> Double? raise PlottingError {
  match plot_eval_numeric(expr, variable, sample_real, sample_imag) {
    Some((real, imag)) => plot_output_value(return_mode, real, imag)
    None => None
  }
}

///|
fn plot_adaptive_sample(
  series : LineOver1DRangeSeries,
  sample_imag : Double,
  left_x : Double,
  left_y : Double?,
  right_x : Double,
  right_y : Double?,
  depth : Int,
  xs : Array[Double],
  ys : Array[Double?],
) -> Unit raise PlottingError {
  let mid_x = plot_adaptive_midpoint(left_x, right_x, series.xscale)
  let mid_y = plot_eval_output(
    series.expr,
    series.variable,
    mid_x,
    sample_imag,
    series.return_mode,
  )
  if depth > series.depth {
    xs.push(right_x)
    ys.push(right_y)
    return
  }
  if depth < 6 {
    plot_adaptive_sample(
      series,
      sample_imag,
      left_x,
      left_y,
      mid_x,
      mid_y,
      depth + 1,
      xs,
      ys,
    )
    plot_adaptive_sample(
      series,
      sample_imag,
      mid_x,
      mid_y,
      right_x,
      right_y,
      depth + 1,
      xs,
      ys,
    )
    return
  }
  let should_split = match (left_y, mid_y, right_y) {
    (Some(py), Some(qy), Some(ry)) =>
      !plot_points_flat(left_x, py, mid_x, qy, right_x, ry)
    _ => true
  }
  if should_split {
    plot_adaptive_sample(
      series,
      sample_imag,
      left_x,
      left_y,
      mid_x,
      mid_y,
      depth + 1,
      xs,
      ys,
    )
    plot_adaptive_sample(
      series,
      sample_imag,
      mid_x,
      mid_y,
      right_x,
      right_y,
      depth + 1,
      xs,
      ys,
    )
  } else {
    xs.push(right_x)
    ys.push(right_y)
  }
}

///|
/// - Does: Samples x/y points for one 1D line series.
/// - Input: One `LineOver1DRangeSeries`.
/// - Returns: `(Array[Double], Array[Double?])`.
/// - Limits: Raises `PlottingError::ValueError` when bounds are not numeric or when complex-range endpoints do not share the same imaginary part.
pub fn LineOver1DRangeSeries::get_points(
  self : LineOver1DRangeSeries,
) -> (Array[Double], Array[Double?]) raise PlottingError {
  let (start_real, start_imag) = match plot_expr_to_complex_parts(self.start) {
    Some(value) => value
    None =>
      raise ValueError("LineOver1DRangeSeries requires numeric range bounds")
  }
  let (end_real, end_imag) = match plot_expr_to_complex_parts(self.end) {
    Some(value) => value
    None =>
      raise ValueError("LineOver1DRangeSeries requires numeric range bounds")
  }
  if (start_imag - end_imag).abs() > 1.0e-8 {
    raise ValueError(
      "LineOver1DRangeSeries requires the imaginary part of the start and end values of the range to be the same.",
    )
  }
  if self.adaptive && !self.only_integers {
    let xs : Array[Double] = [start_real]
    let ys : Array[Double?] = [
      plot_eval_output(
        self.expr,
        self.variable,
        start_real,
        start_imag,
        self.return_mode,
      ),
    ]
    let end_y = plot_eval_output(
      self.expr,
      self.variable,
      end_real,
      start_imag,
      self.return_mode,
    )
    plot_adaptive_sample(
      self,
      start_imag,
      start_real,
      ys[0],
      end_real,
      end_y,
      0,
      xs,
      ys,
    )
    return (xs, ys)
  }
  let xs = plot_discretize(
    start_real,
    end_real,
    self.n,
    self.xscale,
    self.only_integers,
  )
  let ys : Array[Double?] = []
  for value in xs {
    ys.push(
      plot_eval_output(
        self.expr,
        self.variable,
        value,
        start_imag,
        self.return_mode,
      ),
    )
  }
  (xs, ys)
}

///|
/// - Does: Returns the sampled data of one 1D line series.
/// - Input: One `LineOver1DRangeSeries`.
/// - Returns: `(Array[Double], Array[Double?])`.
/// - Limits: This forwards to `get_points`, so it raises the same `PlottingError` cases.
pub fn LineOver1DRangeSeries::get_data(
  self : LineOver1DRangeSeries,
) -> (Array[Double], Array[Double?]) raise PlottingError {
  self.get_points()
}

///|
/// - Does: Builds a Cartesian 1D line-series object from an expression and range tuple.
/// - Input: One expression, one `(symbol, start, end)` range tuple, and optional sampling metadata.
/// - Returns: `LineOver1DRangeSeries`.
/// - Limits: Raises `PlottingError::ValueError` unless the range has the accepted tuple shape.
pub fn line_over_1d_range_series(
  expr : @symcore.Expr,
  range : @symcore.Expr,
  label? : String? = None,
  rendering_kw? : Map[String, String]? = None,
  adaptive? : Bool = false,
  depth? : Int = 12,
  only_integers? : Bool = false,
  n? : Int = 1000,
  return_mode? : String? = None,
  xscale? : String = "linear",
) -> LineOver1DRangeSeries raise PlottingError {
  let resolved_label = match label {
    Some(value) => Some(value)
    None => Some(@symprint.pretty_string(expr))
  }
  match range {
    Tuple([variable, start, end]) if is_plot_range(range) =>
      {
        expr,
        variable,
        start,
        end,
        label: resolved_label,
        rendering_kw,
        adaptive,
        depth,
        only_integers,
        n,
        return_mode,
        xscale,
      }
    _ =>
      raise ValueError(
        "A plotting range must be a tuple of the form (symbol, start, end)",
      )
  }
}

///|
fn plot_eval_real_value(
  expr : @symcore.Expr,
  variable : @symcore.Expr,
  sample_real : Double,
  sample_imag : Double,
) -> Double? {
  match plot_eval_numeric(expr, variable, sample_real, sample_imag) {
    Some((real, imag)) => if imag.abs() <= 1.0e-8 { Some(real) } else { None }
    None => None
  }
}

///|
fn plot_parametric_2d_label(
  expr_x : @symcore.Expr,
  expr_y : @symcore.Expr,
  label : String?,
  use_cm : Bool,
) -> String? {
  match label {
    Some(value) => Some(value)
    None =>
      if use_cm {
        None
      } else {
        Some(
          "(" +
          @symprint.pretty_string(expr_x) +
          ", " +
          @symprint.pretty_string(expr_y) +
          ")",
        )
      }
  }
}

///|
fn plot_parametric_3d_label(
  expr_x : @symcore.Expr,
  expr_y : @symcore.Expr,
  expr_z : @symcore.Expr,
  label : String?,
  use_cm : Bool,
) -> String? {
  match label {
    Some(value) => Some(value)
    None =>
      if use_cm {
        None
      } else {
        Some(
          "(" +
          @symprint.pretty_string(expr_x) +
          ", " +
          @symprint.pretty_string(expr_y) +
          ", " +
          @symprint.pretty_string(expr_z) +
          ")",
        )
      }
  }
}

///|
fn plot_surface_label(expr : @symcore.Expr, label : String?) -> String? {
  match label {
    Some(value) => Some(value)
    None => Some(@symprint.pretty_string(expr))
  }
}

///|
fn plot_parametric_surface_label(
  expr_x : @symcore.Expr,
  expr_y : @symcore.Expr,
  expr_z : @symcore.Expr,
  label : String?,
) -> String? {
  match label {
    Some(value) => Some(value)
    None =>
      Some(
        "(" +
        @symprint.pretty_string(expr_x) +
        ", " +
        @symprint.pretty_string(expr_y) +
        ", " +
        @symprint.pretty_string(expr_z) +
        ")",
      )
  }
}

///|
fn plot_eval_numeric_2d(
  expr : @symcore.Expr,
  variable_x : @symcore.Expr,
  sample_x_real : Double,
  sample_x_imag : Double,
  variable_y : @symcore.Expr,
  sample_y_real : Double,
  sample_y_imag : Double,
) -> (Double, Double)? {
  let sample_x = plot_numeric_sample_expr(sample_x_real, sample_x_imag)
  let sample_y = plot_numeric_sample_expr(sample_y_real, sample_y_imag)
  let substituted = plot_raw_xreplace(expr, [
    (variable_x, sample_x),
    (variable_y, sample_y),
  ])
  let evaluated = @symcore.evalf(substituted, prec=80)
  match evaluated {
    Float(value) => Some((value.to_double(), 0.0)) catch { _ => None }
    ComplexFloat(value) =>
      Some((value.real_part().to_double(), value.imag_part().to_double())) catch {
        _ => None
      }
    _ => None
  }
}

///|
fn plot_eval_real_value_2d(
  expr : @symcore.Expr,
  variable_x : @symcore.Expr,
  sample_x_real : Double,
  sample_x_imag : Double,
  variable_y : @symcore.Expr,
  sample_y_real : Double,
  sample_y_imag : Double,
) -> Double? {
  match
    plot_eval_numeric_2d(
      expr, variable_x, sample_x_real, sample_x_imag, variable_y, sample_y_real,
      sample_y_imag,
    ) {
    Some((real, imag)) => if imag.abs() <= 1.0e-8 { Some(real) } else { None }
    None => None
  }
}

///|
fn plot_implicit_eval_real_2d(
  expr : @symcore.Expr,
  variable_x : @symcore.Expr,
  sample_x_real : Double,
  sample_x_imag : Double,
  variable_y : @symcore.Expr,
  sample_y_real : Double,
  sample_y_imag : Double,
) -> Double? {
  plot_eval_real_value_2d(
    expr, variable_x, sample_x_real, sample_x_imag, variable_y, sample_y_real, sample_y_imag,
  )
}

///|
fn plot_implicit_compare(
  op : @symcore.RelOp,
  lhs : Double,
  rhs : Double,
) -> Bool {
  match op {
    Eq => (lhs - rhs).abs() <= 1.0e-8
    Ne => (lhs - rhs).abs() > 1.0e-8
    Lt => lhs < rhs
    Le => lhs <= rhs
    Gt => lhs > rhs
    Ge => lhs >= rhs
  }
}

///|
fn plot_implicit_boolean_expr(
  expr : @symcore.Expr,
  variable_x : @symcore.Expr,
  sample_x_real : Double,
  sample_x_imag : Double,
  variable_y : @symcore.Expr,
  sample_y_real : Double,
  sample_y_imag : Double,
) -> Bool? {
  match expr {
    Boolean(value) => Some(value)
    Relational(op, lhs, rhs) =>
      match
        (
          plot_implicit_eval_real_2d(
            lhs, variable_x, sample_x_real, sample_x_imag, variable_y, sample_y_real,
            sample_y_imag,
          ),
          plot_implicit_eval_real_2d(
            rhs, variable_x, sample_x_real, sample_x_imag, variable_y, sample_y_real,
            sample_y_imag,
          ),
        ) {
        (Some(lhs_value), Some(rhs_value)) =>
          Some(plot_implicit_compare(op, lhs_value, rhs_value))
        _ => None
      }
    Apply(FunctionHead(name), args) | Function(name, args) =>
      match name {
        "And" => {
          let mut saw_unknown = false
          for arg in args {
            match
              plot_implicit_boolean_expr(
                arg, variable_x, sample_x_real, sample_x_imag, variable_y, sample_y_real,
                sample_y_imag,
              ) {
              Some(false) => return Some(false)
              Some(true) => ()
              None => saw_unknown = true
            }
          }
          if saw_unknown {
            None
          } else {
            Some(true)
          }
        }
        "Or" => {
          let mut saw_unknown = false
          for arg in args {
            match
              plot_implicit_boolean_expr(
                arg, variable_x, sample_x_real, sample_x_imag, variable_y, sample_y_real,
                sample_y_imag,
              ) {
              Some(true) => return Some(true)
              Some(false) => ()
              None => saw_unknown = true
            }
          }
          if saw_unknown {
            None
          } else {
            Some(false)
          }
        }
        "Not" =>
          match args {
            [inner] =>
              match
                plot_implicit_boolean_expr(
                  inner, variable_x, sample_x_real, sample_x_imag, variable_y, sample_y_real,
                  sample_y_imag,
                ) {
                Some(value) => Some(!value)
                None => None
              }
            _ => None
          }
        "Xor" => {
          let mut saw_unknown = false
          let mut parity = false
          for arg in args {
            match
              plot_implicit_boolean_expr(
                arg, variable_x, sample_x_real, sample_x_imag, variable_y, sample_y_real,
                sample_y_imag,
              ) {
              Some(value) => parity = parity != value
              None => saw_unknown = true
            }
          }
          if saw_unknown {
            None
          } else {
            Some(parity)
          }
        }
        _ =>
          match
            plot_implicit_eval_real_2d(
              expr, variable_x, sample_x_real, sample_x_imag, variable_y, sample_y_real,
              sample_y_imag,
            ) {
            Some(value) => Some(value.abs() <= 1.0e-8)
            None => None
          }
      }
    _ =>
      match
        plot_implicit_eval_real_2d(
          expr, variable_x, sample_x_real, sample_x_imag, variable_y, sample_y_real,
          sample_y_imag,
        ) {
        Some(value) => Some(value.abs() <= 1.0e-8)
        None => None
      }
  }
}

///|
fn plot_implicit_plot_type(expr : @symcore.Expr) -> String {
  match expr {
    Boolean(_) => "contourf"
    Relational(op, _, _) =>
      match op {
        Eq => "contour"
        _ => "contourf"
      }
    Apply(FunctionHead(name), _) | Function(name, _) =>
      match name {
        "And" | "Or" | "Not" | "Xor" => "contourf"
        _ => "contour"
      }
    _ => "contour"
  }
}

///|
fn plot_implicit_scalar_expr(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    Relational(Eq, lhs, rhs) =>
      @symcore.add([lhs, @symcore.mul([@symcore.int(-1), rhs])])
    _ => expr
  }
}

///|
fn plot_implicit_interval_fill(
  expr : @symcore.Expr,
  variable_x : @symcore.Expr,
  start_x_real : Double,
  start_x_imag : Double,
  end_x_real : Double,
  variable_y : @symcore.Expr,
  start_y_real : Double,
  start_y_imag : Double,
  end_y_real : Double,
  depth : Int,
) -> Array[ImplicitRectangle]? {
  let xs = linspace(start_x_real, end_x_real, 33)
  let ys = linspace(start_y_real, end_y_real, 33)
  let interval_list : Array[ImplicitRectangle] = []
  for yi in 0..<(ys.length() - 1) {
    for xi in 0..<(xs.length() - 1) {
      interval_list.push({
        x_start: xs[xi],
        x_end: xs[xi + 1],
        y_start: ys[yi],
        y_end: ys[yi + 1],
      })
    }
  }
  let plot_list : Array[ImplicitRectangle] = []
  let has_equality = plot_implicit_has_equality(expr)
  let mut remaining_depth = depth
  while remaining_depth >= 0 && !interval_list.is_empty() {
    let next_intervals : Array[ImplicitRectangle] = []
    for rect in interval_list {
      let interval_x = plot_interval(rect.x_start, rect.x_end)
      let interval_y = plot_interval(rect.y_start, rect.y_end)
      match
        plot_implicit_interval_membership(
          expr, variable_x, interval_x, variable_y, interval_y,
        ) {
        Some(result) =>
          if result.validity == Some(false) || result.truth == Some(false) {
            ()
          } else if result.truth == Some(true) && result.validity == Some(true) {
            plot_list.push(rect)
          } else if result.truth == None || result.validity == None {
            for child in plot_implicit_subdivide_rect(rect) {
              next_intervals.push(child)
            }
          }
        None => return None
      }
    }
    interval_list.clear()
    for rect in next_intervals {
      interval_list.push(rect)
    }
    remaining_depth -= 1
  }
  if has_equality {
    for rect in interval_list {
      let interval_x = plot_interval(rect.x_start, rect.x_end)
      let interval_y = plot_interval(rect.y_start, rect.y_end)
      match
        plot_implicit_interval_membership(
          expr, variable_x, interval_x, variable_y, interval_y,
        ) {
        Some(result) if result.validity == Some(true) &&
          result.truth != Some(false) => plot_list.push(rect)
        Some(_) => ()
        None => return None
      }
    }
  }
  ignore(start_x_imag)
  ignore(start_y_imag)
  Some(plot_list)
}

///|
fn plot_implicit_requires_adaptive(expr : @symcore.Expr) -> Bool {
  match expr {
    Relational(Ne, _, _) => true
    Apply(FunctionHead(name), _) | Function(name, _) =>
      name == "And" || name == "Or" || name == "Not" || name == "Xor"
    _ => false
  }
}

///|
fn plot_implicit_subdivide_rect(
  rect : ImplicitRectangle,
) -> Array[ImplicitRectangle] {
  let mid_x = (rect.x_start + rect.x_end) / 2.0
  let mid_y = (rect.y_start + rect.y_end) / 2.0
  [
    { x_start: rect.x_start, x_end: mid_x, y_start: rect.y_start, y_end: mid_y },
    { x_start: rect.x_start, x_end: mid_x, y_start: mid_y, y_end: rect.y_end },
    { x_start: mid_x, x_end: rect.x_end, y_start: rect.y_start, y_end: mid_y },
    { x_start: mid_x, x_end: rect.x_end, y_start: mid_y, y_end: rect.y_end },
  ]
}

///|
fn plot_implicit_sample_points(
  rect : ImplicitRectangle,
) -> Array[(Double, Double)] {
  let mid_x = (rect.x_start + rect.x_end) / 2.0
  let mid_y = (rect.y_start + rect.y_end) / 2.0
  [
    (rect.x_start, rect.y_start),
    (rect.x_start, rect.y_end),
    (rect.x_end, rect.y_start),
    (rect.x_end, rect.y_end),
    (mid_x, mid_y),
  ]
}

///|
fn plot_implicit_equality_candidate(
  expr : @symcore.Expr,
  variable_x : @symcore.Expr,
  sample_x_imag : Double,
  variable_y : @symcore.Expr,
  sample_y_imag : Double,
  rect : ImplicitRectangle,
) -> Bool {
  let scalar_expr = plot_implicit_scalar_expr(expr)
  let mut saw_positive = false
  let mut saw_negative = false
  let mut saw_unknown = false
  for sample in plot_implicit_sample_points(rect) {
    let (x, y) = sample
    match
      plot_implicit_eval_real_2d(
        scalar_expr, variable_x, x, sample_x_imag, variable_y, y, sample_y_imag,
      ) {
      Some(value) =>
        if value.abs() <= 1.0e-8 {
          return true
        } else if value > 0.0 {
          saw_positive = true
        } else {
          saw_negative = true
        }
      None => saw_unknown = true
    }
  }
  saw_unknown || (saw_positive && saw_negative)
}

///|
fn plot_implicit_boolean_candidate(
  expr : @symcore.Expr,
  variable_x : @symcore.Expr,
  sample_x_imag : Double,
  variable_y : @symcore.Expr,
  sample_y_imag : Double,
  rect : ImplicitRectangle,
) -> (Bool, Bool, Bool) {
  let mut saw_true = false
  let mut saw_false = false
  let mut saw_unknown = false
  for sample in plot_implicit_sample_points(rect) {
    let (x, y) = sample
    match
      plot_implicit_boolean_expr(
        expr, variable_x, x, sample_x_imag, variable_y, y, sample_y_imag,
      ) {
      Some(true) => saw_true = true
      Some(false) => saw_false = true
      None => saw_unknown = true
    }
  }
  (saw_true, saw_false, saw_unknown)
}

///|
fn plot_meshgrid(
  xs : Array[Double],
  ys : Array[Double],
) -> (Array[Array[Double]], Array[Array[Double]]) {
  let mesh_x : Array[Array[Double]] = []
  let mesh_y : Array[Array[Double]] = []
  for y in ys {
    let row_x : Array[Double] = []
    let row_y : Array[Double] = []
    for x in xs {
      row_x.push(x)
      row_y.push(y)
    }
    mesh_x.push(row_x)
    mesh_y.push(row_y)
  }
  (mesh_x, mesh_y)
}

///|
/// - Does: Stores one 2D parametric line-series specification and its sampling options.
/// - Input: Constructed from two expressions, one parameter range, and sampling metadata.
/// - Returns: One `Parametric2DLineSeries` value.
/// - Limits: Numeric range validation happens when sampling methods are called or through the constructor front door.
pub struct Parametric2DLineSeries {
  expr_x : @symcore.Expr
  expr_y : @symcore.Expr
  variable : @symcore.Expr
  start : @symcore.Expr
  end : @symcore.Expr
  label : String?
  rendering_kw : Map[String, String]?
  adaptive : Bool
  depth : Int
  only_integers : Bool
  n : Int
  use_cm : Bool
  xscale : String
}

///|
/// - Does: Formats the 2D parametric line series for diagnostics.
/// - Input: One `Parametric2DLineSeries`.
/// - Returns: `String`.
/// - Limits: Output is intended for inspection and tests, so string format changes can break assertions.
pub fn Parametric2DLineSeries::to_string(
  self : Parametric2DLineSeries,
) -> String {
  "parametric cartesian line: (" +
  @symprint.pretty_string(self.expr_x) +
  ", " +
  @symprint.pretty_string(self.expr_y) +
  ") for " +
  @symprint.pretty_string(self.variable) +
  " over (" +
  @symprint.pretty_string(self.start) +
  ", " +
  @symprint.pretty_string(self.end) +
  ")"
}

///|
/// - Does: Returns the parameter variable of one 2D parametric series.
/// - Input: One `Parametric2DLineSeries`.
/// - Returns: `Expr`.
/// - Limits: This is a shallow accessor.
pub fn Parametric2DLineSeries::plot_var(
  self : Parametric2DLineSeries,
) -> @symcore.Expr {
  self.variable
}

///|
/// - Does: Returns the configured point count of one 2D parametric series.
/// - Input: One `Parametric2DLineSeries`.
/// - Returns: `Int`.
/// - Limits: Adaptive sampling can produce a different effective number of samples.
pub fn Parametric2DLineSeries::nb_of_points(
  self : Parametric2DLineSeries,
) -> Int {
  self.n
}

///|
/// - Does: Returns the display label of one 2D parametric series.
/// - Input: One `Parametric2DLineSeries`.
/// - Returns: `String`.
/// - Limits: Falls back to the parameter variable when no explicit label is stored.
pub fn Parametric2DLineSeries::get_label(
  self : Parametric2DLineSeries,
) -> String {
  match self.label {
    Some(label) => label
    None => @symprint.pretty_string(self.variable)
  }
}

///|
fn plot_parametric_adaptive_sample(
  series : Parametric2DLineSeries,
  sample_imag : Double,
  left_param : Double,
  left_x : Double?,
  left_y : Double?,
  right_param : Double,
  right_x : Double?,
  right_y : Double?,
  depth : Int,
  xs : Array[Double?],
  ys : Array[Double?],
  params : Array[Double],
) -> Unit raise PlottingError {
  let mid_param = plot_adaptive_midpoint(left_param, right_param, series.xscale)
  let mid_x = plot_eval_real_value(
    series.expr_x,
    series.variable,
    mid_param,
    sample_imag,
  )
  let mid_y = plot_eval_real_value(
    series.expr_y,
    series.variable,
    mid_param,
    sample_imag,
  )
  if depth > series.depth {
    xs.push(right_x)
    ys.push(right_y)
    params.push(right_param)
    return
  }
  if depth < 6 {
    plot_parametric_adaptive_sample(
      series,
      sample_imag,
      left_param,
      left_x,
      left_y,
      mid_param,
      mid_x,
      mid_y,
      depth + 1,
      xs,
      ys,
      params,
    )
    plot_parametric_adaptive_sample(
      series,
      sample_imag,
      mid_param,
      mid_x,
      mid_y,
      right_param,
      right_x,
      right_y,
      depth + 1,
      xs,
      ys,
      params,
    )
    return
  }
  let should_split = match (left_x, left_y, mid_x, mid_y, right_x, right_y) {
    (Some(px), Some(py), Some(qx), Some(qy), Some(rx), Some(ry)) =>
      !plot_points_flat(px, py, qx, qy, rx, ry)
    _ => true
  }
  if should_split {
    plot_parametric_adaptive_sample(
      series,
      sample_imag,
      left_param,
      left_x,
      left_y,
      mid_param,
      mid_x,
      mid_y,
      depth + 1,
      xs,
      ys,
      params,
    )
    plot_parametric_adaptive_sample(
      series,
      sample_imag,
      mid_param,
      mid_x,
      mid_y,
      right_param,
      right_x,
      right_y,
      depth + 1,
      xs,
      ys,
      params,
    )
  } else {
    xs.push(right_x)
    ys.push(right_y)
    params.push(right_param)
  }
}

///|
/// - Does: Returns the sampled parameter values of one 2D parametric series.
/// - Input: One `Parametric2DLineSeries`.
/// - Returns: `Array[Double]`.
/// - Limits: Raises the same `PlottingError` cases as `get_data`.
pub fn Parametric2DLineSeries::get_parameter_points(
  self : Parametric2DLineSeries,
) -> Array[Double] raise PlottingError {
  let (_, _, params) = self.get_data()
  params
}

///|
/// - Does: Returns sampled planar points of one 2D parametric series.
/// - Input: One `Parametric2DLineSeries`.
/// - Returns: `(Array[Double?], Array[Double?])`.
/// - Limits: Raises the same `PlottingError` cases as `get_data`.
pub fn Parametric2DLineSeries::get_points(
  self : Parametric2DLineSeries,
) -> (Array[Double?], Array[Double?]) raise PlottingError {
  let (xs, ys, _) = self.get_data()
  (xs, ys)
}

///|
/// - Does: Samples planar data and parameter values for one 2D parametric series.
/// - Input: One `Parametric2DLineSeries`.
/// - Returns: `(Array[Double?], Array[Double?], Array[Double])`.
/// - Limits: Raises `PlottingError::ValueError` when bounds are not numeric or when complex-range endpoints do not share the same imaginary part.
pub fn Parametric2DLineSeries::get_data(
  self : Parametric2DLineSeries,
) -> (Array[Double?], Array[Double?], Array[Double]) raise PlottingError {
  let (start_real, start_imag) = match plot_expr_to_complex_parts(self.start) {
    Some(value) => value
    None =>
      raise ValueError("Parametric2DLineSeries requires numeric range bounds")
  }
  let (end_real, end_imag) = match plot_expr_to_complex_parts(self.end) {
    Some(value) => value
    None =>
      raise ValueError("Parametric2DLineSeries requires numeric range bounds")
  }
  if (start_imag - end_imag).abs() > 1.0e-8 {
    raise ValueError(
      "Parametric2DLineSeries requires the imaginary part of the start and end values of the range to be the same.",
    )
  }
  if self.adaptive && !self.only_integers {
    let start_x = plot_eval_real_value(
      self.expr_x,
      self.variable,
      start_real,
      start_imag,
    )
    let start_y = plot_eval_real_value(
      self.expr_y,
      self.variable,
      start_real,
      start_imag,
    )
    let end_x = plot_eval_real_value(
      self.expr_x,
      self.variable,
      end_real,
      start_imag,
    )
    let end_y = plot_eval_real_value(
      self.expr_y,
      self.variable,
      end_real,
      start_imag,
    )
    let xs : Array[Double?] = [start_x]
    let ys : Array[Double?] = [start_y]
    let params : Array[Double] = [start_real]
    plot_parametric_adaptive_sample(
      self, start_imag, start_real, start_x, start_y, end_real, end_x, end_y, 0,
      xs, ys, params,
    )
    return (xs, ys, params)
  }
  let params = plot_discretize(
    start_real,
    end_real,
    self.n,
    self.xscale,
    self.only_integers,
  )
  let xs : Array[Double?] = []
  let ys : Array[Double?] = []
  for value in params {
    xs.push(plot_eval_real_value(self.expr_x, self.variable, value, start_imag))
    ys.push(plot_eval_real_value(self.expr_y, self.variable, value, start_imag))
  }
  (xs, ys, params)
}

///|
/// - Does: Builds a 2D parametric line-series object from two expressions and a parameter range tuple.
/// - Input: Two expressions, one `(symbol, start, end)` range tuple, and optional sampling metadata.
/// - Returns: `Parametric2DLineSeries`.
/// - Limits: Raises `PlottingError::ValueError` unless the range has the accepted tuple shape.
pub fn parametric_2d_line_series(
  expr_x : @symcore.Expr,
  expr_y : @symcore.Expr,
  range : @symcore.Expr,
  label? : String? = None,
  rendering_kw? : Map[String, String]? = None,
  adaptive? : Bool = true,
  depth? : Int = 12,
  only_integers? : Bool = false,
  n? : Int = 1000,
  use_cm? : Bool = true,
  xscale? : String = "linear",
) -> Parametric2DLineSeries raise PlottingError {
  let resolved_label = plot_parametric_2d_label(expr_x, expr_y, label, use_cm)
  match range {
    Tuple([variable, start, end]) if is_plot_range(range) =>
      {
        expr_x,
        expr_y,
        variable,
        start,
        end,
        label: resolved_label,
        rendering_kw,
        adaptive,
        depth,
        only_integers,
        n,
        use_cm,
        xscale,
      }
    _ =>
      raise ValueError(
        "A plotting range must be a tuple of the form (symbol, start, end)",
      )
  }
}

///|
/// - Does: Stores one 3D parametric line-series specification and its sampling options.
/// - Input: Constructed from three expressions, one parameter range, and sampling metadata.
/// - Returns: One `Parametric3DLineSeries` value.
/// - Limits: Numeric range validation happens when sampling methods are called or through the constructor front door.
pub struct Parametric3DLineSeries {
  expr_x : @symcore.Expr
  expr_y : @symcore.Expr
  expr_z : @symcore.Expr
  variable : @symcore.Expr
  start : @symcore.Expr
  end : @symcore.Expr
  label : String?
  rendering_kw : Map[String, String]?
  adaptive : Bool
  depth : Int
  only_integers : Bool
  n : Int
  use_cm : Bool
  xscale : String
}

///|
/// - Does: Formats the 3D parametric line series for diagnostics.
/// - Input: One `Parametric3DLineSeries`.
/// - Returns: `String`.
/// - Limits: Output is intended for inspection and tests, so string format changes can break assertions.
pub fn Parametric3DLineSeries::to_string(
  self : Parametric3DLineSeries,
) -> String {
  "3D parametric cartesian line: (" +
  @symprint.pretty_string(self.expr_x) +
  ", " +
  @symprint.pretty_string(self.expr_y) +
  ", " +
  @symprint.pretty_string(self.expr_z) +
  ") for " +
  @symprint.pretty_string(self.variable) +
  " over (" +
  @symprint.pretty_string(self.start) +
  ", " +
  @symprint.pretty_string(self.end) +
  ")"
}

///|
/// - Does: Returns the parameter variable of one 3D parametric series.
/// - Input: One `Parametric3DLineSeries`.
/// - Returns: `Expr`.
/// - Limits: This is a shallow accessor.
pub fn Parametric3DLineSeries::plot_var(
  self : Parametric3DLineSeries,
) -> @symcore.Expr {
  self.variable
}

///|
/// - Does: Returns the configured point count of one 3D parametric series.
/// - Input: One `Parametric3DLineSeries`.
/// - Returns: `Int`.
/// - Limits: Current 3D parametric sampling is non-adaptive in the constructor path.
pub fn Parametric3DLineSeries::nb_of_points(
  self : Parametric3DLineSeries,
) -> Int {
  self.n
}

///|
/// - Does: Returns the display label of one 3D parametric series.
/// - Input: One `Parametric3DLineSeries`.
/// - Returns: `String`.
/// - Limits: Falls back to the parameter variable when no explicit label is stored.
pub fn Parametric3DLineSeries::get_label(
  self : Parametric3DLineSeries,
) -> String {
  match self.label {
    Some(label) => label
    None => @symprint.pretty_string(self.variable)
  }
}

///|
/// - Does: Returns the sampled parameter values of one 3D parametric series.
/// - Input: One `Parametric3DLineSeries`.
/// - Returns: `Array[Double]`.
/// - Limits: Raises the same `PlottingError` cases as `get_data`.
pub fn Parametric3DLineSeries::get_parameter_points(
  self : Parametric3DLineSeries,
) -> Array[Double] raise PlottingError {
  let (_, _, _, params) = self.get_data()
  params
}

///|
/// - Does: Returns sampled 3D points of one 3D parametric series.
/// - Input: One `Parametric3DLineSeries`.
/// - Returns: `(Array[Double?], Array[Double?], Array[Double?])`.
/// - Limits: Raises the same `PlottingError` cases as `get_data`.
pub fn Parametric3DLineSeries::get_points(
  self : Parametric3DLineSeries,
) -> (Array[Double?], Array[Double?], Array[Double?]) raise PlottingError {
  let (xs, ys, zs, _) = self.get_data()
  (xs, ys, zs)
}

///|
/// - Does: Samples 3D data and parameter values for one 3D parametric series.
/// - Input: One `Parametric3DLineSeries`.
/// - Returns: `(Array[Double?], Array[Double?], Array[Double?], Array[Double])`.
/// - Limits: Raises `PlottingError::ValueError` when bounds are not numeric or when complex-range endpoints do not share the same imaginary part.
pub fn Parametric3DLineSeries::get_data(
  self : Parametric3DLineSeries,
) -> (Array[Double?], Array[Double?], Array[Double?], Array[Double]) raise PlottingError {
  let (start_real, start_imag) = match plot_expr_to_complex_parts(self.start) {
    Some(value) => value
    None =>
      raise ValueError("Parametric3DLineSeries requires numeric range bounds")
  }
  let (end_real, end_imag) = match plot_expr_to_complex_parts(self.end) {
    Some(value) => value
    None =>
      raise ValueError("Parametric3DLineSeries requires numeric range bounds")
  }
  if (start_imag - end_imag).abs() > 1.0e-8 {
    raise ValueError(
      "Parametric3DLineSeries requires the imaginary part of the start and end values of the range to be the same.",
    )
  }
  let params = plot_discretize(
    start_real,
    end_real,
    self.n,
    self.xscale,
    self.only_integers,
  )
  let xs : Array[Double?] = []
  let ys : Array[Double?] = []
  let zs : Array[Double?] = []
  for value in params {
    xs.push(plot_eval_real_value(self.expr_x, self.variable, value, start_imag))
    ys.push(plot_eval_real_value(self.expr_y, self.variable, value, start_imag))
    zs.push(plot_eval_real_value(self.expr_z, self.variable, value, start_imag))
  }
  (xs, ys, zs, params)
}

///|
/// - Does: Builds a 3D parametric line-series object from three expressions and a parameter range tuple.
/// - Input: Three expressions, one `(symbol, start, end)` range tuple, and optional sampling metadata.
/// - Returns: `Parametric3DLineSeries`.
/// - Limits: Raises `PlottingError::ValueError` unless the range has the accepted tuple shape.
pub fn parametric_3d_line_series(
  expr_x : @symcore.Expr,
  expr_y : @symcore.Expr,
  expr_z : @symcore.Expr,
  range : @symcore.Expr,
  label? : String? = None,
  rendering_kw? : Map[String, String]? = None,
  adaptive? : Bool = false,
  depth? : Int = 12,
  only_integers? : Bool = false,
  n? : Int = 1000,
  use_cm? : Bool = true,
  xscale? : String = "linear",
) -> Parametric3DLineSeries raise PlottingError {
  let resolved_label = plot_parametric_3d_label(
    expr_x, expr_y, expr_z, label, use_cm,
  )
  ignore(adaptive)
  match range {
    Tuple([variable, start, end]) if is_plot_range(range) =>
      {
        expr_x,
        expr_y,
        expr_z,
        variable,
        start,
        end,
        label: resolved_label,
        rendering_kw,
        adaptive: false,
        depth,
        only_integers,
        n,
        use_cm,
        xscale,
      }
    _ =>
      raise ValueError(
        "A plotting range must be a tuple of the form (symbol, start, end)",
      )
  }
}

///|
/// - Does: Stores one Cartesian surface-series specification and its mesh settings.
/// - Input: Constructed from one expression, two ranges, and mesh metadata.
/// - Returns: One `SurfaceOver2DRangeSeries` value.
/// - Limits: Numeric range validation happens when sampling methods are called or through the constructor front door.
pub struct SurfaceOver2DRangeSeries {
  expr : @symcore.Expr
  variable_x : @symcore.Expr
  start_x : @symcore.Expr
  end_x : @symcore.Expr
  variable_y : @symcore.Expr
  start_y : @symcore.Expr
  end_y : @symcore.Expr
  label : String?
  rendering_kw : Map[String, String]?
  adaptive : Bool
  n1 : Int
  n2 : Int
  use_cm : Bool
  xscale : String
  yscale : String
}

///|
/// - Does: Formats the Cartesian surface series for diagnostics.
/// - Input: One `SurfaceOver2DRangeSeries`.
/// - Returns: `String`.
/// - Limits: Output is intended for inspection and tests, so string format changes can break assertions.
pub fn SurfaceOver2DRangeSeries::to_string(
  self : SurfaceOver2DRangeSeries,
) -> String {
  "cartesian surface: " +
  @symprint.pretty_string(self.expr) +
  " for " +
  @symprint.pretty_string(self.variable_x) +
  " over (" +
  @symprint.pretty_string(self.start_x) +
  ", " +
  @symprint.pretty_string(self.end_x) +
  ") and " +
  @symprint.pretty_string(self.variable_y) +
  " over (" +
  @symprint.pretty_string(self.start_y) +
  ", " +
  @symprint.pretty_string(self.end_y) +
  ")"
}

///|
/// - Does: Returns the configured x-direction mesh size of one surface series.
/// - Input: One `SurfaceOver2DRangeSeries`.
/// - Returns: `Int`.
/// - Limits: This is a shallow accessor.
pub fn SurfaceOver2DRangeSeries::nb_of_points_x(
  self : SurfaceOver2DRangeSeries,
) -> Int {
  self.n1
}

///|
/// - Does: Returns the configured y-direction mesh size of one surface series.
/// - Input: One `SurfaceOver2DRangeSeries`.
/// - Returns: `Int`.
/// - Limits: This is a shallow accessor.
pub fn SurfaceOver2DRangeSeries::nb_of_points_y(
  self : SurfaceOver2DRangeSeries,
) -> Int {
  self.n2
}

///|
/// - Does: Returns the display label of one surface series.
/// - Input: One `SurfaceOver2DRangeSeries`.
/// - Returns: `String`.
/// - Limits: Falls back to the plotted expression when no explicit label is stored.
pub fn SurfaceOver2DRangeSeries::get_label(
  self : SurfaceOver2DRangeSeries,
) -> String {
  match self.label {
    Some(label) => label
    None => @symprint.pretty_string(self.expr)
  }
}

///|
/// - Does: Returns sampled meshes for one Cartesian surface series.
/// - Input: One `SurfaceOver2DRangeSeries`.
/// - Returns: `(Array[Array[Double]], Array[Array[Double]], Array[Array[Double?]])`.
/// - Limits: Raises the same `PlottingError` cases as `get_data`.
pub fn SurfaceOver2DRangeSeries::get_points(
  self : SurfaceOver2DRangeSeries,
) -> (Array[Array[Double]], Array[Array[Double]], Array[Array[Double?]]) raise PlottingError {
  self.get_data()
}

///|
/// - Does: Samples mesh data for one Cartesian surface series.
/// - Input: One `SurfaceOver2DRangeSeries`.
/// - Returns: `(Array[Array[Double]], Array[Array[Double]], Array[Array[Double?]])`.
/// - Limits: Raises `PlottingError::ValueError` when bounds are not numeric or when complex-range endpoints do not share the same imaginary part.
pub fn SurfaceOver2DRangeSeries::get_data(
  self : SurfaceOver2DRangeSeries,
) -> (Array[Array[Double]], Array[Array[Double]], Array[Array[Double?]]) raise PlottingError {
  let (start_x_real, start_x_imag) = match
    plot_expr_to_complex_parts(self.start_x) {
    Some(value) => value
    None =>
      raise ValueError(
        "SurfaceOver2DRangeSeries requires numeric x range bounds",
      )
  }
  let (end_x_real, end_x_imag) = match plot_expr_to_complex_parts(self.end_x) {
    Some(value) => value
    None =>
      raise ValueError(
        "SurfaceOver2DRangeSeries requires numeric x range bounds",
      )
  }
  let (start_y_real, start_y_imag) = match
    plot_expr_to_complex_parts(self.start_y) {
    Some(value) => value
    None =>
      raise ValueError(
        "SurfaceOver2DRangeSeries requires numeric y range bounds",
      )
  }
  let (end_y_real, end_y_imag) = match plot_expr_to_complex_parts(self.end_y) {
    Some(value) => value
    None =>
      raise ValueError(
        "SurfaceOver2DRangeSeries requires numeric y range bounds",
      )
  }
  if (start_x_imag - end_x_imag).abs() > 1.0e-8 {
    raise ValueError(
      "SurfaceOver2DRangeSeries requires the imaginary part of the start and end values of the x range to be the same.",
    )
  }
  if (start_y_imag - end_y_imag).abs() > 1.0e-8 {
    raise ValueError(
      "SurfaceOver2DRangeSeries requires the imaginary part of the start and end values of the y range to be the same.",
    )
  }
  let xs = plot_discretize(
    start_x_real,
    end_x_real,
    self.n1,
    self.xscale,
    false,
  )
  let ys = plot_discretize(
    start_y_real,
    end_y_real,
    self.n2,
    self.yscale,
    false,
  )
  let (mesh_x, mesh_y) = plot_meshgrid(xs, ys)
  let mesh_z : Array[Array[Double?]] = []
  for y in ys {
    let row_z : Array[Double?] = []
    for x in xs {
      row_z.push(
        plot_eval_real_value_2d(
          self.expr,
          self.variable_x,
          x,
          start_x_imag,
          self.variable_y,
          y,
          start_y_imag,
        ),
      )
    }
    mesh_z.push(row_z)
  }
  (mesh_x, mesh_y, mesh_z)
}

///|
/// - Does: Builds a Cartesian surface-series object from one expression and two range tuples.
/// - Input: One expression, two `(symbol, start, end)` range tuples, and optional mesh metadata.
/// - Returns: `SurfaceOver2DRangeSeries`.
/// - Limits: Raises `PlottingError::ValueError` unless both ranges have the accepted tuple shape.
pub fn surface_over_2d_range_series(
  expr : @symcore.Expr,
  range_x : @symcore.Expr,
  range_y : @symcore.Expr,
  label? : String? = None,
  rendering_kw? : Map[String, String]? = None,
  adaptive? : Bool = false,
  n1? : Int = 100,
  n2? : Int = 100,
  use_cm? : Bool = false,
  xscale? : String = "linear",
  yscale? : String = "linear",
) -> SurfaceOver2DRangeSeries raise PlottingError {
  let resolved_label = plot_surface_label(expr, label)
  ignore(adaptive)
  match (range_x, range_y) {
    (Tuple([variable_x, start_x, end_x]), Tuple([variable_y, start_y, end_y])) if is_plot_range(
        range_x,
      ) &&
      is_plot_range(range_y) =>
      {
        expr,
        variable_x,
        start_x,
        end_x,
        variable_y,
        start_y,
        end_y,
        label: resolved_label,
        rendering_kw,
        adaptive: false,
        n1,
        n2,
        use_cm,
        xscale,
        yscale,
      }
    _ =>
      raise ValueError(
        "A plotting range must be a tuple of the form (symbol, start, end)",
      )
  }
}

///|
/// - Does: Stores one parametric surface-series specification and its mesh settings.
/// - Input: Constructed from three expressions, two parameter ranges, and mesh metadata.
/// - Returns: One `ParametricSurfaceSeries` value.
/// - Limits: Numeric range validation happens when sampling methods are called or through the constructor front door.
pub struct ParametricSurfaceSeries {
  expr_x : @symcore.Expr
  expr_y : @symcore.Expr
  expr_z : @symcore.Expr
  variable_u : @symcore.Expr
  start_u : @symcore.Expr
  end_u : @symcore.Expr
  variable_v : @symcore.Expr
  start_v : @symcore.Expr
  end_v : @symcore.Expr
  label : String?
  rendering_kw : Map[String, String]?
  adaptive : Bool
  n1 : Int
  n2 : Int
  use_cm : Bool
  xscale : String
  yscale : String
}

///|
/// - Does: Formats the parametric surface series for diagnostics.
/// - Input: One `ParametricSurfaceSeries`.
/// - Returns: `String`.
/// - Limits: Output is intended for inspection and tests, so string format changes can break assertions.
pub fn ParametricSurfaceSeries::to_string(
  self : ParametricSurfaceSeries,
) -> String {
  "parametric cartesian surface: (" +
  @symprint.pretty_string(self.expr_x) +
  ", " +
  @symprint.pretty_string(self.expr_y) +
  ", " +
  @symprint.pretty_string(self.expr_z) +
  ") for " +
  @symprint.pretty_string(self.variable_u) +
  " over (" +
  @symprint.pretty_string(self.start_u) +
  ", " +
  @symprint.pretty_string(self.end_u) +
  ") and " +
  @symprint.pretty_string(self.variable_v) +
  " over (" +
  @symprint.pretty_string(self.start_v) +
  ", " +
  @symprint.pretty_string(self.end_v) +
  ")"
}

///|
/// - Does: Returns the configured u-direction mesh size of one parametric surface series.
/// - Input: One `ParametricSurfaceSeries`.
/// - Returns: `Int`.
/// - Limits: This is a shallow accessor.
pub fn ParametricSurfaceSeries::nb_of_points_u(
  self : ParametricSurfaceSeries,
) -> Int {
  self.n1
}

///|
/// - Does: Returns the configured v-direction mesh size of one parametric surface series.
/// - Input: One `ParametricSurfaceSeries`.
/// - Returns: `Int`.
/// - Limits: This is a shallow accessor.
pub fn ParametricSurfaceSeries::nb_of_points_v(
  self : ParametricSurfaceSeries,
) -> Int {
  self.n2
}

///|
/// - Does: Returns the display label of one parametric surface series.
/// - Input: One `ParametricSurfaceSeries`.
/// - Returns: `String`.
/// - Limits: Falls back to the expression triple when no explicit label is stored.
pub fn ParametricSurfaceSeries::get_label(
  self : ParametricSurfaceSeries,
) -> String {
  match self.label {
    Some(label) => label
    None =>
      "(" +
      @symprint.pretty_string(self.expr_x) +
      ", " +
      @symprint.pretty_string(self.expr_y) +
      ", " +
      @symprint.pretty_string(self.expr_z) +
      ")"
  }
}

///|
/// - Does: Returns sampled parameter meshes of one parametric surface series.
/// - Input: One `ParametricSurfaceSeries`.
/// - Returns: `(Array[Array[Double]], Array[Array[Double]])`.
/// - Limits: Raises the same `PlottingError` cases as `get_data`.
pub fn ParametricSurfaceSeries::get_parameter_meshes(
  self : ParametricSurfaceSeries,
) -> (Array[Array[Double]], Array[Array[Double]]) raise PlottingError {
  let (_, _, _, mesh_u, mesh_v) = self.get_data()
  (mesh_u, mesh_v)
}

///|
/// - Does: Returns sampled x/y/z meshes of one parametric surface series.
/// - Input: One `ParametricSurfaceSeries`.
/// - Returns: `(Array[Array[Double?]], Array[Array[Double?]], Array[Array[Double?]])`.
/// - Limits: Raises the same `PlottingError` cases as `get_data`.
pub fn ParametricSurfaceSeries::get_meshes(
  self : ParametricSurfaceSeries,
) -> (Array[Array[Double?]], Array[Array[Double?]], Array[Array[Double?]]) raise PlottingError {
  let (mesh_x, mesh_y, mesh_z, _, _) = self.get_data()
  (mesh_x, mesh_y, mesh_z)
}

///|
/// - Does: Samples x/y/z meshes and parameter meshes for one parametric surface series.
/// - Input: One `ParametricSurfaceSeries`.
/// - Returns: `(Array[Array[Double?]], Array[Array[Double?]], Array[Array[Double?]], Array[Array[Double]], Array[Array[Double]])`.
/// - Limits: Raises `PlottingError::ValueError` when bounds are not numeric or when complex-range endpoints do not share the same imaginary part.
pub fn ParametricSurfaceSeries::get_data(
  self : ParametricSurfaceSeries,
) -> (
  Array[Array[Double?]],
  Array[Array[Double?]],
  Array[Array[Double?]],
  Array[Array[Double]],
  Array[Array[Double]],
) raise PlottingError {
  let (start_u_real, start_u_imag) = match
    plot_expr_to_complex_parts(self.start_u) {
    Some(value) => value
    None =>
      raise ValueError(
        "ParametricSurfaceSeries requires numeric u range bounds",
      )
  }
  let (end_u_real, end_u_imag) = match plot_expr_to_complex_parts(self.end_u) {
    Some(value) => value
    None =>
      raise ValueError(
        "ParametricSurfaceSeries requires numeric u range bounds",
      )
  }
  let (start_v_real, start_v_imag) = match
    plot_expr_to_complex_parts(self.start_v) {
    Some(value) => value
    None =>
      raise ValueError(
        "ParametricSurfaceSeries requires numeric v range bounds",
      )
  }
  let (end_v_real, end_v_imag) = match plot_expr_to_complex_parts(self.end_v) {
    Some(value) => value
    None =>
      raise ValueError(
        "ParametricSurfaceSeries requires numeric v range bounds",
      )
  }
  if (start_u_imag - end_u_imag).abs() > 1.0e-8 {
    raise ValueError(
      "ParametricSurfaceSeries requires the imaginary part of the start and end values of the u range to be the same.",
    )
  }
  if (start_v_imag - end_v_imag).abs() > 1.0e-8 {
    raise ValueError(
      "ParametricSurfaceSeries requires the imaginary part of the start and end values of the v range to be the same.",
    )
  }
  let us = plot_discretize(
    start_u_real,
    end_u_real,
    self.n1,
    self.xscale,
    false,
  )
  let vs = plot_discretize(
    start_v_real,
    end_v_real,
    self.n2,
    self.yscale,
    false,
  )
  let (mesh_u, mesh_v) = plot_meshgrid(us, vs)
  let mesh_x : Array[Array[Double?]] = []
  let mesh_y : Array[Array[Double?]] = []
  let mesh_z : Array[Array[Double?]] = []
  for v in vs {
    let row_x : Array[Double?] = []
    let row_y : Array[Double?] = []
    let row_z : Array[Double?] = []
    for u in us {
      row_x.push(
        plot_eval_real_value_2d(
          self.expr_x,
          self.variable_u,
          u,
          start_u_imag,
          self.variable_v,
          v,
          start_v_imag,
        ),
      )
      row_y.push(
        plot_eval_real_value_2d(
          self.expr_y,
          self.variable_u,
          u,
          start_u_imag,
          self.variable_v,
          v,
          start_v_imag,
        ),
      )
      row_z.push(
        plot_eval_real_value_2d(
          self.expr_z,
          self.variable_u,
          u,
          start_u_imag,
          self.variable_v,
          v,
          start_v_imag,
        ),
      )
    }
    mesh_x.push(row_x)
    mesh_y.push(row_y)
    mesh_z.push(row_z)
  }
  (mesh_x, mesh_y, mesh_z, mesh_u, mesh_v)
}

///|
/// - Does: Builds a parametric surface-series object from three expressions and two range tuples.
/// - Input: Three expressions, two `(symbol, start, end)` range tuples, and optional mesh metadata.
/// - Returns: `ParametricSurfaceSeries`.
/// - Limits: Raises `PlottingError::ValueError` unless both ranges have the accepted tuple shape.
pub fn parametric_surface_series(
  expr_x : @symcore.Expr,
  expr_y : @symcore.Expr,
  expr_z : @symcore.Expr,
  range_u : @symcore.Expr,
  range_v : @symcore.Expr,
  label? : String? = None,
  rendering_kw? : Map[String, String]? = None,
  adaptive? : Bool = false,
  n1? : Int = 100,
  n2? : Int = 100,
  use_cm? : Bool = false,
  xscale? : String = "linear",
  yscale? : String = "linear",
) -> ParametricSurfaceSeries raise PlottingError {
  let resolved_label = plot_parametric_surface_label(
    expr_x, expr_y, expr_z, label,
  )
  ignore(adaptive)
  match (range_u, range_v) {
    (Tuple([variable_u, start_u, end_u]), Tuple([variable_v, start_v, end_v])) if is_plot_range(
        range_u,
      ) &&
      is_plot_range(range_v) =>
      {
        expr_x,
        expr_y,
        expr_z,
        variable_u,
        start_u,
        end_u,
        variable_v,
        start_v,
        end_v,
        label: resolved_label,
        rendering_kw,
        adaptive: false,
        n1,
        n2,
        use_cm,
        xscale,
        yscale,
      }
    _ =>
      raise ValueError(
        "A plotting range must be a tuple of the form (symbol, start, end)",
      )
  }
}

///|
/// - Does: Stores one contour-series specification and its mesh settings.
/// - Input: Constructed from one expression, two ranges, and mesh metadata.
/// - Returns: One `ContourSeries` value.
/// - Limits: Numeric range validation happens when sampling methods are called or through the constructor front door.
pub struct ContourSeries {
  expr : @symcore.Expr
  variable_x : @symcore.Expr
  start_x : @symcore.Expr
  end_x : @symcore.Expr
  variable_y : @symcore.Expr
  start_y : @symcore.Expr
  end_y : @symcore.Expr
  label : String?
  rendering_kw : Map[String, String]?
  adaptive : Bool
  n1 : Int
  n2 : Int
  use_cm : Bool
  xscale : String
  yscale : String
}

///|
/// - Does: Formats the contour series for diagnostics.
/// - Input: One `ContourSeries`.
/// - Returns: `String`.
/// - Limits: Output is intended for inspection and tests, so string format changes can break assertions.
pub fn ContourSeries::to_string(self : ContourSeries) -> String {
  "contour: " +
  @symprint.pretty_string(self.expr) +
  " for " +
  @symprint.pretty_string(self.variable_x) +
  " over (" +
  @symprint.pretty_string(self.start_x) +
  ", " +
  @symprint.pretty_string(self.end_x) +
  ") and " +
  @symprint.pretty_string(self.variable_y) +
  " over (" +
  @symprint.pretty_string(self.start_y) +
  ", " +
  @symprint.pretty_string(self.end_y) +
  ")"
}

///|
/// - Does: Returns the display label of one contour series.
/// - Input: One `ContourSeries`.
/// - Returns: `String`.
/// - Limits: Falls back to the plotted expression when no explicit label is stored.
pub fn ContourSeries::get_label(self : ContourSeries) -> String {
  match self.label {
    Some(label) => label
    None => @symprint.pretty_string(self.expr)
  }
}

///|
/// - Does: Samples mesh data for one contour series.
/// - Input: One `ContourSeries`.
/// - Returns: `(Array[Array[Double]], Array[Array[Double]], Array[Array[Double?]])`.
/// - Limits: Raises the same `PlottingError` cases as the underlying surface-series sampler.
pub fn ContourSeries::get_data(
  self : ContourSeries,
) -> (Array[Array[Double]], Array[Array[Double]], Array[Array[Double?]]) raise PlottingError {
  surface_over_2d_range_series(
    self.expr,
    Tuple([self.variable_x, self.start_x, self.end_x]),
    Tuple([self.variable_y, self.start_y, self.end_y]),
    label=self.label,
    rendering_kw=self.rendering_kw,
    adaptive=self.adaptive,
    n1=self.n1,
    n2=self.n2,
    use_cm=self.use_cm,
    xscale=self.xscale,
    yscale=self.yscale,
  ).get_data()
}

///|
/// - Does: Builds a contour-series object from one expression and two range tuples.
/// - Input: One expression, two `(symbol, start, end)` range tuples, and optional mesh metadata.
/// - Returns: `ContourSeries`.
/// - Limits: Raises the same `PlottingError` cases as `surface_over_2d_range_series`.
pub fn contour_series(
  expr : @symcore.Expr,
  range_x : @symcore.Expr,
  range_y : @symcore.Expr,
  label? : String? = None,
  rendering_kw? : Map[String, String]? = None,
  adaptive? : Bool = false,
  n1? : Int = 100,
  n2? : Int = 100,
  use_cm? : Bool = false,
  xscale? : String = "linear",
  yscale? : String = "linear",
) -> ContourSeries raise PlottingError {
  let surface = surface_over_2d_range_series(
    expr,
    range_x,
    range_y,
    label~,
    rendering_kw~,
    adaptive~,
    n1~,
    n2~,
    use_cm~,
    xscale~,
    yscale~,
  )
  {
    expr: surface.expr,
    variable_x: surface.variable_x,
    start_x: surface.start_x,
    end_x: surface.end_x,
    variable_y: surface.variable_y,
    start_y: surface.start_y,
    end_y: surface.end_y,
    label: surface.label,
    rendering_kw: surface.rendering_kw,
    adaptive: surface.adaptive,
    n1: surface.n1,
    n2: surface.n2,
    use_cm: surface.use_cm,
    xscale: surface.xscale,
    yscale: surface.yscale,
  }
}

///|
/// - Does: Stores one implicit-series specification and its sampling settings.
/// - Input: Constructed from one expression, two ranges, and adaptive/mesh metadata.
/// - Returns: One `ImplicitSeries` value.
/// - Limits: Numeric range validation happens when sampling methods are called or through the constructor front door.
pub struct ImplicitSeries {
  expr : @symcore.Expr
  variable_x : @symcore.Expr
  start_x : @symcore.Expr
  end_x : @symcore.Expr
  variable_y : @symcore.Expr
  start_y : @symcore.Expr
  end_y : @symcore.Expr
  label : String?
  adaptive : Bool
  depth : Int
  n : Int
  n1 : Int
  n2 : Int
  line_color : String
  xscale : String
  yscale : String
}

///|
/// - Does: Formats the implicit series for diagnostics.
/// - Input: One `ImplicitSeries`.
/// - Returns: `String`.
/// - Limits: Output is intended for inspection and tests, so string format changes can break assertions.
pub fn ImplicitSeries::to_string(self : ImplicitSeries) -> String {
  "Implicit expression: " +
  @symprint.pretty_string(self.expr) +
  " for " +
  @symprint.pretty_string(self.variable_x) +
  " over (" +
  @symprint.pretty_string(self.start_x) +
  ", " +
  @symprint.pretty_string(self.end_x) +
  ") and " +
  @symprint.pretty_string(self.variable_y) +
  " over (" +
  @symprint.pretty_string(self.start_y) +
  ", " +
  @symprint.pretty_string(self.end_y) +
  ")"
}

///|
/// - Does: Returns the display label of one implicit series.
/// - Input: One `ImplicitSeries`.
/// - Returns: `String`.
/// - Limits: Falls back to the plotted expression when no explicit label is stored.
pub fn ImplicitSeries::get_label(self : ImplicitSeries) -> String {
  match self.label {
    Some(label) => label
    None => @symprint.pretty_string(self.expr)
  }
}

///|
/// - Does: Samples implicit-plot output as either fill rectangles or mesh data.
/// - Input: One `ImplicitSeries`.
/// - Returns: `ImplicitPlotData`.
/// - Limits: Raises `PlottingError::ValueError` when bounds are not numeric or when complex-range endpoints do not share the same imaginary part.
pub fn ImplicitSeries::get_data(
  self : ImplicitSeries,
) -> ImplicitPlotData raise PlottingError {
  let (start_x_real, start_x_imag) = match
    plot_expr_to_complex_parts(self.start_x) {
    Some(value) => value
    None => raise ValueError("ImplicitSeries requires numeric x range bounds")
  }
  let (end_x_real, end_x_imag) = match plot_expr_to_complex_parts(self.end_x) {
    Some(value) => value
    None => raise ValueError("ImplicitSeries requires numeric x range bounds")
  }
  let (start_y_real, start_y_imag) = match
    plot_expr_to_complex_parts(self.start_y) {
    Some(value) => value
    None => raise ValueError("ImplicitSeries requires numeric y range bounds")
  }
  let (end_y_real, end_y_imag) = match plot_expr_to_complex_parts(self.end_y) {
    Some(value) => value
    None => raise ValueError("ImplicitSeries requires numeric y range bounds")
  }
  if (start_x_imag - end_x_imag).abs() > 1.0e-8 {
    raise ValueError(
      "ImplicitSeries requires the imaginary part of the start and end values of the x range to be the same.",
    )
  }
  if (start_y_imag - end_y_imag).abs() > 1.0e-8 {
    raise ValueError(
      "ImplicitSeries requires the imaginary part of the start and end values of the y range to be the same.",
    )
  }
  if self.adaptive {
    match
      plot_implicit_interval_fill(
        self.expr,
        self.variable_x,
        start_x_real,
        start_x_imag,
        end_x_real,
        self.variable_y,
        start_y_real,
        start_y_imag,
        end_y_real,
        self.depth,
      ) {
      Some(rectangles) => return Fill(rectangles)
      None => ()
    }
    let rectangles : Array[ImplicitRectangle] = []
    let pending : Array[(ImplicitRectangle, Int)] = [
      (
        {
          x_start: start_x_real,
          x_end: end_x_real,
          y_start: start_y_real,
          y_end: end_y_real,
        },
        self.depth,
      ),
    ]
    while !pending.is_empty() {
      let (rect, remaining_depth) = pending.pop().unwrap()
      if plot_implicit_plot_type(self.expr) == "contour" {
        if !plot_implicit_equality_candidate(
            self.expr,
            self.variable_x,
            start_x_imag,
            self.variable_y,
            start_y_imag,
            rect,
          ) {
          continue
        }
        if remaining_depth <= 0 {
          rectangles.push(rect)
        } else {
          for child in plot_implicit_subdivide_rect(rect) {
            pending.push((child, remaining_depth - 1))
          }
        }
      } else {
        let (saw_true, saw_false, saw_unknown) = plot_implicit_boolean_candidate(
          self.expr,
          self.variable_x,
          start_x_imag,
          self.variable_y,
          start_y_imag,
          rect,
        )
        if saw_true && !saw_false && !saw_unknown {
          rectangles.push(rect)
        } else if !saw_true && saw_false && !saw_unknown {
          continue
        } else if remaining_depth <= 0 {
          if saw_true || saw_unknown {
            rectangles.push(rect)
          }
        } else {
          for child in plot_implicit_subdivide_rect(rect) {
            pending.push((child, remaining_depth - 1))
          }
        }
      }
    }
    return Fill(rectangles)
  }
  let xs = plot_discretize(
    start_x_real,
    end_x_real,
    self.n1,
    self.xscale,
    false,
  )
  let ys = plot_discretize(
    start_y_real,
    end_y_real,
    self.n2,
    self.yscale,
    false,
  )
  let (mesh_x, mesh_y) = plot_meshgrid(xs, ys)
  let mesh_z : Array[Array[Double?]] = []
  for y in ys {
    let row_z : Array[Double?] = []
    for x in xs {
      match plot_implicit_plot_type(self.expr) {
        "contour" =>
          row_z.push(
            plot_implicit_eval_real_2d(
              plot_implicit_scalar_expr(self.expr),
              self.variable_x,
              x,
              start_x_imag,
              self.variable_y,
              y,
              start_y_imag,
            ),
          )
        _ =>
          row_z.push(
            match
              plot_implicit_boolean_expr(
                self.expr,
                self.variable_x,
                x,
                start_x_imag,
                self.variable_y,
                y,
                start_y_imag,
              ) {
              Some(true) => Some(1.0)
              Some(false) => Some(0.0)
              None => None
            },
          )
      }
    }
    mesh_z.push(row_z)
  }
  Mesh(mesh_x, mesh_y, mesh_z, plot_implicit_plot_type(self.expr))
}

///|
/// - Does: Builds an implicit-series object from one expression and two range tuples.
/// - Input: One expression, two `(symbol, start, end)` range tuples, and optional adaptive/mesh metadata.
/// - Returns: `ImplicitSeries`.
/// - Limits: Raises `PlottingError::ValueError` unless both ranges have the accepted tuple shape.
pub fn implicit_series(
  expr : @symcore.Expr,
  range_x : @symcore.Expr,
  range_y : @symcore.Expr,
  adaptive? : Bool = true,
  depth? : Int = 0,
  n? : Int = 300,
  n1? : Int? = None,
  n2? : Int? = None,
  line_color? : String = "blue",
  label? : String? = None,
  xscale? : String = "linear",
  yscale? : String = "linear",
) -> ImplicitSeries raise PlottingError {
  let clamped_depth = if depth < 0 { 0 } else if depth > 4 { 4 } else { depth }
  let resolved_label = plot_surface_label(expr, label)
  let resolved_adaptive = adaptive || plot_implicit_requires_adaptive(expr)
  let resolved_n1 = match n1 {
    Some(value) => value
    None => n
  }
  let resolved_n2 = match n2 {
    Some(value) => value
    None => n
  }
  match (range_x, range_y) {
    (Tuple([variable_x, start_x, end_x]), Tuple([variable_y, start_y, end_y])) if is_plot_range(
        range_x,
      ) &&
      is_plot_range(range_y) =>
      {
        expr,
        variable_x,
        start_x,
        end_x,
        variable_y,
        start_y,
        end_y,
        label: resolved_label,
        adaptive: resolved_adaptive,
        depth: 4 + clamped_depth,
        n,
        n1: resolved_n1,
        n2: resolved_n2,
        line_color,
        xscale,
        yscale,
      }
    _ =>
      raise ValueError(
        "A plotting range must be a tuple of the form (symbol, start, end)",
      )
  }
}

///|
/// - Does: Enumerates every series kind that can be stored in a `Plot`.
/// - Input: One concrete series value.
/// - Returns: One `PlotSeries` value.
/// - Limits: Only the listed series kinds are representable here.
pub enum PlotSeries {
  Line(LineOver1DRangeSeries)
  Parametric2D(Parametric2DLineSeries)
  Parametric3D(Parametric3DLineSeries)
  Surface(SurfaceOver2DRangeSeries)
  ParametricSurface(ParametricSurfaceSeries)
  Contour(ContourSeries)
  Implicit(ImplicitSeries)
}

///|
/// - Does: Formats one plot-series value for diagnostics.
/// - Input: One `PlotSeries`.
/// - Returns: `String`.
/// - Limits: Output is intended for inspection and tests, so string format changes can break assertions.
pub fn PlotSeries::to_string(self : PlotSeries) -> String {
  match self {
    Line(series) => series.to_string()
    Parametric2D(series) => series.to_string()
    Parametric3D(series) => series.to_string()
    Surface(series) => series.to_string()
    ParametricSurface(series) => series.to_string()
    Contour(series) => series.to_string()
    Implicit(series) => series.to_string()
  }
}
