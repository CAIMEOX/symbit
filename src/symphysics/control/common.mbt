///|
/// Shared symbolic and numeric helpers for `physics.control`.

///|
pub type ControlComplex = (Double, Double)

///|
fn control_expr_number(expr : @symcore.Expr) -> @symnum.BigRational? {
  match expr {
    @symcore.Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
fn control_number_text_to_double(text : String) -> Double? {
  let parts = Array::from_iter(text.split("/"))
  if parts.length() == 1 {
    try @strconv.parse_double(parts[0]) catch {
      _ => None
    } noraise {
      value => Some(value)
    }
  } else if parts.length() == 2 {
    match
      (
        try? @strconv.parse_double(parts[0]),
        try? @strconv.parse_double(parts[1]),
      ) {
      (Ok(num), Ok(den)) => Some(num / den)
      _ => None
    }
  } else {
    None
  }
}

///|
fn control_rational_to_double(value : @symnum.BigRational) -> Double? {
  control_number_text_to_double(value.to_string())
}

///|
fn control_expr_depends_on_symbol(expr : @symcore.Expr, name : String) -> Bool {
  match expr {
    @symcore.Expr::Symbol(sym) => sym == name
    @symcore.Expr::Add(args)
    | @symcore.Expr::Mul(args)
    | @symcore.Expr::Function(_, args) =>
      args.any(arg => control_expr_depends_on_symbol(arg, name))
    @symcore.Expr::Pow(base, exp) =>
      control_expr_depends_on_symbol(base, name) ||
      control_expr_depends_on_symbol(exp, name)
    _ => false
  }
}

///|
fn control_collect_symbols(
  expr : @symcore.Expr,
  seen : Map[String, Bool],
) -> Unit {
  match expr {
    @symcore.Expr::Symbol(name) => seen[name] = true
    @symcore.Expr::Add(args)
    | @symcore.Expr::Mul(args)
    | @symcore.Expr::Function(_, args) =>
      for arg in args {
        control_collect_symbols(arg, seen)
      }
    @symcore.Expr::Pow(base, exp) => {
      control_collect_symbols(base, seen)
      control_collect_symbols(exp, seen)
    }
    _ => ()
  }
}

///|
fn control_has_extra_free_symbols(
  expr : @symcore.Expr,
  variable_name : String,
) -> Bool {
  let seen : Map[String, Bool] = {}
  control_collect_symbols(expr, seen)
  for name, _ in seen {
    if name != variable_name && name != "I" && name != "pi" && name != "oo" {
      return true
    }
  }
  false
}

///|
fn control_double_pow(base : Double, exp : Int) -> Double {
  if exp == 0 {
    return 1.0
  }
  if exp < 0 {
    return 1.0 / control_double_pow(base, -exp)
  }
  let mut out = 1.0
  let mut cur = base
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      out = out * cur
    }
    e = e / 2
    if e > 0 {
      cur = cur * cur
    }
  }
  out
}

///|
fn control_complex_add(
  lhs : ControlComplex,
  rhs : ControlComplex,
) -> ControlComplex {
  (lhs.0 + rhs.0, lhs.1 + rhs.1)
}

///|
fn control_complex_sub(
  lhs : ControlComplex,
  rhs : ControlComplex,
) -> ControlComplex {
  (lhs.0 - rhs.0, lhs.1 - rhs.1)
}

///|
fn control_complex_mul(
  lhs : ControlComplex,
  rhs : ControlComplex,
) -> ControlComplex {
  (lhs.0 * rhs.0 - lhs.1 * rhs.1, lhs.0 * rhs.1 + lhs.1 * rhs.0)
}

///|
fn control_complex_scale(
  value : ControlComplex,
  scalar : Double,
) -> ControlComplex {
  (value.0 * scalar, value.1 * scalar)
}

///|
fn control_complex_abs2(value : ControlComplex) -> Double {
  value.0 * value.0 + value.1 * value.1
}

///|
fn control_complex_abs(value : ControlComplex) -> Double {
  control_complex_abs2(value).sqrt()
}

///|
fn control_complex_arg(value : ControlComplex) -> Double {
  @math.atan2(value.1, value.0)
}

///|
fn control_complex_inv(value : ControlComplex) -> ControlComplex? {
  let denom = control_complex_abs2(value)
  if denom.is_close(0.0, absolute_tolerance=1.0e-20, relative_tolerance=1.0e-20) {
    None
  } else {
    Some((value.0 / denom, -value.1 / denom))
  }
}

///|
fn control_complex_div(
  lhs : ControlComplex,
  rhs : ControlComplex,
) -> ControlComplex? {
  match control_complex_inv(rhs) {
    Some(inv) => Some(control_complex_mul(lhs, inv))
    None => None
  }
}

///|
fn control_complex_exp(value : ControlComplex) -> ControlComplex {
  let factor = @math.exp(value.0)
  (factor * @math.cos(value.1), factor * @math.sin(value.1))
}

///|
fn control_complex_log(value : ControlComplex) -> ControlComplex? {
  let mag = control_complex_abs(value)
  if mag <= 0.0 {
    None
  } else {
    Some((@math.ln(mag), control_complex_arg(value)))
  }
}

///|
fn control_complex_sqrt(value : ControlComplex) -> ControlComplex {
  if value.1 == 0.0 && value.0 >= 0.0 {
    return (value.0.sqrt(), 0.0)
  }
  let mag = control_complex_abs(value)
  let re = ((mag + value.0) / 2.0).sqrt()
  let im_mag = ((mag - value.0) / 2.0).sqrt()
  let im = if value.1 < 0.0 { -im_mag } else { im_mag }
  (re, im)
}

///|
fn control_complex_pow_int(
  value : ControlComplex,
  exp : Int,
) -> ControlComplex? {
  if exp == 0 {
    return Some((1.0, 0.0))
  }
  if exp < 0 {
    match control_complex_pow_int(value, -exp) {
      Some(pos) => control_complex_inv(pos)
      None => None
    }
  } else {
    let mut out = (1.0, 0.0)
    let mut cur = value
    let mut e = exp
    while e > 0 {
      if e % 2 == 1 {
        out = control_complex_mul(out, cur)
      }
      e = e / 2
      if e > 0 {
        cur = control_complex_mul(cur, cur)
      }
    }
    Some(out)
  }
}

///|
fn control_complex_is_zero(value : ControlComplex) -> Bool {
  value.0.is_close(0.0, absolute_tolerance=1.0e-12, relative_tolerance=1.0e-12) &&
  value.1.is_close(0.0, absolute_tolerance=1.0e-12, relative_tolerance=1.0e-12)
}

///|
fn control_complex_close(
  lhs : ControlComplex,
  rhs : ControlComplex,
  tol? : Double = 1.0e-8,
) -> Bool {
  let eps = tol
  (lhs.0 - rhs.0).abs() <= eps && (lhs.1 - rhs.1).abs() <= eps
}

///|
fn control_expr_complex_double(
  expr : @symcore.Expr,
  env : Map[String, ControlComplex],
) -> ControlComplex? {
  match expr {
    @symcore.Expr::Number(n) =>
      match control_rational_to_double(n) {
        Some(value) => Some((value, 0.0))
        None => None
      }
    @symcore.Expr::Symbol(name) =>
      match name {
        "I" => Some((0.0, 1.0))
        "pi" => Some((@math.PI, 0.0))
        _ => env.get(name)
      }
    @symcore.Expr::Add(args) => {
      let mut acc = (0.0, 0.0)
      for arg in args {
        match control_expr_complex_double(arg, env) {
          Some(value) => acc = control_complex_add(acc, value)
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Mul(args) => {
      let mut acc = (1.0, 0.0)
      for arg in args {
        match control_expr_complex_double(arg, env) {
          Some(value) => acc = control_complex_mul(acc, value)
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Pow(base, exp) =>
      match (control_expr_complex_double(base, env), control_expr_number(exp)) {
        (Some(base_value), Some(exp_value)) =>
          if exp_value.is_integral() {
            control_complex_pow_int(base_value, exp_value.numerator().to_int())
          } else if base_value.1.abs() <= 1.0e-12 {
            match control_rational_to_double(exp_value) {
              Some(power) => Some((@math.pow(base_value.0, power), 0.0))
              None => None
            }
          } else {
            None
          }
        _ => None
      }
    @symcore.Expr::Function("sqrt", args) if args.length() == 1 =>
      match control_expr_complex_double(args[0], env) {
        Some(value) => Some(control_complex_sqrt(value))
        None => None
      }
    @symcore.Expr::Function("exp", args) if args.length() == 1 =>
      match control_expr_complex_double(args[0], env) {
        Some(value) => Some(control_complex_exp(value))
        None => None
      }
    @symcore.Expr::Function("log", args) if args.length() == 1 =>
      match control_expr_complex_double(args[0], env) {
        Some(value) => control_complex_log(value)
        None => None
      }
    @symcore.Expr::Function("sin", args) if args.length() == 1 =>
      match control_expr_complex_double(args[0], env) {
        Some(value) => {
          let iz = (-value.1, value.0)
          let minus_iz = (value.1, -value.0)
          let diff = control_complex_sub(
            control_complex_exp(iz),
            control_complex_exp(minus_iz),
          )
          Some((diff.1 / 2.0, -diff.0 / 2.0))
        }
        None => None
      }
    @symcore.Expr::Function("cos", args) if args.length() == 1 =>
      match control_expr_complex_double(args[0], env) {
        Some(value) => {
          let iz = (-value.1, value.0)
          let minus_iz = (value.1, -value.0)
          let sum = control_complex_add(
            control_complex_exp(iz),
            control_complex_exp(minus_iz),
          )
          Some((sum.0 / 2.0, sum.1 / 2.0))
        }
        None => None
      }
    @symcore.Expr::Function("Abs", args) if args.length() == 1 =>
      match control_expr_complex_double(args[0], env) {
        Some(value) => Some((control_complex_abs(value), 0.0))
        None => None
      }
    @symcore.Expr::Function("arg", args) if args.length() == 1 =>
      match control_expr_complex_double(args[0], env) {
        Some(value) => Some((control_complex_arg(value), 0.0))
        None => None
      }
    @symcore.Expr::Function("atan", args) if args.length() == 1 =>
      match control_expr_complex_double(args[0], env) {
        Some(value) if value.1.abs() <= 1.0e-12 =>
          Some((@math.atan(value.0), 0.0))
        _ => None
      }
    @symcore.Expr::Function("atan2", args) if args.length() == 2 =>
      match
        (
          control_expr_complex_double(args[0], env),
          control_expr_complex_double(args[1], env),
        ) {
        (Some(y), Some(x)) if y.1.abs() <= 1.0e-12 && x.1.abs() <= 1.0e-12 =>
          Some((@math.atan2(y.0, x.0), 0.0))
        _ => None
      }
    _ => None
  }
}

///|
fn control_expr_real_double(
  expr : @symcore.Expr,
  env? : Map[String, Double] = {},
) -> Double? {
  let complex_env : Map[String, ControlComplex] = {}
  for name, value in env {
    complex_env[name] = (value, 0.0)
  }
  match control_expr_complex_double(expr, complex_env) {
    Some(value) if value.1.abs() <= 1.0e-10 => Some(value.0)
    _ => None
  }
}

///|
fn control_poly_coeffs_as_doubles(
  expr : @symcore.Expr,
  variable_name : String,
) -> Array[Double]? raise @symphysics.PhysicsError {
  let (_, coeffs) = coeff_array(poly_from_expr(expr, variable_name))
  let out : Array[Double] = []
  for coeff in coeffs {
    match control_expr_real_double(control_normalize(coeff)) {
      Some(value) => out.push(value)
      None => return None
    }
  }
  Some(out)
}

///|
fn control_poly_eval_complex(
  coeffs : Array[ControlComplex],
  z : ControlComplex,
) -> ControlComplex {
  let mut acc = (0.0, 0.0)
  for coeff in coeffs {
    acc = control_complex_add(control_complex_mul(acc, z), coeff)
  }
  acc
}

///|
fn control_trim_leading_zeros(coeffs : Array[Double]) -> Array[Double] {
  let mut idx = 0
  while idx < coeffs.length() - 1 && coeffs[idx].abs() <= 1.0e-16 {
    idx += 1
  }
  coeffs[idx:].to_array()
}

///|
fn control_zero_root_multiplicity(coeffs : Array[Double]) -> Int {
  let mut count = 0
  let mut idx = coeffs.length() - 1
  while idx >= 0 && coeffs[idx].abs() <= 1.0e-14 {
    count += 1
    if idx == 0 {
      break
    }
    idx -= 1
  }
  count
}

///|
fn control_poly_numeric_roots(
  coeffs0 : Array[Double],
) -> Array[ControlComplex]? {
  let coeffs = control_trim_leading_zeros(coeffs0)
  let degree = coeffs.length() - 1
  if degree <= 0 {
    return Some([])
  }
  if coeffs[0].abs() <= 1.0e-16 {
    return None
  }
  let zero_mult = control_zero_root_multiplicity(coeffs)
  let reduced = if zero_mult > 0 {
    coeffs[:coeffs.length() - zero_mult]
  } else {
    coeffs
  }
  let reduced_degree = reduced.length() - 1
  let out : Array[ControlComplex] = []
  for _ in 0..<zero_mult {
    out.push((0.0, 0.0))
  }
  if reduced_degree <= 0 {
    return Some(out)
  }
  let lead = reduced[0]
  let norm : Array[ControlComplex] = []
  for coeff in reduced {
    norm.push((coeff / lead, 0.0))
  }
  let roots : Array[ControlComplex] = []
  let angle_step = 2.0 * @math.PI / reduced_degree.to_double()
  for i in 0..<reduced_degree {
    let angle = angle_step * i.to_double()
    let radius = 1.0 + 0.3 * i.to_double() / reduced_degree.to_double()
    roots.push((radius * @math.cos(angle), radius * @math.sin(angle)))
  }
  let tol = 1.0e-12
  for _ in 0..<250 {
    let mut max_delta = 0.0
    for i in 0..<roots.length() {
      let xi = roots[i]
      let mut denom = (1.0, 0.0)
      for j in 0..<roots.length() {
        if i != j {
          denom = control_complex_mul(denom, control_complex_sub(xi, roots[j]))
        }
      }
      if control_complex_is_zero(denom) {
        denom = control_complex_add(denom, (1.0e-9, 1.0e-9))
      }
      let px = control_poly_eval_complex(norm, xi)
      let delta = match control_complex_div(px, denom) {
        Some(value) => value
        None => return None
      }
      roots[i] = control_complex_sub(xi, delta)
      let step = control_complex_abs(delta)
      if step > max_delta {
        max_delta = step
      }
    }
    if max_delta < tol {
      break
    }
  }
  control_sort_roots_in_place(roots)
  for root in roots {
    out.push(root)
  }
  Some(out)
}

///|
fn control_sort_roots_in_place(roots : Array[ControlComplex]) -> Unit {
  for i in 0..<roots.length() {
    for j in (i + 1)..<roots.length() {
      let lhs = roots[i]
      let rhs = roots[j]
      if rhs.0 < lhs.0 || (rhs.0 == lhs.0 && rhs.1 < lhs.1) {
        roots[i] = rhs
        roots[j] = lhs
      }
    }
  }
}

///|
fn control_sort_root_groups_in_place(
  groups : Array[(ControlComplex, Int)],
) -> Unit {
  for i in 0..<groups.length() {
    for j in (i + 1)..<groups.length() {
      let lhs = groups[i]
      let rhs = groups[j]
      if rhs.0.0 < lhs.0.0 || (rhs.0.0 == lhs.0.0 && rhs.0.1 < lhs.0.1) {
        groups[i] = rhs
        groups[j] = lhs
      }
    }
  }
}

///|
fn control_group_roots(
  roots : Array[ControlComplex],
) -> Array[(ControlComplex, Int)] {
  let groups : Array[(ControlComplex, Int)] = []
  for root in roots {
    let mut matched = false
    for i in 0..<groups.length() {
      if control_complex_close(groups[i].0, root, tol=1.0e-5) {
        let prev = groups[i]
        let next_count = prev.1 + 1
        let avg = (
          (prev.0.0 * prev.1.to_double() + root.0) / next_count.to_double(),
          (prev.0.1 * prev.1.to_double() + root.1) / next_count.to_double(),
        )
        groups[i] = (avg, next_count)
        matched = true
        break
      }
    }
    if !matched {
      groups.push((root, 1))
    }
  }
  control_sort_root_groups_in_place(groups)
  groups
}

///|
fn control_choose_sample_points(
  roots : Array[(ControlComplex, Int)],
  count : Int,
) -> Array[ControlComplex] {
  let points : Array[ControlComplex] = []
  let mut idx = 0
  while points.length() < count {
    let candidate = (
      0.75 + idx.to_double(),
      0.35 + 0.17 * (idx % 3).to_double(),
    )
    idx += 1
    let mut okay = true
    for root in roots {
      if control_complex_abs(control_complex_sub(candidate, root.0)) < 0.2 {
        okay = false
        break
      }
    }
    if okay {
      points.push(candidate)
    }
  }
  points
}

///|
fn control_solve_complex_linear(
  matrix0 : Array[Array[ControlComplex]],
  rhs0 : Array[ControlComplex],
) -> Array[ControlComplex]? {
  let n = matrix0.length()
  if n == 0 || rhs0.length() != n {
    return Some([])
  }
  let matrix : Array[Array[ControlComplex]] = []
  for row in matrix0 {
    let next : Array[ControlComplex] = []
    for value in row {
      next.push(value)
    }
    matrix.push(next)
  }
  let rhs : Array[ControlComplex] = []
  for value in rhs0 {
    rhs.push(value)
  }
  for col in 0..<n {
    let mut pivot = col
    let mut pivot_abs = control_complex_abs(matrix[col][col])
    for row in (col + 1)..<n {
      let cand = control_complex_abs(matrix[row][col])
      if cand > pivot_abs {
        pivot = row
        pivot_abs = cand
      }
    }
    if pivot_abs <= 1.0e-12 {
      return None
    }
    if pivot != col {
      let tmp_row = matrix[col]
      matrix[col] = matrix[pivot]
      matrix[pivot] = tmp_row
      let tmp_rhs = rhs[col]
      rhs[col] = rhs[pivot]
      rhs[pivot] = tmp_rhs
    }
    let pivot_value = matrix[col][col]
    for j in col..<n {
      matrix[col][j] = match control_complex_div(matrix[col][j], pivot_value) {
        Some(value) => value
        None => return None
      }
    }
    rhs[col] = match control_complex_div(rhs[col], pivot_value) {
      Some(value) => value
      None => return None
    }
    for row in 0..<n {
      if row == col {
        continue
      }
      let factor = matrix[row][col]
      if control_complex_is_zero(factor) {
        continue
      }
      for j in col..<n {
        matrix[row][j] = control_complex_sub(
          matrix[row][j],
          control_complex_mul(factor, matrix[col][j]),
        )
      }
      rhs[row] = control_complex_sub(
        rhs[row],
        control_complex_mul(factor, rhs[col]),
      )
    }
  }
  Some(rhs)
}

///|
fn control_factorial_double(n : Int) -> Double {
  let mut out = 1.0
  for i in 2..<=n {
    out = out * i.to_double()
  }
  out
}

///|
fn control_partial_fraction_terms(
  numerator_coeffs : Array[Double],
  denominator_coeffs : Array[Double],
) -> Array[(ControlComplex, Int, ControlComplex)]? {
  let roots = match control_poly_numeric_roots(denominator_coeffs) {
    Some(value) => value
    None => return None
  }
  let groups = control_group_roots(roots)
  let basis : Array[(ControlComplex, Int)] = []
  for group in groups {
    for power in 1..<=group.1 {
      basis.push((group.0, power))
    }
  }
  if basis.is_empty() {
    return Some([])
  }
  let sample_points = control_choose_sample_points(groups, basis.length())
  let num_complex = numerator_coeffs.map(coeff => (coeff, 0.0))
  let den_complex = denominator_coeffs.map(coeff => (coeff, 0.0))
  let matrix : Array[Array[ControlComplex]] = []
  let rhs : Array[ControlComplex] = []
  for sample in sample_points {
    let row : Array[ControlComplex] = []
    for item in basis {
      let diff = control_complex_sub(sample, item.0)
      let term = match control_complex_pow_int(diff, item.1) {
        Some(value) =>
          match control_complex_inv(value) {
            Some(inv) => inv
            None => return None
          }
        None => return None
      }
      row.push(term)
    }
    matrix.push(row)
    let value = match
      control_complex_div(
        control_poly_eval_complex(num_complex, sample),
        control_poly_eval_complex(den_complex, sample),
      ) {
      Some(result) => result
      None => return None
    }
    rhs.push(value)
  }
  let coeffs = match control_solve_complex_linear(matrix, rhs) {
    Some(value) => value
    None => return None
  }
  let out : Array[(ControlComplex, Int, ControlComplex)] = []
  for i in 0..<basis.length() {
    out.push((basis[i].0, basis[i].1, coeffs[i]))
  }
  Some(out)
}

///|
fn control_response_samples_from_coeffs(
  numerator_coeffs : Array[Double],
  denominator_coeffs : Array[Double],
  times : Array[Double],
) -> Array[Double]? {
  let terms = match
    control_partial_fraction_terms(numerator_coeffs, denominator_coeffs) {
    Some(value) => value
    None => return None
  }
  let out : Array[Double] = []
  for t in times {
    let mut acc = (0.0, 0.0)
    for term in terms {
      let root = term.0
      let power = term.1
      let coeff = term.2
      let poly_scale = if power <= 1 {
        1.0
      } else {
        control_double_pow(t, power - 1) / control_factorial_double(power - 1)
      }
      let exp_term = control_complex_exp((root.0 * t, root.1 * t))
      acc = control_complex_add(
        acc,
        control_complex_mul(coeff, control_complex_scale(exp_term, poly_scale)),
      )
    }
    out.push(acc.0)
  }
  Some(out)
}

///|
fn control_response_grid(
  lower_limit : Double,
  upper_limit : Double,
  n : Int,
) -> Array[Double] {
  if n <= 1 {
    return [lower_limit]
  }
  let step = (upper_limit - lower_limit) / (n - 1).to_double()
  let out : Array[Double] = []
  for i in 0..<n {
    out.push(lower_limit + step * i.to_double())
  }
  out
}
