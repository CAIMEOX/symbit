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
pub fn plot_factory(
  series : Array[LineOver1DRangeSeries],
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
  let series : Array[LineOver1DRangeSeries] = []
  for spec in specs {
    let (expr, range, label, rendering_kw) = spec
    series.push(
      line_over_1d_range_series(
        expr,
        range,
        label~,
        rendering_kw~,
        adaptive~,
        only_integers~,
        n~,
        return_mode~,
        xscale~,
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
