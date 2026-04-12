///|
fn plot_symbol_like(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Symbol(_) | @symcore.Expr::Dummy(_, _) => true
    _ => false
  }
}

///|
pub fn is_plot_range(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Tuple([symbol, start, end]) =>
      plot_symbol_like(symbol) &&
      @symcore.is_number_atom(start) &&
      @symcore.is_number_atom(end)
    _ => false
  }
}

///|
pub struct LineOver1DRangeSeries {
  expr : @symcore.Expr
  variable : @symcore.Expr
  start : @symcore.Expr
  end : @symcore.Expr
  label : String?
  rendering_kw : Map[String, String]?
  adaptive : Bool
  only_integers : Bool
  n : Int
  return_mode : String?
  xscale : String
}

///|
pub fn LineOver1DRangeSeries::to_string(self : LineOver1DRangeSeries) -> String {
  "cartesian line: " +
  @symprint.to_string(self.expr) +
  " for " +
  @symprint.to_string(self.variable) +
  " over (" +
  @symprint.to_string(self.start) +
  ", " +
  @symprint.to_string(self.end) +
  ")"
}

///|
pub fn LineOver1DRangeSeries::plot_var(
  self : LineOver1DRangeSeries,
) -> @symcore.Expr {
  self.variable
}

///|
pub fn LineOver1DRangeSeries::nb_of_points(self : LineOver1DRangeSeries) -> Int {
  self.n
}

///|
fn plot_expr_to_double(expr : @symcore.Expr) -> Double? {
  match @symcore.evalf(expr, prec=80) {
    @symcore.Expr::Float(value) => Some(value.to_double()) catch { _ => None }
    @symcore.Expr::ComplexFloat(value) => {
      let imag = value.imag_part()
      if imag.format(dps=12).has_prefix("0") {
        Some(value.real_part().to_double()) catch {
          _ => None
        }
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn plot_eval_numeric(
  expr : @symcore.Expr,
  variable : @symcore.Expr,
  sample : Double,
) -> (Double, Double)? {
  let sample_expr = @symcore.Expr::Float(
    @symcore.Float::from_double(sample, prec=80),
  )
  let substituted = @symcore.xreplace(expr, [(variable, sample_expr)])
  let evaluated = @symcore.evalf(substituted, prec=80)
  match evaluated {
    @symcore.Expr::Float(value) =>
      Some((value.to_double(), 0.0)) catch {
        _ => None
      }
    @symcore.Expr::ComplexFloat(value) =>
      Some((value.real_part().to_double(), value.imag_part().to_double())) catch {
        _ => None
      }
    _ => None
  }
}

///|
fn plot_geomspace(
  start : Double,
  end : Double,
  count : Int,
) -> Array[Double] raise PlottingError {
  if start == 0.0 || end == 0.0 {
    raise PlottingError::ValueError("log scale requires non-zero range bounds")
  }
  if (start > 0.0 && end < 0.0) || (start < 0.0 && end > 0.0) {
    raise PlottingError::ValueError(
      "log scale requires start and end to have the same sign",
    )
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
  raise PlottingError::ValueError("unknown plotting scale: " + scale)
}

///|
pub fn LineOver1DRangeSeries::get_points(
  self : LineOver1DRangeSeries,
) -> (Array[Double], Array[Double?]) raise PlottingError {
  let start = match plot_expr_to_double(self.start) {
    Some(value) => value
    None =>
      raise PlottingError::ValueError(
        "LineOver1DRangeSeries requires numeric range bounds",
      )
  }
  let end = match plot_expr_to_double(self.end) {
    Some(value) => value
    None =>
      raise PlottingError::ValueError(
        "LineOver1DRangeSeries requires numeric range bounds",
      )
  }
  let xs = plot_discretize(start, end, self.n, self.xscale, self.only_integers)
  let ys : Array[Double?] = []
  for value in xs {
    match plot_eval_numeric(self.expr, self.variable, value) {
      Some((real, imag)) => {
        let output = match self.return_mode {
          None => if imag.abs() <= 1.0e-8 { Some(real) } else { None }
          Some("real") => Some(real)
          Some("imag") => Some(imag)
          Some("abs") => Some((real * real + imag * imag).sqrt())
          Some("arg") => Some(@math.atan2(imag, real))
          Some(other) =>
            raise PlottingError::ValueError(
              "`_return` not recognized. Received: " + other,
            )
        }
        ys.push(output)
      }
      None => ys.push(None)
    }
  }
  (xs, ys)
}

///|
pub fn LineOver1DRangeSeries::get_data(
  self : LineOver1DRangeSeries,
) -> (Array[Double], Array[Double?]) raise PlottingError {
  self.get_points()
}

///|
pub fn line_over_1d_range_series(
  expr : @symcore.Expr,
  range : @symcore.Expr,
  label? : String? = None,
  rendering_kw? : Map[String, String]? = None,
  adaptive? : Bool = false,
  only_integers? : Bool = false,
  n? : Int = 1000,
  return_mode? : String? = None,
  xscale? : String = "linear",
) -> LineOver1DRangeSeries raise PlottingError {
  let resolved_label = match label {
    Some(value) => Some(value)
    None => Some(@symprint.to_string(expr))
  }
  match range {
    @symcore.Expr::Tuple([variable, start, end]) if is_plot_range(range) =>
      LineOver1DRangeSeries::{
        expr,
        variable,
        start,
        end,
        label: resolved_label,
        rendering_kw,
        adaptive,
        only_integers,
        n,
        return_mode,
        xscale,
      }
    _ =>
      raise PlottingError::ValueError(
        "A plotting range must be a tuple of the form (symbol, start, end)",
      )
  }
}
