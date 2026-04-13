///|
fn plot_interval_abs(value : PlotInterval) -> PlotInterval {
  if value.start < 0.0 && value.end > 0.0 {
    plot_interval(
      0.0,
      plot_max2(value.start.abs(), value.end.abs()),
      is_valid=value.is_valid,
    )
  } else {
    plot_interval(value.start.abs(), value.end.abs(), is_valid=value.is_valid)
  }
}

///|
fn plot_interval_exp(value : PlotInterval) -> PlotInterval {
  plot_interval(
    @math.exp(value.start),
    @math.exp(value.end),
    is_valid=value.is_valid,
  )
}

///|
fn plot_interval_log(value : PlotInterval) -> PlotInterval {
  if value.is_valid == Some(false) || value.end <= 0.0 {
    return plot_interval_invalid(Some(false))
  }
  if value.start <= 0.0 {
    return plot_interval_invalid(None)
  }
  plot_interval(@math.ln(value.start), @math.ln(value.end), is_valid=value.is_valid)
}

///|
fn plot_interval_sqrt(value : PlotInterval) -> PlotInterval {
  if value.is_valid == Some(false) || value.end < 0.0 {
    return plot_interval_invalid(Some(false))
  }
  if value.start < 0.0 {
    return plot_interval_invalid(None)
  }
  plot_interval(value.start.sqrt(), value.end.sqrt(), is_valid=value.is_valid)
}

///|
fn plot_interval_sin(value : PlotInterval) -> PlotInterval {
  let start = plot_min2(@math.sin(value.start), @math.sin(value.end))
  let end = plot_max2(@math.sin(value.start), @math.sin(value.end))
  let quarter_turns = (value.end - value.start) / (@math.PI / 2.0)
  if quarter_turns > 4.0 {
    return plot_interval(-1.0, 1.0, is_valid=value.is_valid)
  }
  let na = @math.floor(value.start / (@math.PI / 2.0))
  let nb = @math.floor(value.end / (@math.PI / 2.0))
  let mut lo = start
  let mut hi = end
  if @math.floor((na - 1.0) / 4.0) != @math.floor((nb - 1.0) / 4.0) {
    hi = 1.0
  }
  if @math.floor((na - 3.0) / 4.0) != @math.floor((nb - 3.0) / 4.0) {
    lo = -1.0
  }
  plot_interval(lo, hi, is_valid=value.is_valid)
}

///|
fn plot_interval_cos(value : PlotInterval) -> PlotInterval {
  let start = plot_min2(@math.cos(value.start), @math.cos(value.end))
  let end = plot_max2(@math.cos(value.start), @math.cos(value.end))
  let quarter_turns = (value.end - value.start) / (@math.PI / 2.0)
  if quarter_turns > 4.0 {
    return plot_interval(-1.0, 1.0, is_valid=value.is_valid)
  }
  let na = @math.floor(value.start / (@math.PI / 2.0))
  let nb = @math.floor(value.end / (@math.PI / 2.0))
  let mut lo = start
  let mut hi = end
  if @math.floor(na / 4.0) != @math.floor(nb / 4.0) {
    hi = 1.0
  }
  if @math.floor((na - 2.0) / 4.0) != @math.floor((nb - 2.0) / 4.0) {
    lo = -1.0
  }
  plot_interval(lo, hi, is_valid=value.is_valid)
}

///|
fn plot_interval_tan(value : PlotInterval) -> PlotInterval {
  plot_interval_div(plot_interval_sin(value), plot_interval_cos(value))
}
