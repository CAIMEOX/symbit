///|
/// Meijer-style integration front door.
///
/// Current Limits:
/// - Coverage is limited to the non-elementary families recognized by the current heuristics.
/// - Unsupported cases return `None`.

///|
/// Try the Meijer-style fallback integrator.
///
/// - Does: Searches for non-elementary antiderivatives recognized by the local Meijer-style rules.
/// - Input: One integrand `Expr` and one variable name.
/// - Returns: `Some(Expr)` for a found antiderivative or `None`.
/// - Limits: Coverage is limited to the currently implemented special-function families.
pub fn meijerg_integrate(expr : Expr, var_name : String) -> Expr? {
  let target = expr_simplify(expr)
  if @symcore.application_has_name(target, "exp", arity=1) {
    match
      extract_erf_scale(@symcore.application_args(target).unwrap()[0], var_name) {
      Some(scale) =>
        Some(
          expr_mul(
            expr_div(sqrt_pi(), @symcore.int(2)),
            @symspec.erf(expr_mul(scale, @symcore.Expr::Symbol(var_name))),
          ),
        )
      None => None
    }
  } else {
    match sincos_division(target, var_name) {
      Some(res) => Some(res)
      None => None
    }
  }
}

///|
/// Compute an indefinite integral through the local Meijer-style rules.
///
/// - Does: Public SymPy-compatible front door over `meijerg_integrate`.
/// - Input: One integrand and one variable symbol.
/// - Returns: `Some(Expr)` for recognized Meijer-style antiderivatives.
/// - Limits: Uses the currently implemented special-function families.
pub fn meijerint_indefinite(expr : Expr, symbol : Expr) -> Expr? {
  match symbol {
    @symcore.Expr::Symbol(name) => meijerg_integrate(expr, name)
    _ => None
  }
}

///|
/// Compute a definite integral using a Meijer-style antiderivative when available.
///
/// - Does: Evaluates the local indefinite result at the two bounds.
/// - Input: Integrand, variable symbol, lower bound, and upper bound.
/// - Returns: `(value, true)` when an antiderivative is found.
/// - Limits: Does not implement SymPy's full convergence-condition search.
pub fn meijerint_definite(
  expr : Expr,
  symbol : Expr,
  lower : Expr,
  upper : Expr,
) -> (Expr, Bool)? {
  match (symbol, meijerint_indefinite(expr, symbol)) {
    (@symcore.Expr::Symbol(name), Some(anti)) =>
      Some(
        (
          expr_simplify(
            expr_sub(
              subst_symbol(anti, name, upper),
              subst_symbol(anti, name, lower),
            ),
          ),
          true,
        ),
      )
    _ => None
  }
}

///|
/// Try an inversion-style integral by delegating to inverse Laplace support.
///
/// - Does: Provides a practical local equivalent for the public `meijerint_inversion` hook.
/// - Input: Transform expression, source variable, and target variable.
/// - Returns: A recognized inverse transform result, if any.
/// - Source map: SymPy's `meijerint_inversion` in
///   `sympy/integrals/meijerint.py` is not a thin alias for the inverse
///   Laplace front door. It assumes the target is real positive, strips
///   exponential/base-power shifts, may return a shifted `DiracDelta`, `None`
///   for a provably non-real shift, or conditional `Piecewise` for an unknown
///   shift, then uses `_rewrite1 -> _rewrite_inversion -> _int_inversion` for
///   the non-recursive Mellin-Barnes contour path. The inverse Laplace
///   integration fallback in `laplace.py` calls that only after inverse Mellin
///   fails.
/// - Limits: This hook intentionally covers the cases already recognized by
///   local inverse Laplace rules. It does not yet implement SymPy's independent
///   analytic/condition-producing Mellin-Barnes contour inversion.
pub fn meijerint_inversion(expr : Expr, source : Expr, target : Expr) -> Expr? {
  match meijerint_inversion_no_laplace_fallback(expr, source, target) {
    Some(value) => return Some(value)
    None => ()
  }
  if meijerint_inversion_rejects_laplace_fallback(expr, source) {
    return None
  }
  match do_inverse_laplace_doit(expr, source, target) {
    Some(value) if @symcore.has(
        value,
        @symcore.Expr::FunctionHead("InverseLaplaceTransform"),
      ) => None
    other => other
  }
}

///|
fn meijerint_inversion_no_laplace_fallback(
  expr : Expr,
  source : Expr,
  target : Expr,
) -> Expr? {
  match meijerint_explicit_single_g_inversion(expr, source, target) {
    Some(value) => return Some(value)
    None => ()
  }
  if meijerint_explicit_nonreal_exp_shift(expr, source) {
    return None
  }
  match meijerint_exp_shift_delta(expr, source, target) {
    Some(value) => return Some(value)
    None => ()
  }
  match meijerint_exp_shifted_transform(expr, source, target) {
    Some(value) => return Some(value)
    None => ()
  }
  match meijerint_sqrt_exp_kernel(expr, source, target) {
    Some(value) => return Some(value)
    None => ()
  }
  if meijerint_source_rejects_base_power_shift(expr, source) {
    return None
  }
  if meijerint_source_rejects_unadorned_sqrt_kernel(expr, source) {
    return None
  }
  if meijerint_source_rejects_add(expr, source) {
    return None
  }
  None
}

///|
fn meijerint_inversion_rejects_laplace_fallback(
  expr : Expr,
  source : Expr,
) -> Bool {
  meijerint_explicit_nonreal_exp_shift(expr, source) ||
  meijerint_source_rejects_base_power_shift(expr, source) ||
  meijerint_source_rejects_unadorned_sqrt_kernel(expr, source) ||
  meijerint_source_rejects_add(expr, source)
}

///|
fn meijerint_source_rejects_add(expr : Expr, source : Expr) -> Bool {
  let s_name = match symbol_name(source) {
    Some(name) => name
    None => return false
  }
  match expr {
    // Source map: SymPy's meijerint_inversion does not split Add terms. The
    // termwise split lives one layer up in laplace.py's integration fallback,
    // so the public Meijer hook should reject source-dependent sums here.
    @symcore.Expr::Add(_) => expr_depends_on(expr, s_name)
    _ => false
  }
}

///|
fn meijerint_source_rejects_base_power_shift(
  expr : Expr,
  source : Expr,
) -> Bool {
  let s_name = match symbol_name(source) {
    Some(name) => name
    None => return false
  }
  meijerint_has_source_base_power_shift(expr, s_name)
}

///|
fn meijerint_has_source_base_power_shift(expr : Expr, s_name : String) -> Bool {
  match expr {
    @symcore.Expr::Pow(base, exp) =>
      if !meijerint_is_exp1(base) &&
        !expr_depends_on(base, s_name) &&
        expr_depends_on(exp, s_name) {
        true
      } else {
        @symcore.children(expr).any(child => {
          meijerint_has_source_base_power_shift(child, s_name)
        })
      }
    _ =>
      @symcore.children(expr).any(child => {
        meijerint_has_source_base_power_shift(child, s_name)
      })
  }
}

///|
fn meijerint_is_exp1(expr : Expr) -> Bool {
  expr == @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Exp1)
}

///|
fn meijerint_explicit_single_g_inversion(
  expr : Expr,
  source : Expr,
  target : Expr,
) -> Expr? {
  let s_name = match symbol_name(source) {
    Some(name) => name
    None => return None
  }
  match meijerint_explicit_single_g_parts(expr, s_name) {
    Some((a1, a2, b1, b2, coeff)) =>
      if a2.is_empty() && b1.is_empty() && b2.is_empty() {
        if meijerint_single_zero_param(a1) {
          Some(meijerint_explicit_single_g_j0_body(coeff, target))
        } else {
          match meijerint_single_half_param(a1) {
            Some(-1) =>
              Some(meijerint_explicit_single_g_a1_neg_half_body(coeff, target))
            _ => None
          }
        }
      } else if meijerint_single_zero_param(a1) && b2.is_empty() {
        if a2.is_empty() {
          match meijerint_single_nonnegative_int_param(b1) {
            Some(order) =>
              Some(
                meijerint_explicit_single_g_laguerre_body(order, coeff, target),
              )
            None =>
              match meijerint_single_half_param(b1) {
                Some(sign) =>
                  Some(
                    meijerint_explicit_single_g_b1_half_body(
                      sign, coeff, target,
                    ),
                  )
                None => None
              }
          }
        } else {
          meijerint_explicit_single_g_a2_b1_body(a2, b1, coeff, target)
        }
      } else if meijerint_single_zero_param(a1) &&
        a2.is_empty() &&
        b1.is_empty() {
        match meijerint_single_half_param(b2) {
          Some(sign) =>
            Some(meijerint_explicit_single_g_b2_half_body(sign, coeff, target))
          None => None
        }
      } else {
        None
      }
    None => None
  }
}

///|
fn meijerint_explicit_single_g_parts(
  expr : Expr,
  s_name : String,
) -> (Array[Expr], Array[Expr], Array[Expr], Array[Expr], Expr)? {
  match named_ternary_application(expr) {
    Some(("meijerg", a, b, arg)) =>
      match
        (
          @symcore.tuple_items(a),
          @symcore.tuple_items(b),
          linear_coeffs(arg, s_name),
        ) {
        (Some([a1, a2]), Some([b1, b2]), Some((coeff, offset))) =>
          if expr_is_zero(offset) && !expr_is_zero(coeff) {
            match
              (
                @symcore.tuple_items(a1),
                @symcore.tuple_items(a2),
                @symcore.tuple_items(b1),
                @symcore.tuple_items(b2),
              ) {
              (Some(a1s), Some(a2s), Some(b1s), Some(b2s)) =>
                Some((a1s, a2s, b1s, b2s, coeff))
              _ => None
            }
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn meijerint_explicit_single_g_j_arg(coeff : Expr, target : Expr) -> Expr {
  expr_div(
    expr_mul(@symcore.int(2), @symelem.sqrt(target)),
    @symelem.sqrt(coeff),
  )
}

///|
fn meijerint_explicit_single_g_j0_body(coeff : Expr, target : Expr) -> Expr {
  inverse_laplace_heaviside(
    target,
    expr_div(
      @symspec.besselj(
        @symcore.int(0),
        meijerint_explicit_single_g_j_arg(coeff, target),
      ),
      coeff,
    ),
  )
}

///|
fn meijerint_explicit_single_g_a1_neg_half_body(
  coeff : Expr,
  target : Expr,
) -> Expr {
  inverse_laplace_heaviside(
    target,
    expr_div(
      @symelem.sin(meijerint_explicit_single_g_j_arg(coeff, target)),
      expr_mul(sqrt_pi(), coeff),
    ),
  )
}

///|
fn meijerint_explicit_single_g_a2_b1_body(
  a2 : Array[Expr],
  b1 : Array[Expr],
  coeff : Expr,
  target : Expr,
) -> Expr? {
  if meijerint_single_zero_param(a2) {
    match meijerint_single_nonnegative_int_param(b1) {
      Some(0) => Some(meijerint_explicit_single_g_j0_body(coeff, target))
      Some(1) =>
        Some(meijerint_explicit_single_g_a2_zero_b1_one_body(coeff, target))
      _ => None
    }
  } else {
    match (meijerint_single_half_param(a2), meijerint_single_zero_param(b1)) {
      (Some(1), true) =>
        Some(
          meijerint_explicit_single_g_a2_pos_half_b1_zero_body(coeff, target),
        )
      (Some(-1), true) =>
        Some(
          meijerint_explicit_single_g_a2_neg_half_b1_zero_body(coeff, target),
        )
      _ => None
    }
  }
}

///|
fn meijerint_explicit_single_g_a2_zero_b1_one_body(
  coeff : Expr,
  target : Expr,
) -> Expr {
  let arg = meijerint_explicit_single_g_j_arg(coeff, target)
  inverse_laplace_heaviside(
    target,
    expr_div(
      expr_sub(
        @symspec.besselj(@symcore.int(0), arg),
        expr_mul(
          expr_div(@symelem.sqrt(target), @symelem.sqrt(coeff)),
          @symspec.besselj(@symcore.int(1), arg),
        ),
      ),
      coeff,
    ),
  )
}

///|
fn meijerint_explicit_single_g_a2_pos_half_b1_zero_body(
  coeff : Expr,
  target : Expr,
) -> Expr {
  let arg = meijerint_explicit_single_g_j_arg(coeff, target)
  inverse_laplace_heaviside(
    target,
    expr_div(
      @symelem.sin(arg),
      expr_mul(sqrt_pi(), expr_mul(@symelem.sqrt(coeff), @symelem.sqrt(target))),
    ),
  )
}

///|
fn meijerint_explicit_single_g_a2_neg_half_b1_zero_body(
  coeff : Expr,
  target : Expr,
) -> Expr {
  let arg = meijerint_explicit_single_g_j_arg(coeff, target)
  inverse_laplace_heaviside(
    target,
    expr_div(@symelem.cos(arg), expr_mul(sqrt_pi(), coeff)),
  )
}

///|
fn meijerint_single_zero_param(params : Array[Expr]) -> Bool {
  params.length() == 1 && expr_is_zero(params[0])
}

///|
fn meijerint_single_nonnegative_int_param(params : Array[Expr]) -> Int? {
  if params.length() != 1 {
    return None
  }
  match expr_is_int_value(params[0]) {
    Some(value) if value >= 0 => Some(value)
    _ => None
  }
}

///|
fn meijerint_single_half_param(params : Array[Expr]) -> Int? {
  if params.length() != 1 {
    return None
  }
  match expr_num_value(params[0]) {
    Some(value) =>
      if value.denominator().to_int() == 2 {
        match value.numerator().to_int() {
          1 => Some(1)
          -1 => Some(-1)
          _ => None
        }
      } else {
        None
      }
    None => None
  }
}

///|
fn meijerint_explicit_single_g_laguerre_body(
  order : Int,
  coeff : Expr,
  target : Expr,
) -> Expr {
  let scaled_target = expr_div(target, coeff)
  let shape = if order == 0 {
    @symcore.int(1)
  } else {
    meijerint_factorial_laguerre_poly(order, scaled_target)
  }
  inverse_laplace_heaviside(
    target,
    expr_div(
      expr_mul(shape, @symelem.exp(expr_mul(@symcore.int(-1), scaled_target))),
      coeff,
    ),
  )
}

///|
fn meijerint_explicit_single_g_b1_half_body(
  sign : Int,
  coeff : Expr,
  target : Expr,
) -> Expr {
  let u = expr_div(target, expr_mul(@symcore.int(2), coeff))
  let scaled = expr_div(target, coeff)
  let i0 = @symspec.besseli(@symcore.int(0), u)
  let exp_term = @symelem.exp(expr_mul(@symcore.int(-1), u))
  let core = if sign < 0 {
    i0
  } else {
    let i1 = @symspec.besseli(@symcore.int(1), u)
    expr_div(
      expr_add(
        expr_mul(expr_sub(@symcore.int(1), scaled), i0),
        expr_mul(scaled, i1),
      ),
      @symcore.int(2),
    )
  }
  inverse_laplace_heaviside(
    target,
    expr_div(expr_mul(sqrt_pi(), expr_mul(exp_term, core)), coeff),
  )
}

///|
fn meijerint_explicit_single_g_b2_half_body(
  sign : Int,
  coeff : Expr,
  target : Expr,
) -> Expr {
  let u = expr_div(target, expr_mul(@symcore.int(2), coeff))
  let scaled = expr_div(target, coeff)
  let i0 = @symspec.besseli(@symcore.int(0), u)
  let exp_term = @symelem.exp(u)
  let core = if sign < 0 {
    i0
  } else {
    let i1 = @symspec.besseli(@symcore.int(1), u)
    expr_mul(
      expr_rat(-1, 2),
      expr_add(
        expr_mul(expr_add(@symcore.int(1), scaled), i0),
        expr_mul(scaled, i1),
      ),
    )
  }
  inverse_laplace_heaviside(
    target,
    expr_div(expr_mul(exp_term, core), expr_mul(sqrt_pi(), coeff)),
  )
}

///|
fn meijerint_factorial_laguerre_poly(order : Int, x : Expr) -> Expr {
  let n_fact = factorial_expr(@symcore.int(order))
  let terms : Array[Expr] = []
  for k in 0..<=order {
    let k_fact = factorial_expr(@symcore.int(k))
    let nk_fact = factorial_expr(@symcore.int(order - k))
    let denom = expr_mul(expr_mul(k_fact, k_fact), nk_fact)
    let coeff = expr_div(expr_mul(n_fact, n_fact), denom)
    let signed_coeff = if k % 2 == 0 {
      coeff
    } else {
      expr_mul(@symcore.int(-1), coeff)
    }
    let power = if k == 0 {
      @symcore.int(1)
    } else {
      expr_pow(x, @symcore.int(k))
    }
    terms.push(expr_mul(signed_coeff, power))
  }
  @symcore.add(terms)
}

///|
fn meijerint_source_rejects_unadorned_sqrt_kernel(
  expr : Expr,
  source : Expr,
) -> Bool {
  let s_name = match symbol_name(source) {
    Some(name) => name
    None => return false
  }
  if !transform_head_flags(expr, s_name).has_irrational_shape {
    return false
  }
  let (num_factors, den_opt) = split_division_raw(expr)
  match den_opt {
    Some(den) => {
      let num = factors_expr(num_factors)
      !expr_depends_on(num, s_name) &&
      meijerint_source_rejects_sqrt_denominator(den, s_name)
    }
    None => {
      let (coeff, factors) = split_mul(expr, s_name)
      if factors.length() != 1 || expr_depends_on(coeff, s_name) {
        false
      } else {
        meijerint_source_rejects_negative_half_power(factors[0], s_name)
      }
    }
  }
}

///|
fn meijerint_source_rejects_sqrt_denominator(
  den : Expr,
  s_name : String,
) -> Bool {
  match parse_sqrt_affine(den, s_name) {
    Some(_) => return true
    None => ()
  }
  match parse_scaled_sqrt_linear_plus_const(den, s_name) {
    Some(_) => true
    None => false
  }
}

///|
fn meijerint_source_rejects_negative_half_power(
  expr : Expr,
  s_name : String,
) -> Bool {
  match expr {
    @symcore.Expr::Pow(base, exp) if expr_same_simplified(exp, expr_rat(-1, 2)) =>
      match split_linear_coeff_direct(base, s_name) {
        Some((coeff, offset)) =>
          !expr_is_zero(coeff) &&
          !expr_depends_on(coeff, s_name) &&
          !expr_depends_on(offset, s_name)
        None => false
      }
    _ => false
  }
}

///|
fn meijerint_explicit_nonreal_exp_shift(expr : Expr, source : Expr) -> Bool {
  match meijerint_exp_shift_components(expr, source) {
    Some((_scale, shift, _offset)) =>
      match meijerint_exact_complex_parts(shift) {
        Some((_real, imag)) => !expr_is_zero(imag)
        None => false
      }
    None => false
  }
}

///|
fn meijerint_exp_shift_delta(
  expr : Expr,
  source : Expr,
  target : Expr,
) -> Expr? {
  match meijerint_exp_shift_components(expr, source) {
    Some((scale, shift, offset)) =>
      match meijerint_exact_complex_parts(shift) {
        Some((real_shift, imag_shift)) if expr_is_zero(imag_shift) => {
          let weight = if expr_is_zero(offset) {
            scale
          } else {
            expr_mul(scale, @symelem.exp(offset))
          }
          Some(
            expr_simplify(
              expr_mul(
                weight,
                @symcore.raw_function("DiracDelta", [
                  expr_add(target, real_shift),
                ]),
              ),
            ),
          )
        }
        Some((_real_shift, _imag_shift)) => None
        None => {
          let weight = if expr_is_zero(offset) {
            scale
          } else {
            expr_mul(scale, @symelem.exp(offset))
          }
          let value = expr_simplify(
            expr_mul(
              weight,
              @symcore.raw_function("DiracDelta", [expr_add(target, shift)]),
            ),
          )
          let cond = @symcore.raw_function("Eq", [
            meijerint_symbolic_im(shift),
            @symcore.int(0),
          ])
          Some(@symcore.raw_function("Piecewise", [value, cond]))
        }
      }
    None => None
  }
}

///|
fn meijerint_exp_shift_components(
  expr : Expr,
  source : Expr,
) -> (Expr, Expr, Expr)? {
  let s_name = match symbol_name(source) {
    Some(name) => name
    None => return None
  }
  let (scale, factors) = split_mul(expr, s_name)
  if factors.length() == 0 {
    return None
  }
  // Source map: SymPy's meijerint_inversion scans a Mul and accumulates every
  // exp(a*x + b) shift before deciding whether the remaining expression is
  // source-free. This is intentionally narrower than normal inverse-Laplace
  // dispatch: if any source-dependent non-exp factor remains, this helper
  // declines and the ordinary inverse rules handle it.
  let mut shift = @symcore.int(0)
  let mut offset = @symcore.int(0)
  for factor in factors {
    match unary_application_arg(factor, "exp") {
      Some(inner) =>
        match linear_coeffs(inner, s_name) {
          Some((part_shift, part_offset)) => {
            shift = expr_simplify(expr_add(shift, part_shift))
            offset = expr_simplify(expr_add(offset, part_offset))
          }
          None => return None
        }
      None => return None
    }
  }
  Some((scale, shift, offset))
}

///|
fn meijerint_exp_shifted_transform(
  expr : Expr,
  source : Expr,
  target : Expr,
) -> Expr? {
  let s_name = match symbol_name(source) {
    Some(name) => name
    None => return None
  }
  let t_name = match symbol_name(target) {
    Some(name) => name
    None => return None
  }
  let (scale, factors) = split_mul(expr, s_name)
  if factors.length() == 0 {
    return None
  }
  let residual_factors : Array[Expr] = []
  let mut residual_scale = scale
  let mut shift = @symcore.int(0)
  let mut stripped = false
  for factor in factors {
    match unary_application_arg(factor, "exp") {
      Some(inner) =>
        match linear_coeffs(inner, s_name) {
          Some((part_shift, part_offset)) if !expr_is_zero(part_shift) => {
            stripped = true
            shift = expr_simplify(expr_add(shift, part_shift))
            if !expr_is_zero(part_offset) {
              residual_scale = expr_simplify(
                expr_mul(residual_scale, @symelem.exp(part_offset)),
              )
            }
          }
          _ => residual_factors.push(factor)
        }
      None => residual_factors.push(factor)
    }
  }
  if !stripped {
    return None
  }
  let residual = expr_simplify(
    expr_mul(residual_scale, factors_expr(residual_factors)),
  )
  if !expr_depends_on(residual, s_name) ||
    !meijerint_shift_residual_supported(residual, s_name) {
    return None
  }
  match do_inverse_laplace_doit(residual, source, target) {
    Some(value) =>
      Some(subst_symbol(value, t_name, expr_simplify(expr_add(target, shift))))
    None => None
  }
}

///|
fn meijerint_shift_residual_supported(expr : Expr, s_name : String) -> Bool {
  if !expr_laplace_rational_candidate(expr, s_name) {
    return false
  }
  let (num_factors, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(value) => value
    None => return false
  }
  let num = factors_expr(num_factors)
  match num {
    @symcore.Expr::Add(_) if expr_depends_on(num, s_name) => return false
    _ => ()
  }
  let num_coeffs = match poly_coeffs_general_int(num, s_name) {
    Some(value) => poly_trim_general_int(value)
    None => return false
  }
  let den_coeffs = match poly_coeffs_general_int(den, s_name) {
    Some(value) => poly_trim_general_int(value)
    None => return false
  }
  den_coeffs.length() > 1 && num_coeffs.length() < den_coeffs.length()
}

///|
fn meijerint_symbolic_im(expr : Expr) -> Expr {
  match meijerint_exact_complex_parts(expr) {
    Some((_real, imag)) => return imag
    None => ()
  }
  match expr {
    @symcore.Expr::Add(args) => {
      let parts : Array[Expr] = []
      for arg in args {
        let imag = meijerint_symbolic_im(arg)
        if !expr_is_zero(imag) {
          parts.push(imag)
        }
      }
      if parts.length() == 0 {
        @symcore.int(0)
      } else {
        expr_simplify(@symcore.add(parts))
      }
    }
    @symcore.Expr::Mul(args) => {
      let unknown : Array[Expr] = []
      let mut real = @symcore.int(1)
      let mut imag = @symcore.int(0)
      for arg in args {
        match meijerint_exact_complex_parts(arg) {
          Some((arg_real, arg_imag)) => {
            let next_real = expr_sub(
              expr_mul(real, arg_real),
              expr_mul(imag, arg_imag),
            )
            let next_imag = expr_add(
              expr_mul(real, arg_imag),
              expr_mul(imag, arg_real),
            )
            real = expr_simplify(next_real)
            imag = expr_simplify(next_imag)
          }
          None => unknown.push(arg)
        }
      }
      if unknown.length() == 0 {
        imag
      } else {
        let rest = factors_expr(unknown)
        expr_simplify(
          expr_add(
            expr_mul(real, @symelem.im(rest)),
            expr_mul(imag, @symelem.re(rest)),
          ),
        )
      }
    }
    _ => @symelem.im(expr)
  }
}

///|
fn meijerint_exact_complex_parts(expr : Expr) -> (Expr, Expr)? {
  match expr {
    @symcore.Expr::Number(_)
    | @symcore.Expr::Float(_)
    | @symcore.Expr::NumberSymbol(
      @symcore.NumberSymbolKind::Pi
      | @symcore.NumberSymbolKind::Exp1
      | @symcore.NumberSymbolKind::EulerGamma
      | @symcore.NumberSymbolKind::GoldenRatio
      | @symcore.NumberSymbolKind::Catalan
    ) => Some((expr, @symcore.int(0)))
    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit) =>
      Some((@symcore.int(0), @symcore.int(1)))
    @symcore.Expr::Add(args) => {
      let mut real = @symcore.int(0)
      let mut imag = @symcore.int(0)
      for arg in args {
        match meijerint_exact_complex_parts(arg) {
          Some((arg_real, arg_imag)) => {
            real = expr_add(real, arg_real)
            imag = expr_add(imag, arg_imag)
          }
          None => return None
        }
      }
      Some((expr_simplify(real), expr_simplify(imag)))
    }
    @symcore.Expr::Mul(args) => {
      let mut real = @symcore.int(1)
      let mut imag = @symcore.int(0)
      for arg in args {
        match meijerint_exact_complex_parts(arg) {
          Some((arg_real, arg_imag)) => {
            let next_real = expr_sub(
              expr_mul(real, arg_real),
              expr_mul(imag, arg_imag),
            )
            let next_imag = expr_add(
              expr_mul(real, arg_imag),
              expr_mul(imag, arg_real),
            )
            real = expr_simplify(next_real)
            imag = expr_simplify(next_imag)
          }
          None => return None
        }
      }
      Some((real, imag))
    }
    _ => None
  }
}

///|
fn meijerint_sqrt_exp_kernel(
  expr : Expr,
  source : Expr,
  target : Expr,
) -> Expr? {
  let s_name = match symbol_name(source) {
    Some(name) => name
    None => return None
  }
  let (scale, factors) = split_mul(expr, s_name)
  if factors.length() != 1 {
    return None
  }
  let param = match
    meijerint_sqrt_exp_kernel_param(factors[0], source, s_name) {
    Some(value) => value
    None => return None
  }
  if !meijerint_sqrt_exp_kernel_scale_matches(scale, param) {
    return None
  }
  match meijerint_exact_complex_parts(param) {
    Some((real, imag)) =>
      if !expr_is_zero(imag) || !expr_is_positive(real) {
        return None
      }
    None => ()
  }
  let body = meijerint_sqrt_exp_kernel_body(param, target)
  if expr_is_positive(param) {
    Some(body)
  } else {
    Some(
      @symcore.raw_function("Piecewise", [
        body,
        meijerint_sqrt_exp_kernel_cond(param),
        @symcore.raw_function("InverseLaplaceTransform", [
          expr,
          source,
          target,
          @symcore.Expr::Symbol("_None"),
        ]),
        true_expr(),
      ]),
    )
  }
}

///|
fn meijerint_sqrt_exp_kernel_param(
  factor : Expr,
  source : Expr,
  s_name : String,
) -> Expr? {
  let inner = match unary_application_arg(factor, "exp") {
    Some(value) => value
    None => return None
  }
  let (coeff, factors) = split_mul(inner, s_name)
  if factors.length() != 1 || !meijerint_is_source_sqrt(factors[0], source) {
    return None
  }
  match
    unary_application_arg(
      expr_simplify(expr_div(coeff, @symcore.int(-2))),
      "sqrt",
    ) {
    Some(param) => Some(param)
    None => None
  }
}

///|
fn meijerint_is_source_sqrt(expr : Expr, source : Expr) -> Bool {
  match unary_application_arg(expr, "sqrt") {
    Some(arg) => expr_eq(arg, source)
    None =>
      match expr {
        @symcore.Expr::Pow(base, exp) =>
          expr_eq(base, source) && expr_same_simplified(exp, expr_rat(1, 2))
        _ => false
      }
  }
}

///|
fn meijerint_sqrt_exp_kernel_scale_matches(scale : Expr, param : Expr) -> Bool {
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  expr_same_simplified(expr_mul(scale, @symelem.sqrt(param)), sqrt_pi()) ||
  expr_same_simplified(scale, @symelem.sqrt(expr_div(pi, param))) ||
  expr_same_simplified(scale, expr_div(sqrt_pi(), @symelem.sqrt(param)))
}

///|
fn meijerint_sqrt_exp_kernel_body(param : Expr, target : Expr) -> Expr {
  expr_simplify(
    expr_div(
      expr_mul(
        @symelem.exp(expr_mul(@symcore.int(-1), expr_div(param, target))),
        @symspec.heaviside(target),
      ),
      expr_pow(target, expr_rat(3, 2)),
    ),
  )
}

///|
fn meijerint_sqrt_exp_kernel_cond(param : Expr) -> Expr {
  let polar = @symcore.raw_function("polar_lift", [param])
  let root = @symelem.sqrt(polar)
  let imag = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::ImaginaryUnit,
  )
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  let quarter_i_pi = expr_div(expr_mul(imag, pi), @symcore.int(4))
  @symcore.raw_function("And", [
    @symcore.raw_function("Ne", [root, @symcore.int(0)]),
    @symcore.raw_function("Gt", [
      @symelem.re(
        expr_mul(@symelem.exp(expr_mul(@symcore.int(-1), quarter_i_pi)), root),
      ),
      @symcore.int(0),
    ]),
    @symcore.raw_function("Gt", [
      @symelem.re(expr_mul(@symelem.exp(quarter_i_pi), root)),
      @symcore.int(0),
    ]),
  ])
}

///|
fn sincos_division(expr : Expr, var_name : String) -> Expr? {
  let (numerator, den_opt) = extract_division(expr)
  match den_opt {
    None => None
    Some(den) =>
      if !expr_is_symbol(den, var_name) {
        None
      } else if numerator.length() != 1 {
        None
      } else {
        match
          (
            @symcore.application_name(numerator[0]),
            @symcore.application_args(numerator[0]),
          ) {
          (Some("sin"), Some([arg])) =>
            match linear_coeffs(arg, var_name) {
              Some(pair) => {
                let a = pair.0
                let b = pair.1
                if expr_is_zero(b) && !expr_is_zero(a) {
                  Some(
                    @symspec.si(expr_mul(a, @symcore.Expr::Symbol(var_name))),
                  )
                } else {
                  None
                }
              }
              None => None
            }
          (Some("cos"), Some([arg])) =>
            match linear_coeffs(arg, var_name) {
              Some(pair) => {
                let a = pair.0
                let b = pair.1
                if expr_is_zero(b) && !expr_is_zero(a) {
                  Some(
                    @symspec.ci(expr_mul(a, @symcore.Expr::Symbol(var_name))),
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
  }
}

///|
fn extract_erf_scale(inner : Expr, var_name : String) -> Expr? {
  match poly_coeffs_upto2(expr_simplify(inner), var_name) {
    Some(coeffs) =>
      if !expr_is_zero(coeffs[1]) || !expr_is_zero(coeffs[0]) {
        None
      } else {
        let quad = expr_simplify(coeffs[2])
        if expr_is_negative(quad) {
          Some(expr_sqrt_positive(expr_mul(@symcore.int(-1), quad)))
        } else {
          None
        }
      }
    _ => None
  }
}

///|
fn extract_division(expr : Expr) -> (Array[Expr], Expr?) {
  let simplified = expr_simplify(expr)
  match simplified {
    @symcore.Expr::Pow(base, exp) if expr_is_minus_one(exp) =>
      ([@symcore.int(1)], Some(base))
    @symcore.Expr::Mul(args) => {
      let numerator : Array[Expr] = []
      let denominator : Array[Expr] = []
      for item in args {
        match item {
          @symcore.Expr::Pow(base, exp) if expr_is_minus_one(exp) =>
            denominator.push(base)
          _ => numerator.push(item)
        }
      }
      if denominator.length() == 0 {
        (numerator, None)
      } else {
        let den = if denominator.length() == 1 {
          denominator[0]
        } else {
          expr_simplify(@symcore.mul(denominator))
        }
        (numerator, Some(den))
      }
    }
    _ => ([simplified], None)
  }
}
