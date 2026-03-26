///|
using @symcore {type Expr, int}

///|
/// Shared symbolic helpers for `physics.continuum_mechanics` ports.

///|
pub fn cm_int_expr(value : Int) -> Expr {
  int(value)
}

///|
pub fn cm_rat_expr(num : Int, den : Int) -> Expr {
  @symcore.rational_from_ints(num, den) catch {
    _ => cm_int_expr(num) * (cm_int_expr(den) ^ cm_int_expr(-1))
  }
}

///|
pub fn cm_symbol(name : String) -> Expr {
  Expr::Symbol(name)
}

///|
pub fn cm_simplify(expr : Expr) -> Expr {
  @symsimplify.ratsimp(@symsimplify.simplify(expr, max_passes=8), max_passes=8)
}

///|
pub fn cm_expr_is_zero(expr : Expr) -> Bool {
  cm_simplify(expr) == cm_int_expr(0)
}

///|
pub fn cm_sign_of_difference(lhs : Expr, rhs : Expr) -> Int? {
  let diff = cm_simplify(lhs - rhs)
  match diff {
    Expr::Number(n) =>
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
pub fn cm_expr_eq(lhs : Expr, rhs : Expr) -> Bool {
  cm_sign_of_difference(lhs, rhs) == Some(0)
}

///|
pub fn cm_depends_on(expr : Expr, var_name : String) -> Bool {
  match expr {
    Expr::Symbol(name) => name == var_name
    Expr::Add(args) | Expr::Mul(args) =>
      args.any(arg => cm_depends_on(arg, var_name))
    Expr::Pow(base, exp) =>
      cm_depends_on(base, var_name) || cm_depends_on(exp, var_name)
    _ if @symcore.application_parts(expr) is Some(_) =>
      @symcore.application_args(expr).unwrap_or([]).any(fn(arg) {
        cm_depends_on(arg, var_name)
      })
    _ => false
  }
}

///|
pub fn cm_collect_symbols(expr : Expr, names : Map[String, Bool]) -> Unit {
  match expr {
    Expr::Symbol(name) => names[name] = true
    Expr::Add(args) | Expr::Mul(args) =>
      for arg in args {
        cm_collect_symbols(arg, names)
      }
    Expr::Pow(base, exp) => {
      cm_collect_symbols(base, names)
      cm_collect_symbols(exp, names)
    }
    _ if @symcore.application_parts(expr) is Some(_) =>
      for arg in @symcore.application_args(expr).unwrap_or([]) {
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
pub fn cm_expr_eval(expr : Expr, env : Map[String, Double]) -> Double? {
  match expr {
    Expr::Number(n) => cm_number_text_to_double(n.to_string())
    Expr::Symbol(name) => env.get(name)
    Expr::Add(args) => {
      let mut acc = 0.0
      for arg in args {
        match cm_expr_eval(arg, env) {
          Some(value) => acc = acc + value
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Mul(args) => {
      let mut acc = 1.0
      for arg in args {
        match cm_expr_eval(arg, env) {
          Some(value) => acc = acc * value
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Pow(base, exp) =>
      match (cm_expr_eval(base, env), exp) {
        (Some(base_value), Expr::Number(n)) if n.is_integral() =>
          Some(cm_double_pow(base_value, n.numerator().to_int()))
        _ => None
      }
    _ if @symcore.application_has_name(expr, "sqrt", arity=1) =>
      match cm_expr_eval(@symcore.application_args(expr).unwrap_or([])[0], env) {
        Some(value) => Some(value.sqrt())
        None => None
      }
    _ if @symcore.application_has_name(expr, "sin", arity=1) =>
      match cm_expr_eval(@symcore.application_args(expr).unwrap_or([])[0], env) {
        Some(value) => Some(@math.sin(value))
        None => None
      }
    _ if @symcore.application_has_name(expr, "cos", arity=1) =>
      match cm_expr_eval(@symcore.application_args(expr).unwrap_or([])[0], env) {
        Some(value) => Some(@math.cos(value))
        None => None
      }
    _ if @symcore.application_has_name(expr, "atan", arity=1) =>
      match cm_expr_eval(@symcore.application_args(expr).unwrap_or([])[0], env) {
        Some(value) => Some(@math.atan(value))
        None => None
      }
    _ if @symcore.application_has_name(expr, "SingularityFunction", arity=3) =>
      match (@symcore.application_args(expr).unwrap_or([])[0], @symcore.application_args(expr).unwrap_or([])[2]) {
        (Expr::Symbol(name), Expr::Number(n)) if n.is_integral() =>
          match (env.get(name), cm_expr_eval(@symcore.application_args(expr).unwrap_or([])[1], env)) {
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
pub fn cm_numeric_expr_eq(lhs : Expr, rhs : Expr) -> Bool {
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
pub fn cm_singularity(var_expr : Expr, start : Expr, order : Int) -> Expr {
  @symspec.singularity_function(var_expr, start, cm_int_expr(order))
}

///|
pub fn cm_subst(expr : Expr, name : String, value : Expr) -> Expr {
  let env : Map[String, Expr] = {}
  env[name] = value
  @symcore.subst(expr, env)
}

///|
fn cm_integrated_singularity(order : Int) -> (Expr, Int) {
  if order >= 0 {
    (cm_rat_expr(1, order + 1), order + 1)
  } else if order == -1 {
    (cm_int_expr(1), 0)
  } else {
    (cm_int_expr(1), order + 1)
  }
}

///|
pub fn cm_integrate(expr : Expr, var_name : String) -> Expr {
  match expr {
    Expr::Add(args) =>
      @symcore.add(args.map(arg => cm_integrate(arg, var_name)))
    Expr::Mul(args) => {
      let indep : Array[Expr] = []
      let dep : Array[Expr] = []
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
          Expr::Symbol(name) if name == var_name =>
            return coeff *
              (cm_symbol(var_name) ^ cm_int_expr(2)) *
              cm_rat_expr(1, 2)
          _ if @symcore.application_has_name(dep_item, "SingularityFunction", arity=3) &&
            @symcore.application_args(dep_item).unwrap_or([])[0] == cm_symbol(var_name) =>
            match @symcore.application_args(dep_item).unwrap_or([])[2] {
              Expr::Number(n) if n.is_integral() => {
                let (scale, next_order) = cm_integrated_singularity(
                  n.numerator().to_int(),
                )
                return coeff *
                  scale *
                  cm_singularity(
                    cm_symbol(var_name),
                    @symcore.application_args(dep_item).unwrap_or([])[1],
                    next_order,
                  )
              }
              _ => ()
            }
          Expr::Pow(base, exp) if base == cm_symbol(var_name) =>
            match exp {
              Expr::Number(n) if n.is_integral() => {
                let power = n.numerator().to_int()
                return coeff *
                  (cm_symbol(var_name) ^ cm_int_expr(power + 1)) *
                  cm_rat_expr(1, power + 1)
              }
              _ => ()
            }
          Expr::Add(_) => return coeff * cm_integrate(dep_item, var_name)
          _ => ()
        }
        return coeff * cm_integrate(dep_item, var_name)
      }
      expr * cm_symbol(var_name)
    }
    Expr::Symbol(name) if name == var_name =>
      (cm_symbol(var_name) ^ cm_int_expr(2)) * cm_rat_expr(1, 2)
    _ => expr * cm_symbol(var_name)
  }
}

///|
pub fn cm_eval_singularity_exact(at : Expr, start : Expr, order : Int) -> Expr {
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
  at : Expr,
  start : Expr,
  order : Int,
) -> Expr {
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
  at : Expr,
  start : Expr,
  order : Int,
) -> Expr {
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
pub fn cm_eval_at(expr : Expr, var_name : String, at : Expr) -> Expr {
  match expr {
    Expr::Symbol(name) => if name == var_name { at } else { expr }
    Expr::Add(args) =>
      @symcore.add(args.map(arg => cm_eval_at(arg, var_name, at)))
    Expr::Mul(args) =>
      @symcore.mul(args.map(arg => cm_eval_at(arg, var_name, at)))
    Expr::Pow(base, exp) =>
      @symcore.pow(
        cm_eval_at(base, var_name, at),
        cm_eval_at(exp, var_name, at),
      )
    _ if @symcore.application_has_name(expr, "SingularityFunction", arity=3) &&
      @symcore.application_args(expr).unwrap_or([])[0] == cm_symbol(var_name) =>
      match @symcore.application_args(expr).unwrap_or([])[2] {
        Expr::Number(n) if n.is_integral() =>
          cm_eval_singularity_exact(
            at,
            @symcore.application_args(expr).unwrap_or([])[1],
            n.numerator().to_int(),
          )
        _ =>
          @symcore.function("SingularityFunction", [
            at,
            cm_eval_at(@symcore.application_args(expr).unwrap_or([])[1], var_name, at),
            cm_eval_at(@symcore.application_args(expr).unwrap_or([])[2], var_name, at),
          ])
      }
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          @symcore.raw_apply(head, args.map(arg => cm_eval_at(arg, var_name, at))).unwrap_or(expr)
        None => expr
      }
  }
}

///|
pub fn cm_left_limit_at(expr : Expr, var_name : String, at : Expr) -> Expr {
  match expr {
    Expr::Symbol(name) => if name == var_name { at } else { expr }
    Expr::Add(args) =>
      @symcore.add(args.map(arg => cm_left_limit_at(arg, var_name, at)))
    Expr::Mul(args) =>
      @symcore.mul(args.map(arg => cm_left_limit_at(arg, var_name, at)))
    Expr::Pow(base, exp) =>
      @symcore.pow(
        cm_left_limit_at(base, var_name, at),
        cm_left_limit_at(exp, var_name, at),
      )
    _ if @symcore.application_has_name(expr, "SingularityFunction", arity=3) &&
      @symcore.application_args(expr).unwrap_or([])[0] == cm_symbol(var_name) =>
      match @symcore.application_args(expr).unwrap_or([])[2] {
        Expr::Number(n) if n.is_integral() =>
          cm_eval_singularity_left_limit(
            at,
            @symcore.application_args(expr).unwrap_or([])[1],
            n.numerator().to_int(),
          )
        _ =>
          @symcore.function("SingularityFunction", [
            at,
            cm_left_limit_at(@symcore.application_args(expr).unwrap_or([])[1], var_name, at),
            cm_left_limit_at(@symcore.application_args(expr).unwrap_or([])[2], var_name, at),
          ])
      }
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          @symcore.raw_apply(
            head,
            args.map(arg => cm_left_limit_at(arg, var_name, at)),
          ).unwrap_or(expr)
        None => expr
      }
  }
}

///|
pub fn cm_right_limit_at(expr : Expr, var_name : String, at : Expr) -> Expr {
  match expr {
    Expr::Symbol(name) => if name == var_name { at } else { expr }
    Expr::Add(args) =>
      @symcore.add(args.map(arg => cm_right_limit_at(arg, var_name, at)))
    Expr::Mul(args) =>
      @symcore.mul(args.map(arg => cm_right_limit_at(arg, var_name, at)))
    Expr::Pow(base, exp) =>
      @symcore.pow(
        cm_right_limit_at(base, var_name, at),
        cm_right_limit_at(exp, var_name, at),
      )
    _ if @symcore.application_has_name(expr, "SingularityFunction", arity=3) &&
      @symcore.application_args(expr).unwrap_or([])[0] == cm_symbol(var_name) =>
      match @symcore.application_args(expr).unwrap_or([])[2] {
        Expr::Number(n) if n.is_integral() =>
          cm_eval_singularity_right_limit(
            at,
            @symcore.application_args(expr).unwrap_or([])[1],
            n.numerator().to_int(),
          )
        _ =>
          @symcore.function("SingularityFunction", [
            at,
            cm_right_limit_at(@symcore.application_args(expr).unwrap_or([])[1], var_name, at),
            cm_right_limit_at(@symcore.application_args(expr).unwrap_or([])[2], var_name, at),
          ])
      }
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          @symcore.raw_apply(
            head,
            args.map(arg => cm_right_limit_at(arg, var_name, at)),
          ).unwrap_or(expr)
        None => expr
      }
  }
}

///|
pub fn cm_linear_solve(
  equations : Array[Expr],
  unknowns : Array[Expr],
) -> Map[String, Expr]? raise @sympolys.PolyError {
  let names : Array[String] = []
  for unknown in unknowns {
    match unknown {
      Expr::Symbol(name) => names.push(name)
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
  equations : Array[Expr],
  names : Array[String],
) -> Map[String, Expr]? raise @sympolys.PolyError {
  let (coeffs, consts) = @sympolys._linear_eq_to_dict(equations, names)
  let rows : Array[Array[Expr]] = []
  for i in 0..<coeffs.length() {
    let row : Array[Expr] = []
    for name in names {
      row.push(cm_simplify(coeffs[i].get(name).unwrap_or(int(0))))
    }
    row.push(cm_simplify(int(0) - consts[i]))
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
        let pivot_inv = cm_simplify(pivot ^ int(-1))
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
  let solution : Map[String, Expr] = {}
  for col in 0..<ncols {
    solution[names[col]] = cm_simplify(rows[pivots[col]][ncols])
  }
  Some(solution)
}
