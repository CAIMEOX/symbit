///|
fn plot_free_symbols(exprs : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = []
  for expr in exprs {
    for symbol in @symcore.free_symbols(expr) {
      if !out.contains(symbol) {
        out.push(symbol)
      }
    }
  }
  out
}

///|
fn plot_default_range(symbol : @symcore.Expr) -> @symcore.Expr {
  @symcore.Expr::Tuple([symbol, @symcore.int(-10), @symcore.int(10)])
}

///|
fn plot_default_symbol() -> @symcore.Expr {
  @symcore.Expr::Symbol("x")
}

///|
fn plot_secondary_default_symbol(primary : @symcore.Expr) -> @symcore.Expr {
  match primary {
    @symcore.Expr::Symbol("x") => @symcore.Expr::Symbol("y")
    @symcore.Expr::Symbol("y") => @symcore.Expr::Symbol("x")
    _ => @symcore.Expr::Symbol("y")
  }
}

///|
fn plot_range_symbol(
  range : @symcore.Expr,
) -> @symcore.Expr raise PlottingError {
  match range {
    @symcore.Expr::Tuple([symbol, _, _]) if is_plot_range(range) => symbol
    _ =>
      raise PlottingError::ValueError(
        "A plotting range must be a tuple of the form (symbol, start, end)",
      )
  }
}

///|
fn plot_create_ranges(
  exprs : Array[@symcore.Expr],
  ranges : Array[@symcore.Expr],
  npar : Int,
) -> Array[@symcore.Expr] raise PlottingError {
  let free_symbols = plot_free_symbols(exprs)
  if free_symbols.length() > npar {
    raise PlottingError::ValueError(
      "Too many free symbols.\nExpected " +
      npar.to_string() +
      " free symbols.\nReceived " +
      free_symbols.length().to_string() +
      ": {" +
      free_symbols.map(@symprint.to_string).join(", ") +
      "}",
    )
  }
  if ranges.length() > npar {
    raise PlottingError::ValueError(
      "Too many ranges. Received " +
      ranges.length().to_string() +
      ", expected " +
      npar.to_string(),
    )
  }

  let out : Array[@symcore.Expr] = []
  for range in ranges {
    if !is_plot_range(range) {
      raise PlottingError::ValueError(
        "A plotting range must be a tuple of the form (symbol, start, end)",
      )
    }
    let symbol = plot_range_symbol(range)
    if out.any(existing => plot_range_symbol(existing) == symbol) {
      raise PlottingError::ValueError("Multiple ranges with the same symbol")
    }
    out.push(range)
  }

  for symbol in free_symbols {
    if !out.any(range => plot_range_symbol(range) == symbol) {
      out.push(plot_default_range(symbol))
    }
  }
  while out.length() < npar {
    out.push(plot_default_range(plot_default_symbol()))
  }

  if free_symbols.length() == npar {
    let range_symbols = out.map(range => plot_range_symbol(range))
    let missing = free_symbols.filter(symbol => !range_symbols.contains(symbol))
    if !missing.is_empty() {
      raise PlottingError::ValueError(
        "Incompatible free symbols of the expressions with the ranges.\n" +
        "Free symbols in the expressions: {" +
        free_symbols.map(@symprint.to_string).join(", ") +
        "}\n" +
        "Free symbols in the ranges: {" +
        range_symbols.map(@symprint.to_string).join(", ") +
        "}",
      )
    }
  }

  out
}

///|
fn plot_unpack(
  args : Array[PlotInput],
) -> (
  Array[@symcore.Expr],
  Array[@symcore.Expr],
  String?,
  Map[String, String]?,
  Array[Array[PlotInput]],
) {
  let exprs : Array[@symcore.Expr] = []
  let ranges : Array[@symcore.Expr] = []
  let mut label : String? = None
  let mut rendering_kw : Map[String, String]? = None
  let groups : Array[Array[PlotInput]] = []

  for arg in args {
    match arg {
      PlotInput::Expr(expr) => exprs.push(expr)
      PlotInput::Range(range) => ranges.push(range)
      PlotInput::Label(value) => label = Some(value)
      PlotInput::RenderingKw(value) => rendering_kw = Some(value)
      PlotInput::Group(items) => groups.push(items)
    }
  }

  (exprs, ranges, label, rendering_kw, groups)
}

///|
fn plot_parametric_unpack(
  args : Array[ParametricPlotInput],
) -> (
  Array[(@symcore.Expr, @symcore.Expr)],
  Array[@symcore.Expr],
  String?,
  Map[String, String]?,
  Array[Array[ParametricPlotInput]],
) {
  let exprs : Array[(@symcore.Expr, @symcore.Expr)] = []
  let ranges : Array[@symcore.Expr] = []
  let mut label : String? = None
  let mut rendering_kw : Map[String, String]? = None
  let groups : Array[Array[ParametricPlotInput]] = []

  for arg in args {
    match arg {
      ParametricPlotInput::Exprs(expr_x, expr_y) => exprs.push((expr_x, expr_y))
      ParametricPlotInput::Range(range) => ranges.push(range)
      ParametricPlotInput::Label(value) => label = Some(value)
      ParametricPlotInput::RenderingKw(value) => rendering_kw = Some(value)
      ParametricPlotInput::Group(items) => groups.push(items)
    }
  }

  (exprs, ranges, label, rendering_kw, groups)
}

///|
fn plot_parametric3d_unpack(
  args : Array[Parametric3DPlotInput],
) -> (
  Array[(@symcore.Expr, @symcore.Expr, @symcore.Expr)],
  Array[@symcore.Expr],
  String?,
  Map[String, String]?,
  Array[Array[Parametric3DPlotInput]],
) {
  let exprs : Array[(@symcore.Expr, @symcore.Expr, @symcore.Expr)] = []
  let ranges : Array[@symcore.Expr] = []
  let mut label : String? = None
  let mut rendering_kw : Map[String, String]? = None
  let groups : Array[Array[Parametric3DPlotInput]] = []

  for arg in args {
    match arg {
      Parametric3DPlotInput::Exprs(expr_x, expr_y, expr_z) =>
        exprs.push((expr_x, expr_y, expr_z))
      Parametric3DPlotInput::Range(range) => ranges.push(range)
      Parametric3DPlotInput::Label(value) => label = Some(value)
      Parametric3DPlotInput::RenderingKw(value) => rendering_kw = Some(value)
      Parametric3DPlotInput::Group(items) => groups.push(items)
    }
  }

  (exprs, ranges, label, rendering_kw, groups)
}

///|
fn plot_build_line_specs(
  args : Array[PlotInput],
) -> Array[(@symcore.Expr, @symcore.Expr, String?, Map[String, String]?)] raise PlottingError {
  let specs : Array[
    (@symcore.Expr, @symcore.Expr, String?, Map[String, String]?),
  ] = []
  let (exprs, ranges, label, rendering_kw, groups) = plot_unpack(args)

  if !exprs.is_empty() {
    let resolved_ranges = plot_create_ranges(exprs, ranges, 1)
    for expr in exprs {
      specs.push((expr, resolved_ranges[0], label, rendering_kw))
    }
  }

  for group in groups {
    let (group_exprs, group_ranges, group_label, group_rendering_kw, nested) = plot_unpack(
      group,
    )
    if !nested.is_empty() {
      raise PlottingError::ValueError(
        "Nested grouped plotting arguments are not supported",
      )
    }
    let resolved_ranges = plot_create_ranges(group_exprs, group_ranges, 1)
    for expr in group_exprs {
      specs.push((expr, resolved_ranges[0], group_label, group_rendering_kw))
    }
  }

  specs
}

///|
fn plot_build_surface_specs(
  args : Array[PlotInput],
) -> Array[
  (@symcore.Expr, @symcore.Expr, @symcore.Expr, String?, Map[String, String]?),
] raise PlottingError {
  let specs : Array[
    (@symcore.Expr, @symcore.Expr, @symcore.Expr, String?, Map[String, String]?),
  ] = []
  let (exprs, ranges, label, rendering_kw, groups) = plot_unpack(args)

  if !exprs.is_empty() {
    let resolved_ranges = plot_create_ranges(exprs, ranges, 2)
    for expr in exprs {
      specs.push(
        (expr, resolved_ranges[0], resolved_ranges[1], label, rendering_kw),
      )
    }
  }

  for group in groups {
    let (group_exprs, group_ranges, group_label, group_rendering_kw, nested) = plot_unpack(
      group,
    )
    if !nested.is_empty() {
      raise PlottingError::ValueError(
        "Nested grouped plotting arguments are not supported",
      )
    }
    if group_exprs.length() != 1 {
      raise PlottingError::ValueError(
        "A grouped surface specification must contain exactly one expression",
      )
    }
    let resolved_ranges = plot_create_ranges(group_exprs, group_ranges, 2)
    specs.push(
      (
        group_exprs[0],
        resolved_ranges[0],
        resolved_ranges[1],
        group_label,
        group_rendering_kw,
      ),
    )
  }

  specs
}

///|
fn plot_build_parametric3d_specs(
  args : Array[Parametric3DPlotInput],
) -> Array[
  (
    @symcore.Expr,
    @symcore.Expr,
    @symcore.Expr,
    @symcore.Expr,
    String?,
    Map[String, String]?,
  ),
] raise PlottingError {
  let specs : Array[
    (
      @symcore.Expr,
      @symcore.Expr,
      @symcore.Expr,
      @symcore.Expr,
      String?,
      Map[String, String]?,
    ),
  ] = []
  let (exprs, ranges, label, rendering_kw, groups) = plot_parametric3d_unpack(
    args,
  )

  if ranges.length() > 1 {
    raise PlottingError::ValueError(
      "Too many ranges. Received " +
      ranges.length().to_string() +
      ", expected 1",
    )
  }

  for expr_triplet in exprs {
    let (expr_x, expr_y, expr_z) = expr_triplet
    let resolved_ranges = plot_create_ranges(
      [expr_x, expr_y, expr_z],
      ranges,
      1,
    )
    specs.push(
      (expr_x, expr_y, expr_z, resolved_ranges[0], label, rendering_kw),
    )
  }

  for group in groups {
    let (group_exprs, group_ranges, group_label, group_rendering_kw, nested) = plot_parametric3d_unpack(
      group,
    )
    if !nested.is_empty() {
      raise PlottingError::ValueError(
        "Nested grouped plotting arguments are not supported",
      )
    }
    if group_exprs.length() != 1 {
      raise PlottingError::ValueError(
        "A grouped 3D parametric specification must contain exactly one expression triplet",
      )
    }
    let (expr_x, expr_y, expr_z) = group_exprs[0]
    let resolved_ranges = plot_create_ranges(
      [expr_x, expr_y, expr_z],
      group_ranges,
      1,
    )
    specs.push(
      (
        expr_x,
        expr_y,
        expr_z,
        resolved_ranges[0],
        group_label,
        group_rendering_kw,
      ),
    )
  }

  specs
}

///|
fn plot_build_parametric_surface_specs(
  args : Array[Parametric3DPlotInput],
) -> Array[
  (
    @symcore.Expr,
    @symcore.Expr,
    @symcore.Expr,
    @symcore.Expr,
    @symcore.Expr,
    String?,
    Map[String, String]?,
  ),
] raise PlottingError {
  let specs : Array[
    (
      @symcore.Expr,
      @symcore.Expr,
      @symcore.Expr,
      @symcore.Expr,
      @symcore.Expr,
      String?,
      Map[String, String]?,
    ),
  ] = []
  let (exprs, ranges, label, rendering_kw, groups) = plot_parametric3d_unpack(
    args,
  )

  if ranges.length() > 2 {
    raise PlottingError::ValueError(
      "Too many ranges. Received " +
      ranges.length().to_string() +
      ", expected 2",
    )
  }

  for expr_triplet in exprs {
    let (expr_x, expr_y, expr_z) = expr_triplet
    let resolved_ranges = plot_create_ranges(
      [expr_x, expr_y, expr_z],
      ranges,
      2,
    )
    specs.push(
      (
        expr_x,
        expr_y,
        expr_z,
        resolved_ranges[0],
        resolved_ranges[1],
        label,
        rendering_kw,
      ),
    )
  }

  for group in groups {
    let (group_exprs, group_ranges, group_label, group_rendering_kw, nested) = plot_parametric3d_unpack(
      group,
    )
    if !nested.is_empty() {
      raise PlottingError::ValueError(
        "Nested grouped plotting arguments are not supported",
      )
    }
    if group_exprs.length() != 1 {
      raise PlottingError::ValueError(
        "A grouped parametric surface specification must contain exactly one expression triplet",
      )
    }
    let (expr_x, expr_y, expr_z) = group_exprs[0]
    let resolved_ranges = plot_create_ranges(
      [expr_x, expr_y, expr_z],
      group_ranges,
      2,
    )
    specs.push(
      (
        expr_x,
        expr_y,
        expr_z,
        resolved_ranges[0],
        resolved_ranges[1],
        group_label,
        group_rendering_kw,
      ),
    )
  }

  specs
}

///|
fn plot_build_parametric_specs(
  args : Array[ParametricPlotInput],
) -> Array[
  (@symcore.Expr, @symcore.Expr, @symcore.Expr, String?, Map[String, String]?),
] raise PlottingError {
  let specs : Array[
    (@symcore.Expr, @symcore.Expr, @symcore.Expr, String?, Map[String, String]?),
  ] = []
  let (exprs, ranges, label, rendering_kw, groups) = plot_parametric_unpack(
    args,
  )

  if ranges.length() > 1 {
    raise PlottingError::ValueError(
      "Too many ranges. Received " +
      ranges.length().to_string() +
      ", expected 1",
    )
  }

  for expr_pair in exprs {
    let (expr_x, expr_y) = expr_pair
    let resolved_ranges = plot_create_ranges([expr_x, expr_y], ranges, 1)
    specs.push((expr_x, expr_y, resolved_ranges[0], label, rendering_kw))
  }

  for group in groups {
    let (group_exprs, group_ranges, group_label, group_rendering_kw, nested) = plot_parametric_unpack(
      group,
    )
    if !nested.is_empty() {
      raise PlottingError::ValueError(
        "Nested grouped plotting arguments are not supported",
      )
    }
    if group_exprs.length() != 1 {
      raise PlottingError::ValueError(
        "A grouped parametric specification must contain exactly one expression pair",
      )
    }
    let (expr_x, expr_y) = group_exprs[0]
    let resolved_ranges = plot_create_ranges([expr_x, expr_y], group_ranges, 1)
    specs.push(
      (expr_x, expr_y, resolved_ranges[0], group_label, group_rendering_kw),
    )
  }

  specs
}

///|
pub fn plot_factory(
  series : Array[PlotSeries],
  backend? : String = "default",
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
) -> Plot raise PlottingError {
  if backend != "default" && backend != "text" && backend != "matplotlib" {
    raise PlottingError::TypeError(
      "backend must be either 'default', 'text' or 'matplotlib'",
    )
  }
  let resolved_backend = if backend == "default" {
    "matplotlib"
  } else {
    backend
  }
  plot_object(
    series,
    backend_name=resolved_backend,
    title~,
    xlabel~,
    ylabel~,
    zlabel~,
    aspect_ratio~,
    axis_center~,
    axis~,
    xscale~,
    yscale~,
    legend~,
    autoscale~,
    margin~,
  )
}

///|
pub fn plot(
  args : Array[PlotInput],
  show? : Bool = true,
  backend? : String = "default",
  adaptive? : Bool = false,
  depth? : Int = 12,
  only_integers? : Bool = false,
  n? : Int = 1000,
  return_mode? : String? = None,
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
) -> Plot raise PlottingError {
  let specs = plot_build_line_specs(args)
  let series : Array[PlotSeries] = []
  for spec in specs {
    let (expr, range, label, rendering_kw) = spec
    series.push(
      PlotSeries::Line(
        line_over_1d_range_series(
          expr,
          range,
          label~,
          rendering_kw~,
          adaptive~,
          depth~,
          only_integers~,
          n~,
          return_mode~,
          xscale~,
        ),
      ),
    )
  }

  let free = plot_free_symbols(
    specs.map(spec => {
      let (expr, _, _, _) = spec
      expr
    }),
  )
  let plot_var = match free {
    [symbol, ..] => symbol
    _ => plot_default_symbol()
  }
  let resolved_xlabel = match xlabel {
    Some(value) => Some(value)
    None => Some(@symprint.to_string(plot_var))
  }
  let resolved_ylabel = match ylabel {
    Some(value) => Some(value)
    None => Some(@symprint.to_string(@symcore.function("f", [plot_var])))
  }

  let backend_obj = plot_factory(
    series,
    backend~,
    title~,
    xlabel=resolved_xlabel,
    ylabel=resolved_ylabel,
    zlabel~,
    aspect_ratio~,
    axis_center~,
    axis~,
    xscale~,
    yscale~,
    legend~,
    autoscale~,
    margin~,
  )
  if show {
    backend_obj.show()
  }
  backend_obj
}

///|
pub fn plot_parametric(
  args : Array[ParametricPlotInput],
  show? : Bool = true,
  backend? : String = "default",
  adaptive? : Bool = true,
  depth? : Int = 12,
  only_integers? : Bool = false,
  n? : Int = 1000,
  use_cm? : Bool = true,
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
) -> Plot raise PlottingError {
  if backend == "text" {
    raise PlottingError::TypeError(
      "plot_parametric only supports the default or matplotlib backend",
    )
  }
  let specs = plot_build_parametric_specs(args)
  let series : Array[PlotSeries] = []
  for spec in specs {
    let (expr_x, expr_y, range, label, rendering_kw) = spec
    series.push(
      PlotSeries::Parametric2D(
        parametric_2d_line_series(
          expr_x,
          expr_y,
          range,
          label~,
          rendering_kw~,
          adaptive~,
          depth~,
          only_integers~,
          n~,
          use_cm~,
          xscale~,
        ),
      ),
    )
  }
  let resolved_xlabel = match xlabel {
    Some(value) => Some(value)
    None => Some("x")
  }
  let resolved_ylabel = match ylabel {
    Some(value) => Some(value)
    None => Some("y")
  }

  let backend_obj = plot_factory(
    series,
    backend~,
    title~,
    xlabel=resolved_xlabel,
    ylabel=resolved_ylabel,
    zlabel~,
    aspect_ratio~,
    axis_center~,
    axis~,
    xscale~,
    yscale~,
    legend~,
    autoscale~,
    margin~,
  )
  if show {
    backend_obj.show()
  }
  backend_obj
}

///|
pub fn plot3d_parametric_line(
  args : Array[Parametric3DPlotInput],
  show? : Bool = true,
  backend? : String = "default",
  adaptive? : Bool = false,
  depth? : Int = 12,
  only_integers? : Bool = false,
  n? : Int = 1000,
  use_cm? : Bool = true,
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
) -> Plot raise PlottingError {
  if backend == "text" {
    raise PlottingError::TypeError(
      "plot3d_parametric_line only supports the default or matplotlib backend",
    )
  }
  let specs = plot_build_parametric3d_specs(args)
  let series : Array[PlotSeries] = []
  for spec in specs {
    let (expr_x, expr_y, expr_z, range, label, rendering_kw) = spec
    series.push(
      PlotSeries::Parametric3D(
        parametric_3d_line_series(
          expr_x,
          expr_y,
          expr_z,
          range,
          label~,
          rendering_kw~,
          adaptive~,
          depth~,
          only_integers~,
          n~,
          use_cm~,
          xscale~,
        ),
      ),
    )
  }
  let resolved_xlabel = match xlabel {
    Some(value) => Some(value)
    None => Some("x")
  }
  let resolved_ylabel = match ylabel {
    Some(value) => Some(value)
    None => Some("y")
  }
  let resolved_zlabel = match zlabel {
    Some(value) => Some(value)
    None => Some("z")
  }
  let backend_obj = plot_factory(
    series,
    backend~,
    title~,
    xlabel=resolved_xlabel,
    ylabel=resolved_ylabel,
    zlabel=resolved_zlabel,
    aspect_ratio~,
    axis_center~,
    axis~,
    xscale~,
    yscale~,
    legend~,
    autoscale~,
    margin~,
  )
  if show {
    backend_obj.show()
  }
  backend_obj
}

///|
pub fn plot3d(
  args : Array[PlotInput],
  show? : Bool = true,
  backend? : String = "default",
  adaptive? : Bool = false,
  n? : Int = 100,
  n1? : Int? = None,
  n2? : Int? = None,
  use_cm? : Bool = false,
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
) -> Plot raise PlottingError {
  if backend == "text" {
    raise PlottingError::TypeError(
      "plot3d only supports the default or matplotlib backend",
    )
  }
  let resolved_n1 = match n1 {
    Some(value) => value
    None => n
  }
  let resolved_n2 = match n2 {
    Some(value) => value
    None => n
  }
  let specs = plot_build_surface_specs(args)
  let series : Array[PlotSeries] = []
  for spec in specs {
    let (expr, range_x, range_y, label, rendering_kw) = spec
    series.push(
      PlotSeries::Surface(
        surface_over_2d_range_series(
          expr,
          range_x,
          range_y,
          label~,
          rendering_kw~,
          adaptive~,
          n1=resolved_n1,
          n2=resolved_n2,
          use_cm~,
          xscale~,
          yscale~,
        ),
      ),
    )
  }
  let resolved_xlabel = match xlabel {
    Some(value) => Some(value)
    None =>
      if specs.is_empty() {
        Some("x")
      } else {
        let (_, range_x, _, _, _) = specs[0]
        Some(@symprint.to_string(plot_range_symbol(range_x)))
      }
  }
  let resolved_ylabel = match ylabel {
    Some(value) => Some(value)
    None =>
      if specs.is_empty() {
        Some("y")
      } else {
        let (_, _, range_y, _, _) = specs[0]
        Some(@symprint.to_string(plot_range_symbol(range_y)))
      }
  }
  let resolved_zlabel = match zlabel {
    Some(value) => Some(value)
    None =>
      if specs.is_empty() {
        Some("f(x, y)")
      } else {
        let (_, range_x, range_y, _, _) = specs[0]
        Some(
          @symprint.to_string(
            @symcore.function("f", [
              plot_range_symbol(range_x),
              plot_range_symbol(range_y),
            ]),
          ),
        )
      }
  }
  let backend_obj = plot_factory(
    series,
    backend~,
    title~,
    xlabel=resolved_xlabel,
    ylabel=resolved_ylabel,
    zlabel=resolved_zlabel,
    aspect_ratio~,
    axis_center~,
    axis~,
    xscale~,
    yscale~,
    legend~,
    autoscale~,
    margin~,
  )
  if show {
    backend_obj.show()
  }
  backend_obj
}

///|
pub fn plot_contour(
  args : Array[PlotInput],
  show? : Bool = true,
  backend? : String = "default",
  adaptive? : Bool = false,
  n? : Int = 100,
  n1? : Int? = None,
  n2? : Int? = None,
  use_cm? : Bool = false,
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
) -> Plot raise PlottingError {
  if backend == "text" {
    raise PlottingError::TypeError(
      "plot_contour only supports the default or matplotlib backend",
    )
  }
  let resolved_n1 = match n1 {
    Some(value) => value
    None => n
  }
  let resolved_n2 = match n2 {
    Some(value) => value
    None => n
  }
  let specs = plot_build_surface_specs(args)
  let series : Array[PlotSeries] = []
  for spec in specs {
    let (expr, range_x, range_y, label, rendering_kw) = spec
    series.push(
      PlotSeries::Contour(
        contour_series(
          expr,
          range_x,
          range_y,
          label~,
          rendering_kw~,
          adaptive~,
          n1=resolved_n1,
          n2=resolved_n2,
          use_cm~,
          xscale~,
          yscale~,
        ),
      ),
    )
  }
  let resolved_xlabel = match xlabel {
    Some(value) => Some(value)
    None =>
      if specs.is_empty() {
        Some("x")
      } else {
        let (_, range_x, _, _, _) = specs[0]
        Some(@symprint.to_string(plot_range_symbol(range_x)))
      }
  }
  let resolved_ylabel = match ylabel {
    Some(value) => Some(value)
    None =>
      if specs.is_empty() {
        Some("y")
      } else {
        let (_, _, range_y, _, _) = specs[0]
        Some(@symprint.to_string(plot_range_symbol(range_y)))
      }
  }
  let resolved_zlabel = match zlabel {
    Some(value) => Some(value)
    None =>
      if specs.is_empty() {
        Some("f(x, y)")
      } else {
        let (_, range_x, range_y, _, _) = specs[0]
        Some(
          @symprint.to_string(
            @symcore.function("f", [
              plot_range_symbol(range_x),
              plot_range_symbol(range_y),
            ]),
          ),
        )
      }
  }
  let backend_obj = plot_factory(
    series,
    backend~,
    title~,
    xlabel=resolved_xlabel,
    ylabel=resolved_ylabel,
    zlabel=resolved_zlabel,
    aspect_ratio~,
    axis_center~,
    axis~,
    xscale~,
    yscale~,
    legend~,
    autoscale~,
    margin~,
  )
  if show {
    backend_obj.show()
  }
  backend_obj
}

///|
pub fn plot3d_parametric_surface(
  args : Array[Parametric3DPlotInput],
  show? : Bool = true,
  backend? : String = "default",
  adaptive? : Bool = false,
  n? : Int = 100,
  n1? : Int? = None,
  n2? : Int? = None,
  use_cm? : Bool = false,
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
) -> Plot raise PlottingError {
  if backend == "text" {
    raise PlottingError::TypeError(
      "plot3d_parametric_surface only supports the default or matplotlib backend",
    )
  }
  let resolved_n1 = match n1 {
    Some(value) => value
    None => n
  }
  let resolved_n2 = match n2 {
    Some(value) => value
    None => n
  }
  let specs = plot_build_parametric_surface_specs(args)
  let series : Array[PlotSeries] = []
  for spec in specs {
    let (expr_x, expr_y, expr_z, range_u, range_v, label, rendering_kw) = spec
    series.push(
      PlotSeries::ParametricSurface(
        parametric_surface_series(
          expr_x,
          expr_y,
          expr_z,
          range_u,
          range_v,
          label~,
          rendering_kw~,
          adaptive~,
          n1=resolved_n1,
          n2=resolved_n2,
          use_cm~,
          xscale~,
          yscale~,
        ),
      ),
    )
  }
  let resolved_xlabel = match xlabel {
    Some(value) => Some(value)
    None => Some("x")
  }
  let resolved_ylabel = match ylabel {
    Some(value) => Some(value)
    None => Some("y")
  }
  let resolved_zlabel = match zlabel {
    Some(value) => Some(value)
    None => Some("z")
  }
  let backend_obj = plot_factory(
    series,
    backend~,
    title~,
    xlabel=resolved_xlabel,
    ylabel=resolved_ylabel,
    zlabel=resolved_zlabel,
    aspect_ratio~,
    axis_center~,
    axis~,
    xscale~,
    yscale~,
    legend~,
    autoscale~,
    margin~,
  )
  if show {
    backend_obj.show()
  }
  backend_obj
}

///|
fn plot_implicit_range_tuple(
  value : @symcore.Expr,
) -> @symcore.Expr raise PlottingError {
  if is_plot_range(value) {
    return value
  }
  match value {
    @symcore.Expr::Symbol(_) | @symcore.Expr::Dummy(_, _) =>
      @symcore.Expr::Tuple([value, @symcore.int(-5), @symcore.int(5)])
    _ =>
      raise PlottingError::ValueError(
        "symbol or `(symbol, min, max)` expected but got " +
        @symprint.to_string(value),
      )
  }
}

///|
pub fn plot_implicit(
  expr : @symcore.Expr,
  x_var? : @symcore.Expr? = None,
  y_var? : @symcore.Expr? = None,
  adaptive? : Bool = true,
  depth? : Int = 0,
  n? : Int = 300,
  line_color? : String = "blue",
  show? : Bool = true,
  backend? : String = "default",
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
) -> Plot raise PlottingError {
  if backend == "text" {
    raise PlottingError::TypeError(
      "plot_implicit only supports the default or matplotlib backend",
    )
  }
  let xyvar : Array[@symcore.Expr] = []
  match x_var {
    Some(value) => xyvar.push(value)
    None => ()
  }
  match y_var {
    Some(value) => xyvar.push(value)
    None => ()
  }
  let free_symbols = plot_free_symbols([expr])
  let range_symbols : Array[@symcore.Expr] = []
  for item in xyvar {
    if is_plot_range(item) {
      range_symbols.push(plot_range_symbol(item))
    } else {
      range_symbols.push(item)
    }
  }
  let overlap_count = free_symbols
    .filter(symbol => range_symbols.contains(symbol))
    .length()
  if overlap_count > 2 {
    raise PlottingError::ValueError(
      "Implicit plotting is not implemented for more than 2 variables",
    )
  }

  let resolved_xyvar : Array[@symcore.Expr] = []
  if xyvar.is_empty() {
    for symbol in free_symbols {
      resolved_xyvar.push(symbol)
    }
  } else {
    for item in xyvar {
      resolved_xyvar.push(item)
    }
  }
  if resolved_xyvar.is_empty() {
    resolved_xyvar.push(plot_default_symbol())
  }

  let range_x = plot_implicit_range_tuple(resolved_xyvar[0])
  let symbol_x = plot_range_symbol(range_x)
  let undeclared = free_symbols.filter(symbol => !range_symbols.contains(symbol))
  if resolved_xyvar.length() != 2 {
    let mut extra_symbol : @symcore.Expr? = None
    for symbol in undeclared {
      if symbol != symbol_x {
        extra_symbol = Some(symbol)
        break
      }
    }
    match extra_symbol {
      Some(value) => resolved_xyvar.push(value)
      None => resolved_xyvar.push(plot_secondary_default_symbol(symbol_x))
    }
  }
  let range_y = plot_implicit_range_tuple(resolved_xyvar[1])
  let series = PlotSeries::Implicit(
    implicit_series(expr, range_x, range_y, adaptive~, depth~, n~, line_color~),
  )

  let resolved_xlabel = match xlabel {
    Some(value) => Some(value)
    None => Some(@symprint.to_string(plot_range_symbol(range_x)))
  }
  let resolved_ylabel = match ylabel {
    Some(value) => Some(value)
    None => Some(@symprint.to_string(plot_range_symbol(range_y)))
  }
  let backend_obj = plot_factory(
    [series],
    backend~,
    title~,
    xlabel=resolved_xlabel,
    ylabel=resolved_ylabel,
    zlabel~,
    aspect_ratio~,
    axis_center~,
    axis~,
    xscale~,
    yscale~,
    legend~,
    autoscale~,
    margin~,
  )
  if show {
    backend_obj.show()
  }
  backend_obj
}
