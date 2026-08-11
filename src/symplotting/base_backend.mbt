///|
/// Mirror SymPy's global `_show` switch used by plotting tests to disable
/// interactive display side-effects.
let plotting_show_enabled : Ref[Bool] = { val: true }

///|
/// - Does: Disables plotting `show()` side effects globally.
/// - Input: No arguments.
/// - Returns: `Unit`.
/// - Limits: This affects the process-wide plotting toggle used by this package.
pub fn unset_show() -> Unit {
  plotting_show_enabled.val = false
}

///|
/// - Does: Re-enables plotting `show()` side effects globally.
/// - Input: No arguments.
/// - Returns: `Unit`.
/// - Limits: This affects the process-wide plotting toggle used by this package.
pub fn set_show() -> Unit {
  plotting_show_enabled.val = true
}

///|
/// - Does: Reports whether plotting `show()` side effects are currently enabled.
/// - Input: No arguments.
/// - Returns: `Bool`.
/// - Limits: Reads only the local process-wide toggle.
pub fn show_is_enabled() -> Bool {
  plotting_show_enabled.val
}

///|
/// - Does: Stores one plot object together with its backend metadata and series list.
/// - Input: Constructed from backend metadata plus `Array[PlotSeries]`.
/// - Returns: One `Plot` value.
/// - Limits: The stored backend name is metadata only; unsupported operations can still raise later.
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
/// - Does: Builds one `Plot` object from series and backend metadata.
/// - Input: `Array[PlotSeries]` plus optional backend and label/axis settings.
/// - Returns: `Plot`.
/// - Limits: Does not validate backend-specific series compatibility beyond storing the metadata.
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
  {
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
/// - Does: Returns the plot object itself.
/// - Input: One `Plot`.
/// - Returns: `Plot`.
/// - Limits: This is a compatibility helper and adds no extra validation.
pub fn Plot::_backend(self : Plot) -> Plot {
  self
}

///|
/// - Does: Returns the backend name stored on the plot.
/// - Input: One `Plot`.
/// - Returns: `String`.
/// - Limits: The name is metadata only and does not guarantee backend support for every method.
pub fn Plot::backend(self : Plot) -> String {
  self.backend_name_
}

///|
/// - Does: Returns the series list stored on the plot.
/// - Input: One `Plot`.
/// - Returns: `Array[PlotSeries]`.
/// - Limits: This is a shallow accessor.
pub fn Plot::series(self : Plot) -> Array[PlotSeries] {
  self.series_
}

///|
/// - Does: Returns one indexed series from the plot.
/// - Input: One `Plot` and one zero-based index.
/// - Returns: `PlotSeries`.
/// - Limits: Raises `PlottingError::ValueError` when the index is out of range.
pub fn Plot::getitem(
  self : Plot,
  index : Int,
) -> PlotSeries raise PlottingError {
  if index < 0 || index >= self.series_.length() {
    raise ValueError("plot series index out of range")
  }
  self.series_[index]
}

///|
/// - Does: Returns a new plot with one extra series appended.
/// - Input: One `Plot` and one `PlotSeries`.
/// - Returns: `Plot`.
/// - Limits: Plot metadata is copied unchanged from the original plot.
pub fn Plot::append(self : Plot, arg : PlotSeries) -> Plot {
  let series = self.series_.copy()
  series.push(arg)
  {
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
/// - Does: Returns a new plot with another plot's series appended.
/// - Input: Two `Plot` values.
/// - Returns: `Plot`.
/// - Limits: Backend and metadata are copied from the left-hand plot only.
#alias(extend, deprecated="Use `Plot::extend_` instead")
pub fn Plot::extend_(self : Plot, other : Plot) -> Plot {
  let series = self.series_.copy()
  for item in other.series_ {
    series.push(item)
  }
  {
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
/// - Does: Renders the plot into ASCII text lines.
/// - Input: One `Plot`.
/// - Returns: `Array[String]`.
/// - Limits: Raises `PlottingError::TypeError` unless the plot uses the text backend.
pub fn Plot::render_lines(self : Plot) -> Array[String] raise PlottingError {
  if self.backend_name_ != "text" {
    raise TypeError("render_lines is only available on the text backend")
  }
  text_backend(self).render_lines()
}

///|
/// - Does: Returns sampled points for one 1D line series.
/// - Input: One `Plot` and one zero-based series index.
/// - Returns: `(Array[Double], Array[Double?])`.
/// - Limits: Raises `PlottingError::TypeError` unless the indexed series is a 1D line series.
pub fn Plot::get_points(
  self : Plot,
  index : Int,
) -> (Array[Double], Array[Double?]) raise PlottingError {
  match self.getitem(index) {
    Line(series) => series.get_points()
    Parametric2D(_)
    | Parametric3D(_)
    | Surface(_)
    | ParametricSurface(_)
    | Contour(_)
    | Implicit(_) =>
      raise TypeError("get_points is only available for 1D line series on Plot")
  }
}

///|
/// - Does: Returns sampled data for one 1D line series.
/// - Input: One `Plot` and one zero-based series index.
/// - Returns: `(Array[Double], Array[Double?])`.
/// - Limits: Raises `PlottingError::TypeError` unless the indexed series is a 1D line series.
pub fn Plot::get_data(
  self : Plot,
  index : Int,
) -> (Array[Double], Array[Double?]) raise PlottingError {
  match self.getitem(index) {
    Line(series) => series.get_data()
    Parametric2D(_)
    | Parametric3D(_)
    | Surface(_)
    | ParametricSurface(_)
    | Contour(_)
    | Implicit(_) =>
      raise TypeError("get_data is only available for 1D line series on Plot")
  }
}

///|
/// - Does: Returns sampled planar points for one 2D parametric series.
/// - Input: One `Plot` and one zero-based series index.
/// - Returns: `(Array[Double?], Array[Double?])`.
/// - Limits: Raises `PlottingError::TypeError` unless the indexed series is a 2D parametric line series.
pub fn Plot::get_parametric_points(
  self : Plot,
  index : Int,
) -> (Array[Double?], Array[Double?]) raise PlottingError {
  match self.getitem(index) {
    Parametric2D(series) => series.get_points()
    Line(_)
    | Parametric3D(_)
    | Surface(_)
    | ParametricSurface(_)
    | Contour(_)
    | Implicit(_) =>
      raise TypeError(
        "get_parametric_points is only available for parametric series on Plot",
      )
  }
}

///|
/// - Does: Returns sampled planar data and parameter values for one 2D parametric series.
/// - Input: One `Plot` and one zero-based series index.
/// - Returns: `(Array[Double?], Array[Double?], Array[Double])`.
/// - Limits: Raises `PlottingError::TypeError` unless the indexed series is a 2D parametric line series.
pub fn Plot::get_parametric_data(
  self : Plot,
  index : Int,
) -> (Array[Double?], Array[Double?], Array[Double]) raise PlottingError {
  match self.getitem(index) {
    Parametric2D(series) => series.get_data()
    Line(_)
    | Parametric3D(_)
    | Surface(_)
    | ParametricSurface(_)
    | Contour(_)
    | Implicit(_) =>
      raise TypeError(
        "get_parametric_data is only available for parametric series on Plot",
      )
  }
}

///|
/// - Does: Returns sampled 3D points for one 3D parametric line series.
/// - Input: One `Plot` and one zero-based series index.
/// - Returns: `(Array[Double?], Array[Double?], Array[Double?])`.
/// - Limits: Raises `PlottingError::TypeError` unless the indexed series is a 3D parametric line series.
pub fn Plot::get_parametric3d_points(
  self : Plot,
  index : Int,
) -> (Array[Double?], Array[Double?], Array[Double?]) raise PlottingError {
  match self.getitem(index) {
    Parametric3D(series) => series.get_points()
    Line(_)
    | Parametric2D(_)
    | Surface(_)
    | ParametricSurface(_)
    | Contour(_)
    | Implicit(_) =>
      raise TypeError(
        "get_parametric3d_points is only available for 3D parametric series on Plot",
      )
  }
}

///|
/// - Does: Returns sampled 3D data and parameter values for one 3D parametric line series.
/// - Input: One `Plot` and one zero-based series index.
/// - Returns: `(Array[Double?], Array[Double?], Array[Double?], Array[Double])`.
/// - Limits: Raises `PlottingError::TypeError` unless the indexed series is a 3D parametric line series.
pub fn Plot::get_parametric3d_data(
  self : Plot,
  index : Int,
) -> (Array[Double?], Array[Double?], Array[Double?], Array[Double]) raise PlottingError {
  match self.getitem(index) {
    Parametric3D(series) => series.get_data()
    Line(_)
    | Parametric2D(_)
    | Surface(_)
    | ParametricSurface(_)
    | Contour(_)
    | Implicit(_) =>
      raise TypeError(
        "get_parametric3d_data is only available for 3D parametric series on Plot",
      )
  }
}

///|
/// - Does: Returns sampled mesh data for one Cartesian surface series.
/// - Input: One `Plot` and one zero-based series index.
/// - Returns: `(Array[Array[Double]], Array[Array[Double]], Array[Array[Double?]])`.
/// - Limits: Raises `PlottingError::TypeError` unless the indexed series is a Cartesian surface series.
pub fn Plot::get_surface_data(
  self : Plot,
  index : Int,
) -> (Array[Array[Double]], Array[Array[Double]], Array[Array[Double?]]) raise PlottingError {
  match self.getitem(index) {
    Surface(series) => series.get_data()
    Line(_)
    | Parametric2D(_)
    | Parametric3D(_)
    | ParametricSurface(_)
    | Contour(_)
    | Implicit(_) =>
      raise TypeError(
        "get_surface_data is only available for cartesian surface series on Plot",
      )
  }
}

///|
/// - Does: Returns sampled mesh data for one parametric surface series.
/// - Input: One `Plot` and one zero-based series index.
/// - Returns: `(Array[Array[Double?]], Array[Array[Double?]], Array[Array[Double?]], Array[Array[Double]], Array[Array[Double]])`.
/// - Limits: Raises `PlottingError::TypeError` unless the indexed series is a parametric surface series.
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
    ParametricSurface(series) => series.get_data()
    Line(_)
    | Parametric2D(_)
    | Parametric3D(_)
    | Surface(_)
    | Contour(_)
    | Implicit(_) =>
      raise TypeError(
        "get_parametric_surface_data is only available for parametric surface series on Plot",
      )
  }
}

///|
/// - Does: Returns sampled contour mesh data for one contour series.
/// - Input: One `Plot` and one zero-based series index.
/// - Returns: `(Array[Array[Double]], Array[Array[Double]], Array[Array[Double?]])`.
/// - Limits: Raises `PlottingError::TypeError` unless the indexed series is a contour series.
pub fn Plot::get_contour_data(
  self : Plot,
  index : Int,
) -> (Array[Array[Double]], Array[Array[Double]], Array[Array[Double?]]) raise PlottingError {
  match self.getitem(index) {
    Contour(series) => series.get_data()
    Line(_)
    | Parametric2D(_)
    | Parametric3D(_)
    | Surface(_)
    | ParametricSurface(_)
    | Implicit(_) =>
      raise TypeError(
        "get_contour_data is only available for contour series on Plot",
      )
  }
}

///|
/// - Does: Returns sampled implicit-plot data for one implicit series.
/// - Input: One `Plot` and one zero-based series index.
/// - Returns: `ImplicitPlotData`.
/// - Limits: Raises `PlottingError::TypeError` unless the indexed series is an implicit series.
pub fn Plot::get_implicit_data(
  self : Plot,
  index : Int,
) -> ImplicitPlotData raise PlottingError {
  match self.getitem(index) {
    Implicit(series) => series.get_data()
    Line(_)
    | Parametric2D(_)
    | Parametric3D(_)
    | Surface(_)
    | ParametricSurface(_)
    | Contour(_) =>
      raise TypeError(
        "get_implicit_data is only available for implicit series on Plot",
      )
  }
}

///|
/// - Does: Dispatches `show()` to the selected backend.
/// - Input: One `Plot`.
/// - Returns: `Unit`.
/// - Limits: Only the text backend performs output here; other backends currently return without rendering.
pub fn Plot::show(self : Plot) -> Unit raise PlottingError {
  if self.backend_name_ == "text" {
    text_backend(self).show()
  } else {
    ignore(self)
  }
}

///|
/// - Does: Closes the plot handle.
/// - Input: One `Plot`.
/// - Returns: `Unit`.
/// - Limits: Current backends do not hold persistent resources, so this is a no-op.
pub fn Plot::close(self : Plot) -> Unit {
  ignore(self)
}

///|
/// - Does: Formats the plot and its series for diagnostics.
/// - Input: One `Plot`.
/// - Returns: `String`.
/// - Limits: Output is intended for inspection and tests, so string format changes can break assertions.
pub fn Plot::to_string(self : Plot) -> String {
  let lines : Array[String] = []
  for i in 0..<self.series_.length() {
    lines.push("[\{i}]: " + self.series_[i].to_string())
  }
  "Plot object containing:\n" + lines.join("\n")
}
