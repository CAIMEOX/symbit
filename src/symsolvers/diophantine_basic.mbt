///|
pub enum DiopSolveResult {
  Tuple(Array[Expr])
  Set(Set)
}

///|
fn solver_bigint_abs(value : @bigint.BigInt) -> @bigint.BigInt {
  if value.compare(0N) < 0 {
    -value
  } else {
    value
  }
}

///|
fn solver_bigint_gcdex(
  a0 : @bigint.BigInt,
  b0 : @bigint.BigInt,
) -> (@bigint.BigInt, @bigint.BigInt, @bigint.BigInt) {
  let mut old_r = a0
  let mut r = b0
  let mut old_s = 1N
  let mut s = 0N
  let mut old_t = 0N
  let mut t = 1N
  while r.compare(0N) != 0 {
    let q = old_r / r
    let next_r = old_r - q * r
    let next_s = old_s - q * s
    let next_t = old_t - q * t
    old_r = r
    r = next_r
    old_s = s
    s = next_s
    old_t = t
    t = next_t
  }
  if old_r.compare(0N) < 0 {
    (-old_s, -old_t, -old_r)
  } else {
    (old_s, old_t, old_r)
  }
}

///|
fn solver_integer_divisors(value : @bigint.BigInt) -> Array[@bigint.BigInt] {
  let abs_value = solver_bigint_abs(value)
  if abs_value.compare(0N) == 0 {
    return [0N]
  }
  let limit = abs_value.to_int()
  let out : Array[@bigint.BigInt] = []
  for i in 1..=limit {
    let candidate = @bigint.BigInt::from_int(i)
    if (abs_value % candidate).compare(0N) == 0 {
      out.push(candidate)
      out.push(-candidate)
    }
  }
  out.sort()
  let deduped : Array[@bigint.BigInt] = []
  for item in out {
    if deduped.is_empty() || deduped[deduped.length() - 1] != item {
      deduped.push(item)
    }
  }
  deduped
}

///|
fn solver_integer_expr(expr : Expr, context : String) -> @bigint.BigInt raise SolverError {
  match @symcore.exact_numeric_expr_num_den(expr) {
    Some((num, den)) if den.compare(1N) == 0 => num
    _ => raise SolverError::ValueError(context + " expects integer coefficients")
  }
}

///|
fn solver_field_elem_expr(
  elem : @sympolys.FieldElem,
  context : String,
) -> Expr raise SolverError {
  match elem {
    @sympolys.FieldElem::QQ(value) => Expr::Number(value)
    _ => raise SolverError::ValueError(context + " expects rational coefficients")
  }
}

///|
fn solver_diophantine_symbols(eq : Expr, syms : Array[Expr]) -> Array[Expr] raise SolverError {
  if syms.is_empty() {
    let inferred = sorted_unique_symbols(@symcore.free_symbols(eq))
    guard !inferred.is_empty() else {
      raise SolverError::ValueError("diophantine expects at least one symbol")
    }
    inferred
  } else {
    sorted_unique_symbols(syms)
  }
}

///|
fn solver_diophantine_parameter(index : Int, param : Expr) -> Expr {
  if index == 0 {
    match param {
      Expr::Symbol(_) => param
      _ => Expr::Symbol("t_0")
    }
  } else {
    Expr::Symbol("t_\{index}")
  }
}

///|
fn solver_linear_diophantine_tuple(
  coeff_values : Array[@bigint.BigInt],
  rhs : @bigint.BigInt,
  param : Expr,
) -> Array[Expr] raise SolverError {
  guard !coeff_values.is_empty() else {
    raise SolverError::ValueError("diophantine expects at least one coefficient")
  }
  let coeff_row : Array[Expr] = []
  let mut any_nonzero = false
  for coeff in coeff_values {
    if coeff.compare(0N) != 0 {
      any_nonzero = true
    }
    coeff_row.push(solver_exact_number_expr(coeff, 1N))
  }
  if !any_nonzero {
    if rhs.compare(0N) != 0 {
      return []
    }
    let out : Array[Expr] = []
    for i in 0..<coeff_values.length() {
      out.push(solver_diophantine_parameter(i, param))
    }
    return out
  }
  let coeff_dm = @sympolys.DomainMatrix::from_Matrix(
    [coeff_row],
    fmt="dense",
    field=false,
  ) catch {
    err => raise wrap_poly_error("diophantine", err)
  }
  let (smf, s, t) = coeff_dm.smith_normal_decomp() catch {
    err => raise wrap_poly_error("diophantine", err)
  }
  let rhs_dm = @sympolys.DomainMatrix::from_Matrix(
    [[solver_exact_number_expr(rhs, 1N)]],
    fmt="dense",
    field=false,
  ) catch {
    err => raise wrap_poly_error("diophantine", err)
  }
  let sb_dm = s.matmul(rhs_dm) catch {
    err => raise wrap_poly_error("diophantine", err)
  }
  let sb_rows = sb_dm.to_Matrix() catch {
    err => raise wrap_poly_error("diophantine", err)
  }
  let sb = solver_integer_expr(sb_rows[0][0], "diophantine")
  let smf_rows = smf.to_Matrix() catch {
    err => raise wrap_poly_error("diophantine", err)
  }
  let d = solver_integer_expr(smf_rows[0][0], "diophantine")
  guard d.compare(0N) != 0 else {
    return []
  }
  if (sb % d).compare(0N) != 0 {
    return []
  }
  let y : Array[Expr] = [solver_exact_number_expr(sb / d, 1N)]
  for i in 1..<coeff_values.length() {
    y.push(solver_diophantine_parameter(i - 1, param))
  }
  let t_rows = t.to_Matrix() catch {
    err => raise wrap_poly_error("diophantine", err)
  }
  let out : Array[Expr] = []
  for i in 0..<coeff_values.length() {
    let parts : Array[Expr] = []
    for j in 0..<coeff_values.length() {
      let coeff_expr = t_rows[i][j]
      if !@symcore.is_zero(coeff_expr) {
        parts.push(@symcore.mul([coeff_expr, y[j]]))
      }
    }
    out.push(@symsimplify.numer_expand(canonical_expr(solver_add_all(parts))))
  }
  out
}

///|
fn solver_univariate_diophantine(
  eq : Expr,
  symbol : Expr,
) -> Set raise SolverError {
  let name = symbol_name(symbol)
  let poly = @sympolys.Poly::from_expr_defaults(
    normalize_equation(eq),
    gens=[name],
  ) catch {
    err => raise wrap_poly_error("diophantine", err)
  }
  let degree = poly.degree(0)
  if degree < 0 {
    return @symsets.empty_set()
  }
  let mut constant = @symcore.int(0)
  for mono, coeff in poly.coeffs {
    if mono.exps[0] == 0 {
      constant = solver_field_elem_expr(coeff, "diophantine")
      break
    }
  }
  let constant_int = solver_integer_expr(constant, "diophantine")
  let roots : Array[Expr] = []
  for candidate in solver_integer_divisors(constant_int) {
    let value = solver_subst_single(normalize_equation(eq), name, solver_exact_number_expr(candidate, 1N))
    if expr_is_zeroish(value) == Some(true) {
      roots.push(Expr::Tuple([solver_exact_number_expr(candidate, 1N)]))
    }
  }
  @symsets.finite_set(roots)
}

///|
pub fn classify_diop(
  eq : Expr,
  syms? : Array[Expr] = [],
) -> (Array[Expr], Map[String, Expr], String) raise SolverError {
  let symbols = solver_diophantine_symbols(eq, syms)
  let names = symbol_names(symbols)
  let linear = try? @sympolys._linear_eq_to_dict([normalize_equation(eq)], names)
  match linear {
    Ok((coeffs, constants)) => {
      let coeff_map = coeffs[0]
      let out : Map[String, Expr] = {}
      out["1"] = constants[0]
      for symbol in symbols {
        let name = symbol_name(symbol)
        let value = coeff_map.get(name).unwrap_or(@symcore.int(0))
        ignore(solver_integer_expr(value, "classify_diop"))
        out[name] = value
      }
      (symbols, out, "linear")
    }
    Err(_) =>
      if symbols.length() == 1 {
        let name = names[0]
        let poly = @sympolys.Poly::from_expr_defaults(
          normalize_equation(eq),
          gens=[name],
        ) catch {
          err => raise wrap_poly_error("classify_diop", err)
        }
        let out : Map[String, Expr] = {}
        for mono, coeff in poly.coeffs {
          let coeff_expr = solver_field_elem_expr(coeff, "classify_diop")
          ignore(solver_integer_expr(coeff_expr, "classify_diop"))
          let exp = mono.exps[0]
          let key = if exp == 0 {
            "1"
          } else if exp == 1 {
            name
          } else {
            name + "**" + exp.to_string()
          }
          out[key] = coeff_expr
        }
        (symbols, out, "univariate")
      } else {
        raise SolverError::ValueError(
          "classify_diop currently supports linear equations and univariate polynomials",
        )
      }
  }
}

///|
pub fn diophantine(
  eq : Expr,
  param? : Expr = Expr::Symbol("t_0"),
  syms? : Array[Expr] = [],
) -> Set raise SolverError {
  let symbols = solver_diophantine_symbols(eq, syms)
  let names = symbol_names(symbols)
  if symbols.length() == 1 {
    let linear = try? @sympolys._linear_eq_to_dict([normalize_equation(eq)], names)
    match linear {
      Ok(_) => ()
      Err(_) => return solver_univariate_diophantine(eq, symbols[0])
    }
  }
  let (coeffs, constants) = @sympolys._linear_eq_to_dict([normalize_equation(eq)], names) catch {
    err => raise wrap_poly_error("diophantine", err)
  }
  let coeff_map = coeffs[0]
  let rhs = solver_integer_expr(
    canonical_expr(@symcore.mul([@symcore.int(-1), constants[0]])),
    "diophantine",
  )
  let coeff_values : Array[@bigint.BigInt] = []
  for symbol in symbols {
    coeff_values.push(
      solver_integer_expr(
        coeff_map.get(symbol_name(symbol)).unwrap_or(@symcore.int(0)),
        "diophantine",
      ),
    )
  }
  if symbols.length() == 1 {
    let a = coeff_values[0]
    guard a.compare(0N) != 0 else {
      return if rhs.compare(0N) == 0 {
        @symsets.finite_set([Expr::Tuple([param])])
      } else {
        @symsets.empty_set()
      }
    }
    if (rhs % a).compare(0N) != 0 {
      return @symsets.empty_set()
    }
    return @symsets.finite_set([
      Expr::Tuple([solver_exact_number_expr(rhs / a, 1N)]),
    ])
  }
  if symbols.length() == 2 {
    let a = coeff_values[0]
    let b = coeff_values[1]
    if solver_bigint_abs(b).compare(1N) == 0 {
      let y_expr = canonical_expr(
        @symcore.add([
          solver_exact_number_expr(rhs / b, 1N),
          @symcore.mul([solver_exact_number_expr(-(a / b), 1N), param]),
        ]),
      )
      return @symsets.finite_set([Expr::Tuple([param, y_expr])])
    }
    if solver_bigint_abs(a).compare(1N) == 0 {
      let x_expr = canonical_expr(
        @symcore.add([
          solver_exact_number_expr(rhs / a, 1N),
          @symcore.mul([solver_exact_number_expr(-(b / a), 1N), param]),
        ]),
      )
      return @symsets.finite_set([Expr::Tuple([x_expr, param])])
    }
    let (s, t, g) = solver_bigint_gcdex(a, b)
    if (rhs % g).compare(0N) != 0 {
      return @symsets.empty_set()
    }
    let scale = rhs / g
    let x0 = s * scale
    let y0 = t * scale
    let step_x = b / g
    let step_y = a / g
    let x_expr = canonical_expr(
      @symcore.add([
        solver_exact_number_expr(x0, 1N),
        @symcore.mul([solver_exact_number_expr(step_x, 1N), param]),
      ]),
    )
    let y_expr = canonical_expr(
      @symcore.add([
        solver_exact_number_expr(y0, 1N),
        @symcore.mul([solver_exact_number_expr(-step_y, 1N), param]),
      ]),
    )
    return @symsets.finite_set([Expr::Tuple([x_expr, y_expr])])
  }
  let parts = solver_linear_diophantine_tuple(coeff_values, rhs, param)
  if parts.is_empty() {
    @symsets.empty_set()
  } else {
    @symsets.finite_set([Expr::Tuple(parts)])
  }
}

///|
pub fn diop_solve(
  eq : Expr,
  param? : Expr = Expr::Symbol("t_0"),
  syms? : Array[Expr] = [],
) -> DiopSolveResult raise SolverError {
  let (symbols, _, kind) = classify_diop(eq, syms=syms)
  if kind == "linear" {
    let solved = diophantine(eq, param=param, syms=symbols)
    match solved {
      @symsets.Set::FiniteSet(items) if items.length() == 1 =>
        match items[0] {
          Expr::Tuple(parts) => DiopSolveResult::Tuple(parts)
          _ => DiopSolveResult::Set(solved)
        }
      _ => DiopSolveResult::Set(solved)
    }
  } else {
    DiopSolveResult::Set(diophantine(eq, param=param, syms=symbols))
  }
}
