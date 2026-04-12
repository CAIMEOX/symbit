///|
/// Errors raised by the plotting package when inputs do not match the
/// supported plotting surface.
pub suberror PlottingError {
  ValueError(String)
  TypeError(String)
} derive(Eq, Debug)

///|
pub enum PlotInput {
  Expr(@symcore.Expr)
  Range(@symcore.Expr)
  Label(String)
  RenderingKw(Map[String, String])
  Group(Array[PlotInput])
}

///|
pub fn plot_expr(expr : @symcore.Expr) -> PlotInput {
  PlotInput::Expr(expr)
}

///|
pub fn plot_range(
  symbol : @symcore.Expr,
  start : @symcore.Expr,
  end : @symcore.Expr,
) -> PlotInput {
  PlotInput::Range(@symcore.Expr::Tuple([symbol, start, end]))
}

///|
pub fn plot_label(value : String) -> PlotInput {
  PlotInput::Label(value)
}

///|
pub fn plot_rendering_kw(value : Map[String, String]) -> PlotInput {
  PlotInput::RenderingKw(value)
}

///|
pub fn plot_group(items : Array[PlotInput]) -> PlotInput {
  PlotInput::Group(items)
}
