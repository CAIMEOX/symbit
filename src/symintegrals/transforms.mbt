///|
/// Stage-5 transform helpers.

///|
type LaplaceInfo = (Expr, Expr, Expr)

///|
type MellinInfo = (Expr, Expr, Expr, Expr)

///|
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
            expr_add(plane, @symelem.re(a))
          } else {
            expr_add(plane, a)
          }
          Some((expr_mul(@symelem.exp(exp_const), value), shifted_plane, cond))
        }
        None => Some((value, plane, cond))
      }
    None => None
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
  match symbol_name(s) {
    Some(_) =>
      match laplace_power_times_term(factors, t_name, shifted_s, s) {
        Some(info) => Some(info)
        None => laplace_generic_shifted_term(factors, t_name, shifted_s)
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
    @symcore.Expr::Function("LaplaceTransform", _)
    | @symcore.Expr::Function("Derivative", _) => {
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
  let mut delta_at : Expr? = None
  let rest : Array[Expr] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Function("DiracDelta", [arg]) =>
        match linear_coeffs(arg, t_name) {
          Some((coeff, offset)) =>
            if delta_at is None &&
              (expr_is_one(coeff) || expr_is_minus_one(coeff)) {
              delta_at = Some(
                if expr_is_one(coeff) {
                  expr_mul(expr_neg_one(), offset)
                } else {
                  offset
                },
              )
            } else {
              return None
            }
          None => return None
        }
      _ => rest.push(factor)
    }
  }
  match delta_at {
    Some(at) =>
      if expr_is_negative(at) {
        Some((expr_zero(), neg_oo_expr(), true_expr()))
      } else {
        Some(
          (
            expr_simplify(
              expr_mul(
                subst_symbol(factors_expr(rest), t_name, at),
                @symelem.exp(expr_mul(expr_neg_one(), expr_mul(at, s))),
              ),
            ),
            neg_oo_expr(),
            nonnegative_condition(at),
          ),
        )
      }
    None => None
  }
}

///|
fn laplace_heaviside_shift_term(
  factors : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  let mut shift : Expr? = None
  let rest : Array[Expr] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Function("Heaviside", [arg]) =>
        match parse_heaviside_limit(arg, t_name) {
          Some((bound, is_le)) =>
            if shift is None && !is_le {
              shift = Some(bound)
            } else {
              return None
            }
          None => return None
        }
      _ => rest.push(factor)
    }
  }
  match shift {
    Some(bound) =>
      if expr_is_negative(bound) {
        None
      } else {
        let shift_name = if t_name == "_laplace_u" {
          "_laplace_v"
        } else {
          "_laplace_u"
        }
        let shift_var = @symcore.symbol(shift_name)
        let shifted = subst_symbol(
          factors_expr(rest),
          t_name,
          expr_add(shift_var, bound),
        )
        match laplace_info_doit(expr_simplify(shifted), shift_name, s) {
          Some((value, plane, cond)) =>
            Some(
              (
                expr_simplify(
                  expr_mul(
                    @symelem.exp(expr_mul(expr_neg_one(), expr_mul(bound, s))),
                    value,
                  ),
                ),
                plane,
                and_expr(cond, nonnegative_condition(bound)),
              ),
            )
          None => None
        }
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
    @symcore.Expr::Pow(base, exp) => {
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
          None => None
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
              Some(v) => Some((v, expr_zero(), true_expr()))
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
              Some(v) => Some((v, expr_zero(), true_expr()))
              None => None
            }
          }
        }
        None => None
      }
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
    @symcore.Expr::Function("fresnels", [@symcore.Expr::Symbol(name)]) =>
      if name == t_name {
        let phase = expr_div(
          expr_pow(s, expr_int(2)),
          expr_mul(expr_int(2), @symcore.symbol("pi")),
        )
        let arg = expr_div(s, @symcore.symbol("pi"))
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
                      expr_add(
                        phase,
                        expr_div(@symcore.symbol("pi"), expr_int(4)),
                      ),
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
          expr_mul(expr_int(2), @symcore.symbol("pi")),
        )
        let arg = expr_div(s, @symcore.symbol("pi"))
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
                      expr_add(
                        phase,
                        expr_div(@symcore.symbol("pi"), expr_int(4)),
                      ),
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
                        expr_mul(@symcore.symbol("I"), @symcore.symbol("pi")),
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
    @symcore.Expr::Function("Derivative", args) =>
      laplace_derivative_term(args, t_name, s)
    _ =>
      if expr_depends_on(expr, t_name) {
        Some(generic_laplace_object(expr, t_name, s))
      } else {
        None
      }
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
  match laplace_generic_trig_term(first, second, t_name, s) {
    Some(info) => Some(info)
    None => laplace_generic_trig_term(second, first, t_name, s)
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
          let ia = expr_mul(@symcore.symbol("I"), a)
          Some(
            (
              expr_mul(
                expr_div(@symcore.symbol("I"), expr_int(2)),
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
          let ia = expr_mul(@symcore.symbol("I"), a)
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
pub fn do_inverse_laplace_doit(expr : Expr, s : Expr, t : Expr) -> Expr? {
  match symbol_name(s) {
    Some(s_name) => inverse_laplace_doit(expr_simplify(expr), s_name, t)
    None => None
  }
}

///|
fn inverse_laplace_doit(expr : Expr, s_name : String, t : Expr) -> Expr? {
  match expr {
    @symcore.Expr::Add(terms) =>
      transform_add(terms, s_name, fn(term) {
        inverse_laplace_doit(term, s_name, t)
      })
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
  inverse_laplace_ci_term(expr, s_name, t)
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
          Some((coeff, offset)) if expr_is_negative(coeff) =>
            if delay is None {
              delay = Some(expr_mul(expr_neg_one(), coeff))
              exp_const = offset
            } else {
              return None
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
                  expr_mul(expr_int(2), expr_mul(@symcore.symbol("pi"), k)),
                  scale,
                ),
              ),
              expr_mul(@symcore.symbol("pi"), k),
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
                    expr_pow(@symcore.symbol("pi"), expr_int(2)),
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
        _ =>
          match parse_fourier_abs_quadratic(den, k_name) {
            Some(a) if expr_eq(numerator, expr_mul(expr_int(2), a)) =>
              Some(
                @symelem.exp(
                  expr_mul(expr_neg_one(), expr_mul(a, @symelem.abs(x))),
                ),
              )
            _ => None
          }
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
              @symelem.sin(expr_div(expr_mul(@symcore.symbol("pi"), k), c1)),
              expr_int(2),
            ),
          ),
          expr_mul(
            expr_pow(@symcore.symbol("pi"), expr_int(2)),
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
      expr_mul(expr_mul(@symcore.symbol("pi"), @symcore.symbol("I")), k),
    ),
  )
}

///|
fn fourier_linear_shift_coeff() -> Expr {
  expr_mul(expr_int(2), expr_mul(@symcore.symbol("pi"), @symcore.symbol("I")))
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
fn parse_fourier_abs_quadratic(expr : Expr, k_name : String) -> Expr? {
  match poly_coeffs_upto2(expr_simplify(expr), k_name) {
    Some(coeffs) =>
      if expr_is_zero(coeffs[1]) &&
        !expr_depends_on(coeffs[0], k_name) &&
        expr_eq(
          coeffs[2],
          expr_mul(expr_int(4), expr_pow(@symcore.symbol("pi"), expr_int(2))),
        ) {
        Some(preferred_positive_sqrt(coeffs[0]))
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
      if !expr_eq(coeff, @symcore.symbol("pi")) || !expr_is_zero(offset) {
        return None
      }
    _ => return None
  }
  match num[0] {
    @symcore.Expr::Function("sin", [arg]) =>
      match linear_coeffs(arg, k_name) {
        Some((coeff, offset)) if expr_is_zero(offset) =>
          Some(
            expr_simplify(
              expr_div(expr_mul(expr_int(2), @symcore.symbol("pi")), coeff),
            ),
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
              expr_eq(coeffs[2], expr_pow(@symcore.symbol("pi"), expr_int(2))) {
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
            if expr_eq(
                expr_simplify(expr_mul(coeff, freq)),
                @symcore.symbol("pi"),
              ) {
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
            expr_mul(expr_int(2), @symcore.symbol("EulerGamma")),
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
                                @symcore.symbol("pi"),
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
        expr_mul(expr_int(2), @symcore.symbol("pi")),
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
pub fn do_inverse_mellin_doit(_expr : Expr, s : Expr, x : Expr) -> Expr? {
  match (symbol_name(s), symbol_name(x)) {
    (Some(s_name), Some(_)) =>
      inverse_mellin_doit(expr_simplify(_expr), s_name, x)
    _ => None
  }
}

///|
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
          None => None
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
      for term in terms {
        match mellin_info_doit(term, x_name, s) {
          Some((value, lo, up, term_cond)) => {
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
          None => return None
        }
      }
      Some(
        (
          expr_simplify(@symcore.add(values)),
          lower.unwrap_or(expr_mul(expr_neg_one(), @symcore.symbol("oo"))),
          upper.unwrap_or(@symcore.symbol("oo")),
          cond,
        ),
      )
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
fn mellin_special_info(expr : Expr, x_name : String, s : Expr) -> MellinInfo? {
  match expr {
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
                        expr_mul(@symcore.symbol("pi"), expr_sub(half_order, s)),
                      ),
                      expr_mul(
                        @symspec.gamma(expr_sub(s, half_order)),
                        @symspec.gamma(expr_add(s, half_order)),
                      ),
                    ),
                  ),
                  @symcore.symbol("pi"),
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
              @symcore.symbol("oo"),
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
            @symcore.symbol("oo"),
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
            @symcore.symbol("oo"),
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
fn mellin_bessel_sqrt_scale(coeff : Expr, s : Expr) -> Expr {
  if expr_eq(coeff, expr_int(2)) {
    expr_one()
  } else {
    expr_pow(expr_div(expr_int(4), expr_pow(coeff, expr_int(2))), s)
  }
}

///|
fn mellin_mul_term(factors : Array[Expr], x_name : String, s : Expr) -> Expr? {
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
        Some(
          (
            value,
            expr_mul(expr_neg_one(), pow),
            @symcore.symbol("oo"),
            true_expr(),
          ),
        )
      } else {
        Some(
          (
            value,
            expr_mul(expr_neg_one(), @symcore.symbol("oo")),
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
          @symcore.symbol("oo"),
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
        expr_mul(expr_neg_one(), @symcore.symbol("oo")),
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
        expr_mul(
          expr_mul(expr_neg_one(), @symcore.symbol("I")),
          @symcore.symbol("pi"),
        ),
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
  None
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
    expr_mul(expr_mul(@symcore.symbol("pi"), @symcore.symbol("I")), linear),
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
      expr_mul(expr_neg_one(), expr_pow(@symcore.symbol("pi"), expr_int(2))),
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
  @symelem.sqrt(@symcore.symbol("pi"))
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
  @symcore.symbol("True")
}

///|
fn false_expr() -> Expr {
  @symcore.symbol("False")
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
  match (expr_num_value(lhs), expr_num_value(rhs)) {
    (Some(ln), Some(rn)) => if ln.compare(rn) >= 0 { lhs } else { rhs }
    _ =>
      if expr_eq(lhs, rhs) {
        lhs
      } else {
        @symcore.function("Max", [lhs, rhs])
      }
  }
}

///|
fn min_expr(lhs : Expr, rhs : Expr) -> Expr {
  match (expr_num_value(lhs), expr_num_value(rhs)) {
    (Some(ln), Some(rn)) => if ln.compare(rn) <= 0 { lhs } else { rhs }
    _ =>
      if expr_eq(lhs, rhs) {
        lhs
      } else {
        @symcore.function("Min", [lhs, rhs])
      }
  }
}

///|
fn nonnegative_condition(expr : Expr) -> Expr {
  match expr_num_value(expr_simplify(expr)) {
    Some(value) =>
      if value.compare(@symnum.BigRational::zero()) >= 0 {
        true_expr()
      } else {
        false_expr()
      }
    None => @symcore.function("Ge", [expr, expr_zero()])
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
  match expr {
    @symcore.Expr::Function("Tuple", args) => Some(args)
    _ => None
  }
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
  @symcore.mul([@symcore.int(-1), @symcore.symbol("oo")])
}
