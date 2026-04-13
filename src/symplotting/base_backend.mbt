///|
/// Mirror SymPy's global `_show` switch used by plotting tests to disable
/// interactive display side-effects.
let plotting_show_enabled : Ref[Bool] = { val: true }

///|
/// Disable `show()` side effects in plotting tests.
pub fn unset_show() -> Unit {
  plotting_show_enabled.val = false
}

///|
/// Re-enable `show()` side effects.
pub fn set_show() -> Unit {
  plotting_show_enabled.val = true
}

///|
/// Return whether plotting side effects are enabled.
pub fn show_is_enabled() -> Bool {
  plotting_show_enabled.val
}

///|
pub struct Plot {
  backend_name_ : String
  title : String?
  xlabel : String?
  ylabel : String?
  zlabel : String?
  aspect_ratio : String
  axis_center : String
  axis : Bool
  xscale : String
  yscale : String
  legend : Bool
  autoscale : Bool
  margin : Int
  series_ : Array[PlotSeries]
}

///|
pub fn plot_object(
  series : Array[PlotSeries],
  backend_name? : String = "default",
  title? : String? = None,
  xlabel? : String? = None,
  ylabel? : String? = None,
  zlabel? : String? = None,
  aspect_ratio? : String = "auto",
  axis_center? : String = "auto",
  axis? : Bool = true,
  xscale? : String = "linear",
  yscale? : String = "linear",
  legend? : Bool = false,
  autoscale? : Bool = true,
  margin? : Int = 0,
) -> Plot {
  Plot::{
    backend_name_: backend_name,
    title,
    xlabel,
    ylabel,
    zlabel,
    aspect_ratio,
    axis_center,
    axis,
    xscale,
    yscale,
    legend,
    autoscale,
    margin,
    series_: series,
  }
}

///|
pub fn Plot::_backend(self : Plot) -> Plot {
  self
}

///|
pub fn Plot::backend(self : Plot) -> String {
  self.backend_name_
}

///|
pub fn Plot::series(self : Plot) -> Array[PlotSeries] {
  self.series_
}

///|
pub fn Plot::getitem(
  self : Plot,
  index : Int,
) -> PlotSeries raise PlottingError {
  if index < 0 || index >= self.series_.length() {
    raise PlottingError::ValueError("plot series index out of range")
  }
  self.series_[index]
}

///|
pub fn Plot::append(self : Plot, arg : PlotSeries) -> Plot {
  let series = self.series_.copy()
  series.push(arg)
  Plot::{
    backend_name_: self.backend_name_,
    title: self.title,
    xlabel: self.xlabel,
    ylabel: self.ylabel,
    zlabel: self.zlabel,
    aspect_ratio: self.aspect_ratio,
    axis_center: self.axis_center,
    axis: self.axis,
    xscale: self.xscale,
    yscale: self.yscale,
    legend: self.legend,
    autoscale: self.autoscale,
    margin: self.margin,
    series_: series,
  }
}

///|
pub fn Plot::extend(self : Plot, other : Plot) -> Plot {
  let series = self.series_.copy()
  for item in other.series_ {
    series.push(item)
  }
  Plot::{
    backend_name_: self.backend_name_,
    title: self.title,
    xlabel: self.xlabel,
    ylabel: self.ylabel,
    zlabel: self.zlabel,
    aspect_ratio: self.aspect_ratio,
    axis_center: self.axis_center,
    axis: self.axis,
    xscale: self.xscale,
    yscale: self.yscale,
    legend: self.legend,
    autoscale: self.autoscale,
    margin: self.margin,
    series_: series,
  }
}

///|
pub fn Plot::render_lines(self : Plot) -> Array[String] raise PlottingError {
  if self.backend_name_ != "text" {
    raise PlottingError::TypeError(
      "render_lines is only available on the text backend",
    )
  }
  text_backend(self).render_lines()
}

///|
pub fn Plot::get_points(
  self : Plot,
  index : Int,
) -> (Array[Double], Array[Double?]) raise PlottingError {
  match self.getitem(index) {
    PlotSeries::Line(series) => series.get_points()
    PlotSeries::Parametric2D(_)
    | PlotSeries::Parametric3D(_)
    | PlotSeries::Surface(_)
    | PlotSeries::ParametricSurface(_)
    | PlotSeries::Contour(_)
    | PlotSeries::Implicit(_) =>
      raise PlottingError::TypeError(
        "get_points is only available for 1D line series on Plot",
      )
  }
}

///|
pub fn Plot::get_data(
  self : Plot,
  index : Int,
) -> (Array[Double], Array[Double?]) raise PlottingError {
  match self.getitem(index) {
    PlotSeries::Line(series) => series.get_data()
    PlotSeries::Parametric2D(_)
    | PlotSeries::Parametric3D(_)
    | PlotSeries::Surface(_)
    | PlotSeries::ParametricSurface(_)
    | PlotSeries::Contour(_)
    | PlotSeries::Implicit(_) =>
      raise PlottingError::TypeError(
        "get_data is only available for 1D line series on Plot",
      )
  }
}

///|
pub fn Plot::get_parametric_points(
  self : Plot,
  index : Int,
) -> (Array[Double?], Array[Double?]) raise PlottingError {
  match self.getitem(index) {
    PlotSeries::Parametric2D(series) => series.get_points()
    PlotSeries::Line(_)
    | PlotSeries::Parametric3D(_)
    | PlotSeries::Surface(_)
    | PlotSeries::ParametricSurface(_)
    | PlotSeries::Contour(_)
    | PlotSeries::Implicit(_) =>
      raise PlottingError::TypeError(
        "get_parametric_points is only available for parametric series on Plot",
      )
  }
}

///|
pub fn Plot::get_parametric_data(
  self : Plot,
  index : Int,
) -> (Array[Double?], Array[Double?], Array[Double]) raise PlottingError {
  match self.getitem(index) {
    PlotSeries::Parametric2D(series) => series.get_data()
    PlotSeries::Line(_)
    | PlotSeries::Parametric3D(_)
    | PlotSeries::Surface(_)
    | PlotSeries::ParametricSurface(_)
    | PlotSeries::Contour(_)
    | PlotSeries::Implicit(_) =>
      raise PlottingError::TypeError(
        "get_parametric_data is only available for parametric series on Plot",
      )
  }
}

///|
pub fn Plot::get_parametric3d_points(
  self : Plot,
  index : Int,
) -> (Array[Double?], Array[Double?], Array[Double?]) raise PlottingError {
  match self.getitem(index) {
    PlotSeries::Parametric3D(series) => series.get_points()
    PlotSeries::Line(_)
    | PlotSeries::Parametric2D(_)
    | PlotSeries::Surface(_)
    | PlotSeries::ParametricSurface(_)
    | PlotSeries::Contour(_)
    | PlotSeries::Implicit(_) =>
      raise PlottingError::TypeError(
        "get_parametric3d_points is only available for 3D parametric series on Plot",
      )
  }
}

///|
pub fn Plot::get_parametric3d_data(
  self : Plot,
  index : Int,
) -> (Array[Double?], Array[Double?], Array[Double?], Array[Double]) raise PlottingError {
  match self.getitem(index) {
    PlotSeries::Parametric3D(series) => series.get_data()
    PlotSeries::Line(_)
    | PlotSeries::Parametric2D(_)
    | PlotSeries::Surface(_)
    | PlotSeries::ParametricSurface(_)
    | PlotSeries::Contour(_)
    | PlotSeries::Implicit(_) =>
      raise PlottingError::TypeError(
        "get_parametric3d_data is only available for 3D parametric series on Plot",
      )
  }
}

///|
pub fn Plot::get_surface_data(
  self : Plot,
  index : Int,
) -> (Array[Array[Double]], Array[Array[Double]], Array[Array[Double?]]) raise PlottingError {
  match self.getitem(index) {
    PlotSeries::Surface(series) => series.get_data()
    PlotSeries::Line(_)
    | PlotSeries::Parametric2D(_)
    | PlotSeries::Parametric3D(_)
    | PlotSeries::ParametricSurface(_)
    | PlotSeries::Contour(_)
    | PlotSeries::Implicit(_) =>
      raise PlottingError::TypeError(
        "get_surface_data is only available for cartesian surface series on Plot",
      )
  }
}

///|
pub fn Plot::get_parametric_surface_data(
  self : Plot,
  index : Int,
) -> (
  Array[Array[Double?]],
  Array[Array[Double?]],
  Array[Array[Double?]],
  Array[Array[Double]],
  Array[Array[Double]],
) raise PlottingError {
  match self.getitem(index) {
    PlotSeries::ParametricSurface(series) => series.get_data()
    PlotSeries::Line(_)
    | PlotSeries::Parametric2D(_)
    | PlotSeries::Parametric3D(_)
    | PlotSeries::Surface(_)
    | PlotSeries::Contour(_)
    | PlotSeries::Implicit(_) =>
      raise PlottingError::TypeError(
        "get_parametric_surface_data is only available for parametric surface series on Plot",
      )
  }
}

///|
pub fn Plot::get_contour_data(
  self : Plot,
  index : Int,
) -> (Array[Array[Double]], Array[Array[Double]], Array[Array[Double?]]) raise PlottingError {
  match self.getitem(index) {
    PlotSeries::Contour(series) => series.get_data()
    PlotSeries::Line(_)
    | PlotSeries::Parametric2D(_)
    | PlotSeries::Parametric3D(_)
    | PlotSeries::Surface(_)
    | PlotSeries::ParametricSurface(_)
    | PlotSeries::Implicit(_) =>
      raise PlottingError::TypeError(
        "get_contour_data is only available for contour series on Plot",
      )
  }
}

///|
pub fn Plot::get_implicit_data(
  self : Plot,
  index : Int,
) -> ImplicitPlotData raise PlottingError {
  match self.getitem(index) {
    PlotSeries::Implicit(series) => series.get_data()
    PlotSeries::Line(_)
    | PlotSeries::Parametric2D(_)
    | PlotSeries::Parametric3D(_)
    | PlotSeries::Surface(_)
    | PlotSeries::ParametricSurface(_)
    | PlotSeries::Contour(_) =>
      raise PlottingError::TypeError(
        "get_implicit_data is only available for implicit series on Plot",
      )
  }
}

///|
pub fn Plot::show(self : Plot) -> Unit raise PlottingError {
  if self.backend_name_ == "text" {
    text_backend(self).show()
  } else {
    ignore(self)
  }
}

///|
pub fn Plot::close(self : Plot) -> Unit {
  ignore(self)
}

///|
pub fn Plot::to_string(self : Plot) -> String {
  let lines : Array[String] = []
  for i in 0..<self.series_.length() {
    lines.push("[\{i}]: " + self.series_[i].to_string())
  }
  "Plot object containing:\n" + lines.join("\n")
}
