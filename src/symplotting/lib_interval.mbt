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
fn plot_interval_log10(value : PlotInterval) -> PlotInterval {
  if value.is_valid == Some(false) || value.end <= 0.0 {
    return plot_interval_invalid(Some(false))
  }
  if value.start <= 0.0 {
    return plot_interval_invalid(None)
  }
  plot_interval(
    @math.log10(value.start),
    @math.log10(value.end),
    is_valid=value.is_valid,
  )
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
fn plot_interval_atan(value : PlotInterval) -> PlotInterval {
  plot_interval(
    @math.atan(value.start),
    @math.atan(value.end),
    is_valid=value.is_valid,
  )
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
fn plot_interval_asin(value : PlotInterval) -> PlotInterval {
  if value.is_valid == Some(false) || value.start > 1.0 || value.end < -1.0 {
    return plot_interval_invalid(Some(false))
  }
  if value.start < -1.0 || value.end > 1.0 {
    return plot_interval_invalid(None)
  }
  plot_interval(
    @math.asin(value.start),
    @math.asin(value.end),
    is_valid=value.is_valid,
  )
}

///|
fn plot_interval_acos(value : PlotInterval) -> PlotInterval {
  if value.is_valid == Some(false) || value.start > 1.0 || value.end < -1.0 {
    return plot_interval_invalid(Some(false))
  }
  if value.start < -1.0 || value.end > 1.0 {
    return plot_interval_invalid(None)
  }
  plot_interval(
    @math.acos(value.start),
    @math.acos(value.end),
    is_valid=value.is_valid,
  )
}

///|
fn plot_interval_ceiling(value : PlotInterval) -> PlotInterval {
  if value.is_valid == Some(false) {
    return plot_interval_invalid(Some(false))
  }
  let start = @math.ceil(value.start)
  let end = @math.ceil(value.end)
  if start == end {
    plot_interval(start, end, is_valid=value.is_valid)
  } else {
    plot_interval(start, end, is_valid=None)
  }
}

///|
fn plot_interval_floor(value : PlotInterval) -> PlotInterval {
  if value.is_valid == Some(false) {
    return plot_interval_invalid(Some(false))
  }
  let start = @math.floor(value.start)
  let end = @math.floor(value.end)
  if start == end {
    plot_interval(start, end, is_valid=value.is_valid)
  } else {
    plot_interval(start, end, is_valid=None)
  }
}

///|
fn plot_interval_tan(value : PlotInterval) -> PlotInterval {
  plot_interval_div(plot_interval_sin(value), plot_interval_cos(value))
}

///|
fn plot_interval_sinh(value : PlotInterval) -> PlotInterval {
  plot_interval(
    @math.sinh(value.start),
    @math.sinh(value.end),
    is_valid=value.is_valid,
  )
}

///|
fn plot_interval_cosh(value : PlotInterval) -> PlotInterval {
  if value.start < 0.0 && value.end > 0.0 {
    return plot_interval(
      1.0,
      plot_max2(@math.cosh(value.start), @math.cosh(value.end)),
      is_valid=value.is_valid,
    )
  }
  plot_interval(
    @math.cosh(value.start),
    @math.cosh(value.end),
    is_valid=value.is_valid,
  )
}

///|
fn plot_interval_tanh(value : PlotInterval) -> PlotInterval {
  plot_interval(
    @math.tanh(value.start),
    @math.tanh(value.end),
    is_valid=value.is_valid,
  )
}

///|
fn plot_interval_asinh(value : PlotInterval) -> PlotInterval {
  plot_interval(
    @math.asinh(value.start),
    @math.asinh(value.end),
    is_valid=value.is_valid,
  )
}

///|
fn plot_interval_acosh(value : PlotInterval) -> PlotInterval {
  if value.end < 1.0 {
    return plot_interval_invalid(Some(false))
  }
  if value.start < 1.0 {
    return plot_interval_invalid(None)
  }
  plot_interval(
    @math.acosh(value.start),
    @math.acosh(value.end),
    is_valid=value.is_valid,
  )
}

///|
fn plot_interval_atanh(value : PlotInterval) -> PlotInterval {
  if value.is_valid == Some(false) || value.start >= 1.0 || value.end <= -1.0 {
    return plot_interval_invalid(Some(false))
  }
  if value.start <= -1.0 || value.end >= 1.0 {
    return plot_interval_invalid(None)
  }
  plot_interval(
    @math.atanh(value.start),
    @math.atanh(value.end),
    is_valid=value.is_valid,
  )
}

///|
fn plot_interval_min(values : Array[PlotInterval]) -> PlotInterval {
  let valid_values = values.filter(v => v.is_valid != Some(false))
  if valid_values.is_empty() {
    if values.all(v => v.is_valid == Some(false)) {
      return plot_interval_invalid(Some(false))
    } else {
      return plot_interval_invalid(None)
    }
  }
  let mut start = valid_values[0].start
  let mut end = valid_values[0].end
  for value in valid_values {
    if value.start < start {
      start = value.start
    }
    if value.end < end {
      end = value.end
    }
  }
  plot_interval(start, end)
}

///|
fn plot_interval_max(values : Array[PlotInterval]) -> PlotInterval {
  let valid_values = values.filter(v => v.is_valid != Some(false))
  if valid_values.is_empty() {
    if values.all(v => v.is_valid == Some(false)) {
      return plot_interval_invalid(Some(false))
    } else {
      return plot_interval_invalid(None)
    }
  }
  let mut start = valid_values[0].start
  let mut end = valid_values[0].end
  for value in valid_values {
    if value.start > start {
      start = value.start
    }
    if value.end > end {
      end = value.end
    }
  }
  plot_interval(start, end)
}
