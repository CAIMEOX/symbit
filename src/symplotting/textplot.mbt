///|
fn textplot_repeat(ch : Char, count : Int) -> String {
  let chars : Array[Char] = []
  for _ in 0..<count {
    chars.push(ch)
  }
  String::from_array(chars)
}

///|
fn textplot_trim_trailing_zeros(text : String) -> String {
  if !text.contains(".") {
    return text
  }
  let chars = text.to_array()
  let mut end = chars.length()
  while end > 0 && chars[end - 1] == '0' {
    end -= 1
  }
  if end > 0 && chars[end - 1] == '.' {
    end -= 1
  }
  if end <= 0 {
    "0"
  } else {
    String::from_array(chars[:end].to_array())
  }
}

///|
fn textplot_format_number(value : Double) -> String {
  let normalized = if value.abs() <= 1.0e-12 { 0.0 } else { value }
  textplot_trim_trailing_zeros(
    @symcore.Float::from_double(normalized, prec=80).format(dps=12),
  )
}

///|
fn textplot_rjust(text : String, width : Int) -> String {
  if text.length() >= width {
    text.unsafe_substring(start=0, end=width)
  } else {
    textplot_repeat(' ', width - text.length()) + text
  }
}

///|
fn textplot_ljust(text : String, width : Int) -> String {
  if text.length() >= width {
    text.unsafe_substring(start=0, end=width)
  } else {
    text + textplot_repeat(' ', width - text.length())
  }
}

///|
fn textplot_expr_to_double(expr : @symcore.Expr) -> Double raise PlottingError {
  @symutilities.lambdify([], expr).call([]) catch {
    _ =>
      raise PlottingError::ValueError(
        "textplot bounds must be real numeric expressions",
      )
  }
}

///|
fn textplot_eval_value(expr : @symcore.Expr, sample : Double) -> Double? {
  Some(@symutilities.lambdify(["__plot_var"], expr).call([sample])) catch {
    _ => None
  }
}

///|
fn textplot_single_variable(
  expr : @symcore.Expr,
) -> @symcore.Expr raise PlottingError {
  let free = @symcore.free_symbols(expr)
  if free.length() > 1 {
    let rendered = free.map(@symprint.to_string).join(", ")
    raise PlottingError::ValueError(
      "The expression must have a single variable. (Got {" + rendered + "})",
    )
  }
  if free.is_empty() {
    @symcore.Expr::Symbol("__plot_var")
  } else {
    free[0]
  }
}

///|
pub fn linspace(start : Double, stop : Double, num : Int) -> Array[Double] {
  if num <= 1 {
    return [start]
  }
  let out : Array[Double] = []
  let denom = (num - 1).to_double()
  for x in 0..<num {
    out.push(start + (stop - start) * x.to_double() / denom)
  }
  out
}

///|
pub fn rescale(
  y : Array[Double?],
  width : Int,
  height : Int,
  min_value : Double,
  max_value : Double,
) -> Array[Int?] {
  let out : Array[Int?] = []
  let norm = max_value - min_value
  let offset = (max_value + min_value) / 2.0
  for x in 0..<width {
    match y[x] {
      Some(value) => {
        let normalized = (value - offset) / norm
        if !@symcore.Float::from_double(normalized).is_finite() {
          out.push(None)
        } else {
          let scaled = (
              normalized * height.to_double() + height.to_double() / 2.0
            ) *
            (height - 1).to_double() /
            height.to_double()
          out.push(Some(@math.floor(scaled + 0.5).to_int()))
        }
      }
      None => out.push(None)
    }
  }
  out
}

///|
pub fn textplot_str(
  expr : @symcore.Expr,
  a0 : @symcore.Expr,
  b0 : @symcore.Expr,
  width? : Int = 55,
  height? : Int = 21,
) -> Array[String] raise PlottingError {
  let free_symbol = textplot_single_variable(expr)
  let normalized_expr = if free_symbol == @symcore.Expr::Symbol("__plot_var") {
    expr
  } else {
    @symcore.xreplace(expr, [(free_symbol, @symcore.Expr::Symbol("__plot_var"))])
  }

  let a = textplot_expr_to_double(a0)
  let b = textplot_expr_to_double(b0)
  let x_values = linspace(a, b, width)
  let y_values : Array[Double?] = []
  for value in x_values {
    y_values.push(textplot_eval_value(normalized_expr, value))
  }

  let valid : Array[Double] = []
  for item in y_values {
    match item {
      Some(value) if @symcore.Float::from_double(value).is_finite() =>
        valid.push(value)
      _ => ()
    }
  }

  let (min_value, max_value) = if valid.is_empty() {
    (-1.0, 1.0)
  } else {
    let mut min_v = valid[0]
    let mut max_v = valid[0]
    for value in valid {
      if value < min_v {
        min_v = value
      }
      if value > max_v {
        max_v = value
      }
    }
    if max_v == min_v {
      if max_v != 0.0 {
        let pair = [0.0, 2.0 * max_v]
        if pair[0] <= pair[1] {
          (pair[0], pair[1])
        } else {
          (pair[1], pair[0])
        }
      } else {
        (-1.0, 1.0)
      }
    } else {
      let y_range = max_v - min_v
      let precision = -1 * (@math.floor(@math.log10(y_range)) - 1.0).to_int()
      let scale = @math.pow(10.0, precision.to_double())
      let min_r = @math.floor(min_v * scale + 0.5) / scale
      let max_r = @math.floor(max_v * scale + 0.5) / scale
      (min_r, max_r)
    }
  }

  let scaled_y = rescale(y_values, width, height, min_value, max_value)
  let y_bins = linspace(min_value, max_value, height)
  let margin = 7
  let out : Array[String] = []

  for row in 0..<height {
    let h = height - row - 1
    let chars : Array[Char] = Array::make(width, ' ')
    for i in 0..<width {
      if scaled_y[i] == Some(h) {
        let left = if i == 0 { None } else { scaled_y[i - 1] }
        let right = if i == width - 1 { None } else { scaled_y[i + 1] }
        let glyph = if (left == Some(h - 1) || i == 0) &&
          (right == Some(h + 1) || i == width - 1) {
          '/'
        } else if (left == Some(h + 1) || i == 0) &&
          (right == Some(h - 1) || i == width - 1) {
          '\\'
        } else {
          '.'
        }
        chars[i] = glyph
      }
    }
    if h == 0 {
      for i in 0..<width {
        chars[i] = '_'
      }
    }

    let prefix = if h == 0 || h == height / 2 || h == height - 1 {
      textplot_rjust(textplot_format_number(y_bins[h]), margin)
    } else {
      textplot_repeat(' ', margin)
    }
    if h == height / 2 {
      for i in 0..<width {
        if chars[i] == ' ' {
          chars[i] = '-'
        }
      }
    }
    out.push(prefix + " |" + String::from_array(chars))
  }

  let mut bottom = textplot_repeat(' ', margin + 2)
  bottom += textplot_ljust(textplot_format_number(x_values[0]), width / 2)
  if width % 2 == 1 {
    bottom += textplot_ljust(
      textplot_format_number(x_values[width / 2]),
      width / 2,
    )
  } else {
    bottom += textplot_ljust(
      textplot_format_number(x_values[width / 2]),
      width / 2 - 1,
    )
  }
  bottom += textplot_format_number(x_values[width - 1])
  out.push(bottom)
  out
}

///|
pub fn textplot(
  expr : @symcore.Expr,
  a0 : @symcore.Expr,
  b0 : @symcore.Expr,
  width? : Int = 55,
  height? : Int = 21,
) -> Unit raise PlottingError {
  for line in textplot_str(expr, a0, b0, width~, height~) {
    println(line)
  }
}
