///|
/// Stage-5 transform helpers.

///|
type LaplaceInfo = (Expr, Expr, Expr)

///|
type MellinInfo = (Expr, Expr, Expr, Expr)

///|
/// Apply the forward Laplace rule table and return only the transformed value.
///
/// This is the internal `.doit()` worker behind `LaplaceTransform`. It drops
/// the convergence plane and condition metadata and returns `None` when the
/// current rule set cannot evaluate the expression.
pub fn do_laplace_doit(expr : Expr, t : Expr, s : Expr) -> Expr? {
  match symbol_name(t) {
    Some(t_name) =>
      match laplace_info_doit(expr_simplify(expr), t_name, s) {
        Some(info) => Some(info.0)
        None => None
      }
    None => None
  }
}

///|
/// Evaluate a forward Laplace transform with optional ROC/condition metadata.
///
/// When the rule engine succeeds, the result matches SymPy's
/// `laplace_transform(..., noconds=...)` convention:
/// - `noconds=true` returns only the transformed expression
/// - `noconds=false` returns `(value, plane, condition)`
/// If no rule applies, the unevaluated `LaplaceTransform` object is returned.
pub fn laplace_transform_result(
  expr : Expr,
  t : Expr,
  s : Expr,
  noconds? : Bool = false,
) -> Expr {
  match symbol_name(t) {
    Some(t_name) =>
      match laplace_info_doit(expr_simplify(expr), t_name, s) {
        Some((value, plane, cond)) =>
          if noconds {
            value
          } else {
            tuple_expr([value, plane, cond])
          }
        None => @symcore.raw_function("LaplaceTransform", [expr, t, s])
      }
    None => @symcore.raw_function("LaplaceTransform", [expr, t, s])
  }
}

///|
/// Collect polynomial structure recursively before Laplace processing.
///
/// This mirrors SymPy's helper that rewrites nested arithmetic into a form
/// where polynomial coefficients in the transform variable are easier to
/// recognize.
pub fn _laplace_deep_collect(expr : Expr, t : Expr) -> Expr {
  match symbol_name(t) {
    Some(t_name) => laplace_deep_collect(expr, t_name)
    None => expr
  }
}

///|
/// Rewrite transform heads according to a function-name correspondence map.
///
/// This is the MoonBit equivalent of SymPy's `laplace_correspondence`, used
/// when moving between named functions and their transform-domain aliases.
pub fn laplace_correspondence(expr : Expr, fdict : Map[String, String]) -> Expr {
  if fdict.is_empty() {
    expr
  } else {
    laplace_correspondence_walk(expr, fdict)
  }
}

///|
/// Substitute initial conditions into Laplace-domain derivatives.
///
/// `fdict` maps function names to the values of successive derivatives at the
/// origin, following the same role as SymPy's `laplace_initial_conds`.
pub fn laplace_initial_conds(
  expr : Expr,
  t : Expr,
  fdict : Map[String, Array[Expr]],
) -> Expr {
  match symbol_name(t) {
    Some(t_name) => laplace_initial_conds_walk(expr, t_name, fdict)
    None => expr
  }
}

///|
fn laplace_info_doit(expr : Expr, t_name : String, s : Expr) -> LaplaceInfo? {
  match expr {
    @symcore.Expr::Add(terms) => laplace_add_info(terms, t_name, s)
    _ => {
      let (coeff, factors) = split_mul(expr, t_name)
      match laplace_mul_term(factors, t_name, s) {
        Some((value, plane, cond)) =>
          Some((expr_mul(coeff, value), plane, cond))
        None => None
      }
    }
  }
}

///|
fn laplace_deep_collect(expr : Expr, t_name : String) -> Expr {
  let rebuilt = match expr {
    @symcore.Expr::Add(args) =>
      @symcore.raw_add(args.map(fn(arg) { laplace_deep_collect(arg, t_name) }))
    @symcore.Expr::Mul(args) =>
      @symcore.raw_mul(args.map(fn(arg) { laplace_deep_collect(arg, t_name) }))
    @symcore.Expr::Pow(base, exp) =>
      @symcore.raw_pow(
        laplace_deep_collect(base, t_name),
        laplace_deep_collect(exp, t_name),
      )
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          match
            @symcore.raw_apply(
              head,
              args.map(fn(arg) { laplace_deep_collect(arg, t_name) }),
            ) {
            Some(value) => value
            None => expr
          }
        None => expr
      }
  }
  match poly_coeffs_general(rebuilt, t_name) {
    Some(coeffs) => polynomial_from_coeffs(coeffs, t_name)
    None => rebuilt
  }
}

///|
fn laplace_correspondence_walk(
  expr : Expr,
  fdict : Map[String, String],
) -> Expr {
  match @symcore.application_parts(expr) {
    Some((head, args)) =>
      match (@symcore.function_head_name(head), args) {
        (Some("LaplaceTransform"), [source_expr, source_t, source_s]) =>
          match @symcore.application_parts(source_expr) {
            Some((source_head, [arg])) =>
              match @symcore.function_head_name(source_head) {
                Some(source_name) =>
                  if @symcore.compare_expr(arg, source_t) == 0 {
                    match fdict.get(source_name) {
                      Some(target_name) =>
                        return @symcore.raw_function(target_name, [
                          laplace_correspondence_walk(source_s, fdict),
                        ])
                      None =>
                        return @symcore.raw_function("LaplaceTransform", [
                          laplace_correspondence_walk(source_expr, fdict),
                          laplace_correspondence_walk(source_t, fdict),
                          laplace_correspondence_walk(source_s, fdict),
                        ])
                    }
                  } else {
                    return @symcore.raw_function("LaplaceTransform", [
                      laplace_correspondence_walk(source_expr, fdict),
                      laplace_correspondence_walk(source_t, fdict),
                      laplace_correspondence_walk(source_s, fdict),
                    ])
                  }
                None =>
                  return @symcore.raw_function("LaplaceTransform", [
                    laplace_correspondence_walk(source_expr, fdict),
                    laplace_correspondence_walk(source_t, fdict),
                    laplace_correspondence_walk(source_s, fdict),
                  ])
              }
            _ =>
              return @symcore.raw_function("LaplaceTransform", [
                laplace_correspondence_walk(source_expr, fdict),
                laplace_correspondence_walk(source_t, fdict),
                laplace_correspondence_walk(source_s, fdict),
              ])
          }
        (Some("InverseLaplaceTransform"), [target_expr, source_s, source_t])
        | (Some("InverseLaplaceTransform"), [target_expr, source_s, source_t, _]
        ) =>
          match @symcore.application_parts(target_expr) {
            Some((target_head, [arg])) =>
              match @symcore.function_head_name(target_head) {
                Some(target_name) =>
                  if @symcore.compare_expr(arg, source_s) == 0 {
                    match find_inverse_laplace_source(target_name, fdict) {
                      Some(source_name) =>
                        return @symcore.raw_function(source_name, [
                          laplace_correspondence_walk(source_t, fdict),
                        ])
                      None =>
                        return @symcore.raw_function(
                          "InverseLaplaceTransform",
                          [
                            laplace_correspondence_walk(target_expr, fdict),
                            laplace_correspondence_walk(source_s, fdict),
                            laplace_correspondence_walk(source_t, fdict),
                          ],
                        )
                    }
                  } else {
                    return @symcore.raw_function("InverseLaplaceTransform", [
                      laplace_correspondence_walk(target_expr, fdict),
                      laplace_correspondence_walk(source_s, fdict),
                      laplace_correspondence_walk(source_t, fdict),
                    ])
                  }
                None =>
                  return @symcore.raw_function("InverseLaplaceTransform", [
                    laplace_correspondence_walk(target_expr, fdict),
                    laplace_correspondence_walk(source_s, fdict),
                    laplace_correspondence_walk(source_t, fdict),
                  ])
              }
            _ =>
              return @symcore.raw_function("InverseLaplaceTransform", [
                laplace_correspondence_walk(target_expr, fdict),
                laplace_correspondence_walk(source_s, fdict),
                laplace_correspondence_walk(source_t, fdict),
              ])
          }
        _ => ()
      }
    None => ()
  }
  match expr {
    @symcore.Expr::Add(args) =>
      @symcore.raw_add(
        args.map(fn(arg) { laplace_correspondence_walk(arg, fdict) }),
      )
    @symcore.Expr::Mul(args) =>
      @symcore.raw_mul(
        args.map(fn(arg) { laplace_correspondence_walk(arg, fdict) }),
      )
    @symcore.Expr::Pow(base, exp) =>
      @symcore.raw_pow(
        laplace_correspondence_walk(base, fdict),
        laplace_correspondence_walk(exp, fdict),
      )
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          match
            @symcore.raw_apply(
              head,
              args.map(fn(arg) { laplace_correspondence_walk(arg, fdict) }),
            ) {
            Some(value) => value
            None => expr
          }
        None => expr
      }
  }
}

///|
fn find_inverse_laplace_source(
  target_name : String,
  fdict : Map[String, String],
) -> String? {
  for source_name, mapped_name in fdict {
    if mapped_name == target_name {
      return Some(source_name)
    }
  }
  None
}

///|
fn laplace_initial_conds_walk(
  expr : Expr,
  t_name : String,
  fdict : Map[String, Array[Expr]],
) -> Expr {
  match match_initial_condition(expr, t_name, fdict) {
    Some(value) => value
    None =>
      match expr {
        @symcore.Expr::Add(args) =>
          @symcore.raw_add(
            args.map(fn(arg) { laplace_initial_conds_walk(arg, t_name, fdict) }),
          )
        @symcore.Expr::Mul(args) =>
          @symcore.raw_mul(
            args.map(fn(arg) { laplace_initial_conds_walk(arg, t_name, fdict) }),
          )
        @symcore.Expr::Pow(base, exp) =>
          @symcore.raw_pow(
            laplace_initial_conds_walk(base, t_name, fdict),
            laplace_initial_conds_walk(exp, t_name, fdict),
          )
        _ =>
          match @symcore.application_parts(expr) {
            Some((head, args)) =>
              match
                @symcore.raw_apply(
                  head,
                  args.map(fn(arg) {
                    laplace_initial_conds_walk(arg, t_name, fdict)
                  }),
                ) {
                Some(value) => value
                None => expr
              }
            None => expr
          }
      }
  }
}

///|
fn match_initial_condition(
  expr : Expr,
  t_name : String,
  fdict : Map[String, Array[Expr]],
) -> Expr? {
  for func_name, values in fdict {
    match initial_condition_order(expr, func_name, t_name) {
      Some(order) if order >= 0 && order < values.length() =>
        return Some(values[order])
      _ => ()
    }
  }
  None
}

///|
fn initial_condition_order(
  expr : Expr,
  func_name : String,
  t_name : String,
) -> Int? {
  match @symcore.application_parts(expr) {
    Some((head, [arg])) =>
      match @symcore.function_head_name(head) {
        Some(func) if func == func_name && expr_is_zero(arg) => Some(0)
        _ =>
          if @symcore.derivative_parts(expr) != None {
            derivative_at_zero_order(expr, func_name)
          } else {
            match @symcore.subs_parts(expr) {
              Some((inner, sub_var, value)) =>
                if @symcore.compare_expr(sub_var, @symcore.symbol(t_name)) == 0 &&
                  expr_is_zero(value) {
                  derivative_ic_order(inner, func_name, t_name)
                } else {
                  None
                }
              None => None
            }
          }
      }
    _ =>
      if @symcore.derivative_parts(expr) != None {
        derivative_at_zero_order(expr, func_name)
      } else {
        match @symcore.subs_parts(expr) {
          Some((inner, sub_var, value)) =>
            if @symcore.compare_expr(sub_var, @symcore.symbol(t_name)) == 0 &&
              expr_is_zero(value) {
              derivative_ic_order(inner, func_name, t_name)
            } else {
              None
            }
          None => None
        }
      }
  }
}

///|
fn derivative_at_zero_order(expr : Expr, func_name : String) -> Int? {
  match @symcore.application_parts(expr) {
    Some((head, [arg])) =>
      match @symcore.function_head_name(head) {
        Some(func) if func == func_name && expr_is_zero(arg) => Some(0)
        _ =>
          match @symcore.derivative_parts(expr) {
            Some((inner, [wrt])) =>
              if expr_is_zero(wrt) {
                match derivative_at_zero_order(inner, func_name) {
                  Some(order) => Some(order + 1)
                  None => None
                }
              } else {
                None
              }
            Some((inner, [wrt, order])) =>
              if expr_is_zero(wrt) {
                match
                  (
                    derivative_at_zero_order(inner, func_name),
                    expr_is_int_value(order),
                  ) {
                  (Some(base_order), Some(n)) if n >= 1 => Some(base_order + n)
                  _ => None
                }
              } else {
                None
              }
            _ => None
          }
      }
    _ =>
      match @symcore.derivative_parts(expr) {
        Some((inner, [wrt])) =>
          if expr_is_zero(wrt) {
            match derivative_at_zero_order(inner, func_name) {
              Some(order) => Some(order + 1)
              None => None
            }
          } else {
            None
          }
        Some((inner, [wrt, order])) =>
          if expr_is_zero(wrt) {
            match
              (
                derivative_at_zero_order(inner, func_name),
                expr_is_int_value(order),
              ) {
              (Some(base_order), Some(n)) if n >= 1 => Some(base_order + n)
              _ => None
            }
          } else {
            None
          }
        _ => None
      }
  }
}

///|
fn derivative_ic_order(
  expr : Expr,
  func_name : String,
  t_name : String,
) -> Int? {
  match @symcore.derivative_parts(expr) {
    Some((inner, [wrt])) =>
      if @symcore.compare_expr(wrt, @symcore.symbol(t_name)) == 0 {
        match derivative_chain_order(inner, func_name, t_name) {
          Some(order) => Some(order + 1)
          None => None
        }
      } else {
        None
      }
    Some((inner, [wrt, order])) =>
      if @symcore.compare_expr(wrt, @symcore.symbol(t_name)) == 0 {
        match
          (
            derivative_chain_order(inner, func_name, t_name),
            expr_is_int_value(order),
          ) {
          (Some(base_order), Some(n)) if n >= 1 => Some(base_order + n)
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn derivative_chain_order(
  expr : Expr,
  func_name : String,
  t_name : String,
) -> Int? {
  match expr {
    @symcore.Expr::Function(func, [arg]) =>
      if func == func_name &&
        @symcore.compare_expr(arg, @symcore.symbol(t_name)) == 0 {
        Some(0)
      } else {
        None
      }
    _ =>
      match @symcore.derivative_parts(expr) {
        Some((inner, [wrt])) =>
          if @symcore.compare_expr(wrt, @symcore.symbol(t_name)) == 0 {
            match derivative_chain_order(inner, func_name, t_name) {
              Some(order) => Some(order + 1)
              None => None
            }
          } else {
            None
          }
        Some((inner, [wrt, order])) =>
          if @symcore.compare_expr(wrt, @symcore.symbol(t_name)) == 0 {
            match
              (
                derivative_chain_order(inner, func_name, t_name),
                expr_is_int_value(order),
              ) {
              (Some(base_order), Some(n)) if n >= 1 => Some(base_order + n)
              _ => None
            }
          } else {
            None
          }
        _ => None
      }
  }
}

///|
fn poly_coeffs_general(expr : Expr, var_name : String) -> Array[Expr]? {
  match expr {
    @symcore.Expr::Number(_)
    | @symcore.Expr::Float(_)
    | @symcore.Expr::NumberSymbol(_)
    | @symcore.Expr::ComplexFloat(_) => Some([expr])
    @symcore.Expr::Symbol(name) =>
      if name == var_name {
        Some([expr_zero(), expr_one()])
      } else {
        Some([expr])
      }
    @symcore.Expr::Dummy(_, _)
    | @symcore.Expr::Wild(_)
    | @symcore.Expr::FunctionHead(_)
    | @symcore.Expr::UndefinedFunction(_) => Some([expr])
    @symcore.Expr::AppliedUndef(_, _) =>
      if expr_depends_on(expr, var_name) {
        None
      } else {
        Some([expr])
      }
    @symcore.Expr::Add(args) => {
      let acc : Array[Expr] = [expr_zero()]
      for arg in args {
        match poly_coeffs_general(arg, var_name) {
          Some(coeffs) => poly_accum_add(acc, coeffs)
          None => return None
        }
      }
      Some(poly_trim_general(acc))
    }
    @symcore.Expr::Mul(args) => {
      let mut acc : Array[Expr] = [expr_one()]
      for arg in args {
        match poly_coeffs_general(arg, var_name) {
          Some(coeffs) => acc = poly_mul_general(acc, coeffs)
          None => return None
        }
      }
      Some(poly_trim_general(acc))
    }
    @symcore.Expr::Pow(base, exp) =>
      match expr_is_int_value(exp) {
        Some(power) if power >= 0 =>
          match poly_coeffs_general(base, var_name) {
            Some(coeffs) => Some(poly_pow_general(coeffs, power))
            None => None
          }
        _ => if expr_depends_on(expr, var_name) { None } else { Some([expr]) }
      }
    @symcore.Expr::Mod(_, _) =>
      if expr_depends_on(expr, var_name) {
        None
      } else {
        Some([expr])
      }
    @symcore.Expr::Function(_, _)
    | @symcore.Expr::Derivative(_, _)
    | @symcore.Expr::Subs(_, _, _) =>
      if expr_depends_on(expr, var_name) {
        None
      } else {
        Some([expr])
      }
    @symcore.Expr::Boolean(_)
    | @symcore.Expr::Tuple(_)
    | @symcore.Expr::Dict(_)
    | @symcore.Expr::Relational(_, _, _)
    | @symcore.Expr::Lambda(_, _) => None
  }
}

///|
fn poly_accum_add(acc : Array[Expr], coeffs : Array[Expr]) -> Unit {
  if coeffs.length() > acc.length() {
    let mut idx = acc.length()
    while idx < coeffs.length() {
      acc.push(expr_zero())
      idx += 1
    }
  }
  for i in 0..<coeffs.length() {
    acc[i] = expr_add(acc[i], coeffs[i])
  }
}

///|
fn poly_mul_general(lhs : Array[Expr], rhs : Array[Expr]) -> Array[Expr] {
  if lhs.is_empty() || rhs.is_empty() {
    return []
  }
  let out : Array[Expr] = []
  for _ in 0..<(lhs.length() + rhs.length() - 1) {
    out.push(expr_zero())
  }
  for i in 0..<lhs.length() {
    for j in 0..<rhs.length() {
      out[i + j] = expr_add(out[i + j], expr_mul(lhs[i], rhs[j]))
    }
  }
  poly_trim_general(out)
}

///|
fn poly_pow_general(base : Array[Expr], exp : Int) -> Array[Expr] {
  if exp == 0 {
    return [expr_one()]
  }
  let mut result : Array[Expr] = [expr_one()]
  let mut factor = base
  let mut n = exp
  while n > 0 {
    if n % 2 == 1 {
      result = poly_mul_general(result, factor)
    }
    n = n / 2
    if n > 0 {
      factor = poly_mul_general(factor, factor)
    }
  }
  poly_trim_general(result)
}

///|
fn poly_trim_general(poly : Array[Expr]) -> Array[Expr] {
  let mut end = poly.length()
  while end > 0 && expr_is_zero(poly[end - 1]) {
    end -= 1
  }
  let out : Array[Expr] = []
  for i in 0..<end {
    out.push(poly[i])
  }
  out
}

///|
fn polynomial_from_coeffs(coeffs : Array[Expr], var_name : String) -> Expr {
  if coeffs.is_empty() {
    return expr_zero()
  }
  let terms : Array[Expr] = []
  let poly_var = @symcore.symbol(var_name)
  for i in 0..<coeffs.length() {
    let coeff = coeffs[i]
    if expr_is_zero(coeff) {
      continue
    }
    let term = if i == 0 {
      coeff
    } else if i == 1 {
      expr_mul(coeff, poly_var)
    } else {
      expr_mul(coeff, expr_pow(poly_var, expr_int(i)))
    }
    terms.push(term)
  }
  if terms.is_empty() {
    expr_zero()
  } else {
    expr_simplify(@symcore.add(terms))
  }
}

///|
fn laplace_add_info(
  terms : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  let values : Array[Expr] = []
  let mut plane : Expr? = None
  let mut cond = true_expr()
  for term in terms {
    match laplace_info_doit(term, t_name, s) {
      Some((value, roc, term_cond)) => {
        values.push(value)
        plane = Some(
          match plane {
            Some(prev) => max_expr(prev, roc)
            None => roc
          },
        )
        cond = and_expr(cond, term_cond)
      }
      None => return None
    }
  }
  Some(
    (expr_simplify(@symcore.add(values)), plane.unwrap_or(expr_zero()), cond),
  )
}

///|
fn laplace_mul_term(
  factors : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  if factors.length() == 0 {
    return laplace_base_term(expr_one(), t_name, s)
  }
  match laplace_delta_term(factors, t_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  match laplace_heaviside_shift_term(factors, t_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  match laplace_distribute_add_term(factors, t_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  let mut exp_coeff : Expr? = None
  let mut exp_const = expr_zero()
  let rest : Array[Expr] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Function("exp", [inner]) =>
        match linear_coeffs(inner, t_name) {
          Some((a, b)) =>
            if exp_coeff is None {
              exp_coeff = Some(a)
              exp_const = b
            } else {
              return None
            }
          None => rest.push(factor)
        }
      _ => rest.push(factor)
    }
  }
  let shifted_s = match exp_coeff {
    Some(a) => expr_sub(s, a)
    None => s
  }
  let base_info = laplace_rest_term(rest, t_name, shifted_s, s)
  match base_info {
    Some((value, plane, cond)) =>
      match exp_coeff {
        Some(a) => {
          let shifted_plane = if expr_eq(plane, neg_oo_expr()) {
            expr_add(plane, laplace_plane_shift_expr(a))
          } else {
            expr_add(plane, laplace_plane_shift_expr(a))
          }
          Some((expr_mul(@symelem.exp(exp_const), value), shifted_plane, cond))
        }
        None => Some((value, plane, cond))
      }
    None =>
      if expr_depends_on(expr_simplify(factors_expr(factors)), t_name) {
        Some(
          generic_laplace_object(
            expr_simplify(factors_expr(factors)),
            t_name,
            s,
          ),
        )
      } else {
        None
      }
  }
}

///|
fn laplace_plane_shift_expr(a : Expr) -> Expr {
  match a {
    @symcore.Expr::Number(_) | @symcore.Expr::Symbol(_) => a
    @symcore.Expr::Float(_) | @symcore.Expr::ComplexFloat(_) => @symelem.re(a)
    _ => @symelem.re(a)
  }
}

///|
fn laplace_distribute_add_term(
  factors : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  for i in 0..<factors.length() {
    match factors[i] {
      @symcore.Expr::Add(terms) => {
        let expanded : Array[Expr] = []
        for term in terms {
          let items : Array[Expr] = []
          for j in 0..<factors.length() {
            items.push(if i == j { term } else { factors[j] })
          }
          expanded.push(factors_expr(items))
        }
        return laplace_add_info(expanded, t_name, s)
      }
      _ => ()
    }
  }
  None
}

///|
fn laplace_rest_term(
  factors : Array[Expr],
  t_name : String,
  shifted_s : Expr,
  s : Expr,
) -> LaplaceInfo? {
  if factors.length() == 0 {
    return laplace_base_term(expr_one(), t_name, shifted_s)
  }
  if factors.length() == 1 {
    return laplace_base_term(factors[0], t_name, shifted_s)
  }
  match laplace_inverse_power_trig_term(factors, t_name, shifted_s) {
    Some(info) => return Some(info)
    None => ()
  }
  match laplace_power_product_identity_term(factors, t_name, shifted_s) {
    Some(info) => return Some(info)
    None => ()
  }
  match laplace_identity_product_term(factors, t_name, shifted_s) {
    Some(info) => return Some(info)
    None => ()
  }
  match laplace_gaussian_mul_term(factors, t_name, shifted_s) {
    Some(info) => return Some(info)
    None => ()
  }
  match symbol_name(s) {
    Some(_) =>
      match laplace_symbolic_power_times_term(factors, t_name, shifted_s, s) {
        Some(info) => Some(info)
        None =>
          match laplace_power_times_term(factors, t_name, shifted_s, s) {
            Some(info) => Some(info)
            None => laplace_generic_shifted_term(factors, t_name, shifted_s)
          }
      }
    None => None
  }
}

///|
fn laplace_symbolic_power_times_term(
  factors : Array[Expr],
  t_name : String,
  shifted_s : Expr,
  s : Expr,
) -> LaplaceInfo? {
  let mut symbolic_power : Expr? = None
  let rest : Array[Expr] = []
  for factor in factors {
    match parse_power_factor(factor, t_name) {
      Some(power) if expr_is_constant(power, t_name) &&
        expr_is_int_value(power) == None =>
        if symbolic_power is None {
          symbolic_power = Some(power)
        } else {
          return None
        }
      Some(_) => rest.push(factor)
      None => rest.push(factor)
    }
  }
  if symbolic_power is None || rest.length() != 1 {
    return None
  }
  let power = symbolic_power.unwrap()
  match laplace_base_term(rest[0], t_name, shifted_s) {
    Some((value, plane, cond)) =>
      match value {
        @symcore.Expr::Function("LaplaceTransform", _) =>
          Some(
            (
              expr_mul(
                expr_pow(expr_neg_one(), power),
                @symcore.raw_function("Derivative", [value, s, power]),
              ),
              plane,
              cond,
            ),
          )
        _ if @symcore.derivative_parts(value) != None =>
          Some(
            (
              expr_mul(
                expr_pow(expr_neg_one(), power),
                @symcore.raw_function("Derivative", [value, s, power]),
              ),
              plane,
              cond,
            ),
          )
        _ => None
      }
    None => None
  }
}

///|
fn laplace_power_times_term(
  factors : Array[Expr],
  t_name : String,
  shifted_s : Expr,
  s : Expr,
) -> LaplaceInfo? {
  let mut total_power = 0
  let rest : Array[Expr] = []
  for factor in factors {
    match parse_power_factor(factor, t_name) {
      Some(power_expr) =>
        match expr_is_int_value(power_expr) {
          Some(power) if power >= 0 => total_power += power
          _ => return None
        }
      None => rest.push(factor)
    }
  }
  if total_power == 0 || rest.length() != 1 {
    return None
  }
  match laplace_base_term(rest[0], t_name, shifted_s) {
    Some((value, plane, cond)) => {
      let out = match laplace_generic_power_derivative(value, s, total_power) {
        Some(generic_out) => generic_out
        None => {
          let mut derived = value
          for _ in 0..<total_power {
            derived = expr_mul(expr_neg_one(), @symcalculus.diff(derived, s))
          }
          derived
        }
      }
      Some((expr_simplify(out), plane, cond))
    }
    None => None
  }
}

///|
fn laplace_generic_power_derivative(
  value : Expr,
  s : Expr,
  order : Int,
) -> Expr? {
  if order <= 0 {
    return Some(value)
  }
  match value {
    @symcore.Expr::Function("LaplaceTransform", _) => {
      let deriv = if order == 1 {
        @symcore.raw_function("Derivative", [value, s])
      } else {
        @symcore.raw_function("Derivative", [value, s, expr_int(order)])
      }
      if order % 2 == 0 {
        Some(deriv)
      } else {
        Some(expr_mul(expr_neg_one(), deriv))
      }
    }
    _ if @symcore.derivative_parts(value) != None => {
      let deriv = if order == 1 {
        @symcore.raw_function("Derivative", [value, s])
      } else {
        @symcore.raw_function("Derivative", [value, s, expr_int(order)])
      }
      if order % 2 == 0 {
        Some(deriv)
      } else {
        Some(expr_mul(expr_neg_one(), deriv))
      }
    }
    _ => None
  }
}

///|
fn laplace_delta_term(
  factors : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  let mut delta_roots : Array[(Expr, Expr)]? = None
  let rest : Array[Expr] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Function("DiracDelta", [arg]) =>
        match laplace_delta_roots(arg, t_name) {
          Some(parsed) if delta_roots is None => delta_roots = Some(parsed)
          _ => return None
        }
      _ => rest.push(factor)
    }
  }
  match delta_roots {
    Some(entries) => {
      let terms : Array[Expr] = []
      let mut cond = true_expr()
      for entry in entries {
        let root = entry.0
        let scale = entry.1
        if expr_is_negative(root) {
          continue
        }
        let term = expr_div(
          expr_mul(
            subst_symbol(factors_expr(rest), t_name, root),
            @symelem.exp(expr_mul(expr_neg_one(), expr_mul(root, s))),
          ),
          scale,
        )
        terms.push(term)
        cond = and_expr(cond, nonnegative_condition(root))
      }
      if terms.is_empty() {
        Some((expr_zero(), neg_oo_expr(), true_expr()))
      } else {
        Some(
          (
            expr_simplify(
              if terms.length() == 1 {
                terms[0]
              } else {
                @symcore.add(terms)
              },
            ),
            neg_oo_expr(),
            cond,
          ),
        )
      }
    }
    None => None
  }
}

///|
fn abs_rational_expr(value : @symnum.BigRational) -> Expr {
  if value.compare(@symnum.BigRational::zero()) < 0 {
    expr_from_num(value.neg_r())
  } else {
    expr_from_num(value)
  }
}

///|
fn laplace_delta_roots(arg : Expr, t_name : String) -> Array[(Expr, Expr)]? {
  match linear_coeffs(arg, t_name) {
    Some((coeff, offset)) if !expr_is_zero(coeff) => {
      let scale = match expr_num_value(expr_simplify(coeff)) {
        Some(value) => abs_rational_expr(value)
        None =>
          if expr_is_one(coeff) || expr_is_minus_one(coeff) {
            expr_one()
          } else {
            coeff
          }
      }
      Some([(expr_div(expr_mul(expr_neg_one(), offset), coeff), scale)])
    }
    _ =>
      match poly_coeffs_upto2(expr_simplify(arg), t_name) {
        Some(coeffs) if !expr_is_zero(coeffs[2]) => {
          let disc = expr_simplify(
            expr_sub(
              expr_pow(coeffs[1], expr_int(2)),
              expr_mul(expr_int(4), expr_mul(coeffs[2], coeffs[0])),
            ),
          )
          let sqrt_disc = preferred_positive_sqrt(disc)
          let denom = expr_mul(expr_int(2), coeffs[2])
          let roots : Array[(Expr, Expr)] = []
          let deriv = @symcalculus.diff(arg, @symcore.symbol(t_name))
          for
            root in [
              expr_div(
                expr_sub(expr_mul(expr_neg_one(), coeffs[1]), sqrt_disc),
                denom,
              ),
              expr_div(
                expr_add(expr_mul(expr_neg_one(), coeffs[1]), sqrt_disc),
                denom,
              ),
            ] {
            let scale_expr = expr_simplify(subst_symbol(deriv, t_name, root))
            let scale = match expr_num_value(scale_expr) {
              Some(value) if value.compare(@symnum.BigRational::zero()) != 0 =>
                expr_from_num(value)
              _ => scale_expr
            }
            if roots.all(fn(item) { !expr_eq(item.0, root) }) {
              roots.push((expr_simplify(root), scale))
            }
          }
          Some(roots)
        }
        _ => None
      }
  }
}

///|
fn laplace_heaviside_shift_term(
  factors : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  let mut window : (Expr, Bool)? = None
  let rest : Array[Expr] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Function("Heaviside", [arg]) =>
        match parse_heaviside_limit(arg, t_name) {
          Some((bound, is_le)) =>
            if window is None {
              window = Some((bound, is_le))
            } else {
              return None
            }
          None => return None
        }
      _ => rest.push(factor)
    }
  }
  let rest_expr = expr_simplify(factors_expr(rest))
  match window {
    Some((bound, is_upper)) =>
      if is_upper {
        if expr_is_negative(bound) || expr_is_zero(bound) {
          Some((expr_zero(), expr_zero(), true_expr()))
        } else {
          match laplace_info_doit(rest_expr, t_name, s) {
            Some((full_value, full_plane, full_cond)) =>
              match
                laplace_heaviside_shifted_rest(rest_expr, t_name, s, bound) {
                Some((shifted_value, shifted_plane, shifted_cond)) =>
                  Some(
                    (
                      expr_simplify(expr_sub(full_value, shifted_value)),
                      max_expr(full_plane, shifted_plane),
                      and_expr(full_cond, shifted_cond),
                    ),
                  )
                None => None
              }
            None => None
          }
        }
      } else if expr_is_negative(bound) || expr_is_zero(bound) {
        laplace_info_doit(rest_expr, t_name, s)
      } else {
        laplace_heaviside_shifted_rest(rest_expr, t_name, s, bound)
      }
    None => None
  }
}

///|
fn laplace_heaviside_shifted_rest(
  rest_expr : Expr,
  t_name : String,
  s : Expr,
  bound : Expr,
) -> LaplaceInfo? {
  let shift_name = if t_name == "_laplace_u" {
    "_laplace_v"
  } else {
    "_laplace_u"
  }
  let shift_var = @symcore.symbol(shift_name)
  let shifted = subst_symbol(rest_expr, t_name, expr_add(shift_var, bound))
  match laplace_info_doit(expr_simplify(shifted), shift_name, s) {
    Some((value, plane, cond)) => {
      let restored_value = subst_symbol(
        value,
        shift_name,
        @symcore.symbol(t_name),
      )
      let restored_plane = subst_symbol(
        plane,
        shift_name,
        @symcore.symbol(t_name),
      )
      let restored_cond = subst_symbol(
        cond,
        shift_name,
        @symcore.symbol(t_name),
      )
      Some(
        (
          expr_simplify(
            expr_mul(
              @symelem.exp(expr_mul(expr_neg_one(), expr_mul(bound, s))),
              restored_value,
            ),
          ),
          restored_plane,
          and_expr(restored_cond, nonnegative_condition(bound)),
        ),
      )
    }
    None => None
  }
}

///|
fn laplace_base_term(expr : Expr, t_name : String, s : Expr) -> LaplaceInfo? {
  match expr {
    @symcore.Expr::Number(_) =>
      Some((expr_div(expr, s), expr_zero(), true_expr()))
    @symcore.Expr::Symbol(name) =>
      if name == t_name {
        Some(
          (
            expr_div(expr_one(), expr_pow(s, expr_int(2))),
            expr_zero(),
            true_expr(),
          ),
        )
      } else {
        None
      }
    @symcore.Expr::Function("exp", [inner]) =>
      laplace_gaussian_base_term(inner, t_name, s)
    @symcore.Expr::Function("log", [inner]) =>
      laplace_log_term(inner, t_name, s)
    @symcore.Expr::Function("Piecewise", args) =>
      match laplace_piecewise_term(args, t_name, s) {
        Some(info) => Some(info)
        None => None
      }
    @symcore.Expr::Pow(@symcore.Expr::Function("log", [inner]), exp) =>
      match expr_is_int_value(exp) {
        Some(2) => laplace_log_squared_term(inner, t_name, s)
        _ => None
      }
    @symcore.Expr::Pow(base, exp) =>
      match laplace_function_power_base_term(base, exp, t_name, s) {
        Some(info) => Some(info)
        None => {
          let base_name = symbol_name(base)
          if base_name == None {
            None
          } else {
            let name = match base_name {
              Some(v) => v
              None => ""
            }
            match expr_is_int_value(exp) {
              Some(power) =>
                if name == t_name && power >= 0 {
                  Some(
                    (
                      expr_div(
                        factorial_expr(expr_int(power)),
                        expr_pow(s, expr_int(power + 1)),
                      ),
                      expr_zero(),
                      true_expr(),
                    ),
                  )
                } else {
                  None
                }
              None =>
                if name == t_name && expr_is_constant(exp, t_name) {
                  let gamma_arg = expr_add(exp, expr_one())
                  Some(
                    (
                      expr_div(
                        @symspec.gamma(gamma_arg),
                        expr_pow(s, gamma_arg),
                      ),
                      expr_zero(),
                      @symcore.function("Gt", [@symelem.re(exp), expr_neg_one()]),
                    ),
                  )
                } else {
                  None
                }
            }
          }
        }
      }
    @symcore.Expr::Function("sin", [arg]) =>
      match linear_coeffs(arg, t_name) {
        Some(pair) => {
          let a = pair.0
          let b = pair.1
          if expr_is_zero(a) {
            None
          } else {
            match laplace_trig_term(a, b, s, true) {
              Some(v) => Some((v, expr_zero(), true_expr()))
              None => None
            }
          }
        }
        None => None
      }
    @symcore.Expr::Function("Abs", [@symcore.Expr::Function("sin", [arg])]) =>
      match linear_coeffs(arg, t_name) {
        Some((a, b)) =>
          if expr_is_zero(a) || !expr_is_zero(b) {
            None
          } else {
            Some(
              (
                expr_div(
                  expr_mul(
                    a,
                    @symelem.coth(
                      expr_div(
                        expr_mul(@symcore.pi(), s),
                        expr_mul(expr_int(2), a),
                      ),
                    ),
                  ),
                  expr_add(expr_pow(a, expr_int(2)), expr_pow(s, expr_int(2))),
                ),
                expr_zero(),
                true_expr(),
              ),
            )
          }
        None => None
      }
    @symcore.Expr::Function("cos", [arg]) =>
      match linear_coeffs(arg, t_name) {
        Some(pair) => {
          let a = pair.0
          let b = pair.1
          if expr_is_zero(a) {
            None
          } else {
            match laplace_trig_term(a, b, s, false) {
              Some(v) => Some((v, expr_zero(), true_expr()))
              None => None
            }
          }
        }
        None => None
      }
    @symcore.Expr::Function("sinh", [arg]) =>
      match linear_coeffs(arg, t_name) {
        Some(pair) => {
          let a = pair.0
          let b = pair.1
          if expr_is_zero(a) {
            None
          } else {
            match laplace_hyperbolic_term(a, b, s, true) {
              Some(v) => Some((v, hyperbolic_laplace_plane(a), true_expr()))
              None => None
            }
          }
        }
        None => None
      }
    @symcore.Expr::Function("cosh", [arg]) =>
      match linear_coeffs(arg, t_name) {
        Some(pair) => {
          let a = pair.0
          let b = pair.1
          if expr_is_zero(a) {
            None
          } else {
            match laplace_hyperbolic_term(a, b, s, false) {
              Some(v) => Some((v, hyperbolic_laplace_plane(a), true_expr()))
              None => None
            }
          }
        }
        None => None
      }
    @symcore.Expr::Function("Heaviside", [arg]) =>
      laplace_numeric_heaviside_base_term(arg, t_name, s)
    @symcore.Expr::Function("SingularityFunction", _) =>
      laplace_singularity_base_term(expr, t_name, s)
    @symcore.Expr::Function("erf", [arg]) =>
      match linear_coeffs(arg, t_name) {
        Some((a, b)) =>
          if expr_is_zero(a) || !expr_is_zero(b) {
            None
          } else {
            Some(
              (
                expr_div(
                  expr_mul(
                    @symelem.exp(
                      expr_div(
                        expr_pow(s, expr_int(2)),
                        expr_mul(expr_int(4), expr_pow(a, expr_int(2))),
                      ),
                    ),
                    @symspec.erfc(expr_div(s, expr_mul(expr_int(2), a))),
                  ),
                  s,
                ),
                expr_zero(),
                true_expr(),
              ),
            )
          }
        None => None
      }
    @symcore.Expr::Function("besselj", [order, arg]) =>
      match linear_coeffs(arg, t_name) {
        Some((a, b)) =>
          if !expr_is_zero(order) || expr_is_zero(a) || !expr_is_zero(b) {
            None
          } else {
            Some(
              (
                expr_div(
                  expr_one(),
                  preferred_positive_sqrt(
                    expr_add(expr_pow(a, expr_int(2)), expr_pow(s, expr_int(2))),
                  ),
                ),
                expr_zero(),
                true_expr(),
              ),
            )
          }
        None => None
      }
    @symcore.Expr::Function("besseli", [order, arg]) =>
      match linear_coeffs(arg, t_name) {
        Some((a, b)) =>
          if !expr_is_zero(order) || expr_is_zero(a) || !expr_is_zero(b) {
            None
          } else {
            Some(
              (
                expr_div(
                  expr_one(),
                  preferred_positive_sqrt(
                    expr_sub(expr_pow(s, expr_int(2)), expr_pow(a, expr_int(2))),
                  ),
                ),
                a,
                true_expr(),
              ),
            )
          }
        None => None
      }
    @symcore.Expr::Function("bessely", [order, arg]) =>
      match linear_coeffs(arg, t_name) {
        Some((a, b)) =>
          if !expr_is_zero(order) || expr_is_zero(a) || !expr_is_zero(b) {
            None
          } else {
            Some(
              (
                expr_mul(
                  expr_mul(
                    expr_rat(-2, 1),
                    expr_pow(@symcore.pi(), expr_int(-1)),
                  ),
                  expr_div(
                    @symelem.asinh(expr_div(s, a)),
                    preferred_positive_sqrt(
                      expr_add(
                        expr_pow(a, expr_int(2)),
                        expr_pow(s, expr_int(2)),
                      ),
                    ),
                  ),
                ),
                expr_zero(),
                true_expr(),
              ),
            )
          }
        None => None
      }
    @symcore.Expr::Function("besselk", [order, arg]) =>
      match linear_coeffs(arg, t_name) {
        Some((a, b)) =>
          if !expr_is_zero(order) || expr_is_zero(a) || !expr_is_zero(b) {
            None
          } else {
            let radicand = expr_sub(
              expr_pow(s, expr_int(2)),
              expr_pow(a, expr_int(2)),
            )
            let root = preferred_positive_sqrt(radicand)
            Some(
              (
                expr_div(@symelem.log(expr_div(expr_add(s, root), a)), root),
                expr_mul(expr_neg_one(), a),
                true_expr(),
              ),
            )
          }
        None => None
      }
    @symcore.Expr::Function("fresnels", [@symcore.Expr::Symbol(name)]) =>
      if name == t_name {
        let phase = expr_div(
          expr_pow(s, expr_int(2)),
          expr_mul(expr_int(2), @symcore.pi()),
        )
        let arg = expr_div(s, @symcore.pi())
        Some(
          (
            expr_div(
              expr_add(
                expr_mul(
                  expr_neg_one(),
                  expr_mul(@symelem.sin(phase), @symspec.fresnels(arg)),
                ),
                expr_add(
                  expr_mul(
                    expr_div(expr_sqrt_two(), expr_int(2)),
                    @symelem.sin(
                      expr_add(phase, expr_div(@symcore.pi(), expr_int(4))),
                    ),
                  ),
                  expr_mul(
                    expr_neg_one(),
                    expr_mul(@symelem.cos(phase), @symspec.fresnelc(arg)),
                  ),
                ),
              ),
              s,
            ),
            expr_zero(),
            true_expr(),
          ),
        )
      } else {
        None
      }
    @symcore.Expr::Function("fresnelc", [@symcore.Expr::Symbol(name)]) =>
      if name == t_name {
        let phase = expr_div(
          expr_pow(s, expr_int(2)),
          expr_mul(expr_int(2), @symcore.pi()),
        )
        let arg = expr_div(s, @symcore.pi())
        Some(
          (
            expr_div(
              expr_add(
                expr_mul(@symelem.sin(phase), @symspec.fresnelc(arg)),
                expr_add(
                  expr_mul(
                    expr_mul(expr_neg_one(), @symelem.cos(phase)),
                    @symspec.fresnels(arg),
                  ),
                  expr_mul(
                    expr_div(expr_sqrt_two(), expr_int(2)),
                    @symelem.cos(
                      expr_add(phase, expr_div(@symcore.pi(), expr_int(4))),
                    ),
                  ),
                ),
              ),
              s,
            ),
            expr_zero(),
            true_expr(),
          ),
        )
      } else {
        None
      }
    @symcore.Expr::Function("Ci", [@symcore.Expr::Symbol(name)]) =>
      if name == t_name {
        Some(
          (
            expr_mul(
              expr_rat(-1, 2),
              expr_div(
                @symelem.log(expr_add(expr_one(), expr_pow(s, expr_int(2)))),
                s,
              ),
            ),
            expr_zero(),
            true_expr(),
          ),
        )
      } else {
        None
      }
    @symcore.Expr::Function("Si", [@symcore.Expr::Symbol(name)]) =>
      if name == t_name {
        Some(
          (
            expr_div(@symelem.atan(expr_pow(s, expr_int(-1))), s),
            expr_zero(),
            true_expr(),
          ),
        )
      } else {
        None
      }
    @symcore.Expr::Function("Shi", [@symcore.Expr::Symbol(name)]) =>
      if name == t_name {
        Some(
          (
            expr_div(@symelem.acoth(s), s),
            neg_oo_expr(),
            @symcore.function("Gt", [expr_pow(s, expr_int(2)), expr_one()]),
          ),
        )
      } else {
        None
      }
    @symcore.Expr::Function("Chi", [@symcore.Expr::Symbol(name)]) =>
      if name == t_name {
        Some(
          (
            expr_div(
              expr_sub(
                @symelem.log(expr_pow(s, expr_int(-2))),
                @symelem.log(
                  expr_sub(
                    expr_one(),
                    expr_div(expr_one(), expr_pow(s, expr_int(2))),
                  ),
                ),
              ),
              expr_mul(expr_int(2), s),
            ),
            neg_oo_expr(),
            @symcore.function("Gt", [expr_pow(s, expr_int(2)), expr_one()]),
          ),
        )
      } else {
        None
      }
    @symcore.Expr::Function("E1", [@symcore.Expr::Symbol(name)]) =>
      if name == t_name {
        Some(
          (
            expr_div(@symelem.log(expr_add(s, expr_one())), s),
            expr_zero(),
            true_expr(),
          ),
        )
      } else {
        None
      }
    @symcore.Expr::Function("expint", [n, @symcore.Expr::Symbol(name)]) =>
      if name == t_name {
        match expr_is_int_value(n) {
          Some(1) =>
            Some(
              (
                expr_div(@symelem.log(expr_add(s, expr_one())), s),
                expr_zero(),
                true_expr(),
              ),
            )
          Some(2) =>
            Some(
              (
                expr_div(
                  expr_sub(s, @symelem.log(expr_add(s, expr_one()))),
                  expr_pow(s, expr_int(2)),
                ),
                expr_zero(),
                true_expr(),
              ),
            )
          _ =>
            if expr_is_constant(n, t_name) {
              Some(
                (
                  @symspec.lerchphi(
                    expr_mul(
                      s,
                      @symelem.exp_polar(
                        expr_mul(@symcore.imag_unit(), @symcore.pi()),
                      ),
                    ),
                    expr_one(),
                    n,
                  ),
                  expr_zero(),
                  @symcore.function("Gt", [@symelem.re(n), expr_zero()]),
                ),
              )
            } else {
              None
            }
        }
      } else {
        None
      }
    _ =>
      match @symcore.derivative_parts(expr) {
        Some((inner, deriv_args)) => {
          let args : Array[Expr] = [inner]
          for arg in deriv_args {
            args.push(arg)
          }
          laplace_derivative_term(args, t_name, s)
        }
        None =>
          match expr {
            @symcore.Expr::Function(name, [arg]) =>
              match linear_coeffs(arg, t_name) {
                Some((coeff, offset)) =>
                  if expr_is_positive(coeff) && expr_is_zero(offset) {
                    Some(
                      (
                        expr_simplify(
                          expr_div(
                            @symcore.raw_function("LaplaceTransform", [
                              @symcore.raw_function(name, [
                                @symcore.symbol(t_name),
                              ]),
                              @symcore.symbol(t_name),
                              expr_div(s, coeff),
                            ]),
                            coeff,
                          ),
                        ),
                        neg_oo_expr(),
                        true_expr(),
                      ),
                    )
                  } else if expr_depends_on(arg, t_name) {
                    Some(generic_laplace_object(expr, t_name, s))
                  } else {
                    None
                  }
                _ =>
                  if expr_depends_on(arg, t_name) {
                    Some(generic_laplace_object(expr, t_name, s))
                  } else {
                    None
                  }
              }
            _ =>
              if expr_depends_on(expr, t_name) {
                Some(generic_laplace_object(expr, t_name, s))
              } else {
                None
              }
          }
      }
  }
}

///|
fn laplace_singularity_base_term(
  expr : Expr,
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  match expr {
    @symcore.Expr::Function(
      "SingularityFunction",
      [@symcore.Expr::Symbol(name), offset, order]
    ) if name == t_name && !expr_depends_on(offset, t_name) =>
      match expr_is_int_value(order) {
        Some(-1) =>
          Some(
            (
              expr_simplify(
                @symelem.exp(expr_mul(expr_neg_one(), expr_mul(offset, s))),
              ),
              expr_zero(),
              true_expr(),
            ),
          )
        Some(k) if k >= 0 => {
          let shifted = @symelem.exp(
            expr_mul(expr_neg_one(), expr_mul(offset, s)),
          )
          Some(
            (
              expr_simplify(
                expr_mul(
                  factorial_expr(expr_int(k)),
                  expr_div(shifted, expr_pow(s, expr_int(k + 1))),
                ),
              ),
              expr_zero(),
              true_expr(),
            ),
          )
        }
        _ => None
      }
    _ => None
  }
}

///|
fn laplace_gaussian_mul_term(
  factors : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  let mut scale : Expr? = None
  let mut total_power = 0
  for factor in factors {
    match factor {
      @symcore.Expr::Function("exp", [inner]) =>
        match parse_negative_quadratic_exp(inner, t_name) {
          Some(parsed_scale) =>
            if scale is None {
              scale = Some(parsed_scale)
            } else {
              return None
            }
          None => return None
        }
      _ =>
        match parse_power_factor(factor, t_name) {
          Some(power_expr) =>
            match expr_is_int_value(power_expr) {
              Some(power) if power >= 0 => total_power += power
              _ => return None
            }
          None => return None
        }
    }
  }
  match scale {
    Some(parsed_scale) if total_power >= 0 && total_power <= 2 =>
      Some(
        (
          laplace_gaussian_value(parsed_scale, s, total_power),
          expr_zero(),
          gaussian_laplace_condition(parsed_scale),
        ),
      )
    _ => None
  }
}

///|
fn laplace_gaussian_base_term(
  inner : Expr,
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  match parse_negative_quadratic_exp(inner, t_name) {
    Some(scale) =>
      Some(
        (
          laplace_gaussian_value(scale, s, 0),
          expr_zero(),
          gaussian_laplace_condition(scale),
        ),
      )
    None => None
  }
}

///|
fn laplace_gaussian_value(scale : Expr, s : Expr, power : Int) -> Expr {
  let sqrt_scale = expr_sqrt_positive(scale)
  let erfc_arg = expr_div(s, expr_mul(expr_int(2), sqrt_scale))
  let erfc_term = @symspec.erfc(erfc_arg)
  let exp_term = @symelem.exp(
    expr_div(expr_pow(s, expr_int(2)), expr_mul(expr_int(4), scale)),
  )
  let common = expr_mul(sqrt_pi(), expr_mul(exp_term, erfc_term))
  match power {
    0 => expr_div(common, expr_mul(expr_int(2), sqrt_scale))
    1 =>
      expr_sub(
        expr_div(expr_one(), expr_mul(expr_int(2), scale)),
        expr_div(
          expr_mul(s, erfc_term),
          expr_mul(
            expr_int(4),
            expr_mul(sqrt_pi(), expr_pow(scale, expr_rat(3, 2))),
          ),
        ),
      )
    2 =>
      expr_add(
        expr_mul(
          expr_neg_one(),
          expr_div(s, expr_mul(expr_int(4), expr_pow(scale, expr_int(2)))),
        ),
        expr_add(
          expr_div(
            common,
            expr_mul(expr_int(4), expr_pow(scale, expr_rat(3, 2))),
          ),
          expr_div(
            expr_mul(common, expr_pow(s, expr_int(2))),
            expr_mul(expr_int(8), expr_pow(scale, expr_rat(5, 2))),
          ),
        ),
      )
    _ => expr_zero()
  }
}

///|
fn gaussian_laplace_condition(scale : Expr) -> Expr {
  if expr_is_positive(scale) {
    true_expr()
  } else {
    @symcore.function("Le", [
      @symelem.abs(@symelem.arg(scale)),
      expr_div(@symcore.pi(), expr_int(2)),
    ])
  }
}

///|
fn hyperbolic_laplace_plane(scale : Expr) -> Expr {
  expr_simplify(@symelem.abs(@symelem.re(scale)))
}

///|
fn laplace_function_power_base_term(
  base : Expr,
  exp : Expr,
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  let power = match expr_is_int_value(exp) {
    Some(v) => v
    None => return None
  }
  match base {
    @symcore.Expr::Function("sin", [arg]) if power == 2 =>
      laplace_info_doit(
        expr_mul(
          expr_rat(1, 2),
          expr_sub(expr_one(), @symelem.cos(expr_mul(expr_int(2), arg))),
        ),
        t_name,
        s,
      )
    @symcore.Expr::Function("sin", [arg]) if power == 4 =>
      laplace_info_doit(
        expr_mul(
          expr_rat(1, 8),
          expr_add(
            expr_int(3),
            expr_add(
              expr_mul(expr_int(-4), @symelem.cos(expr_mul(expr_int(2), arg))),
              @symelem.cos(expr_mul(expr_int(4), arg)),
            ),
          ),
        ),
        t_name,
        s,
      )
    @symcore.Expr::Function("cos", [arg]) if power == 2 =>
      laplace_info_doit(
        expr_mul(
          expr_rat(1, 2),
          expr_add(expr_one(), @symelem.cos(expr_mul(expr_int(2), arg))),
        ),
        t_name,
        s,
      )
    @symcore.Expr::Function("sinh", [arg]) if power == 2 =>
      laplace_info_doit(
        expr_mul(
          expr_rat(1, 2),
          expr_sub(@symelem.cosh(expr_mul(expr_int(2), arg)), expr_one()),
        ),
        t_name,
        s,
      )
    @symcore.Expr::Function("cosh", [arg]) if power == 2 =>
      laplace_info_doit(
        expr_mul(
          expr_rat(1, 2),
          expr_add(@symelem.cosh(expr_mul(expr_int(2), arg)), expr_one()),
        ),
        t_name,
        s,
      )
    _ => None
  }
}

///|
fn laplace_power_product_identity_term(
  factors : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  if factors.length() != 2 {
    return None
  }
  match (factors[0], factors[1]) {
    (
      @symcore.Expr::Pow(@symcore.Expr::Function("sin", [arg]), exp),
      @symcore.Expr::Function("cosh", [other_arg]),
    )
    | (
      @symcore.Expr::Function("cosh", [other_arg]),
      @symcore.Expr::Pow(@symcore.Expr::Function("sin", [arg]), exp),
    ) =>
      match
        (
          expr_is_int_value(exp),
          linear_coeffs(arg, t_name),
          linear_coeffs(other_arg, t_name),
        ) {
        (Some(3), Some((a, offset_a)), Some((b, offset_b))) if expr_is_zero(
            offset_a,
          ) &&
          expr_is_zero(offset_b) =>
          Some(
            (
              expr_mul(
                expr_div(expr_mul(expr_int(3), a), expr_int(8)),
                expr_sub(
                  expr_add(
                    expr_pow(
                      expr_add(
                        expr_pow(expr_add(s, b), expr_int(2)),
                        expr_pow(a, expr_int(2)),
                      ),
                      expr_int(-1),
                    ),
                    expr_pow(
                      expr_add(
                        expr_pow(expr_sub(s, b), expr_int(2)),
                        expr_pow(a, expr_int(2)),
                      ),
                      expr_int(-1),
                    ),
                  ),
                  expr_add(
                    expr_pow(
                      expr_add(
                        expr_pow(expr_add(s, b), expr_int(2)),
                        expr_mul(expr_int(9), expr_pow(a, expr_int(2))),
                      ),
                      expr_int(-1),
                    ),
                    expr_pow(
                      expr_add(
                        expr_pow(expr_sub(s, b), expr_int(2)),
                        expr_mul(expr_int(9), expr_pow(a, expr_int(2))),
                      ),
                      expr_int(-1),
                    ),
                  ),
                ),
              ),
              hyperbolic_laplace_plane(b),
              true_expr(),
            ),
          )
        _ => None
      }
    _ => None
  }
}

///|
fn laplace_identity_product_term(
  factors : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  if factors.length() != 2 {
    return None
  }
  let rewrite = match (factors[0], factors[1]) {
    (@symcore.Expr::Function("sin", [u]), @symcore.Expr::Function("sin", [v])) =>
      Some(
        expr_mul(
          expr_rat(1, 2),
          expr_sub(@symelem.cos(expr_sub(u, v)), @symelem.cos(expr_add(u, v))),
        ),
      )
    (@symcore.Expr::Function("cos", [u]), @symcore.Expr::Function("cos", [v])) =>
      Some(
        expr_mul(
          expr_rat(1, 2),
          expr_add(@symelem.cos(expr_sub(u, v)), @symelem.cos(expr_add(u, v))),
        ),
      )
    (@symcore.Expr::Function("cos", [u]), @symcore.Expr::Function("sin", [v]))
    | (@symcore.Expr::Function("sin", [v]), @symcore.Expr::Function("cos", [u])) =>
      Some(
        expr_mul(
          expr_rat(1, 2),
          expr_add(@symelem.sin(expr_add(u, v)), @symelem.sin(expr_sub(v, u))),
        ),
      )
    (@symcore.Expr::Function("sinh", [u]), @symcore.Expr::Function("cosh", [v]))
    | (
      @symcore.Expr::Function("cosh", [v]),
      @symcore.Expr::Function("sinh", [u]),
    ) =>
      Some(
        expr_mul(
          expr_rat(1, 2),
          expr_add(@symelem.sinh(expr_add(u, v)), @symelem.sinh(expr_sub(u, v))),
        ),
      )
    (@symcore.Expr::Function("sin", [u]), @symcore.Expr::Function("cosh", [v]))
    | (@symcore.Expr::Function("cosh", [v]), @symcore.Expr::Function("sin", [u])
    ) =>
      match (linear_coeffs(u, t_name), linear_coeffs(v, t_name)) {
        (Some((a, bu)), Some((b, bv))) if expr_is_zero(bu) && expr_is_zero(bv) =>
          Some(
            expr_mul(
              expr_rat(1, 2),
              expr_add(
                expr_div(
                  a,
                  expr_add(
                    expr_pow(expr_sub(s, b), expr_int(2)),
                    expr_pow(a, expr_int(2)),
                  ),
                ),
                expr_div(
                  a,
                  expr_add(
                    expr_pow(expr_add(s, b), expr_int(2)),
                    expr_pow(a, expr_int(2)),
                  ),
                ),
              ),
            ),
          )
        _ => None
      }
    _ => None
  }
  match rewrite {
    Some(expr) => laplace_info_doit(expr_simplify(expr), t_name, s)
    None => None
  }
}

///|
fn laplace_numeric_heaviside_base_term(
  arg : Expr,
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  match linear_coeffs(arg, t_name) {
    Some((coeff, offset)) =>
      if expr_is_zero(coeff) || !expr_is_constant(offset, t_name) {
        None
      } else {
        let bound = expr_simplify(
          expr_div(expr_mul(expr_neg_one(), offset), coeff),
        )
        let value = if expr_is_positive(coeff) {
          if expr_is_negative(bound) || expr_is_zero(bound) {
            expr_div(expr_one(), s)
          } else {
            expr_div(
              @symelem.exp(expr_mul(expr_neg_one(), expr_mul(bound, s))),
              s,
            )
          }
        } else if expr_is_negative(coeff) {
          if expr_is_negative(bound) || expr_is_zero(bound) {
            expr_zero()
          } else {
            expr_sub(
              expr_div(expr_one(), s),
              expr_div(
                @symelem.exp(expr_mul(expr_neg_one(), expr_mul(bound, s))),
                s,
              ),
            )
          }
        } else {
          return None
        }
        Some((expr_simplify(value), expr_zero(), true_expr()))
      }
    _ => None
  }
}

///|
fn generic_laplace_object(
  expr : Expr,
  t_name : String,
  s : Expr,
) -> LaplaceInfo {
  (
    @symcore.raw_function("LaplaceTransform", [expr, @symcore.symbol(t_name), s]),
    neg_oo_expr(),
    true_expr(),
  )
}

///|
fn laplace_piecewise_term(
  args : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  match piecewise_to_heaviside_expr(args, t_name) {
    Some(rewritten) => laplace_info_doit(expr_simplify(rewritten), t_name, s)
    None => None
  }
}

///|
fn piecewise_to_heaviside_expr(args : Array[Expr], t_name : String) -> Expr? {
  if args.length() < 2 {
    return None
  }
  let t = @symcore.symbol(t_name)
  let mut default = expr_zero()
  let mut has_default = false
  let terms : Array[Expr] = []
  let mut i = 0
  while i + 1 < args.length() {
    let branch = args[i]
    let cond = args[i + 1]
    if cond == true_expr() {
      default = branch
      has_default = true
      break
    }
    i += 2
  }
  if !has_default {
    return None
  }

  let base = expr_simplify(
    expr_mul(default, heaviside_window(t, expr_zero(), None)),
  )
  if !expr_is_zero(base) {
    terms.push(base)
  }

  let mut current_start = expr_zero()
  i = 0
  while i + 1 < args.length() {
    let branch = args[i]
    let cond = args[i + 1]
    if cond == true_expr() {
      break
    }
    match parse_piecewise_interval(cond, t_name) {
      Some((lower, upper)) => {
        let start = match lower {
          Some(v) => max_expr(current_start, v)
          None => current_start
        }
        let window = heaviside_window(t, start, upper)
        let correction = expr_simplify(
          expr_mul(expr_sub(branch, default), window),
        )
        if !expr_is_zero(correction) {
          terms.push(correction)
        }
        match upper {
          Some(v) => current_start = max_expr(current_start, v)
          None => current_start = max_expr(current_start, start)
        }
      }
      None => return None
    }
    i += 2
  }
  if terms.length() == 0 {
    Some(expr_zero())
  } else {
    Some(expr_simplify(@symcore.add(terms)))
  }
}

///|
fn heaviside_window(t : Expr, start : Expr, end : Expr?) -> Expr {
  let left = @symspec.heaviside(expr_sub(t, start))
  match end {
    Some(bound) =>
      expr_simplify(expr_sub(left, @symspec.heaviside(expr_sub(t, bound))))
    None => left
  }
}

///|
fn parse_piecewise_interval(cond : Expr, t_name : String) -> (Expr?, Expr?)? {
  match cond {
    @symcore.Expr::Function("And", items) => {
      let mut lower : Expr? = None
      let mut upper : Expr? = None
      for item in items {
        match parse_piecewise_interval(item, t_name) {
          Some((item_lower, item_upper)) => {
            match item_lower {
              Some(v) =>
                lower = Some(
                  match lower {
                    Some(curr) => max_expr(curr, v)
                    None => v
                  },
                )
              None => ()
            }
            match item_upper {
              Some(v) =>
                upper = Some(
                  match upper {
                    Some(curr) => min_expr(curr, v)
                    None => v
                  },
                )
              None => ()
            }
          }
          None => return None
        }
      }
      Some((lower, upper))
    }
    _ =>
      match @symcore.relational_parts(cond) {
        Some((@symcore.RelOp::Le, lhs, rhs))
        | Some((@symcore.RelOp::Lt, lhs, rhs)) =>
          parse_piecewise_relational(lhs, rhs, t_name, true)
        Some((@symcore.RelOp::Ge, lhs, rhs))
        | Some((@symcore.RelOp::Gt, lhs, rhs)) =>
          parse_piecewise_relational(lhs, rhs, t_name, false)
        _ => None
      }
  }
}

///|
fn parse_piecewise_relational(
  lhs : Expr,
  rhs : Expr,
  t_name : String,
  is_upper : Bool,
) -> (Expr?, Expr?)? {
  match (lhs, rhs) {
    (@symcore.Expr::Symbol(name), bound) =>
      if name == t_name && expr_is_constant(bound, t_name) {
        if is_upper {
          Some((None, Some(bound)))
        } else {
          Some((Some(bound), None))
        }
      } else {
        None
      }
    (bound, @symcore.Expr::Symbol(name)) =>
      if name == t_name && expr_is_constant(bound, t_name) {
        if is_upper {
          Some((Some(bound), None))
        } else {
          Some((None, Some(bound)))
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn laplace_generic_shifted_term(
  factors : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  if factors.length() != 2 {
    return None
  }
  let first = factors[0]
  let second = factors[1]
  match laplace_generic_trig_power_term(first, second, t_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  match laplace_generic_trig_power_term(second, first, t_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  match laplace_generic_trig_term(first, second, t_name, s) {
    Some(info) => Some(info)
    None => laplace_generic_trig_term(second, first, t_name, s)
  }
}

///|
fn laplace_generic_trig_power_term(
  trig_factor : Expr,
  other : Expr,
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  if !expr_depends_on(other, t_name) {
    return None
  }
  match trig_factor {
    @symcore.Expr::Pow(@symcore.Expr::Function("sin", [arg]), exp) =>
      match expr_is_int_value(exp) {
        Some(2) =>
          match linear_coeffs(arg, t_name) {
            Some((a, b)) if expr_is_constant(a, t_name) &&
              expr_is_constant(b, t_name) => {
              let ia2 = expr_mul(expr_mul(expr_int(2), @symcore.imag_unit()), a)
              let value = expr_sub(
                expr_mul(
                  expr_rat(1, 2),
                  @symcore.raw_function("LaplaceTransform", [
                    other,
                    @symcore.symbol(t_name),
                    s,
                  ]),
                ),
                expr_add(
                  expr_mul(
                    expr_rat(1, 4),
                    expr_mul(
                      @symelem.exp(
                        expr_mul(expr_mul(expr_int(2), @symcore.imag_unit()), b),
                      ),
                      @symcore.raw_function("LaplaceTransform", [
                        other,
                        @symcore.symbol(t_name),
                        expr_sub(s, ia2),
                      ]),
                    ),
                  ),
                  expr_mul(
                    expr_rat(1, 4),
                    expr_mul(
                      @symelem.exp(
                        expr_mul(
                          expr_mul(expr_int(-2), @symcore.imag_unit()),
                          b,
                        ),
                      ),
                      @symcore.raw_function("LaplaceTransform", [
                        other,
                        @symcore.symbol(t_name),
                        expr_add(s, ia2),
                      ]),
                    ),
                  ),
                ),
              )
              Some((expr_simplify(value), neg_oo_expr(), true_expr()))
            }
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn laplace_generic_trig_term(
  trig_factor : Expr,
  other : Expr,
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  if !expr_depends_on(other, t_name) {
    return None
  }
  let transform = fn(shifted_s : Expr) {
    @symcore.raw_function("LaplaceTransform", [
      other,
      @symcore.symbol(t_name),
      shifted_s,
    ])
  }
  match trig_factor {
    @symcore.Expr::Function("sinh", [arg]) =>
      match linear_coeffs(arg, t_name) {
        Some((a, b)) if expr_is_zero(b) =>
          Some(
            (
              expr_mul(
                expr_rat(1, 2),
                expr_sub(transform(expr_sub(s, a)), transform(expr_add(s, a))),
              ),
              max_expr(
                expr_add(
                  expr_mul(expr_neg_one(), @symelem.re(a)),
                  neg_oo_expr(),
                ),
                expr_add(@symelem.re(a), neg_oo_expr()),
              ),
              true_expr(),
            ),
          )
        _ => None
      }
    @symcore.Expr::Function("cosh", [arg]) =>
      match linear_coeffs(arg, t_name) {
        Some((a, b)) if expr_is_zero(b) =>
          Some(
            (
              expr_mul(
                expr_rat(1, 2),
                expr_add(transform(expr_sub(s, a)), transform(expr_add(s, a))),
              ),
              max_expr(
                expr_add(
                  expr_mul(expr_neg_one(), @symelem.re(a)),
                  neg_oo_expr(),
                ),
                expr_add(@symelem.re(a), neg_oo_expr()),
              ),
              true_expr(),
            ),
          )
        _ => None
      }
    @symcore.Expr::Function("sin", [arg]) =>
      match linear_coeffs(arg, t_name) {
        Some((a, b)) if expr_is_zero(b) => {
          let ia = expr_mul(@symcore.imag_unit(), a)
          Some(
            (
              expr_mul(
                expr_div(@symcore.imag_unit(), expr_int(2)),
                expr_sub(transform(expr_add(s, ia)), transform(expr_sub(s, ia))),
              ),
              max_expr(
                expr_add(
                  expr_mul(expr_neg_one(), @symelem.im(a)),
                  neg_oo_expr(),
                ),
                expr_add(@symelem.im(a), neg_oo_expr()),
              ),
              true_expr(),
            ),
          )
        }
        _ => None
      }
    @symcore.Expr::Function("cos", [arg]) =>
      match linear_coeffs(arg, t_name) {
        Some((a, b)) if expr_is_zero(b) => {
          let ia = expr_mul(@symcore.imag_unit(), a)
          Some(
            (
              expr_mul(
                expr_rat(1, 2),
                expr_add(transform(expr_add(s, ia)), transform(expr_sub(s, ia))),
              ),
              max_expr(
                expr_add(
                  expr_mul(expr_neg_one(), @symelem.im(a)),
                  neg_oo_expr(),
                ),
                expr_add(@symelem.im(a), neg_oo_expr()),
              ),
              true_expr(),
            ),
          )
        }
        _ => None
      }
    _ => None
  }
}

///|
fn laplace_log_term(inner : Expr, t_name : String, s : Expr) -> LaplaceInfo? {
  match linear_coeffs(inner, t_name) {
    Some((coeff, offset)) =>
      if expr_is_zero(coeff) {
        None
      } else if expr_is_zero(offset) {
        Some(
          (
            expr_div(
              expr_sub(
                @symelem.log(coeff),
                expr_add(@symelem.log(s), @symcore.euler_gamma()),
              ),
              s,
            ),
            expr_zero(),
            true_expr(),
          ),
        )
      } else if expr_is_one(offset) {
        let shift = expr_div(s, coeff)
        Some(
          (
            expr_mul(
              expr_neg_one(),
              expr_div(
                expr_mul(
                  @symelem.exp(shift),
                  @symspec.ei(expr_neg_one() * shift),
                ),
                s,
              ),
            ),
            expr_zero(),
            true_expr(),
          ),
        )
      } else if expr_is_one(coeff) {
        let shift = expr_div(s, offset)
        Some(
          (
            expr_div(
              expr_sub(
                expr_mul(s, @symelem.log(offset)),
                expr_mul(
                  @symelem.exp(shift),
                  @symspec.ei(expr_neg_one() * shift),
                ),
              ),
              expr_pow(s, expr_int(2)),
            ),
            expr_zero(),
            true_expr(),
          ),
        )
      } else {
        None
      }
    None => None
  }
}

///|
fn laplace_log_squared_term(
  inner : Expr,
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  match inner {
    @symcore.Expr::Symbol(name) if name == t_name =>
      Some(
        (
          expr_div(
            expr_add(
              expr_pow(
                expr_add(@symelem.log(s), @symcore.euler_gamma()),
                expr_int(2),
              ),
              expr_mul(expr_pow(@symcore.pi(), expr_int(2)), expr_rat(1, 6)),
            ),
            s,
          ),
          expr_zero(),
          true_expr(),
        ),
      )
    _ => None
  }
}

///|
fn laplace_inverse_power_trig_term(
  factors : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  if factors.length() != 2 {
    return None
  }
  let mut inverse_power : Int? = None
  let mut trig_factor : Expr? = None
  for factor in factors {
    match parse_negative_power(factor, t_name) {
      Some(power) =>
        match expr_is_int_value(power) {
          Some(value) if value >= 1 && inverse_power is None =>
            inverse_power = Some(value)
          _ => ()
        }
      _ =>
        if trig_factor is None {
          trig_factor = Some(factor)
        } else {
          return None
        }
    }
  }
  if inverse_power is None {
    return None
  }
  let power = inverse_power.unwrap()
  match trig_factor {
    Some(@symcore.Expr::Function("sin", [arg])) =>
      match linear_coeffs(arg, t_name) {
        Some((a, b)) if !expr_is_zero(a) && expr_is_zero(b) =>
          if power == 1 {
            Some((@symelem.atan(expr_div(a, s)), expr_zero(), true_expr()))
          } else {
            None
          }
        _ => None
      }
    Some(@symcore.Expr::Pow(@symcore.Expr::Function("sin", [arg]), exp)) =>
      match (expr_is_int_value(exp), linear_coeffs(arg, t_name)) {
        (Some(2), Some((a, b))) if !expr_is_zero(a) && expr_is_zero(b) => {
          let log_term = expr_mul(
            expr_rat(1, 4),
            @symelem.log(
              expr_add(
                expr_one(),
                expr_div(
                  expr_mul(expr_int(4), expr_pow(a, expr_int(2))),
                  expr_pow(s, expr_int(2)),
                ),
              ),
            ),
          )
          if power == 1 {
            Some((log_term, expr_zero(), true_expr()))
          } else if power == 2 {
            Some(
              (
                expr_sub(
                  expr_mul(
                    a,
                    @symelem.atan(expr_div(expr_mul(expr_int(2), a), s)),
                  ),
                  expr_mul(s, log_term),
                ),
                expr_zero(),
                true_expr(),
              ),
            )
          } else {
            None
          }
        }
        _ => None
      }
    Some(@symcore.Expr::Function("sinh", [arg])) =>
      match linear_coeffs(arg, t_name) {
        Some((a, b)) if !expr_is_zero(a) && expr_is_zero(b) =>
          if power == 1 {
            Some(
              (
                expr_mul(
                  expr_rat(1, 2),
                  @symelem.log(expr_div(expr_add(a, s), expr_sub(s, a))),
                ),
                hyperbolic_laplace_plane(a),
                true_expr(),
              ),
            )
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn laplace_derivative_term(
  args : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  let order = match laplace_derivative_order(args, t_name) {
    Some(v) if v > 0 => v
    _ => return None
  }
  let base = args[0]
  let t_sym = @symcore.symbol(t_name)
  let (base_value, plane, cond) = match
    laplace_info_doit(expr_simplify(base), t_name, s) {
    Some(info) => info
    None =>
      (
        @symcore.raw_function("LaplaceTransform", [base, t_sym, s]),
        neg_oo_expr(),
        true_expr(),
      )
  }
  let leading = expr_mul(expr_pow(s, expr_int(order)), base_value)
  let init_terms : Array[Expr] = []
  for idx in 0..<order {
    let init = laplace_initial_value(base, t_sym, t_name, idx)
    let s_pow = order - idx - 1
    init_terms.push(
      if s_pow == 0 {
        init
      } else {
        expr_mul(expr_pow(s, expr_int(s_pow)), init)
      },
    )
  }
  Some(
    (
      expr_simplify(
        expr_sub(
          leading,
          if init_terms.length() == 1 {
            init_terms[0]
          } else {
            expr_simplify(@symcore.add(init_terms))
          },
        ),
      ),
      plane,
      cond,
    ),
  )
}

///|
fn laplace_derivative_order(args : Array[Expr], t_name : String) -> Int? {
  if args.length() < 2 {
    return None
  }
  let mut order = 0
  let mut saw_var = false
  for idx in 1..<args.length() {
    match args[idx] {
      @symcore.Expr::Symbol(name) if name == t_name => {
        order += 1
        saw_var = true
      }
      @symcore.Expr::Number(n) if saw_var &&
        n.is_integral() &&
        n.numerator().to_int() >= 1 => order += n.numerator().to_int() - 1
      _ => return None
    }
  }
  if saw_var {
    Some(order)
  } else {
    None
  }
}

///|
fn laplace_initial_value(
  base : Expr,
  t_sym : Expr,
  t_name : String,
  order : Int,
) -> Expr {
  if order == 0 {
    expr_simplify(subst_symbol(base, t_name, expr_zero()))
  } else {
    let mut deriv = base
    for _ in 0..<order {
      deriv = @symcalculus.diff(deriv, t_sym)
    }
    if expr_has_function_name(deriv, "Derivative") {
      @symcore.raw_function("Subs", [deriv, t_sym, expr_zero()])
    } else {
      expr_simplify(subst_symbol(deriv, t_name, expr_zero()))
    }
  }
}

///|
fn laplace_trig_term(a : Expr, b : Expr, s : Expr, is_sin : Bool) -> Expr? {
  let a2 = expr_pow(a, expr_int(2))
  let den = expr_add(a2, expr_pow(s, expr_int(2)))
  if expr_is_zero(b) {
    if is_sin {
      Some(expr_div(a, den))
    } else {
      Some(expr_div(s, den))
    }
  } else {
    let cb = @symelem.cos(b)
    let sb = @symelem.sin(b)
    if is_sin {
      Some(
        expr_add(expr_mul(cb, expr_div(a, den)), expr_mul(sb, expr_div(s, den))),
      )
    } else {
      Some(
        expr_sub(expr_mul(cb, expr_div(s, den)), expr_mul(sb, expr_div(a, den))),
      )
    }
  }
}

///|
fn laplace_hyperbolic_term(
  a : Expr,
  b : Expr,
  s : Expr,
  is_sinh : Bool,
) -> Expr? {
  let a2 = expr_pow(a, expr_int(2))
  let den = expr_sub(expr_pow(s, expr_int(2)), a2)
  let cb = @symelem.cosh(b)
  let sb = @symelem.sinh(b)
  if is_sinh {
    Some(
      expr_add(expr_mul(cb, expr_div(a, den)), expr_mul(sb, expr_div(s, den))),
    )
  } else {
    Some(
      expr_add(expr_mul(cb, expr_div(s, den)), expr_mul(sb, expr_div(a, den))),
    )
  }
}

///|
/// Apply the inverse Laplace rule table and return only the time-domain value.
///
/// This drives `.doit()` for `InverseLaplaceTransform`. Delay/object semantics
/// and `Heaviside` factors are handled here; `None` means the expression stays
/// unevaluated.
pub fn do_inverse_laplace_doit(expr : Expr, s : Expr, t : Expr) -> Expr? {
  match symbol_name(s) {
    Some(s_name) => inverse_laplace_doit(expr_simplify(expr), s_name, t)
    None => None
  }
}

///|
fn inverse_laplace_doit(expr : Expr, s_name : String, t : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Add(terms) => inverse_laplace_add_termwise(terms, s_name, t)
    _ =>
      match inverse_laplace_special_term(expr_simplify(expr), s_name, t) {
        Some(v) => Some(v)
        None =>
          match inverse_laplace_delay_term(expr, s_name, t) {
            Some(v) => Some(v)
            None => {
              let (num_exprs, den_opt) = split_division(expr)
              match den_opt {
                None => None
                Some(den) => {
                  let (coeff, var_expr_opt) = split_mul_factor(
                    num_exprs, s_name,
                  )
                  match var_expr_opt {
                    None => inverse_laplace_no_var(coeff, den, t, s_name)
                    Some(var_expr) =>
                      inverse_laplace_with_var(coeff, var_expr, den, t, s_name)
                  }
                }
              }
            }
          }
      }
  }
}

///|
fn inverse_laplace_special_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  match inverse_laplace_constant_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_dirac_polynomial_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_time_diff_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_transform_object_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_e1_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_expint2_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_log_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_atan_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_sinh_over_t_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_power_law_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_bessel_branch_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_square_over_quadratic_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_irrational_algebraic_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_generic_head_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  inverse_laplace_ci_term(expr, s_name, t)
}

///|
fn inverse_laplace_constant_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  if expr_depends_on(expr, s_name) {
    None
  } else {
    Some(expr_simplify(expr * @symspec.dirac_delta(t)))
  }
}

///|
fn inverse_laplace_dirac_polynomial_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (_, den_opt) = split_division(expr)
  if den_opt is Some(_) {
    return None
  }
  let (coeff, factors) = split_mul(expr, s_name)
  if factors.length() == 0 {
    return None
  }
  let mut order = 0
  for factor in factors {
    match parse_power_factor(factor, s_name) {
      Some(power) =>
        match expr_is_int_value(power) {
          Some(n) if n > 0 => order += n
          _ => return None
        }
      None => return None
    }
  }
  if order <= 0 {
    return None
  }
  Some(
    expr_simplify(
      coeff * @symcore.raw_function("DiracDelta", [t, expr_int(order)]),
    ),
  )
}

///|
fn inverse_laplace_time_diff_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (_, den_opt) = split_division(expr)
  if den_opt is Some(_) {
    return None
  }
  let (coeff, factors) = split_mul(expr, s_name)
  if factors.length() == 0 {
    return None
  }
  let rest : Array[Expr] = []
  let mut order = 0
  let mut removed = false
  for factor in factors {
    match parse_power_factor(factor, s_name) {
      Some(power) =>
        match expr_is_int_value(power) {
          Some(n) if n > 0 => {
            order += n
            removed = true
          }
          _ => rest.push(factor)
        }
      None => rest.push(factor)
    }
  }
  if !removed || rest.length() == 0 {
    return None
  }
  let reduced = expr_simplify(expr_mul(coeff, factors_expr(rest)))
  let power_factor = @symcore.symbol(s_name) ^ expr_int(order)
  match reduced {
    @symcore.Expr::Add(terms) => {
      let mapped : Array[Expr] = []
      for term in terms {
        let lifted = expr_simplify(coeff * power_factor * term)
        match inverse_laplace_doit(lifted, s_name, t) {
          Some(v) => mapped.push(v)
          None => mapped.push(make_inverse_laplace_object(lifted, s_name, t))
        }
      }
      return Some(expr_simplify(@symcore.add(mapped)))
    }
    _ => ()
  }
  let base = match inverse_laplace_doit(reduced, s_name, t) {
    Some(v) => v
    None => make_inverse_laplace_object(reduced, s_name, t)
  }
  Some(make_expr_derivative(base, t, order))
}

///|
fn inverse_laplace_transform_object_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  match expr {
    @symcore.Expr::Function("LaplaceTransform", [inner, source_t, source_s]) => {
      let s_sym = @symcore.symbol(s_name)
      if expr_eq(source_s, s_sym) {
        match symbol_name(source_t) {
          Some(source_name) =>
            Some(
              expr_simplify(
                subst_symbol(inner, source_name, t) * @symspec.heaviside(t),
              ),
            )
          None => Some(expr_simplify(inner * @symspec.heaviside(t)))
        }
      } else {
        Some(expr_simplify(expr * @symspec.dirac_delta(t)))
      }
    }
    _ => None
  }
}

///|
fn inverse_laplace_add_termwise(
  terms : Array[Expr],
  s_name : String,
  t : Expr,
) -> Expr? {
  let mapped : Array[Expr] = []
  for term in terms {
    match inverse_laplace_doit(term, s_name, t) {
      Some(v) => mapped.push(v)
      None => mapped.push(make_inverse_laplace_object(term, s_name, t))
    }
  }
  Some(expr_simplify(@symcore.add(mapped)))
}

///|
fn make_inverse_laplace_object(expr : Expr, s_name : String, t : Expr) -> Expr {
  let (coeff, factors) = split_mul(expr, s_name)
  let core = factors_expr(factors)
  expr_simplify(
    coeff *
    @symcore.raw_function("InverseLaplaceTransform", [
      core,
      @symcore.symbol(s_name),
      t,
    ]),
  )
}

///|
fn inverse_laplace_ci_term(expr : Expr, s_name : String, t : Expr) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  if !expr_eq(den, @symcore.symbol(s_name)) {
    return None
  }
  let numerator = factors_expr(num)
  let (coeff, factors) = split_mul(numerator, s_name)
  if !expr_eq(coeff, expr_rat(-1, 2)) || factors.length() != 1 {
    return None
  }
  match factors[0] {
    @symcore.Expr::Function("log", [inner]) =>
      match poly_coeffs_upto2(inner, s_name) {
        Some(coeffs) =>
          if expr_eq(coeffs[0], expr_one()) &&
            expr_is_zero(coeffs[1]) &&
            expr_eq(coeffs[2], expr_one()) {
            Some(expr_simplify(@symspec.heaviside(t) * @symspec.ci(t)))
          } else {
            None
          }
        None => None
      }
    _ => None
  }
}

///|
fn inverse_laplace_e1_term(expr : Expr, s_name : String, t : Expr) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  if !expr_eq(den, @symcore.symbol(s_name)) {
    return None
  }
  let numerator = factors_expr(num)
  if matches_log_one_plus_linear(numerator, s_name) {
    Some(expr_simplify(@symspec.heaviside(t) * @symspec.e1(t)))
  } else {
    None
  }
}

///|
fn inverse_laplace_expint2_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let s_sym = @symcore.symbol(s_name)
  let target = expr_div(
    expr_sub(s_sym, @symelem.log(expr_add(s_sym, expr_one()))),
    expr_pow(s_sym, expr_int(2)),
  )
  if expr_eq(expr_simplify(expr), expr_simplify(target)) {
    Some(expr_simplify(@symspec.heaviside(t) * @symspec.expint(expr_int(2), t)))
  } else {
    None
  }
}

///|
fn inverse_laplace_log_term(expr : Expr, s_name : String, t : Expr) -> Expr? {
  match inverse_laplace_log_plain_term(expr, s_name, t) {
    Some(v) => Some(v)
    None => inverse_laplace_log_one_plus_linear_term(expr, s_name, t)
  }
}

///|
fn inverse_laplace_log_plain_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let s_sym = @symcore.symbol(s_name)
  let target = expr_div(
    expr_mul(
      expr_neg_one(),
      expr_add(@symelem.log(s_sym), @symcore.euler_gamma()),
    ),
    s_sym,
  )
  if expr_eq(expr_simplify(expr), expr_simplify(target)) {
    Some(expr_simplify(@symspec.heaviside(t) * @symelem.log(t)))
  } else {
    None
  }
}

///|
fn inverse_laplace_log_one_plus_linear_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  if !expr_eq(den, @symcore.symbol(s_name)) {
    return None
  }
  let (coeff, factors) = split_mul(factors_expr(num), s_name)
  if !expr_is_minus_one(coeff) || factors.length() != 2 {
    return None
  }
  let mut exp_coeff : Expr? = None
  let mut ei_coeff : Expr? = None
  for factor in factors {
    match factor {
      @symcore.Expr::Function("exp", [inner]) =>
        match parse_linear_scale_only(inner, s_name) {
          Some(scale) => exp_coeff = Some(scale)
          _ => return None
        }
      @symcore.Expr::Function("Ei", [inner]) =>
        match parse_linear_scale_only(inner, s_name) {
          Some(scale) => ei_coeff = Some(scale)
          _ => return None
        }
      _ => return None
    }
  }
  let scale = match exp_coeff {
    Some(v) => v
    None => return None
  }
  if !expr_same_simplified(
      ei_coeff.unwrap_or(expr_zero()),
      expr_mul(expr_neg_one(), scale),
    ) {
    return None
  }
  let a = expr_simplify(expr_pow(scale, expr_int(-1)))
  Some(
    expr_simplify(
      @symspec.heaviside(t) * @symelem.log(expr_add(expr_one(), expr_mul(a, t))),
    ),
  )
}

///|
fn inverse_laplace_atan_term(expr : Expr, s_name : String, t : Expr) -> Expr? {
  match expr_simplify(expr) {
    @symcore.Expr::Function("atan", [inner]) =>
      match parse_scaled_inverse_symbol(inner, s_name) {
        Some(scale) =>
          Some(
            expr_simplify(
              @symspec.heaviside(t) *
              @symelem.sin(expr_mul(scale, t)) *
              expr_pow(t, expr_int(-1)),
            ),
          )
        None => None
      }
    _ => None
  }
}

///|
fn inverse_laplace_sinh_over_t_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (coeff, factors) = split_mul(expr, s_name)
  if !expr_eq(expr_simplify(coeff), expr_rat(1, 2)) || factors.length() != 1 {
    return None
  }
  match factors[0] {
    @symcore.Expr::Function("log", [inner]) =>
      match parse_log_ratio_linear_offsets(inner, s_name) {
        Some((num_offset, den_offset)) =>
          if expr_same_simplified(
              den_offset,
              expr_mul(expr_neg_one(), num_offset),
            ) {
            Some(
              expr_simplify(
                @symspec.heaviside(t) *
                @symelem.sinh(expr_mul(num_offset, t)) *
                expr_pow(t, expr_int(-1)),
              ),
            )
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn inverse_laplace_power_law_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (coeff, factors) = split_mul(expr, s_name)
  if factors.length() == 2 {
    let mut delay : Expr? = None
    let mut power : Expr? = None
    for factor in factors {
      match factor {
        @symcore.Expr::Function("exp", [inner]) =>
          match parse_negative_linear_exp_raw(inner, s_name) {
            Some(v) if delay is None => delay = Some(v)
            _ => return None
          }
        _ =>
          match parse_symbol_negative_power(factor, s_name) {
            Some(v) if power is None => power = Some(v)
            _ => return None
          }
      }
    }
    match (delay, power) {
      (Some(amount), Some(parsed_power)) =>
        return Some(
          expr_simplify(
            @symspec.heaviside(t - amount) *
            expr_mul(
              coeff,
              expr_div(
                expr_pow(t - amount, expr_simplify(parsed_power - expr_one())),
                @symspec.gamma(parsed_power),
              ),
            ),
          ),
        )
      _ => return None
    }
  }
  if factors.length() != 1 {
    return None
  }
  let power = match parse_symbol_negative_power(factors[0], s_name) {
    Some(v) => v
    None => return None
  }
  let exponent = expr_simplify(expr_sub(power, expr_one()))
  Some(
    expr_simplify(
      @symspec.heaviside(t) *
      expr_mul(coeff, expr_div(expr_pow(t, exponent), @symspec.gamma(power))),
    ),
  )
}

///|
fn inverse_laplace_generic_head_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  match inverse_laplace_generic_head_core(expr_simplify(expr), s_name, t) {
    Some(v) => Some(v)
    None =>
      match expr_simplify(expr) {
        @symcore.Expr::Mul(args) => {
          let t_name = match symbol_name(t) {
            Some(v) => v
            None => return None
          }
          let mut delay : Expr? = None
          let mut exp_const = expr_zero()
          let rest : Array[Expr] = []
          for factor in args {
            match factor {
              @symcore.Expr::Function("exp", [inner]) =>
                match linear_coeffs(inner, s_name) {
                  Some((coeff, offset)) =>
                    match extract_explicit_negative_factor(coeff) {
                      Some(amount) =>
                        if delay is None {
                          delay = Some(amount)
                          exp_const = offset
                        } else {
                          return None
                        }
                      None => rest.push(factor)
                    }
                  _ => rest.push(factor)
                }
              _ => rest.push(factor)
            }
          }
          match delay {
            Some(amount) => {
              let reduced = expr_simplify(
                expr_mul(@symelem.exp(exp_const), factors_expr(rest)),
              )
              match inverse_laplace_generic_head_core(reduced, s_name, t) {
                Some(base) =>
                  Some(expr_simplify(subst_symbol(base, t_name, t - amount)))
                None => None
              }
            }
            None => None
          }
        }
        _ => None
      }
  }
}

///|
fn inverse_laplace_generic_head_core(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (coeff, factors) = split_mul(expr, s_name)
  if factors.length() != 1 {
    return None
  }
  match inverse_laplace_generic_head_factor(factors[0], s_name, t) {
    Some(v) => Some(expr_simplify(coeff * v))
    None => None
  }
}

///|
fn inverse_laplace_generic_head_factor(
  factor : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  match factor {
    @symcore.Expr::Function(name, [arg]) =>
      inverse_laplace_generic_function_term(name, arg, s_name, t)
    _ =>
      match @symcore.derivative_parts(factor) {
        Some((inner, deriv_args)) => {
          let args : Array[Expr] = [inner]
          for arg in deriv_args {
            args.push(arg)
          }
          inverse_laplace_generic_derivative_term(args, s_name, t)
        }
        None => None
      }
  }
}

///|
fn inverse_laplace_generic_function_term(
  name : String,
  arg : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  match linear_coeffs(arg, s_name) {
    Some((coeff, offset)) if expr_is_one(coeff) => {
      let base = @symcore.raw_function("InverseLaplaceTransform", [
        @symcore.raw_function(name, [@symcore.symbol(s_name)]),
        @symcore.symbol(s_name),
        t,
      ])
      if expr_is_zero(offset) {
        Some(base)
      } else {
        Some(expr_simplify(@symelem.exp(offset * t) * base))
      }
    }
    _ => None
  }
}

///|
fn inverse_laplace_generic_derivative_term(
  args : Array[Expr],
  s_name : String,
  t : Expr,
) -> Expr? {
  let order = match inverse_laplace_generic_derivative_order(args, s_name) {
    Some(v) if v > 0 => v
    _ => return None
  }
  let base = match inverse_laplace_generic_head_factor(args[0], s_name, t) {
    Some(v) => v
    None => return None
  }
  let sign = if order % 2 == 0 { expr_one() } else { expr_neg_one() }
  Some(expr_simplify(sign * (t ^ expr_int(order)) * base))
}

///|
fn inverse_laplace_generic_derivative_order(
  args : Array[Expr],
  s_name : String,
) -> Int? {
  if args.length() < 2 {
    return None
  }
  let mut order = 0
  for idx in 1..<args.length() {
    match args[idx] {
      @symcore.Expr::Symbol(name) if name == s_name => order += 1
      @symcore.Expr::Number(_) if idx > 1 =>
        match args[idx - 1] {
          @symcore.Expr::Symbol(name) if name == s_name =>
            match expr_is_int_value(args[idx]) {
              Some(v) if v > 0 => order += v - 1
              _ => return None
            }
          _ => return None
        }
      _ => return None
    }
  }
  Some(order)
}

///|
fn inverse_laplace_bessel_branch_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let factors = match expr_simplify(expr) {
    @symcore.Expr::Mul(args) => args
    _ => return None
  }
  let mut coeff = expr_one()
  let mut order : Expr? = None
  let mut kernel_sq : Expr? = None
  let mut is_diff : Bool? = None
  for factor in factors {
    match parse_reciprocal_sqrt_quadratic(factor, s_name) {
      Some(constant) =>
        match extract_explicit_negative_factor(constant) {
          Some(pos_constant) =>
            if kernel_sq is None {
              kernel_sq = Some(pos_constant)
              is_diff = Some(true)
            } else {
              return None
            }
          None =>
            if kernel_sq is None {
              kernel_sq = Some(constant)
              is_diff = Some(false)
            } else {
              return None
            }
        }
      None =>
        match parse_general_negative_power_base(factor) {
          Some((base, parsed_order)) =>
            match parse_symbol_plus_sqrt_quadratic(base, s_name) {
              Some((branch_kernel_sq, branch_is_diff)) =>
                if order is None && kernel_sq is None {
                  order = Some(parsed_order)
                  kernel_sq = Some(branch_kernel_sq)
                  is_diff = Some(branch_is_diff)
                } else if order is None {
                  let expected_kernel_sq = kernel_sq.unwrap()
                  let expected_diff = is_diff.unwrap()
                  if expr_same_simplified(branch_kernel_sq, expected_kernel_sq) &&
                    branch_is_diff == expected_diff {
                    order = Some(parsed_order)
                  } else {
                    return None
                  }
                } else {
                  return None
                }
              None =>
                if expr_depends_on(factor, s_name) {
                  return None
                } else {
                  coeff = expr_mul(coeff, factor)
                }
            }
          None =>
            if expr_depends_on(factor, s_name) {
              return None
            } else {
              coeff = expr_mul(coeff, factor)
            }
        }
    }
  }
  let parsed_order = match order {
    Some(v) => v
    None => return None
  }
  let parsed_kernel_sq = match kernel_sq {
    Some(v) => v
    None => return None
  }
  let parsed_is_diff = match is_diff {
    Some(v) => v
    None => return None
  }
  let kernel = match parse_coeff_power_with_order(coeff, parsed_order) {
    Some(v) if expr_same_simplified(expr_mul(v, v), parsed_kernel_sq) => v
    _ => return None
  }
  let arg = expr_mul(kernel, t)
  Some(
    expr_simplify(
      @symspec.heaviside(t) *
      (if parsed_is_diff {
        @symspec.besseli(parsed_order, arg)
      } else {
        @symspec.besselj(parsed_order, arg)
      }),
    ),
  )
}

///|
fn inverse_laplace_square_over_quadratic_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  let (coeff, num_var_opt) = split_mul_factor(num, s_name)
  let num_var = match num_var_opt {
    Some(v) => v
    None => return None
  }
  match parse_pure_symbol_positive_int_power(num_var, s_name) {
    Some(2) => ()
    _ => return None
  }
  let coeffs = match poly_coeffs_upto2(expr_simplify(den), s_name) {
    Some(v) => v
    None => return None
  }
  if !expr_is_zero(coeffs[1]) ||
    expr_depends_on(coeffs[0], s_name) ||
    expr_depends_on(coeffs[2], s_name) ||
    expr_is_zero(coeffs[2]) {
    return None
  }
  let lead = coeffs[2]
  let delta_coeff = expr_div(coeff, lead)
  let ratio = expr_div(coeffs[0], lead)
  let wave = if expr_is_negative(ratio) {
    let freq = expr_sqrt_positive(expr_mul(expr_neg_one(), ratio))
    expr_mul(
      expr_div(expr_mul(coeff, freq), lead),
      @symelem.sinh(expr_mul(freq, t)),
    )
  } else {
    let freq = expr_sqrt_positive(ratio)
    expr_mul(
      expr_div(expr_mul(expr_neg_one(), expr_mul(coeff, freq)), lead),
      @symelem.sin(expr_mul(freq, t)),
    )
  }
  Some(
    expr_simplify(
      delta_coeff * @symcore.raw_function("DiracDelta", [t]) +
      @symspec.heaviside(t) * wave,
    ),
  )
}

///|
fn inverse_laplace_irrational_algebraic_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  match inverse_laplace_reciprocal_sqrt_quadratic_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    inverse_laplace_reciprocal_sqrt_linear_plus_const_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_s_over_scaled_sqrt_linear_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    inverse_laplace_sqrt_linear_over_s_pow_three_halves_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_scaled_sqrt_ratio_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    inverse_laplace_sqrt_over_sqrt_linear_shifted_linear_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    inverse_laplace_reciprocal_sqrt_sqrt_linear_shifted_linear_term(
      expr, s_name, t,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_shifted_sqrt_over_linear_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_sqrt_linear_power_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    inverse_laplace_reciprocal_sqrt_times_sqrt_linear_plus_const_term(
      expr, s_name, t,
    ) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_reciprocal_sqrt_shifted_over_s_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    inverse_laplace_reciprocal_sqrt_shifted_linear_over_s_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  inverse_laplace_reciprocal_sqrt_shifted_linear_term(expr, s_name, t)
}

///|
fn inverse_laplace_reciprocal_sqrt_quadratic_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  match parse_reciprocal_sqrt_quadratic(expr, s_name) {
    Some(constant) =>
      if expr_is_zero(constant) {
        None
      } else {
        match extract_explicit_negative_factor(constant) {
          Some(pos_constant) =>
            Some(
              expr_simplify(
                @symspec.heaviside(t) *
                @symspec.besseli(
                  expr_zero(),
                  expr_mul(preferred_positive_sqrt(pos_constant), t),
                ),
              ),
            )
          None =>
            Some(
              expr_simplify(
                @symspec.heaviside(t) *
                @symspec.besselj(
                  expr_zero(),
                  expr_mul(preferred_positive_sqrt(constant), t),
                ),
              ),
            )
        }
      }
    None => None
  }
}

///|
fn inverse_laplace_reciprocal_sqrt_linear_plus_const_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  if !(num.length() == 0 || (num.length() == 1 && expr_is_one(num[0]))) {
    return None
  }
  match parse_sqrt_affine_plus_const(den, s_name) {
    Some((scale, offset, constant)) =>
      if expr_is_zero(scale) || !expr_is_zero(offset) {
        None
      } else {
        let sqrt_scale = preferred_positive_sqrt(scale)
        let sqrt_t = @symelem.sqrt(t)
        Some(
          expr_simplify(
            @symspec.heaviside(t) *
            (
              expr_div(
                expr_one(),
                expr_mul(sqrt_pi(), expr_mul(sqrt_scale, sqrt_t)),
              ) +
              expr_mul(
                expr_mul(expr_neg_one(), expr_div(constant, scale)),
                expr_mul(
                  @symelem.exp(
                    expr_div(
                      expr_mul(expr_pow(constant, expr_int(2)), t),
                      scale,
                    ),
                  ),
                  @symspec.erfc(
                    expr_div(expr_mul(constant, sqrt_t), sqrt_scale),
                  ),
                ),
              )
            ),
          ),
        )
      }
    None => None
  }
}

///|
fn inverse_laplace_s_over_scaled_sqrt_linear_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  let numerator = factors_expr(num)
  let factors = match expr_simplify(den) {
    @symcore.Expr::Mul(args) if args.length() == 2 => args
    _ => return None
  }
  let mut saw_s = false
  let mut scale : Expr? = None
  let mut constant : Expr? = None
  for factor in factors {
    match split_linear_power_denom(factor, s_name) {
      Some((coeff, offset, 1)) =>
        if expr_same_simplified(coeff, expr_one()) && expr_is_zero(offset) {
          saw_s = true
        } else {
          return None
        }
      _ =>
        match parse_scaled_sqrt_linear_plus_const(factor, s_name) {
          Some((parsed_scale, parsed_const)) =>
            if scale is None {
              scale = Some(parsed_scale)
              constant = Some(parsed_const)
            } else {
              return None
            }
          None => return None
        }
    }
  }
  let parsed_scale = match scale {
    Some(v) if saw_s && !expr_is_zero(v) => v
    _ => return None
  }
  let parsed_const = match constant {
    Some(v) if expr_same_simplified(v, numerator) => v
    _ => return None
  }
  let sqrt_t = @symelem.sqrt(t)
  let scaled_term = expr_mul(
    @symelem.exp(
      expr_div(
        expr_mul(expr_pow(parsed_const, expr_int(2)), t),
        expr_pow(parsed_scale, expr_int(2)),
      ),
    ),
    @symspec.erfc(expr_div(expr_mul(parsed_const, sqrt_t), parsed_scale)),
  )
  Some(
    expr_simplify(
      @symspec.heaviside(t) *
      expr_add(expr_one(), expr_mul(expr_neg_one(), scaled_term)),
    ),
  )
}

///|
fn inverse_laplace_sqrt_linear_over_s_pow_three_halves_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  let numerator = factors_expr(num)
  let factors = match expr_simplify(den) {
    @symcore.Expr::Mul(args) if args.length() == 3 => args
    _ => return None
  }
  let mut saw_s = false
  let mut saw_sqrt_s = false
  let mut constant : Expr? = None
  for factor in factors {
    match split_linear_power_denom(factor, s_name) {
      Some((coeff, offset, 1)) =>
        if expr_same_simplified(coeff, expr_one()) &&
          expr_is_zero(offset) &&
          !saw_s {
          saw_s = true
        } else {
          return None
        }
      _ =>
        match parse_sqrt_linear(factor, s_name) {
          Some(scale) if expr_same_simplified(scale, expr_one()) && !saw_sqrt_s =>
            saw_sqrt_s = true
          _ =>
            match parse_scaled_sqrt_linear_plus_const(factor, s_name) {
              Some((scale, parsed_const)) =>
                if expr_same_simplified(scale, expr_one()) && constant is None {
                  constant = Some(parsed_const)
                } else {
                  return None
                }
              None => return None
            }
        }
    }
  }
  let parsed_const = match constant {
    Some(v) if saw_s && saw_sqrt_s => v
    _ => return None
  }
  let scale_factor = expr_simplify(
    expr_div(numerator, expr_pow(parsed_const, expr_int(2))),
  )
  let sqrt_t = @symelem.sqrt(t)
  let c2t = expr_mul(expr_pow(parsed_const, expr_int(2)), t)
  Some(
    expr_simplify(
      scale_factor *
      (
        @symspec.heaviside(t) *
        expr_add(
          expr_add(
            expr_div(
              expr_mul(expr_int(2), expr_mul(parsed_const, sqrt_t)),
              sqrt_pi(),
            ),
            expr_mul(
              @symelem.exp(c2t),
              @symspec.erfc(expr_mul(parsed_const, sqrt_t)),
            ),
          ),
          expr_neg_one(),
        )
      ),
    ),
  )
}

///|
fn inverse_laplace_scaled_sqrt_ratio_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  let numerator = factors_expr(num)
  let factors = match expr_simplify(den) {
    @symcore.Expr::Mul(args) if args.length() == 2 => args
    _ => return None
  }
  let mut saw_s = false
  let mut scale : Expr? = None
  let mut constant : Expr? = None
  for factor in factors {
    match split_linear_power_denom(factor, s_name) {
      Some((coeff, offset, 1)) =>
        if expr_same_simplified(coeff, expr_one()) && expr_is_zero(offset) {
          saw_s = true
        } else {
          return None
        }
      _ =>
        match parse_scaled_sqrt_linear_plus_const(factor, s_name) {
          Some((parsed_scale, parsed_const)) =>
            if scale is None {
              scale = Some(parsed_scale)
              constant = Some(parsed_const)
            } else {
              return None
            }
          None => return None
        }
    }
  }
  let parsed_scale = match scale {
    Some(v) if saw_s && !expr_is_zero(v) => v
    _ => return None
  }
  let parsed_const = match constant {
    Some(v) => v
    None => return None
  }
  match parse_scaled_sqrt_linear_plus_const(numerator, s_name) {
    Some((num_scale, num_const)) =>
      if expr_same_simplified(num_scale, parsed_scale) &&
        expr_same_simplified(num_const, expr_mul(expr_neg_one(), parsed_const)) {
        let sqrt_t = @symelem.sqrt(t)
        let scaled_term = expr_mul(
          @symelem.exp(
            expr_div(
              expr_mul(expr_pow(parsed_const, expr_int(2)), t),
              expr_pow(parsed_scale, expr_int(2)),
            ),
          ),
          @symspec.erfc(expr_div(expr_mul(parsed_const, sqrt_t), parsed_scale)),
        )
        Some(
          expr_simplify(
            @symspec.heaviside(t) *
            expr_add(expr_mul(expr_int(2), scaled_term), expr_neg_one()),
          ),
        )
      } else {
        None
      }
    _ => None
  }
}

///|
fn inverse_laplace_sqrt_over_sqrt_linear_shifted_linear_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  let numerator = factors_expr(num)
  let numerator_coeff = match parse_sqrt_linear(numerator, s_name) {
    Some(v) => v
    None => return None
  }
  let factors = match expr_simplify(den) {
    @symcore.Expr::Mul(args) if args.length() == 2 => args
    _ => return None
  }
  let mut alpha : Expr? = None
  let mut beta_sq : Expr? = None
  for factor in factors {
    match parse_scaled_sqrt_linear_plus_const(factor, s_name) {
      Some((scale, parsed_const)) =>
        if expr_same_simplified(scale, expr_one()) && alpha is None {
          alpha = Some(parsed_const)
        } else {
          return None
        }
      None =>
        match split_linear_power_denom(factor, s_name) {
          Some((coeff, offset, 1)) if expr_same_simplified(coeff, expr_one()) =>
            match extract_explicit_negative_factor(offset) {
              Some(v) if beta_sq is None => beta_sq = Some(v)
              _ => return None
            }
          _ => return None
        }
    }
  }
  let parsed_alpha = match alpha {
    Some(v) => v
    None => return None
  }
  let parsed_beta_sq = match beta_sq {
    Some(v) => v
    None => return None
  }
  let parsed_alpha_sq = expr_simplify(expr_mul(parsed_alpha, parsed_alpha))
  let scale_factor = expr_simplify(
    expr_div(numerator_coeff, expr_sub(parsed_alpha_sq, parsed_beta_sq)),
  )
  let parsed_beta = preferred_positive_sqrt(parsed_beta_sq)
  let sqrt_t = @symelem.sqrt(t)
  Some(
    expr_simplify(
      scale_factor *
      (
        @symspec.heaviside(t) *
        expr_add(
          expr_add(
            expr_mul(
              expr_mul(parsed_alpha, parsed_beta),
              expr_mul(
                @symelem.exp(expr_mul(parsed_beta_sq, t)),
                @symspec.erfc(expr_mul(parsed_beta, sqrt_t)),
              ),
            ),
            expr_mul(
              parsed_alpha_sq,
              expr_mul(
                @symelem.exp(expr_mul(parsed_alpha_sq, t)),
                @symspec.erfc(expr_mul(parsed_alpha, sqrt_t)),
              ),
            ),
          ),
          expr_mul(
            expr_neg_one(),
            expr_mul(parsed_beta_sq, @symelem.exp(expr_mul(parsed_beta_sq, t))),
          ),
        )
      ),
    ),
  )
}

///|
fn inverse_laplace_reciprocal_sqrt_sqrt_linear_shifted_linear_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  let numerator = factors_expr(num)
  let factors = match expr_simplify(den) {
    @symcore.Expr::Mul(args) if args.length() == 3 => args
    _ => return None
  }
  let mut alpha : Expr? = None
  let mut beta_sq : Expr? = None
  let mut saw_sqrt_s = false
  for factor in factors {
    match parse_scaled_sqrt_linear_plus_const(factor, s_name) {
      Some((scale, parsed_const)) =>
        if expr_same_simplified(scale, expr_one()) && alpha is None {
          alpha = Some(parsed_const)
        } else {
          return None
        }
      None =>
        match parse_sqrt_linear(factor, s_name) {
          Some(scale) if expr_same_simplified(scale, expr_one()) && !saw_sqrt_s =>
            saw_sqrt_s = true
          _ =>
            match split_linear_power_denom(factor, s_name) {
              Some((coeff, offset, 1)) if expr_same_simplified(
                  coeff,
                  expr_one(),
                ) =>
                match extract_explicit_negative_factor(offset) {
                  Some(v) if beta_sq is None => beta_sq = Some(v)
                  _ => return None
                }
              _ => return None
            }
        }
    }
  }
  let parsed_alpha = match alpha {
    Some(v) if saw_sqrt_s => v
    _ => return None
  }
  let parsed_beta_sq = match beta_sq {
    Some(v) => v
    None => return None
  }
  let parsed_alpha_sq = expr_simplify(expr_mul(parsed_alpha, parsed_alpha))
  let parsed_beta = preferred_positive_sqrt(parsed_beta_sq)
  let scale_factor = expr_simplify(
    expr_div(
      numerator,
      expr_mul(expr_sub(parsed_alpha_sq, parsed_beta_sq), parsed_beta),
    ),
  )
  let sqrt_t = @symelem.sqrt(t)
  Some(
    expr_simplify(
      scale_factor *
      (
        @symspec.heaviside(t) *
        expr_add(
          expr_add(
            expr_mul(
              parsed_alpha,
              expr_mul(
                @symelem.exp(expr_mul(parsed_beta_sq, t)),
                @symspec.erf(expr_mul(parsed_beta, sqrt_t)),
              ),
            ),
            expr_mul(
              parsed_beta,
              expr_mul(
                @symelem.exp(expr_mul(parsed_alpha_sq, t)),
                @symspec.erfc(expr_mul(parsed_alpha, sqrt_t)),
              ),
            ),
          ),
          expr_mul(
            expr_neg_one(),
            expr_mul(parsed_beta, @symelem.exp(expr_mul(parsed_beta_sq, t))),
          ),
        )
      ),
    ),
  )
}

///|
fn inverse_laplace_shifted_sqrt_over_linear_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  let numerator = factors_expr(num)
  let (num_scale, num_offset) = match parse_sqrt_affine(numerator, s_name) {
    Some(v) => v
    None => return None
  }
  if !expr_same_simplified(num_scale, expr_one()) {
    return None
  }
  match split_linear_power_denom(den, s_name) {
    Some((coeff, offset, 1)) => {
      if !expr_same_simplified(coeff, expr_one()) ||
        expr_depends_on(offset, s_name) {
        return None
      }
      let diff = expr_simplify(expr_sub(num_offset, offset))
      let sqrt_t = @symelem.sqrt(t)
      Some(
        expr_simplify(
          @symspec.heaviside(t) *
          expr_add(
            expr_mul(
              @symelem.exp(expr_mul(expr_neg_one(), expr_mul(num_offset, t))),
              expr_div(expr_one(), expr_mul(sqrt_pi(), sqrt_t)),
            ),
            expr_mul(
              preferred_positive_sqrt(diff),
              expr_mul(
                @symelem.exp(expr_mul(expr_neg_one(), expr_mul(offset, t))),
                @symspec.erf(expr_mul(preferred_positive_sqrt(diff), sqrt_t)),
              ),
            ),
          ),
        ),
      )
    }
    _ => None
  }
}

///|
fn inverse_laplace_sqrt_linear_power_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  let numerator = factors_expr(num)
  let unit_numerator = num.length() == 0 ||
    (num.length() == 1 && expr_is_one(num[0]))
  match parse_scaled_sqrt_linear_plus_const_power(den, s_name) {
    Some((scale, constant, 2)) =>
      if unit_numerator && expr_same_simplified(scale, expr_one()) {
        return inverse_laplace_sqrt_linear_squared_family(constant, t)
      }
    Some((scale, constant, 3)) =>
      if unit_numerator && expr_same_simplified(scale, expr_one()) {
        return inverse_laplace_sqrt_linear_cubed_family(constant, t)
      }
    Some((scale, constant, 4)) =>
      if expr_same_simplified(scale, expr_one()) &&
        !expr_depends_on(numerator, s_name) {
        return match inverse_laplace_sqrt_linear_quartic_family(constant, t) {
          Some(value) => Some(expr_simplify(numerator * value))
          None => None
        }
      }
    _ => ()
  }
  match parse_scaled_sqrt_linear_plus_const_power(den, s_name) {
    Some((scale, constant, 3)) if expr_same_simplified(scale, expr_one()) =>
      match parse_sqrt_linear(numerator, s_name) {
        Some(num_scale) if expr_same_simplified(num_scale, expr_one()) =>
          return inverse_laplace_sqrt_over_sqrt_linear_cubed_family(constant, t)
        _ => ()
      }
    _ => ()
  }
  let factors = match expr_simplify(den) {
    @symcore.Expr::Mul(args) if args.length() == 2 => args
    _ => return None
  }
  let mut power_info : (Expr, Int)? = None
  let mut saw_s = false
  let mut saw_sqrt_s = false
  for factor in factors {
    match parse_scaled_sqrt_linear_plus_const_power(factor, s_name) {
      Some((scale, constant, power)) =>
        if expr_same_simplified(scale, expr_one()) && power_info is None {
          power_info = Some((constant, power))
        } else {
          return None
        }
      None =>
        match split_linear_power_denom(factor, s_name) {
          Some((coeff, offset, 1)) =>
            if expr_same_simplified(coeff, expr_one()) && expr_is_zero(offset) {
              saw_s = true
            } else {
              return None
            }
          _ =>
            match parse_sqrt_linear(factor, s_name) {
              Some(scale) if expr_same_simplified(scale, expr_one()) =>
                saw_sqrt_s = true
              _ => return None
            }
        }
    }
  }
  match power_info {
    Some((constant, 2)) =>
      if saw_s {
        match parse_scaled_sqrt_linear_plus_const_power(numerator, s_name) {
          Some((num_scale, num_const, 2)) =>
            if expr_same_simplified(num_scale, expr_one()) &&
              expr_same_simplified(
                num_const,
                expr_mul(expr_neg_one(), constant),
              ) {
              inverse_laplace_scaled_sqrt_ratio_squared_family(constant, t)
            } else if unit_numerator {
              inverse_laplace_sqrt_linear_squared_over_s_family(constant, t)
            } else {
              None
            }
          Some((num_scale, num_const, 3)) =>
            if expr_same_simplified(num_scale, expr_one()) &&
              expr_same_simplified(
                num_const,
                expr_mul(expr_neg_one(), constant),
              ) {
              inverse_laplace_scaled_sqrt_ratio_cubed_family(constant, t)
            } else if unit_numerator {
              inverse_laplace_sqrt_linear_squared_over_s_family(constant, t)
            } else {
              None
            }
          _ =>
            if unit_numerator {
              inverse_laplace_sqrt_linear_squared_over_s_family(constant, t)
            } else {
              None
            }
        }
      } else if saw_sqrt_s && unit_numerator {
        inverse_laplace_sqrt_linear_squared_over_sqrt_family(constant, t)
      } else {
        None
      }
    Some((constant, 3)) =>
      if saw_s {
        match parse_scaled_sqrt_linear_plus_const_power(numerator, s_name) {
          Some((num_scale, num_const, 3)) =>
            if expr_same_simplified(num_scale, expr_one()) &&
              expr_same_simplified(
                num_const,
                expr_mul(expr_neg_one(), constant),
              ) {
              inverse_laplace_scaled_sqrt_ratio_cubed_family(constant, t)
            } else {
              None
            }
          _ => None
        }
      } else if saw_sqrt_s && unit_numerator {
        inverse_laplace_sqrt_linear_cubed_over_sqrt_family(constant, t)
      } else {
        None
      }
    _ => None
  }
}

///|
fn inverse_laplace_sqrt_linear_squared_family(
  constant : Expr,
  t : Expr,
) -> Expr? {
  let sqrt_t = @symelem.sqrt(t)
  let c2t = expr_mul(expr_pow(constant, expr_int(2)), t)
  Some(
    expr_simplify(
      @symspec.heaviside(t) *
      expr_add(
        expr_one(),
        expr_add(
          expr_mul(
            expr_sub(expr_one(), expr_mul(expr_int(2), c2t)),
            expr_mul(
              expr_add(@symspec.erf(expr_mul(constant, sqrt_t)), expr_neg_one()),
              @symelem.exp(c2t),
            ),
          ),
          expr_mul(
            expr_neg_one(),
            expr_div(
              expr_mul(expr_int(2), expr_mul(constant, sqrt_t)),
              sqrt_pi(),
            ),
          ),
        ),
      ),
    ),
  )
}

///|
fn inverse_laplace_scaled_sqrt_ratio_squared_family(
  constant : Expr,
  t : Expr,
) -> Expr? {
  let sqrt_t = @symelem.sqrt(t)
  let c2t = expr_mul(expr_pow(constant, expr_int(2)), t)
  Some(
    expr_simplify(
      @symspec.heaviside(t) *
      expr_add(
        expr_one(),
        expr_add(
          expr_mul(
            expr_int(8),
            expr_mul(
              c2t,
              expr_mul(
                @symelem.exp(c2t),
                @symspec.erfc(expr_mul(constant, sqrt_t)),
              ),
            ),
          ),
          expr_mul(
            expr_neg_one(),
            expr_div(
              expr_mul(expr_int(8), expr_mul(constant, sqrt_t)),
              sqrt_pi(),
            ),
          ),
        ),
      ),
    ),
  )
}

///|
fn inverse_laplace_scaled_sqrt_ratio_cubed_family(
  constant : Expr,
  t : Expr,
) -> Expr? {
  let sqrt_t = @symelem.sqrt(t)
  let c2 = expr_pow(constant, expr_int(2))
  let c2t = expr_mul(c2, t)
  let e_term = expr_mul(
    @symelem.exp(c2t),
    @symspec.erfc(expr_mul(constant, sqrt_t)),
  )
  Some(
    expr_simplify(
      @symspec.heaviside(t) *
      expr_add(
        expr_add(
          expr_mul(
            expr_int(2),
            expr_mul(
              expr_add(
                expr_mul(
                  expr_int(8),
                  expr_mul(expr_pow(c2, expr_int(2)), expr_pow(t, expr_int(2))),
                ),
                expr_add(expr_mul(expr_int(8), c2t), expr_one()),
              ),
              e_term,
            ),
          ),
          expr_mul(
            expr_neg_one(),
            expr_div(
              expr_mul(
                expr_int(8),
                expr_mul(
                  constant,
                  expr_mul(
                    sqrt_t,
                    expr_add(expr_mul(expr_int(2), c2t), expr_one()),
                  ),
                ),
              ),
              sqrt_pi(),
            ),
          ),
        ),
        expr_neg_one(),
      ),
    ),
  )
}

///|
fn inverse_laplace_sqrt_linear_squared_over_s_family(
  constant : Expr,
  t : Expr,
) -> Expr? {
  if expr_is_zero(constant) {
    return None
  }
  let sqrt_t = @symelem.sqrt(t)
  let c2 = expr_pow(constant, expr_int(2))
  let c2t = expr_mul(c2, t)
  let e_term = expr_mul(
    @symelem.exp(c2t),
    @symspec.erfc(expr_mul(constant, sqrt_t)),
  )
  Some(
    expr_simplify(
      @symspec.heaviside(t) *
      expr_add(
        expr_add(
          expr_mul(
            expr_add(
              expr_mul(expr_int(2), t),
              expr_mul(expr_neg_one(), expr_pow(c2, expr_int(-1))),
            ),
            e_term,
          ),
          expr_pow(c2, expr_int(-1)),
        ),
        expr_mul(
          expr_neg_one(),
          expr_div(expr_mul(expr_int(2), sqrt_t), expr_mul(sqrt_pi(), constant)),
        ),
      ),
    ),
  )
}

///|
fn inverse_laplace_sqrt_linear_squared_over_sqrt_family(
  constant : Expr,
  t : Expr,
) -> Expr? {
  let sqrt_t = @symelem.sqrt(t)
  let e_term = expr_mul(
    @symelem.exp(expr_mul(expr_pow(constant, expr_int(2)), t)),
    @symspec.erfc(expr_mul(constant, sqrt_t)),
  )
  Some(
    expr_simplify(
      @symspec.heaviside(t) *
      expr_add(
        expr_mul(
          expr_neg_one(),
          expr_mul(expr_int(2), expr_mul(constant, expr_mul(t, e_term))),
        ),
        expr_div(expr_mul(expr_int(2), sqrt_t), sqrt_pi()),
      ),
    ),
  )
}

///|
fn inverse_laplace_sqrt_linear_cubed_family(constant : Expr, t : Expr) -> Expr? {
  let sqrt_t = @symelem.sqrt(t)
  let c2 = expr_pow(constant, expr_int(2))
  let c2t = expr_mul(c2, t)
  let e_term = expr_mul(
    @symelem.exp(c2t),
    @symspec.erfc(expr_mul(constant, sqrt_t)),
  )
  Some(
    expr_simplify(
      @symspec.heaviside(t) *
      expr_add(
        expr_mul(
          expr_neg_one(),
          expr_mul(
            expr_mul(constant, t),
            expr_mul(expr_add(expr_mul(expr_int(2), c2t), expr_int(3)), e_term),
          ),
        ),
        expr_div(
          expr_mul(expr_int(2), expr_mul(sqrt_t, expr_add(c2t, expr_one()))),
          sqrt_pi(),
        ),
      ),
    ),
  )
}

///|
fn inverse_laplace_sqrt_linear_quartic_family(
  constant : Expr,
  t : Expr,
) -> Expr? {
  let sqrt_t = @symelem.sqrt(t)
  let c2 = expr_pow(constant, expr_int(2))
  let c2t = expr_mul(c2, t)
  let c4 = expr_pow(constant, expr_int(4))
  let t2 = expr_pow(t, expr_int(2))
  let t2_sqrt_t = expr_mul(t2, sqrt_t)
  let e_term = expr_mul(
    @symelem.exp(c2t),
    @symspec.erfc(expr_mul(constant, sqrt_t)),
  )
  let poly = expr_add(
    expr_add(
      expr_mul(expr_int(4), expr_mul(c4, t2)),
      expr_mul(expr_int(12), c2t),
    ),
    expr_int(3),
  )
  Some(
    expr_simplify(
      @symspec.heaviside(t) *
      expr_add(
        expr_div(expr_mul(t, expr_mul(poly, e_term)), expr_int(3)),
        expr_mul(
          expr_neg_one(),
          expr_div(
            expr_mul(
              expr_int(2),
              expr_mul(
                expr_pow(constant, expr_int(3)),
                expr_mul(
                  t2_sqrt_t,
                  expr_add(expr_mul(expr_int(2), c2t), expr_int(5)),
                ),
              ),
            ),
            expr_mul(expr_int(3), sqrt_pi()),
          ),
        ),
      ),
    ),
  )
}

///|
fn inverse_laplace_sqrt_linear_cubed_over_sqrt_family(
  constant : Expr,
  t : Expr,
) -> Expr? {
  if expr_is_zero(constant) {
    return None
  }
  let sqrt_t = @symelem.sqrt(t)
  let c2t = expr_mul(expr_pow(constant, expr_int(2)), t)
  let e_term = expr_mul(
    @symelem.exp(c2t),
    @symspec.erfc(expr_mul(constant, sqrt_t)),
  )
  let scaled_erfc = expr_sub(
    expr_mul(sqrt_pi(), expr_mul(constant, expr_mul(sqrt_t, e_term))),
    expr_one(),
  )
  Some(
    expr_simplify(
      @symspec.heaviside(t) *
      expr_div(
        expr_mul(
          sqrt_t,
          expr_add(
            expr_mul(
              expr_add(expr_mul(expr_int(2), c2t), expr_one()),
              scaled_erfc,
            ),
            expr_one(),
          ),
        ),
        expr_mul(sqrt_pi(), constant),
      ),
    ),
  )
}

///|
fn inverse_laplace_sqrt_over_sqrt_linear_cubed_family(
  constant : Expr,
  t : Expr,
) -> Expr? {
  if expr_is_zero(constant) {
    return None
  }
  let sqrt_t = @symelem.sqrt(t)
  let c2t = expr_mul(expr_pow(constant, expr_int(2)), t)
  let c2t2 = expr_pow(c2t, expr_int(2))
  let e_term = expr_mul(
    @symelem.exp(c2t),
    @symspec.erfc(expr_mul(constant, sqrt_t)),
  )
  let scaled_erfc = expr_sub(
    expr_mul(sqrt_pi(), expr_mul(constant, expr_mul(sqrt_t, e_term))),
    expr_one(),
  )
  Some(
    expr_simplify(
      @symspec.heaviside(t) *
      expr_div(
        expr_add(
          expr_add(
            c2t,
            expr_mul(
              scaled_erfc,
              expr_add(
                expr_add(
                  expr_mul(expr_int(2), c2t2),
                  expr_mul(expr_int(5), c2t),
                ),
                expr_one(),
              ),
            ),
          ),
          expr_one(),
        ),
        expr_mul(sqrt_pi(), expr_mul(constant, sqrt_t)),
      ),
    ),
  )
}

///|
fn inverse_laplace_reciprocal_sqrt_times_sqrt_linear_plus_const_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  if !(num.length() == 0 || (num.length() == 1 && expr_is_one(num[0]))) {
    return None
  }
  let factors = match expr_simplify(den) {
    @symcore.Expr::Mul(args) if args.length() == 2 => args
    _ => return None
  }
  let mut saw_recip_sqrt_s = false
  let mut scale : Expr? = None
  let mut constant : Expr? = None
  for factor in factors {
    match parse_sqrt_affine(factor, s_name) {
      Some((sqrt_scale, offset)) =>
        if expr_is_zero(offset) && expr_same_simplified(sqrt_scale, expr_one()) {
          saw_recip_sqrt_s = true
        } else {
          return None
        }
      None =>
        match parse_sqrt_affine_plus_const(factor, s_name) {
          Some((parsed_scale, offset, parsed_const)) =>
            if expr_is_zero(offset) && scale is None {
              scale = Some(parsed_scale)
              constant = Some(parsed_const)
            } else {
              return None
            }
          None => return None
        }
    }
  }
  let parsed_scale = match scale {
    Some(v) if !expr_is_zero(v) && saw_recip_sqrt_s => v
    _ => return None
  }
  let parsed_const = match constant {
    Some(v) => v
    None => return None
  }
  let sqrt_scale = preferred_positive_sqrt(parsed_scale)
  let sqrt_t = @symelem.sqrt(t)
  Some(
    expr_simplify(
      @symspec.heaviside(t) *
      expr_div(
        expr_mul(
          @symelem.exp(
            expr_div(
              expr_mul(expr_pow(parsed_const, expr_int(2)), t),
              parsed_scale,
            ),
          ),
          @symspec.erfc(expr_div(expr_mul(parsed_const, sqrt_t), sqrt_scale)),
        ),
        sqrt_scale,
      ),
    ),
  )
}

///|
fn inverse_laplace_reciprocal_sqrt_shifted_linear_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  if !(num.length() == 0 || (num.length() == 1 && expr_is_one(num[0]))) {
    return None
  }
  let factors = match expr_simplify(den) {
    @symcore.Expr::Mul(args) if args.length() == 2 => args
    _ => return None
  }
  let mut root_scale : Expr? = None
  let mut root_offset : Expr? = None
  let mut linear_coeff : Expr? = None
  let mut linear_offset : Expr? = None
  for factor in factors {
    match parse_sqrt_affine(factor, s_name) {
      Some((scale, offset)) =>
        if !expr_is_zero(scale) && root_offset is None {
          root_scale = Some(scale)
          root_offset = Some(offset)
        } else {
          return None
        }
      None =>
        match split_linear_power_denom(factor, s_name) {
          Some((coeff, offset, 1)) =>
            if linear_offset is None {
              linear_coeff = Some(coeff)
              linear_offset = Some(offset)
            } else {
              return None
            }
          _ => return None
        }
    }
  }
  let parsed_root_offset = match root_offset {
    Some(v) => v
    None => return None
  }
  let parsed_root_scale = match root_scale {
    Some(v) if !expr_is_zero(v) => v
    _ => return None
  }
  let parsed_linear_coeff = match linear_coeff {
    Some(v) if !expr_is_zero(v) => v
    _ => return None
  }
  let parsed_linear_offset = match linear_offset {
    Some(v) => v
    None => return None
  }
  let normalized_root_offset = expr_simplify(
    expr_div(parsed_root_offset, parsed_root_scale),
  )
  let normalized_linear_offset = expr_simplify(
    expr_div(parsed_linear_offset, parsed_linear_coeff),
  )
  let diff = expr_simplify(
    expr_sub(normalized_root_offset, normalized_linear_offset),
  )
  if expr_is_zero(diff) {
    return None
  }
  let sqrt_diff = preferred_positive_sqrt(diff)
  let sqrt_root_scale = preferred_positive_sqrt(parsed_root_scale)
  let sqrt_t = @symelem.sqrt(t)
  Some(
    expr_simplify(
      @symspec.heaviside(t) *
      expr_mul(
        expr_div(expr_one(), expr_mul(parsed_linear_coeff, sqrt_root_scale)),
        expr_mul(
          @symelem.exp(
            expr_mul(expr_neg_one(), expr_mul(normalized_linear_offset, t)),
          ),
          expr_div(@symspec.erf(expr_mul(sqrt_diff, sqrt_t)), sqrt_diff),
        ),
      ),
    ),
  )
}

///|
fn inverse_laplace_reciprocal_sqrt_shifted_over_s_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  if !(num.length() == 0 || (num.length() == 1 && expr_is_one(num[0]))) {
    return None
  }
  let factors = match expr_simplify(den) {
    @symcore.Expr::Mul(args) if args.length() == 2 => args
    _ => return None
  }
  let mut root_scale : Expr? = None
  let mut root_offset : Expr? = None
  let mut saw_s = false
  for factor in factors {
    match parse_sqrt_affine(factor, s_name) {
      Some((scale, offset)) =>
        if !expr_is_zero(scale) && root_scale is None {
          root_scale = Some(scale)
          root_offset = Some(offset)
        } else {
          return None
        }
      None =>
        match split_linear_power_denom(factor, s_name) {
          Some((coeff, offset, 1)) =>
            if expr_same_simplified(coeff, expr_one()) &&
              expr_is_zero(offset) &&
              !saw_s {
              saw_s = true
            } else {
              return None
            }
          _ => return None
        }
    }
  }
  let parsed_root_scale = match root_scale {
    Some(v) if !expr_is_zero(v) && saw_s => v
    _ => return None
  }
  let parsed_root_offset = match root_offset {
    Some(v) => v
    None => return None
  }
  let sqrt_t = @symelem.sqrt(t)
  let sqrt_scale = preferred_positive_sqrt(parsed_root_scale)
  let body = if expr_is_zero(parsed_root_offset) {
    expr_div(expr_mul(expr_int(2), sqrt_t), expr_mul(sqrt_pi(), sqrt_scale))
  } else {
    let normalized_offset = expr_simplify(
      expr_div(parsed_root_offset, parsed_root_scale),
    )
    let sqrt_offset = preferred_positive_sqrt(normalized_offset)
    expr_div(
      @symspec.erf(expr_mul(sqrt_offset, sqrt_t)),
      expr_mul(sqrt_scale, sqrt_offset),
    )
  }
  Some(expr_simplify(@symspec.heaviside(t) * body))
}

///|
fn inverse_laplace_reciprocal_sqrt_shifted_linear_over_s_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  if !(num.length() == 0 || (num.length() == 1 && expr_is_one(num[0]))) {
    return None
  }
  let factors = match expr_simplify(den) {
    @symcore.Expr::Mul(args) if args.length() == 3 => args
    _ => return None
  }
  let mut root_scale : Expr? = None
  let mut linear_coeff : Expr? = None
  let mut linear_offset : Expr? = None
  let mut saw_s = false
  for factor in factors {
    match parse_sqrt_affine(factor, s_name) {
      Some((scale, offset)) =>
        if expr_is_zero(offset) && !expr_is_zero(scale) && root_scale is None {
          root_scale = Some(scale)
        } else {
          return None
        }
      None =>
        match split_linear_power_denom(factor, s_name) {
          Some((coeff, offset, 1)) =>
            if expr_same_simplified(coeff, expr_one()) &&
              expr_is_zero(offset) &&
              !saw_s {
              saw_s = true
            } else if linear_coeff is None {
              linear_coeff = Some(coeff)
              linear_offset = Some(offset)
            } else {
              return None
            }
          _ => return None
        }
    }
  }
  let parsed_root_scale = match root_scale {
    Some(v) if !expr_is_zero(v) && saw_s => v
    _ => return None
  }
  let parsed_linear_coeff = match linear_coeff {
    Some(v) if !expr_is_zero(v) => v
    _ => return None
  }
  let parsed_linear_offset = match linear_offset {
    Some(v) => v
    None => return None
  }
  let diff = expr_simplify(
    expr_mul(
      expr_neg_one(),
      expr_div(parsed_linear_offset, parsed_linear_coeff),
    ),
  )
  if expr_is_zero(diff) {
    return None
  }
  let sqrt_root_scale = preferred_positive_sqrt(parsed_root_scale)
  let sqrt_diff = preferred_positive_sqrt(diff)
  let sqrt_t = @symelem.sqrt(t)
  let exp_erf_term = expr_div(
    expr_mul(
      @symelem.exp(expr_mul(diff, t)),
      @symspec.erf(expr_mul(sqrt_diff, sqrt_t)),
    ),
    expr_mul(diff, sqrt_diff),
  )
  let sqrt_term = expr_mul(
    expr_neg_one(),
    expr_div(expr_mul(expr_int(2), sqrt_t), expr_mul(sqrt_pi(), diff)),
  )
  Some(
    expr_simplify(
      @symspec.heaviside(t) *
      expr_mul(
        expr_div(expr_one(), expr_mul(parsed_linear_coeff, sqrt_root_scale)),
        expr_add(exp_erf_term, sqrt_term),
      ),
    ),
  )
}

///|
fn matches_log_one_plus_linear(expr : Expr, s_name : String) -> Bool {
  match expr_simplify(expr) {
    @symcore.Expr::Function("log", [inner]) =>
      match linear_coeffs(inner, s_name) {
        Some((coeff, offset)) => expr_is_one(coeff) && expr_is_one(offset)
        None => false
      }
    _ => false
  }
}

///|
fn parse_scaled_inverse_symbol(expr : Expr, var_name : String) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  if !expr_eq(den, @symcore.symbol(var_name)) {
    return None
  }
  let numerator = factors_expr(num)
  if expr_depends_on(numerator, var_name) {
    None
  } else {
    Some(numerator)
  }
}

///|
fn parse_symbol_negative_power(expr : Expr, var_name : String) -> Expr? {
  match expr_simplify(expr) {
    @symcore.Expr::Pow(@symcore.Expr::Symbol(name), power) if name == var_name =>
      extract_explicit_negative_factor(power)
    _ => None
  }
}

///|
fn parse_general_negative_power_base(expr : Expr) -> (Expr, Expr)? {
  match expr_simplify(expr) {
    @symcore.Expr::Pow(base, power) =>
      match extract_explicit_negative_factor(power) {
        Some(v) => Some((base, v))
        None => None
      }
    _ => None
  }
}

///|
fn parse_pure_symbol_positive_int_power(expr : Expr, var_name : String) -> Int? {
  let (_, factors) = split_mul(expr, var_name)
  if factors.length() == 0 {
    return None
  }
  let mut total = 0
  for factor in factors {
    match parse_power_factor(factor, var_name) {
      Some(power) =>
        match expr_is_int_value(power) {
          Some(n) if n > 0 => total += n
          _ => return None
        }
      None => return None
    }
  }
  if total > 0 {
    Some(total)
  } else {
    None
  }
}

///|
fn parse_coeff_power_with_order(coeff : Expr, order : Expr) -> Expr? {
  match expr_simplify(coeff) {
    @symcore.Expr::Pow(base, exp) if expr_same_simplified(exp, order) =>
      Some(base)
    _ => None
  }
}

///|
fn parse_symbol_plus_sqrt_quadratic(
  expr : Expr,
  var_name : String,
) -> (Expr, Bool)? {
  match expr_simplify(expr) {
    @symcore.Expr::Add(args) if args.length() == 2 => {
      let mut saw_symbol = false
      let mut kernel_sq : Expr? = None
      let mut is_diff : Bool? = None
      for arg in args {
        match arg {
          @symcore.Expr::Symbol(name) if name == var_name => saw_symbol = true
          @symcore.Expr::Function("sqrt", [inner]) =>
            match poly_coeffs_upto2(inner, var_name) {
              Some(coeffs) =>
                if expr_is_zero(coeffs[1]) &&
                  expr_is_one(coeffs[2]) &&
                  !expr_depends_on(coeffs[0], var_name) {
                  match extract_explicit_negative_factor(coeffs[0]) {
                    Some(v) =>
                      if kernel_sq is None {
                        kernel_sq = Some(v)
                        is_diff = Some(true)
                      } else {
                        return None
                      }
                    None =>
                      if kernel_sq is None {
                        kernel_sq = Some(coeffs[0])
                        is_diff = Some(false)
                      } else {
                        return None
                      }
                  }
                } else {
                  return None
                }
              None => return None
            }
          _ => return None
        }
      }
      match (saw_symbol, kernel_sq, is_diff) {
        (true, Some(v), Some(diff)) => Some((v, diff))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn make_expr_derivative(expr : Expr, wrt : Expr, order : Int) -> Expr {
  if order <= 0 {
    expr
  } else if order == 1 {
    @symcore.raw_function("Derivative", [expr, wrt])
  } else {
    @symcore.raw_function("Derivative", [expr, wrt, expr_int(order)])
  }
}

///|
fn parse_linear_scale_only(expr : Expr, var_name : String) -> Expr? {
  let (coeff, factors) = split_mul(expr_simplify(expr), var_name)
  if factors.length() != 1 {
    return None
  }
  match parse_power_factor(factors[0], var_name) {
    Some(power) if expr_is_one(power) => Some(coeff)
    _ => None
  }
}

///|
fn parse_sqrt_affine(expr : Expr, var_name : String) -> (Expr, Expr)? {
  match expr_simplify(expr) {
    @symcore.Expr::Function("sqrt", [inner]) =>
      match split_linear_coeff(inner, var_name) {
        Some((coeff, offset)) =>
          if !expr_is_zero(coeff) &&
            !expr_depends_on(coeff, var_name) &&
            !expr_depends_on(offset, var_name) {
            Some((coeff, offset))
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn parse_sqrt_affine_plus_const(
  expr : Expr,
  var_name : String,
) -> (Expr, Expr, Expr)? {
  match expr_simplify(expr) {
    @symcore.Expr::Add(args) if args.length() == 2 => {
      let mut sqrt_scale : Expr? = None
      let mut sqrt_offset : Expr? = None
      let mut constant : Expr? = None
      for arg in args {
        match parse_sqrt_affine(arg, var_name) {
          Some((scale, offset)) =>
            if sqrt_scale is None {
              sqrt_scale = Some(scale)
              sqrt_offset = Some(offset)
            } else {
              return None
            }
          None =>
            if expr_depends_on(arg, var_name) || !(constant is None) {
              return None
            } else {
              constant = Some(arg)
            }
        }
      }
      match (sqrt_scale, sqrt_offset, constant) {
        (Some(scale), Some(offset), Some(v)) => Some((scale, offset, v))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn parse_scaled_sqrt_linear_plus_const(
  expr : Expr,
  var_name : String,
) -> (Expr, Expr)? {
  match expr_simplify(expr) {
    @symcore.Expr::Add(args) if args.length() == 2 => {
      let mut scale : Expr? = None
      let mut constant : Expr? = None
      for arg in args {
        match parse_sqrt_linear(arg, var_name) {
          Some(v) => if scale is None { scale = Some(v) } else { return None }
          None =>
            if expr_depends_on(arg, var_name) || !(constant is None) {
              return None
            } else {
              constant = Some(arg)
            }
        }
      }
      match (scale, constant) {
        (Some(parsed_scale), Some(parsed_const)) =>
          Some((parsed_scale, parsed_const))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn parse_scaled_sqrt_linear_plus_const_power(
  expr : Expr,
  var_name : String,
) -> (Expr, Expr, Int)? {
  match expr_simplify(expr) {
    @symcore.Expr::Pow(base, exp) =>
      match expr_is_int_value(exp) {
        Some(power) if power > 0 =>
          match parse_scaled_sqrt_linear_plus_const(base, var_name) {
            Some((scale, constant)) => Some((scale, constant, power))
            None => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn parse_log_ratio_linear_offsets(
  expr : Expr,
  var_name : String,
) -> (Expr, Expr)? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  match
    (linear_coeffs(factors_expr(num), var_name), linear_coeffs(den, var_name)) {
    (Some((num_coeff, num_offset)), Some((den_coeff, den_offset))) =>
      if expr_is_one(num_coeff) && expr_is_one(den_coeff) {
        Some((num_offset, den_offset))
      } else {
        None
      }
    _ => None
  }
}

///|
fn inverse_laplace_delay_term(expr : Expr, s_name : String, t : Expr) -> Expr? {
  let t_name = match symbol_name(t) {
    Some(v) => v
    None => return None
  }
  let factors = match expr_simplify(expr) {
    @symcore.Expr::Mul(args) => args
    _ => return None
  }
  let mut delay : Expr? = None
  let mut exp_const = expr_zero()
  let rest : Array[Expr] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Function("exp", [inner]) =>
        match linear_coeffs(inner, s_name) {
          Some((coeff, offset)) =>
            match extract_explicit_negative_factor(coeff) {
              Some(amount) =>
                if delay is None {
                  delay = Some(amount)
                  exp_const = offset
                } else {
                  return None
                }
              None => rest.push(factor)
            }
          _ => rest.push(factor)
        }
      _ => rest.push(factor)
    }
  }
  match delay {
    Some(amount) =>
      match
        inverse_laplace_doit(
          expr_simplify(expr_mul(@symelem.exp(exp_const), factors_expr(rest))),
          s_name,
          t,
        ) {
        Some(value) =>
          Some(expr_simplify(subst_symbol(value, t_name, expr_sub(t, amount))))
        None => None
      }
    None => None
  }
}

///|
fn inverse_laplace_no_var(
  coeff : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  match
    inverse_laplace_shifted_diff_square_power(
      expr_zero(),
      coeff,
      den,
      t,
      s_name,
    ) {
    Some(v) => Some(v)
    None =>
      match
        inverse_laplace_shifted_square_power(expr_zero(), coeff, den, t, s_name) {
        Some(v) => Some(v)
        None =>
          match
            inverse_laplace_quadratic_power(expr_zero(), coeff, den, t, s_name) {
            Some(v) => Some(v)
            None =>
              match
                inverse_laplace_two_linear_factors(
                  expr_zero(),
                  coeff,
                  den,
                  t,
                  s_name,
                ) {
                Some(v) => Some(v)
                None =>
                  match
                    inverse_laplace_shifted_diff_square_term(
                      expr_zero(),
                      coeff,
                      den,
                      t,
                      s_name,
                    ) {
                    Some(v) => Some(v)
                    None =>
                      match
                        inverse_laplace_shifted_square_term(
                          expr_zero(),
                          coeff,
                          den,
                          t,
                          s_name,
                        ) {
                        Some(v) => Some(v)
                        None =>
                          match denom_to_diff_square_freq(den, s_name) {
                            Some(freq) =>
                              Some(
                                expr_simplify(
                                  expr_mul(
                                    expr_mul(
                                      expr_div(coeff, freq),
                                      @symelem.sinh(expr_mul(freq, t)),
                                    ),
                                    @symspec.heaviside(t),
                                  ),
                                ),
                              )
                            None =>
                              match split_linear_power_denom(den, s_name) {
                                Some((a, b, power)) =>
                                  if expr_is_zero(a) {
                                    None
                                  } else {
                                    let scale = expr_div(
                                      coeff,
                                      expr_mul(
                                        expr_pow(a, expr_int(power)),
                                        factorial_expr(expr_int(power - 1)),
                                      ),
                                    )
                                    let tpow = if power == 1 {
                                      expr_one()
                                    } else {
                                      expr_pow(t, expr_int(power - 1))
                                    }
                                    Some(
                                      expr_simplify(
                                        expr_mul(
                                          expr_mul(
                                            expr_mul(scale, tpow),
                                            @symspec.heaviside(t),
                                          ),
                                          @symelem.exp(
                                            expr_mul(
                                              expr_div(expr_neg_one(), a),
                                              expr_mul(b, t),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  }
                                None => None
                              }
                          }
                      }
                  }
              }
          }
      }
  }
}

///|
fn inverse_laplace_with_var(
  coeff : Expr,
  num_var : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  match split_linear_coeff(num_var, s_name) {
    Some((lin_coeff, lin_const)) => {
      let num_linear = expr_mul(coeff, lin_coeff)
      let num_const = expr_mul(coeff, lin_const)
      match
        inverse_laplace_shifted_diff_square_power(
          num_linear, num_const, den, t, s_name,
        ) {
        Some(v) => Some(v)
        None =>
          match
            inverse_laplace_shifted_square_power(
              num_linear, num_const, den, t, s_name,
            ) {
            Some(v) => Some(v)
            None =>
              match
                inverse_laplace_quadratic_power(
                  num_linear, num_const, den, t, s_name,
                ) {
                Some(v) => Some(v)
                None =>
                  match
                    inverse_laplace_two_linear_factors(
                      num_linear, num_const, den, t, s_name,
                    ) {
                    Some(v) => Some(v)
                    None =>
                      match
                        inverse_laplace_shifted_diff_square_term(
                          num_linear, num_const, den, t, s_name,
                        ) {
                        Some(v) => Some(v)
                        None =>
                          match
                            inverse_laplace_shifted_square_term(
                              num_linear, num_const, den, t, s_name,
                            ) {
                            Some(v) => Some(v)
                            None =>
                              match denom_to_diff_square_freq(den, s_name) {
                                Some(freq) =>
                                  Some(
                                    expr_simplify(
                                      expr_mul(
                                        @symspec.heaviside(t),
                                        expr_add(
                                          expr_mul(
                                            num_linear,
                                            @symelem.cosh(expr_mul(freq, t)),
                                          ),
                                          expr_mul(
                                            expr_div(num_const, freq),
                                            @symelem.sinh(expr_mul(freq, t)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                None => None
                              }
                          }
                      }
                  }
              }
          }
      }
    }
    None => None
  }
}

///|
fn inverse_laplace_shifted_diff_square_term(
  num_linear : Expr,
  num_const : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  match split_shifted_diff_square_denom(den, s_name) {
    Some((lead, shift, freq)) =>
      if expr_is_zero(freq) {
        None
      } else {
        let centered_const = expr_sub(num_const, expr_mul(num_linear, shift))
        let cosh_part = if expr_is_zero(num_linear) {
          expr_zero()
        } else {
          expr_mul(num_linear, @symelem.cosh(expr_mul(freq, t)))
        }
        let sinh_part = if expr_is_zero(centered_const) {
          expr_zero()
        } else {
          expr_mul(
            expr_div(centered_const, freq),
            @symelem.sinh(expr_mul(freq, t)),
          )
        }
        Some(
          expr_simplify(
            expr_mul(
              expr_mul(
                expr_mul(
                  expr_div(expr_one(), lead),
                  @symelem.exp(expr_mul(expr_neg_one(), expr_mul(shift, t))),
                ),
                @symspec.heaviside(t),
              ),
              expr_add(cosh_part, sinh_part),
            ),
          ),
        )
      }
    None => None
  }
}

///|
fn inverse_laplace_shifted_square_term(
  num_linear : Expr,
  num_const : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  match split_shifted_square_denom(den, s_name) {
    Some((lead, shift, freq)) =>
      if expr_is_zero(freq) {
        None
      } else {
        let centered_const = expr_sub(num_const, expr_mul(num_linear, shift))
        let cos_part = if expr_is_zero(num_linear) {
          expr_zero()
        } else {
          expr_mul(num_linear, @symelem.cos(expr_mul(freq, t)))
        }
        let sin_part = if expr_is_zero(centered_const) {
          expr_zero()
        } else {
          expr_mul(
            expr_div(centered_const, freq),
            @symelem.sin(expr_mul(freq, t)),
          )
        }
        Some(
          expr_simplify(
            expr_mul(
              expr_mul(
                expr_mul(
                  expr_div(expr_one(), lead),
                  @symelem.exp(expr_mul(expr_neg_one(), expr_mul(shift, t))),
                ),
                @symspec.heaviside(t),
              ),
              expr_add(cos_part, sin_part),
            ),
          ),
        )
      }
    None => None
  }
}

///|
fn inverse_laplace_shifted_diff_square_power(
  num_linear : Expr,
  num_const : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  match split_shifted_diff_square_power_denom(den, s_name) {
    Some((lead, shift, freq, power)) if power == 2 => {
      let lead_scale = expr_pow(lead, expr_int(2))
      let centered_const = expr_sub(num_const, expr_mul(num_linear, shift))
      let const_part = if expr_is_zero(centered_const) {
        expr_zero()
      } else {
        expr_mul(
          expr_div(
            centered_const,
            expr_mul(
              expr_int(2),
              expr_mul(lead_scale, expr_pow(freq, expr_int(3))),
            ),
          ),
          expr_sub(
            expr_mul(expr_mul(freq, t), @symelem.cosh(expr_mul(freq, t))),
            @symelem.sinh(expr_mul(freq, t)),
          ),
        )
      }
      let linear_part = if expr_is_zero(num_linear) {
        expr_zero()
      } else {
        expr_mul(
          expr_div(
            num_linear,
            expr_mul(expr_int(2), expr_mul(lead_scale, freq)),
          ),
          expr_mul(t, @symelem.sinh(expr_mul(freq, t))),
        )
      }
      Some(
        expr_simplify(
          expr_mul(
            expr_mul(
              @symspec.heaviside(t),
              @symelem.exp(expr_mul(expr_neg_one(), expr_mul(shift, t))),
            ),
            expr_add(const_part, linear_part),
          ),
        ),
      )
    }
    _ => None
  }
}

///|
fn inverse_laplace_shifted_square_power(
  num_linear : Expr,
  num_const : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  match split_shifted_square_power_denom(den, s_name) {
    Some((lead, shift, freq, power)) if power == 2 => {
      let lead_scale = expr_pow(lead, expr_int(2))
      let centered_const = expr_sub(num_const, expr_mul(num_linear, shift))
      let const_part = if expr_is_zero(centered_const) {
        expr_zero()
      } else {
        expr_mul(
          expr_div(
            centered_const,
            expr_mul(
              expr_int(2),
              expr_mul(lead_scale, expr_pow(freq, expr_int(3))),
            ),
          ),
          expr_sub(
            @symelem.sin(expr_mul(freq, t)),
            expr_mul(expr_mul(freq, t), @symelem.cos(expr_mul(freq, t))),
          ),
        )
      }
      let linear_part = if expr_is_zero(num_linear) {
        expr_zero()
      } else {
        expr_mul(
          expr_div(
            num_linear,
            expr_mul(expr_int(2), expr_mul(lead_scale, freq)),
          ),
          expr_mul(t, @symelem.sin(expr_mul(freq, t))),
        )
      }
      Some(
        expr_simplify(
          expr_mul(
            expr_mul(
              @symspec.heaviside(t),
              @symelem.exp(expr_mul(expr_neg_one(), expr_mul(shift, t))),
            ),
            expr_add(const_part, linear_part),
          ),
        ),
      )
    }
    _ => None
  }
}

///|
fn inverse_laplace_quadratic_power(
  num_linear : Expr,
  num_const : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  match split_quadratic_power_denom(den, s_name) {
    Some((lead, freq, is_diff, power)) if power == 2 => {
      let lead_scale = expr_pow(lead, expr_int(2))
      let const_part = if expr_is_zero(num_const) {
        expr_zero()
      } else if is_diff {
        expr_mul(
          expr_div(
            num_const,
            expr_mul(
              expr_int(2),
              expr_mul(lead_scale, expr_pow(freq, expr_int(3))),
            ),
          ),
          expr_sub(
            expr_mul(freq * t, @symelem.cosh(expr_mul(freq, t))),
            @symelem.sinh(expr_mul(freq, t)),
          ),
        )
      } else {
        expr_mul(
          expr_div(
            num_const,
            expr_mul(
              expr_int(2),
              expr_mul(lead_scale, expr_pow(freq, expr_int(3))),
            ),
          ),
          expr_sub(
            @symelem.sin(expr_mul(freq, t)),
            expr_mul(freq * t, @symelem.cos(expr_mul(freq, t))),
          ),
        )
      }
      let linear_part = if expr_is_zero(num_linear) {
        expr_zero()
      } else if is_diff {
        expr_mul(
          expr_div(
            num_linear,
            expr_mul(expr_int(2), expr_mul(lead_scale, freq)),
          ),
          expr_mul(t, @symelem.sinh(expr_mul(freq, t))),
        )
      } else {
        expr_mul(
          expr_div(
            num_linear,
            expr_mul(expr_int(2), expr_mul(lead_scale, freq)),
          ),
          expr_mul(t, @symelem.sin(expr_mul(freq, t))),
        )
      }
      Some(
        expr_simplify(
          expr_mul(@symspec.heaviside(t), expr_add(const_part, linear_part)),
        ),
      )
    }
    _ => None
  }
}

///|
fn inverse_laplace_two_linear_factors(
  num_linear : Expr,
  num_const : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  match split_two_linear_factors(den, s_name) {
    Some(((a1, b1), (a2, b2))) => {
      let det = expr_sub(expr_mul(a2, b1), expr_mul(a1, b2))
      if expr_is_zero(det) {
        None
      } else {
        let left_coeff = expr_div(
          expr_sub(expr_mul(num_linear, b1), expr_mul(num_const, a1)),
          det,
        )
        let right_coeff = expr_div(
          expr_sub(expr_mul(num_const, a2), expr_mul(num_linear, b2)),
          det,
        )
        Some(
          expr_simplify(
            expr_mul(
              @symspec.heaviside(t),
              expr_add(
                expr_mul(
                  expr_div(left_coeff, a1),
                  @symelem.exp(
                    expr_mul(expr_div(expr_neg_one(), a1), expr_mul(b1, t)),
                  ),
                ),
                expr_mul(
                  expr_div(right_coeff, a2),
                  @symelem.exp(
                    expr_mul(expr_div(expr_neg_one(), a2), expr_mul(b2, t)),
                  ),
                ),
              ),
            ),
          ),
        )
      }
    }
    None => None
  }
}

///|
/// Evaluate a forward Fourier transform if a closed form is available.
pub fn do_fourier_doit(expr : Expr, x : Expr, k : Expr) -> Expr? {
  match symbol_name(x) {
    Some(x_name) => fourier_doit(expr_simplify(expr), x_name, k)
    None => None
  }
}

///|
fn fourier_doit(expr : Expr, x_name : String, k : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Add(terms) =>
      transform_add(terms, x_name, fn(term) { fourier_doit(term, x_name, k) })
    _ => {
      let (coeff, factors) = split_mul(expr, x_name)
      if factors.length() == 0 {
        match fourier_term(coeff, x_name, k) {
          Some(v) => Some(v)
          None => None
        }
      } else {
        match fourier_mul_term(factors, x_name, k) {
          Some(v) => Some(expr_mul(coeff, v))
          None => None
        }
      }
    }
  }
}

///|
fn fourier_mul_term(factors : Array[Expr], x_name : String, k : Expr) -> Expr? {
  match fourier_triangle_term(factors, x_name, k) {
    Some(value) => return Some(value)
    None => ()
  }
  match fourier_half_line_term(factors, x_name, k) {
    Some(value) => return Some(value)
    None => ()
  }
  if factors.length() == 1 {
    fourier_term(factors[0], x_name, k)
  } else {
    None
  }
}

///|
fn fourier_term(expr : Expr, x_name : String, k : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Function("Heaviside", [arg]) =>
      match parse_one_minus_abs_linear(arg, x_name) {
        Some(scale) =>
          Some(
            expr_div(
              @symelem.sin(
                expr_div(
                  expr_mul(expr_int(2), expr_mul(@symcore.pi(), k)),
                  scale,
                ),
              ),
              expr_mul(@symcore.pi(), k),
            ),
          )
        None => None
      }
    @symcore.Expr::Function("exp", [inner]) =>
      match parse_negative_abs_linear(inner, x_name) {
        Some(a) =>
          Some(
            expr_div(
              expr_mul(expr_int(2), a),
              expr_add(
                expr_pow(a, expr_int(2)),
                expr_mul(
                  expr_int(4),
                  expr_mul(
                    expr_pow(@symcore.pi(), expr_int(2)),
                    expr_pow(k, expr_int(2)),
                  ),
                ),
              ),
            ),
          )
        None =>
          match extract_negative_quadratic_poly(inner, x_name) {
            Some((scale, linear, constant)) =>
              Some(
                expr_mul(
                  expr_div(sqrt_pi(), expr_sqrt_positive(scale)),
                  @symelem.exp(
                    fourier_gaussian_exponent(scale, linear, constant, k, false),
                  ),
                ),
              )
            None => None
          }
      }
    _ => None
  }
}

///|
/// Evaluate an inverse Fourier transform if a closed form is available.
pub fn do_inverse_fourier_doit(expr : Expr, k : Expr, x : Expr) -> Expr? {
  match symbol_name(k) {
    Some(k_name) => inverse_fourier_doit(expr_simplify(expr), k_name, x)
    None => None
  }
}

///|
fn inverse_fourier_doit(expr : Expr, k_name : String, x : Expr) -> Expr? {
  match inverse_fourier_window_term(expr_simplify(expr), k_name, x) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_fourier_half_line_term(expr_simplify(expr), k_name, x) {
    Some(v) => Some(v)
    None => {
      let (coeff, factors) = split_mul(expr, k_name)
      if factors.length() == 0 {
        None
      } else if factors.length() != 1 {
        None
      } else {
        match factors[0] {
          @symcore.Expr::Function("exp", [inner]) =>
            match extract_negative_quadratic_poly(inner, k_name) {
              Some((scale, linear, constant)) =>
                Some(
                  expr_mul(
                    coeff,
                    expr_mul(
                      expr_div(sqrt_pi(), expr_sqrt_positive(scale)),
                      @symelem.exp(
                        fourier_gaussian_exponent(
                          scale, linear, constant, x, true,
                        ),
                      ),
                    ),
                  ),
                )
              None => None
            }
          _ => None
        }
      }
    }
  }
}

///|
fn inverse_fourier_window_term(expr : Expr, k_name : String, x : Expr) -> Expr? {
  match parse_inverse_fourier_box_scale(expr, k_name) {
    Some(scale) => Some(inverse_fourier_box_window(scale, x))
    None =>
      match parse_inverse_fourier_triangle_scale(expr, k_name) {
        Some(scale) =>
          Some(
            inverse_fourier_box_window(scale, x) *
            (expr_one() - @symelem.abs(expr_mul(scale, x))),
          )
        None => None
      }
  }
}

///|
fn inverse_fourier_box_window(scale : Expr, x : Expr) -> Expr {
  @symspec.heaviside(expr_one() - @symelem.abs(expr_mul(scale, x)))
}

///|
fn inverse_fourier_half_line_term(
  expr : Expr,
  k_name : String,
  x : Expr,
) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  let numerator = if num.length() == 0 {
    expr_one()
  } else if num.length() == 1 {
    num[0]
  } else {
    expr_simplify(@symcore.mul(num))
  }
  let heaviside = @symspec.heaviside(x)
  match parse_inverse_fourier_abs_decay_rate(numerator, den, k_name) {
    Some(a) =>
      return Some(
        @symelem.exp(expr_mul(expr_neg_one(), expr_mul(a, @symelem.abs(x)))),
      )
    _ => ()
  }
  match parse_fourier_shift_power(den, k_name) {
    Some((a, 1)) if expr_is_one(numerator) =>
      Some(heaviside * @symelem.exp(expr_mul(expr_neg_one(), expr_mul(a, x))))
    Some((a, 2)) if expr_is_one(numerator) =>
      Some(
        heaviside * x * @symelem.exp(expr_mul(expr_neg_one(), expr_mul(a, x))),
      )
    _ =>
      match parse_fourier_shifted_sine_denominator(den, k_name) {
        Some((a, b)) if expr_eq(numerator, b) =>
          Some(
            heaviside *
            @symelem.exp(expr_mul(expr_neg_one(), expr_mul(a, x))) *
            @symelem.sin(expr_mul(b, x)),
          )
        _ => None
      }
  }
}

///|
fn fourier_half_line_term(
  factors : Array[Expr],
  x_name : String,
  k : Expr,
) -> Expr? {
  let mut exp_rate : Expr? = None
  let mut power = expr_zero()
  let mut sine_rate : Expr? = None
  let mut saw_heaviside = false
  for factor in factors {
    match parse_power_factor(factor, x_name) {
      Some(p) => {
        power = expr_add(power, p)
        continue
      }
      None => ()
    }
    match factor {
      @symcore.Expr::Function("exp", [inner]) =>
        match parse_negative_linear_exp_raw(inner, x_name) {
          Some(a) =>
            if exp_rate is None {
              exp_rate = Some(a)
            } else {
              return None
            }
          None => return None
        }
      @symcore.Expr::Function("Heaviside", [arg]) =>
        match parse_heaviside_limit(arg, x_name) {
          Some((bound, is_le)) if expr_is_zero(bound) && !is_le =>
            saw_heaviside = true
          _ => return None
        }
      @symcore.Expr::Function("sin", [inner]) =>
        match linear_coeffs(inner, x_name) {
          Some((b, offset)) =>
            if expr_is_zero(offset) &&
              expr_is_constant(expr_simplify(b), x_name) {
              if sine_rate is None {
                sine_rate = Some(b)
              } else {
                return None
              }
            } else {
              return None
            }
          _ => return None
        }
      _ => return None
    }
  }
  if !saw_heaviside || exp_rate is None {
    return None
  }
  let a = exp_rate.unwrap()
  let shift = fourier_linear_shift(a, k)
  match (expr_is_zero(power), expr_eq(power, expr_one()), sine_rate) {
    (true, _, None) => Some(expr_pow(shift, expr_int(-1)))
    (_, true, None) => Some(expr_pow(shift, expr_int(-2)))
    (true, _, Some(b)) =>
      Some(
        expr_div(
          b,
          expr_add(expr_pow(b, expr_int(2)), expr_pow(shift, expr_int(2))),
        ),
      )
    _ => None
  }
}

///|
fn fourier_triangle_term(
  factors : Array[Expr],
  x_name : String,
  k : Expr,
) -> Expr? {
  if factors.length() != 2 {
    return None
  }
  let mut box_scale : Expr? = None
  let mut ramp_scale : Expr? = None
  for factor in factors {
    match factor {
      @symcore.Expr::Function("Heaviside", [arg]) =>
        match parse_one_minus_abs_linear(arg, x_name) {
          Some(scale) => box_scale = Some(scale)
          None => return None
        }
      _ =>
        match parse_one_minus_abs_linear(factor, x_name) {
          Some(scale) => ramp_scale = Some(scale)
          None => return None
        }
    }
  }
  match (box_scale, ramp_scale) {
    (Some(c1), Some(c2)) if expr_eq(c1, c2) =>
      Some(
        expr_div(
          expr_mul(
            c1,
            expr_pow(
              @symelem.sin(expr_div(expr_mul(@symcore.pi(), k), c1)),
              expr_int(2),
            ),
          ),
          expr_mul(
            expr_pow(@symcore.pi(), expr_int(2)),
            expr_pow(k, expr_int(2)),
          ),
        ),
      )
    _ => None
  }
}

///|
fn fourier_linear_shift(a : Expr, k : Expr) -> Expr {
  expr_add(
    a,
    expr_mul(
      expr_int(2),
      expr_mul(expr_mul(@symcore.pi(), @symcore.imag_unit()), k),
    ),
  )
}

///|
fn fourier_linear_shift_coeff() -> Expr {
  expr_mul(expr_int(2), expr_mul(@symcore.pi(), @symcore.imag_unit()))
}

///|
fn parse_fourier_linear_shift(expr : Expr, k_name : String) -> Expr? {
  match linear_coeffs(expr_simplify(expr), k_name) {
    Some((coeff, offset)) =>
      if expr_eq(coeff, fourier_linear_shift_coeff()) &&
        !expr_depends_on(offset, k_name) {
        Some(offset)
      } else {
        None
      }
    _ => None
  }
}

///|
fn parse_fourier_shift_power(expr : Expr, k_name : String) -> (Expr, Int)? {
  match expr_simplify(expr) {
    @symcore.Expr::Pow(base, exp) =>
      match expr_is_int_value(exp) {
        Some(power) =>
          match parse_fourier_linear_shift(base, k_name) {
            Some(a) if power > 0 => Some((a, power))
            _ => None
          }
        _ => None
      }
    _ =>
      match parse_fourier_linear_shift(expr, k_name) {
        Some(a) => Some((a, 1))
        None => None
      }
  }
}

///|
fn parse_fourier_shifted_sine_denominator(
  expr : Expr,
  k_name : String,
) -> (Expr, Expr)? {
  match expr_simplify(expr) {
    @symcore.Expr::Add(args) if args.length() == 2 => {
      let mut shift : Expr? = None
      let mut other : Expr? = None
      for arg in args {
        match parse_fourier_shift_power(arg, k_name) {
          Some((a, 2)) =>
            if shift is None {
              shift = Some(a)
            } else {
              return None
            }
          _ =>
            if expr_depends_on(arg, k_name) {
              return None
            } else if other is None {
              other = Some(arg)
            } else {
              return None
            }
        }
      }
      match (shift, other) {
        (Some(a), Some(b_sq)) => Some((a, preferred_positive_sqrt(b_sq)))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn parse_inverse_fourier_abs_decay_rate(
  numerator : Expr,
  den : Expr,
  k_name : String,
) -> Expr? {
  match poly_coeffs_upto2(expr_simplify(den), k_name) {
    Some(coeffs) =>
      if expr_is_zero(coeffs[1]) &&
        !expr_depends_on(coeffs[0], k_name) &&
        !expr_depends_on(coeffs[2], k_name) &&
        !expr_is_zero(coeffs[2]) {
        let quad_base = expr_mul(
          expr_int(4),
          expr_pow(@symcore.pi(), expr_int(2)),
        )
        let scale = expr_simplify(expr_div(coeffs[2], quad_base))
        if expr_depends_on(scale, k_name) || expr_is_zero(scale) {
          None
        } else {
          let expected_quad = expr_simplify(expr_mul(scale, quad_base))
          if !expr_same_simplified(coeffs[2], expected_quad) {
            None
          } else {
            let rate_sq = expr_simplify(expr_div(coeffs[0], scale))
            let rate = preferred_positive_sqrt(rate_sq)
            let expected_num = expr_simplify(
              expr_mul(scale, expr_mul(expr_int(2), rate)),
            )
            if expr_same_simplified(expr_simplify(numerator), expected_num) {
              Some(rate)
            } else {
              None
            }
          }
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn parse_inverse_fourier_box_scale(expr : Expr, k_name : String) -> Expr? {
  match parse_inverse_fourier_box_sinc_scale(expr, k_name) {
    Some(v) => return Some(v)
    None => ()
  }
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  if num.length() != 1 {
    return None
  }
  match linear_coeffs(den, k_name) {
    Some((coeff, offset)) =>
      if !expr_eq(coeff, @symcore.pi()) || !expr_is_zero(offset) {
        return None
      }
    _ => return None
  }
  match num[0] {
    @symcore.Expr::Function("sin", [arg]) =>
      match linear_coeffs(arg, k_name) {
        Some((coeff, offset)) if expr_is_zero(offset) =>
          Some(
            expr_simplify(expr_div(expr_mul(expr_int(2), @symcore.pi()), coeff)),
          )
        _ => None
      }
    _ => None
  }
}

///|
fn parse_inverse_fourier_box_sinc_scale(expr : Expr, k_name : String) -> Expr? {
  let (coeff, factors) = split_mul(expr, k_name)
  if factors.length() != 1 {
    return None
  }
  match factors[0] {
    @symcore.Expr::Function("sinc", [arg]) =>
      match parse_scaled_symbol(arg, k_name) {
        Some(freq) =>
          match inverse_fourier_sinc_scale(coeff, freq, 2) {
            Some(scale) => Some(scale)
            None => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn parse_inverse_fourier_triangle_scale(expr : Expr, k_name : String) -> Expr? {
  match parse_inverse_fourier_triangle_sinc_scale(expr, k_name) {
    Some(v) => return Some(v)
    None => ()
  }
  let (coeff, factors) = split_mul(expr, k_name)
  if factors.length() != 2 {
    return None
  }
  let mut den_ok = false
  let mut scale : Expr? = None
  for factor in factors {
    match factor {
      @symcore.Expr::Pow(base, exp) if expr_eq(exp, expr_int(-1)) =>
        match poly_coeffs_upto2(base, k_name) {
          Some(coeffs) =>
            if expr_is_zero(coeffs[0]) &&
              expr_is_zero(coeffs[1]) &&
              expr_eq(coeffs[2], expr_pow(@symcore.pi(), expr_int(2))) {
              den_ok = true
            } else {
              return None
            }
          _ => return None
        }
      @symcore.Expr::Pow(@symcore.Expr::Function("sin", [arg]), exp) if expr_eq(
          exp,
          expr_int(2),
        ) =>
        match linear_coeffs(arg, k_name) {
          Some((freq, offset)) if expr_is_zero(offset) =>
            if expr_eq(expr_simplify(expr_mul(coeff, freq)), @symcore.pi()) {
              scale = Some(coeff)
            } else {
              return None
            }
          _ => return None
        }
      _ => return None
    }
  }
  match (den_ok, scale) {
    (true, Some(v)) => Some(v)
    _ => None
  }
}

///|
fn parse_inverse_fourier_triangle_sinc_scale(
  expr : Expr,
  k_name : String,
) -> Expr? {
  let (coeff, factors) = split_mul(expr, k_name)
  if factors.length() != 1 {
    return None
  }
  match factors[0] {
    @symcore.Expr::Pow(@symcore.Expr::Function("sinc", [arg]), exp) if expr_eq(
        exp,
        expr_int(2),
      ) =>
      match parse_scaled_symbol(arg, k_name) {
        Some(freq) =>
          match inverse_fourier_sinc_scale(coeff, freq, 1) {
            Some(scale) => Some(scale)
            None => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn inverse_fourier_sinc_scale(coeff : Expr, freq : Expr, width : Int) -> Expr? {
  let ratio = expr_simplify(expr_mul(coeff, expr_pow(freq, expr_int(-1))))
  if expr_eq(ratio, expr_one()) || expr_eq(ratio, expr_neg_one()) {
    Some(expr_simplify(expr_div(expr_int(width), freq)))
  } else {
    None
  }
}

///|
fn parse_scaled_symbol(expr : Expr, var_name : String) -> Expr? {
  match expr_simplify(expr) {
    @symcore.Expr::Symbol(name) =>
      if name == var_name {
        Some(expr_one())
      } else {
        None
      }
    @symcore.Expr::Mul(args) => {
      let mut coeff = expr_one()
      let mut seen_var = false
      for arg in args {
        match arg {
          @symcore.Expr::Symbol(name) =>
            if name == var_name {
              if seen_var {
                return None
              }
              seen_var = true
            } else {
              return None
            }
          _ =>
            if expr_depends_on(arg, var_name) {
              return None
            } else {
              coeff = expr_mul(coeff, arg)
            }
        }
      }
      if seen_var {
        Some(coeff)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
/// Evaluate a forward sine transform if a closed form is available.
pub fn do_sine_doit(expr : Expr, x : Expr, k : Expr) -> Expr? {
  match symbol_name(x) {
    Some(x_name) => sine_doit(expr_simplify(expr), x_name, k)
    None => None
  }
}

///|
fn sine_doit(expr : Expr, x_name : String, k : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Add(terms) =>
      transform_add(terms, x_name, fn(term) { sine_doit(term, x_name, k) })
    _ => {
      let (coeff, factors) = split_mul(expr, x_name)
      match sine_mul_term(factors, x_name, k) {
        Some(value) => Some(expr_mul(coeff, value))
        None => None
      }
    }
  }
}

///|
fn sine_mul_term(factors : Array[Expr], x_name : String, k : Expr) -> Expr? {
  match sine_log_over_x_term(factors, x_name, k) {
    Some(value) => return Some(value)
    None => ()
  }
  if factors.length() == 1 {
    return sine_base_term(factors[0], x_name, k)
  }
  let mut exp_quad : Expr? = None
  let mut x_pow = expr_zero()
  for factor in factors {
    match parse_power_factor(factor, x_name) {
      Some(power) => x_pow = expr_add(x_pow, power)
      None =>
        match factor {
          @symcore.Expr::Function("exp", [inner]) =>
            match parse_negative_quadratic_exp(inner, x_name) {
              Some(scale) =>
                if exp_quad is None {
                  exp_quad = Some(scale)
                } else {
                  return None
                }
              None => return None
            }
          _ => return None
        }
    }
  }
  match exp_quad {
    Some(scale) if expr_eq(x_pow, expr_one()) =>
      Some(
        expr_div(
          expr_mul(
            expr_mul(
              expr_mul(expr_sqrt_two(), k),
              @symelem.exp(
                expr_div(
                  expr_mul(expr_neg_one(), expr_pow(k, expr_int(2))),
                  expr_mul(expr_int(4), scale),
                ),
              ),
            ),
            expr_one(),
          ),
          expr_mul(expr_int(4), expr_pow(scale, expr_rat(3, 2))),
        ),
      )
    _ => None
  }
}

///|
fn sine_log_over_x_term(
  factors : Array[Expr],
  x_name : String,
  k : Expr,
) -> Expr? {
  if factors.length() != 2 {
    return None
  }
  let mut saw_log = false
  let mut saw_inverse_x = false
  for factor in factors {
    match factor {
      @symcore.Expr::Function("log", [@symcore.Expr::Symbol(name)]) if name ==
        x_name => saw_log = true
      _ =>
        match parse_negative_power(factor, x_name) {
          Some(power) if expr_eq(power, expr_one()) => saw_inverse_x = true
          _ => return None
        }
    }
  }
  if saw_log && saw_inverse_x {
    Some(
      expr_div(
        expr_mul(
          expr_mul(expr_neg_one(), expr_mul(expr_sqrt_two(), sqrt_pi())),
          expr_add(
            @symelem.log(expr_pow(k, expr_int(2))),
            expr_mul(expr_int(2), @symcore.euler_gamma()),
          ),
        ),
        expr_int(4),
      ),
    )
  } else {
    None
  }
}

///|
fn sine_base_term(expr : Expr, x_name : String, k : Expr) -> Expr? {
  match parse_negative_power(expr, x_name) {
    Some(a) =>
      Some(
        expr_div(
          expr_mul(
            expr_pow(
              expr_int(2),
              expr_add(
                expr_div(expr_one(), expr_int(2)),
                expr_mul(expr_neg_one(), a),
              ),
            ),
            expr_mul(
              expr_pow(k, expr_sub(a, expr_one())),
              @symspec.gamma(expr_sub(expr_one(), expr_div(a, expr_int(2)))),
            ),
          ),
          @symspec.gamma(expr_div(expr_add(a, expr_one()), expr_int(2))),
        ),
      )
    None =>
      match parse_negative_linear_exp(expr, x_name) {
        Some(a) =>
          Some(
            expr_div(
              expr_mul(expr_sqrt_two(), k),
              expr_mul(
                sqrt_pi(),
                expr_add(expr_pow(a, expr_int(2)), expr_pow(k, expr_int(2))),
              ),
            ),
          )
        None => None
      }
  }
}

///|
/// Evaluate an inverse sine transform if a closed form is available.
pub fn do_inverse_sine_doit(expr : Expr, k : Expr, x : Expr) -> Expr? {
  match symbol_name(k) {
    Some(k_name) => inverse_sine_doit(expr_simplify(expr), k_name, x)
    None => None
  }
}

///|
fn inverse_sine_doit(expr : Expr, k_name : String, x : Expr) -> Expr? {
  if matches_negative_power_transform(expr, k_name, x, true) is Some(v) {
    return Some(v)
  }
  match inverse_sine_exp_term(expr, k_name, x) {
    Some(v) => Some(v)
    None => inverse_sine_gaussian_term(expr, k_name, x)
  }
}

///|
fn inverse_sine_exp_term(expr : Expr, k_name : String, x : Expr) -> Expr? {
  let (coeff, den_opt) = split_division(expr)
  match den_opt {
    Some(den) =>
      match coeff.length() {
        2 => {
          let mut k_seen = false
          let mut const_coeff = expr_one()
          for item in coeff {
            if expr_eq(item, @symcore.symbol(k_name)) {
              k_seen = true
            } else {
              const_coeff = expr_mul(const_coeff, item)
            }
          }
          if !k_seen {
            return None
          }
          match denom_to_square_freq(den, k_name) {
            Some(a) => {
              let expected = expr_div(expr_sqrt_two(), sqrt_pi())
              if expr_eq(const_coeff, expected) {
                Some(@symelem.exp(expr_mul(expr_neg_one(), expr_mul(a, x))))
              } else {
                None
              }
            }
            None => None
          }
        }
        _ => None
      }
    None => None
  }
}

///|
fn inverse_sine_gaussian_term(expr : Expr, k_name : String, x : Expr) -> Expr? {
  let (coeff, factors) = split_mul(expr, k_name)
  if factors.length() != 2 {
    return None
  }
  let mut k_seen = false
  let mut exp_scale : Expr? = None
  for factor in factors {
    if expr_eq(factor, @symcore.symbol(k_name)) {
      k_seen = true
    } else {
      match factor {
        @symcore.Expr::Function("exp", [inner]) =>
          match parse_negative_quadratic_exp(inner, k_name) {
            Some(scale) => exp_scale = Some(scale)
            None => return None
          }
        _ => return None
      }
    }
  }
  if !k_seen {
    return None
  }
  match exp_scale {
    Some(scale) => {
      let a = expr_div(expr_one(), expr_mul(expr_int(4), scale))
      let expected = expr_div(
        expr_sqrt_two(),
        expr_mul(expr_int(4), expr_pow(a, expr_rat(3, 2))),
      )
      if expr_eq(coeff, expected) {
        Some(
          expr_mul(
            x,
            @symelem.exp(
              expr_mul(expr_neg_one(), expr_mul(a, expr_pow(x, expr_int(2)))),
            ),
          ),
        )
      } else {
        None
      }
    }
    None => None
  }
}

///|
/// Evaluate a forward cosine transform if a closed form is available.
pub fn do_cosine_doit(expr : Expr, x : Expr, k : Expr) -> Expr? {
  match symbol_name(x) {
    Some(x_name) => cosine_doit(expr_simplify(expr), x_name, k)
    None => None
  }
}

///|
fn cosine_doit(expr : Expr, x_name : String, k : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Add(terms) =>
      transform_add(terms, x_name, fn(term) { cosine_doit(term, x_name, k) })
    _ => {
      let (coeff, factors) = split_mul(expr, x_name)
      match cosine_mul_term(factors, x_name, k) {
        Some(value) => Some(expr_mul(coeff, value))
        None => None
      }
    }
  }
}

///|
fn cosine_mul_term(factors : Array[Expr], x_name : String, k : Expr) -> Expr? {
  if factors.length() == 1 {
    return cosine_base_term(factors[0], x_name, k)
  }
  if factors.length() == 2 {
    let mut exp_coeff : Expr? = None
    let mut cos_coeff : Expr? = None
    for factor in factors {
      match factor {
        @symcore.Expr::Function("exp", [inner]) =>
          match parse_sqrt_linear(expr_mul(expr_neg_one(), inner), x_name) {
            Some(a) => exp_coeff = Some(a)
            None => return None
          }
        @symcore.Expr::Function("cos", [inner]) =>
          match parse_sqrt_linear(inner, x_name) {
            Some(a) => cos_coeff = Some(a)
            None => return None
          }
        _ => return None
      }
    }
    match (exp_coeff, cos_coeff) {
      (Some(a1), Some(a2)) if expr_eq(a1, a2) =>
        Some(
          expr_div(
            expr_mul(
              a1,
              @symelem.exp(
                expr_div(
                  expr_mul(expr_neg_one(), expr_pow(a1, expr_int(2))),
                  expr_mul(expr_int(2), k),
                ),
              ),
            ),
            expr_mul(expr_int(2), expr_pow(k, expr_rat(3, 2))),
          ),
        )
      _ => None
    }
  } else {
    None
  }
}

///|
fn cosine_base_term(expr : Expr, x_name : String, k : Expr) -> Expr? {
  match parse_negative_power(expr, x_name) {
    Some(a) =>
      Some(
        expr_div(
          expr_mul(
            expr_pow(
              expr_int(2),
              expr_add(
                expr_div(expr_one(), expr_int(2)),
                expr_mul(expr_neg_one(), a),
              ),
            ),
            expr_mul(
              expr_pow(k, expr_sub(a, expr_one())),
              @symspec.gamma(expr_div(expr_sub(expr_one(), a), expr_int(2))),
            ),
          ),
          @symspec.gamma(expr_div(a, expr_int(2))),
        ),
      )
    None =>
      match parse_negative_linear_exp(expr, x_name) {
        Some(a) =>
          Some(
            expr_div(
              expr_mul(expr_sqrt_two(), a),
              expr_mul(
                sqrt_pi(),
                expr_add(expr_pow(a, expr_int(2)), expr_pow(k, expr_int(2))),
              ),
            ),
          )
        None =>
          match parse_reciprocal_quadratic(expr, x_name) {
            Some(a) =>
              Some(
                expr_div(
                  expr_mul(
                    expr_mul(expr_sqrt_two(), sqrt_pi()),
                    @symelem.exp(expr_mul(expr_neg_one(), expr_mul(a, k))),
                  ),
                  expr_mul(expr_int(2), a),
                ),
              )
            None =>
              match parse_shifted_reciprocal_linear(expr, x_name) {
                Some(a) =>
                  Some(
                    expr_div(
                      expr_mul(
                        expr_sqrt_two(),
                        expr_sub(
                          expr_mul(
                            expr_div(
                              expr_sub(
                                @symcore.pi(),
                                expr_mul(
                                  expr_int(2),
                                  @symspec.si(expr_mul(a, k)),
                                ),
                              ),
                              expr_int(2),
                            ),
                            @symelem.sin(expr_mul(a, k)),
                          ),
                          expr_mul(
                            @symelem.cos(expr_mul(a, k)),
                            @symspec.ci(expr_mul(a, k)),
                          ),
                        ),
                      ),
                      sqrt_pi(),
                    ),
                  )
                None =>
                  match parse_reciprocal_sqrt_quadratic(expr, x_name) {
                    Some(a_sq) =>
                      Some(
                        expr_div(
                          expr_mul(
                            expr_sqrt_two(),
                            @symspec.meijerg(
                              [expr_rat(1, 2)],
                              [],
                              [expr_zero(), expr_zero()],
                              [expr_rat(1, 2)],
                              expr_div(
                                expr_mul(a_sq, expr_pow(k, expr_int(2))),
                                expr_int(4),
                              ),
                            ),
                          ),
                          expr_mul(expr_int(2), sqrt_pi()),
                        ),
                      )
                    None =>
                      match expr {
                        @symcore.Expr::Function("exp", [inner]) =>
                          match parse_negative_quadratic_exp(inner, x_name) {
                            Some(a) =>
                              Some(
                                expr_div(
                                  expr_mul(
                                    expr_sqrt_two(),
                                    @symelem.exp(
                                      expr_div(
                                        expr_mul(
                                          expr_neg_one(),
                                          expr_pow(k, expr_int(2)),
                                        ),
                                        expr_mul(expr_int(4), a),
                                      ),
                                    ),
                                  ),
                                  expr_mul(expr_int(2), expr_sqrt_positive(a)),
                                ),
                              )
                            None => None
                          }
                        _ => None
                      }
                  }
              }
          }
      }
  }
}

///|
fn parse_sqrt_linear(expr : Expr, var_name : String) -> Expr? {
  let simplified = expr_simplify(expr)
  match simplified {
    @symcore.Expr::Function("sqrt", [@symcore.Expr::Symbol(name)]) if name ==
      var_name => Some(expr_one())
    @symcore.Expr::Mul(args) => {
      let mut coeff = expr_one()
      let mut saw_sqrt = false
      for arg in args {
        match arg {
          @symcore.Expr::Function("sqrt", [@symcore.Expr::Symbol(name)]) =>
            if name == var_name {
              saw_sqrt = true
            } else {
              return None
            }
          _ =>
            if expr_depends_on(arg, var_name) {
              return None
            } else {
              coeff = expr_mul(coeff, arg)
            }
        }
      }
      if saw_sqrt {
        Some(coeff)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
/// Evaluate an inverse cosine transform if a closed form is available.
pub fn do_inverse_cosine_doit(expr : Expr, k : Expr, x : Expr) -> Expr? {
  match symbol_name(k) {
    Some(k_name) => inverse_cosine_doit(expr_simplify(expr), k_name, x)
    None => None
  }
}

///|
fn inverse_cosine_doit(expr : Expr, k_name : String, x : Expr) -> Expr? {
  if matches_negative_power_transform(expr, k_name, x, false) is Some(v) {
    return Some(v)
  }
  match inverse_cosine_meijerg_term(expr, k_name, x) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_cosine_reciprocal_quadratic_term(expr, k_name, x) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_cosine_gaussian_term(expr, k_name, x) {
    Some(v) => return Some(v)
    None => ()
  }
  let (num, den_opt) = split_division(expr)
  match den_opt {
    Some(den) => {
      let coeff = if num.length() == 0 {
        expr_one()
      } else if num.length() == 1 {
        num[0]
      } else {
        expr_simplify(@symcore.mul(num))
      }
      match denom_to_square_freq(den, k_name) {
        Some(a) => {
          let expected = expr_div(expr_mul(expr_sqrt_two(), a), sqrt_pi())
          if expr_eq(coeff, expected) {
            Some(@symelem.exp(expr_mul(expr_neg_one(), expr_mul(a, x))))
          } else {
            None
          }
        }
        None => None
      }
    }
    None => None
  }
}

///|
fn inverse_cosine_meijerg_term(expr : Expr, k_name : String, x : Expr) -> Expr? {
  let (coeff, factors) = split_mul(expr, k_name)
  if factors.length() != 1 {
    return None
  }
  match parse_cosine_linear_meijerg(factors[0], k_name) {
    Some(a_sq) => {
      let expected = expr_div(
        expr_sqrt_two(),
        expr_mul(expr_int(2), @symcore.pi()),
      )
      if expr_eq(coeff, expected) {
        Some(expr_pow(expr_add(x, expr_sqrt_positive(a_sq)), expr_int(-1)))
      } else {
        None
      }
    }
    None =>
      match parse_cosine_sqrt_meijerg(factors[0], k_name) {
        Some(a_sq) => {
          let expected = expr_div(
            expr_sqrt_two(),
            expr_mul(expr_int(2), sqrt_pi()),
          )
          if expr_eq(coeff, expected) {
            Some(
              expr_div(
                expr_one(),
                expr_mul(
                  x,
                  @symelem.sqrt(
                    expr_add(
                      expr_div(a_sq, expr_pow(x, expr_int(2))),
                      expr_one(),
                    ),
                  ),
                ),
              ),
            )
          } else {
            None
          }
        }
        None => None
      }
  }
}

///|
fn inverse_cosine_reciprocal_quadratic_term(
  expr : Expr,
  k_name : String,
  x : Expr,
) -> Expr? {
  let (coeff, factors) = split_mul(expr, k_name)
  if factors.length() != 1 {
    return None
  }
  match parse_negative_linear_exp(factors[0], k_name) {
    Some(a) => {
      let expected = expr_div(
        expr_mul(expr_sqrt_two(), sqrt_pi()),
        expr_mul(expr_int(2), a),
      )
      if expr_eq(coeff, expected) {
        Some(
          expr_div(
            expr_one(),
            expr_add(expr_pow(a, expr_int(2)), expr_pow(x, expr_int(2))),
          ),
        )
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn inverse_cosine_gaussian_term(
  expr : Expr,
  k_name : String,
  x : Expr,
) -> Expr? {
  let (coeff, factors) = split_mul(expr, k_name)
  if factors.length() != 1 {
    return None
  }
  match factors[0] {
    @symcore.Expr::Function("exp", [inner]) =>
      match parse_negative_quadratic_exp(inner, k_name) {
        Some(scale) => {
          let a = expr_div(expr_one(), expr_mul(expr_int(4), scale))
          let forward_coeff = expr_div(
            expr_sqrt_two(),
            expr_mul(expr_int(2), expr_sqrt_positive(a)),
          )
          let simplified_coeff = expr_mul(
            expr_sqrt_two(),
            expr_sqrt_positive(scale),
          )
          if expr_eq(coeff, forward_coeff) ||
            expr_eq(coeff, simplified_coeff) ||
            expr_eq(expr_pow(coeff, expr_int(2)), expr_mul(expr_int(2), scale)) {
            Some(
              @symelem.exp(
                expr_mul(expr_neg_one(), expr_mul(a, expr_pow(x, expr_int(2)))),
              ),
            )
          } else {
            None
          }
        }
        None => None
      }
    _ => None
  }
}

///|
/// Evaluate a forward Hankel transform of order `nu`.
pub fn do_hankel_doit(expr : Expr, r : Expr, k : Expr, nu : Expr) -> Expr? {
  match symbol_name(r) {
    Some(r_name) => hankel_doit(expr_simplify(expr), r_name, k, nu)
    None => None
  }
}

///|
fn hankel_doit(expr : Expr, r_name : String, k : Expr, nu : Expr) -> Expr? {
  let (coeff, factors) = split_mul(expr, r_name)
  match hankel_mul_term(factors, r_name, k, nu) {
    Some(value) => Some(expr_mul(coeff, value))
    None => None
  }
}

///|
fn hankel_mul_term(
  factors : Array[Expr],
  r_name : String,
  k : Expr,
  nu : Expr,
) -> Expr? {
  match hankel_gaussian_term(factors, r_name, k, nu) {
    Some(value) => return Some(value)
    None => ()
  }
  if factors.length() == 1 {
    return hankel_base_term(factors[0], r_name, k, nu)
  }
  if factors.length() == 2 {
    let mut power : Expr? = None
    let mut decay : Expr? = None
    for factor in factors {
      match parse_power_factor(factor, r_name) {
        Some(p) => power = Some(p)
        None =>
          match factor {
            @symcore.Expr::Function("exp", [inner]) =>
              match parse_negative_linear_exp_raw(inner, r_name) {
                Some(a) => decay = Some(a)
                None => return None
              }
            _ => return None
          }
      }
    }
    match (power, decay) {
      (Some(p), Some(a)) if expr_eq(p, nu) =>
        Some(
          expr_div(
            expr_mul(
              expr_mul(expr_pow(expr_int(2), expr_add(nu, expr_one())), a),
              @symspec.gamma(expr_add(nu, expr_rat(3, 2))),
            ) *
            expr_pow(k, expr_sub(expr_neg_one(), expr_add(nu, expr_int(2)))),
            expr_mul(
              sqrt_pi(),
              expr_pow(
                expr_add(
                  expr_div(expr_pow(a, expr_int(2)), expr_pow(k, expr_int(2))),
                  expr_one(),
                ),
                expr_add(nu, expr_rat(3, 2)),
              ),
            ),
          ),
        )
      _ => None
    }
  } else {
    None
  }
}

///|
fn hankel_gaussian_term(
  factors : Array[Expr],
  r_name : String,
  k : Expr,
  nu : Expr,
) -> Expr? {
  let mut power = expr_zero()
  let mut decay : Expr? = None
  for factor in factors {
    match parse_power_factor(factor, r_name) {
      Some(p) => power = expr_add(power, p)
      None =>
        match factor {
          @symcore.Expr::Function("exp", [inner]) =>
            match parse_negative_quadratic_exp(inner, r_name) {
              Some(a) =>
                if decay is None {
                  decay = Some(a)
                } else {
                  return None
                }
              None => return None
            }
          _ => return None
        }
    }
  }
  match decay {
    Some(a) if expr_eq(power, nu) =>
      Some(
        expr_mul(
          expr_mul(
            expr_pow(k, nu),
            expr_pow(
              expr_div(expr_one(), expr_mul(expr_int(2), a)),
              expr_add(nu, expr_one()),
            ),
          ),
          @symelem.exp(
            expr_div(
              expr_mul(expr_neg_one(), expr_pow(k, expr_int(2))),
              expr_mul(expr_int(4), a),
            ),
          ),
        ),
      )
    _ => None
  }
}

///|
fn hankel_base_term(expr : Expr, r_name : String, k : Expr, nu : Expr) -> Expr? {
  match parse_negative_power(expr, r_name) {
    Some(m) =>
      Some(
        expr_mul(
          expr_pow(expr_int(2), expr_sub(expr_one(), m)),
          expr_div(
            expr_mul(
              expr_pow(k, expr_sub(m, expr_int(2))),
              @symspec.gamma(
                expr_add(
                  expr_sub(expr_one(), expr_div(m, expr_int(2))),
                  expr_div(nu, expr_int(2)),
                ),
              ),
            ),
            @symspec.gamma(
              expr_add(expr_div(m, expr_int(2)), expr_div(nu, expr_int(2))),
            ),
          ),
        ),
      )
    None => None
  }
}

///|
/// Evaluate an inverse Hankel transform of order `nu`.
pub fn do_inverse_hankel_doit(
  expr : Expr,
  k : Expr,
  r : Expr,
  nu : Expr,
) -> Expr? {
  match symbol_name(k) {
    Some(k_name) => inverse_hankel_doit(expr_simplify(expr), k_name, r, nu)
    None => None
  }
}

///|
fn inverse_hankel_doit(
  expr : Expr,
  k_name : String,
  r : Expr,
  nu : Expr,
) -> Expr? {
  if matches_hankel_power_transform(expr, k_name, r, nu) is Some(v) {
    return Some(v)
  }
  match inverse_hankel_gaussian_term(expr, k_name, r, nu) {
    Some(v) => Some(v)
    None => inverse_hankel_exp_term(expr, k_name, r, nu)
  }
}

///|
/// Apply the forward Mellin rule table and return only the transformed value.
///
/// Strip and condition metadata are available through
/// `mellin_transform_result`.
pub fn do_mellin_doit(_expr : Expr, x : Expr, s : Expr) -> Expr? {
  match (symbol_name(x), symbol_name(s)) {
    (Some(x_name), Some(s_name)) =>
      match
        mellin_info_doit(expr_simplify(_expr), x_name, @symcore.symbol(s_name)) {
        Some(info) => Some(info.0)
        None =>
          mellin_doit(expr_simplify(_expr), x_name, @symcore.symbol(s_name))
      }
    _ => None
  }
}

///|
/// Apply the inverse Mellin rule table and return only the recovered value.
pub fn do_inverse_mellin_doit(_expr : Expr, s : Expr, x : Expr) -> Expr? {
  match (symbol_name(s), symbol_name(x)) {
    (Some(s_name), Some(_)) =>
      inverse_mellin_doit(expr_simplify(_expr), s_name, x)
    _ => None
  }
}

///|
/// Evaluate a Mellin transform with optional strip/condition metadata.
///
/// When `noconds=false`, this returns `(value, (left, right), condition)` in
/// the same style as SymPy's `mellin_transform`.
pub fn mellin_transform_result(
  expr : Expr,
  x : Expr,
  s : Expr,
  noconds? : Bool = false,
) -> Expr {
  match (symbol_name(x), symbol_name(s)) {
    (Some(x_name), Some(s_name)) =>
      match
        mellin_info_doit(expr_simplify(expr), x_name, @symcore.symbol(s_name)) {
        Some((value, lower, upper, cond)) =>
          if noconds {
            value
          } else {
            tuple_expr([value, tuple_expr([lower, upper]), cond])
          }
        None => @symcore.raw_function("MellinTransform", [expr, x, s])
      }
    _ => @symcore.raw_function("MellinTransform", [expr, x, s])
  }
}

///|
fn mellin_doit(expr : Expr, x_name : String, s : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Add(terms) =>
      transform_add(terms, x_name, fn(term) { mellin_doit(term, x_name, s) })
    _ => {
      match mellin_special_info(expr, x_name, s) {
        Some((value, _, _, _)) => return Some(value)
        None => ()
      }
      let (coeff, factors) = split_mul(expr, x_name)
      if factors.length() == 0 {
        None
      } else {
        match mellin_mul_term(factors, x_name, s) {
          Some(v) => Some(expr_mul(coeff, v))
          None =>
            if expr_depends_on(expr, x_name) {
              Some(generic_mellin_object(expr, x_name, s))
            } else {
              None
            }
        }
      }
    }
  }
}

///|
fn mellin_info_doit(expr : Expr, x_name : String, s : Expr) -> MellinInfo? {
  match expr {
    @symcore.Expr::Add(terms) => {
      let values : Array[Expr] = []
      let mut lower : Expr? = None
      let mut upper : Expr? = None
      let mut cond = true_expr()
      let mut saw_known = false
      for term in terms {
        match mellin_info_doit(term, x_name, s) {
          Some((value, lo, up, term_cond)) => {
            saw_known = true
            values.push(value)
            lower = Some(
              match lower {
                Some(prev) => max_expr(prev, lo)
                None => lo
              },
            )
            upper = Some(
              match upper {
                Some(prev) => min_expr(prev, up)
                None => up
              },
            )
            cond = and_expr(cond, term_cond)
          }
          None =>
            if expr_depends_on(term, x_name) {
              values.push(generic_mellin_object(term, x_name, s))
            } else {
              return None
            }
        }
      }
      if saw_known {
        Some(
          (
            expr_simplify(@symcore.add(values)),
            lower.unwrap_or(expr_mul(expr_neg_one(), @symcore.oo())),
            upper.unwrap_or(@symcore.oo()),
            cond,
          ),
        )
      } else {
        None
      }
    }
    _ => {
      match mellin_special_info(expr, x_name, s) {
        Some(info) => return Some(info)
        None => ()
      }
      let (coeff, factors) = split_mul(expr, x_name)
      if factors.length() == 0 {
        None
      } else {
        match mellin_mul_info(factors, x_name, s) {
          Some((value, lower, upper, cond)) =>
            Some((expr_mul(coeff, value), lower, upper, cond))
          None => None
        }
      }
    }
  }
}

///|
fn generic_mellin_object(expr : Expr, x_name : String, s : Expr) -> Expr {
  @symcore.raw_function("MellinTransform", [expr, @symcore.symbol(x_name), s])
}

///|
fn mellin_special_info(expr : Expr, x_name : String, s : Expr) -> MellinInfo? {
  match mellin_shifted_power_info(expr, x_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  match mellin_algebraic_info(expr, x_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  match mellin_abs_one_minus_power_info(expr, x_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  match mellin_log_special_info(expr, x_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  match expr {
    @symcore.Expr::Function(
      "erf",
      [@symcore.Expr::Function("sqrt", [@symcore.Expr::Symbol(name)])]
    ) =>
      if name == x_name {
        Some(
          (
            expr_div(
              expr_mul(
                expr_neg_one(),
                @symspec.gamma(expr_add(s, expr_rat(1, 2))),
              ),
              expr_mul(sqrt_pi(), s),
            ),
            expr_mul(expr_neg_one(), expr_rat(1, 2)),
            expr_zero(),
            true_expr(),
          ),
        )
      } else {
        None
      }
    @symcore.Expr::Function("besselj", [order, arg]) =>
      match parse_sqrt_linear(arg, x_name) {
        Some(coeff) =>
          Some(
            (
              expr_mul(
                mellin_bessel_sqrt_scale(coeff, s),
                expr_div(
                  @symspec.gamma(expr_add(s, expr_div(order, expr_int(2)))),
                  @symspec.gamma(
                    expr_add(
                      expr_one(),
                      expr_sub(expr_div(order, expr_int(2)), s),
                    ),
                  ),
                ),
              ),
              expr_div(
                expr_mul(expr_neg_one(), @symelem.re(order)),
                expr_int(2),
              ),
              expr_rat(3, 4),
              true_expr(),
            ),
          )
        None => None
      }
    @symcore.Expr::Function("bessely", [order, arg]) =>
      match parse_sqrt_linear(arg, x_name) {
        Some(coeff) => {
          let half_order = expr_div(order, expr_int(2))
          Some(
            (
              expr_mul(
                mellin_bessel_sqrt_scale(coeff, s),
                expr_div(
                  expr_mul(
                    expr_neg_one(),
                    expr_mul(
                      @symelem.cos(
                        expr_mul(@symcore.pi(), expr_sub(half_order, s)),
                      ),
                      expr_mul(
                        @symspec.gamma(expr_sub(s, half_order)),
                        @symspec.gamma(expr_add(s, half_order)),
                      ),
                    ),
                  ),
                  @symcore.pi(),
                ),
              ),
              max_expr(
                expr_div(
                  expr_mul(expr_neg_one(), @symelem.re(order)),
                  expr_int(2),
                ),
                expr_div(@symelem.re(order), expr_int(2)),
              ),
              expr_rat(3, 4),
              true_expr(),
            ),
          )
        }
        None => None
      }
    @symcore.Expr::Function("besselk", [order, arg]) =>
      match parse_sqrt_linear(arg, x_name) {
        Some(coeff) => {
          let half_order = expr_div(order, expr_int(2))
          Some(
            (
              expr_mul(
                mellin_bessel_sqrt_scale(coeff, s),
                expr_div(
                  expr_mul(
                    @symspec.gamma(expr_sub(s, half_order)),
                    @symspec.gamma(expr_add(s, half_order)),
                  ),
                  expr_int(2),
                ),
              ),
              max_expr(
                expr_div(
                  expr_mul(expr_neg_one(), @symelem.re(order)),
                  expr_int(2),
                ),
                expr_div(@symelem.re(order), expr_int(2)),
              ),
              @symcore.oo(),
              true_expr(),
            ),
          )
        }
        None => None
      }
    @symcore.Expr::Function("E1", [@symcore.Expr::Symbol(name)]) =>
      if name == x_name {
        Some(
          (
            expr_div(@symspec.gamma(s), s),
            expr_zero(),
            @symcore.oo(),
            true_expr(),
          ),
        )
      } else {
        None
      }
    @symcore.Expr::Function("expint", [n, @symcore.Expr::Symbol(name)]) =>
      if name == x_name && expr_is_constant(n, x_name) {
        Some(
          (
            expr_div(@symspec.gamma(s), expr_sub(expr_add(n, s), expr_one())),
            max_expr(expr_sub(expr_one(), n), expr_zero()),
            @symcore.oo(),
            true_expr(),
          ),
        )
      } else {
        None
      }
    @symcore.Expr::Function("Si", [@symcore.Expr::Symbol(name)]) =>
      if name == x_name {
        Some(
          (
            expr_div(
              expr_mul(
                expr_neg_one(),
                expr_mul(
                  expr_pow(expr_int(2), s),
                  expr_mul(
                    sqrt_pi(),
                    @symspec.gamma(
                      expr_div(expr_add(s, expr_one()), expr_int(2)),
                    ),
                  ),
                ),
              ),
              expr_mul(
                expr_int(2),
                expr_mul(
                  s,
                  @symspec.gamma(expr_sub(expr_one(), expr_div(s, expr_int(2)))),
                ),
              ),
            ),
            expr_int(-1),
            expr_zero(),
            true_expr(),
          ),
        )
      } else {
        None
      }
    @symcore.Expr::Function(
      "Ci",
      [@symcore.Expr::Function("sqrt", [@symcore.Expr::Symbol(name)])]
    ) =>
      if name == x_name {
        Some(
          (
            expr_div(
              expr_mul(
                expr_neg_one(),
                expr_mul(
                  expr_pow(
                    expr_int(2),
                    expr_sub(expr_mul(expr_int(2), s), expr_one()),
                  ),
                  expr_mul(sqrt_pi(), @symspec.gamma(s)),
                ),
              ),
              expr_mul(s, @symspec.gamma(expr_sub(expr_rat(1, 2), s))),
            ),
            expr_zero(),
            expr_one(),
            true_expr(),
          ),
        )
      } else {
        None
      }
    _ => None
  }
}

///|
fn mellin_algebraic_info(expr : Expr, x_name : String, s : Expr) -> MellinInfo? {
  match mellin_difference_quotient_info(expr, x_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  mellin_sqrt_shifted_power_info(expr, x_name, s)
}

///|
fn mellin_difference_quotient_info(
  expr : Expr,
  x_name : String,
  s : Expr,
) -> MellinInfo? {
  match parse_difference_quotient(expr, x_name) {
    Some((power, scale)) =>
      Some(
        (
          expr_simplify(
            expr_div(
              expr_mul(
                @symcore.pi(),
                expr_mul(
                  expr_pow(scale, expr_add(expr_sub(power, expr_one()), s)),
                  @symelem.sin(expr_mul(@symcore.pi(), power)),
                ),
              ),
              expr_mul(
                @symelem.sin(expr_mul(@symcore.pi(), s)),
                @symelem.sin(expr_mul(@symcore.pi(), expr_add(power, s))),
              ),
            ),
          ),
          max_expr(expr_zero(), expr_mul(expr_neg_one(), @symelem.re(power))),
          min_expr(expr_one(), expr_sub(expr_one(), @symelem.re(power))),
          true_expr(),
        ),
      )
    None => None
  }
}

///|
fn mellin_sqrt_shifted_power_info(
  expr : Expr,
  x_name : String,
  s : Expr,
) -> MellinInfo? {
  match parse_sqrt_shifted_power_expr(expr, x_name) {
    Some((scale, _shift_sq, power, with_recip_sqrt)) => {
      let scale_pow = if with_recip_sqrt {
        expr_sub(expr_add(power, expr_mul(expr_int(2), s)), expr_one())
      } else {
        expr_add(power, expr_mul(expr_int(2), s))
      }
      let gamma_arg = if with_recip_sqrt {
        expr_sub(expr_one(), expr_add(power, expr_mul(expr_int(2), s)))
      } else {
        expr_mul(expr_neg_one(), expr_add(power, expr_mul(expr_int(2), s)))
      }
      let numerator = expr_mul(
        expr_pow(expr_int(2), expr_add(power, expr_mul(expr_int(2), s))),
        expr_mul(
          expr_pow(scale, scale_pow),
          expr_mul(@symspec.gamma(s), @symspec.gamma(gamma_arg)),
        ),
      )
      let value = if with_recip_sqrt {
        expr_div(
          numerator,
          @symspec.gamma(expr_sub(expr_one(), expr_add(power, s))),
        )
      } else {
        expr_mul(
          expr_neg_one(),
          expr_div(
            expr_mul(power, numerator),
            @symspec.gamma(expr_sub(expr_one(), expr_add(power, s))),
          ),
        )
      }
      let upper = if with_recip_sqrt {
        expr_add(
          expr_mul(expr_neg_one(), expr_div(@symelem.re(power), expr_int(2))),
          expr_rat(1, 2),
        )
      } else {
        expr_mul(expr_neg_one(), expr_div(@symelem.re(power), expr_int(2)))
      }
      Some((expr_simplify(value), expr_zero(), upper, true_expr()))
    }
    None => None
  }
}

///|
fn mellin_abs_one_minus_power_info(
  expr : Expr,
  x_name : String,
  s : Expr,
) -> MellinInfo? {
  match expr_simplify(expr) {
    @symcore.Expr::Pow(@symcore.Expr::Function("Abs", [arg]), exp) =>
      match
        (
          parse_one_minus_linear(arg, x_name),
          extract_explicit_negative_factor(exp),
        ) {
        (true, Some(rho)) =>
          Some(
            (
              expr_div(
                expr_mul(
                  expr_int(2),
                  expr_mul(
                    @symelem.sin(
                      expr_div(expr_mul(@symcore.pi(), rho), expr_int(2)),
                    ),
                    expr_mul(
                      @symspec.gamma(expr_sub(expr_one(), rho)),
                      expr_mul(
                        @symelem.cos(
                          expr_mul(
                            @symcore.pi(),
                            expr_sub(s, expr_div(rho, expr_int(2))),
                          ),
                        ),
                        expr_mul(
                          @symspec.gamma(s),
                          @symspec.gamma(expr_sub(rho, s)),
                        ),
                      ),
                    ),
                  ),
                ),
                @symcore.pi(),
              ),
              expr_zero(),
              @symelem.re(rho),
              @symcore.function("Lt", [@symelem.re(rho), expr_one()]),
            ),
          )
        _ => None
      }
    _ => None
  }
}

///|
fn mellin_log_special_info(
  expr : Expr,
  x_name : String,
  s : Expr,
) -> MellinInfo? {
  match expr {
    @symcore.Expr::Function("log", [inner]) =>
      if parse_one_plus_linear(inner, x_name) {
        Some(
          (
            expr_div(
              @symcore.pi(),
              expr_mul(s, @symelem.sin(expr_mul(@symcore.pi(), s))),
            ),
            expr_int(-1),
            expr_zero(),
            true_expr(),
          ),
        )
      } else if parse_one_plus_inverse(inner, x_name) {
        Some(
          (
            expr_div(
              @symcore.pi(),
              expr_mul(s, @symelem.sin(expr_mul(@symcore.pi(), s))),
            ),
            expr_zero(),
            expr_one(),
            true_expr(),
          ),
        )
      } else if parse_abs_one_minus_linear(inner, x_name) {
        Some(
          (
            expr_div(
              @symcore.pi(),
              expr_mul(s, @symelem.tan(expr_mul(@symcore.pi(), s))),
            ),
            expr_int(-1),
            expr_zero(),
            true_expr(),
          ),
        )
      } else if parse_abs_one_minus_inverse(inner, x_name) {
        Some(
          (
            expr_div(
              @symcore.pi(),
              expr_mul(s, @symelem.tan(expr_mul(@symcore.pi(), s))),
            ),
            expr_zero(),
            expr_one(),
            true_expr(),
          ),
        )
      } else {
        None
      }
    _ => None
  }
}

///|
fn mellin_shifted_power_info(
  expr : Expr,
  x_name : String,
  s : Expr,
) -> MellinInfo? {
  match parse_shifted_linear_power(expr, x_name) {
    Some((coeff, offset, exp)) if expr_is_one(coeff) && expr_is_one(offset) =>
      match extract_explicit_negative_factor(exp) {
        Some(rho) =>
          Some(
            (
              expr_div(
                expr_mul(@symspec.gamma(s), @symspec.gamma(expr_sub(rho, s))),
                @symspec.gamma(rho),
              ),
              expr_zero(),
              @symelem.re(rho),
              true_expr(),
            ),
          )
        None => None
      }
    _ => None
  }
}

///|
fn mellin_bessel_sqrt_scale(coeff : Expr, s : Expr) -> Expr {
  if expr_eq(coeff, expr_int(2)) {
    expr_one()
  } else {
    expr_pow(expr_div(expr_int(4), expr_pow(coeff, expr_int(2))), s)
  }
}

///|
fn mellin_mul_term(factors : Array[Expr], x_name : String, s : Expr) -> Expr? {
  match mellin_log_heaviside_info(factors, x_name, s) {
    Some((value, _, _, _)) => return Some(value)
    None => ()
  }
  match mellin_trig_bessel_info(factors, x_name, s) {
    Some((value, _, _, _)) => return Some(value)
    None => ()
  }
  match mellin_beta_heaviside_info(factors, x_name, s) {
    Some((value, _, _, _)) => return Some(value)
    None => ()
  }
  match mellin_besselj_product_info(factors, x_name, s) {
    Some((value, _, _, _)) => return Some(value)
    None => ()
  }
  match mellin_besselj_bessely_product_info(factors, x_name, s) {
    Some((value, _, _, _)) => return Some(value)
    None => ()
  }
  match mellin_besseli_besselk_product_info(factors, x_name, s) {
    Some((value, _, _, _)) => return Some(value)
    None => ()
  }
  let mut pow_opt : Expr? = None
  let mut exp_opt : (Expr, Int)? = None
  let mut heav_opt : (Expr, Bool)? = None
  let mut other_count = 0
  for factor in factors {
    match factor {
      @symcore.Expr::Function("exp", [inner]) =>
        match parse_mellin_exp(inner, x_name) {
          Some((coef, degree)) =>
            if exp_opt is None {
              exp_opt = Some((coef, degree))
            } else {
              return None
            }
          None => return None
        }
      @symcore.Expr::Function("Heaviside", [arg]) =>
        match parse_heaviside_limit(arg, x_name) {
          Some((bound, is_le)) =>
            if heav_opt is None {
              heav_opt = Some((bound, is_le))
            } else {
              return None
            }
          None => other_count += 1
        }
      _ =>
        match parse_power_factor(factor, x_name) {
          Some(p) =>
            match pow_opt {
              None => pow_opt = Some(p)
              Some(prev) => pow_opt = Some(expr_add(prev, p))
            }
          None => other_count += 1
        }
    }
  }
  if other_count != 0 {
    return None
  }
  let pow = match pow_opt {
    Some(v) => v
    None => expr_zero()
  }
  match (exp_opt, heav_opt) {
    (Some((coef, degree)), None) =>
      Some(mellin_exp_formula(pow, coef, degree, s))
    (None, Some((bound, is_le))) =>
      Some(mellin_heaviside_term(pow, bound, is_le, s))
    _ => None
  }
}

///|
fn mellin_mul_info(
  factors : Array[Expr],
  x_name : String,
  s : Expr,
) -> MellinInfo? {
  match mellin_log_heaviside_info(factors, x_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  match mellin_trig_bessel_info(factors, x_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  match mellin_beta_heaviside_info(factors, x_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  match mellin_besselj_product_info(factors, x_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  match mellin_besselj_bessely_product_info(factors, x_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  match mellin_besseli_besselk_product_info(factors, x_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  let mut pow_opt : Expr? = None
  let mut exp_opt : (Expr, Int)? = None
  let mut heav_opt : (Expr, Bool)? = None
  let mut other_count = 0
  for factor in factors {
    match factor {
      @symcore.Expr::Function("exp", [inner]) =>
        match parse_mellin_exp(inner, x_name) {
          Some((coef, degree)) =>
            if exp_opt is None {
              exp_opt = Some((coef, degree))
            } else {
              return None
            }
          None => return None
        }
      @symcore.Expr::Function("Heaviside", [arg]) =>
        match parse_heaviside_limit(arg, x_name) {
          Some((bound, is_le)) =>
            if heav_opt is None {
              heav_opt = Some((bound, is_le))
            } else {
              return None
            }
          None => other_count += 1
        }
      _ =>
        match parse_power_factor(factor, x_name) {
          Some(p) =>
            match pow_opt {
              None => pow_opt = Some(p)
              Some(prev) => pow_opt = Some(expr_add(prev, p))
            }
          None => other_count += 1
        }
    }
  }
  if other_count != 0 {
    return None
  }
  let pow = pow_opt.unwrap_or(expr_zero())
  match (exp_opt, heav_opt) {
    (Some((coef, degree)), None) => mellin_exp_info(pow, coef, degree, s)
    (None, Some((bound, is_le))) => {
      let value = mellin_heaviside_term(pow, bound, is_le, s)
      if is_le {
        Some((value, expr_mul(expr_neg_one(), pow), @symcore.oo(), true_expr()))
      } else {
        Some(
          (
            value,
            expr_mul(expr_neg_one(), @symcore.oo()),
            expr_mul(expr_neg_one(), pow),
            true_expr(),
          ),
        )
      }
    }
    _ => None
  }
}

///|
fn mellin_beta_heaviside_info(
  factors : Array[Expr],
  x_name : String,
  s : Expr,
) -> MellinInfo? {
  if factors.length() != 2 {
    return None
  }
  let mut power_data : (Expr, Expr, Expr)? = None
  let mut heav_data : (Expr, Bool)? = None
  for factor in factors {
    match factor {
      @symcore.Expr::Function("Heaviside", [arg]) =>
        match parse_heaviside_limit(arg, x_name) {
          Some(info) =>
            if heav_data is None {
              heav_data = Some(info)
            } else {
              return None
            }
          None => return None
        }
      _ =>
        match parse_shifted_linear_power(factor, x_name) {
          Some(info) =>
            if power_data is None {
              power_data = Some(info)
            } else {
              return None
            }
          None => return None
        }
    }
  }
  match (power_data, heav_data) {
    (Some((pow_coeff, pow_offset, exp)), Some((bound, is_le))) =>
      if expr_is_one(bound) &&
        expr_is_minus_one(pow_coeff) &&
        expr_is_one(pow_offset) &&
        is_le {
        let beta = expr_add(exp, expr_one())
        Some(
          (
            expr_div(
              expr_mul(@symspec.gamma(beta), @symspec.gamma(s)),
              @symspec.gamma(expr_add(beta, s)),
            ),
            expr_zero(),
            @symcore.oo(),
            @symcore.function("Gt", [@symelem.re(beta), expr_zero()]),
          ),
        )
      } else if expr_is_one(bound) &&
        expr_is_one(pow_coeff) &&
        expr_is_minus_one(pow_offset) &&
        !is_le {
        let beta = expr_add(exp, expr_one())
        Some(
          (
            expr_div(
              expr_mul(
                @symspec.gamma(beta),
                @symspec.gamma(expr_sub(expr_sub(expr_one(), beta), s)),
              ),
              @symspec.gamma(expr_sub(expr_one(), s)),
            ),
            neg_oo_expr(),
            expr_sub(expr_one(), @symelem.re(beta)),
            @symcore.function("Gt", [@symelem.re(beta), expr_zero()]),
          ),
        )
      } else {
        None
      }
    _ => None
  }
}

///|
fn mellin_log_heaviside_info(
  factors : Array[Expr],
  x_name : String,
  s : Expr,
) -> MellinInfo? {
  if factors.length() != 2 {
    return None
  }
  let mut power : Int? = None
  let mut heav : (Expr, Bool)? = None
  for factor in factors {
    match factor {
      @symcore.Expr::Function("Heaviside", [arg]) =>
        match parse_heaviside_limit(arg, x_name) {
          Some(info) =>
            if heav is None {
              heav = Some(info)
            } else {
              return None
            }
          None => return None
        }
      _ =>
        match parse_log_x_power(factor, x_name) {
          Some(n) => if power is None { power = Some(n) } else { return None }
          None => return None
        }
    }
  }
  match (power, heav) {
    (Some(n), Some((bound, is_le))) if expr_is_one(bound) => {
      let sign = if is_le {
        if n % 2 == 0 {
          expr_one()
        } else {
          expr_neg_one()
        }
      } else if n % 2 == 0 {
        expr_neg_one()
      } else {
        expr_one()
      }
      let value = expr_mul(
        sign,
        expr_mul(factorial_expr(expr_int(n)), expr_pow(s, expr_int(-(n + 1)))),
      )
      if is_le {
        Some((value, expr_zero(), @symcore.oo(), true_expr()))
      } else {
        Some((value, neg_oo_expr(), expr_zero(), true_expr()))
      }
    }
    _ => None
  }
}

///|
fn mellin_trig_bessel_info(
  factors : Array[Expr],
  x_name : String,
  s : Expr,
) -> MellinInfo? {
  if factors.length() != 2 {
    return None
  }
  let mut trig_name : String? = None
  let mut trig_coeff : Expr? = None
  let mut bessel_kind : String? = None
  let mut bessel_order : Expr? = None
  let mut bessel_coeff : Expr? = None
  for factor in factors {
    match factor {
      @symcore.Expr::Function("sin", [arg]) =>
        match parse_sqrt_linear(arg, x_name) {
          Some(coeff) =>
            if trig_name is None {
              trig_name = Some("sin")
              trig_coeff = Some(coeff)
            } else {
              return None
            }
          None => return None
        }
      @symcore.Expr::Function("cos", [arg]) =>
        match parse_sqrt_linear(arg, x_name) {
          Some(coeff) =>
            if trig_name is None {
              trig_name = Some("cos")
              trig_coeff = Some(coeff)
            } else {
              return None
            }
          None => return None
        }
      @symcore.Expr::Function("besselj", [order, arg]) =>
        match parse_sqrt_linear(arg, x_name) {
          Some(coeff) =>
            if bessel_kind is None {
              bessel_kind = Some("besselj")
              bessel_order = Some(order)
              bessel_coeff = Some(coeff)
            } else {
              return None
            }
          None => return None
        }
      @symcore.Expr::Function("bessely", [order, arg]) =>
        match parse_sqrt_linear(arg, x_name) {
          Some(coeff) =>
            if bessel_kind is None {
              bessel_kind = Some("bessely")
              bessel_order = Some(order)
              bessel_coeff = Some(coeff)
            } else {
              return None
            }
          None => return None
        }
      _ => return None
    }
  }
  match (trig_name, trig_coeff, bessel_kind, bessel_order, bessel_coeff) {
    (Some(trig), Some(coeff1), Some(kind), Some(order), Some(coeff2)) =>
      if !expr_eq(coeff1, coeff2) {
        None
      } else {
        let scale = mellin_bessel_pair_scale(coeff1, s)
        let half_order = expr_div(order, expr_int(2))
        let common_strip = max_expr(
          expr_div(expr_mul(expr_neg_one(), @symelem.re(order)), expr_int(2)),
          expr_div(@symelem.re(order), expr_int(2)),
        )
        match (trig, kind) {
          ("sin", "besselj") =>
            Some(
              (
                expr_mul(
                  scale,
                  expr_div(
                    expr_mul(
                      expr_pow(expr_int(2), order),
                      expr_mul(
                        @symspec.gamma(
                          expr_sub(expr_rat(1, 2), expr_mul(expr_int(2), s)),
                        ),
                        @symspec.gamma(
                          expr_add(half_order, expr_add(s, expr_rat(1, 2))),
                        ),
                      ),
                    ),
                    expr_mul(
                      @symspec.gamma(
                        expr_add(
                          expr_mul(expr_neg_one(), half_order),
                          expr_sub(expr_one(), s),
                        ),
                      ),
                      @symspec.gamma(
                        expr_add(
                          order,
                          expr_sub(expr_one(), expr_mul(expr_int(2), s)),
                        ),
                      ),
                    ),
                  ),
                ),
                expr_sub(
                  expr_div(
                    expr_mul(expr_neg_one(), @symelem.re(order)),
                    expr_int(2),
                  ),
                  expr_rat(1, 2),
                ),
                expr_rat(1, 4),
                true_expr(),
              ),
            )
          ("cos", "besselj") =>
            Some(
              (
                expr_mul(
                  scale,
                  expr_div(
                    expr_mul(
                      expr_pow(expr_int(2), order),
                      expr_mul(
                        @symspec.gamma(expr_add(half_order, s)),
                        @symspec.gamma(
                          expr_sub(expr_rat(1, 2), expr_mul(expr_int(2), s)),
                        ),
                      ),
                    ),
                    expr_mul(
                      @symspec.gamma(
                        expr_add(
                          expr_sub(expr_rat(1, 2), half_order),
                          expr_mul(expr_neg_one(), s),
                        ),
                      ),
                      @symspec.gamma(
                        expr_add(
                          order,
                          expr_sub(expr_one(), expr_mul(expr_int(2), s)),
                        ),
                      ),
                    ),
                  ),
                ),
                expr_div(
                  expr_mul(expr_neg_one(), @symelem.re(order)),
                  expr_int(2),
                ),
                expr_rat(1, 4),
                true_expr(),
              ),
            )
          ("sin", "bessely") =>
            Some(
              (
                expr_mul(
                  scale,
                  expr_div(
                    expr_mul(
                      expr_neg_one(),
                      expr_mul(
                        expr_pow(expr_int(4), s),
                        expr_mul(
                          @symelem.sin(
                            expr_mul(@symcore.pi(), expr_sub(half_order, s)),
                          ),
                          expr_mul(
                            @symspec.gamma(
                              expr_sub(expr_rat(1, 2), expr_mul(expr_int(2), s)),
                            ),
                            expr_mul(
                              @symspec.gamma(
                                expr_add(
                                  expr_div(
                                    expr_sub(expr_one(), order),
                                    expr_int(2),
                                  ),
                                  s,
                                ),
                              ),
                              @symspec.gamma(
                                expr_add(
                                  expr_div(
                                    expr_add(expr_one(), order),
                                    expr_int(2),
                                  ),
                                  s,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    expr_mul(
                      sqrt_pi(),
                      expr_mul(
                        @symspec.gamma(
                          expr_sub(expr_one(), expr_add(s, half_order)),
                        ),
                        @symspec.gamma(
                          expr_add(expr_sub(expr_one(), s), half_order),
                        ),
                      ),
                    ),
                  ),
                ),
                max_expr(
                  expr_div(
                    expr_sub(
                      expr_mul(expr_neg_one(), @symelem.re(order)),
                      expr_one(),
                    ),
                    expr_int(2),
                  ),
                  expr_div(
                    expr_sub(@symelem.re(order), expr_one()),
                    expr_int(2),
                  ),
                ),
                expr_rat(1, 4),
                true_expr(),
              ),
            )
          ("cos", "bessely") =>
            Some(
              (
                expr_mul(
                  scale,
                  expr_div(
                    expr_mul(
                      expr_neg_one(),
                      expr_mul(
                        expr_pow(expr_int(4), s),
                        expr_mul(
                          @symelem.cos(
                            expr_mul(@symcore.pi(), expr_sub(half_order, s)),
                          ),
                          expr_mul(
                            @symspec.gamma(expr_sub(s, half_order)),
                            expr_mul(
                              @symspec.gamma(expr_add(s, half_order)),
                              @symspec.gamma(
                                expr_sub(
                                  expr_rat(1, 2),
                                  expr_mul(expr_int(2), s),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    expr_mul(
                      sqrt_pi(),
                      expr_mul(
                        @symspec.gamma(
                          expr_sub(expr_rat(1, 2), expr_add(s, half_order)),
                        ),
                        @symspec.gamma(
                          expr_add(expr_sub(expr_rat(1, 2), s), half_order),
                        ),
                      ),
                    ),
                  ),
                ),
                common_strip,
                expr_rat(1, 4),
                true_expr(),
              ),
            )
          _ => None
        }
      }
    _ => None
  }
}

///|
fn normalize_bessel_product_factors(factors : Array[Expr]) -> Array[Expr]? {
  let items : Array[Expr] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Pow(base, exp) if expr_eq(exp, expr_int(2)) => {
        items.push(base)
        items.push(base)
      }
      _ => items.push(factor)
    }
  }
  if items.length() == 2 {
    Some(items)
  } else {
    None
  }
}

///|
fn mellin_bessel_pair_scale(coeff : Expr, s : Expr) -> Expr {
  if expr_eq(coeff, expr_one()) {
    expr_one()
  } else {
    expr_pow(expr_pow(coeff, expr_int(2)), expr_mul(expr_neg_one(), s))
  }
}

///|
fn parse_besselj_pair(
  factors : Array[Expr],
  x_name : String,
) -> ((Expr, Expr), Expr)? {
  let normalized = match normalize_bessel_product_factors(factors) {
    Some(items) => items
    None => return None
  }
  let mut first : (Expr, Expr)? = None
  let mut second : (Expr, Expr)? = None
  for factor in normalized {
    match factor {
      @symcore.Expr::Function("besselj", [order, arg]) =>
        match parse_sqrt_linear(arg, x_name) {
          Some(coeff) =>
            if first is None {
              first = Some((order, coeff))
            } else if second is None {
              second = Some((order, coeff))
            } else {
              return None
            }
          None => return None
        }
      _ => return None
    }
  }
  match (first, second) {
    (Some((order1, coeff1)), Some((order2, coeff2))) if expr_eq(coeff1, coeff2) =>
      Some(((order1, order2), coeff1))
    _ => None
  }
}

///|
fn mellin_besselj_product_info(
  factors : Array[Expr],
  x_name : String,
  s : Expr,
) -> MellinInfo? {
  match parse_besselj_pair(factors, x_name) {
    Some(((order1, order2), coeff)) => {
      let scale = mellin_bessel_pair_scale(coeff, s)
      if expr_eq(order1, order2) {
        Some(
          (
            expr_mul(
              scale,
              expr_div(
                expr_mul(
                  @symspec.gamma(expr_add(order1, s)),
                  @symspec.gamma(expr_sub(expr_rat(1, 2), s)),
                ),
                expr_mul(
                  sqrt_pi(),
                  expr_mul(
                    @symspec.gamma(expr_sub(expr_one(), s)),
                    @symspec.gamma(expr_add(expr_sub(order1, s), expr_one())),
                  ),
                ),
              ),
            ),
            expr_mul(expr_neg_one(), @symelem.re(order1)),
            expr_rat(1, 2),
            true_expr(),
          ),
        )
      } else if expr_eq(order2, expr_mul(expr_neg_one(), order1)) {
        Some(
          (
            expr_mul(
              scale,
              expr_div(
                expr_mul(
                  @symspec.gamma(s),
                  @symspec.gamma(expr_sub(expr_rat(1, 2), s)),
                ),
                expr_mul(
                  sqrt_pi(),
                  expr_mul(
                    @symspec.gamma(
                      expr_add(
                        expr_mul(expr_neg_one(), order1),
                        expr_sub(expr_one(), s),
                      ),
                    ),
                    @symspec.gamma(expr_add(order1, expr_sub(expr_one(), s))),
                  ),
                ),
              ),
            ),
            expr_zero(),
            expr_rat(1, 2),
            true_expr(),
          ),
        )
      } else if expr_eq(order1, expr_mul(expr_neg_one(), order2)) {
        Some(
          (
            expr_mul(
              scale,
              expr_div(
                expr_mul(
                  @symspec.gamma(s),
                  @symspec.gamma(expr_sub(expr_rat(1, 2), s)),
                ),
                expr_mul(
                  sqrt_pi(),
                  expr_mul(
                    @symspec.gamma(
                      expr_add(
                        expr_mul(expr_neg_one(), order2),
                        expr_sub(expr_one(), s),
                      ),
                    ),
                    @symspec.gamma(expr_add(order2, expr_sub(expr_one(), s))),
                  ),
                ),
              ),
            ),
            expr_zero(),
            expr_rat(1, 2),
            true_expr(),
          ),
        )
      } else {
        Some(
          (
            expr_mul(
              scale,
              expr_div(
                expr_mul(
                  expr_pow(expr_int(4), s),
                  expr_mul(
                    @symspec.gamma(
                      expr_sub(expr_one(), expr_mul(expr_int(2), s)),
                    ),
                    @symspec.gamma(
                      expr_add(
                        expr_div(expr_add(order1, order2), expr_int(2)),
                        s,
                      ),
                    ),
                  ),
                ),
                expr_mul(
                  @symspec.gamma(
                    expr_add(
                      expr_sub(expr_one(), s),
                      expr_div(expr_sub(order2, order1), expr_int(2)),
                    ),
                  ),
                  expr_mul(
                    @symspec.gamma(
                      expr_add(
                        expr_sub(expr_one(), s),
                        expr_div(expr_sub(order1, order2), expr_int(2)),
                      ),
                    ),
                    @symspec.gamma(
                      expr_add(
                        expr_sub(expr_one(), s),
                        expr_div(expr_add(order1, order2), expr_int(2)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            expr_div(
              expr_mul(
                expr_neg_one(),
                expr_add(@symelem.re(order1), @symelem.re(order2)),
              ),
              expr_int(2),
            ),
            expr_rat(1, 2),
            true_expr(),
          ),
        )
      }
    }
    None => None
  }
}

///|
fn mellin_besselj_bessely_product_info(
  factors : Array[Expr],
  x_name : String,
  s : Expr,
) -> MellinInfo? {
  let normalized = match normalize_bessel_product_factors(factors) {
    Some(items) => items
    None => return None
  }
  let mut j_data : (Expr, Expr)? = None
  let mut y_data : (Expr, Expr)? = None
  for factor in normalized {
    match factor {
      @symcore.Expr::Function("besselj", [order, arg]) =>
        match parse_sqrt_linear(arg, x_name) {
          Some(coeff) =>
            if j_data is None {
              j_data = Some((order, coeff))
            } else {
              return None
            }
          None => return None
        }
      @symcore.Expr::Function("bessely", [order, arg]) =>
        match parse_sqrt_linear(arg, x_name) {
          Some(coeff) =>
            if y_data is None {
              y_data = Some((order, coeff))
            } else {
              return None
            }
          None => return None
        }
      _ => return None
    }
  }
  match (j_data, y_data) {
    (Some((order_j, coeff_j)), Some((order_y, coeff_y))) =>
      if expr_eq(order_j, order_y) && expr_eq(coeff_j, coeff_y) {
        let scale = mellin_bessel_pair_scale(coeff_j, s)
        Some(
          (
            expr_mul(
              scale,
              expr_div(
                expr_mul(
                  expr_neg_one(),
                  expr_mul(
                    @symelem.cos(expr_mul(@symcore.pi(), s)),
                    expr_mul(
                      @symspec.gamma(s),
                      expr_mul(
                        @symspec.gamma(expr_add(order_j, s)),
                        @symspec.gamma(expr_sub(expr_rat(1, 2), s)),
                      ),
                    ),
                  ),
                ),
                expr_mul(
                  expr_mul(@symcore.pi(), sqrt_pi()),
                  @symspec.gamma(expr_add(expr_sub(order_j, s), expr_one())),
                ),
              ),
            ),
            max_expr(
              expr_mul(expr_neg_one(), @symelem.re(order_j)),
              expr_zero(),
            ),
            expr_rat(1, 2),
            true_expr(),
          ),
        )
      } else if expr_eq(coeff_j, coeff_y) {
        let scale = mellin_bessel_pair_scale(coeff_j, s)
        let half_diff = expr_div(expr_sub(order_j, order_y), expr_int(2))
        let half_sum = expr_div(expr_add(order_j, order_y), expr_int(2))
        Some(
          (
            expr_mul(
              scale,
              expr_div(
                expr_mul(
                  expr_neg_one(),
                  expr_mul(
                    expr_pow(expr_int(4), s),
                    expr_mul(
                      @symelem.cos(
                        expr_mul(@symcore.pi(), expr_add(half_diff, s)),
                      ),
                      expr_mul(
                        @symspec.gamma(
                          expr_sub(expr_one(), expr_mul(expr_int(2), s)),
                        ),
                        expr_mul(
                          @symspec.gamma(expr_add(half_diff, s)),
                          @symspec.gamma(expr_add(half_sum, s)),
                        ),
                      ),
                    ),
                  ),
                ),
                expr_mul(
                  @symcore.pi(),
                  expr_mul(
                    @symspec.gamma(expr_add(expr_sub(expr_one(), s), half_diff)),
                    @symspec.gamma(expr_add(expr_sub(expr_one(), s), half_sum)),
                  ),
                ),
              ),
            ),
            max_expr(
              expr_div(
                expr_sub(@symelem.re(order_y), @symelem.re(order_j)),
                expr_int(2),
              ),
              expr_div(
                expr_mul(
                  expr_neg_one(),
                  expr_add(@symelem.re(order_j), @symelem.re(order_y)),
                ),
                expr_int(2),
              ),
            ),
            expr_rat(1, 2),
            true_expr(),
          ),
        )
      } else {
        None
      }
    _ => None
  }
}

///|
fn mellin_besseli_besselk_product_info(
  factors : Array[Expr],
  x_name : String,
  s : Expr,
) -> MellinInfo? {
  let normalized = match normalize_bessel_product_factors(factors) {
    Some(items) => items
    None => return None
  }
  let mut order_i : Expr? = None
  let mut coeff_i : Expr? = None
  let mut order_k : Expr? = None
  let mut coeff_k : Expr? = None
  for factor in normalized {
    match factor {
      @symcore.Expr::Function("besseli", [order, arg]) =>
        match parse_sqrt_linear(arg, x_name) {
          Some(coeff) =>
            if order_i is None {
              order_i = Some(order)
              coeff_i = Some(coeff)
            } else {
              return None
            }
          None => return None
        }
      @symcore.Expr::Function("besselk", [order, arg]) =>
        match parse_sqrt_linear(arg, x_name) {
          Some(coeff) =>
            if order_k is None {
              order_k = Some(order)
              coeff_k = Some(coeff)
            } else {
              return None
            }
          None => return None
        }
      _ => return None
    }
  }
  match (order_i, coeff_i, order_k, coeff_k) {
    (Some(order1), Some(coeff1), Some(order2), Some(coeff2)) =>
      if expr_eq(order1, order2) && expr_eq(coeff1, coeff2) {
        let scale = mellin_bessel_pair_scale(coeff1, s)
        Some(
          (
            expr_mul(
              scale,
              expr_div(
                expr_mul(
                  @symspec.gamma(s),
                  expr_mul(
                    @symspec.gamma(expr_add(order1, s)),
                    @symspec.gamma(expr_sub(expr_rat(1, 2), s)),
                  ),
                ),
                expr_mul(
                  expr_int(2),
                  expr_mul(
                    sqrt_pi(),
                    @symspec.gamma(expr_add(expr_sub(order1, s), expr_one())),
                  ),
                ),
              ),
            ),
            max_expr(expr_mul(expr_neg_one(), @symelem.re(order1)), expr_zero()),
            expr_rat(1, 2),
            true_expr(),
          ),
        )
      } else if expr_eq(coeff1, coeff2) {
        let scale = mellin_bessel_pair_scale(coeff1, s)
        let half_diff = expr_div(expr_sub(order1, order2), expr_int(2))
        let half_sum = expr_div(expr_add(order1, order2), expr_int(2))
        Some(
          (
            expr_mul(
              scale,
              expr_div(
                expr_mul(
                  expr_pow(
                    expr_int(2),
                    expr_sub(expr_mul(expr_int(2), s), expr_one()),
                  ),
                  expr_mul(
                    @symspec.gamma(
                      expr_sub(expr_one(), expr_mul(expr_int(2), s)),
                    ),
                    expr_mul(
                      @symspec.gamma(expr_add(half_diff, s)),
                      @symspec.gamma(expr_add(half_sum, s)),
                    ),
                  ),
                ),
                expr_mul(
                  @symspec.gamma(expr_add(expr_sub(expr_one(), s), half_diff)),
                  @symspec.gamma(expr_add(expr_sub(expr_one(), s), half_sum)),
                ),
              ),
            ),
            max_expr(
              expr_div(
                expr_sub(
                  expr_mul(expr_neg_one(), @symelem.re(order1)),
                  @symelem.re(order2),
                ),
                expr_int(2),
              ),
              expr_div(
                expr_sub(@symelem.re(order2), @symelem.re(order1)),
                expr_int(2),
              ),
            ),
            expr_rat(1, 2),
            true_expr(),
          ),
        )
      } else {
        None
      }
    _ => None
  }
}

///|
fn mellin_exp_info(
  pow : Expr,
  coef : Expr,
  degree : Int,
  s : Expr,
) -> MellinInfo? {
  if degree == 1 {
    if expr_is_negative(coef) {
      Some(
        (
          mellin_exp_formula(pow, coef, degree, s),
          expr_mul(expr_neg_one(), pow),
          @symcore.oo(),
          true_expr(),
        ),
      )
    } else {
      None
    }
  } else if degree == -1 {
    Some(
      (
        mellin_exp_formula(pow, coef, degree, s),
        expr_mul(expr_neg_one(), @symcore.oo()),
        expr_mul(expr_neg_one(), pow),
        true_expr(),
      ),
    )
  } else {
    None
  }
}

///|
fn parse_power_factor(expr : Expr, x_name : String) -> Expr? {
  match expr {
    @symcore.Expr::Symbol(name) =>
      if name == x_name {
        Some(expr_one())
      } else {
        None
      }
    @symcore.Expr::Function("sqrt", [@symcore.Expr::Symbol(name)]) =>
      if name == x_name {
        Some(expr_rat(1, 2))
      } else {
        None
      }
    @symcore.Expr::Pow(@symcore.Expr::Symbol(name), exp) =>
      if name == x_name {
        Some(exp)
      } else {
        None
      }
    @symcore.Expr::Pow(
      @symcore.Expr::Function("sqrt", [@symcore.Expr::Symbol(name)]),
      exp
    ) => if name == x_name { Some(expr_div(exp, expr_int(2))) } else { None }
    _ => None
  }
}

///|
fn parse_mellin_exp(inner : Expr, x_name : String) -> (Expr, Int)? {
  match parse_mellin_inverse_exp(inner, x_name) {
    Some(coef) => Some((coef, -1))
    None => parse_mellin_polynomial_exp(inner, x_name)
  }
}

///|
fn parse_mellin_polynomial_exp(inner : Expr, x_name : String) -> (Expr, Int)? {
  match poly_coeffs_upto2(inner, x_name) {
    Some(coeffs) =>
      if !expr_is_zero(coeffs[0]) {
        None
      } else if !expr_is_zero(coeffs[1]) && expr_is_zero(coeffs[2]) {
        if expr_is_constant(expr_simplify(coeffs[1]), x_name) {
          Some((coeffs[1], 1))
        } else {
          None
        }
      } else if !expr_is_zero(coeffs[2]) && expr_is_zero(coeffs[1]) {
        if expr_is_constant(expr_simplify(coeffs[2]), x_name) {
          Some((coeffs[2], 2))
        } else {
          None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn parse_mellin_inverse_exp(inner : Expr, x_name : String) -> Expr? {
  let (coeff, vars) = split_mul(inner, x_name)
  match vars.length() {
    1 =>
      match vars[0] {
        @symcore.Expr::Pow(@symcore.Expr::Symbol(name), exp) =>
          if name == x_name &&
            expr_is_minus_one(exp) &&
            expr_is_constant(expr_simplify(coeff), x_name) &&
            expr_is_negative(coeff) {
            Some(coeff)
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn parse_heaviside_limit(arg : Expr, x_name : String) -> (Expr, Bool)? {
  match linear_coeffs(arg, x_name) {
    Some((coeff, offset)) =>
      if expr_is_one(coeff) {
        Some((expr_mul(expr_neg_one(), offset), false))
      } else if expr_is_minus_one(coeff) {
        Some((offset, true))
      } else {
        None
      }
    _ => None
  }
}

///|
fn mellin_exp_formula(pow : Expr, coef : Expr, degree : Int, s : Expr) -> Expr {
  let shifted = expr_add(s, pow)
  if degree == 1 {
    if expr_is_positive(expr_simplify(coef)) {
      let phase = expr_mul(
        expr_mul(expr_mul(expr_neg_one(), @symcore.imag_unit()), @symcore.pi()),
        shifted,
      )
      let gamma_factor = expr_pow(coef, expr_mul(expr_neg_one(), shifted))
      let lower = @symspec.lowergamma(shifted, neg_oo_expr())
      expr_mul(@symelem.exp(phase), expr_mul(gamma_factor, lower))
    } else {
      expr_mul(
        expr_pow(
          expr_mul(expr_neg_one(), coef),
          expr_mul(expr_neg_one(), shifted),
        ),
        @symspec.gamma(shifted),
      )
    }
  } else if degree == -1 {
    let norm = expr_mul(expr_neg_one(), coef)
    let coef_factor = if expr_eq(norm, expr_one()) {
      expr_one()
    } else {
      expr_pow(norm, shifted)
    }
    expr_mul(coef_factor, @symspec.gamma(expr_sub(expr_zero(), shifted)))
  } else {
    expr_div(
      expr_mul(
        expr_pow(
          coef,
          expr_mul(expr_neg_one(), expr_div(shifted, expr_int(degree))),
        ),
        @symspec.gamma(expr_div(shifted, expr_int(degree))),
      ),
      expr_int(degree),
    )
  }
}

///|
fn mellin_heaviside_term(
  pow : Expr,
  bound : Expr,
  is_le : Bool,
  s : Expr,
) -> Expr {
  let scale = expr_div(expr_pow(bound, expr_add(s, pow)), expr_add(s, pow))
  if is_le {
    scale
  } else {
    expr_mul(expr_neg_one(), scale)
  }
}

///|
fn expr_is_constant(expr : Expr, symbol_name : String) -> Bool {
  !expr_depends_on(expr, symbol_name)
}

///|
fn inverse_mellin_doit(expr : Expr, s_name : String, x : Expr) -> Expr? {
  let s_sym = @symcore.symbol(s_name)
  match expr {
    @symcore.Expr::Add(terms) =>
      transform_add(terms, s_name, fn(term) {
        inverse_mellin_doit(term, s_name, x)
      })
    _ => {
      match inverse_mellin_special_term(expr_simplify(expr), s_sym, x) {
        Some(v) => return Some(v)
        None => ()
      }
      let (num, den_opt) = split_division(expr)
      let numerator = if num.length() == 0 {
        expr_one()
      } else if num.length() == 1 {
        num[0]
      } else {
        expr_simplify(@symcore.mul(num))
      }
      let direct_gamma = match den_opt {
        None =>
          match numerator {
            @symcore.Expr::Function("gamma", [arg]) =>
              if expr_eq(arg, s_sym) {
                Some(@symelem.exp(expr_mul(expr_neg_one(), x)))
              } else if expr_eq(arg, expr_mul(expr_neg_one(), s_sym)) {
                Some(@symelem.exp(expr_div(expr_neg_one(), x)))
              } else {
                None
              }
            _ => None
          }
        Some(_) => None
      }
      if direct_gamma is Some(gamma_inv) {
        return Some(gamma_inv)
      }
      let (num_coeff, vars_opt) = split_mul(numerator, s_name)
      if vars_opt.length() != 0 {
        None
      } else {
        match den_opt {
          None =>
            match numerator {
              @symcore.Expr::Function("gamma", [arg]) =>
                if expr_eq(arg, s_sym) {
                  Some(@symelem.exp(expr_mul(expr_neg_one(), x)))
                } else if expr_eq(arg, expr_mul(expr_neg_one(), s_sym)) {
                  Some(@symelem.exp(expr_div(expr_neg_one(), x)))
                } else {
                  None
                }
              _ => None
            }
          Some(den) =>
            match linear_coeffs(den, s_name) {
              Some((s_coeff, shift)) =>
                if expr_is_zero(s_coeff) {
                  None
                } else {
                  let norm_shift = expr_div(shift, s_coeff)
                  let norm_num = expr_div(num_coeff, s_coeff)
                  let (side_is_le, coeff_abs) = if expr_is_negative(norm_num) {
                    (false, expr_mul(expr_neg_one(), norm_num))
                  } else {
                    (true, norm_num)
                  }
                  Some(
                    expr_mul(
                      coeff_abs,
                      inverse_mellin_term(norm_shift, side_is_le, x),
                    ),
                  )
                }
              _ => None
            }
        }
      }
    }
  }
}

///|
fn inverse_mellin_special_term(expr : Expr, s_sym : Expr, x : Expr) -> Expr? {
  match inverse_mellin_gamma_linear_term(expr, s_sym, x) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_mellin_beta_heaviside_term(expr, s_sym, x) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_mellin_shifted_power_term(expr, s_sym, x) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_mellin_algebraic_term(expr, s_sym, x) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_mellin_multiplicative_substitution_term(expr, s_sym, x) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_mellin_log_power_term(expr, s_sym, x) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_mellin_piecewise_log_term(expr, s_sym, x) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_mellin_bessel_single_term(expr, s_sym, x) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_mellin_trig_besselj_term(expr, s_sym, x) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_mellin_trig_bessely_term(expr, s_sym, x) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_mellin_besselj_product_term(expr, s_sym, x) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_mellin_besselj_bessely_product_term(expr, s_sym, x) {
    Some(v) => return Some(v)
    None => ()
  }
  let erf_sqrt_formula = expr_div(
    expr_mul(expr_neg_one(), @symspec.gamma(expr_add(s_sym, expr_rat(1, 2)))),
    expr_mul(sqrt_pi(), s_sym),
  )
  if expr_eq(expr_simplify(expr), expr_simplify(erf_sqrt_formula)) {
    return Some(@symspec.erf(@symelem.sqrt(x)))
  }
  let e1_formula = expr_div(@symspec.gamma(s_sym), s_sym)
  if expr_eq(expr_simplify(expr), expr_simplify(e1_formula)) {
    return Some(@symspec.e1(x))
  }
  let expint2_formula = expr_div(
    @symspec.gamma(s_sym),
    expr_add(s_sym, expr_one()),
  )
  if expr_eq(expr_simplify(expr), expr_simplify(expint2_formula)) {
    return Some(@symspec.expint(expr_int(2), x))
  }
  let si_formula = expr_div(
    expr_mul(
      expr_neg_one(),
      expr_mul(
        expr_pow(expr_int(2), s_sym),
        expr_mul(
          sqrt_pi(),
          @symspec.gamma(expr_div(expr_add(s_sym, expr_one()), expr_int(2))),
        ),
      ),
    ),
    expr_mul(
      expr_int(2),
      expr_mul(
        s_sym,
        @symspec.gamma(expr_sub(expr_one(), expr_div(s_sym, expr_int(2)))),
      ),
    ),
  )
  if expr_eq(expr_simplify(expr), expr_simplify(si_formula)) {
    return Some(@symspec.si(x))
  }
  let ci_sqrt_formula = expr_div(
    expr_mul(
      expr_neg_one(),
      expr_mul(
        expr_pow(
          expr_int(2),
          expr_sub(expr_mul(expr_int(2), s_sym), expr_one()),
        ),
        expr_mul(sqrt_pi(), @symspec.gamma(s_sym)),
      ),
    ),
    expr_mul(s_sym, @symspec.gamma(expr_sub(expr_rat(1, 2), s_sym))),
  )
  if expr_eq(expr_simplify(expr), expr_simplify(ci_sqrt_formula)) {
    return Some(@symspec.ci(@symelem.sqrt(x)))
  }
  let sec_formula = expr_div(
    @symcore.pi(),
    @symelem.cos(expr_mul(@symcore.pi(), s_sym)),
  )
  if expr_eq(expr_simplify(expr), expr_simplify(sec_formula)) {
    return Some(expr_div(@symelem.sqrt(x), expr_add(x, expr_one())))
  }
  let log_quadratic_formula = expr_div(
    @symcore.pi(),
    expr_mul(
      s_sym,
      @symelem.sin(expr_div(expr_mul(@symcore.pi(), s_sym), expr_int(2))),
    ),
  )
  if expr_eq(expr_simplify(expr), expr_simplify(log_quadratic_formula)) {
    return Some(@symelem.log(expr_add(expr_pow(x, expr_int(2)), expr_one())))
  }
  None
}

///|
fn inverse_mellin_algebraic_term(expr : Expr, s_sym : Expr, x : Expr) -> Expr? {
  match inverse_mellin_difference_quotient_term(expr, s_sym, x) {
    Some(v) => return Some(v)
    None => ()
  }
  inverse_mellin_sqrt_shifted_power_term(expr, s_sym, x)
}

///|
fn inverse_mellin_difference_quotient_term(
  expr : Expr,
  s_sym : Expr,
  x : Expr,
) -> Expr? {
  let s_name = match symbol_name(s_sym) {
    Some(name) => name
    None => return None
  }
  let factors = match expr_simplify(expr) {
    @symcore.Expr::Mul(args) => args
    _ => return None
  }
  let gamma_args : Array[Expr] = []
  let mut scale : Expr? = None
  for factor in factors {
    match factor {
      @symcore.Expr::Function("gamma", [arg]) => gamma_args.push(arg)
      @symcore.Expr::Pow(base, exp) if !expr_depends_on(base, s_name) =>
        match parse_linear_offset_expr(exp, s_name) {
          Some((coeff, _)) if expr_same_simplified(coeff, expr_one()) =>
            if scale is None {
              scale = Some(base)
            } else if !expr_same_simplified(scale.unwrap(), base) {
              return None
            }
          _ => ()
        }
      _ => ()
    }
  }
  if gamma_args.length() != 4 {
    return None
  }
  let linears : Array[(Expr, Expr)] = []
  for arg in gamma_args {
    match parse_linear_offset_expr(arg, s_name) {
      Some(info) => linears.push(info)
      None => return None
    }
  }
  let mut power : Expr? = None
  let mut saw_gamma_s = false
  let mut saw_gamma_one_minus_s = false
  let mut one_minus_power : Expr? = None
  for item in linears {
    if expr_same_simplified(item.0, expr_one()) &&
      expr_same_simplified(item.1, expr_zero()) {
      saw_gamma_s = true
    } else if expr_same_simplified(item.0, expr_one()) {
      power = Some(item.1)
    } else if expr_same_simplified(item.0, expr_int(-1)) &&
      expr_same_simplified(item.1, expr_one()) {
      saw_gamma_one_minus_s = true
    } else if expr_same_simplified(item.0, expr_int(-1)) {
      one_minus_power = Some(item.1)
    } else {
      return None
    }
  }
  let power = match power {
    Some(v) if saw_gamma_s && saw_gamma_one_minus_s => v
    _ => return None
  }
  let scale = match scale {
    Some(v) => v
    None => return None
  }
  if !expr_same_simplified(
      one_minus_power.unwrap_or(expr_zero()),
      expr_sub(expr_one(), power),
    ) {
    return None
  }
  let expected = expr_simplify(
    expr_div(
      expr_mul(
        expr_pow(scale, expr_add(expr_sub(s_sym, expr_one()), power)),
        expr_mul(
          @symelem.sin(expr_mul(@symcore.pi(), power)),
          expr_mul(
            @symspec.gamma(s_sym),
            expr_mul(
              @symspec.gamma(expr_add(s_sym, power)),
              expr_mul(
                @symspec.gamma(expr_sub(expr_one(), s_sym)),
                @symspec.gamma(expr_sub(expr_sub(expr_one(), s_sym), power)),
              ),
            ),
          ),
        ),
      ),
      @symcore.pi(),
    ),
  )
  if !expr_same_simplified(expr, expected) {
    return None
  }
  Some(
    expr_simplify(
      expr_div(
        expr_sub(expr_pow(x, power), expr_pow(scale, power)),
        expr_sub(x, scale),
      ),
    ),
  )
}

///|
fn inverse_mellin_sqrt_shifted_power_term(
  expr : Expr,
  s_sym : Expr,
  x : Expr,
) -> Expr? {
  let s_name = match symbol_name(s_sym) {
    Some(name) => name
    None => return None
  }
  let factors = match expr_simplify(expr) {
    @symcore.Expr::Mul(args) => args
    _ => return None
  }
  let gamma_num_args : Array[Expr] = []
  let gamma_den_args : Array[Expr] = []
  let mut scale : Expr? = None
  for factor in factors {
    match factor {
      @symcore.Expr::Function("gamma", [arg]) => gamma_num_args.push(arg)
      @symcore.Expr::Pow(@symcore.Expr::Function("gamma", [arg]), exp) =>
        if expr_same_simplified(exp, expr_int(-1)) {
          gamma_den_args.push(arg)
        } else {
          return None
        }
      @symcore.Expr::Pow(base, exp) if !expr_depends_on(base, s_name) =>
        match parse_linear_offset_expr(exp, s_name) {
          Some((coeff, _)) if expr_same_simplified(coeff, expr_int(2)) &&
            !expr_same_simplified(base, expr_int(2)) =>
            if scale is None {
              scale = Some(base)
            } else if !expr_same_simplified(scale.unwrap(), base) {
              return None
            }
          _ => ()
        }
      _ => ()
    }
  }
  if gamma_num_args.length() != 2 || gamma_den_args.length() != 1 {
    return None
  }
  let num_linears : Array[(Expr, Expr)] = []
  for arg in gamma_num_args {
    match parse_linear_offset_expr(arg, s_name) {
      Some(info) => num_linears.push(info)
      None => return None
    }
  }
  let den_linear = match parse_linear_offset_expr(gamma_den_args[0], s_name) {
    Some(v) => v
    None => return None
  }
  let scale = match scale {
    Some(v) => v
    None => return None
  }
  let mut saw_gamma_s = false
  let mut double_linear : (Expr, Expr)? = None
  for item in num_linears {
    if expr_same_simplified(item.0, expr_one()) &&
      expr_same_simplified(item.1, expr_zero()) {
      saw_gamma_s = true
    } else if expr_same_simplified(item.0, expr_int(-2)) {
      double_linear = Some(item)
    } else {
      return None
    }
  }
  let power = match double_linear {
    Some((_, offset)) if saw_gamma_s &&
      expr_same_simplified(den_linear.0, expr_int(-1)) =>
      if expr_same_simplified(den_linear.1, offset) {
        expr_sub(expr_one(), offset)
      } else if expr_same_simplified(den_linear.1, expr_add(offset, expr_one())) {
        expr_mul(expr_neg_one(), offset)
      } else {
        return None
      }
    _ => return None
  }
  let shift = expr_add(x, expr_pow(scale, expr_int(2)))
  let base = expr_add(@symelem.sqrt(shift), scale)
  Some(
    expr_simplify(
      if expr_same_simplified(
          den_linear.1,
          match double_linear {
            Some((_, offset)) => expr_add(offset, expr_one())
            None => expr_zero()
          },
        ) {
        expr_pow(base, power)
      } else {
        expr_div(expr_pow(base, power), @symelem.sqrt(shift))
      },
    ),
  )
}

///|
fn inverse_mellin_gamma_linear_term(
  expr : Expr,
  s_sym : Expr,
  x : Expr,
) -> Expr? {
  let s_name = match symbol_name(s_sym) {
    Some(name) => name
    None => return None
  }
  match expr_simplify(expr) {
    @symcore.Expr::Function("gamma", [arg]) =>
      match split_linear_coeff(arg, s_name) {
        Some((coeff, offset)) if !expr_depends_on(offset, s_name) =>
          if expr_is_one(coeff) {
            let xpow = if expr_is_zero(offset) {
              expr_one()
            } else {
              expr_pow(x, offset)
            }
            Some(expr_mul(xpow, @symelem.exp(expr_mul(expr_neg_one(), x))))
          } else if expr_is_minus_one(coeff) {
            let xpow = if expr_is_zero(offset) {
              expr_one()
            } else {
              expr_pow(x, expr_mul(expr_neg_one(), offset))
            }
            Some(expr_mul(xpow, @symelem.exp(expr_div(expr_neg_one(), x))))
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn inverse_mellin_beta_heaviside_term(
  expr : Expr,
  s_sym : Expr,
  x : Expr,
) -> Expr? {
  let s_name = match symbol_name(s_sym) {
    Some(name) => name
    None => return None
  }
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  let num_factors = expr_factors(factors_expr(num))
  let den_factors = expr_factors(den)
  if num_factors.length() != 2 || den_factors.length() != 1 {
    return None
  }
  let mut beta_const : Expr? = None
  for factor in num_factors {
    match factor {
      @symcore.Expr::Function("gamma", [arg]) =>
        if !expr_depends_on(arg, s_name) {
          beta_const = Some(arg)
        } else {
          ()
        }
      _ => return None
    }
  }
  match beta_const {
    Some(beta) => {
      let left_formula = expr_simplify(
        @symspec.gamma(beta) *
        @symspec.gamma(s_sym) *
        (@symspec.gamma(s_sym + beta) ^ @symcore.int(-1)),
      )
      if expr_eq(expr_simplify(expr), left_formula) {
        Some(
          expr_mul(
            expr_pow(expr_sub(expr_one(), x), expr_sub(beta, expr_one())),
            @symspec.heaviside(expr_sub(expr_one(), x)),
          ),
        )
      } else {
        let right_formula = expr_simplify(
          @symspec.gamma(beta) *
          @symspec.gamma(@symcore.int(1) - beta - s_sym) *
          (@symspec.gamma(@symcore.int(1) - s_sym) ^ @symcore.int(-1)),
        )
        if expr_eq(expr_simplify(expr), right_formula) {
          Some(
            expr_mul(
              expr_pow(expr_sub(x, expr_one()), expr_sub(beta, expr_one())),
              @symspec.heaviside(expr_sub(x, expr_one())),
            ),
          )
        } else {
          None
        }
      }
    }
    None => None
  }
}

///|
fn inverse_mellin_shifted_power_term(
  expr : Expr,
  s_sym : Expr,
  x : Expr,
) -> Expr? {
  let s_name = match symbol_name(s_sym) {
    Some(name) => name
    None => return None
  }
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  let num_factors = expr_factors(factors_expr(num))
  let den_factors = expr_factors(den)
  if num_factors.length() != 2 || den_factors.length() != 1 {
    return None
  }
  let rho = match den_factors[0] {
    @symcore.Expr::Function("gamma", [arg]) if !expr_depends_on(arg, s_name) =>
      arg
    _ => return None
  }
  let mut has_gamma_s = false
  let mut has_gamma_rho_minus_s = false
  for factor in num_factors {
    match factor {
      @symcore.Expr::Function("gamma", [arg]) =>
        match split_linear_coeff(arg, s_name) {
          Some((coeff, offset)) if expr_is_one(coeff) && expr_is_zero(offset) =>
            has_gamma_s = true
          Some((coeff, offset)) if expr_is_minus_one(coeff) &&
            expr_eq(offset, rho) => has_gamma_rho_minus_s = true
          _ => return None
        }
      _ => return None
    }
  }
  if has_gamma_s && has_gamma_rho_minus_s {
    Some(expr_pow(expr_add(x, expr_one()), expr_mul(expr_neg_one(), rho)))
  } else {
    None
  }
}

///|
fn inverse_mellin_multiplicative_substitution_term(
  expr : Expr,
  s_sym : Expr,
  x : Expr,
) -> Expr? {
  let s_name = match symbol_name(s_sym) {
    Some(name) => name
    None => return None
  }
  let (num_factors, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  let mut gamma_info : (Expr, Expr)? = None
  let mut scale_info : (Expr, Expr)? = None
  for factor in num_factors {
    match parse_gamma_like_linear_arg(factor, s_name) {
      Some(info) =>
        if gamma_info is None {
          gamma_info = Some(info)
        } else {
          return None
        }
      None =>
        match expr_simplify(factor) {
          @symcore.Expr::Pow(base, exp) if !expr_depends_on(base, s_name) =>
            match parse_linear_offset_expr(exp, s_name) {
              Some((coeff, offset)) if expr_same_simplified(offset, expr_zero()) =>
                if scale_info is None {
                  scale_info = Some((base, coeff))
                } else {
                  return None
                }
              _ => return None
            }
          _ => return None
        }
    }
  }
  let (gamma_coeff, gamma_offset) = match gamma_info {
    Some(v) => v
    None => return None
  }
  let (den_coeff, den_offset) = match split_linear_coeff(den, s_name) {
    Some(v) => v
    None => return None
  }
  if !expr_same_simplified(den_coeff, expr_one()) ||
    !expr_same_simplified(
      expr_sub(gamma_offset, expr_one()),
      expr_mul(den_offset, gamma_coeff),
    ) {
    return None
  }
  let scale = match scale_info {
    Some((base, coeff)) =>
      if expr_same_simplified(coeff, expr_mul(expr_neg_one(), gamma_coeff)) {
        base
      } else {
        return None
      }
    None => expr_one()
  }
  let power = expr_simplify(expr_div(expr_one(), gamma_coeff))
  let xpow = if expr_same_simplified(den_offset, expr_zero()) {
    expr_one()
  } else {
    expr_pow(x, den_offset)
  }
  let exp_arg = expr_mul(expr_neg_one(), expr_mul(scale, expr_pow(x, power)))
  Some(expr_simplify(expr_mul(xpow, @symelem.exp(exp_arg))))
}

///|
fn inverse_mellin_log_power_term(expr : Expr, s_sym : Expr, x : Expr) -> Expr? {
  let s_name = match symbol_name(s_sym) {
    Some(name) => name
    None => return None
  }
  let (coeff, factors) = split_mul(expr_simplify(expr), s_name)
  if factors.length() != 1 {
    return None
  }
  let n = match factors[0] {
    @symcore.Expr::Pow(@symcore.Expr::Symbol(name), exp) if name == s_name =>
      match expr_is_int_value(exp) {
        Some(v) if v <= -2 => -v - 1
        _ => return None
      }
    _ => return None
  }
  let factorial = factorial_expr(expr_int(n))
  let log_pow = if n == 1 {
    @symelem.log(x)
  } else {
    expr_pow(@symelem.log(x), expr_int(n))
  }
  let left_coeff = expr_simplify(
    if n % 2 == 0 {
      factorial
    } else {
      expr_mul(expr_neg_one(), factorial)
    },
  )
  let right_coeff = expr_simplify(expr_mul(expr_neg_one(), left_coeff))
  let coeff_simplified = expr_simplify(coeff)
  if expr_eq(coeff_simplified, left_coeff) {
    Some(expr_mul(log_pow, @symspec.heaviside(expr_sub(expr_one(), x))))
  } else if expr_eq(coeff_simplified, right_coeff) {
    Some(expr_mul(log_pow, @symspec.heaviside(expr_sub(x, expr_one()))))
  } else {
    None
  }
}

///|
fn inverse_mellin_piecewise_log_term(
  expr : Expr,
  s_sym : Expr,
  x : Expr,
) -> Expr? {
  let pi = @symcore.pi()
  let one = expr_one()
  let sin_pi_formula = expr_div(
    pi,
    expr_mul(s_sym, @symelem.sin(expr_mul(pi, s_sym))),
  )
  if expr_eq(expr_simplify(expr), expr_simplify(sin_pi_formula)) {
    return Some(
      expr_simplify(
        expr_add(
          expr_mul(
            @symelem.log(expr_add(one, x)),
            @symspec.heaviside(expr_sub(one, x)),
          ),
          expr_mul(
            @symelem.log(expr_add(one, expr_pow(x, expr_int(-1)))),
            @symspec.heaviside(expr_sub(x, one)),
          ),
        ),
      ),
    )
  }
  let sin_two_pi_formula = expr_div(
    pi,
    expr_mul(s_sym, @symelem.sin(expr_mul(expr_int(2), expr_mul(pi, s_sym)))),
  )
  if expr_eq(expr_simplify(expr), expr_simplify(sin_two_pi_formula)) {
    let sqrt_x = @symelem.sqrt(x)
    return Some(
      expr_simplify(
        expr_add(
          expr_mul(
            @symelem.log(expr_add(one, sqrt_x)),
            @symspec.heaviside(expr_sub(one, x)),
          ),
          expr_mul(
            @symelem.log(expr_add(one, expr_pow(sqrt_x, expr_int(-1)))),
            @symspec.heaviside(expr_sub(x, one)),
          ),
        ),
      ),
    )
  }
  let tan_formula = expr_div(
    pi,
    expr_mul(s_sym, @symelem.tan(expr_mul(pi, s_sym))),
  )
  let cot_formula = expr_div(
    expr_mul(pi, @symelem.cot(expr_mul(pi, s_sym))),
    s_sym,
  )
  if expr_eq(expr_simplify(expr), expr_simplify(tan_formula)) ||
    expr_eq(expr_simplify(expr), expr_simplify(cot_formula)) {
    return Some(
      expr_simplify(
        expr_add(
          expr_mul(
            @symelem.log(expr_sub(one, x)),
            @symspec.heaviside(expr_sub(one, x)),
          ),
          expr_mul(
            @symelem.log(expr_sub(x, one)),
            @symspec.heaviside(expr_sub(x, one)),
          ),
        ),
      ),
    )
  }
  None
}

///|
fn inverse_mellin_bessel_single_term(
  expr : Expr,
  s_sym : Expr,
  x : Expr,
) -> Expr? {
  match inverse_mellin_besselj_single_term(expr, s_sym, x) {
    Some(v) => Some(v)
    None =>
      match inverse_mellin_bessely_single_term(expr, s_sym, x) {
        Some(v) => Some(v)
        None => inverse_mellin_besselk_single_term(expr, s_sym, x)
      }
  }
}

///|
fn inverse_mellin_trig_besselj_term(
  expr : Expr,
  s_sym : Expr,
  x : Expr,
) -> Expr? {
  let s_name = match symbol_name(s_sym) {
    Some(name) => name
    None => return None
  }
  let simplified = expr_simplify(expr)
  let factors = match simplified {
    @symcore.Expr::Mul(args) => args
    _ => return None
  }
  let mut coeff = expr_one()
  let gamma_num_args : Array[Expr] = []
  let gamma_den_args : Array[Expr] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Function("gamma", [arg]) => gamma_num_args.push(arg)
      @symcore.Expr::Pow(@symcore.Expr::Function("gamma", [arg]), exp) =>
        if expr_eq(exp, expr_int(-1)) {
          gamma_den_args.push(arg)
        } else {
          return None
        }
      @symcore.Expr::Pow(@symcore.Expr::Mul(items), exp) =>
        if expr_eq(exp, expr_int(-1)) {
          for item in items {
            match item {
              @symcore.Expr::Function("gamma", [arg]) =>
                gamma_den_args.push(arg)
              other =>
                if expr_depends_on(other, s_name) {
                  return None
                } else {
                  coeff = expr_mul(coeff, expr_pow(other, expr_int(-1)))
                }
            }
          }
        } else {
          return None
        }
      other =>
        if expr_depends_on(other, s_name) {
          return None
        } else {
          coeff = expr_mul(coeff, other)
        }
    }
  }
  if gamma_num_args.length() != 2 || gamma_den_args.length() != 2 {
    return None
  }
  let order = match parse_power_of_two(coeff, s_name) {
    Some(v) => v
    None => return None
  }
  let half = expr_rat(1, 2)
  let sin_formula = expr_simplify(
    expr_mul(
      expr_pow(expr_int(2), order),
      expr_mul(
        @symspec.gamma(expr_sub(half, expr_mul(expr_int(2), s_sym))),
        expr_mul(
          @symspec.gamma(
            expr_add(s_sym, expr_mul(expr_add(order, expr_one()), half)),
          ),
          expr_mul(
            expr_pow(
              @symspec.gamma(
                expr_sub(expr_sub(expr_one(), s_sym), expr_mul(order, half)),
              ),
              expr_int(-1),
            ),
            expr_pow(
              @symspec.gamma(
                expr_add(
                  expr_sub(expr_one(), expr_mul(expr_int(2), s_sym)),
                  order,
                ),
              ),
              expr_int(-1),
            ),
          ),
        ),
      ),
    ),
  )
  if expr_eq(simplified, sin_formula) {
    return Some(
      expr_simplify(
        expr_mul(
          @symelem.sin(@symelem.sqrt(x)),
          @symspec.besselj(order, @symelem.sqrt(x)),
        ),
      ),
    )
  }
  let cos_formula = expr_simplify(
    expr_mul(
      expr_pow(expr_int(2), order),
      expr_mul(
        @symspec.gamma(expr_add(expr_mul(order, half), s_sym)),
        expr_mul(
          @symspec.gamma(expr_sub(half, expr_mul(expr_int(2), s_sym))),
          expr_mul(
            expr_pow(
              @symspec.gamma(
                expr_sub(expr_sub(half, s_sym), expr_mul(order, half)),
              ),
              expr_int(-1),
            ),
            expr_pow(
              @symspec.gamma(
                expr_add(
                  expr_sub(expr_one(), expr_mul(expr_int(2), s_sym)),
                  order,
                ),
              ),
              expr_int(-1),
            ),
          ),
        ),
      ),
    ),
  )
  if expr_eq(simplified, cos_formula) {
    return Some(
      expr_simplify(
        expr_mul(
          @symelem.cos(@symelem.sqrt(x)),
          @symspec.besselj(order, @symelem.sqrt(x)),
        ),
      ),
    )
  }
  let num_linears : Array[(Expr, Expr)] = []
  let den_linears : Array[(Expr, Expr)] = []
  for arg in gamma_num_args {
    match parse_linear_offset_expr(arg, s_name) {
      Some(info) => num_linears.push(info)
      None => return None
    }
  }
  for arg in gamma_den_args {
    match parse_linear_offset_expr(arg, s_name) {
      Some(info) => den_linears.push(info)
      None => return None
    }
  }
  if has_linear_offset(num_linears, expr_int(-2), fn(offset) {
      expr_same_simplified(expr_mul(expr_int(2), offset), expr_one())
    }) &&
    has_linear_offset(num_linears, expr_one(), fn(offset) {
      expr_same_simplified(
        expr_mul(expr_int(2), offset),
        expr_add(order, expr_one()),
      )
    }) &&
    has_linear_offset(den_linears, expr_int(-1), fn(offset) {
      expr_same_simplified(
        offset,
        expr_sub(expr_one(), expr_mul(expr_rat(1, 2), order)),
      )
    }) &&
    has_linear_offset(den_linears, expr_int(-2), fn(offset) {
      expr_same_simplified(offset, expr_add(order, expr_one()))
    }) {
    return Some(
      expr_simplify(
        expr_mul(
          @symelem.sin(@symelem.sqrt(x)),
          @symspec.besselj(order, @symelem.sqrt(x)),
        ),
      ),
    )
  }
  if has_linear_offset(num_linears, expr_int(-2), fn(offset) {
      expr_same_simplified(expr_mul(expr_int(2), offset), expr_one())
    }) &&
    has_linear_offset(num_linears, expr_one(), fn(offset) {
      expr_same_simplified(expr_mul(expr_int(2), offset), order)
    }) &&
    has_linear_offset(den_linears, expr_int(-1), fn(offset) {
      expr_same_simplified(
        offset,
        expr_sub(expr_rat(1, 2), expr_mul(expr_rat(1, 2), order)),
      )
    }) &&
    has_linear_offset(den_linears, expr_int(-2), fn(offset) {
      expr_same_simplified(offset, expr_add(order, expr_one()))
    }) {
    return Some(
      expr_simplify(
        expr_mul(
          @symelem.cos(@symelem.sqrt(x)),
          @symspec.besselj(order, @symelem.sqrt(x)),
        ),
      ),
    )
  }
  None
}

///|
fn inverse_mellin_trig_bessely_term(
  expr : Expr,
  s_sym : Expr,
  x : Expr,
) -> Expr? {
  let s_name = match symbol_name(s_sym) {
    Some(name) => name
    None => return None
  }
  let factors = match expr_simplify(expr) {
    @symcore.Expr::Mul(args) => args
    _ => return None
  }
  let mut coeff = expr_one()
  let mut s_scale = expr_one()
  let mut trig_info : (String, Int, Expr)? = None
  let gamma_num_args : Array[Expr] = []
  let gamma_den_args : Array[Expr] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Function("gamma", [arg]) => gamma_num_args.push(arg)
      @symcore.Expr::Pow(@symcore.Expr::Function("gamma", [arg]), exp) =>
        if expr_eq(exp, expr_int(-1)) {
          gamma_den_args.push(arg)
        } else {
          return None
        }
      @symcore.Expr::Pow(@symcore.Expr::Mul(items), exp) =>
        if expr_eq(exp, expr_int(-1)) {
          for item in items {
            match item {
              @symcore.Expr::Function("gamma", [arg]) =>
                gamma_den_args.push(arg)
              other =>
                if expr_depends_on(other, s_name) {
                  return None
                } else {
                  coeff = expr_mul(coeff, expr_pow(other, expr_int(-1)))
                }
            }
          }
        } else {
          return None
        }
      @symcore.Expr::Function(name, _) if name == "sin" || name == "cos" =>
        match parse_pi_linear_trig_factor(factor, s_name, name) {
          Some((trig_coeff, trig_offset)) =>
            if trig_info is None {
              trig_info = Some((name, trig_coeff, trig_offset))
            } else {
              return None
            }
          None => return None
        }
      @symcore.Expr::Pow(base, exp) =>
        if expr_eq(exp, s_sym) && !expr_depends_on(base, s_name) {
          s_scale = expr_mul(s_scale, factor)
        } else if expr_depends_on(factor, s_name) {
          return None
        } else {
          coeff = expr_mul(coeff, factor)
        }
      other =>
        if expr_depends_on(other, s_name) {
          return None
        } else {
          coeff = expr_mul(coeff, other)
        }
    }
  }
  if gamma_num_args.length() != 3 || gamma_den_args.length() != 2 {
    return None
  }
  if !expr_same_simplified(s_scale, expr_pow(expr_int(4), s_sym)) ||
    !expr_same_simplified(
      coeff,
      expr_mul(expr_neg_one(), expr_div(expr_one(), sqrt_pi())),
    ) {
    return None
  }
  let (trig_name, trig_coeff, trig_offset) = match trig_info {
    Some(v) => v
    None => return None
  }
  if trig_coeff != -1 && trig_coeff != 1 {
    return None
  }
  let half = expr_rat(1, 2)
  let order = expr_simplify(expr_mul(expr_int(-2 * trig_coeff), trig_offset))
  let sin_formula = expr_simplify(
    expr_mul(
      expr_mul(
        expr_neg_one(),
        expr_pow(@symelem.sqrt(@symcore.pi()), expr_int(-1)),
      ),
      expr_mul(
        expr_pow(expr_int(4), s_sym),
        expr_mul(
          @symelem.sin(
            expr_mul(@symcore.pi(), expr_sub(expr_mul(order, half), s_sym)),
          ),
          expr_mul(
            @symspec.gamma(expr_sub(half, expr_mul(expr_int(2), s_sym))),
            expr_mul(
              @symspec.gamma(
                expr_add(expr_mul(expr_sub(expr_one(), order), half), s_sym),
              ),
              expr_mul(
                @symspec.gamma(
                  expr_add(expr_mul(expr_add(expr_one(), order), half), s_sym),
                ),
                expr_mul(
                  expr_pow(
                    @symspec.gamma(
                      expr_sub(
                        expr_sub(expr_one(), s_sym),
                        expr_mul(order, half),
                      ),
                    ),
                    expr_int(-1),
                  ),
                  expr_pow(
                    @symspec.gamma(
                      expr_add(
                        expr_sub(expr_one(), s_sym),
                        expr_mul(order, half),
                      ),
                    ),
                    expr_int(-1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  )
  if expr_eq(expr_simplify(expr), sin_formula) {
    return Some(
      expr_simplify(
        expr_mul(
          @symelem.sin(@symelem.sqrt(x)),
          @symspec.bessely(order, @symelem.sqrt(x)),
        ),
      ),
    )
  }
  let cos_formula = expr_simplify(
    expr_mul(
      expr_mul(
        expr_neg_one(),
        expr_pow(@symelem.sqrt(@symcore.pi()), expr_int(-1)),
      ),
      expr_mul(
        expr_pow(expr_int(4), s_sym),
        expr_mul(
          @symelem.cos(
            expr_mul(@symcore.pi(), expr_sub(expr_mul(order, half), s_sym)),
          ),
          expr_mul(
            @symspec.gamma(expr_sub(s_sym, expr_mul(order, half))),
            expr_mul(
              @symspec.gamma(expr_add(s_sym, expr_mul(order, half))),
              expr_mul(
                @symspec.gamma(expr_sub(half, expr_mul(expr_int(2), s_sym))),
                expr_mul(
                  expr_pow(
                    @symspec.gamma(
                      expr_sub(expr_sub(half, s_sym), expr_mul(order, half)),
                    ),
                    expr_int(-1),
                  ),
                  expr_pow(
                    @symspec.gamma(
                      expr_add(expr_sub(half, s_sym), expr_mul(order, half)),
                    ),
                    expr_int(-1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  )
  if expr_eq(expr_simplify(expr), cos_formula) {
    return Some(
      expr_simplify(
        expr_mul(
          @symelem.cos(@symelem.sqrt(x)),
          @symspec.bessely(order, @symelem.sqrt(x)),
        ),
      ),
    )
  }
  let num_linears : Array[(Expr, Expr)] = []
  let den_linears : Array[(Expr, Expr)] = []
  for arg in gamma_num_args {
    match parse_linear_offset_expr(arg, s_name) {
      Some(info) => num_linears.push(info)
      None => return None
    }
  }
  for arg in gamma_den_args {
    match parse_linear_offset_expr(arg, s_name) {
      Some(info) => den_linears.push(info)
      None => return None
    }
  }
  let saw_gamma_half_minus_2s = has_linear_offset(num_linears, expr_int(-2), fn(
    offset,
  ) {
    expr_same_simplified(offset, half)
  })
  if !saw_gamma_half_minus_2s {
    return None
  }
  let expected_den_sin_pos = expr_simplify(expr_add(expr_one(), order))
  let expected_den_sin_neg = expr_simplify(expr_sub(expr_one(), order))
  let expected_den_cos_pos = expr_simplify(expr_add(half, order))
  let expected_den_cos_neg = expr_simplify(expr_sub(half, order))
  let ok = match trig_name {
    "sin" =>
      has_linear_offset(num_linears, expr_one(), fn(offset) {
        expr_same_simplified(
          expr_mul(expr_int(2), offset),
          expr_add(expr_one(), expr_mul(expr_int(2), order)),
        )
      }) &&
      has_linear_offset(num_linears, expr_one(), fn(offset) {
        expr_same_simplified(
          expr_mul(expr_int(2), offset),
          expr_sub(expr_one(), expr_mul(expr_int(2), order)),
        )
      }) &&
      has_linear_offset(den_linears, expr_int(-1), fn(offset) {
        expr_same_simplified(offset, expected_den_sin_pos)
      }) &&
      has_linear_offset(den_linears, expr_int(-1), fn(offset) {
        expr_same_simplified(offset, expected_den_sin_neg)
      })
    "cos" =>
      has_linear_offset(num_linears, expr_one(), fn(offset) {
        expr_same_simplified(offset, order)
      }) &&
      has_linear_offset(num_linears, expr_one(), fn(offset) {
        expr_same_simplified(offset, expr_mul(expr_neg_one(), order))
      }) &&
      has_linear_offset(den_linears, expr_int(-1), fn(offset) {
        expr_same_simplified(offset, expected_den_cos_pos)
      }) &&
      has_linear_offset(den_linears, expr_int(-1), fn(offset) {
        expr_same_simplified(offset, expected_den_cos_neg)
      })
    _ => false
  }
  if !ok {
    return None
  }
  let body = @symspec.bessely(
    expr_simplify(expr_mul(expr_int(2), order)),
    @symelem.sqrt(x),
  )
  Some(
    expr_simplify(
      match trig_name {
        "sin" => expr_mul(@symelem.sin(@symelem.sqrt(x)), body)
        "cos" => expr_mul(@symelem.cos(@symelem.sqrt(x)), body)
        _ => body
      },
    ),
  )
}

///|
fn inverse_mellin_besselj_product_term(
  expr : Expr,
  s_sym : Expr,
  x : Expr,
) -> Expr? {
  let s_name = match symbol_name(s_sym) {
    Some(name) => name
    None => return None
  }
  let simplified = expr_simplify(expr)
  let factors = match simplified {
    @symcore.Expr::Mul(args) => args
    _ => return None
  }
  let mut coeff = expr_one()
  let mut s_scale = expr_one()
  let gamma_num_args : Array[Expr] = []
  let gamma_den_args : Array[Expr] = []
  let extra_linears : Array[(Expr, Expr)] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Function("gamma", [arg]) => gamma_num_args.push(arg)
      @symcore.Expr::Pow(@symcore.Expr::Function("gamma", [arg]), exp) =>
        if expr_eq(exp, expr_int(-1)) {
          gamma_den_args.push(arg)
        } else {
          return None
        }
      @symcore.Expr::Pow(@symcore.Expr::Mul(items), exp) =>
        if expr_eq(exp, expr_int(-1)) {
          for item in items {
            match item {
              @symcore.Expr::Function("gamma", [arg]) =>
                gamma_den_args.push(arg)
              other =>
                if expr_depends_on(other, s_name) {
                  return None
                } else {
                  coeff = expr_mul(coeff, expr_pow(other, expr_int(-1)))
                }
            }
          }
        } else {
          return None
        }
      @symcore.Expr::Pow(base, exp) =>
        if expr_eq(exp, s_sym) && !expr_depends_on(base, s_name) {
          s_scale = expr_mul(s_scale, factor)
        } else if expr_depends_on(factor, s_name) {
          match parse_linear_offset_expr(factor, s_name) {
            Some(info) => extra_linears.push(info)
            None => return None
          }
        } else {
          coeff = expr_mul(coeff, factor)
        }
      other =>
        if expr_depends_on(other, s_name) {
          match parse_linear_offset_expr(other, s_name) {
            Some(info) => extra_linears.push(info)
            None => return None
          }
        } else {
          coeff = expr_mul(coeff, other)
        }
    }
  }
  if gamma_num_args.length() != 2 {
    return None
  }
  let num_linears : Array[(Expr, Expr)] = []
  let den_linears : Array[(Expr, Expr)] = []
  for arg in gamma_num_args {
    match parse_linear_offset_expr(arg, s_name) {
      Some(info) => num_linears.push(info)
      None => return None
    }
  }
  for arg in gamma_den_args {
    match parse_linear_offset_expr(arg, s_name) {
      Some(info) => den_linears.push(info)
      None => return None
    }
  }
  let (coeff, num_linears) = match
    absorb_linear_prefactors_into_gamma_numerators(
      coeff, extra_linears, num_linears,
    ) {
    Some(v) => v
    None => return None
  }
  let sqrt_x = @symelem.sqrt(x)
  if expr_same_simplified(s_scale, expr_one()) &&
    gamma_den_args.length() == 2 &&
    expr_same_simplified(coeff, expr_div(expr_one(), sqrt_pi())) {
    match inverse_mellin_same_order_besselj_product(num_linears, den_linears) {
      Some(order) =>
        return Some(
          expr_simplify(expr_pow(@symspec.besselj(order, sqrt_x), expr_int(2))),
        )
      None => ()
    }
    match inverse_mellin_pm_order_besselj_product(num_linears, den_linears) {
      Some(order) =>
        return Some(
          expr_simplify(
            expr_mul(
              @symspec.besselj(expr_mul(expr_int(-1), order), sqrt_x),
              @symspec.besselj(order, sqrt_x),
            ),
          ),
        )
      None => ()
    }
  }
  if expr_same_simplified(s_scale, expr_pow(expr_int(4), s_sym)) &&
    gamma_den_args.length() == 3 &&
    expr_same_simplified(coeff, expr_one()) {
    match inverse_mellin_general_besselj_product(num_linears, den_linears) {
      Some((order1, order2)) =>
        return Some(
          expr_simplify(
            expr_mul(
              @symspec.besselj(order1, sqrt_x),
              @symspec.besselj(order2, sqrt_x),
            ),
          ),
        )
      None => ()
    }
  }
  None
}

///|
fn inverse_mellin_besselj_bessely_product_term(
  expr : Expr,
  s_sym : Expr,
  x : Expr,
) -> Expr? {
  let s_name = match symbol_name(s_sym) {
    Some(name) => name
    None => return None
  }
  let factors = match expr_simplify(expr) {
    @symcore.Expr::Mul(args) => args
    _ => return None
  }
  let mut coeff = expr_one()
  let mut s_scale = expr_one()
  let mut trig_info : (Int, Expr)? = None
  let gamma_num_args : Array[Expr] = []
  let gamma_den_args : Array[Expr] = []
  let extra_linears : Array[(Expr, Expr)] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Function("gamma", [arg]) => gamma_num_args.push(arg)
      @symcore.Expr::Pow(@symcore.Expr::Function("gamma", [arg]), exp) =>
        if expr_eq(exp, expr_int(-1)) {
          gamma_den_args.push(arg)
        } else {
          return None
        }
      @symcore.Expr::Pow(@symcore.Expr::Mul(items), exp) =>
        if expr_eq(exp, expr_int(-1)) {
          for item in items {
            match item {
              @symcore.Expr::Function("gamma", [arg]) =>
                gamma_den_args.push(arg)
              other =>
                if expr_depends_on(other, s_name) {
                  return None
                } else {
                  coeff = expr_mul(coeff, expr_pow(other, expr_int(-1)))
                }
            }
          }
        } else {
          return None
        }
      @symcore.Expr::Function("cos", _) =>
        match parse_pi_linear_trig_factor(factor, s_name, "cos") {
          Some(info) =>
            if trig_info is None {
              trig_info = Some(info)
            } else {
              return None
            }
          None => return None
        }
      @symcore.Expr::Pow(base, exp) =>
        if expr_eq(exp, s_sym) && !expr_depends_on(base, s_name) {
          s_scale = expr_mul(s_scale, factor)
        } else if expr_depends_on(factor, s_name) {
          match parse_linear_offset_expr(factor, s_name) {
            Some(info) => extra_linears.push(info)
            None => return None
          }
        } else {
          coeff = expr_mul(coeff, factor)
        }
      other =>
        if expr_depends_on(other, s_name) {
          match parse_linear_offset_expr(other, s_name) {
            Some(info) => extra_linears.push(info)
            None => return None
          }
        } else {
          coeff = expr_mul(coeff, other)
        }
    }
  }
  if gamma_num_args.length() != 3 {
    return None
  }
  let (trig_coeff, trig_shift) = match trig_info {
    Some(v) => v
    None => return None
  }
  let num_linears : Array[(Expr, Expr)] = []
  let den_linears : Array[(Expr, Expr)] = []
  for arg in gamma_num_args {
    match parse_linear_offset_expr(arg, s_name) {
      Some(info) => num_linears.push(info)
      None => return None
    }
  }
  for arg in gamma_den_args {
    match parse_linear_offset_expr(arg, s_name) {
      Some(info) => den_linears.push(info)
      None => return None
    }
  }
  let (coeff, num_linears) = match
    absorb_linear_prefactors_into_gamma_numerators(
      coeff, extra_linears, num_linears,
    ) {
    Some(v) => v
    None => return None
  }
  if gamma_den_args.length() == 1 &&
    expr_same_simplified(s_scale, expr_one()) &&
    expr_same_simplified(
      coeff,
      expr_mul(
        expr_neg_one(),
        expr_mul(
          expr_pow(@symcore.pi(), expr_int(-1)),
          expr_div(expr_one(), sqrt_pi()),
        ),
      ),
    ) &&
    trig_coeff == 1 &&
    expr_same_simplified(trig_shift, expr_zero()) {
    match
      inverse_mellin_same_order_besselj_bessely_product(
        num_linears, den_linears,
      ) {
      Some(order) =>
        return Some(
          expr_simplify(
            expr_mul(
              @symspec.besselj(order, @symelem.sqrt(x)),
              @symspec.bessely(order, @symelem.sqrt(x)),
            ),
          ),
        )
      None => ()
    }
  }
  if gamma_den_args.length() != 2 ||
    !expr_same_simplified(s_scale, expr_pow(expr_int(4), s_sym)) ||
    !expr_same_simplified(
      coeff,
      expr_mul(expr_neg_one(), expr_pow(@symcore.pi(), expr_int(-1))),
    ) ||
    trig_coeff != 1 {
    return None
  }
  match
    inverse_mellin_general_besselj_bessely_product(
      num_linears, den_linears, trig_shift,
    ) {
    Some((order_j, order_y)) =>
      Some(
        expr_simplify(
          expr_mul(
            @symspec.besselj(order_j, @symelem.sqrt(x)),
            @symspec.bessely(order_y, @symelem.sqrt(x)),
          ),
        ),
      )
    None => None
  }
}

///|
fn inverse_mellin_same_order_besselj_bessely_product(
  num_linears : Array[(Expr, Expr)],
  den_linears : Array[(Expr, Expr)],
) -> Expr? {
  if num_linears.length() != 3 || den_linears.length() != 1 {
    return None
  }
  let mut order : Expr? = None
  let mut saw_zero_num = false
  let mut saw_half_num = false
  for item in num_linears {
    if expr_same_simplified(item.0, expr_one()) &&
      expr_same_simplified(item.1, expr_zero()) {
      saw_zero_num = true
    } else if expr_same_simplified(item.0, expr_one()) {
      order = Some(item.1)
    } else if expr_same_simplified(item.0, expr_int(-1)) &&
      expr_same_simplified(item.1, expr_rat(1, 2)) {
      saw_half_num = true
    } else {
      return None
    }
  }
  let order = match order {
    Some(v) if saw_zero_num && saw_half_num => v
    _ => return None
  }
  if !expr_same_simplified(den_linears[0].0, expr_int(-1)) ||
    !expr_same_simplified(den_linears[0].1, expr_add(order, expr_one())) {
    return None
  }
  Some(order)
}

///|
fn inverse_mellin_same_order_besselj_product(
  num_linears : Array[(Expr, Expr)],
  den_linears : Array[(Expr, Expr)],
) -> Expr? {
  let mut order : Expr? = None
  let mut saw_half_num = false
  for item in num_linears {
    if expr_same_simplified(item.0, expr_one()) {
      order = Some(item.1)
    } else if expr_same_simplified(item.0, expr_int(-1)) &&
      expr_same_simplified(item.1, expr_rat(1, 2)) {
      saw_half_num = true
    } else {
      return None
    }
  }
  let order = match order {
    Some(v) if saw_half_num => v
    _ => return None
  }
  let mut saw_one_den = false
  let mut saw_order_den = false
  for item in den_linears {
    if !expr_same_simplified(item.0, expr_int(-1)) {
      return None
    }
    if expr_same_simplified(item.1, expr_one()) {
      saw_one_den = true
    } else if expr_same_simplified(item.1, expr_add(order, expr_one())) {
      saw_order_den = true
    } else {
      return None
    }
  }
  if saw_one_den && saw_order_den {
    Some(order)
  } else {
    None
  }
}

///|
fn inverse_mellin_pm_order_besselj_product(
  num_linears : Array[(Expr, Expr)],
  den_linears : Array[(Expr, Expr)],
) -> Expr? {
  let mut saw_zero_num = false
  let mut saw_half_num = false
  for item in num_linears {
    if expr_same_simplified(item.0, expr_one()) &&
      expr_same_simplified(item.1, expr_zero()) {
      saw_zero_num = true
    } else if expr_same_simplified(item.0, expr_int(-1)) &&
      expr_same_simplified(item.1, expr_rat(1, 2)) {
      saw_half_num = true
    } else {
      return None
    }
  }
  if !(saw_zero_num && saw_half_num) {
    return None
  }
  if den_linears.length() != 2 ||
    !expr_same_simplified(den_linears[0].0, expr_int(-1)) ||
    !expr_same_simplified(den_linears[1].0, expr_int(-1)) {
    return None
  }
  let offset1 = den_linears[0].1
  let offset2 = den_linears[1].1
  if !expr_same_simplified(expr_add(offset1, offset2), expr_int(2)) {
    return None
  }
  Some(expr_simplify(expr_sub(offset2, expr_one())))
}

///|
fn inverse_mellin_general_besselj_product(
  num_linears : Array[(Expr, Expr)],
  den_linears : Array[(Expr, Expr)],
) -> (Expr, Expr)? {
  if num_linears.length() != 2 || den_linears.length() != 3 {
    return None
  }
  let mut half_sum : Expr? = None
  let mut saw_gamma_one_minus_2s = false
  for item in num_linears {
    if expr_same_simplified(item.0, expr_int(-2)) &&
      expr_same_simplified(item.1, expr_one()) {
      saw_gamma_one_minus_2s = true
    } else if expr_same_simplified(item.0, expr_one()) {
      half_sum = Some(item.1)
    } else {
      return None
    }
  }
  let half_sum = match half_sum {
    Some(v) if saw_gamma_one_minus_2s => v
    _ => return None
  }
  let mut saw_sum_den = false
  let diff_offsets : Array[Expr] = []
  let sum_offset = expr_simplify(expr_add(expr_one(), half_sum))
  for item in den_linears {
    if !expr_same_simplified(item.0, expr_int(-1)) {
      return None
    }
    if expr_same_simplified(item.1, sum_offset) {
      saw_sum_den = true
    } else {
      diff_offsets.push(item.1)
    }
  }
  if !saw_sum_den || diff_offsets.length() != 2 {
    return None
  }
  let diff_half = expr_simplify(expr_sub(diff_offsets[0], expr_one()))
  Some(
    (
      expr_simplify(expr_add(half_sum, diff_half)),
      expr_simplify(expr_sub(half_sum, diff_half)),
    ),
  )
}

///|
fn inverse_mellin_general_besselj_bessely_product(
  num_linears : Array[(Expr, Expr)],
  den_linears : Array[(Expr, Expr)],
  trig_shift : Expr,
) -> (Expr, Expr)? {
  if num_linears.length() != 3 || den_linears.length() != 2 {
    return None
  }
  let mut half_diff : Expr? = None
  let mut half_sum : Expr? = None
  let mut saw_gamma_one_minus_2s = false
  for item in num_linears {
    if expr_same_simplified(item.0, expr_int(-2)) &&
      expr_same_simplified(item.1, expr_one()) {
      saw_gamma_one_minus_2s = true
    } else if expr_same_simplified(item.0, expr_one()) {
      if half_diff is None {
        half_diff = Some(item.1)
      } else if half_sum is None {
        half_sum = Some(item.1)
      } else {
        return None
      }
    } else {
      return None
    }
  }
  let half_diff = match half_diff {
    Some(v) if saw_gamma_one_minus_2s => v
    _ => return None
  }
  let half_sum = match half_sum {
    Some(v) => v
    None => return None
  }
  if !expr_same_simplified(trig_shift, half_diff) {
    return None
  }
  let expected_den1 = expr_simplify(expr_add(expr_one(), half_diff))
  let expected_den2 = expr_simplify(expr_add(expr_one(), half_sum))
  let mut saw_diff_den = false
  let mut saw_sum_den = false
  for item in den_linears {
    if !expr_same_simplified(item.0, expr_int(-1)) {
      return None
    }
    if expr_same_simplified(item.1, expected_den1) {
      saw_diff_den = true
    } else if expr_same_simplified(item.1, expected_den2) {
      saw_sum_den = true
    } else {
      return None
    }
  }
  if !saw_diff_den || !saw_sum_den {
    return None
  }
  Some(
    (
      expr_simplify(expr_add(half_sum, half_diff)),
      expr_simplify(expr_sub(half_sum, half_diff)),
    ),
  )
}

///|
fn absorb_linear_prefactors_into_gamma_numerators(
  coeff : Expr,
  extra_linears : Array[(Expr, Expr)],
  num_linears : Array[(Expr, Expr)],
) -> (Expr, Array[(Expr, Expr)])? {
  let mut normalized_coeff = coeff
  let normalized_linears : Array[(Expr, Expr)] = []
  for item in num_linears {
    normalized_linears.push(item)
  }
  for extra in extra_linears {
    let mut absorbed = false
    for i in 0..<normalized_linears.length() {
      let current = normalized_linears[i]
      let scale = expr_simplify(expr_div(extra.0, current.0))
      if expr_same_simplified(extra.0, expr_mul(scale, current.0)) &&
        expr_same_simplified(extra.1, expr_mul(scale, current.1)) {
        normalized_coeff = expr_simplify(expr_mul(normalized_coeff, scale))
        normalized_linears[i] = (
          current.0,
          expr_simplify(expr_add(current.1, expr_one())),
        )
        absorbed = true
        break
      }
    }
    if !absorbed {
      return None
    }
  }
  Some((normalized_coeff, normalized_linears))
}

///|
fn inverse_mellin_besselj_single_term(
  expr : Expr,
  s_sym : Expr,
  x : Expr,
) -> Expr? {
  let s_name = match symbol_name(s_sym) {
    Some(name) => name
    None => return None
  }
  let simplified = expr_simplify(expr)
  let factors = match simplified {
    @symcore.Expr::Mul(args) if args.length() == 2 => args
    _ => return None
  }
  let mut gamma_num : Expr? = None
  let mut gamma_den : Expr? = None
  for factor in factors {
    match factor {
      @symcore.Expr::Function("gamma", [arg]) =>
        if gamma_num is None {
          gamma_num = Some(arg)
        } else {
          return None
        }
      @symcore.Expr::Pow(@symcore.Expr::Function("gamma", [arg]), exp) =>
        if expr_eq(exp, expr_int(-1)) && gamma_den is None {
          gamma_den = Some(arg)
        } else {
          return None
        }
      _ => return None
    }
  }
  match (gamma_num, gamma_den) {
    (Some(num_arg), Some(den_arg)) =>
      match
        (
          parse_unit_linear_offset(num_arg, s_name),
          parse_unit_linear_offset(den_arg, s_name),
        ) {
        (Some((1, num_offset)), Some((-1, den_offset))) =>
          if !expr_eq(
              expr_simplify(expr_sub(den_offset, num_offset)),
              expr_one(),
            ) {
            None
          } else {
            let order = expr_simplify(expr_mul(expr_int(2), num_offset))
            if expr_depends_on(order, s_name) {
              None
            } else {
              Some(@symspec.besselj(order, expr_int(2) * @symelem.sqrt(x)))
            }
          }
        _ => None
      }
    _ => None
  }
}

///|
fn inverse_mellin_besselk_single_term(
  expr : Expr,
  s_sym : Expr,
  x : Expr,
) -> Expr? {
  let simplified = expr_simplify(expr)
  let factors = match simplified {
    @symcore.Expr::Mul(args) if args.length() == 3 => args
    @symcore.Expr::Mul(args) if args.length() == 2 => args
    _ => return None
  }
  let mut coeff = expr_one()
  let gamma_args : Array[Expr] = []
  let s_name = match symbol_name(s_sym) {
    Some(name) => name
    None => return None
  }
  for factor in factors {
    match factor {
      @symcore.Expr::Function("gamma", [arg]) => gamma_args.push(arg)
      other =>
        if expr_depends_on(other, s_name) {
          return None
        } else {
          coeff = expr_mul(coeff, other)
        }
    }
  }
  if !expr_eq(expr_simplify(coeff), expr_rat(1, 2)) || gamma_args.length() != 2 {
    return None
  }
  match
    (
      parse_unit_linear_offset(gamma_args[0], s_name),
      parse_unit_linear_offset(gamma_args[1], s_name),
    ) {
    (Some((1, offset1)), Some((1, offset2))) =>
      if !expr_eq(expr_simplify(expr_add(offset1, offset2)), expr_zero()) {
        None
      } else {
        let order = expr_simplify(expr_sub(offset2, offset1))
        if expr_depends_on(order, s_name) {
          None
        } else {
          Some(@symspec.besselk(order, expr_int(2) * @symelem.sqrt(x)))
        }
      }
    _ => None
  }
}

///|
fn parse_unit_linear_offset(expr : Expr, var_name : String) -> (Int, Expr)? {
  match expr_simplify(expr) {
    @symcore.Expr::Add(args) => {
      let mut sign : Int? = None
      let offset_terms : Array[Expr] = []
      for arg in args {
        match parse_unit_linear_var_term(arg, var_name) {
          Some(term_sign) =>
            if sign is None {
              sign = Some(term_sign)
            } else {
              return None
            }
          None =>
            if expr_depends_on(arg, var_name) {
              return None
            } else {
              offset_terms.push(arg)
            }
        }
      }
      match sign {
        Some(term_sign) =>
          if offset_terms.is_empty() {
            Some((term_sign, expr_zero()))
          } else {
            Some((term_sign, expr_simplify(@symcore.add(offset_terms))))
          }
        None => None
      }
    }
    simplified =>
      match parse_unit_linear_var_term(simplified, var_name) {
        Some(term_sign) => Some((term_sign, expr_zero()))
        None => None
      }
  }
}

///|
fn parse_linear_offset_expr(expr : Expr, var_name : String) -> (Expr, Expr)? {
  match expr_simplify(expr) {
    @symcore.Expr::Add(args) => {
      let mut coeff : Expr? = None
      let offset_terms : Array[Expr] = []
      for arg in args {
        match parse_linear_var_coeff(arg, var_name) {
          Some(term_coeff) =>
            if coeff is None {
              coeff = Some(term_coeff)
            } else {
              return None
            }
          None =>
            if expr_depends_on(arg, var_name) {
              return None
            } else {
              offset_terms.push(arg)
            }
        }
      }
      match coeff {
        Some(term_coeff) =>
          if offset_terms.is_empty() {
            Some((expr_simplify(term_coeff), expr_zero()))
          } else {
            Some(
              (
                expr_simplify(term_coeff),
                expr_simplify(@symcore.add(offset_terms)),
              ),
            )
          }
        None => None
      }
    }
    @symcore.Expr::Mul(args) => {
      let mut coeff_scale = expr_one()
      let mut dependent : Expr? = None
      for arg in args {
        if expr_depends_on(arg, var_name) {
          if dependent is None {
            dependent = Some(arg)
          } else {
            return None
          }
        } else {
          coeff_scale = expr_mul(coeff_scale, arg)
        }
      }
      match dependent {
        Some(dep) =>
          match parse_linear_offset_expr(dep, var_name) {
            Some((coeff, offset)) =>
              Some(
                (
                  expr_simplify(expr_mul(coeff_scale, coeff)),
                  expr_simplify(expr_mul(coeff_scale, offset)),
                ),
              )
            None => None
          }
        None => None
      }
    }
    simplified =>
      match parse_linear_var_coeff(simplified, var_name) {
        Some(term_coeff) => Some((expr_simplify(term_coeff), expr_zero()))
        None => None
      }
  }
}

///|
fn parse_linear_var_coeff(expr : Expr, var_name : String) -> Expr? {
  match expr_simplify(expr) {
    @symcore.Expr::Symbol(name) =>
      if name == var_name {
        Some(expr_one())
      } else {
        None
      }
    @symcore.Expr::Mul(args) => {
      let mut saw_var = false
      let coeff_factors : Array[Expr] = []
      for arg in args {
        match expr_simplify(arg) {
          @symcore.Expr::Symbol(name) =>
            if name == var_name {
              if saw_var {
                return None
              }
              saw_var = true
            } else {
              return None
            }
          simplified =>
            if expr_depends_on(simplified, var_name) {
              return None
            } else {
              coeff_factors.push(simplified)
            }
        }
      }
      if !saw_var {
        None
      } else if coeff_factors.is_empty() {
        Some(expr_one())
      } else {
        Some(expr_simplify(@symcore.mul(coeff_factors)))
      }
    }
    _ => None
  }
}

///|
fn inverse_mellin_bessely_single_term(
  expr : Expr,
  s_sym : Expr,
  x : Expr,
) -> Expr? {
  let s_name = match symbol_name(s_sym) {
    Some(name) => name
    None => return None
  }
  let factors = match expr_simplify(expr) {
    @symcore.Expr::Mul(args) => args
    _ => return None
  }
  let mut coeff = expr_one()
  let mut trig_info : (Int, Expr)? = None
  let gamma_args : Array[Expr] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Function("gamma", [arg]) => gamma_args.push(arg)
      @symcore.Expr::Function("cos", _) =>
        match parse_pi_linear_trig_factor(factor, s_name, "cos") {
          Some(info) =>
            if trig_info is None {
              trig_info = Some(info)
            } else {
              return None
            }
          None => return None
        }
      other =>
        if expr_depends_on(other, s_name) {
          return None
        } else {
          coeff = expr_mul(coeff, other)
        }
    }
  }
  if gamma_args.length() != 2 ||
    !expr_same_simplified(
      coeff,
      expr_mul(expr_neg_one(), expr_pow(@symcore.pi(), expr_int(-1))),
    ) {
    return None
  }
  let (trig_coeff, half_order) = match trig_info {
    Some(v) => v
    None => return None
  }
  if trig_coeff != -1 && trig_coeff != 1 {
    return None
  }
  let mut saw_pos = false
  let mut saw_neg = false
  for arg in gamma_args {
    match parse_linear_offset_expr(arg, s_name) {
      Some((linear, offset)) if expr_same_simplified(linear, expr_one()) =>
        if expr_same_simplified(offset, half_order) {
          saw_pos = true
        } else if expr_same_simplified(
            offset,
            expr_mul(expr_neg_one(), half_order),
          ) {
          saw_neg = true
        } else {
          return None
        }
      _ => return None
    }
  }
  if !(saw_pos && saw_neg) {
    return None
  }
  Some(
    @symspec.bessely(
      expr_simplify(expr_mul(expr_int(-2 * trig_coeff), half_order)),
      expr_int(2) * @symelem.sqrt(x),
    ),
  )
}

///|
fn parse_gamma_like_linear_arg(expr : Expr, var_name : String) -> (Expr, Expr)? {
  match expr_simplify(expr) {
    @symcore.Expr::Function("gamma", [arg]) =>
      parse_linear_offset_expr(arg, var_name)
    @symcore.Expr::Function("factorial", [arg]) =>
      match parse_linear_offset_expr(arg, var_name) {
        Some((coeff, offset)) =>
          Some((coeff, expr_simplify(expr_add(offset, expr_one()))))
        None => None
      }
    _ => None
  }
}

///|
fn divide_by_pi_if_common(expr : Expr) -> Expr? {
  let pi = @symcore.pi()
  match expr_simplify(expr) {
    expr if expr_same_simplified(expr, pi) => Some(expr_one())
    @symcore.Expr::Mul(args) => {
      let rest : Array[Expr] = []
      let mut removed = false
      for arg in args {
        if !removed && expr_same_simplified(arg, pi) {
          removed = true
        } else {
          rest.push(arg)
        }
      }
      if !removed {
        None
      } else if rest.is_empty() {
        Some(expr_one())
      } else if rest.length() == 1 {
        Some(rest[0])
      } else {
        Some(expr_simplify(@symcore.mul(rest)))
      }
    }
    @symcore.Expr::Add(args) => {
      let reduced : Array[Expr] = []
      for arg in args {
        match divide_by_pi_if_common(arg) {
          Some(v) => reduced.push(v)
          None => return None
        }
      }
      if reduced.length() == 1 {
        Some(reduced[0])
      } else {
        Some(expr_simplify(@symcore.add(reduced)))
      }
    }
    _ => None
  }
}

///|
fn parse_pi_linear_trig_factor(
  expr : Expr,
  var_name : String,
  trig_name : String,
) -> (Int, Expr)? {
  match expr_simplify(expr) {
    @symcore.Expr::Function(name, [arg]) if name == trig_name =>
      match divide_by_pi_if_common(arg) {
        Some(linear_arg) =>
          match parse_linear_offset_expr(linear_arg, var_name) {
            Some((coeff, offset)) if expr_same_simplified(coeff, expr_one()) =>
              Some((1, expr_simplify(offset)))
            Some((coeff, offset)) if expr_same_simplified(coeff, expr_int(-1)) =>
              Some((-1, expr_simplify(offset)))
            _ => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn parse_unit_linear_var_term(expr : Expr, var_name : String) -> Int? {
  match expr_simplify(expr) {
    @symcore.Expr::Symbol(name) => if name == var_name { Some(1) } else { None }
    @symcore.Expr::Mul(args) => {
      let mut saw_var = false
      let coeff_factors : Array[Expr] = []
      for arg in args {
        match expr_simplify(arg) {
          @symcore.Expr::Symbol(name) =>
            if name == var_name {
              if saw_var {
                return None
              }
              saw_var = true
            } else {
              return None
            }
          simplified =>
            if expr_depends_on(simplified, var_name) {
              return None
            } else {
              coeff_factors.push(simplified)
            }
        }
      }
      if !saw_var {
        None
      } else {
        let coeff = if coeff_factors.is_empty() {
          expr_one()
        } else {
          expr_simplify(@symcore.mul(coeff_factors))
        }
        if expr_eq(coeff, expr_one()) {
          Some(1)
        } else if expr_eq(coeff, expr_int(-1)) {
          Some(-1)
        } else {
          None
        }
      }
    }
    _ => None
  }
}

///|
fn has_linear_offset(
  args : Array[(Expr, Expr)],
  target_coeff : Expr,
  check_offset : (Expr) -> Bool,
) -> Bool {
  for item in args {
    if expr_eq(item.0, target_coeff) && check_offset(item.1) {
      return true
    }
  }
  false
}

///|
fn expr_same_simplified(left : Expr, right : Expr) -> Bool {
  @symcore.compare_expr(expr_simplify(left), expr_simplify(right)) == 0
}

///|
fn parse_power_of_two(expr : Expr, var_name : String) -> Expr? {
  let simplified = expr_simplify(expr)
  if expr_depends_on(simplified, var_name) {
    return None
  }
  if expr_eq(simplified, expr_one()) {
    return Some(expr_zero())
  }
  match simplified {
    @symcore.Expr::Pow(base, exp) =>
      if expr_eq(base, expr_int(2)) && !expr_depends_on(exp, var_name) {
        Some(exp)
      } else {
        None
      }
    _ => None
  }
}

///|
fn inverse_mellin_term(pow : Expr, is_le : Bool, x : Expr) -> Expr {
  let xpow = if expr_is_zero(pow) { expr_one() } else { expr_pow(x, pow) }
  if is_le {
    expr_mul(xpow, @symspec.heaviside(expr_sub(expr_one(), x)))
  } else {
    expr_mul(xpow, @symspec.heaviside(expr_sub(x, expr_one())))
  }
}

///|
fn expr_factors(expr : Expr) -> Array[Expr] {
  match expr_simplify(expr) {
    @symcore.Expr::Mul(args) => args
    simplified => [simplified]
  }
}

///|
fn transform_add(
  terms : Array[Expr],
  _var_name : String,
  map_term : (Expr) -> Expr?,
) -> Expr? {
  let mapped : Array[Expr] = []
  for term in terms {
    match map_term(term) {
      Some(v) => mapped.push(v)
      None => return None
    }
  }
  Some(expr_simplify(@symcore.add(mapped)))
}

///|
fn split_mul(expr : Expr, var_name : String) -> (Expr, Array[Expr]) {
  let simplified = expr_simplify(expr)
  match simplified {
    @symcore.Expr::Mul(args) => {
      let mut coeff = expr_one()
      let vars : Array[Expr] = []
      for factor in args {
        if expr_depends_on(factor, var_name) {
          vars.push(factor)
        } else {
          coeff = expr_mul(coeff, factor)
        }
      }
      (coeff, vars)
    }
    _ =>
      if expr_depends_on(simplified, var_name) {
        (expr_one(), [simplified])
      } else {
        (simplified, [])
      }
  }
}

///|
fn split_division(expr : Expr) -> (Array[Expr], Expr?) {
  let simplified = expr_simplify(expr)
  match simplified {
    @symcore.Expr::Pow(base, exp) if expr_is_int_value(exp) is Some(exp_int) &&
      exp_int < 0 => {
      let n = -exp_int
      if n == 1 {
        ([], Some(base))
      } else {
        ([], Some(base ^ @symcore.int(n)))
      }
    }
    @symcore.Expr::Mul(args) => {
      let num : Array[Expr] = []
      let den : Array[Expr] = []
      for factor in args {
        match factor {
          @symcore.Expr::Pow(base, exp) if expr_is_int_value(exp)
            is Some(exp_int) &&
            exp_int < 0 => {
            let n = -exp_int
            if n == 1 {
              den.push(base)
            } else {
              den.push(base ^ @symcore.int(n))
            }
          }
          _ => num.push(factor)
        }
      }
      if den.length() == 0 {
        (num, None)
      } else {
        let den_expr = if den.length() == 1 {
          den[0]
        } else {
          expr_simplify(@symcore.mul(den))
        }
        (num, Some(den_expr))
      }
    }
    _ => ([simplified], None)
  }
}

///|
fn split_mul_factor(factors : Array[Expr], var_name : String) -> (Expr, Expr?) {
  let mut coeff = expr_one()
  let mut var_expr : Expr? = None
  for item in factors {
    if expr_depends_on(item, var_name) {
      var_expr = Some(
        match var_expr {
          None => item
          Some(prev) => expr_mul(prev, item)
        },
      )
    } else {
      coeff = expr_mul(coeff, item)
    }
  }
  (coeff, var_expr)
}

///|
fn factors_expr(factors : Array[Expr]) -> Expr {
  if factors.length() == 0 {
    expr_one()
  } else if factors.length() == 1 {
    factors[0]
  } else {
    expr_simplify(@symcore.mul(factors))
  }
}

///|
fn split_linear_coeff(expr : Expr, var_name : String) -> (Expr, Expr)? {
  match poly_coeffs_upto2(expr_simplify(expr), var_name) {
    Some(coeffs) =>
      if expr_is_zero(coeffs[2]) {
        Some((coeffs[1], coeffs[0]))
      } else {
        None
      }
    _ => None
  }
}

///|
fn parse_shifted_linear_power(
  expr : Expr,
  var_name : String,
) -> (Expr, Expr, Expr)? {
  match expr_simplify(expr) {
    @symcore.Expr::Pow(base, exp) =>
      match split_linear_coeff(base, var_name) {
        Some((coeff, offset)) =>
          if !expr_depends_on(coeff, var_name) &&
            !expr_depends_on(offset, var_name) {
            Some((coeff, offset, exp))
          } else {
            None
          }
        None => None
      }
    _ => None
  }
}

///|
fn parse_difference_quotient(expr : Expr, x_name : String) -> (Expr, Expr)? {
  let (num_factors, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  let (den_coeff, den_offset) = match split_linear_coeff(den, x_name) {
    Some(v) => v
    None => return None
  }
  if !expr_same_simplified(den_coeff, expr_one()) {
    return None
  }
  let scale = expr_mul(expr_neg_one(), den_offset)
  let num = factors_expr(num_factors)
  match expr_simplify(num) {
    @symcore.Expr::Add(args) if args.length() == 2 => {
      let mut power : Expr? = None
      let mut saw_const = false
      for arg in args {
        match parse_power_factor(arg, x_name) {
          Some(p) => power = Some(p)
          None =>
            match power {
              Some(p) =>
                if expr_same_simplified(
                    arg,
                    expr_mul(expr_neg_one(), expr_pow(scale, p)),
                  ) {
                  saw_const = true
                } else {
                  return None
                }
              None => return None
            }
        }
      }
      match power {
        Some(p) if saw_const => Some((p, scale))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn parse_sqrt_shifted_base(expr : Expr, x_name : String) -> (Expr, Expr)? {
  match expr_simplify(expr) {
    @symcore.Expr::Add(args) if args.length() == 2 => {
      let mut scale : Expr? = None
      let mut shift_sq : Expr? = None
      for arg in args {
        match arg {
          @symcore.Expr::Function("sqrt", [inner]) =>
            match split_linear_coeff(inner, x_name) {
              Some((coeff, offset)) if expr_same_simplified(coeff, expr_one()) &&
                !expr_depends_on(offset, x_name) =>
                if shift_sq is None {
                  shift_sq = Some(offset)
                } else {
                  return None
                }
              _ => return None
            }
          other =>
            if expr_depends_on(other, x_name) {
              return None
            } else if scale is None {
              scale = Some(other)
            } else {
              return None
            }
        }
      }
      match (scale, shift_sq) {
        (Some(v), Some(shift)) =>
          if expr_same_simplified(expr_pow(v, expr_int(2)), shift) ||
            expr_same_simplified(v, preferred_positive_sqrt(shift)) {
            Some((v, shift))
          } else {
            None
          }
        _ => None
      }
    }
    _ => None
  }
}

///|
fn parse_reciprocal_sqrt_shift(expr : Expr, x_name : String) -> Expr? {
  match expr_simplify(expr) {
    @symcore.Expr::Pow(@symcore.Expr::Function("sqrt", [inner]), exp) =>
      if expr_same_simplified(exp, expr_int(-1)) {
        match split_linear_coeff(inner, x_name) {
          Some((coeff, offset)) if expr_same_simplified(coeff, expr_one()) &&
            !expr_depends_on(offset, x_name) => Some(offset)
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn parse_sqrt_shifted_power_expr(
  expr : Expr,
  x_name : String,
) -> (Expr, Expr, Expr, Bool)? {
  match expr_simplify(expr) {
    @symcore.Expr::Pow(base, power) =>
      match parse_sqrt_shifted_base(base, x_name) {
        Some((scale, shift_sq)) => Some((scale, shift_sq, power, false))
        None => None
      }
    @symcore.Expr::Mul(args) if args.length() == 2 => {
      let mut scale : Expr? = None
      let mut shift_sq : Expr? = None
      let mut power : Expr? = None
      let mut saw_recip = false
      for arg in args {
        match arg {
          @symcore.Expr::Pow(base, exp) =>
            match parse_sqrt_shifted_base(base, x_name) {
              Some((parsed_scale, parsed_shift)) =>
                if scale is None {
                  scale = Some(parsed_scale)
                  shift_sq = Some(parsed_shift)
                  power = Some(exp)
                } else {
                  return None
                }
              None =>
                match parse_reciprocal_sqrt_shift(arg, x_name) {
                  Some(parsed_shift) =>
                    if saw_recip {
                      return None
                    } else {
                      shift_sq = Some(parsed_shift)
                      saw_recip = true
                    }
                  None => return None
                }
            }
          _ =>
            match parse_reciprocal_sqrt_shift(arg, x_name) {
              Some(parsed_shift) =>
                if saw_recip {
                  return None
                } else {
                  shift_sq = Some(parsed_shift)
                  saw_recip = true
                }
              None => return None
            }
        }
      }
      match (scale, shift_sq, power) {
        (Some(v), Some(shift), Some(exp)) if saw_recip &&
          expr_same_simplified(expr_pow(v, expr_int(2)), shift) =>
          Some((v, shift, exp, true))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn parse_log_x_power(expr : Expr, var_name : String) -> Int? {
  match expr_simplify(expr) {
    @symcore.Expr::Function("log", [@symcore.Expr::Symbol(name)]) =>
      if name == var_name {
        Some(1)
      } else {
        None
      }
    @symcore.Expr::Pow(
      @symcore.Expr::Function("log", [@symcore.Expr::Symbol(name)]),
      exp
    ) =>
      if name == var_name {
        match expr_is_int_value(exp) {
          Some(n) if n > 0 => Some(n)
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn parse_one_plus_linear(expr : Expr, var_name : String) -> Bool {
  match linear_coeffs(expr_simplify(expr), var_name) {
    Some((coeff, offset)) => expr_is_one(coeff) && expr_is_one(offset)
    _ => false
  }
}

///|
fn parse_one_minus_linear(expr : Expr, var_name : String) -> Bool {
  match linear_coeffs(expr_simplify(expr), var_name) {
    Some((coeff, offset)) =>
      (expr_is_one(coeff) || expr_is_minus_one(coeff)) && expr_is_one(offset)
    _ => false
  }
}

///|
fn parse_one_plus_inverse(expr : Expr, var_name : String) -> Bool {
  match expr_simplify(expr) {
    @symcore.Expr::Add(args) if args.length() == 2 => {
      let mut saw_one = false
      let mut saw_inv = false
      for arg in args {
        if expr_is_one(arg) {
          saw_one = true
        } else {
          match parse_negative_power(arg, var_name) {
            Some(power) if expr_eq(power, expr_one()) => saw_inv = true
            _ => return false
          }
        }
      }
      saw_one && saw_inv
    }
    _ => false
  }
}

///|
fn parse_abs_one_minus_linear(expr : Expr, var_name : String) -> Bool {
  match expr_simplify(expr) {
    @symcore.Expr::Function("Abs", [inner]) =>
      parse_one_minus_linear(inner, var_name)
    _ => false
  }
}

///|
fn parse_abs_one_minus_inverse(expr : Expr, var_name : String) -> Bool {
  match expr_simplify(expr) {
    @symcore.Expr::Function("Abs", [inner]) =>
      match expr_simplify(inner) {
        @symcore.Expr::Add(args) if args.length() == 2 => {
          let mut saw_one = false
          let mut saw_neg_inv = false
          for arg in args {
            if expr_is_one(arg) {
              saw_one = true
            } else {
              match
                parse_negative_power(expr_mul(expr_neg_one(), arg), var_name) {
                Some(power) if expr_eq(power, expr_one()) => saw_neg_inv = true
                _ => return false
              }
            }
          }
          saw_one && saw_neg_inv
        }
        _ => false
      }
    _ => false
  }
}

///|
fn split_linear_power_denom(
  expr : Expr,
  var_name : String,
) -> (Expr, Expr, Int)? {
  match expr_simplify(expr) {
    @symcore.Expr::Pow(base, exp) =>
      match expr_is_int_value(exp) {
        Some(power) if power > 0 =>
          match split_linear_coeff(base, var_name) {
            Some((a, b)) => Some((a, b, power))
            None => None
          }
        _ => None
      }
    _ =>
      match split_linear_coeff(expr, var_name) {
        Some((a, b)) => Some((a, b, 1))
        None => None
      }
  }
}

///|
fn split_shifted_square_denom(
  den : Expr,
  s_name : String,
) -> (Expr, Expr, Expr)? {
  match poly_coeffs_upto2(expr_simplify(den), s_name) {
    Some(coeffs) =>
      if expr_is_zero(coeffs[2]) ||
        expr_depends_on(coeffs[0], s_name) ||
        expr_depends_on(coeffs[1], s_name) ||
        expr_depends_on(coeffs[2], s_name) {
        None
      } else {
        let lead = coeffs[2]
        let shift = expr_div(coeffs[1], expr_mul(expr_int(2), lead))
        let remainder = expr_sub(
          expr_div(coeffs[0], lead),
          expr_pow(shift, expr_int(2)),
        )
        if expr_is_negative(remainder) || expr_is_zero(remainder) {
          None
        } else {
          Some((lead, shift, expr_sqrt_positive(remainder)))
        }
      }
    None => None
  }
}

///|
fn split_shifted_diff_square_denom(
  den : Expr,
  s_name : String,
) -> (Expr, Expr, Expr)? {
  match poly_coeffs_upto2(expr_simplify(den), s_name) {
    Some(coeffs) =>
      if expr_is_zero(coeffs[2]) ||
        expr_depends_on(coeffs[0], s_name) ||
        expr_depends_on(coeffs[1], s_name) ||
        expr_depends_on(coeffs[2], s_name) {
        None
      } else {
        let lead = coeffs[2]
        let shift = expr_div(coeffs[1], expr_mul(expr_int(2), lead))
        let remainder = expr_sub(
          expr_div(coeffs[0], lead),
          expr_pow(shift, expr_int(2)),
        )
        if expr_is_negative(remainder) {
          Some(
            (
              lead,
              shift,
              expr_sqrt_positive(expr_mul(expr_neg_one(), remainder)),
            ),
          )
        } else {
          None
        }
      }
    None => None
  }
}

///|
fn split_shifted_square_power_denom(
  den : Expr,
  s_name : String,
) -> (Expr, Expr, Expr, Int)? {
  match expr_simplify(den) {
    @symcore.Expr::Pow(base, exp) =>
      match expr_is_int_value(exp) {
        Some(power) if power > 1 =>
          match split_shifted_square_denom(base, s_name) {
            Some((lead, shift, freq)) => Some((lead, shift, freq, power))
            None => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn split_shifted_diff_square_power_denom(
  den : Expr,
  s_name : String,
) -> (Expr, Expr, Expr, Int)? {
  match expr_simplify(den) {
    @symcore.Expr::Pow(base, exp) =>
      match expr_is_int_value(exp) {
        Some(power) if power > 1 =>
          match split_shifted_diff_square_denom(base, s_name) {
            Some((lead, shift, freq)) => Some((lead, shift, freq, power))
            None => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn split_two_linear_factors(
  den : Expr,
  s_name : String,
) -> ((Expr, Expr), (Expr, Expr))? {
  match expr_simplify(den) {
    @symcore.Expr::Mul(args) if args.length() == 2 =>
      match
        (
          split_linear_power_denom(args[0], s_name),
          split_linear_power_denom(args[1], s_name),
        ) {
        (Some((a1, b1, 1)), Some((a2, b2, 1))) => Some(((a1, b1), (a2, b2)))
        _ => None
      }
    _ => None
  }
}

///|
fn split_quadratic_power_denom(
  den : Expr,
  s_name : String,
) -> (Expr, Expr, Bool, Int)? {
  match expr_simplify(den) {
    @symcore.Expr::Pow(base, exp) =>
      match expr_is_int_value(exp) {
        Some(power) if power > 1 =>
          match split_quadratic_base(base, s_name) {
            Some(info) => Some((info.0, info.1, info.2, power))
            None => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn split_quadratic_base(base : Expr, s_name : String) -> (Expr, Expr, Bool)? {
  match poly_coeffs_upto2(expr_simplify(base), s_name) {
    Some(c) =>
      if expr_is_zero(c[1]) &&
        !expr_depends_on(c[0], s_name) &&
        !expr_depends_on(c[2], s_name) &&
        !expr_is_zero(c[2]) {
        let ratio = expr_div(c[0], c[2])
        if expr_is_negative(ratio) {
          Some(
            (c[2], expr_sqrt_positive(expr_mul(expr_neg_one(), ratio)), true),
          )
        } else {
          Some((c[2], expr_sqrt_positive(ratio), false))
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn denom_to_diff_square_freq(den : Expr, s_name : String) -> Expr? {
  let coeffs = poly_coeffs_upto2(expr_simplify(den), s_name)
  match coeffs {
    Some(c) =>
      if expr_is_zero(c[1]) &&
        !expr_depends_on(c[0], s_name) &&
        !expr_depends_on(c[2], s_name) {
        if expr_is_zero(c[2]) {
          None
        } else {
          let ratio = expr_div(c[0], c[2])
          if expr_is_negative(ratio) {
            Some(expr_sqrt_positive(expr_mul(expr_neg_one(), ratio)))
          } else {
            None
          }
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn denom_to_square_freq(den : Expr, s_name : String) -> Expr? {
  let coeffs = poly_coeffs_upto2(expr_simplify(den), s_name)
  match coeffs {
    Some(c) =>
      if expr_is_zero(c[1]) &&
        !expr_depends_on(c[0], s_name) &&
        !expr_depends_on(c[2], s_name) {
        if expr_is_zero(c[2]) {
          None
        } else {
          let ratio = expr_div(c[0], c[2])
          if expr_is_negative(ratio) {
            None
          } else {
            Some(expr_sqrt_positive(ratio))
          }
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn extract_negative_quadratic_poly(
  inner : Expr,
  var_name : String,
) -> (Expr, Expr, Expr)? {
  let coeffs = poly_coeffs_upto2(expr_simplify(inner), var_name)
  match coeffs {
    Some(c) =>
      if !expr_depends_on(c[0], var_name) &&
        !expr_depends_on(c[1], var_name) &&
        !expr_depends_on(c[2], var_name) {
        match extract_explicit_negative_factor(c[2]) {
          Some(scale) => Some((scale, c[1], c[0]))
          None => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn fourier_gaussian_exponent(
  scale : Expr,
  linear : Expr,
  constant : Expr,
  var_expr : Expr,
  inverse : Bool,
) -> Expr {
  let const_term = expr_add(
    constant,
    expr_div(expr_pow(linear, expr_int(2)), expr_mul(expr_int(4), scale)),
  )
  let imag_coeff = expr_div(
    expr_mul(expr_mul(@symcore.pi(), @symcore.imag_unit()), linear),
    scale,
  )
  let linear_term = expr_mul(
    if inverse {
      imag_coeff
    } else {
      expr_mul(expr_neg_one(), imag_coeff)
    },
    var_expr,
  )
  let quad_term = expr_mul(
    expr_div(
      expr_mul(expr_neg_one(), expr_pow(@symcore.pi(), expr_int(2))),
      scale,
    ),
    expr_pow(var_expr, expr_int(2)),
  )
  expr_simplify(expr_add(const_term, expr_add(linear_term, quad_term)))
}

///|
fn extract_explicit_negative_factor(expr : Expr) -> Expr? {
  let simplified = expr_simplify(expr)
  match expr_num_value(simplified) {
    Some(value) =>
      if value.compare(@symnum.BigRational::zero()) < 0 {
        Some(@symcore.number(value.neg()))
      } else {
        None
      }
    None =>
      match simplified {
        @symcore.Expr::Mul(args) => {
          let positive_factors : Array[Expr] = []
          let mut sign = 1
          for arg in args {
            match expr_num_value(arg) {
              Some(value) =>
                if value.compare(@symnum.BigRational::zero()) < 0 {
                  sign = -sign
                  positive_factors.push(@symcore.number(value.neg()))
                } else {
                  positive_factors.push(arg)
                }
              None => positive_factors.push(arg)
            }
          }
          if sign < 0 {
            Some(
              if positive_factors.length() == 0 {
                expr_one()
              } else if positive_factors.length() == 1 {
                positive_factors[0]
              } else {
                expr_simplify(@symcore.mul(positive_factors))
              },
            )
          } else {
            None
          }
        }
        _ => None
      }
  }
}

///|
fn factorial_expr(n : Expr) -> Expr {
  match expr_is_int_value(n) {
    Some(v) if v > 1 => {
      let mut i = 2
      let mut out = expr_int(1)
      while i <= v {
        out = expr_mul(out, expr_int(i))
        i += 1
      }
      out
    }
    Some(v) if v >= 0 => expr_int(1)
    _ => expr_zero()
  }
}

///|
fn sqrt_pi() -> Expr {
  @symelem.sqrt(@symcore.pi())
}

///|
fn preferred_positive_sqrt(expr : Expr) -> Expr {
  match expr_exact_sqrt(expr_simplify(expr)) {
    @symcore.Expr::Function("sqrt", _) => expr_sqrt_positive(expr)
    exact => exact
  }
}

///|
fn expr_sqrt_two() -> Expr {
  @symelem.sqrt(expr_int(2))
}

///|
fn true_expr() -> Expr {
  @symcore.true_()
}

///|
fn false_expr() -> Expr {
  @symcore.false_()
}

///|
fn and_expr(lhs : Expr, rhs : Expr) -> Expr {
  if lhs == true_expr() {
    rhs
  } else if rhs == true_expr() {
    lhs
  } else if lhs == false_expr() || rhs == false_expr() {
    false_expr()
  } else if expr_eq(lhs, rhs) {
    lhs
  } else {
    @symcore.function("And", [lhs, rhs])
  }
}

///|
fn max_expr(lhs : Expr, rhs : Expr) -> Expr {
  let args = flatten_extrema_args("Max", [lhs, rhs])
  if args.any(is_pos_infinity_expr) {
    return oo_expr()
  }
  let filtered : Array[Expr] = []
  for arg in args {
    if !is_neg_infinity_expr(arg) &&
      !filtered.any(fn(item) { expr_eq(item, arg) }) {
      filtered.push(arg)
    }
  }
  if filtered.is_empty() {
    return neg_oo_expr()
  }
  let mut numeric_best : Expr? = None
  let nonnumeric : Array[Expr] = []
  for arg in filtered {
    match expr_num_value(arg) {
      Some(value) =>
        match numeric_best {
          Some(best) =>
            match expr_num_value(best) {
              Some(best_value) =>
                if value.compare(best_value) > 0 {
                  numeric_best = Some(arg)
                }
              None => numeric_best = Some(arg)
            }
          None => numeric_best = Some(arg)
        }
      None => nonnumeric.push(arg)
    }
  }
  let reduced : Array[Expr] = []
  match numeric_best {
    Some(best) => reduced.push(best)
    None => ()
  }
  for arg in nonnumeric {
    reduced.push(arg)
  }
  if reduced.length() == 1 {
    reduced[0]
  } else {
    @symcore.function("Max", reduced)
  }
}

///|
fn min_expr(lhs : Expr, rhs : Expr) -> Expr {
  let args = flatten_extrema_args("Min", [lhs, rhs])
  if args.any(is_neg_infinity_expr) {
    return neg_oo_expr()
  }
  let filtered : Array[Expr] = []
  for arg in args {
    if !is_pos_infinity_expr(arg) &&
      !filtered.any(fn(item) { expr_eq(item, arg) }) {
      filtered.push(arg)
    }
  }
  if filtered.is_empty() {
    return oo_expr()
  }
  let mut numeric_best : Expr? = None
  let nonnumeric : Array[Expr] = []
  for arg in filtered {
    match expr_num_value(arg) {
      Some(value) =>
        match numeric_best {
          Some(best) =>
            match expr_num_value(best) {
              Some(best_value) =>
                if value.compare(best_value) < 0 {
                  numeric_best = Some(arg)
                }
              None => numeric_best = Some(arg)
            }
          None => numeric_best = Some(arg)
        }
      None => nonnumeric.push(arg)
    }
  }
  let reduced : Array[Expr] = []
  match numeric_best {
    Some(best) => reduced.push(best)
    None => ()
  }
  for arg in nonnumeric {
    reduced.push(arg)
  }
  if reduced.length() == 1 {
    reduced[0]
  } else {
    @symcore.function("Min", reduced)
  }
}

///|
fn flatten_extrema_args(name : String, args : Array[Expr]) -> Array[Expr] {
  let out : Array[Expr] = []
  for arg in args {
    match @symcore.applied_parts(arg) {
      Some((head, inner)) if head == name =>
        for item in inner {
          out.push(item)
        }
      _ => out.push(arg)
    }
  }
  out
}

///|
fn is_pos_infinity_expr(expr : Expr) -> Bool {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::NumberSymbol(@symcore.NumberSymbolKind::Infinity) => true
    _ => false
  }
}

///|
fn is_neg_infinity_expr(expr : Expr) -> Bool {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::NumberSymbol(@symcore.NumberSymbolKind::NegativeInfinity) =>
      true
    _ => false
  }
}

///|
fn nonnegative_condition(expr : Expr) -> Expr {
  let simplified = expr_simplify(expr)
  if expr_is_structurally_nonnegative(simplified) {
    return true_expr()
  }
  match expr_num_value(simplified) {
    Some(value) =>
      if value.compare(@symnum.BigRational::zero()) >= 0 {
        true_expr()
      } else {
        false_expr()
      }
    None => @symcore.function("Ge", [simplified, expr_zero()])
  }
}

///|
fn expr_is_structurally_nonnegative(expr : Expr) -> Bool {
  match expr {
    @symcore.Expr::Function("exp", [_]) => true
    @symcore.Expr::Function("sqrt", [_]) => true
    @symcore.Expr::Function("Abs", [_]) => true
    @symcore.Expr::Pow(_, exp) =>
      match expr_is_int_value(exp) {
        Some(value) => value % 2 == 0
        None => false
      }
    _ => false
  }
}

///|
fn parse_negative_power(expr : Expr, var_name : String) -> Expr? {
  match parse_power_factor(expr, var_name) {
    Some(power) => extract_explicit_negative_factor(power)
    None => None
  }
}

///|
fn parse_negative_linear_exp(expr : Expr, var_name : String) -> Expr? {
  match expr {
    @symcore.Expr::Function("exp", [inner]) =>
      parse_negative_linear_exp_raw(inner, var_name)
    _ => None
  }
}

///|
fn parse_negative_abs_linear(inner : Expr, var_name : String) -> Expr? {
  let (coeff, factors) = split_mul(inner, var_name)
  if factors.length() != 1 {
    return None
  }
  match factors[0] {
    @symcore.Expr::Function("Abs", [@symcore.Expr::Symbol(name)]) if name ==
      var_name => extract_explicit_negative_factor(coeff)
    _ => None
  }
}

///|
fn parse_abs_scaled_var(inner : Expr, var_name : String) -> Expr? {
  let (coeff, factors) = split_mul(inner, var_name)
  if factors.length() != 1 {
    return None
  }
  match parse_power_factor(factors[0], var_name) {
    Some(power) if expr_eq(power, expr_one()) =>
      match extract_explicit_negative_factor(coeff) {
        Some(pos_coeff) => Some(pos_coeff)
        None => Some(coeff)
      }
    _ => None
  }
}

///|
fn parse_negative_abs_term(expr : Expr, var_name : String) -> Expr? {
  match expr_simplify(expr) {
    @symcore.Expr::Mul(args) => {
      let mut coeff = expr_one()
      let mut abs_scale : Expr? = None
      for arg in args {
        match arg {
          @symcore.Expr::Function("Abs", [inner]) =>
            match parse_abs_scaled_var(inner, var_name) {
              Some(scale) =>
                if abs_scale is None {
                  abs_scale = Some(scale)
                } else {
                  return None
                }
              None => return None
            }
          _ =>
            if expr_depends_on(arg, var_name) {
              return None
            } else {
              coeff = expr_mul(coeff, arg)
            }
        }
      }
      match abs_scale {
        Some(scale) =>
          match extract_explicit_negative_factor(coeff) {
            Some(neg_coeff) if expr_is_one(neg_coeff) => Some(scale)
            _ => None
          }
        None => None
      }
    }
    _ => None
  }
}

///|
fn parse_shifted_reciprocal_linear(expr : Expr, var_name : String) -> Expr? {
  match split_division(expr) {
    (num, Some(den)) =>
      if num.length() == 0 || (num.length() == 1 && expr_is_one(num[0])) {
        match linear_coeffs(den, var_name) {
          Some((coeff, offset)) =>
            if expr_is_one(coeff) && !expr_depends_on(offset, var_name) {
              Some(offset)
            } else {
              None
            }
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn parse_reciprocal_sqrt_quadratic(expr : Expr, var_name : String) -> Expr? {
  match split_division(expr) {
    (num, Some(@symcore.Expr::Function("sqrt", [inner]))) =>
      if num.length() == 0 || (num.length() == 1 && expr_is_one(num[0])) {
        match poly_coeffs_upto2(inner, var_name) {
          Some(coeffs) =>
            if expr_is_zero(coeffs[1]) &&
              expr_is_one(coeffs[2]) &&
              !expr_depends_on(coeffs[0], var_name) {
              Some(coeffs[0])
            } else {
              None
            }
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn parse_square_scaled_var(expr : Expr, var_name : String) -> Expr? {
  match poly_coeffs_upto2(expr_simplify(expr), var_name) {
    Some(coeffs) =>
      if expr_is_zero(coeffs[0]) &&
        expr_is_zero(coeffs[1]) &&
        !expr_depends_on(coeffs[2], var_name) {
        Some(coeffs[2])
      } else {
        None
      }
    _ => None
  }
}

///|
fn tuple_items(expr : Expr) -> Array[Expr]? {
  @symcore.tuple_items(expr)
}

///|
fn parse_cosine_linear_meijerg(expr : Expr, k_name : String) -> Expr? {
  match expr {
    @symcore.Expr::Function("meijerg", [a, b, z]) =>
      match
        (tuple_items(a), tuple_items(b), parse_square_scaled_var(z, k_name)) {
        (Some([a1, a2]), Some([b1, b2]), Some(scale)) =>
          match
            (tuple_items(a1), tuple_items(a2), tuple_items(b1), tuple_items(b2)) {
            (Some(a1s), Some(a2s), Some(b1s), Some(b2s)) =>
              if a1s.length() == 2 &&
                expr_eq(a1s[0], expr_rat(1, 2)) &&
                expr_is_zero(a1s[1]) &&
                a2s.is_empty() &&
                b1s.length() == 3 &&
                expr_eq(b1s[0], expr_rat(1, 2)) &&
                expr_is_zero(b1s[1]) &&
                expr_is_zero(b1s[2]) &&
                b2s.length() == 1 &&
                expr_eq(b2s[0], expr_rat(1, 2)) {
                Some(expr_mul(expr_int(4), scale))
              } else {
                None
              }
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn parse_cosine_sqrt_meijerg(expr : Expr, k_name : String) -> Expr? {
  match expr {
    @symcore.Expr::Function("meijerg", [a, b, z]) =>
      match
        (tuple_items(a), tuple_items(b), parse_square_scaled_var(z, k_name)) {
        (Some([a1, a2]), Some([b1, b2]), Some(scale)) =>
          match
            (tuple_items(a1), tuple_items(a2), tuple_items(b1), tuple_items(b2)) {
            (Some(a1s), Some(a2s), Some(b1s), Some(b2s)) =>
              if a1s.length() == 1 &&
                expr_eq(a1s[0], expr_rat(1, 2)) &&
                a2s.is_empty() &&
                b1s.length() == 2 &&
                expr_is_zero(b1s[0]) &&
                expr_is_zero(b1s[1]) &&
                b2s.length() == 1 &&
                expr_eq(b2s[0], expr_rat(1, 2)) {
                Some(expr_mul(expr_int(4), scale))
              } else {
                None
              }
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn parse_one_minus_abs_linear(expr : Expr, var_name : String) -> Expr? {
  match expr_simplify(expr) {
    @symcore.Expr::Add(args) if args.length() == 2 => {
      let mut saw_one = false
      let mut scale : Expr? = None
      for arg in args {
        if expr_is_one(arg) {
          saw_one = true
        } else {
          match parse_negative_abs_term(arg, var_name) {
            Some(found) => scale = Some(found)
            None => return None
          }
        }
      }
      if saw_one {
        scale
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn parse_negative_linear_exp_raw(inner : Expr, var_name : String) -> Expr? {
  match linear_coeffs(inner, var_name) {
    Some((a, b)) =>
      if expr_is_zero(b) {
        extract_explicit_negative_factor(a)
      } else {
        None
      }
    None => None
  }
}

///|
fn parse_negative_quadratic_exp(inner : Expr, var_name : String) -> Expr? {
  match poly_coeffs_upto2(inner, var_name) {
    Some(coeffs) =>
      if expr_is_zero(coeffs[0]) && expr_is_zero(coeffs[1]) {
        extract_explicit_negative_factor(coeffs[2])
      } else {
        None
      }
    None => None
  }
}

///|
fn parse_reciprocal_quadratic(expr : Expr, var_name : String) -> Expr? {
  match split_division(expr) {
    (num, Some(den)) =>
      if num.length() == 0 || (num.length() == 1 && expr_is_one(num[0])) {
        denom_to_square_freq(den, var_name)
      } else {
        None
      }
    _ => None
  }
}

///|
fn matches_negative_power_transform(
  expr : Expr,
  var_name : String,
  x : Expr,
  is_sine : Bool,
) -> Expr? {
  let (coeff, factors) = split_mul(expr, var_name)
  if factors.length() != 1 {
    return None
  }
  let power = match parse_power_factor(factors[0], var_name) {
    Some(v) => v
    None => return None
  }
  let a = expr_add(power, expr_one())
  let expected = if is_sine {
    expr_div(
      expr_mul(
        expr_pow(
          expr_int(2),
          expr_add(
            expr_div(expr_one(), expr_int(2)),
            expr_mul(expr_neg_one(), a),
          ),
        ),
        @symspec.gamma(expr_sub(expr_one(), expr_div(a, expr_int(2)))),
      ),
      @symspec.gamma(expr_div(expr_add(a, expr_one()), expr_int(2))),
    )
  } else {
    expr_div(
      expr_mul(
        expr_pow(
          expr_int(2),
          expr_add(
            expr_div(expr_one(), expr_int(2)),
            expr_mul(expr_neg_one(), a),
          ),
        ),
        @symspec.gamma(expr_div(expr_sub(expr_one(), a), expr_int(2))),
      ),
      @symspec.gamma(expr_div(a, expr_int(2))),
    )
  }
  if expr_eq(coeff, expected) {
    Some(expr_pow(x, expr_mul(expr_neg_one(), a)))
  } else {
    None
  }
}

///|
fn matches_hankel_power_transform(
  expr : Expr,
  k_name : String,
  r : Expr,
  nu : Expr,
) -> Expr? {
  let (coeff, factors) = split_mul(expr, k_name)
  if factors.length() != 1 {
    return None
  }
  let power = match parse_power_factor(factors[0], k_name) {
    Some(v) => v
    None => return None
  }
  let m = expr_add(power, expr_int(2))
  let expected = expr_mul(
    expr_pow(expr_int(2), expr_sub(expr_one(), m)),
    expr_div(
      @symspec.gamma(
        expr_add(
          expr_sub(expr_one(), expr_div(m, expr_int(2))),
          expr_div(nu, expr_int(2)),
        ),
      ),
      @symspec.gamma(
        expr_add(expr_div(m, expr_int(2)), expr_div(nu, expr_int(2))),
      ),
    ),
  )
  if expr_eq(coeff, expected) {
    Some(expr_pow(r, expr_mul(expr_neg_one(), m)))
  } else {
    None
  }
}

///|
fn inverse_hankel_exp_term(
  expr : Expr,
  k_name : String,
  r : Expr,
  nu : Expr,
) -> Expr? {
  let (coeff, factors) = split_mul(expr, k_name)
  if factors.length() != 2 {
    return None
  }
  let mut power_ok = false
  let mut kernel_a : Expr? = None
  for factor in factors {
    match parse_power_factor(factor, k_name) {
      Some(power) =>
        if expr_eq(power, expr_sub(expr_neg_one(), expr_add(nu, expr_int(2)))) {
          power_ok = true
        } else {
          return None
        }
      None =>
        match factor {
          @symcore.Expr::Pow(base, exp) if expr_eq(
              exp,
              expr_mul(expr_neg_one(), expr_add(nu, expr_rat(3, 2))),
            ) =>
            match base {
              @symcore.Expr::Add(args) if args.length() == 2 => {
                let mut saw_one = false
                let mut other : Expr? = None
                for arg in args {
                  if expr_is_one(arg) {
                    saw_one = true
                  } else {
                    other = Some(arg)
                  }
                }
                if !saw_one || other is None {
                  return None
                }
                match other.unwrap() {
                  @symcore.Expr::Mul(parts) if parts.length() == 2 => {
                    let mut a_sq : Expr? = None
                    let mut k_sq_inv = false
                    for part in parts {
                      match part {
                        @symcore.Expr::Pow(base2, exp2) if expr_eq(
                            exp2,
                            expr_int(-2),
                          ) &&
                          expr_eq(base2, @symcore.symbol(k_name)) =>
                          k_sq_inv = true
                        _ => a_sq = Some(part)
                      }
                    }
                    if k_sq_inv {
                      kernel_a = a_sq
                    } else {
                      return None
                    }
                  }
                  _ => return None
                }
              }
              _ => return None
            }
          _ => return None
        }
    }
  }
  if !power_ok || kernel_a is None {
    return None
  }
  let a = expr_sqrt_positive(kernel_a.unwrap())
  let expected = expr_div(
    expr_mul(
      expr_mul(expr_pow(expr_int(2), expr_add(nu, expr_one())), a),
      @symspec.gamma(expr_add(nu, expr_rat(3, 2))),
    ),
    sqrt_pi(),
  )
  if expr_eq(coeff, expected) {
    Some(
      expr_mul(
        expr_pow(r, nu),
        @symelem.exp(expr_mul(expr_neg_one(), expr_mul(a, r))),
      ),
    )
  } else {
    None
  }
}

///|
fn inverse_hankel_gaussian_term(
  expr : Expr,
  k_name : String,
  r : Expr,
  nu : Expr,
) -> Expr? {
  let (coeff, factors) = split_mul(expr, k_name)
  let mut power = expr_zero()
  let mut scale : Expr? = None
  for factor in factors {
    match parse_power_factor(factor, k_name) {
      Some(p) => power = expr_add(power, p)
      None =>
        match factor {
          @symcore.Expr::Function("exp", [inner]) =>
            match parse_negative_quadratic_exp(inner, k_name) {
              Some(a) =>
                if scale is None {
                  scale = Some(a)
                } else {
                  return None
                }
              None => return None
            }
          _ => return None
        }
    }
  }
  match scale {
    Some(v) if expr_eq(power, nu) => {
      let a = expr_div(expr_one(), expr_mul(expr_int(4), v))
      let expected = expr_pow(
        expr_mul(expr_int(2), v),
        expr_add(nu, expr_one()),
      )
      let forward_coeff = expr_pow(
        expr_div(expr_one(), expr_mul(expr_int(2), a)),
        expr_add(nu, expr_one()),
      )
      if expr_eq(coeff, expected) || expr_eq(coeff, forward_coeff) {
        Some(
          expr_mul(
            expr_pow(r, nu),
            @symelem.exp(
              expr_mul(expr_neg_one(), expr_mul(a, expr_pow(r, expr_int(2)))),
            ),
          ),
        )
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn expr_has_function_name(expr : Expr, name : String) -> Bool {
  match expr {
    @symcore.Expr::Function(func_name, args) =>
      func_name == name ||
      args.any(fn(arg) { expr_has_function_name(arg, name) })
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      args.any(fn(arg) { expr_has_function_name(arg, name) })
    @symcore.Expr::Pow(base, exp) =>
      expr_has_function_name(base, name) || expr_has_function_name(exp, name)
    _ => false
  }
}

///|
fn expr_is_negative(expr : Expr) -> Bool {
  match expr_num_value(expr_simplify(expr)) {
    Some(value) => value.compare(@symnum.BigRational::zero()) < 0
    None => false
  }
}

///|
fn expr_is_positive(expr : Expr) -> Bool {
  match expr_num_value(expr_simplify(expr)) {
    Some(value) => value.compare(@symnum.BigRational::zero()) > 0
    None => false
  }
}

///|
fn neg_oo_expr() -> Expr {
  @symcore.mul([@symcore.int(-1), @symcore.oo()])
}

///|
fn oo_expr() -> Expr {
  @symcore.oo()
}
