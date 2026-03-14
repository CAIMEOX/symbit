///|
/// Shared symbolic helpers for `physics.continuum_mechanics` ports.

///|
pub fn cm_int_expr(value : Int) -> @symcore.Expr {
  @symcore.int(value)
}

///|
pub fn cm_rat_expr(num : Int, den : Int) -> @symcore.Expr {
  try! @symcore.rational_from_ints(num, den)
}

///|
pub fn cm_symbol(name : String) -> @symcore.Expr {
  @symcore.symbol(name)
}

///|
pub fn cm_simplify(expr : @symcore.Expr) -> @symcore.Expr {
  @symsimplify.ratsimp(@symsimplify.simplify(expr, max_passes=8), max_passes=8)
}

///|
pub fn cm_expr_is_zero(expr : @symcore.Expr) -> Bool {
  cm_simplify(expr) == cm_int_expr(0)
}

///|
pub fn cm_sign_of_difference(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Int? {
  let diff = cm_simplify(lhs - rhs)
  match diff {
    @symcore.Expr::Number(n) =>
      if n.is_zero() {
        Some(0)
      } else if n.numerator().to_int() > 0 {
        Some(1)
      } else {
        Some(-1)
      }
    _ => None
  }
}

///|
pub fn cm_expr_eq(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Bool {
  cm_sign_of_difference(lhs, rhs) == Some(0)
}

///|
pub fn cm_depends_on(expr : @symcore.Expr, var_name : String) -> Bool {
  match expr {
    @symcore.Expr::Symbol(name) => name == var_name
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      args.any(arg => cm_depends_on(arg, var_name))
    @symcore.Expr::Pow(base, exp) =>
      cm_depends_on(base, var_name) || cm_depends_on(exp, var_name)
    @symcore.Expr::Function(_, args) =>
      args.any(arg => cm_depends_on(arg, var_name))
    _ => false
  }
}

///|
pub fn cm_collect_symbols(
  expr : @symcore.Expr,
  names : Map[String, Bool],
) -> Unit {
  match expr {
    @symcore.Expr::Symbol(name) => names[name] = true
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      for arg in args {
        cm_collect_symbols(arg, names)
      }
    @symcore.Expr::Pow(base, exp) => {
      cm_collect_symbols(base, names)
      cm_collect_symbols(exp, names)
    }
    @symcore.Expr::Function(_, args) =>
      for arg in args {
        cm_collect_symbols(arg, names)
      }
    _ => ()
  }
}

///|
pub fn cm_double_pow(base : Double, exp : Int) -> Double {
  if exp == 0 {
    return 1.0
  }
  if exp < 0 {
    return 1.0 / cm_double_pow(base, -exp)
  }
  let mut acc = 1.0
  let mut cur = base
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      acc = acc * cur
    }
    e = e / 2
    if e > 0 {
      cur = cur * cur
    }
  }
  acc
}

///|
fn cm_number_text_to_double(text : String) -> Double? {
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
pub fn cm_expr_eval(expr : @symcore.Expr, env : Map[String, Double]) -> Double? {
  match expr {
    @symcore.Expr::Number(n) => cm_number_text_to_double(n.to_string())
    @symcore.Expr::Symbol(name) => env.get(name)
    @symcore.Expr::Add(args) => {
      let mut acc = 0.0
      for arg in args {
        match cm_expr_eval(arg, env) {
          Some(value) => acc = acc + value
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Mul(args) => {
      let mut acc = 1.0
      for arg in args {
        match cm_expr_eval(arg, env) {
          Some(value) => acc = acc * value
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Pow(base, exp) =>
      match (cm_expr_eval(base, env), exp) {
        (Some(base_value), @symcore.Expr::Number(n)) if n.is_integral() =>
          Some(cm_double_pow(base_value, n.numerator().to_int()))
        _ => None
      }
    @symcore.Expr::Function("sqrt", args) if args.length() == 1 =>
      match cm_expr_eval(args[0], env) {
        Some(value) => Some(value.sqrt())
        None => None
      }
    @symcore.Expr::Function("sin", args) if args.length() == 1 =>
      match cm_expr_eval(args[0], env) {
        Some(value) => Some(@math.sin(value))
        None => None
      }
    @symcore.Expr::Function("cos", args) if args.length() == 1 =>
      match cm_expr_eval(args[0], env) {
        Some(value) => Some(@math.cos(value))
        None => None
      }
    @symcore.Expr::Function("atan", args) if args.length() == 1 =>
      match cm_expr_eval(args[0], env) {
        Some(value) => Some(@math.atan(value))
        None => None
      }
    @symcore.Expr::Function("SingularityFunction", args) if args.length() == 3 =>
      match (args[0], args[2]) {
        (@symcore.Expr::Symbol(name), @symcore.Expr::Number(n)) if n.is_integral() =>
          match (env.get(name), cm_expr_eval(args[1], env)) {
            (Some(at), Some(start)) => {
              let order = n.numerator().to_int()
              let diff = at - start
              if diff < -1.0e-12 {
                Some(0.0)
              } else if diff > 1.0e-12 {
                if order < 0 {
                  Some(0.0)
                } else if order == 0 {
                  Some(1.0)
                } else {
                  Some(cm_double_pow(diff, order))
                }
              } else if order < 0 {
                Some(0.0)
              } else if order == 0 {
                Some(1.0)
              } else {
                Some(0.0)
              }
            }
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
pub fn cm_numeric_expr_eq(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Bool {
  if cm_expr_is_zero(lhs - rhs) {
    return true
  }
  let names : Map[String, Bool] = {}
  cm_collect_symbols(lhs, names)
  cm_collect_symbols(rhs, names)
  let ordered = names.keys().to_array()
  ordered.sort()
  for seed in [2, 5, 9] {
    let env : Map[String, Double] = {}
    for i in 0..<ordered.length() {
      env[ordered[i]] = Double::from_int(seed + i)
    }
    match (cm_expr_eval(lhs, env), cm_expr_eval(rhs, env)) {
      (Some(a), Some(b)) =>
        if !a.is_close(b, relative_tolerance=1.0e-8, absolute_tolerance=1.0e-8) {
          return false
        }
      _ => return false
    }
  }
  true
}

///|
pub fn cm_singularity(
  var_expr : @symcore.Expr,
  start : @symcore.Expr,
  order : Int,
) -> @symcore.Expr {
  @symspec.singularity_function(var_expr, start, cm_int_expr(order))
}

///|
pub fn cm_subst(
  expr : @symcore.Expr,
  name : String,
  value : @symcore.Expr,
) -> @symcore.Expr {
  let env : Map[String, @symcore.Expr] = {}
  env[name] = value
  @symcore.subst(expr, env)
}

///|
fn cm_integrated_singularity(order : Int) -> (@symcore.Expr, Int) {
  if order >= 0 {
    (cm_rat_expr(1, order + 1), order + 1)
  } else if order == -1 {
    (cm_int_expr(1), 0)
  } else {
    (cm_int_expr(1), order + 1)
  }
}

///|
pub fn cm_integrate(expr : @symcore.Expr, var_name : String) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) =>
      @symcore.add(args.map(arg => cm_integrate(arg, var_name)))
    @symcore.Expr::Mul(args) => {
      let indep : Array[@symcore.Expr] = []
      let dep : Array[@symcore.Expr] = []
      for arg in args {
        if cm_depends_on(arg, var_name) {
          dep.push(arg)
        } else {
          indep.push(arg)
        }
      }
      if dep.is_empty() {
        return expr * cm_symbol(var_name)
      }
      if dep.length() == 1 {
        let dep_item = dep[0]
        let coeff = if indep.is_empty() {
          cm_int_expr(1)
        } else {
          @symcore.mul(indep)
        }
        match dep_item {
          @symcore.Expr::Symbol(name) if name == var_name =>
            return coeff *
              (cm_symbol(var_name) ^ cm_int_expr(2)) *
              cm_rat_expr(1, 2)
          @symcore.Expr::Function("SingularityFunction", sf_args) if sf_args.length() ==
            3 &&
            sf_args[0] == cm_symbol(var_name) =>
            match sf_args[2] {
              @symcore.Expr::Number(n) if n.is_integral() => {
                let (scale, next_order) = cm_integrated_singularity(
                  n.numerator().to_int(),
                )
                return coeff *
                  scale *
                  cm_singularity(cm_symbol(var_name), sf_args[1], next_order)
              }
              _ => ()
            }
          @symcore.Expr::Pow(base, exp) if base == cm_symbol(var_name) =>
            match exp {
              @symcore.Expr::Number(n) if n.is_integral() => {
                let power = n.numerator().to_int()
                return coeff *
                  (cm_symbol(var_name) ^ cm_int_expr(power + 1)) *
                  cm_rat_expr(1, power + 1)
              }
              _ => ()
            }
          @symcore.Expr::Add(_) =>
            return coeff * cm_integrate(dep_item, var_name)
          _ => ()
        }
        return coeff * cm_integrate(dep_item, var_name)
      }
      expr * cm_symbol(var_name)
    }
    @symcore.Expr::Symbol(name) if name == var_name =>
      (cm_symbol(var_name) ^ cm_int_expr(2)) * cm_rat_expr(1, 2)
    _ => expr * cm_symbol(var_name)
  }
}

///|
pub fn cm_eval_singularity_exact(
  at : @symcore.Expr,
  start : @symcore.Expr,
  order : Int,
) -> @symcore.Expr {
  match cm_sign_of_difference(at, start) {
    Some(sign) =>
      if sign < 0 {
        cm_int_expr(0)
      } else if sign > 0 {
        if order < 0 {
          cm_int_expr(0)
        } else if order == 0 {
          cm_int_expr(1)
        } else {
          cm_simplify((at - start) ^ cm_int_expr(order))
        }
      } else if order < 0 {
        cm_singularity(at, start, order)
      } else if order == 0 {
        cm_int_expr(1)
      } else {
        cm_int_expr(0)
      }
    None => cm_singularity(at, start, order)
  }
}

///|
pub fn cm_eval_singularity_left_limit(
  at : @symcore.Expr,
  start : @symcore.Expr,
  order : Int,
) -> @symcore.Expr {
  match cm_sign_of_difference(at, start) {
    Some(sign) =>
      if sign <= 0 {
        cm_int_expr(0)
      } else if order < 0 {
        cm_int_expr(0)
      } else if order == 0 {
        cm_int_expr(1)
      } else {
        cm_simplify((at - start) ^ cm_int_expr(order))
      }
    None => cm_singularity(at, start, order)
  }
}

///|
pub fn cm_eval_singularity_right_limit(
  at : @symcore.Expr,
  start : @symcore.Expr,
  order : Int,
) -> @symcore.Expr {
  match cm_sign_of_difference(at, start) {
    Some(sign) =>
      if sign < 0 {
        cm_int_expr(0)
      } else if order < 0 {
        cm_int_expr(0)
      } else if order == 0 {
        cm_int_expr(1)
      } else if sign == 0 {
        cm_int_expr(0)
      } else {
        cm_simplify((at - start) ^ cm_int_expr(order))
      }
    None => cm_singularity(at, start, order)
  }
}

///|
pub fn cm_eval_at(
  expr : @symcore.Expr,
  var_name : String,
  at : @symcore.Expr,
) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Symbol(name) => if name == var_name { at } else { expr }
    @symcore.Expr::Add(args) =>
      @symcore.add(args.map(arg => cm_eval_at(arg, var_name, at)))
    @symcore.Expr::Mul(args) =>
      @symcore.mul(args.map(arg => cm_eval_at(arg, var_name, at)))
    @symcore.Expr::Pow(base, exp) =>
      @symcore.pow(
        cm_eval_at(base, var_name, at),
        cm_eval_at(exp, var_name, at),
      )
    @symcore.Expr::Function("SingularityFunction", args) if args.length() == 3 &&
      args[0] == cm_symbol(var_name) =>
      match args[2] {
        @symcore.Expr::Number(n) if n.is_integral() =>
          cm_eval_singularity_exact(at, args[1], n.numerator().to_int())
        _ =>
          @symcore.function("SingularityFunction", [
            at,
            cm_eval_at(args[1], var_name, at),
            cm_eval_at(args[2], var_name, at),
          ])
      }
    @symcore.Expr::Function(name, args) =>
      @symcore.function(name, args.map(arg => cm_eval_at(arg, var_name, at)))
    _ => expr
  }
}

///|
pub fn cm_left_limit_at(
  expr : @symcore.Expr,
  var_name : String,
  at : @symcore.Expr,
) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Symbol(name) => if name == var_name { at } else { expr }
    @symcore.Expr::Add(args) =>
      @symcore.add(args.map(arg => cm_left_limit_at(arg, var_name, at)))
    @symcore.Expr::Mul(args) =>
      @symcore.mul(args.map(arg => cm_left_limit_at(arg, var_name, at)))
    @symcore.Expr::Pow(base, exp) =>
      @symcore.pow(
        cm_left_limit_at(base, var_name, at),
        cm_left_limit_at(exp, var_name, at),
      )
    @symcore.Expr::Function("SingularityFunction", args) if args.length() == 3 &&
      args[0] == cm_symbol(var_name) =>
      match args[2] {
        @symcore.Expr::Number(n) if n.is_integral() =>
          cm_eval_singularity_left_limit(at, args[1], n.numerator().to_int())
        _ =>
          @symcore.function("SingularityFunction", [
            at,
            cm_left_limit_at(args[1], var_name, at),
            cm_left_limit_at(args[2], var_name, at),
          ])
      }
    @symcore.Expr::Function(name, args) =>
      @symcore.function(
        name,
        args.map(arg => cm_left_limit_at(arg, var_name, at)),
      )
    _ => expr
  }
}

///|
pub fn cm_right_limit_at(
  expr : @symcore.Expr,
  var_name : String,
  at : @symcore.Expr,
) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Symbol(name) => if name == var_name { at } else { expr }
    @symcore.Expr::Add(args) =>
      @symcore.add(args.map(arg => cm_right_limit_at(arg, var_name, at)))
    @symcore.Expr::Mul(args) =>
      @symcore.mul(args.map(arg => cm_right_limit_at(arg, var_name, at)))
    @symcore.Expr::Pow(base, exp) =>
      @symcore.pow(
        cm_right_limit_at(base, var_name, at),
        cm_right_limit_at(exp, var_name, at),
      )
    @symcore.Expr::Function("SingularityFunction", args) if args.length() == 3 &&
      args[0] == cm_symbol(var_name) =>
      match args[2] {
        @symcore.Expr::Number(n) if n.is_integral() =>
          cm_eval_singularity_right_limit(at, args[1], n.numerator().to_int())
        _ =>
          @symcore.function("SingularityFunction", [
            at,
            cm_right_limit_at(args[1], var_name, at),
            cm_right_limit_at(args[2], var_name, at),
          ])
      }
    @symcore.Expr::Function(name, args) =>
      @symcore.function(
        name,
        args.map(arg => cm_right_limit_at(arg, var_name, at)),
      )
    _ => expr
  }
}

///|
pub fn cm_linear_solve(
  equations : Array[@symcore.Expr],
  unknowns : Array[@symcore.Expr],
) -> Map[String, @symcore.Expr]? raise @sympolys.PolyError {
  let names : Array[String] = []
  for unknown in unknowns {
    match unknown {
      @symcore.Expr::Symbol(name) => names.push(name)
      _ => raise @sympolys.PolyError::NonPolynomial
    }
  }
  try @sympolys._linsolve(equations, names) catch {
    _ => cm_linear_solve_elimination(equations, names)
  } noraise {
    solved =>
      match solved {
        Some(solution) => Some(solution)
        None => cm_linear_solve_elimination(equations, names)
      }
  }
}

///|
fn cm_linear_solve_elimination(
  equations : Array[@symcore.Expr],
  names : Array[String],
) -> Map[String, @symcore.Expr]? raise @sympolys.PolyError {
  let (coeffs, consts) = @sympolys._linear_eq_to_dict(equations, names)
  let rows : Array[Array[@symcore.Expr]] = []
  for i in 0..<coeffs.length() {
    let row : Array[@symcore.Expr] = []
    for name in names {
      row.push(cm_simplify(coeffs[i].get(name).unwrap_or(@symcore.int(0))))
    }
    row.push(cm_simplify(@symcore.int(0) - consts[i]))
    rows.push(row)
  }
  let nrows = rows.length()
  let ncols = names.length()
  let mut pivot_row = 0
  let pivots : Map[Int, Int] = {}
  for col in 0..<ncols {
    let mut found : Int? = None
    for row in pivot_row..<nrows {
      if !cm_expr_is_zero(rows[row][col]) {
        found = Some(row)
        break
      }
    }
    match found {
      Some(row_idx) => {
        if row_idx != pivot_row {
          let temp = rows[pivot_row]
          rows[pivot_row] = rows[row_idx]
          rows[row_idx] = temp
        }
        let pivot = rows[pivot_row][col]
        let pivot_inv = cm_simplify(pivot ^ @symcore.int(-1))
        for j in col..<(ncols + 1) {
          rows[pivot_row][j] = cm_simplify(rows[pivot_row][j] * pivot_inv)
        }
        for row in 0..<nrows {
          if row == pivot_row || cm_expr_is_zero(rows[row][col]) {
            continue
          }
          let factor = rows[row][col]
          for j in col..<(ncols + 1) {
            rows[row][j] = cm_simplify(
              rows[row][j] - factor * rows[pivot_row][j],
            )
          }
        }
        pivots[col] = pivot_row
        pivot_row += 1
        if pivot_row == nrows {
          break
        }
      }
      None => ()
    }
  }
  for row in 0..<nrows {
    let mut all_zero = true
    for col in 0..<ncols {
      if !cm_expr_is_zero(rows[row][col]) {
        all_zero = false
        break
      }
    }
    if all_zero && !cm_expr_is_zero(rows[row][ncols]) {
      return None
    }
  }
  if pivots.length() != ncols {
    return None
  }
  let solution : Map[String, @symcore.Expr] = {}
  for col in 0..<ncols {
    solution[names[col]] = cm_simplify(rows[pivots[col]][ncols])
  }
  Some(solution)
}
