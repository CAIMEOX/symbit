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
pub fn line_over_1d_range_series(
  expr : @symcore.Expr,
  range : @symcore.Expr,
  label? : String? = None,
  rendering_kw? : Map[String, String]? = None,
) -> LineOver1DRangeSeries raise PlottingError {
  match range {
    @symcore.Expr::Tuple([variable, start, end]) if is_plot_range(range) =>
      LineOver1DRangeSeries::{ expr, variable, start, end, label, rendering_kw }
    _ =>
      raise PlottingError::ValueError(
        "A plotting range must be a tuple of the form (symbol, start, end)",
      )
  }
}
