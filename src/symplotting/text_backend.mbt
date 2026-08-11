///|
/// - Does: Stores the text backend wrapper around one `Plot`.
/// - Input: Constructed from one `Plot`.
/// - Returns: One `TextBackend` value.
/// - Limits: Only 1D line series are supported by this backend.
pub struct TextBackend {
  plot_ : Plot
}

///|
/// - Does: Builds the text backend wrapper for one plot.
/// - Input: One `Plot`.
/// - Returns: `TextBackend`.
/// - Limits: Unsupported series kinds are rejected later by backend methods rather than here.
pub fn text_backend(plot : Plot) -> TextBackend {
  { plot_: plot }
}

///|
/// - Does: Returns the backend object itself.
/// - Input: One `TextBackend`.
/// - Returns: `TextBackend`.
/// - Limits: This is a compatibility helper and adds no extra validation.
pub fn TextBackend::_backend(self : TextBackend) -> TextBackend {
  self
}

///|
/// - Does: Returns the backend name used by this wrapper.
/// - Input: One `TextBackend`.
/// - Returns: `String`.
/// - Limits: The name is a fixed literal and does not reflect runtime capabilities beyond this wrapper.
pub fn TextBackend::backend(self : TextBackend) -> String {
  ignore(self)
  "TextBackend"
}

///|
/// - Does: Returns the wrapped plot object.
/// - Input: One `TextBackend`.
/// - Returns: `Plot`.
/// - Limits: This is a shallow accessor.
pub fn TextBackend::plot(self : TextBackend) -> Plot {
  self.plot_
}

///|
/// - Does: Returns the 1D line series supported by the text backend.
/// - Input: One `TextBackend`.
/// - Returns: `Array[LineOver1DRangeSeries]`.
/// - Limits: Non-line series are silently filtered out instead of raising here.
pub fn TextBackend::series(self : TextBackend) -> Array[LineOver1DRangeSeries] {
  let out : Array[LineOver1DRangeSeries] = []
  for item in self.plot_.series() {
    match item {
      Line(series) => out.push(series)
      Parametric2D(_)
      | Parametric3D(_)
      | Surface(_)
      | ParametricSurface(_)
      | Contour(_)
      | Implicit(_) => ()
    }
  }
  out
}

///|
/// - Does: Returns one indexed 1D line series from the wrapped plot.
/// - Input: One `TextBackend` and one zero-based index.
/// - Returns: `LineOver1DRangeSeries`.
/// - Limits: Raises `PlottingError::TypeError` when the indexed item is not a 1D line series.
pub fn TextBackend::getitem(
  self : TextBackend,
  index : Int,
) -> LineOver1DRangeSeries raise PlottingError {
  match self.plot_.getitem(index) {
    Line(series) => series
    Parametric2D(_)
    | Parametric3D(_)
    | Surface(_)
    | ParametricSurface(_)
    | Contour(_)
    | Implicit(_) =>
      raise TypeError("The TextBackend only supports 1D line series.")
  }
}

///|
/// - Does: Renders the wrapped plot into ASCII text lines.
/// - Input: One `TextBackend`.
/// - Returns: `Array[String]`.
/// - Limits: Raises `PlottingError::ValueError` unless the plot contains exactly one line series.
pub fn TextBackend::render_lines(
  self : TextBackend,
) -> Array[String] raise PlottingError {
  if self.plot_.series().length() != 1 {
    raise ValueError("The TextBackend supports only one graph per Plot.")
  }
  let ser = self.getitem(0)
  textplot_str(ser.expr, ser.start, ser.end)
}

///|
/// - Does: Prints the rendered text plot when plotting side effects are enabled.
/// - Input: One `TextBackend`.
/// - Returns: `Unit`.
/// - Limits: Raises the same rendering errors as `render_lines`; when global show is disabled it returns immediately.
pub fn TextBackend::show(self : TextBackend) -> Unit raise PlottingError {
  if !show_is_enabled() {
    return
  }
  for line in self.render_lines() {
    println(line)
  }
}

///|
/// - Does: Closes the text backend no-op handle.
/// - Input: One `TextBackend`.
/// - Returns: `Unit`.
/// - Limits: This backend has no persistent resources to release.
pub fn TextBackend::close(self : TextBackend) -> Unit {
  ignore(self)
}
