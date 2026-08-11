///|
fn plot_min2(lhs : Double, rhs : Double) -> Double {
  if lhs <= rhs {
    lhs
  } else {
    rhs
  }
}

///|
fn plot_max2(lhs : Double, rhs : Double) -> Double {
  if lhs >= rhs {
    lhs
  } else {
    rhs
  }
}

///|
priv struct PlotInterval {
  start : Double
  end : Double
  is_valid : Bool?
}

///|
fn plot_interval(
  start : Double,
  end : Double,
  is_valid? : Bool? = Some(true),
) -> PlotInterval {
  if start <= end {
    { start, end, is_valid }
  } else {
    { start: end, end: start, is_valid }
  }
}

///|
fn plot_interval_point(value : Double) -> PlotInterval {
  plot_interval(value, value)
}

///|
fn plot_interval_invalid(validity : Bool?) -> PlotInterval {
  { start: -1.0 / 0.0, end: 1.0 / 0.0, is_valid: validity }
}

///|
fn plot_interval_width(value : PlotInterval) -> Double {
  value.end - value.start
}

///|
fn plot_interval_contains(value : PlotInterval, other : Double) -> Bool {
  value.start <= other && other <= value.end
}

///|
fn plot_interval_add(lhs : PlotInterval, rhs : PlotInterval) -> PlotInterval {
  plot_interval(
    lhs.start + rhs.start,
    lhs.end + rhs.end,
    is_valid=plot_fuzzy_and([lhs.is_valid, rhs.is_valid]),
  )
}

///|
fn plot_interval_mul(lhs : PlotInterval, rhs : PlotInterval) -> PlotInterval {
  if lhs.is_valid == Some(false) || rhs.is_valid == Some(false) {
    return plot_interval_invalid(Some(false))
  }
  if lhs.is_valid == None || rhs.is_valid == None {
    return plot_interval_invalid(None)
  }
  let products = [
    lhs.start * rhs.start,
    lhs.start * rhs.end,
    lhs.end * rhs.start,
    lhs.end * rhs.end,
  ]
  let mut lo = products[0]
  let mut hi = products[0]
  for value in products {
    if value < lo {
      lo = value
    }
    if value > hi {
      hi = value
    }
  }
  plot_interval(lo, hi, is_valid=plot_fuzzy_and([lhs.is_valid, rhs.is_valid]))
}

///|
fn plot_interval_div(lhs : PlotInterval, rhs : PlotInterval) -> PlotInterval {
  if lhs.is_valid == Some(false) {
    return plot_interval_invalid(Some(false))
  }
  if lhs.is_valid == None {
    return plot_interval_invalid(None)
  }
  let validity = plot_fuzzy_and([lhs.is_valid, rhs.is_valid])
  if rhs.is_valid == Some(false) {
    return plot_interval_invalid(Some(false))
  }
  if rhs.is_valid == None {
    return plot_interval_invalid(None)
  }
  if plot_interval_contains(rhs, 0.0) {
    return plot_interval_invalid(None)
  }
  let quotients = [
    lhs.start / rhs.start,
    lhs.start / rhs.end,
    lhs.end / rhs.start,
    lhs.end / rhs.end,
  ]
  let mut lo = quotients[0]
  let mut hi = quotients[0]
  for value in quotients {
    if value < lo {
      lo = value
    }
    if value > hi {
      hi = value
    }
  }
  plot_interval(lo, hi, is_valid=validity)
}

///|
fn plot_interval_pow_int(value : PlotInterval, power : Int) -> PlotInterval {
  if value.is_valid != Some(true) {
    return value
  }
  if power < 0 {
    return plot_interval_div(
      plot_interval_point(1.0),
      plot_interval_pow_int(value, -power),
    )
  }
  let p = power.to_double()
  if power % 2 == 1 {
    return plot_interval(
      @math.pow(value.start, p),
      @math.pow(value.end, p),
      is_valid=value.is_valid,
    )
  }
  if value.start < 0.0 && value.end > 0.0 {
    let lo = 0.0
    let hi = plot_max2(@math.pow(value.start, p), @math.pow(value.end, p))
    return plot_interval(lo, hi, is_valid=value.is_valid)
  }
  plot_interval(
    @math.pow(value.start, p),
    @math.pow(value.end, p),
    is_valid=value.is_valid,
  )
}

///|
fn plot_interval_pow_float(
  value : PlotInterval,
  power : Double,
) -> PlotInterval {
  if value.is_valid != Some(true) {
    return value
  }
  let rounded = @math.floor(power + 0.5)
  if (power - rounded).abs() <= 1.0e-10 {
    return plot_interval_pow_int(value, rounded.to_int())
  }
  if value.end < 0.0 {
    return plot_interval_invalid(Some(false))
  }
  if value.start < 0.0 {
    return plot_interval_invalid(None)
  }
  plot_interval(
    @math.pow(value.start, power),
    @math.pow(value.end, power),
    is_valid=value.is_valid,
  )
}

///|
fn plot_interval_pow_rational(
  value : PlotInterval,
  numerator : BigInt,
  denominator : BigInt,
) -> PlotInterval {
  if value.is_valid != Some(true) {
    return value
  }
  if numerator.compare(0N) < 0 {
    return plot_interval_div(
      plot_interval_point(1.0),
      plot_interval_pow_rational(value, numerator.neg(), denominator),
    )
  }
  if denominator.equal_int(1) {
    return plot_interval_pow_int(value, numerator.to_int())
  }
  let power = numerator.to_int().to_double() / denominator.to_int().to_double()
  if numerator.mod(2N).compare(0N) == 0 {
    let start = @math.pow(value.start.abs(), power)
    let end = @math.pow(value.end.abs(), power)
    if start < 0.0 {
      return plot_interval(0.0, plot_max2(start, end))
    }
    return plot_interval(start, end)
  }
  if denominator.mod(2N).compare(0N) == 0 {
    if value.end < 0.0 {
      return plot_interval_invalid(Some(false))
    }
    if value.start < 0.0 {
      return plot_interval(0.0, @math.pow(value.end, power), is_valid=None)
    }
    return plot_interval(
      @math.pow(value.start, power),
      @math.pow(value.end, power),
    )
  }
  let start = if value.start < 0.0 {
    -@math.pow(value.start.abs(), power)
  } else {
    @math.pow(value.start, power)
  }
  let end = if value.end < 0.0 {
    -@math.pow(value.end.abs(), power)
  } else {
    @math.pow(value.end, power)
  }
  plot_interval(start, end, is_valid=value.is_valid)
}

///|
fn plot_interval_compare_lt(
  lhs : PlotInterval,
  rhs : PlotInterval,
) -> IntervalMembership {
  let validity = plot_fuzzy_and([lhs.is_valid, rhs.is_valid])
  if lhs.end < rhs.start {
    interval_membership(Some(true), validity)
  } else if lhs.start > rhs.end {
    interval_membership(Some(false), validity)
  } else {
    interval_membership(None, validity)
  }
}

///|
fn plot_interval_compare_le(
  lhs : PlotInterval,
  rhs : PlotInterval,
) -> IntervalMembership {
  let validity = plot_fuzzy_and([lhs.is_valid, rhs.is_valid])
  if lhs.end <= rhs.start {
    interval_membership(Some(true), validity)
  } else if lhs.start > rhs.end {
    interval_membership(Some(false), validity)
  } else {
    interval_membership(None, validity)
  }
}

///|
fn plot_interval_compare_gt(
  lhs : PlotInterval,
  rhs : PlotInterval,
) -> IntervalMembership {
  plot_interval_compare_lt(rhs, lhs)
}

///|
fn plot_interval_compare_ge(
  lhs : PlotInterval,
  rhs : PlotInterval,
) -> IntervalMembership {
  plot_interval_compare_le(rhs, lhs)
}

///|
fn plot_interval_compare_eq(
  lhs : PlotInterval,
  rhs : PlotInterval,
) -> IntervalMembership {
  let validity = plot_fuzzy_and([lhs.is_valid, rhs.is_valid])
  if lhs.start == rhs.start && lhs.end == rhs.end {
    interval_membership(Some(true), validity)
  } else if lhs.end < rhs.start || lhs.start > rhs.end {
    interval_membership(Some(false), validity)
  } else {
    interval_membership(None, validity)
  }
}

///|
fn plot_interval_compare_ne(
  lhs : PlotInterval,
  rhs : PlotInterval,
) -> IntervalMembership {
  let eq = plot_interval_compare_eq(lhs, rhs)
  interval_membership(plot_fuzzy_not(eq.truth), eq.validity)
}
