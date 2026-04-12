///|
pub struct TextBackend {
  plot_ : Plot
}

///|
pub fn text_backend(plot : Plot) -> TextBackend {
  TextBackend::{ plot_: plot }
}

///|
pub fn TextBackend::_backend(self : TextBackend) -> TextBackend {
  self
}

///|
pub fn TextBackend::backend(self : TextBackend) -> String {
  ignore(self)
  "TextBackend"
}

///|
pub fn TextBackend::plot(self : TextBackend) -> Plot {
  self.plot_
}

///|
pub fn TextBackend::series(self : TextBackend) -> Array[LineOver1DRangeSeries] {
  let out : Array[LineOver1DRangeSeries] = []
  for item in self.plot_.series() {
    match item {
      PlotSeries::Line(series) => out.push(series)
      PlotSeries::Parametric2D(_)
      | PlotSeries::Parametric3D(_)
      | PlotSeries::Surface(_)
      | PlotSeries::ParametricSurface(_)
      | PlotSeries::Contour(_) => ()
    }
  }
  out
}

///|
pub fn TextBackend::getitem(
  self : TextBackend,
  index : Int,
) -> LineOver1DRangeSeries raise PlottingError {
  match self.plot_.getitem(index) {
    PlotSeries::Line(series) => series
    PlotSeries::Parametric2D(_)
    | PlotSeries::Parametric3D(_)
    | PlotSeries::Surface(_)
    | PlotSeries::ParametricSurface(_)
    | PlotSeries::Contour(_) =>
      raise PlottingError::TypeError(
        "The TextBackend only supports 1D line series.",
      )
  }
}

///|
pub fn TextBackend::render_lines(
  self : TextBackend,
) -> Array[String] raise PlottingError {
  if self.plot_.series().length() != 1 {
    raise PlottingError::ValueError(
      "The TextBackend supports only one graph per Plot.",
    )
  }
  let ser = self.getitem(0)
  textplot_str(ser.expr, ser.start, ser.end)
}

///|
pub fn TextBackend::show(self : TextBackend) -> Unit raise PlottingError {
  if !show_is_enabled() {
    return
  }
  for line in self.render_lines() {
    println(line)
  }
}

///|
pub fn TextBackend::close(self : TextBackend) -> Unit {
  ignore(self)
}
