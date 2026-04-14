///|
/// Errors raised by the plotting package when inputs do not match the
/// supported plotting surface.
pub suberror PlottingError {
  ValueError(String)
  TypeError(String)
} derive(Eq, Debug)

///|
pub struct ImplicitRectangle {
  x_start : Double
  x_end : Double
  y_start : Double
  y_end : Double
}

///|
pub enum ImplicitPlotData {
  Mesh(
    Array[Array[Double]],
    Array[Array[Double]],
    Array[Array[Double?]],
    String
  )
  Fill(Array[ImplicitRectangle])
}

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

///|
pub enum ParametricPlotInput {
  Exprs(@symcore.Expr, @symcore.Expr)
  Range(@symcore.Expr)
  Label(String)
  RenderingKw(Map[String, String])
  Group(Array[ParametricPlotInput])
}

///|
pub fn plot_parametric_expr(
  expr_x : @symcore.Expr,
  expr_y : @symcore.Expr,
) -> ParametricPlotInput {
  ParametricPlotInput::Exprs(expr_x, expr_y)
}

///|
pub fn plot_parametric_range(
  symbol : @symcore.Expr,
  start : @symcore.Expr,
  end : @symcore.Expr,
) -> ParametricPlotInput {
  ParametricPlotInput::Range(@symcore.Expr::Tuple([symbol, start, end]))
}

///|
pub fn plot_parametric_label(value : String) -> ParametricPlotInput {
  ParametricPlotInput::Label(value)
}

///|
pub fn plot_parametric_rendering_kw(
  value : Map[String, String],
) -> ParametricPlotInput {
  ParametricPlotInput::RenderingKw(value)
}

///|
pub fn plot_parametric_group(
  items : Array[ParametricPlotInput],
) -> ParametricPlotInput {
  ParametricPlotInput::Group(items)
}

///|
pub enum Parametric3DPlotInput {
  Exprs(@symcore.Expr, @symcore.Expr, @symcore.Expr)
  Range(@symcore.Expr)
  Label(String)
  RenderingKw(Map[String, String])
  Group(Array[Parametric3DPlotInput])
}

///|
pub fn plot3d_parametric_line_expr(
  expr_x : @symcore.Expr,
  expr_y : @symcore.Expr,
  expr_z : @symcore.Expr,
) -> Parametric3DPlotInput {
  Parametric3DPlotInput::Exprs(expr_x, expr_y, expr_z)
}

///|
pub fn plot3d_parametric_line_range(
  symbol : @symcore.Expr,
  start : @symcore.Expr,
  end : @symcore.Expr,
) -> Parametric3DPlotInput {
  Parametric3DPlotInput::Range(@symcore.Expr::Tuple([symbol, start, end]))
}

///|
pub fn plot3d_parametric_line_label(value : String) -> Parametric3DPlotInput {
  Parametric3DPlotInput::Label(value)
}

///|
pub fn plot3d_parametric_line_rendering_kw(
  value : Map[String, String],
) -> Parametric3DPlotInput {
  Parametric3DPlotInput::RenderingKw(value)
}

///|
pub fn plot3d_parametric_line_group(
  items : Array[Parametric3DPlotInput],
) -> Parametric3DPlotInput {
  Parametric3DPlotInput::Group(items)
}

///|
pub fn plot3d_parametric_surface_expr(
  expr_x : @symcore.Expr,
  expr_y : @symcore.Expr,
  expr_z : @symcore.Expr,
) -> Parametric3DPlotInput {
  Parametric3DPlotInput::Exprs(expr_x, expr_y, expr_z)
}

///|
pub fn plot3d_parametric_surface_range(
  symbol : @symcore.Expr,
  start : @symcore.Expr,
  end : @symcore.Expr,
) -> Parametric3DPlotInput {
  Parametric3DPlotInput::Range(@symcore.Expr::Tuple([symbol, start, end]))
}

///|
pub fn plot3d_parametric_surface_label(value : String) -> Parametric3DPlotInput {
  Parametric3DPlotInput::Label(value)
}

///|
pub fn plot3d_parametric_surface_rendering_kw(
  value : Map[String, String],
) -> Parametric3DPlotInput {
  Parametric3DPlotInput::RenderingKw(value)
}

///|
pub fn plot3d_parametric_surface_group(
  items : Array[Parametric3DPlotInput],
) -> Parametric3DPlotInput {
  Parametric3DPlotInput::Group(items)
}
