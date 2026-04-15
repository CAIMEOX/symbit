///|
/// Errors raised by the plotting package when inputs do not match the
/// supported plotting surface.
pub suberror PlottingError {
  ValueError(String)
  TypeError(String)
} derive(Eq, Debug)

///|
/// - Does: Stores one rectangle used by implicit-plot fill output.
/// - Input: Four `Double` bounds for `x` and `y`.
/// - Returns: One `ImplicitRectangle` value.
/// - Limits: Coordinates are assumed to already be numeric plot-space bounds.
pub struct ImplicitRectangle {
  x_start : Double
  x_end : Double
  y_start : Double
  y_end : Double
}

///|
/// - Does: Describes the sampled output of one implicit plot.
/// - Input: Either mesh arrays plus a plot-kind tag or a rectangle fill list.
/// - Returns: One `ImplicitPlotData` value.
/// - Limits: Only the mesh and fill shapes implemented by `plot_implicit` are representable here.
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
/// - Does: Describes one argument accepted by `plot`.
/// - Input: One expression, one range tuple, one label, rendering keywords, or one grouped input list.
/// - Returns: One `PlotInput` value.
/// - Limits: Range inputs must still satisfy the front-door validation performed by `plot`.
pub enum PlotInput {
  Expr(@symcore.Expr)
  Range(@symcore.Expr)
  Label(String)
  RenderingKw(Map[String, String])
  Group(Array[PlotInput])
}

///|
/// - Does: Wraps one scalar expression for `plot`.
/// - Input: One `Expr`.
/// - Returns: `PlotInput`.
/// - Limits: Shape validation is deferred to `plot`.
pub fn plot_expr(expr : @symcore.Expr) -> PlotInput {
  PlotInput::Expr(expr)
}

///|
/// - Does: Builds one range argument for `plot`.
/// - Input: One symbol-like expression plus start and end expressions.
/// - Returns: `PlotInput`.
/// - Limits: Validation is deferred to `plot`, so malformed ranges can still raise later.
pub fn plot_range(
  symbol : @symcore.Expr,
  start : @symcore.Expr,
  end : @symcore.Expr,
) -> PlotInput {
  PlotInput::Range(@symcore.Expr::Tuple([symbol, start, end]))
}

///|
/// - Does: Wraps one explicit series label for `plot`.
/// - Input: One `String`.
/// - Returns: `PlotInput`.
/// - Limits: Label interpretation is left to the plotting front door.
pub fn plot_label(value : String) -> PlotInput {
  PlotInput::Label(value)
}

///|
/// - Does: Wraps rendering keyword metadata for `plot`.
/// - Input: `Map[String, String]`.
/// - Returns: `PlotInput`.
/// - Limits: Keywords are stored structurally and are not validated here.
pub fn plot_rendering_kw(value : Map[String, String]) -> PlotInput {
  PlotInput::RenderingKw(value)
}

///|
/// - Does: Groups several `plot` inputs into one nested input item.
/// - Input: `Array[PlotInput]`.
/// - Returns: `PlotInput`.
/// - Limits: Group semantics are interpreted by `plot`, not by this constructor.
pub fn plot_group(items : Array[PlotInput]) -> PlotInput {
  PlotInput::Group(items)
}

///|
/// - Does: Describes one argument accepted by `plot_parametric`.
/// - Input: One expression pair, one range tuple, one label, rendering keywords, or one grouped input list.
/// - Returns: One `ParametricPlotInput` value.
/// - Limits: Range and grouping validation are deferred to `plot_parametric`.
pub enum ParametricPlotInput {
  Exprs(@symcore.Expr, @symcore.Expr)
  Range(@symcore.Expr)
  Label(String)
  RenderingKw(Map[String, String])
  Group(Array[ParametricPlotInput])
}

///|
/// - Does: Wraps one planar parametric expression pair.
/// - Input: Two expressions `(x(t), y(t))`.
/// - Returns: `ParametricPlotInput`.
/// - Limits: Validation is deferred to `plot_parametric`.
pub fn plot_parametric_expr(
  expr_x : @symcore.Expr,
  expr_y : @symcore.Expr,
) -> ParametricPlotInput {
  ParametricPlotInput::Exprs(expr_x, expr_y)
}

///|
/// - Does: Builds one range argument for `plot_parametric`.
/// - Input: One symbol-like expression plus start and end expressions.
/// - Returns: `ParametricPlotInput`.
/// - Limits: Validation is deferred to `plot_parametric`, so malformed ranges can still raise later.
pub fn plot_parametric_range(
  symbol : @symcore.Expr,
  start : @symcore.Expr,
  end : @symcore.Expr,
) -> ParametricPlotInput {
  ParametricPlotInput::Range(@symcore.Expr::Tuple([symbol, start, end]))
}

///|
/// - Does: Wraps one explicit series label for `plot_parametric`.
/// - Input: One `String`.
/// - Returns: `ParametricPlotInput`.
/// - Limits: Label interpretation is left to the plotting front door.
pub fn plot_parametric_label(value : String) -> ParametricPlotInput {
  ParametricPlotInput::Label(value)
}

///|
/// - Does: Wraps rendering keyword metadata for `plot_parametric`.
/// - Input: `Map[String, String]`.
/// - Returns: `ParametricPlotInput`.
/// - Limits: Keywords are stored structurally and are not validated here.
pub fn plot_parametric_rendering_kw(
  value : Map[String, String],
) -> ParametricPlotInput {
  ParametricPlotInput::RenderingKw(value)
}

///|
/// - Does: Groups several `plot_parametric` inputs into one nested input item.
/// - Input: `Array[ParametricPlotInput]`.
/// - Returns: `ParametricPlotInput`.
/// - Limits: Group semantics are interpreted by `plot_parametric`, not by this constructor.
pub fn plot_parametric_group(
  items : Array[ParametricPlotInput],
) -> ParametricPlotInput {
  ParametricPlotInput::Group(items)
}

///|
/// - Does: Describes one argument accepted by 3D parametric plotting front doors.
/// - Input: One expression triple, one range tuple, one label, rendering keywords, or one grouped input list.
/// - Returns: One `Parametric3DPlotInput` value.
/// - Limits: Validation is deferred to the consuming 3D plotting front door.
pub enum Parametric3DPlotInput {
  Exprs(@symcore.Expr, @symcore.Expr, @symcore.Expr)
  Range(@symcore.Expr)
  Label(String)
  RenderingKw(Map[String, String])
  Group(Array[Parametric3DPlotInput])
}

///|
/// - Does: Wraps one 3D parametric line expression triple.
/// - Input: Three expressions `(x(t), y(t), z(t))`.
/// - Returns: `Parametric3DPlotInput`.
/// - Limits: Validation is deferred to `plot3d_parametric_line`.
pub fn plot3d_parametric_line_expr(
  expr_x : @symcore.Expr,
  expr_y : @symcore.Expr,
  expr_z : @symcore.Expr,
) -> Parametric3DPlotInput {
  Parametric3DPlotInput::Exprs(expr_x, expr_y, expr_z)
}

///|
/// - Does: Builds one range argument for `plot3d_parametric_line`.
/// - Input: One symbol-like expression plus start and end expressions.
/// - Returns: `Parametric3DPlotInput`.
/// - Limits: Validation is deferred to `plot3d_parametric_line`, so malformed ranges can still raise later.
pub fn plot3d_parametric_line_range(
  symbol : @symcore.Expr,
  start : @symcore.Expr,
  end : @symcore.Expr,
) -> Parametric3DPlotInput {
  Parametric3DPlotInput::Range(@symcore.Expr::Tuple([symbol, start, end]))
}

///|
/// - Does: Wraps one explicit series label for `plot3d_parametric_line`.
/// - Input: One `String`.
/// - Returns: `Parametric3DPlotInput`.
/// - Limits: Label interpretation is left to the plotting front door.
pub fn plot3d_parametric_line_label(value : String) -> Parametric3DPlotInput {
  Parametric3DPlotInput::Label(value)
}

///|
/// - Does: Wraps rendering keyword metadata for `plot3d_parametric_line`.
/// - Input: `Map[String, String]`.
/// - Returns: `Parametric3DPlotInput`.
/// - Limits: Keywords are stored structurally and are not validated here.
pub fn plot3d_parametric_line_rendering_kw(
  value : Map[String, String],
) -> Parametric3DPlotInput {
  Parametric3DPlotInput::RenderingKw(value)
}

///|
/// - Does: Groups several `plot3d_parametric_line` inputs into one nested input item.
/// - Input: `Array[Parametric3DPlotInput]`.
/// - Returns: `Parametric3DPlotInput`.
/// - Limits: Group semantics are interpreted by the consuming 3D plotting front door.
pub fn plot3d_parametric_line_group(
  items : Array[Parametric3DPlotInput],
) -> Parametric3DPlotInput {
  Parametric3DPlotInput::Group(items)
}

///|
/// - Does: Wraps one 3D parametric surface expression triple.
/// - Input: Three expressions `(x(u, v), y(u, v), z(u, v))`.
/// - Returns: `Parametric3DPlotInput`.
/// - Limits: Validation is deferred to `plot3d_parametric_surface`.
pub fn plot3d_parametric_surface_expr(
  expr_x : @symcore.Expr,
  expr_y : @symcore.Expr,
  expr_z : @symcore.Expr,
) -> Parametric3DPlotInput {
  Parametric3DPlotInput::Exprs(expr_x, expr_y, expr_z)
}

///|
/// - Does: Builds one range argument for `plot3d_parametric_surface`.
/// - Input: One symbol-like expression plus start and end expressions.
/// - Returns: `Parametric3DPlotInput`.
/// - Limits: Validation is deferred to `plot3d_parametric_surface`, so malformed ranges can still raise later.
pub fn plot3d_parametric_surface_range(
  symbol : @symcore.Expr,
  start : @symcore.Expr,
  end : @symcore.Expr,
) -> Parametric3DPlotInput {
  Parametric3DPlotInput::Range(@symcore.Expr::Tuple([symbol, start, end]))
}

///|
/// - Does: Wraps one explicit series label for `plot3d_parametric_surface`.
/// - Input: One `String`.
/// - Returns: `Parametric3DPlotInput`.
/// - Limits: Label interpretation is left to the plotting front door.
pub fn plot3d_parametric_surface_label(value : String) -> Parametric3DPlotInput {
  Parametric3DPlotInput::Label(value)
}

///|
/// - Does: Wraps rendering keyword metadata for `plot3d_parametric_surface`.
/// - Input: `Map[String, String]`.
/// - Returns: `Parametric3DPlotInput`.
/// - Limits: Keywords are stored structurally and are not validated here.
pub fn plot3d_parametric_surface_rendering_kw(
  value : Map[String, String],
) -> Parametric3DPlotInput {
  Parametric3DPlotInput::RenderingKw(value)
}

///|
/// - Does: Groups several `plot3d_parametric_surface` inputs into one nested input item.
/// - Input: `Array[Parametric3DPlotInput]`.
/// - Returns: `Parametric3DPlotInput`.
/// - Limits: Group semantics are interpreted by the consuming 3D plotting front door.
pub fn plot3d_parametric_surface_group(
  items : Array[Parametric3DPlotInput],
) -> Parametric3DPlotInput {
  Parametric3DPlotInput::Group(items)
}
