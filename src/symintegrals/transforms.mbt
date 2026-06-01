///|
/// Public transform rule helpers.
///
/// Current Limits:
/// - This file exposes the currently public transform rule workers and metadata helpers.
/// - Most public functions here are low-level front doors used by `integrals.mbt`, not high-level user constructors.

///|
type LaplaceInfo = (Expr, Expr, Expr)

///|
type MellinInfo = (Expr, Expr, Expr, Expr)

///|
fn unary_application_arg(expr : Expr, name : String) -> Expr? {
  match @symcore.application_args(expr) {
    Some([arg]) if @symcore.application_has_name(expr, name, arity=1) =>
      Some(arg)
    _ => None
  }
}

///|
fn named_unary_application(expr : Expr) -> (String, Expr)? {
  match (@symcore.application_name(expr), @symcore.application_args(expr)) {
    (Some(name), Some([arg])) => Some((name, arg))
    _ => None
  }
}

///|
fn named_application(expr : Expr) -> (String, Array[Expr])? {
  match (@symcore.application_name(expr), @symcore.application_args(expr)) {
    (Some(name), Some(args)) => Some((name, args))
    _ => None
  }
}

///|
priv struct TransformHeadFlags {
  mut has_log : Bool
  mut has_exp : Bool
  mut has_ei : Bool
  mut has_atan : Bool
  mut has_laplace_transform : Bool
  mut has_gamma : Bool
  mut has_sin : Bool
  mut has_cos : Bool
  mut has_tan : Bool
  mut has_cot : Bool
  mut has_factorial : Bool
  mut has_irrational_shape : Bool
}

///|
fn transform_head_flags_new() -> TransformHeadFlags {
  TransformHeadFlags::{
    has_log: false,
    has_exp: false,
    has_ei: false,
    has_atan: false,
    has_laplace_transform: false,
    has_gamma: false,
    has_sin: false,
    has_cos: false,
    has_tan: false,
    has_cot: false,
    has_factorial: false,
    has_irrational_shape: false,
  }
}

///|
fn transform_head_flags_mark(flags : TransformHeadFlags, name : String) -> Unit {
  match name {
    "log" => flags.has_log = true
    "exp" => flags.has_exp = true
    "Ei" => flags.has_ei = true
    "atan" => flags.has_atan = true
    "LaplaceTransform" => flags.has_laplace_transform = true
    "gamma" => flags.has_gamma = true
    "sin" => flags.has_sin = true
    "cos" => flags.has_cos = true
    "tan" => flags.has_tan = true
    "cot" => flags.has_cot = true
    "factorial" => flags.has_factorial = true
    _ => ()
  }
}

///|
fn transform_head_flags_visit(
  expr : Expr,
  flags : TransformHeadFlags,
  s_name : String,
) -> Bool {
  match expr {
    @symcore.Expr::Apply(head, args) => {
      match @symcore.function_head_name(head) {
        Some(name) => transform_head_flags_mark(flags, name)
        _ => ()
      }
      let mut depends = transform_head_flags_visit(head, flags, s_name)
      for arg in args {
        depends = transform_head_flags_visit(arg, flags, s_name) || depends
      }
      match @symcore.function_head_name(head) {
        Some("sqrt") | Some("root") if depends =>
          flags.has_irrational_shape = true
        _ => ()
      }
      depends
    }
    @symcore.Expr::Function(name, args) => {
      transform_head_flags_mark(flags, name)
      let mut depends = false
      for arg in args {
        depends = transform_head_flags_visit(arg, flags, s_name) || depends
      }
      if (name == "sqrt" || name == "root") && depends {
        flags.has_irrational_shape = true
      }
      depends
    }
    @symcore.Expr::Add(args)
    | @symcore.Expr::Mul(args)
    | @symcore.Expr::Tuple(args) => {
      let mut depends = false
      for arg in args {
        depends = transform_head_flags_visit(arg, flags, s_name) || depends
      }
      depends
    }
    @symcore.Expr::Pow(base, exp) => {
      let base_depends = transform_head_flags_visit(base, flags, s_name)
      let exp_depends = transform_head_flags_visit(exp, flags, s_name)
      if base_depends && expr_is_int_value(exp) is None {
        flags.has_irrational_shape = true
      }
      base_depends || exp_depends
    }
    @symcore.Expr::Mod(base, exp) | @symcore.Expr::Relational(_, base, exp) => {
      let base_depends = transform_head_flags_visit(base, flags, s_name)
      let exp_depends = transform_head_flags_visit(exp, flags, s_name)
      base_depends || exp_depends
    }
    @symcore.Expr::Dict(items) => {
      let mut depends = false
      for item in items {
        let (key, value) = item
        depends = transform_head_flags_visit(key, flags, s_name) || depends
        depends = transform_head_flags_visit(value, flags, s_name) || depends
      }
      depends
    }
    @symcore.Expr::Derivative(inner, args) => {
      let mut depends = transform_head_flags_visit(inner, flags, s_name)
      for arg in args {
        depends = transform_head_flags_visit(arg, flags, s_name) || depends
      }
      depends
    }
    @symcore.Expr::Subs(inner, variable, value) =>
      transform_head_flags_visit(inner, flags, s_name) ||
      transform_head_flags_visit(variable, flags, s_name) ||
      transform_head_flags_visit(value, flags, s_name)
    @symcore.Expr::Lambda(vars, body) =>
      transform_head_flags_visit(vars, flags, s_name) ||
      transform_head_flags_visit(body, flags, s_name)
    @symcore.Expr::Symbol(name) => name == s_name
    _ => false
  }
}

///|
fn transform_head_flags(expr : Expr, s_name : String) -> TransformHeadFlags {
  let flags = transform_head_flags_new()
  ignore(transform_head_flags_visit(expr, flags, s_name))
  flags
}

///|
fn named_binary_application(expr : Expr) -> (String, Expr, Expr)? {
  match (@symcore.application_name(expr), @symcore.application_args(expr)) {
    (Some(name), Some([lhs, rhs])) => Some((name, lhs, rhs))
    _ => None
  }
}

///|
fn named_ternary_application(expr : Expr) -> (String, Expr, Expr, Expr)? {
  match (@symcore.application_name(expr), @symcore.application_args(expr)) {
    (Some(name), Some([x, y, z])) => Some((name, x, y, z))
    _ => None
  }
}

///|
fn pow_named_unary_application(expr : Expr) -> (String, Expr, Expr)? {
  match expr {
    Expr::Pow(base, exp) =>
      match named_unary_application(base) {
        Some((name, arg)) => Some((name, arg, exp))
        None => None
      }
    _ => None
  }
}

///|
/// Apply the forward Laplace rule table.
///
/// - Does: Evaluates a forward Laplace transform and keeps only the transformed value.
/// - Input: One source `Expr`, one time variable `t`, and one transform variable `s`.
/// - Returns: `Some(Expr)` for a computed transform or `None`.
/// - Limits: Convergence plane and condition metadata are discarded here.
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
/// Evaluate a forward Laplace transform with optional metadata.
///
/// - Does: Runs the forward Laplace rule engine and optionally returns the convergence plane and condition.
/// - Input: One source `Expr`, variables `t` and `s`, and an optional `noconds` flag.
/// - Returns: Either the transformed `Expr` or a tuple `(value, plane, condition)`.
/// - Limits: Returns an unevaluated `LaplaceTransform(...)` when no rule applies.
pub fn laplace_transform_result(
  expr : Expr,
  t : Expr,
  s : Expr,
  noconds? : Bool = false,
) -> Expr {
  match symbol_name(t) {
    Some(t_name) => {
      let info = match laplace_info_doit(expr, t_name, s) {
        Some(found) => Some(found)
        None => laplace_info_doit(expr_simplify(expr), t_name, s)
      }
      match info {
        Some((value, plane, cond)) =>
          if noconds {
            value
          } else {
            Expr::Tuple([value, plane, cond])
          }
        None => @symcore.raw_function("LaplaceTransform", [expr, t, s])
      }
    }
    None => @symcore.raw_function("LaplaceTransform", [expr, t, s])
  }
}

///|
/// Recursively collect polynomial structure before Laplace processing.
///
/// - Does: Rewrites nested arithmetic into a form that is easier for the Laplace rule engine to inspect.
/// - Input: One source `Expr` and one time variable `t`.
/// - Returns: One rewritten `Expr`.
/// - Limits: This helper is heuristic and only targets the current Laplace preprocessing path.
pub fn _laplace_deep_collect(expr : Expr, t : Expr) -> Expr {
  match symbol_name(t) {
    Some(t_name) => laplace_deep_collect(expr, t_name)
    None => expr
  }
}

///|
/// Rewrite transform heads through a correspondence map.
///
/// - Does: Replaces mapped function names inside transform-domain expressions.
/// - Input: One symbolic `Expr` and a map from source names to target names.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the transform head patterns recognized by this walker are rewritten.
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
/// - Does: Rewrites derivative terms using the provided initial-condition table.
/// - Input: One symbolic `Expr`, one time variable `t`, and a map from function names to derivative values.
/// - Returns: One rewritten `Expr`.
/// - Limits: Only the derivative patterns recognized by this helper are substituted.
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
  match match_initial_condition(expr, fdict) {
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
  fdict : Map[String, Array[Expr]],
) -> Expr? {
  for func_name, values in fdict {
    match initial_condition_order(expr, func_name) {
      Some(order) if order >= 0 && order < values.length() =>
        return Some(values[order])
      _ => ()
    }
  }
  None
}

///|
fn initial_condition_order(expr : Expr, func_name : String) -> Int? {
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
                if expr_is_zero(value) {
                  match symbol_name(sub_var) {
                    Some(source_name) =>
                      derivative_ic_order(inner, func_name, source_name)
                    None => None
                  }
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
            if expr_is_zero(value) {
              match symbol_name(sub_var) {
                Some(source_name) =>
                  derivative_ic_order(inner, func_name, source_name)
                None => None
              }
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
    Some((inner, deriv_args)) =>
      match
        (
          derivative_chain_order(inner, func_name, t_name),
          derivative_args_order(deriv_args, t_name),
        ) {
        (Some(base_order), Some(n)) if n >= 1 => Some(base_order + n)
        _ => None
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
  if @symcore.application_has_name(expr, func_name, arity=1) {
    let arg = @symcore.application_args(expr).unwrap()[0]
    if @symcore.compare_expr(arg, @symcore.Expr::Symbol(t_name)) == 0 {
      return Some(0)
    }
  }
  match @symcore.expr_form(expr) {
    _ =>
      match @symcore.derivative_parts(expr) {
        Some((inner, deriv_args)) =>
          match
            (
              derivative_chain_order(inner, func_name, t_name),
              derivative_args_order(deriv_args, t_name),
            ) {
            (Some(base_order), Some(n)) if n >= 1 => Some(base_order + n)
            _ => None
          }
        _ => None
      }
  }
}

///|
fn derivative_args_order(args : Array[Expr], t_name : String) -> Int? {
  let t_sym = @symcore.Expr::Symbol(t_name)
  let mut total = 0
  let mut idx = 0
  while idx < args.length() {
    match args[idx] {
      @symcore.Expr::Tuple([wrt, order]) =>
        if @symcore.compare_expr(wrt, t_sym) == 0 {
          match expr_is_int_value(order) {
            Some(n) if n >= 1 => {
              total += n
              idx += 1
            }
            _ => return None
          }
        } else {
          return None
        }
      wrt if @symcore.compare_expr(wrt, t_sym) == 0 =>
        if idx + 1 < args.length() {
          match expr_is_int_value(args[idx + 1]) {
            Some(n) if n >= 1 => {
              total += n
              idx += 2
            }
            _ => {
              total += 1
              idx += 1
            }
          }
        } else {
          total += 1
          idx += 1
        }
      _ => return None
    }
  }
  if total > 0 {
    Some(total)
  } else {
    None
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
        Some([@symcore.int(0), @symcore.int(1)])
      } else {
        Some([expr])
      }
    @symcore.Expr::Dummy(_, _)
    | @symcore.Expr::Wild(_, _, _)
    | @symcore.Expr::FunctionHead(_)
    | @symcore.Expr::UndefinedFunction(_) => Some([expr])
    @symcore.Expr::Apply(_, _) =>
      if expr_depends_on(expr, var_name) {
        None
      } else {
        Some([expr])
      }
    @symcore.Expr::Add(args) => {
      let acc : Array[Expr] = [@symcore.int(0)]
      for arg in args {
        match poly_coeffs_general(arg, var_name) {
          Some(coeffs) => poly_accum_add(acc, coeffs)
          None => return None
        }
      }
      Some(poly_trim_general(acc))
    }
    @symcore.Expr::Mul(args) => {
      let mut acc : Array[Expr] = [@symcore.int(1)]
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
    @symcore.Expr::Derivative(_, _) | @symcore.Expr::Subs(_, _, _) =>
      if expr_depends_on(expr, var_name) {
        None
      } else {
        Some([expr])
      }
    _ if @symcore.application_parts(expr) is Some(_) =>
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
    _ => if expr_depends_on(expr, var_name) { None } else { Some([expr]) }
  }
}

///|
fn poly_accum_add(acc : Array[Expr], coeffs : Array[Expr]) -> Unit {
  if coeffs.length() > acc.length() {
    let mut idx = acc.length()
    while idx < coeffs.length() {
      acc.push(@symcore.int(0))
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
    out.push(@symcore.int(0))
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
    return [@symcore.int(1)]
  }
  let mut result : Array[Expr] = [@symcore.int(1)]
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
    return @symcore.int(0)
  }
  let terms : Array[Expr] = []
  let poly_var = @symcore.Expr::Symbol(var_name)
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
      expr_mul(coeff, expr_pow(poly_var, @symcore.int(i)))
    }
    terms.push(term)
  }
  if terms.is_empty() {
    @symcore.int(0)
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
    (
      if values.length() == 0 {
        @symcore.int(0)
      } else if values.length() == 1 {
        values[0]
      } else {
        @symcore.add(values)
      },
      plane.unwrap_or(@symcore.int(0)),
      cond,
    ),
  )
}

///|
fn laplace_mul_term(
  factors : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  if factors.length() == 0 {
    return laplace_base_term(@symcore.int(1), t_name, s)
  }
  match laplace_delta_term(factors, t_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  match laplace_heaviside_shift_term(factors, t_name, s) {
    Some(info) => return Some(info)
    None => ()
  }
  let mut exp_coeff : Expr? = None
  let mut exp_const = @symcore.int(0)
  let rest : Array[Expr] = []
  for factor in factors {
    match unary_application_arg(factor, "exp") {
      Some(inner) =>
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
          let shifted_plane = if expr_eq(
              plane,
              @symcore.Expr::NumberSymbol(
                @symcore.NumberSymbolKind::NegativeInfinity,
              ),
            ) {
            expr_add(plane, laplace_plane_shift_expr(a))
          } else {
            expr_add(plane, laplace_plane_shift_expr(a))
          }
          Some((expr_mul(@symelem.exp(exp_const), value), shifted_plane, cond))
        }
        None => Some((value, plane, cond))
      }
    None =>
      match laplace_distribute_add_term(factors, t_name, s) {
        Some(info) => Some(info)
        None =>
          if expr_depends_on(factors_expr(factors), t_name) {
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
    return laplace_base_term(@symcore.int(1), t_name, shifted_s)
  }
  if factors.length() == 1 {
    match laplace_polynomial_term(factors[0], t_name, shifted_s) {
      Some(info) => return Some(info)
      None => return laplace_base_term(factors[0], t_name, shifted_s)
    }
  }
  match laplace_polynomial_term(factors_expr(factors), t_name, shifted_s) {
    Some(info) => return Some(info)
    None => ()
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
  match laplace_info_doit(rest[0], t_name, shifted_s) {
    Some((value, plane, cond)) =>
      if @symcore.application_has_name(value, "LaplaceTransform") ||
        @symcore.derivative_parts(value) != None {
        Some(
          (
            expr_mul(
              expr_pow(@symcore.int(-1), power),
              @symcore.raw_function("Derivative", [value, s, power]),
            ),
            plane,
            cond,
          ),
        )
      } else {
        None
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
  match laplace_info_doit(rest[0], t_name, shifted_s) {
    Some((value, plane, cond)) => {
      let out = match laplace_generic_power_derivative(value, s, total_power) {
        Some(generic_out) => generic_out
        None => {
          let mut derived = value
          for _ in 0..<total_power {
            derived = expr_mul(@symcore.int(-1), @symcalculus.diff(derived, s))
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
  if @symcore.application_has_name(value, "LaplaceTransform") {
    let deriv = if order == 1 {
      @symcore.raw_function("Derivative", [value, s])
    } else {
      @symcore.raw_function("Derivative", [value, s, @symcore.int(order)])
    }
    if order % 2 == 0 {
      Some(deriv)
    } else {
      Some(expr_mul(@symcore.int(-1), deriv))
    }
  } else {
    match value {
      _ if @symcore.derivative_parts(value) != None => {
        let deriv = if order == 1 {
          @symcore.raw_function("Derivative", [value, s])
        } else {
          @symcore.raw_function("Derivative", [value, s, @symcore.int(order)])
        }
        if order % 2 == 0 {
          Some(deriv)
        } else {
          Some(expr_mul(@symcore.int(-1), deriv))
        }
      }
      _ => None
    }
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
    match unary_application_arg(factor, "DiracDelta") {
      Some(arg) =>
        match laplace_delta_roots(arg, t_name) {
          Some(parsed) if delta_roots is None => delta_roots = Some(parsed)
          _ => return None
        }
      None => rest.push(factor)
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
            @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(root, s))),
          ),
          scale,
        )
        terms.push(term)
        cond = and_expr(cond, nonnegative_condition(root))
      }
      if terms.is_empty() {
        Some(
          (
            @symcore.int(0),
            @symcore.Expr::NumberSymbol(
              @symcore.NumberSymbolKind::NegativeInfinity,
            ),
            true_expr(),
          ),
        )
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
            @symcore.Expr::NumberSymbol(
              @symcore.NumberSymbolKind::NegativeInfinity,
            ),
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
      let scale = match expr_num_value(coeff) {
        Some(value) => abs_rational_expr(value)
        None =>
          if expr_is_one(coeff) || expr_is_minus_one(coeff) {
            @symcore.int(1)
          } else {
            coeff
          }
      }
      Some([(expr_div(expr_mul(@symcore.int(-1), offset), coeff), scale)])
    }
    _ =>
      match poly_coeffs_upto2(arg, t_name) {
        Some(coeffs) if !expr_is_zero(coeffs[2]) => {
          let disc = expr_simplify(
            expr_sub(
              expr_pow(coeffs[1], @symcore.int(2)),
              expr_mul(@symcore.int(4), expr_mul(coeffs[2], coeffs[0])),
            ),
          )
          let sqrt_disc = preferred_positive_sqrt(disc)
          let denom = expr_mul(@symcore.int(2), coeffs[2])
          let roots : Array[(Expr, Expr)] = []
          let deriv = @symcalculus.diff(arg, @symcore.Expr::Symbol(t_name))
          for
            root in [
              expr_div(
                expr_sub(expr_mul(@symcore.int(-1), coeffs[1]), sqrt_disc),
                denom,
              ),
              expr_div(
                expr_add(expr_mul(@symcore.int(-1), coeffs[1]), sqrt_disc),
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
fn laplace_polynomial_term(
  expr : Expr,
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  match poly_coeffs_general(expr, t_name) {
    Some(coeffs) => {
      let mut numerator = @symcore.int(0)
      for i in 0..<coeffs.length() {
        let weighted = if expr_is_zero(coeffs[i]) {
          @symcore.int(0)
        } else {
          @symcore.mul([coeffs[i], factorial_int_expr(i)])
        }
        numerator = @symcore.add([@symcore.mul([numerator, s]), weighted])
      }
      let value = if expr_is_zero(numerator) {
        @symcore.int(0)
      } else {
        @symcore.mul([
          numerator,
          @symcore.pow(s, @symcore.int(-coeffs.length())),
        ])
      }
      Some((value, @symcore.int(0), true_expr()))
    }
    None => None
  }
}

///|
fn factorial_int_expr(n : Int) -> Expr {
  if n <= 1 {
    return @symcore.int(1)
  }
  let mut out = @symcore.int(1)
  let mut i = 2
  while i <= n {
    out = @symcore.mul([out, @symcore.int(i)])
    i += 1
  }
  out
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
    match unary_application_arg(factor, "Heaviside") {
      Some(arg) =>
        match parse_heaviside_limit(arg, t_name) {
          Some((bound, is_le)) =>
            if window is None {
              window = Some((bound, is_le))
            } else {
              return None
            }
          None => return None
        }
      None => rest.push(factor)
    }
  }
  let rest_expr = expr_simplify(factors_expr(rest))
  match window {
    Some((bound, is_upper)) =>
      if is_upper {
        if expr_is_negative(bound) || expr_is_zero(bound) {
          Some((@symcore.int(0), @symcore.int(0), true_expr()))
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
  let shift_var = @symcore.Expr::Symbol(shift_name)
  let shifted = subst_symbol(rest_expr, t_name, expr_add(shift_var, bound))
  match laplace_info_doit(expr_simplify(shifted), shift_name, s) {
    Some((value, plane, cond)) => {
      let restored_value = subst_symbol(
        value,
        shift_name,
        @symcore.Expr::Symbol(t_name),
      )
      let restored_plane = subst_symbol(
        plane,
        shift_name,
        @symcore.Expr::Symbol(t_name),
      )
      let restored_cond = subst_symbol(
        cond,
        shift_name,
        @symcore.Expr::Symbol(t_name),
      )
      Some(
        (
          expr_simplify(
            expr_mul(
              @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(bound, s))),
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
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(_) =>
      Some((expr_div(expr, s), @symcore.int(0), true_expr()))
    @symcore.ExprForm::Symbol(name) =>
      if name == t_name {
        Some(
          (
            expr_div(@symcore.int(1), expr_pow(s, @symcore.int(2))),
            @symcore.int(0),
            true_expr(),
          ),
        )
      } else {
        None
      }
    _ if @symcore.application_has_name(expr, "exp", arity=1) =>
      laplace_gaussian_base_term(
        @symcore.application_args(expr).unwrap()[0],
        t_name,
        s,
      )
    _ if @symcore.application_has_name(expr, "log", arity=1) =>
      laplace_log_term(@symcore.application_args(expr).unwrap()[0], t_name, s)
    _ if @symcore.application_has_name(expr, "Piecewise") =>
      match
        laplace_piecewise_term(
          @symcore.application_args(expr).unwrap(),
          t_name,
          s,
        ) {
        Some(info) => Some(info)
        None => None
      }
    @symcore.ExprForm::Pow(base, exp) if unary_application_arg(base, "log")
      is Some(inner) =>
      match expr_is_int_value(exp) {
        Some(2) => laplace_log_squared_term(inner, t_name, s)
        _ => None
      }
    @symcore.ExprForm::Pow(base, exp) =>
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
                        factorial_expr(@symcore.int(power)),
                        expr_pow(s, @symcore.int(power + 1)),
                      ),
                      @symcore.int(0),
                      true_expr(),
                    ),
                  )
                } else {
                  None
                }
              None =>
                if name == t_name && expr_is_constant(exp, t_name) {
                  let gamma_arg = expr_add(exp, @symcore.int(1))
                  Some(
                    (
                      expr_div(
                        @symspec.gamma(gamma_arg),
                        expr_pow(s, gamma_arg),
                      ),
                      @symcore.int(0),
                      @symcore.function("Gt", [
                        @symelem.re(exp),
                        @symcore.int(-1),
                      ]),
                    ),
                  )
                } else {
                  None
                }
            }
          }
        }
      }
    _ if @symcore.application_has_name(expr, "sin", arity=1) =>
      match linear_coeffs(@symcore.application_args(expr).unwrap()[0], t_name) {
        Some(pair) => {
          let a = pair.0
          let b = pair.1
          if expr_is_zero(a) {
            None
          } else {
            match laplace_trig_term(a, b, s, true) {
              Some(v) => Some((v, @symcore.int(0), true_expr()))
              None => None
            }
          }
        }
        None => None
      }
    _ if unary_application_arg(expr, "Abs") is Some(inner) &&
      unary_application_arg(inner, "sin") is Some(arg) =>
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
                        expr_mul(
                          @symcore.Expr::NumberSymbol(
                            @symcore.NumberSymbolKind::Pi,
                          ),
                          s,
                        ),
                        expr_mul(@symcore.int(2), a),
                      ),
                    ),
                  ),
                  expr_add(
                    expr_pow(a, @symcore.int(2)),
                    expr_pow(s, @symcore.int(2)),
                  ),
                ),
                @symcore.int(0),
                true_expr(),
              ),
            )
          }
        None => None
      }
    _ if @symcore.application_has_name(expr, "cos", arity=1) =>
      match linear_coeffs(@symcore.application_args(expr).unwrap()[0], t_name) {
        Some(pair) => {
          let a = pair.0
          let b = pair.1
          if expr_is_zero(a) {
            None
          } else {
            match laplace_trig_term(a, b, s, false) {
              Some(v) => Some((v, @symcore.int(0), true_expr()))
              None => None
            }
          }
        }
        None => None
      }
    _ if @symcore.application_has_name(expr, "sinh", arity=1) =>
      match linear_coeffs(@symcore.application_args(expr).unwrap()[0], t_name) {
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
    _ if @symcore.application_has_name(expr, "cosh", arity=1) =>
      match linear_coeffs(@symcore.application_args(expr).unwrap()[0], t_name) {
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
    _ if @symcore.application_has_name(expr, "Heaviside", arity=1) =>
      laplace_numeric_heaviside_base_term(
        @symcore.application_args(expr).unwrap()[0],
        t_name,
        s,
      )
    _ if @symcore.application_has_name(expr, "SingularityFunction") =>
      laplace_singularity_base_term(expr, t_name, s)
    _ if @symcore.application_has_name(expr, "erf", arity=1) =>
      match linear_coeffs(@symcore.application_args(expr).unwrap()[0], t_name) {
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
                        expr_pow(s, @symcore.int(2)),
                        expr_mul(@symcore.int(4), expr_pow(a, @symcore.int(2))),
                      ),
                    ),
                    @symspec.erfc(expr_div(s, expr_mul(@symcore.int(2), a))),
                  ),
                  s,
                ),
                @symcore.int(0),
                true_expr(),
              ),
            )
          }
        None => None
      }
    _ if @symcore.application_has_name(expr, "besselj", arity=2) => {
      let args = @symcore.application_args(expr).unwrap()
      let order = args[0]
      let arg = args[1]
      match linear_coeffs(arg, t_name) {
        Some((a, b)) =>
          if !expr_is_zero(order) || expr_is_zero(a) || !expr_is_zero(b) {
            None
          } else {
            Some(
              (
                expr_div(
                  @symcore.int(1),
                  preferred_positive_sqrt(
                    expr_add(
                      expr_pow(a, @symcore.int(2)),
                      expr_pow(s, @symcore.int(2)),
                    ),
                  ),
                ),
                @symcore.int(0),
                true_expr(),
              ),
            )
          }
        None => None
      }
    }
    _ if @symcore.application_has_name(expr, "besseli", arity=2) => {
      let args = @symcore.application_args(expr).unwrap()
      let order = args[0]
      let arg = args[1]
      match linear_coeffs(arg, t_name) {
        Some((a, b)) =>
          if !expr_is_zero(order) || expr_is_zero(a) || !expr_is_zero(b) {
            None
          } else {
            Some(
              (
                expr_div(
                  @symcore.int(1),
                  preferred_positive_sqrt(
                    expr_sub(
                      expr_pow(s, @symcore.int(2)),
                      expr_pow(a, @symcore.int(2)),
                    ),
                  ),
                ),
                a,
                true_expr(),
              ),
            )
          }
        None => None
      }
    }
    _ if @symcore.application_has_name(expr, "bessely", arity=2) => {
      let args = @symcore.application_args(expr).unwrap()
      let order = args[0]
      let arg = args[1]
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
                    expr_pow(
                      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                      @symcore.int(-1),
                    ),
                  ),
                  expr_div(
                    @symelem.asinh(expr_div(s, a)),
                    preferred_positive_sqrt(
                      expr_add(
                        expr_pow(a, @symcore.int(2)),
                        expr_pow(s, @symcore.int(2)),
                      ),
                    ),
                  ),
                ),
                @symcore.int(0),
                true_expr(),
              ),
            )
          }
        None => None
      }
    }
    _ if @symcore.application_has_name(expr, "besselk", arity=2) => {
      let args = @symcore.application_args(expr).unwrap()
      let order = args[0]
      let arg = args[1]
      match linear_coeffs(arg, t_name) {
        Some((a, b)) =>
          if !expr_is_zero(order) || expr_is_zero(a) || !expr_is_zero(b) {
            None
          } else {
            let radicand = expr_sub(
              expr_pow(s, @symcore.int(2)),
              expr_pow(a, @symcore.int(2)),
            )
            let root = preferred_positive_sqrt(radicand)
            Some(
              (
                expr_div(@symelem.log(expr_div(expr_add(s, root), a)), root),
                expr_mul(@symcore.int(-1), a),
                true_expr(),
              ),
            )
          }
        None => None
      }
    }
    _ if @symcore.application_has_name(expr, "fresnels", arity=1) =>
      match @symcore.application_args(expr).unwrap() {
        [@symcore.Expr::Symbol(name)] if name == t_name => {
          let phase = expr_div(
            expr_pow(s, @symcore.int(2)),
            expr_mul(
              @symcore.int(2),
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
            ),
          )
          let arg = expr_div(
            s,
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
          )
          Some(
            (
              expr_div(
                expr_add(
                  expr_mul(
                    @symcore.int(-1),
                    expr_mul(@symelem.sin(phase), @symspec.fresnels(arg)),
                  ),
                  expr_add(
                    expr_mul(
                      expr_div(expr_sqrt_two(), @symcore.int(2)),
                      @symelem.sin(
                        expr_add(
                          phase,
                          expr_div(
                            @symcore.Expr::NumberSymbol(
                              @symcore.NumberSymbolKind::Pi,
                            ),
                            @symcore.int(4),
                          ),
                        ),
                      ),
                    ),
                    expr_mul(
                      @symcore.int(-1),
                      expr_mul(@symelem.cos(phase), @symspec.fresnelc(arg)),
                    ),
                  ),
                ),
                s,
              ),
              @symcore.int(0),
              true_expr(),
            ),
          )
        }
        _ => None
      }
    _ if @symcore.application_has_name(expr, "fresnelc", arity=1) =>
      match @symcore.application_args(expr).unwrap() {
        [@symcore.Expr::Symbol(name)] if name == t_name => {
          let phase = expr_div(
            expr_pow(s, @symcore.int(2)),
            expr_mul(
              @symcore.int(2),
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
            ),
          )
          let arg = expr_div(
            s,
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
          )
          Some(
            (
              expr_div(
                expr_add(
                  expr_mul(@symelem.sin(phase), @symspec.fresnelc(arg)),
                  expr_add(
                    expr_mul(
                      expr_mul(@symcore.int(-1), @symelem.cos(phase)),
                      @symspec.fresnels(arg),
                    ),
                    expr_mul(
                      expr_div(expr_sqrt_two(), @symcore.int(2)),
                      @symelem.cos(
                        expr_add(
                          phase,
                          expr_div(
                            @symcore.Expr::NumberSymbol(
                              @symcore.NumberSymbolKind::Pi,
                            ),
                            @symcore.int(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                s,
              ),
              @symcore.int(0),
              true_expr(),
            ),
          )
        }
        _ => None
      }
    _ if @symcore.application_has_name(expr, "Ci", arity=1) =>
      match @symcore.application_args(expr).unwrap() {
        [@symcore.Expr::Symbol(name)] if name == t_name =>
          Some(
            (
              expr_mul(
                expr_rat(-1, 2),
                expr_div(
                  @symelem.log(
                    expr_add(@symcore.int(1), expr_pow(s, @symcore.int(2))),
                  ),
                  s,
                ),
              ),
              @symcore.int(0),
              true_expr(),
            ),
          )
        _ => None
      }
    _ if @symcore.application_has_name(expr, "Si", arity=1) =>
      match @symcore.application_args(expr).unwrap() {
        [@symcore.Expr::Symbol(name)] if name == t_name =>
          Some(
            (
              expr_div(@symelem.atan(expr_pow(s, @symcore.int(-1))), s),
              @symcore.int(0),
              true_expr(),
            ),
          )
        _ => None
      }
    _ if @symcore.application_has_name(expr, "Shi", arity=1) =>
      match @symcore.application_args(expr).unwrap() {
        [@symcore.Expr::Symbol(name)] if name == t_name =>
          Some(
            (
              expr_div(@symelem.acoth(s), s),
              @symcore.Expr::NumberSymbol(
                @symcore.NumberSymbolKind::NegativeInfinity,
              ),
              @symcore.function("Gt", [
                expr_pow(s, @symcore.int(2)),
                @symcore.int(1),
              ]),
            ),
          )
        _ => None
      }
    _ if @symcore.application_has_name(expr, "Chi", arity=1) =>
      match @symcore.application_args(expr).unwrap() {
        [@symcore.Expr::Symbol(name)] if name == t_name =>
          Some(
            (
              expr_div(
                expr_sub(
                  @symelem.log(expr_pow(s, @symcore.int(-2))),
                  @symelem.log(
                    expr_sub(
                      @symcore.int(1),
                      expr_div(@symcore.int(1), expr_pow(s, @symcore.int(2))),
                    ),
                  ),
                ),
                expr_mul(@symcore.int(2), s),
              ),
              @symcore.Expr::NumberSymbol(
                @symcore.NumberSymbolKind::NegativeInfinity,
              ),
              @symcore.function("Gt", [
                expr_pow(s, @symcore.int(2)),
                @symcore.int(1),
              ]),
            ),
          )
        _ => None
      }
    _ if @symcore.application_has_name(expr, "E1", arity=1) =>
      match @symcore.application_args(expr).unwrap() {
        [@symcore.Expr::Symbol(name)] if name == t_name =>
          Some(
            (
              expr_div(@symelem.log(expr_add(s, @symcore.int(1))), s),
              @symcore.int(0),
              true_expr(),
            ),
          )
        _ => None
      }
    _ if @symcore.application_has_name(expr, "expint", arity=2) =>
      match @symcore.application_args(expr).unwrap() {
        [n, @symcore.Expr::Symbol(name)] if name == t_name =>
          match expr_is_int_value(n) {
            Some(1) =>
              Some(
                (
                  expr_div(@symelem.log(expr_add(s, @symcore.int(1))), s),
                  @symcore.int(0),
                  true_expr(),
                ),
              )
            Some(2) =>
              Some(
                (
                  expr_div(
                    expr_sub(s, @symelem.log(expr_add(s, @symcore.int(1)))),
                    expr_pow(s, @symcore.int(2)),
                  ),
                  @symcore.int(0),
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
                          expr_mul(
                            @symcore.Expr::NumberSymbol(
                              @symcore.NumberSymbolKind::ImaginaryUnit,
                            ),
                            @symcore.Expr::NumberSymbol(
                              @symcore.NumberSymbolKind::Pi,
                            ),
                          ),
                        ),
                      ),
                      @symcore.int(1),
                      n,
                    ),
                    @symcore.int(0),
                    @symcore.function("Gt", [@symelem.re(n), @symcore.int(0)]),
                  ),
                )
              } else {
                None
              }
          }
        _ => None
      }
    _ =>
      match laplace_subs_derivative_term(expr, t_name, s) {
        Some(info) => Some(info)
        None =>
          match @symcore.derivative_parts(expr) {
            Some((inner, deriv_args)) => {
              let args : Array[Expr] = [inner]
              for arg in deriv_args {
                args.push(arg)
              }
              laplace_derivative_term(args, t_name, s)
            }
            None =>
              match named_unary_application(expr) {
                Some((name, arg)) =>
                  match linear_coeffs(arg, t_name) {
                    Some((coeff, offset)) =>
                      if expr_is_positive(coeff) && expr_is_zero(offset) {
                        Some(
                          (
                            expr_simplify(
                              expr_div(
                                @symcore.raw_function("LaplaceTransform", [
                                  @symcore.raw_function(name, [
                                    @symcore.Expr::Symbol(t_name),
                                  ]),
                                  @symcore.Expr::Symbol(t_name),
                                  expr_div(s, coeff),
                                ]),
                                coeff,
                              ),
                            ),
                            @symcore.Expr::NumberSymbol(
                              @symcore.NumberSymbolKind::NegativeInfinity,
                            ),
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
                None =>
                  if expr_depends_on(expr, t_name) {
                    Some(generic_laplace_object(expr, t_name, s))
                  } else {
                    None
                  }
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
  match @symcore.application_args(expr) {
    Some([@symcore.Expr::Symbol(name), offset, order]) =>
      if @symcore.application_has_name(expr, "SingularityFunction", arity=3) &&
        name == t_name &&
        !expr_depends_on(offset, t_name) {
        match expr_is_int_value(order) {
          Some(-1) =>
            Some(
              (
                expr_simplify(
                  @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(offset, s))),
                ),
                @symcore.int(0),
                true_expr(),
              ),
            )
          Some(k) if k >= 0 => {
            let shifted = @symelem.exp(
              expr_mul(@symcore.int(-1), expr_mul(offset, s)),
            )
            Some(
              (
                expr_simplify(
                  expr_mul(
                    factorial_expr(@symcore.int(k)),
                    expr_div(shifted, expr_pow(s, @symcore.int(k + 1))),
                  ),
                ),
                @symcore.int(0),
                true_expr(),
              ),
            )
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
fn laplace_gaussian_mul_term(
  factors : Array[Expr],
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  let mut scale : Expr? = None
  let mut total_power = 0
  for factor in factors {
    match unary_application_arg(factor, "exp") {
      Some(inner) =>
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
          @symcore.int(0),
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
          @symcore.int(0),
          gaussian_laplace_condition(scale),
        ),
      )
    None => None
  }
}

///|
fn laplace_gaussian_value(scale : Expr, s : Expr, power : Int) -> Expr {
  let sqrt_scale = expr_sqrt_positive(scale)
  let erfc_arg = expr_div(s, expr_mul(@symcore.int(2), sqrt_scale))
  let erfc_term = @symspec.erfc(erfc_arg)
  let exp_term = @symelem.exp(
    expr_div(expr_pow(s, @symcore.int(2)), expr_mul(@symcore.int(4), scale)),
  )
  let common = expr_mul(sqrt_pi(), expr_mul(exp_term, erfc_term))
  match power {
    0 => expr_div(common, expr_mul(@symcore.int(2), sqrt_scale))
    1 =>
      expr_sub(
        expr_div(@symcore.int(1), expr_mul(@symcore.int(2), scale)),
        expr_div(
          expr_mul(s, erfc_term),
          expr_mul(
            @symcore.int(4),
            expr_mul(sqrt_pi(), expr_pow(scale, expr_rat(3, 2))),
          ),
        ),
      )
    2 =>
      expr_add(
        expr_mul(
          @symcore.int(-1),
          expr_div(
            s,
            expr_mul(@symcore.int(4), expr_pow(scale, @symcore.int(2))),
          ),
        ),
        expr_add(
          expr_div(
            common,
            expr_mul(@symcore.int(4), expr_pow(scale, expr_rat(3, 2))),
          ),
          expr_div(
            expr_mul(common, expr_pow(s, @symcore.int(2))),
            expr_mul(@symcore.int(8), expr_pow(scale, expr_rat(5, 2))),
          ),
        ),
      )
    _ => @symcore.int(0)
  }
}

///|
fn gaussian_laplace_condition(scale : Expr) -> Expr {
  if expr_is_positive(scale) {
    true_expr()
  } else {
    @symcore.function("Le", [
      @symelem.abs(@symelem.arg(scale)),
      expr_div(
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        @symcore.int(2),
      ),
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
  match named_unary_application(base) {
    Some((name, arg)) if name == "sin" && power == 2 =>
      laplace_info_doit(
        expr_mul(
          expr_rat(1, 2),
          expr_sub(
            @symcore.int(1),
            @symelem.cos(expr_mul(@symcore.int(2), arg)),
          ),
        ),
        t_name,
        s,
      )
    Some((name, arg)) if name == "sin" && power == 4 =>
      laplace_info_doit(
        expr_mul(
          expr_rat(1, 8),
          expr_add(
            @symcore.int(3),
            expr_add(
              expr_mul(
                @symcore.int(-4),
                @symelem.cos(expr_mul(@symcore.int(2), arg)),
              ),
              @symelem.cos(expr_mul(@symcore.int(4), arg)),
            ),
          ),
        ),
        t_name,
        s,
      )
    Some((name, arg)) if name == "cos" && power == 2 =>
      laplace_info_doit(
        expr_mul(
          expr_rat(1, 2),
          expr_add(
            @symcore.int(1),
            @symelem.cos(expr_mul(@symcore.int(2), arg)),
          ),
        ),
        t_name,
        s,
      )
    Some((name, arg)) if name == "sinh" && power == 2 =>
      laplace_info_doit(
        expr_mul(
          expr_rat(1, 2),
          expr_sub(
            @symelem.cosh(expr_mul(@symcore.int(2), arg)),
            @symcore.int(1),
          ),
        ),
        t_name,
        s,
      )
    Some((name, arg)) if name == "cosh" && power == 2 =>
      laplace_info_doit(
        expr_mul(
          expr_rat(1, 2),
          expr_add(
            @symelem.cosh(expr_mul(@symcore.int(2), arg)),
            @symcore.int(1),
          ),
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
  match
    (
      pow_named_unary_application(factors[0]),
      named_unary_application(factors[1]),
      named_unary_application(factors[0]),
      pow_named_unary_application(factors[1]),
    ) {
    (Some(("sin", arg, exp)), Some(("cosh", other_arg)), _, _)
    | (_, _, Some(("cosh", other_arg)), Some(("sin", arg, exp))) =>
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
                expr_div(expr_mul(@symcore.int(3), a), @symcore.int(8)),
                expr_sub(
                  expr_add(
                    expr_pow(
                      expr_add(
                        expr_pow(expr_add(s, b), @symcore.int(2)),
                        expr_pow(a, @symcore.int(2)),
                      ),
                      @symcore.int(-1),
                    ),
                    expr_pow(
                      expr_add(
                        expr_pow(expr_sub(s, b), @symcore.int(2)),
                        expr_pow(a, @symcore.int(2)),
                      ),
                      @symcore.int(-1),
                    ),
                  ),
                  expr_add(
                    expr_pow(
                      expr_add(
                        expr_pow(expr_add(s, b), @symcore.int(2)),
                        expr_mul(@symcore.int(9), expr_pow(a, @symcore.int(2))),
                      ),
                      @symcore.int(-1),
                    ),
                    expr_pow(
                      expr_add(
                        expr_pow(expr_sub(s, b), @symcore.int(2)),
                        expr_mul(@symcore.int(9), expr_pow(a, @symcore.int(2))),
                      ),
                      @symcore.int(-1),
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
  let rewrite = match
    (named_unary_application(factors[0]), named_unary_application(factors[1])) {
    (Some(("sin", u)), Some(("sin", v))) =>
      Some(
        expr_mul(
          expr_rat(1, 2),
          expr_sub(
            @symelem.cos(expr_simplify(expr_sub(u, v))),
            @symelem.cos(expr_simplify(expr_add(u, v))),
          ),
        ),
      )
    (Some(("cos", u)), Some(("cos", v))) =>
      Some(
        expr_mul(
          expr_rat(1, 2),
          expr_add(
            @symelem.cos(expr_simplify(expr_sub(u, v))),
            @symelem.cos(expr_simplify(expr_add(u, v))),
          ),
        ),
      )
    (Some(("cos", u)), Some(("sin", v)))
    | (Some(("sin", v)), Some(("cos", u))) =>
      Some(
        expr_mul(
          expr_rat(1, 2),
          expr_add(
            @symelem.sin(expr_simplify(expr_add(u, v))),
            @symelem.sin(expr_simplify(expr_sub(v, u))),
          ),
        ),
      )
    (Some(("sinh", u)), Some(("cosh", v)))
    | (Some(("cosh", v)), Some(("sinh", u))) =>
      if expr_same_simplified(u, v) {
        Some(
          expr_mul(
            expr_rat(1, 2),
            @symelem.sinh(expr_simplify(expr_mul(@symcore.int(2), u))),
          ),
        )
      } else {
        Some(
          expr_mul(
            expr_rat(1, 2),
            expr_add(
              @symelem.sinh(expr_simplify(expr_add(u, v))),
              @symelem.sinh(expr_simplify(expr_sub(u, v))),
            ),
          ),
        )
      }
    (Some(("sin", u)), Some(("cosh", v)))
    | (Some(("cosh", v)), Some(("sin", u))) =>
      match (linear_coeffs(u, t_name), linear_coeffs(v, t_name)) {
        (Some((a, bu)), Some((b, bv))) if expr_is_zero(bu) && expr_is_zero(bv) =>
          Some(
            expr_mul(
              expr_rat(1, 2),
              expr_add(
                expr_div(
                  a,
                  expr_add(
                    expr_pow(expr_sub(s, b), @symcore.int(2)),
                    expr_pow(a, @symcore.int(2)),
                  ),
                ),
                expr_div(
                  a,
                  expr_add(
                    expr_pow(expr_add(s, b), @symcore.int(2)),
                    expr_pow(a, @symcore.int(2)),
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
fn laplace_subs_derivative_term(
  expr : Expr,
  t_name : String,
  s : Expr,
) -> LaplaceInfo? {
  match @symcore.subs_parts(expr) {
    Some((inner, sub_var, value)) => {
      if @symcore.compare_expr(value, @symcore.Expr::Symbol(t_name)) != 0 {
        return None
      }
      match (symbol_name(sub_var), @symcore.derivative_parts(inner)) {
        (Some(source_name), Some((base, deriv_args))) =>
          match derivative_args_order(deriv_args, source_name) {
            Some(order) if order > 0 => {
              let base_at_t = subst_symbol(
                base,
                source_name,
                @symcore.Expr::Symbol(t_name),
              )
              laplace_derivative_term(
                [base_at_t, @symcore.Expr::Symbol(t_name), @symcore.int(order)],
                t_name,
                s,
              )
            }
            _ => None
          }
        _ => None
      }
    }
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
          expr_div(expr_mul(@symcore.int(-1), offset), coeff),
        )
        let value = if expr_is_positive(coeff) {
          if expr_is_negative(bound) || expr_is_zero(bound) {
            expr_div(@symcore.int(1), s)
          } else {
            expr_div(
              @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(bound, s))),
              s,
            )
          }
        } else if expr_is_negative(coeff) {
          if expr_is_negative(bound) || expr_is_zero(bound) {
            @symcore.int(0)
          } else {
            expr_sub(
              expr_div(@symcore.int(1), s),
              expr_div(
                @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(bound, s))),
                s,
              ),
            )
          }
        } else {
          return None
        }
        Some((expr_simplify(value), @symcore.int(0), true_expr()))
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
    @symcore.raw_function("LaplaceTransform", [
      expr,
      @symcore.Expr::Symbol(t_name),
      s,
    ]),
    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NegativeInfinity),
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
  let t = @symcore.Expr::Symbol(t_name)
  let mut default = @symcore.int(0)
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
    expr_mul(default, heaviside_window(t, @symcore.int(0), None)),
  )
  if !expr_is_zero(base) {
    terms.push(base)
  }

  let mut current_start = @symcore.int(0)
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
    Some(@symcore.int(0))
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
  match named_application(cond) {
    Some(("And", items)) => {
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
  match pow_named_unary_application(trig_factor) {
    Some(("sin", arg, exp)) =>
      match expr_is_int_value(exp) {
        Some(2) =>
          match linear_coeffs(arg, t_name) {
            Some((a, b)) if expr_is_constant(a, t_name) &&
              expr_is_constant(b, t_name) => {
              let ia2 = expr_mul(
                expr_mul(
                  @symcore.int(2),
                  @symcore.Expr::NumberSymbol(
                    @symcore.NumberSymbolKind::ImaginaryUnit,
                  ),
                ),
                a,
              )
              let value = expr_sub(
                expr_mul(
                  expr_rat(1, 2),
                  @symcore.raw_function("LaplaceTransform", [
                    other,
                    @symcore.Expr::Symbol(t_name),
                    s,
                  ]),
                ),
                expr_add(
                  expr_mul(
                    expr_rat(1, 4),
                    expr_mul(
                      @symelem.exp(
                        expr_mul(
                          expr_mul(
                            @symcore.int(2),
                            @symcore.Expr::NumberSymbol(
                              @symcore.NumberSymbolKind::ImaginaryUnit,
                            ),
                          ),
                          b,
                        ),
                      ),
                      @symcore.raw_function("LaplaceTransform", [
                        other,
                        @symcore.Expr::Symbol(t_name),
                        expr_sub(s, ia2),
                      ]),
                    ),
                  ),
                  expr_mul(
                    expr_rat(1, 4),
                    expr_mul(
                      @symelem.exp(
                        expr_mul(
                          expr_mul(
                            @symcore.int(-2),
                            @symcore.Expr::NumberSymbol(
                              @symcore.NumberSymbolKind::ImaginaryUnit,
                            ),
                          ),
                          b,
                        ),
                      ),
                      @symcore.raw_function("LaplaceTransform", [
                        other,
                        @symcore.Expr::Symbol(t_name),
                        expr_add(s, ia2),
                      ]),
                    ),
                  ),
                ),
              )
              Some(
                (
                  expr_simplify(value),
                  @symcore.Expr::NumberSymbol(
                    @symcore.NumberSymbolKind::NegativeInfinity,
                  ),
                  true_expr(),
                ),
              )
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
      @symcore.Expr::Symbol(t_name),
      shifted_s,
    ])
  }
  match named_unary_application(trig_factor) {
    Some(("sinh", arg)) =>
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
                  expr_mul(@symcore.int(-1), @symelem.re(a)),
                  @symcore.Expr::NumberSymbol(
                    @symcore.NumberSymbolKind::NegativeInfinity,
                  ),
                ),
                expr_add(
                  @symelem.re(a),
                  @symcore.Expr::NumberSymbol(
                    @symcore.NumberSymbolKind::NegativeInfinity,
                  ),
                ),
              ),
              true_expr(),
            ),
          )
        _ => None
      }
    Some(("cosh", arg)) =>
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
                  expr_mul(@symcore.int(-1), @symelem.re(a)),
                  @symcore.Expr::NumberSymbol(
                    @symcore.NumberSymbolKind::NegativeInfinity,
                  ),
                ),
                expr_add(
                  @symelem.re(a),
                  @symcore.Expr::NumberSymbol(
                    @symcore.NumberSymbolKind::NegativeInfinity,
                  ),
                ),
              ),
              true_expr(),
            ),
          )
        _ => None
      }
    Some(("sin", arg)) =>
      match linear_coeffs(arg, t_name) {
        Some((a, b)) if expr_is_zero(b) => {
          let ia = expr_mul(
            @symcore.Expr::NumberSymbol(
              @symcore.NumberSymbolKind::ImaginaryUnit,
            ),
            a,
          )
          Some(
            (
              expr_mul(
                expr_div(
                  @symcore.Expr::NumberSymbol(
                    @symcore.NumberSymbolKind::ImaginaryUnit,
                  ),
                  @symcore.int(2),
                ),
                expr_sub(transform(expr_add(s, ia)), transform(expr_sub(s, ia))),
              ),
              max_expr(
                expr_add(
                  expr_mul(@symcore.int(-1), @symelem.im(a)),
                  @symcore.Expr::NumberSymbol(
                    @symcore.NumberSymbolKind::NegativeInfinity,
                  ),
                ),
                expr_add(
                  @symelem.im(a),
                  @symcore.Expr::NumberSymbol(
                    @symcore.NumberSymbolKind::NegativeInfinity,
                  ),
                ),
              ),
              true_expr(),
            ),
          )
        }
        _ => None
      }
    Some(("cos", arg)) =>
      match linear_coeffs(arg, t_name) {
        Some((a, b)) if expr_is_zero(b) => {
          let ia = expr_mul(
            @symcore.Expr::NumberSymbol(
              @symcore.NumberSymbolKind::ImaginaryUnit,
            ),
            a,
          )
          Some(
            (
              expr_mul(
                expr_rat(1, 2),
                expr_add(transform(expr_add(s, ia)), transform(expr_sub(s, ia))),
              ),
              max_expr(
                expr_add(
                  expr_mul(@symcore.int(-1), @symelem.im(a)),
                  @symcore.Expr::NumberSymbol(
                    @symcore.NumberSymbolKind::NegativeInfinity,
                  ),
                ),
                expr_add(
                  @symelem.im(a),
                  @symcore.Expr::NumberSymbol(
                    @symcore.NumberSymbolKind::NegativeInfinity,
                  ),
                ),
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
                expr_add(
                  @symelem.log(s),
                  @symcore.Expr::NumberSymbol(
                    @symcore.NumberSymbolKind::EulerGamma,
                  ),
                ),
              ),
              s,
            ),
            @symcore.int(0),
            true_expr(),
          ),
        )
      } else if expr_is_one(offset) {
        let shift = expr_div(s, coeff)
        Some(
          (
            expr_mul(
              @symcore.int(-1),
              expr_div(
                expr_mul(
                  @symelem.exp(shift),
                  @symspec.ei(@symcore.int(-1) * shift),
                ),
                s,
              ),
            ),
            @symcore.int(0),
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
                  @symspec.ei(@symcore.int(-1) * shift),
                ),
              ),
              expr_pow(s, @symcore.int(2)),
            ),
            @symcore.int(0),
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
                expr_add(
                  @symelem.log(s),
                  @symcore.Expr::NumberSymbol(
                    @symcore.NumberSymbolKind::EulerGamma,
                  ),
                ),
                @symcore.int(2),
              ),
              expr_mul(
                expr_pow(
                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                  @symcore.int(2),
                ),
                expr_rat(1, 6),
              ),
            ),
            s,
          ),
          @symcore.int(0),
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
    Some(factor) =>
      match unary_application_arg(factor, "sin") {
        Some(arg) =>
          match linear_coeffs(arg, t_name) {
            Some((a, b)) if !expr_is_zero(a) && expr_is_zero(b) =>
              if power == 1 {
                Some(
                  (@symelem.atan(expr_div(a, s)), @symcore.int(0), true_expr()),
                )
              } else {
                None
              }
            _ => None
          }
        None =>
          match pow_named_unary_application(factor) {
            Some(("sin", arg, exp)) =>
              match (expr_is_int_value(exp), linear_coeffs(arg, t_name)) {
                (Some(2), Some((a, b))) if !expr_is_zero(a) && expr_is_zero(b) => {
                  let log_term = expr_mul(
                    expr_rat(1, 4),
                    @symelem.log(
                      expr_add(
                        @symcore.int(1),
                        expr_div(
                          expr_mul(
                            @symcore.int(4),
                            expr_pow(a, @symcore.int(2)),
                          ),
                          expr_pow(s, @symcore.int(2)),
                        ),
                      ),
                    ),
                  )
                  if power == 1 {
                    Some((log_term, @symcore.int(0), true_expr()))
                  } else if power == 2 {
                    Some(
                      (
                        expr_sub(
                          expr_mul(
                            a,
                            @symelem.atan(
                              expr_div(expr_mul(@symcore.int(2), a), s),
                            ),
                          ),
                          expr_mul(s, log_term),
                        ),
                        @symcore.int(0),
                        true_expr(),
                      ),
                    )
                  } else {
                    None
                  }
                }
                _ => None
              }
            _ =>
              match unary_application_arg(factor, "sinh") {
                Some(arg) =>
                  match linear_coeffs(arg, t_name) {
                    Some((a, b)) if !expr_is_zero(a) && expr_is_zero(b) =>
                      if power == 1 {
                        Some(
                          (
                            expr_mul(
                              expr_rat(1, 2),
                              @symelem.log(
                                expr_div(expr_add(a, s), expr_sub(s, a)),
                              ),
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
                None => None
              }
          }
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
  let t_sym = @symcore.Expr::Symbol(t_name)
  let (base_value, plane, cond) = match
    laplace_info_doit(expr_simplify(base), t_name, s) {
    Some(info) => info
    None =>
      (
        @symcore.raw_function("LaplaceTransform", [base, t_sym, s]),
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NegativeInfinity),
        true_expr(),
      )
  }
  let leading = expr_mul(expr_pow(s, @symcore.int(order)), base_value)
  let init_terms : Array[Expr] = []
  for idx in 0..<order {
    let init = laplace_initial_value(base, t_sym, t_name, idx)
    let s_pow = order - idx - 1
    init_terms.push(
      if s_pow == 0 {
        init
      } else {
        expr_mul(expr_pow(s, @symcore.int(s_pow)), init)
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
    expr_simplify(subst_symbol(base, t_name, @symcore.int(0)))
  } else {
    match @symcore.undefined_application_parts(base) {
      Some((_, [arg])) if @symcore.compare_expr(arg, t_sym) == 0 =>
        return @symcore.raw_function("Subs", [
          @symcore.raw_derivative(base, [t_sym, @symcore.int(order)]),
          t_sym,
          @symcore.int(0),
        ])
      _ => ()
    }
    let mut deriv = base
    for _ in 0..<order {
      deriv = @symcalculus.diff(deriv, t_sym)
    }
    if @symcore.derivative_parts(deriv) is Some(_) ||
      expr_has_function_name(deriv, "Derivative") {
      @symcore.raw_function("Subs", [deriv, t_sym, @symcore.int(0)])
    } else {
      expr_simplify(subst_symbol(deriv, t_name, @symcore.int(0)))
    }
  }
}

///|
fn laplace_trig_term(a : Expr, b : Expr, s : Expr, is_sin : Bool) -> Expr? {
  let a2 = expr_pow(a, @symcore.int(2))
  let den = expr_add(a2, expr_pow(s, @symcore.int(2)))
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
  let a2 = expr_pow(a, @symcore.int(2))
  let den = expr_sub(expr_pow(s, @symcore.int(2)), a2)
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
/// Apply the inverse Laplace rule table.
///
/// - Does: Evaluates an inverse Laplace transform and returns only the recovered time-domain value.
/// - Input: One source `Expr`, one transform variable `s`, and one time variable `t`.
/// - Returns: `Some(Expr)` for a computed transform or `None`.
/// - Limits: Delay and `Heaviside` semantics are handled here; unsupported cases return `None`.
pub fn do_inverse_laplace_doit(expr : Expr, s : Expr, t : Expr) -> Expr? {
  match symbol_name(s) {
    Some(s_name) => inverse_laplace_doit(expr, s_name, t)
    None => None
  }
}

///|
fn inverse_laplace_doit(expr : Expr, s_name : String, t : Expr) -> Expr? {
  inverse_laplace_doit_control(expr, s_name, t, true)
}

///|
fn inverse_laplace_doit_control(
  expr : Expr,
  s_name : String,
  t : Expr,
  dorational : Bool,
) -> Expr? {
  match expr {
    @symcore.Expr::Add(terms) =>
      inverse_laplace_add_termwise(terms, s_name, t, dorational)
    _ => {
      match inverse_laplace_exp_normalize_term(expr, s_name) {
        Some(normalized) =>
          return inverse_laplace_doit_control(normalized, s_name, t, dorational)
        None => ()
      }
      match
        inverse_laplace_independent_factor_term(expr, s_name, t, dorational) {
        Some(v) => return Some(v)
        None => ()
      }
      if dorational {
        match inverse_laplace_rational_term(expr, s_name, t) {
          Some(v) => return Some(v)
          None => ()
        }
      }
      match inverse_laplace_special_term(expr, s_name, t) {
        Some(v) => Some(v)
        None =>
          match inverse_laplace_integration_term(expr, s_name, t) {
            Some(v) => Some(v)
            None =>
              inverse_laplace_independent_object_fallback_term(expr, s_name, t)
          }
      }
    }
  }
}

///|
fn inverse_laplace_independent_factor_term(
  expr : Expr,
  s_name : String,
  t : Expr,
  dorational : Bool,
) -> Expr? {
  // Source map: SymPy's _inverse_laplace_transform applies
  // term.as_independent(s, as_Add=False) before the rule cascade. We first
  // try that split only when the dependent core can actually be evaluated, so
  // full-expression rules that still need the independent factor get a chance.
  let (coeff, factors) = split_mul(expr, s_name)
  if expr_is_one(coeff) || factors.length() == 0 {
    return None
  }
  let core = factors_expr(factors)
  if @symcore.compare_expr(core, expr) == 0 {
    return None
  }
  match inverse_laplace_doit_control(core, s_name, t, dorational) {
    Some(value) => Some(expr_simplify(expr_mul(coeff, value)))
    None => None
  }
}

///|
fn inverse_laplace_independent_object_fallback_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  // This is the other half of SymPy's as_independent design: if every rule and
  // the integration fallback fail, the independent factor is still multiplied
  // outside the unevaluated transform of the dependent core.
  let (coeff, factors) = split_mul(expr, s_name)
  if expr_is_one(coeff) || factors.length() == 0 {
    return None
  }
  let core = factors_expr(factors)
  if @symcore.compare_expr(core, expr) == 0 {
    return None
  }
  Some(
    expr_simplify(expr_mul(coeff, make_inverse_laplace_object(core, s_name, t))),
  )
}

///|
fn inverse_laplace_rational_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  // Source map: SymPy's _inverse_laplace_rational first apart-normalizes
  // rational functions, emits DiracDelta derivatives for polynomial pieces,
  // handles linear/quadratic denominators directly, and only then recurses
  // with dorational=False for harder terms.
  if !expr_laplace_rational_candidate(expr, s_name) {
    return None
  }
  let (num_exprs, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  let (coeff, var_expr_opt) = split_mul_factor(num_exprs, s_name)
  let direct = match var_expr_opt {
    None => inverse_laplace_no_var(coeff, den, t, s_name)
    Some(var_expr) => inverse_laplace_with_var(coeff, var_expr, den, t, s_name)
  }
  match direct {
    Some(v) => Some(v)
    None =>
      match
        inverse_laplace_improper_rational_term(
          factors_expr(num_exprs),
          den,
          t,
          s_name,
        ) {
        Some(v) => Some(v)
        None =>
          match
            inverse_laplace_linear_power_factors_apart_term(
              factors_expr(num_exprs),
              den,
              t,
              s_name,
            ) {
            Some(v) => Some(v)
            None =>
              match
                inverse_laplace_repeated_linear_apart_term(
                  factors_expr(num_exprs),
                  den,
                  t,
                  s_name,
                ) {
                Some(v) => Some(v)
                None =>
                  match
                    inverse_laplace_linear_factors_apart_term(
                      factors_expr(num_exprs),
                      den,
                      t,
                      s_name,
                    ) {
                    Some(v) => Some(v)
                    None =>
                      inverse_laplace_cubic_apart_term(
                        factors_expr(num_exprs),
                        den,
                        t,
                        s_name,
                      )
                  }
              }
          }
      }
  }
}

///|
fn inverse_laplace_improper_rational_term(
  num : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  let num_coeffs = match poly_coeffs_general_int(num, s_name) {
    Some(value) => poly_trim_general_int(value)
    None => return None
  }
  let den_coeffs = match poly_coeffs_general_int(den, s_name) {
    Some(value) => poly_trim_general_int(value)
    None => return None
  }
  if num_coeffs.length() < den_coeffs.length() || den_coeffs.length() <= 1 {
    return None
  }
  let (quotient, remainder) = match
    inverse_laplace_poly_divmod_expr(num_coeffs, den_coeffs) {
    Some(value) => value
    None => return None
  }
  if quotient.is_empty() {
    return None
  }
  let terms : Array[Expr] = []
  if !inverse_laplace_poly_coeffs_are_zero(quotient) {
    let quotient_expr = polynomial_horner_light_from_coeffs(quotient, s_name)
    match inverse_laplace_doit_control(quotient_expr, s_name, t, false) {
      Some(value) => terms.push(value)
      None => return None
    }
  }
  if !inverse_laplace_poly_coeffs_are_zero(remainder) {
    let remainder_expr = polynomial_horner_light_from_coeffs(remainder, s_name)
    let proper_expr = expr_div(remainder_expr, den)
    match inverse_laplace_rational_term(proper_expr, s_name, t) {
      Some(value) => terms.push(value)
      None => return None
    }
  }
  if terms.is_empty() {
    None
  } else {
    Some(expr_simplify(@symcore.add(terms)))
  }
}

///|
fn inverse_laplace_poly_divmod_expr(
  dividend : Array[Expr],
  divisor : Array[Expr],
) -> (Array[Expr], Array[Expr])? {
  let divisor = poly_trim_general_int(divisor)
  if divisor.is_empty() {
    return None
  }
  let divisor_degree = divisor.length() - 1
  let divisor_lead = divisor[divisor_degree]
  if expr_is_zero(divisor_lead) {
    return None
  }
  let mut remainder = poly_trim_general_int(dividend)
  if remainder.length() < divisor.length() {
    return Some(([], remainder))
  }
  let quotient : Array[Expr] = []
  for _ in 0..<(remainder.length() - divisor_degree) {
    quotient.push(@symcore.int(0))
  }
  while !remainder.is_empty() && remainder.length() >= divisor.length() {
    let remainder_degree = remainder.length() - 1
    let offset = remainder_degree - divisor_degree
    let coeff = expr_simplify(
      expr_div(remainder[remainder_degree], divisor_lead),
    )
    quotient[offset] = expr_add(quotient[offset], coeff)
    for i in 0..<=divisor_degree {
      remainder[i + offset] = expr_sub(
        remainder[i + offset],
        expr_mul(coeff, divisor[i]),
      )
    }
    remainder = poly_trim_general_int(remainder)
  }
  Some((poly_trim_general_int(quotient), remainder))
}

///|
fn inverse_laplace_poly_coeffs_are_zero(coeffs : Array[Expr]) -> Bool {
  for coeff in coeffs {
    if !expr_is_zero(coeff) {
      return false
    }
  }
  true
}

///|
fn inverse_laplace_repeated_linear_apart_term(
  num : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  let ((a_rep, b_rep, rep_power), (a_single, b_single)) = match
    split_repeated_linear_pair(den, s_name) {
    Some(value) => value
    None => return None
  }
  if rep_power < 2 || expr_is_zero(a_rep) || expr_is_zero(a_single) {
    return None
  }
  let root_rep = expr_div(expr_mul(@symcore.int(-1), b_rep), a_rep)
  let single_at_rep = expr_add(expr_mul(a_single, root_rep), b_single)
  if expr_is_zero(single_at_rep) {
    return None
  }
  let num_coeffs = match poly_coeffs_general(num, s_name) {
    Some(coeffs) if coeffs.length() <= rep_power + 1 => coeffs
    _ => return None
  }
  let u_coeffs = inverse_laplace_poly_coeffs_after_linear_change(
    num_coeffs,
    root_rep,
    expr_div(@symcore.int(1), a_rep),
    rep_power,
  )
  let single_u_coeff = expr_div(a_single, a_rep)
  let repeated_coeffs : Array[Expr] = []
  for _ in 0..<=rep_power {
    repeated_coeffs.push(@symcore.int(0))
  }
  let mut next_higher = @symcore.int(0)
  for j in 0..<rep_power {
    let power = rep_power - j
    let coeff = expr_div(
      expr_sub(
        inverse_laplace_coeff_at(u_coeffs, j),
        expr_mul(next_higher, single_u_coeff),
      ),
      single_at_rep,
    )
    repeated_coeffs[power] = expr_simplify(coeff)
    next_higher = coeff
  }
  let single_coeff = expr_simplify(
    expr_sub(
      inverse_laplace_coeff_at(u_coeffs, rep_power),
      expr_mul(repeated_coeffs[1], single_u_coeff),
    ),
  )
  let rep_linear = expr_add(
    expr_mul(a_rep, @symcore.Expr::Symbol(s_name)),
    b_rep,
  )
  let single_linear = expr_add(
    expr_mul(a_single, @symcore.Expr::Symbol(s_name)),
    b_single,
  )
  let parts : Array[Expr] = []
  for power in 1..<=rep_power {
    let coeff = repeated_coeffs[power]
    if expr_is_zero(coeff) {
      continue
    }
    let den = if power == 1 {
      rep_linear
    } else {
      expr_pow(rep_linear, @symcore.int(power))
    }
    match inverse_laplace_linear_power_no_var(coeff, den, t, s_name) {
      Some(v) => parts.push(v)
      None => return None
    }
  }
  if !expr_is_zero(single_coeff) {
    match
      inverse_laplace_linear_power_no_var(
        single_coeff, single_linear, t, s_name,
      ) {
      Some(v) => parts.push(v)
      None => return None
    }
  }
  if parts.is_empty() {
    None
  } else {
    Some(@symcore.add(parts))
  }
}

///|
fn inverse_laplace_linear_power_factors_apart_term(
  num : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  let factors = match split_linear_power_factors(den, s_name) {
    Some(value) if value.length() >= 2 => value
    _ => return None
  }
  let parts = match
    inverse_laplace_linear_power_apart_parts(num, factors, s_name) {
    Some(value) => value
    None => return None
  }
  let terms : Array[Expr] = []
  for part in parts {
    let (coeff, a, b, power) = part
    if expr_is_zero(coeff) {
      continue
    }
    let linear = expr_add(expr_mul(a, @symcore.Expr::Symbol(s_name)), b)
    let den = if power == 1 {
      linear
    } else {
      expr_pow(linear, @symcore.int(power))
    }
    match inverse_laplace_linear_power_no_var(coeff, den, t, s_name) {
      Some(value) => terms.push(value)
      None => return None
    }
  }
  if terms.is_empty() {
    None
  } else {
    Some(@symcore.add(terms))
  }
}

///|
fn inverse_laplace_linear_factors_apart_term(
  num : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  let factors = match split_distinct_linear_factors(den, s_name) {
    Some(value) if value.length() >= 3 => value
    Some(_) => return None
    None => return None
  }
  let num_coeffs = match poly_coeffs_general(num, s_name) {
    Some(coeffs) if coeffs.length() <= factors.length() => coeffs
    _ => return None
  }
  let parts : Array[Expr] = []
  for i in 0..<factors.length() {
    let (ai, bi) = factors[i]
    let root = expr_div(expr_mul(@symcore.int(-1), bi), ai)
    let mut denom_at = @symcore.int(1)
    for j in 0..<factors.length() {
      if i != j {
        let (aj, bj) = factors[j]
        denom_at = expr_mul(denom_at, expr_add(expr_mul(aj, root), bj))
      }
    }
    if expr_is_zero(denom_at) {
      return None
    }
    let coeff = expr_div(
      inverse_laplace_eval_poly_coeffs(num_coeffs, root),
      denom_at,
    )
    if !expr_is_zero(coeff) {
      let linear = expr_add(expr_mul(ai, @symcore.Expr::Symbol(s_name)), bi)
      match inverse_laplace_linear_power_no_var(coeff, linear, t, s_name) {
        Some(v) => parts.push(v)
        None => return None
      }
    }
  }
  if parts.is_empty() {
    None
  } else {
    Some(@symcore.add(parts))
  }
}

///|
fn inverse_laplace_rational_apart_expr(
  num : Expr,
  den : Expr,
  s_name : String,
) -> Expr? {
  match inverse_laplace_linear_power_factors_apart_expr(num, den, s_name) {
    Some(value) => Some(value)
    None =>
      match inverse_laplace_repeated_linear_apart_expr(num, den, s_name) {
        Some(value) => Some(value)
        None => inverse_laplace_linear_factors_apart_expr(num, den, s_name)
      }
  }
}

///|
fn inverse_laplace_linear_power_factors_apart_expr(
  num : Expr,
  den : Expr,
  s_name : String,
) -> Expr? {
  let factors = match split_linear_power_factors(den, s_name) {
    Some(value) if value.length() >= 2 => value
    _ => return None
  }
  let parts = match
    inverse_laplace_linear_power_apart_parts(num, factors, s_name) {
    Some(value) => value
    None => return None
  }
  let terms : Array[Expr] = []
  for part in parts {
    let (coeff, a, b, power) = part
    if expr_is_zero(coeff) {
      continue
    }
    let linear = expr_add(expr_mul(a, @symcore.Expr::Symbol(s_name)), b)
    let den = if power == 1 {
      linear
    } else {
      expr_pow(linear, @symcore.int(power))
    }
    terms.push(expr_div(coeff, den))
  }
  if terms.length() > 1 {
    Some(@symcore.add(terms))
  } else {
    None
  }
}

///|
fn inverse_laplace_repeated_linear_apart_expr(
  num : Expr,
  den : Expr,
  s_name : String,
) -> Expr? {
  let ((a_rep, b_rep, rep_power), (a_single, b_single)) = match
    split_repeated_linear_pair(den, s_name) {
    Some(value) => value
    None => return None
  }
  if rep_power < 2 || expr_is_zero(a_rep) || expr_is_zero(a_single) {
    return None
  }
  let root_rep = expr_div(expr_mul(@symcore.int(-1), b_rep), a_rep)
  let single_at_rep = expr_add(expr_mul(a_single, root_rep), b_single)
  if expr_is_zero(single_at_rep) {
    return None
  }
  let num_coeffs = match poly_coeffs_general(num, s_name) {
    Some(coeffs) if coeffs.length() <= rep_power + 1 => coeffs
    _ => return None
  }
  let u_coeffs = inverse_laplace_poly_coeffs_after_linear_change(
    num_coeffs,
    root_rep,
    expr_div(@symcore.int(1), a_rep),
    rep_power,
  )
  let single_u_coeff = expr_div(a_single, a_rep)
  let repeated_coeffs : Array[Expr] = []
  for _ in 0..<=rep_power {
    repeated_coeffs.push(@symcore.int(0))
  }
  let mut next_higher = @symcore.int(0)
  for j in 0..<rep_power {
    let power = rep_power - j
    let coeff = expr_div(
      expr_sub(
        inverse_laplace_coeff_at(u_coeffs, j),
        expr_mul(next_higher, single_u_coeff),
      ),
      single_at_rep,
    )
    repeated_coeffs[power] = expr_simplify(coeff)
    next_higher = coeff
  }
  let single_coeff = expr_simplify(
    expr_sub(
      inverse_laplace_coeff_at(u_coeffs, rep_power),
      expr_mul(repeated_coeffs[1], single_u_coeff),
    ),
  )
  let rep_linear = expr_add(
    expr_mul(a_rep, @symcore.Expr::Symbol(s_name)),
    b_rep,
  )
  let single_linear = expr_add(
    expr_mul(a_single, @symcore.Expr::Symbol(s_name)),
    b_single,
  )
  let terms : Array[Expr] = []
  for power in 1..<=rep_power {
    let coeff = repeated_coeffs[power]
    if expr_is_zero(coeff) {
      continue
    }
    let part_den = if power == 1 {
      rep_linear
    } else {
      expr_pow(rep_linear, @symcore.int(power))
    }
    terms.push(expr_div(coeff, part_den))
  }
  if !expr_is_zero(single_coeff) {
    terms.push(expr_div(single_coeff, single_linear))
  }
  if terms.length() > 1 {
    Some(@symcore.add(terms))
  } else {
    None
  }
}

///|
fn inverse_laplace_linear_factors_apart_expr(
  num : Expr,
  den : Expr,
  s_name : String,
) -> Expr? {
  let factors = match split_distinct_linear_factors(den, s_name) {
    Some(value) if value.length() >= 3 => value
    Some(_) => return None
    None => return None
  }
  let num_coeffs = match poly_coeffs_general(num, s_name) {
    Some(coeffs) if coeffs.length() <= factors.length() => coeffs
    _ => return None
  }
  let terms : Array[Expr] = []
  for i in 0..<factors.length() {
    let (ai, bi) = factors[i]
    let root = expr_div(expr_mul(@symcore.int(-1), bi), ai)
    let mut denom_at = @symcore.int(1)
    for j in 0..<factors.length() {
      if i != j {
        let (aj, bj) = factors[j]
        denom_at = expr_mul(denom_at, expr_add(expr_mul(aj, root), bj))
      }
    }
    if expr_is_zero(denom_at) {
      return None
    }
    let coeff = expr_div(
      inverse_laplace_eval_poly_coeffs(num_coeffs, root),
      denom_at,
    )
    if !expr_is_zero(coeff) {
      let linear = expr_add(expr_mul(ai, @symcore.Expr::Symbol(s_name)), bi)
      terms.push(expr_div(coeff, linear))
    }
  }
  if terms.length() > 1 {
    Some(@symcore.add(terms))
  } else {
    None
  }
}

///|
fn inverse_laplace_linear_power_apart_parts(
  num : Expr,
  factors : Array[(Expr, Expr, Int)],
  s_name : String,
) -> Array[(Expr, Expr, Expr, Int)]? {
  let mut total_power = 0
  for factor in factors {
    total_power += factor.2
  }
  let num_coeffs = match poly_coeffs_general(num, s_name) {
    Some(coeffs) if coeffs.length() <= total_power => coeffs
    _ => return None
  }
  if !inverse_laplace_linear_power_factors_distinct(factors) {
    return None
  }
  let basis : Array[Array[Expr]] = []
  let descriptors : Array[(Expr, Expr, Int)] = []
  for idx in 0..<factors.length() {
    let (a, b, power_count) = factors[idx]
    for power in 1..<=power_count {
      descriptors.push((a, b, power))
      basis.push(inverse_laplace_linear_power_apart_basis(factors, idx, power))
    }
  }
  let matrix : Array[Array[Expr]] = []
  let rhs : Array[Expr] = []
  for row_idx in 0..<total_power {
    let row : Array[Expr] = []
    for col_idx in 0..<basis.length() {
      row.push(inverse_laplace_coeff_at(basis[col_idx], row_idx))
    }
    matrix.push(row)
    rhs.push(inverse_laplace_coeff_at(num_coeffs, row_idx))
  }
  let coeffs = match solve_expr_linear_system(matrix, rhs) {
    Some(value) => value
    None => return None
  }
  let out : Array[(Expr, Expr, Expr, Int)] = []
  for idx in 0..<coeffs.length() {
    let (a, b, power) = descriptors[idx]
    out.push((expr_simplify(coeffs[idx]), a, b, power))
  }
  Some(out)
}

///|
fn inverse_laplace_linear_power_factors_distinct(
  factors : Array[(Expr, Expr, Int)],
) -> Bool {
  for i in 0..<factors.length() {
    let (a_i, b_i, _) = factors[i]
    if expr_is_zero(a_i) {
      return false
    }
    for j in (i + 1)..<factors.length() {
      let (a_j, b_j, _) = factors[j]
      if expr_is_zero(a_j) ||
        expr_is_zero(expr_sub(expr_mul(a_i, b_j), expr_mul(a_j, b_i))) {
        return false
      }
    }
  }
  true
}

///|
fn inverse_laplace_linear_power_apart_basis(
  factors : Array[(Expr, Expr, Int)],
  target_index : Int,
  target_power : Int,
) -> Array[Expr] {
  let mut poly : Array[Expr] = [@symcore.int(1)]
  for idx in 0..<factors.length() {
    let (a, b, power_count) = factors[idx]
    let remaining = if idx == target_index {
      power_count - target_power
    } else {
      power_count
    }
    if remaining > 0 {
      poly = poly_mul_general(poly, poly_pow_general([b, a], remaining))
    }
  }
  poly
}

///|
fn solve_expr_linear_system(
  matrix : Array[Array[Expr]],
  rhs : Array[Expr],
) -> Array[Expr]? {
  let n = rhs.length()
  if matrix.length() != n {
    return None
  }
  let rows : Array[Array[Expr]] = []
  for i in 0..<n {
    if matrix[i].length() != n {
      return None
    }
    let row : Array[Expr] = []
    for j in 0..<n {
      row.push(matrix[i][j])
    }
    row.push(rhs[i])
    rows.push(row)
  }
  for col in 0..<n {
    let mut pivot = col
    while pivot < n && expr_is_zero(rows[pivot][col]) {
      pivot += 1
    }
    if pivot >= n {
      return None
    }
    if pivot != col {
      let tmp = rows[col]
      rows[col] = rows[pivot]
      rows[pivot] = tmp
    }
    let pivot_value = rows[col][col]
    if expr_is_zero(pivot_value) {
      return None
    }
    for j in col..<=n {
      rows[col][j] = expr_simplify(expr_div(rows[col][j], pivot_value))
    }
    for r in 0..<n {
      if r == col {
        continue
      }
      let factor = rows[r][col]
      if expr_is_zero(factor) {
        continue
      }
      for j in col..<=n {
        rows[r][j] = expr_simplify(
          expr_sub(rows[r][j], expr_mul(factor, rows[col][j])),
        )
      }
    }
  }
  let out : Array[Expr] = []
  for i in 0..<n {
    out.push(expr_simplify(rows[i][n]))
  }
  Some(out)
}

///|
fn inverse_laplace_eval_poly_coeffs(coeffs : Array[Expr], value : Expr) -> Expr {
  let mut out = @symcore.int(0)
  let mut power = @symcore.int(1)
  for coeff in coeffs {
    out = expr_add(out, expr_mul(coeff, power))
    power = expr_mul(power, value)
  }
  out
}

///|
fn inverse_laplace_poly_coeffs_after_linear_change(
  coeffs : Array[Expr],
  offset : Expr,
  scale : Expr,
  degree : Int,
) -> Array[Expr] {
  let out : Array[Expr] = []
  for _ in 0..<=degree {
    out.push(@symcore.int(0))
  }
  for i in 0..<coeffs.length() {
    let coeff = coeffs[i]
    if expr_is_zero(coeff) {
      continue
    }
    for k in 0..<=i {
      if k > degree {
        break
      }
      let term = expr_mul(
        coeff,
        expr_mul(
          int_binomial_expr(i, k),
          expr_mul(
            expr_pow(offset, @symcore.int(i - k)),
            expr_pow(scale, @symcore.int(k)),
          ),
        ),
      )
      out[k] = expr_add(out[k], term)
    }
  }
  out.map(expr_simplify)
}

///|
fn int_binomial_expr(n : Int, k : Int) -> Expr {
  if k < 0 || k > n {
    return @symcore.int(0)
  }
  let mut kk = k
  if kk > n - kk {
    kk = n - kk
  }
  let mut result = 1
  for i in 1..<=kk {
    result = result * (n - kk + i) / i
  }
  @symcore.int(result)
}

///|
fn inverse_laplace_cubic_apart_term(
  num : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  let den_coeffs = match poly_coeffs_general(den, s_name) {
    Some(coeffs) if coeffs.length() == 4 => coeffs
    _ => return None
  }
  if !expr_is_zero(den_coeffs[0]) ||
    !expr_is_zero(den_coeffs[2]) ||
    expr_is_zero(den_coeffs[1]) ||
    expr_is_zero(den_coeffs[3]) ||
    expr_depends_on(den_coeffs[1], s_name) ||
    expr_depends_on(den_coeffs[3], s_name) {
    return None
  }
  let num_coeffs = match poly_coeffs_general(num, s_name) {
    Some(coeffs) if coeffs.length() <= 3 => coeffs
    _ => return None
  }
  let c0 = inverse_laplace_coeff_at(num_coeffs, 0)
  let c1 = inverse_laplace_coeff_at(num_coeffs, 1)
  let c2 = inverse_laplace_coeff_at(num_coeffs, 2)
  let a = den_coeffs[3]
  let b = den_coeffs[1]
  let shift = expr_div(b, a)
  let pole_coeff = expr_div(c0, b)
  let quad_linear = expr_div(expr_sub(c2, expr_mul(pole_coeff, a)), a)
  let quad_const = expr_div(c1, a)
  let s = @symcore.Expr::Symbol(s_name)
  let quad_den = expr_add(expr_pow(s, @symcore.int(2)), shift)
  let parts : Array[Expr] = []
  if !expr_is_zero(pole_coeff) {
    match inverse_laplace_linear_power_no_var(pole_coeff, s, t, s_name) {
      Some(v) => parts.push(v)
      None => return None
    }
  }
  if !expr_is_zero(quad_linear) || !expr_is_zero(quad_const) {
    let quad_part = match
      inverse_laplace_shifted_square_term(
        quad_linear, quad_const, quad_den, t, s_name,
      ) {
      Some(v) => Some(v)
      None =>
        inverse_laplace_shifted_diff_square_term(
          quad_linear, quad_const, quad_den, t, s_name,
        )
    }
    match quad_part {
      Some(v) => parts.push(v)
      None => return None
    }
  }
  if parts.is_empty() {
    None
  } else {
    Some(@symcore.add(parts))
  }
}

///|
fn inverse_laplace_coeff_at(coeffs : Array[Expr], index : Int) -> Expr {
  if index < coeffs.length() {
    coeffs[index]
  } else {
    @symcore.int(0)
  }
}

///|
fn expr_laplace_rational_candidate(expr : Expr, s_name : String) -> Bool {
  expr_laplace_rational_info(expr, s_name).1
}

///|
fn expr_laplace_rational_info(expr : Expr, s_name : String) -> (Bool, Bool) {
  match expr {
    @symcore.Expr::Number(_)
    | @symcore.Expr::Float(_)
    | @symcore.Expr::ComplexFloat(_)
    | @symcore.Expr::NumberSymbol(_) => (false, true)
    @symcore.Expr::Symbol(name) => (name == s_name, true)
    @symcore.Expr::Add(args)
    | @symcore.Expr::Mul(args)
    | @symcore.Expr::Tuple(args) => {
      let mut depends = false
      let mut rational = true
      for arg in args {
        let info = expr_laplace_rational_info(arg, s_name)
        depends = depends || info.0
        rational = rational && info.1
      }
      (depends, rational)
    }
    @symcore.Expr::Pow(base, exp) => {
      let base_info = expr_laplace_rational_info(base, s_name)
      let exp_info = expr_laplace_rational_info(exp, s_name)
      let depends = base_info.0 || exp_info.0
      match expr_is_int_value(exp) {
        Some(_) => (depends, base_info.1 && exp_info.1)
        None => if depends { (depends, false) } else { (false, true) }
      }
    }
    @symcore.Expr::Dict(items) => {
      let mut depends = false
      for item in items {
        let (key, value) = item
        let key_info = expr_laplace_rational_info(key, s_name)
        let value_info = expr_laplace_rational_info(value, s_name)
        depends = depends || key_info.0 || value_info.0
        if !key_info.1 || !value_info.1 {
          return (depends, false)
        }
      }
      (depends, true)
    }
    @symcore.Expr::Derivative(inner, args) => {
      let inner_info = expr_laplace_rational_info(inner, s_name)
      let mut depends = inner_info.0
      for arg in args {
        let info = expr_laplace_rational_info(arg, s_name)
        depends = depends || info.0
        if !info.1 {
          return (depends, false)
        }
      }
      (depends, inner_info.1)
    }
    @symcore.Expr::Subs(inner, variable, value) => {
      let inner_info = expr_laplace_rational_info(inner, s_name)
      let variable_info = expr_laplace_rational_info(variable, s_name)
      let value_info = expr_laplace_rational_info(value, s_name)
      let depends = inner_info.0 || variable_info.0 || value_info.0
      (depends, inner_info.1 && variable_info.1 && value_info.1)
    }
    @symcore.Expr::Lambda(vars, body) => {
      let vars_info = expr_laplace_rational_info(vars, s_name)
      let body_info = expr_laplace_rational_info(body, s_name)
      (vars_info.0 || body_info.0, vars_info.1 && body_info.1)
    }
    @symcore.Expr::Mod(left, right)
    | @symcore.Expr::Relational(_, left, right) => {
      let left_info = expr_laplace_rational_info(left, s_name)
      let right_info = expr_laplace_rational_info(right, s_name)
      (left_info.0 || right_info.0, left_info.1 && right_info.1)
    }
    _ =>
      if expr_depends_on(expr, s_name) {
        (true, false)
      } else {
        (false, true)
      }
  }
}

///|
fn inverse_laplace_special_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let flags = transform_head_flags(expr, s_name)
  let has_irrational_shape = flags.has_irrational_shape
  // Keep this order source-led: SymPy's _inverse_laplace_transform tries
  // simple rules, early program rules, then time/frequency/differentiation
  // program rules before falling back to integration.
  match inverse_laplace_constant_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_dirac_polynomial_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  // SymPy's simple-rule table deliberately checks 1/s**b before
  // 1/(s*(s+a)**b), so the a=0 power-law case never falls into the
  // lowergamma shifted-power branch.
  if inverse_laplace_power_law_candidate(expr, s_name) {
    match inverse_laplace_power_law_term(expr, s_name, t) {
      Some(v) => return Some(v)
      None => ()
    }
  }
  match inverse_laplace_shifted_power_law_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_lowergamma_shifted_power_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  if !has_irrational_shape && expr_laplace_rational_candidate(expr, s_name) {
    match inverse_laplace_square_over_quadratic_term(expr, s_name, t) {
      Some(v) => return Some(v)
      None => ()
    }
  }
  // SymPy's early program rules try an embedded LaplaceTransform and then
  // the irrational table before the later time/frequency-shift rules.
  if flags.has_laplace_transform {
    match inverse_laplace_transform_object_term(expr, s_name, t) {
      Some(v) => return Some(v)
      None => ()
    }
  }
  if has_irrational_shape {
    match inverse_laplace_irrational_special_term(expr, s_name, t) {
      Some(v) => return Some(v)
      None => ()
    }
  }
  // Keep log/Ei/atan closed forms intact until the source integration
  // fallback is represented directly; otherwise expansion can split the
  // composite kernels those rules intentionally recognize.
  if !flags.has_log && !flags.has_atan && !flags.has_ei {
    match inverse_laplace_expand_term(expr, s_name, t) {
      Some(v) => return Some(v)
      None => ()
    }
  }
  match inverse_laplace_positive_time_shift_object_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_delay_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_frequency_shift_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_generic_head_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_time_diff_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_frequency_diff_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  if flags.has_log {
    match inverse_laplace_e1_term(expr, s_name, t) {
      Some(v) => return Some(v)
      None => ()
    }
    match inverse_laplace_expint2_term(expr, s_name, t) {
      Some(v) => return Some(v)
      None => ()
    }
  }
  if flags.has_log || flags.has_exp || flags.has_ei {
    match inverse_laplace_log_term(expr, s_name, t) {
      Some(v) => return Some(v)
      None => ()
    }
  }
  if flags.has_atan {
    match inverse_laplace_atan_term(expr, s_name, t) {
      Some(v) => return Some(v)
      None => ()
    }
  }
  if flags.has_log {
    match inverse_laplace_sinh_over_t_term(expr, s_name, t) {
      Some(v) => return Some(v)
      None => ()
    }
  }
  if flags.has_log {
    match inverse_laplace_ci_term(expr, s_name, t) {
      Some(v) => return Some(v)
      None => ()
    }
  }
  None
}

///|
fn inverse_laplace_expand_term(expr : Expr, s_name : String, t : Expr) -> Expr? {
  // Source map: SymPy's _inverse_laplace_expand refuses Add because the main
  // front-end has already split Add.make_args(fn); expansion is only a later
  // rescue path for non-Add terms whose product/power form hides an Add.
  match expr {
    @symcore.Expr::Add(_) => return None
    _ => ()
  }
  let expanded = inverse_laplace_expand_mul_expr(expr)
  match expanded {
    @symcore.Expr::Add(_) if @symcore.compare_expr(expanded, expr) != 0 =>
      inverse_laplace_doit(expanded, s_name, t)
    _ =>
      if expr_laplace_rational_candidate(expr, s_name) {
        let (num_exprs, den_opt) = split_division(expr)
        match den_opt {
          Some(den) =>
            match
              inverse_laplace_rational_apart_expr(
                factors_expr(num_exprs),
                den,
                s_name,
              ) {
              Some(apart) =>
                inverse_laplace_doit_control(apart, s_name, t, true)
              None => None
            }
          None => None
        }
      } else {
        None
      }
  }
}

///|
fn inverse_laplace_exp_normalize_term(expr : Expr, s_name : String) -> Expr? {
  let flags = transform_head_flags(expr, s_name)
  if !flags.has_exp {
    return None
  }
  // SymPy's pre-pass does not combine a separate constant exponential into a
  // positive time-shift factor: E*exp(2*s) stays E*ILT(exp(2*s)), while the
  // single head exp(2*s + 1) can fall through to the integration path.
  if inverse_laplace_has_nonnegative_time_shift_exp(expr, s_name) {
    return None
  }
  let normalized = inverse_laplace_exp_normalize_expr(expr, s_name)
  if @symcore.compare_expr(normalized, expr) == 0 {
    None
  } else {
    Some(normalized)
  }
}

///|
fn inverse_laplace_integration_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  // Source map: SymPy's _inverse_laplace_transform_integration first tries
  // inverse_mellin_transform(F, s, exp(-t), (None, oo)), then falls back to
  // meijerint_inversion(F, s, t), with Piecewise/Heaviside/exp cleanup.
  // This local path mirrors the inverse-Mellin strategy, then uses the
  // non-recursive part of the local Meijer hook before applying the cleanup
  // that rewrites Heaviside(exp(-t)-c) and expand_complex(exp(...)).
  if inverse_laplace_has_applied_undefined(expr, s_name) {
    return None
  }
  match inverse_laplace_exp_offset_integration_term(expr, s_name, t) {
    Some(value) => return Some(value)
    None => ()
  }
  let x_name = "__symbit_laplace_mellin_x"
  let x = @symcore.Expr::Symbol(x_name)
  match do_inverse_mellin_doit(expr, @symcore.Expr::Symbol(s_name), x) {
    Some(value) =>
      Some(
        inverse_laplace_mellin_subst_simplify(
          subst_symbol(
            value,
            x_name,
            @symelem.exp(expr_mul(@symcore.int(-1), t)),
          ),
          t,
        ),
      )
    None =>
      match
        meijerint_inversion_no_laplace_fallback(
          expr,
          @symcore.Expr::Symbol(s_name),
          t,
        ) {
        Some(value) =>
          Some(
            inverse_laplace_mellin_subst_simplify(
              inverse_laplace_meijer_first_piece(value),
              t,
            ),
          )
        None => None
      }
  }
}

///|
fn inverse_laplace_meijer_first_piece(expr : Expr) -> Expr {
  match @symcore.application_parts(expr) {
    Some((head, args)) if @symcore.function_head_name(head) == Some("Piecewise") &&
      args.length() >= 2 => args[0]
    _ => expr
  }
}

///|
fn inverse_laplace_exp_offset_integration_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  match unary_application_arg(expr, "exp") {
    Some(inner) =>
      match linear_coeffs(inner, s_name) {
        Some((shift, offset)) if !expr_is_zero(shift) && !expr_is_zero(offset) =>
          return Some(
            expr_mul(
              @symelem.exp(offset),
              @symspec.dirac_delta(expr_add(t, shift)),
            ),
          )
        _ => ()
      }
    None => ()
  }
  let (num_exprs, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(value) => value
    None => return None
  }
  let num = factors_expr(num_exprs)
  let (shift, offset) = match unary_application_arg(num, "exp") {
    Some(inner) =>
      match linear_coeffs(inner, s_name) {
        Some((shift, offset)) if !expr_is_zero(shift) && !expr_is_zero(offset) =>
          (shift, offset)
        _ => return None
      }
    None => return None
  }
  let (den_coeff, den_offset, den_power) = match
    split_linear_power_denom(den, s_name) {
    Some((coeff, offset, power)) if !expr_is_zero(coeff) =>
      (coeff, offset, power)
    _ => return None
  }
  let pole = expr_div(den_offset, den_coeff)
  let shifted_t = expr_add(t, shift)
  let scale = expr_mul(
    expr_div(@symcore.int(1), expr_pow(den_coeff, @symcore.int(den_power))),
    expr_mul(
      @symelem.exp(expr_sub(offset, expr_mul(pole, shifted_t))),
      @symspec.heaviside(shifted_t),
    ),
  )
  if den_power == 1 {
    Some(expr_simplify(scale))
  } else {
    let log_power = den_power - 1
    let sign = if log_power % 2 == 0 {
      @symcore.int(1)
    } else {
      @symcore.int(-1)
    }
    let log_arg = expr_mul(
      @symelem.exp_polar(expr_mul(@symcore.int(-1), shift)),
      @symelem.exp(expr_mul(@symcore.int(-1), t)),
    )
    Some(
      expr_simplify(
        expr_mul(
          scale,
          expr_div(
            expr_mul(
              sign,
              expr_pow(@symelem.log(log_arg), @symcore.int(log_power)),
            ),
            factorial_expr(@symcore.int(log_power)),
          ),
        ),
      ),
    )
  }
}

///|
fn inverse_laplace_mellin_subst_simplify(expr : Expr, t : Expr) -> Expr {
  let simplified = expr_simplify(expr)
  match @symcore.application_parts(simplified) {
    Some((head, [arg])) if @symcore.function_head_name(head) ==
      Some("Heaviside") =>
      match inverse_laplace_mellin_heaviside_arg(arg, t) {
        Some(mapped) => @symspec.heaviside(mapped)
        None => simplified
      }
    Some((head, [arg])) if @symcore.function_head_name(head) == Some("exp") =>
      match inverse_laplace_mellin_complex_exp(arg, t) {
        Some(mapped) => mapped
        None =>
          @symcore.raw_apply(head, [
            inverse_laplace_mellin_subst_simplify(arg, t),
          ]).unwrap_or(simplified)
      }
    Some((head, args)) =>
      @symcore.raw_apply(
        head,
        args.map(fn(arg) { inverse_laplace_mellin_subst_simplify(arg, t) }),
      ).unwrap_or(simplified)
    None =>
      match simplified {
        @symcore.Expr::Add(args) =>
          @symcore.add(
            args.map(fn(arg) { inverse_laplace_mellin_subst_simplify(arg, t) }),
          )
        @symcore.Expr::Mul(args) =>
          @symcore.mul(
            args.map(fn(arg) { inverse_laplace_mellin_subst_simplify(arg, t) }),
          )
        @symcore.Expr::Pow(base, exp) => {
          let mapped_base = inverse_laplace_mellin_subst_simplify(base, t)
          let mapped_exp = inverse_laplace_mellin_subst_simplify(exp, t)
          match unary_application_arg(mapped_base, "exp") {
            Some(inner) =>
              match
                inverse_laplace_mellin_complex_exp(
                  expr_simplify(expr_mul(mapped_exp, inner)),
                  t,
                ) {
                Some(mapped) => mapped
                None => @symcore.pow(mapped_base, mapped_exp)
              }
            None => @symcore.pow(mapped_base, mapped_exp)
          }
        }
        _ => simplified
      }
  }
}

///|
fn inverse_laplace_mellin_complex_exp(arg : Expr, t : Expr) -> Expr? {
  let t_name = match symbol_name(t) {
    Some(name) => name
    None => return None
  }
  let (real_part, phase) = match
    inverse_laplace_mellin_complex_parts(arg, t_name) {
    Some((real, imag)) =>
      if expr_is_zero(imag) {
        return None
      } else {
        (real, imag)
      }
    None => {
      let phase = match inverse_laplace_extract_imaginary_phase(arg) {
        Some(value) => value
        None => return None
      }
      if !inverse_laplace_mellin_phase_known_real(phase, t_name) {
        return None
      }
      (@symcore.int(0), phase)
    }
  }
  let imag = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::ImaginaryUnit,
  )
  let trig = @symcore.add([
    @symelem.cos(phase),
    @symcore.mul([imag, @symelem.sin(phase)]),
  ])
  if expr_is_zero(real_part) {
    Some(trig)
  } else {
    Some(@symcore.mul([@symelem.exp(real_part), trig]))
  }
}

///|
fn inverse_laplace_mellin_complex_parts(
  expr : Expr,
  t_name : String,
) -> (Expr, Expr)? {
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
    @symcore.Expr::Symbol(name) =>
      if name == t_name {
        Some((expr, @symcore.int(0)))
      } else {
        Some((@symelem.re(expr), @symelem.im(expr)))
      }
    @symcore.Expr::Add(args) => {
      let mut real = @symcore.int(0)
      let mut imag = @symcore.int(0)
      for arg in args {
        match inverse_laplace_mellin_complex_parts(arg, t_name) {
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
        match inverse_laplace_mellin_complex_parts(arg, t_name) {
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
    @symcore.Expr::Pow(base, exp) =>
      match inverse_laplace_mellin_complex_parts(base, t_name) {
        Some((_base_real, base_imag)) if expr_is_zero(base_imag) &&
          !expr_depends_on(exp, t_name) &&
          inverse_laplace_mellin_phase_known_real(exp, t_name) =>
          Some((expr, @symcore.int(0)))
        _ => Some((@symelem.re(expr), @symelem.im(expr)))
      }
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, [arg])) =>
          match @symcore.function_head_name(head) {
            Some("exp") | Some("sin") | Some("cos") | Some("re") | Some("im") =>
              match inverse_laplace_mellin_complex_parts(arg, t_name) {
                Some((_real, imag)) if expr_is_zero(imag) =>
                  Some((expr, @symcore.int(0)))
                _ => Some((@symelem.re(expr), @symelem.im(expr)))
              }
            _ => Some((@symelem.re(expr), @symelem.im(expr)))
          }
        _ => Some((@symelem.re(expr), @symelem.im(expr)))
      }
  }
}

///|
fn inverse_laplace_extract_imaginary_phase(arg : Expr) -> Expr? {
  let imag = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::ImaginaryUnit,
  )
  let neg_imag = expr_mul(@symcore.int(-1), imag)
  let rest : Array[Expr] = []
  let mut removed = false
  for factor in expr_factors(arg) {
    if !removed && expr_same_simplified(factor, imag) {
      removed = true
    } else if !removed && expr_same_simplified(factor, neg_imag) {
      removed = true
      rest.push(@symcore.int(-1))
    } else {
      rest.push(factor)
    }
  }
  if removed {
    Some(factors_expr(rest))
  } else {
    None
  }
}

///|
fn inverse_laplace_mellin_phase_known_real(
  expr : Expr,
  t_name : String,
) -> Bool {
  match expr {
    @symcore.Expr::Number(_)
    | @symcore.Expr::Float(_)
    | @symcore.Expr::NumberSymbol(
      @symcore.NumberSymbolKind::Pi
      | @symcore.NumberSymbolKind::Exp1
      | @symcore.NumberSymbolKind::EulerGamma
      | @symcore.NumberSymbolKind::GoldenRatio
      | @symcore.NumberSymbolKind::Catalan
    ) => true
    @symcore.Expr::Symbol(name) => name == t_name
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      args.all(fn(arg) { inverse_laplace_mellin_phase_known_real(arg, t_name) })
    @symcore.Expr::Pow(base, exp) =>
      inverse_laplace_mellin_phase_known_real(base, t_name) &&
      !expr_depends_on(exp, t_name) &&
      inverse_laplace_mellin_phase_known_real(exp, t_name)
    _ => false
  }
}

///|
fn inverse_laplace_mellin_heaviside_arg(expr : Expr, t : Expr) -> Expr? {
  match inverse_laplace_mellin_exp_linear_coeffs(expr, t) {
    Some((coeff, offset)) => {
      let threshold = expr_simplify(
        expr_div(expr_mul(@symcore.int(-1), offset), coeff),
      )
      if !expr_is_positive(threshold) {
        return None
      }
      let shifted = expr_simplify(expr_add(t, @symelem.log(threshold)))
      if expr_is_negative(coeff) {
        Some(shifted)
      } else if expr_is_positive(coeff) {
        Some(expr_simplify(expr_mul(@symcore.int(-1), shifted)))
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn inverse_laplace_mellin_exp_linear_coeffs(
  expr : Expr,
  t : Expr,
) -> (Expr, Expr)? {
  let t_name = match symbol_name(t) {
    Some(name) => name
    None => return None
  }
  let exp_neg_t = @symelem.exp(expr_mul(@symcore.int(-1), t))
  let simplified = expr_simplify(expr)
  match simplified {
    @symcore.Expr::Add(args) => {
      let mut coeff = @symcore.int(0)
      let mut offset = @symcore.int(0)
      for arg in args {
        match inverse_laplace_mellin_exp_linear_part(arg, exp_neg_t, t_name) {
          Some((part_coeff, part_offset)) => {
            coeff = expr_add(coeff, part_coeff)
            offset = expr_add(offset, part_offset)
          }
          None => return None
        }
      }
      Some((expr_simplify(coeff), expr_simplify(offset)))
    }
    _ => inverse_laplace_mellin_exp_linear_part(simplified, exp_neg_t, t_name)
  }
}

///|
fn inverse_laplace_mellin_exp_linear_part(
  expr : Expr,
  exp_neg_t : Expr,
  t_name : String,
) -> (Expr, Expr)? {
  if expr_same_simplified(expr, exp_neg_t) {
    return Some((@symcore.int(1), @symcore.int(0)))
  }
  match expr_simplify(expr) {
    @symcore.Expr::Mul(args) => {
      let coeff_factors : Array[Expr] = []
      let mut saw_exp = false
      for arg in args {
        if expr_same_simplified(arg, exp_neg_t) {
          if saw_exp {
            return None
          }
          saw_exp = true
        } else if expr_depends_on(arg, t_name) {
          return None
        } else {
          coeff_factors.push(arg)
        }
      }
      if saw_exp {
        let coeff = if coeff_factors.is_empty() {
          @symcore.int(1)
        } else {
          expr_simplify(@symcore.mul(coeff_factors))
        }
        Some((coeff, @symcore.int(0)))
      } else if !expr_depends_on(expr, t_name) {
        Some((@symcore.int(0), expr))
      } else {
        None
      }
    }
    other =>
      if !expr_depends_on(other, t_name) {
        Some((@symcore.int(0), other))
      } else {
        None
      }
  }
}

///|
fn inverse_laplace_has_applied_undefined(expr : Expr, s_name : String) -> Bool {
  match @symcore.application_parts(expr) {
    Some((head, args)) =>
      match @symcore.function_head_name(head) {
        Some(name) if !inverse_laplace_known_function_name(name) => {
          for arg in args {
            if expr_depends_on(arg, s_name) {
              return true
            }
          }
          args.any(fn(arg) {
            inverse_laplace_has_applied_undefined(arg, s_name)
          })
        }
        _ =>
          args.any(fn(arg) {
            inverse_laplace_has_applied_undefined(arg, s_name)
          })
      }
    None =>
      match expr {
        @symcore.Expr::Add(args)
        | @symcore.Expr::Mul(args)
        | @symcore.Expr::Tuple(args) =>
          args.any(fn(arg) {
            inverse_laplace_has_applied_undefined(arg, s_name)
          })
        @symcore.Expr::Pow(base, exp)
        | @symcore.Expr::Mod(base, exp)
        | @symcore.Expr::Relational(_, base, exp) =>
          inverse_laplace_has_applied_undefined(base, s_name) ||
          inverse_laplace_has_applied_undefined(exp, s_name)
        @symcore.Expr::Derivative(inner, args) =>
          inverse_laplace_has_applied_undefined(inner, s_name) ||
          args.any(fn(arg) {
            inverse_laplace_has_applied_undefined(arg, s_name)
          })
        @symcore.Expr::Subs(inner, variable, value) =>
          inverse_laplace_has_applied_undefined(inner, s_name) ||
          inverse_laplace_has_applied_undefined(variable, s_name) ||
          inverse_laplace_has_applied_undefined(value, s_name)
        @symcore.Expr::Dict(items) =>
          items.any(fn(item) {
            inverse_laplace_has_applied_undefined(item.0, s_name) ||
            inverse_laplace_has_applied_undefined(item.1, s_name)
          })
        @symcore.Expr::Lambda(vars, body) =>
          inverse_laplace_has_applied_undefined(vars, s_name) ||
          inverse_laplace_has_applied_undefined(body, s_name)
        _ => false
      }
  }
}

///|
fn inverse_laplace_known_function_name(name : String) -> Bool {
  match name {
    "sqrt"
    | "exp"
    | "exp_polar"
    | "sin"
    | "cos"
    | "tan"
    | "cot"
    | "sec"
    | "csc"
    | "sinh"
    | "cosh"
    | "tanh"
    | "coth"
    | "acoth"
    | "log"
    | "atan"
    | "atanh"
    | "asin"
    | "asinh"
    | "arg"
    | "re"
    | "Ei"
    | "expint"
    | "E1"
    | "Si"
    | "Ci"
    | "Shi"
    | "Chi"
    | "erf"
    | "erfc"
    | "fresnels"
    | "fresnelc"
    | "besselj"
    | "bessely"
    | "besselk"
    | "besseli"
    | "gamma"
    | "lowergamma"
    | "uppergamma"
    | "Abs"
    | "DiracDelta"
    | "Heaviside"
    | "SingularityFunction"
    | "Piecewise"
    | "Tuple"
    | "And"
    | "Or"
    | "Not"
    | "Eq"
    | "Ne"
    | "Min"
    | "Max"
    | "Lt"
    | "Le"
    | "Gt"
    | "Ge"
    | "Derivative"
    | "Subs"
    | "LaplaceTransform"
    | "InverseLaplaceTransform"
    | "MellinTransform"
    | "InverseMellinTransform"
    | "FourierTransform"
    | "InverseFourierTransform"
    | "SineTransform"
    | "InverseSineTransform"
    | "CosineTransform"
    | "InverseCosineTransform"
    | "HankelTransform"
    | "InverseHankelTransform"
    | "Integral"
    | "Matrix"
    | "meijerg"
    | "lerchphi"
    | "factorial" => true
    _ => false
  }
}

///|
fn inverse_laplace_exp_normalize_expr(expr : Expr, s_name : String) -> Expr {
  match expr {
    @symcore.Expr::Add(args) =>
      @symcore.add(
        args.map(fn(arg) { inverse_laplace_exp_normalize_expr(arg, s_name) }),
      )
    @symcore.Expr::Mul(args) =>
      inverse_laplace_exp_normalize_mul(
        args.map(fn(arg) { inverse_laplace_exp_normalize_expr(arg, s_name) }),
        s_name,
      )
    @symcore.Expr::Pow(base, exp) => {
      let base = inverse_laplace_exp_normalize_expr(base, s_name)
      let exp = inverse_laplace_exp_normalize_expr(exp, s_name)
      @symcore.pow(base, exp)
    }
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          @symcore.raw_apply(
            head,
            args.map(fn(arg) { inverse_laplace_exp_normalize_expr(arg, s_name) }),
          ).unwrap_or(expr)
        None => expr
      }
  }
}

///|
fn inverse_laplace_exp_normalize_mul(
  args : Array[Expr],
  s_name : String,
) -> Expr {
  let mut exp_inner : Expr? = None
  let mut exp_count = 0
  let add_factors : Array[Expr] = []
  let rest : Array[Expr] = []
  for arg in args {
    match inverse_laplace_linear_exp_inner(arg, s_name) {
      Some(inner) => {
        exp_inner = Some(
          match exp_inner {
            Some(prev) => expr_add(prev, inner)
            None => inner
          },
        )
        exp_count += 1
      }
      None =>
        match arg {
          @symcore.Expr::Add(_) => add_factors.push(arg)
          _ => rest.push(arg)
        }
    }
  }
  if exp_count == 0 {
    return @symcore.mul(args)
  }
  let total_inner = expr_simplify(exp_inner.unwrap())
  if add_factors.length() == 1 {
    let normalized_add = match add_factors[0] {
      @symcore.Expr::Add(terms) => {
        let mapped : Array[Expr] = []
        for term in terms {
          mapped.push(
            inverse_laplace_exp_normalize_term_with_inner(
              term, total_inner, s_name,
            ),
          )
        }
        @symcore.add(mapped)
      }
      _ => add_factors[0]
    }
    let out : Array[Expr] = []
    for factor in rest {
      out.push(factor)
    }
    out.push(normalized_add)
    return @symcore.mul(out)
  }
  inverse_laplace_combine_exp_product(rest, total_inner)
}

///|
fn inverse_laplace_exp_normalize_term_with_inner(
  term : Expr,
  inner : Expr,
  s_name : String,
) -> Expr {
  if expr_is_zero(inner) {
    term
  } else {
    let factors = match term {
      @symcore.Expr::Mul(args) => args
      _ => [term]
    }
    let with_exp : Array[Expr] = []
    for factor in factors {
      with_exp.push(factor)
    }
    with_exp.push(@symelem.exp(inner))
    inverse_laplace_exp_normalize_mul(with_exp, s_name)
  }
}

///|
fn inverse_laplace_combine_exp_product(
  rest : Array[Expr],
  inner : Expr,
) -> Expr {
  let out : Array[Expr] = []
  for factor in rest {
    out.push(factor)
  }
  if !expr_is_zero(inner) {
    out.push(@symelem.exp(inner))
  }
  factors_expr(out)
}

///|
fn inverse_laplace_linear_exp_inner(expr : Expr, s_name : String) -> Expr? {
  match unary_application_arg(expr, "exp") {
    Some(inner) =>
      match linear_coeffs(inner, s_name) {
        Some(_) => Some(inner)
        None => None
      }
    None => None
  }
}

///|
fn inverse_laplace_expand_mul_expr(expr : Expr) -> Expr {
  match expr {
    @symcore.Expr::Add(args) => {
      let expanded : Array[Expr] = []
      let mut changed = false
      for arg in args {
        let next = inverse_laplace_expand_mul_expr(arg)
        changed = changed || @symcore.compare_expr(next, arg) != 0
        expanded.push(next)
      }
      if changed {
        @symcore.add(expanded)
      } else {
        expr
      }
    }
    @symcore.Expr::Mul(args) => {
      let expanded : Array[Expr] = []
      let mut changed = false
      let mut has_sum = false
      for arg in args {
        let next = inverse_laplace_expand_mul_expr(arg)
        changed = changed || @symcore.compare_expr(next, arg) != 0
        match next {
          @symcore.Expr::Add(_) => has_sum = true
          _ => ()
        }
        expanded.push(next)
      }
      if has_sum {
        inverse_laplace_expand_mul_sequence(expanded)
      } else if changed {
        @symcore.mul(expanded)
      } else {
        expr
      }
    }
    @symcore.Expr::Pow(base, exp) => {
      let base_expanded = inverse_laplace_expand_mul_expr(base)
      let exp_expanded = inverse_laplace_expand_mul_expr(exp)
      match (base_expanded, expr_is_int_value(exp_expanded)) {
        (@symcore.Expr::Add(_), Some(power)) if power > 1 => {
          let factors : Array[Expr] = []
          for _ in 0..<power {
            factors.push(base_expanded)
          }
          return inverse_laplace_expand_mul_sequence(factors)
        }
        _ => ()
      }
      if @symcore.compare_expr(base_expanded, base) == 0 &&
        @symcore.compare_expr(exp_expanded, exp) == 0 {
        expr
      } else {
        @symcore.pow(base_expanded, exp_expanded)
      }
    }
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) => {
          let expanded : Array[Expr] = []
          let mut changed = false
          for arg in args {
            let next = inverse_laplace_expand_mul_expr(arg)
            changed = changed || @symcore.compare_expr(next, arg) != 0
            expanded.push(next)
          }
          if changed {
            @symcore.raw_apply(head, expanded).unwrap_or(expr)
          } else {
            expr
          }
        }
        None => expr
      }
  }
}

///|
fn inverse_laplace_additive_terms(expr : Expr) -> Array[Expr] {
  match expr {
    @symcore.Expr::Add(args) => args
    _ => [expr]
  }
}

///|
fn inverse_laplace_expand_mul_sums_range(
  sums : Array[Expr],
  start : Int,
  end_ : Int,
) -> Array[Expr] {
  let len = end_ - start
  if len <= 0 {
    return [@symcore.int(1)]
  }
  if len == 1 {
    return inverse_laplace_additive_terms(sums[start])
  }
  let mid = start + len / 2
  let left = inverse_laplace_expand_mul_sums_range(sums, start, mid)
  let right = inverse_laplace_expand_mul_sums_range(sums, mid, end_)
  let products : Array[Expr] = []
  for a in left {
    for b in right {
      products.push(@symcore.mul([a, b]))
    }
  }
  inverse_laplace_additive_terms(@symcore.add(products))
}

///|
fn inverse_laplace_expand_mul_sequence(factors : Array[Expr]) -> Expr {
  let plain : Array[Expr] = []
  let sums : Array[Expr] = []
  for factor in factors {
    match factor {
      @symcore.Expr::Add(_) => sums.push(factor)
      _ => plain.push(factor)
    }
  }
  if sums.is_empty() {
    return @symcore.mul(factors)
  }
  let plain_term = if plain.is_empty() {
    @symcore.int(1)
  } else {
    @symcore.mul(plain)
  }
  let terms = inverse_laplace_expand_mul_sums_range(sums, 0, sums.length())
  let scaled : Array[Expr] = []
  for term in terms {
    if plain.is_empty() {
      scaled.push(term)
    } else {
      scaled.push(@symcore.mul([plain_term, term]))
    }
  }
  if scaled.length() == 1 {
    scaled[0]
  } else {
    @symcore.add(scaled)
  }
}

///|
fn inverse_laplace_irrational_special_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  match inverse_laplace_bessel_branch_term(expr, s_name, t) {
    Some(v) => return Some(v)
    None => ()
  }
  inverse_laplace_irrational_algebraic_term(expr, s_name, t)
}

///|
fn inverse_laplace_constant_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  // Source map: SymPy special-cases f == 1 as DiracDelta(t), while later
  // simple-table matches such as a/s are wrapped in Heaviside(t).
  if expr_depends_on(expr, s_name) {
    None
  } else {
    Some(expr_mul(expr, @symspec.dirac_delta(t)))
  }
}

///|
fn inverse_laplace_heaviside(t : Expr, body : Expr) -> Expr {
  expr_mul(@symspec.heaviside(t), body)
}

///|
fn inverse_laplace_dirac_polynomial_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (_, den_opt) = split_division_raw(expr)
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
    expr_mul(
      coeff,
      @symcore.raw_function("DiracDelta", [t, @symcore.int(order)]),
    ),
  )
}

///|
fn inverse_laplace_time_diff_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (_, den_opt) = split_division_raw(expr)
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
  let reduced = expr_simplify(factors_expr(rest))
  let power_factor = @symcore.Expr::Symbol(s_name) ^ @symcore.int(order)
  match reduced {
    @symcore.Expr::Add(terms) => {
      let mapped : Array[Expr] = []
      for term in terms {
        let lifted = expr_simplify(power_factor * term)
        match inverse_laplace_doit(lifted, s_name, t) {
          Some(v) => mapped.push(v)
          None => mapped.push(make_inverse_laplace_object(lifted, s_name, t))
        }
      }
      return Some(expr_mul(coeff, expr_simplify(@symcore.add(mapped))))
    }
    _ => ()
  }
  let base = match inverse_laplace_doit(reduced, s_name, t) {
    Some(v) => v
    None => make_inverse_laplace_object(reduced, s_name, t)
  }
  let differentiated = if inverse_laplace_has_transform_object(base) {
    make_expr_derivative(base, t, order)
  } else {
    // Source map: SymPy's _inverse_laplace_time_diff replaces
    // Heaviside(t) by 1 before differentiating, then wraps the result in a
    // fresh Heaviside(t). This prevents spurious DiracDelta terms from
    // differentiating the support marker.
    let mut value = inverse_laplace_replace_heaviside_at_t(base, t)
    for _ in 0..<order {
      value = @symcalculus.diff(value, t)
    }
    inverse_laplace_heaviside(t, value)
  }
  Some(expr_mul(coeff, differentiated))
}

///|
fn inverse_laplace_has_transform_object(expr : Expr) -> Bool {
  @symcore.has(expr, @symcore.Expr::FunctionHead("InverseLaplaceTransform"))
}

///|
fn inverse_laplace_replace_heaviside_at_t(expr : Expr, t : Expr) -> Expr {
  match @symcore.application_parts(expr) {
    Some((head, [arg])) if @symcore.function_head_name(head) ==
      Some("Heaviside") &&
      expr_eq(arg, t) => @symcore.int(1)
    Some((head, args)) =>
      @symcore.raw_apply(
        head,
        args.map(fn(arg) { inverse_laplace_replace_heaviside_at_t(arg, t) }),
      ).unwrap_or(expr)
    None =>
      match expr {
        @symcore.Expr::Add(args) =>
          @symcore.add(
            args.map(fn(arg) { inverse_laplace_replace_heaviside_at_t(arg, t) }),
          )
        @symcore.Expr::Mul(args) =>
          @symcore.mul(
            args.map(fn(arg) { inverse_laplace_replace_heaviside_at_t(arg, t) }),
          )
        @symcore.Expr::Pow(base, exp) =>
          @symcore.pow(
            inverse_laplace_replace_heaviside_at_t(base, t),
            inverse_laplace_replace_heaviside_at_t(exp, t),
          )
        _ => expr
      }
  }
}

///|
fn inverse_laplace_frequency_diff_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  // Source map: SymPy's _inverse_laplace_diff rewrites
  // Derivative(g, (s, n)) to (-t)**n * ILT(g), and recurses with
  // dorational=False so the derivative rule itself owns the outer shape.
  let (coeff, factors) = split_mul(expr, s_name)
  if factors.length() != 1 {
    return None
  }
  let (inner, deriv_args) = match @symcore.derivative_parts(factors[0]) {
    Some(value) => value
    None => return None
  }
  let order = match inverse_laplace_derivative_order_args(deriv_args, s_name) {
    Some(value) if value > 0 => value
    _ => return None
  }
  let base = match inverse_laplace_doit_control(inner, s_name, t, false) {
    Some(value) => value
    None => make_inverse_laplace_object(inner, s_name, t)
  }
  let signed_power = if order % 2 == 0 {
    expr_pow(t, @symcore.int(order))
  } else {
    expr_mul(@symcore.int(-1), expr_pow(t, @symcore.int(order)))
  }
  Some(expr_mul(coeff, expr_mul(signed_power, base)))
}

///|
fn inverse_laplace_frequency_shift_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  // Source map: SymPy's _inverse_laplace_freq_shift only rewrites unary
  // functions F(s-a), and only when re(a).is_positive is known.
  let (coeff, factors) = split_mul(expr, s_name)
  if factors.length() != 1 {
    return None
  }
  match named_unary_application(factors[0]) {
    Some((name, arg)) =>
      match linear_coeffs(arg, s_name) {
        Some((arg_coeff, offset)) if expr_is_one(arg_coeff) &&
          inverse_laplace_frequency_shift_offset_supported(offset) => {
          let shifted = @symcore.raw_function(name, [
            @symcore.Expr::Symbol(s_name),
          ])
          let base = make_inverse_laplace_object(shifted, s_name, t)
          Some(
            expr_mul(coeff, expr_mul(@symelem.exp(expr_mul(offset, t)), base)),
          )
        }
        _ => None
      }
    None => None
  }
}

///|
fn inverse_laplace_frequency_shift_offset_supported(offset : Expr) -> Bool {
  if expr_is_negative(offset) {
    return true
  }
  match meijerint_exact_complex_parts(offset) {
    Some((real, _imag)) => expr_is_negative(real)
    None => false
  }
}

///|
fn inverse_laplace_derivative_order_args(
  deriv_args : Array[Expr],
  s_name : String,
) -> Int? {
  if deriv_args.length() == 0 || deriv_args.length() % 2 != 0 {
    return None
  }
  let mut order = 0
  let mut idx = 0
  while idx < deriv_args.length() {
    match deriv_args[idx] {
      @symcore.Expr::Symbol(name) if name == s_name =>
        match expr_is_int_value(deriv_args[idx + 1]) {
          Some(value) if value > 0 => order += value
          _ => return None
        }
      _ => return None
    }
    idx += 2
  }
  Some(order)
}

///|
fn inverse_laplace_transform_object_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  // Source map: SymPy's early _inverse_laplace_laplace rule only unwraps a
  // direct LaplaceTransform whose transform variable matches the outer s.
  // Other embedded transforms fall through to the normal dispatcher.
  match @symcore.application_parts(expr) {
    Some((head, [inner, source_t, source_s])) =>
      if @symcore.function_head_name(head) == Some("LaplaceTransform") {
        let s_sym = @symcore.Expr::Symbol(s_name)
        if expr_eq(source_s, s_sym) {
          match symbol_name(source_t) {
            Some(source_name) =>
              Some(
                inverse_laplace_heaviside(
                  t,
                  subst_symbol(inner, source_name, t),
                ),
              )
            None => Some(inverse_laplace_heaviside(t, inner))
          }
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
fn inverse_laplace_add_termwise(
  terms : Array[Expr],
  s_name : String,
  t : Expr,
  dorational : Bool,
) -> Expr? {
  let mapped : Array[Expr] = []
  for term in terms {
    match inverse_laplace_doit_control(term, s_name, t, dorational) {
      Some(v) => mapped.push(v)
      None => mapped.push(make_inverse_laplace_object(term, s_name, t))
    }
  }
  Some(@symcore.add(mapped))
}

///|
fn make_inverse_laplace_object(expr : Expr, s_name : String, t : Expr) -> Expr {
  let (coeff, factors) = split_mul(expr, s_name)
  let core = factors_expr(factors)
  expr_mul(
    coeff,
    @symcore.raw_function("InverseLaplaceTransform", [
      core,
      @symcore.Expr::Symbol(s_name),
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
  if !expr_eq(den, @symcore.Expr::Symbol(s_name)) {
    return None
  }
  let numerator = factors_expr(num)
  let (coeff, factors) = split_mul(numerator, s_name)
  if !expr_eq(coeff, expr_rat(-1, 2)) || factors.length() != 1 {
    return None
  }
  match unary_application_arg(factors[0], "log") {
    Some(inner) =>
      match poly_coeffs_upto2(inner, s_name) {
        Some(coeffs) =>
          if expr_eq(coeffs[0], @symcore.int(1)) &&
            expr_is_zero(coeffs[1]) &&
            expr_eq(coeffs[2], @symcore.int(1)) {
            Some(inverse_laplace_heaviside(t, @symspec.ci(t)))
          } else {
            None
          }
        None => None
      }
    None => None
  }
}

///|
fn inverse_laplace_e1_term(expr : Expr, s_name : String, t : Expr) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  if !expr_eq(den, @symcore.Expr::Symbol(s_name)) {
    return None
  }
  let numerator = factors_expr(num)
  if matches_log_one_plus_linear(numerator, s_name) {
    Some(inverse_laplace_heaviside(t, @symspec.e1(t)))
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
  if inverse_laplace_matches_expint2(expr, s_name) {
    Some(inverse_laplace_heaviside(t, @symspec.expint(@symcore.int(2), t)))
  } else {
    None
  }
}

///|
fn inverse_laplace_matches_expint2(expr : Expr, s_name : String) -> Bool {
  let s_sym = @symcore.Expr::Symbol(s_name)
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(value) => value
    None => return false
  }
  if !expr_eq(den, expr_pow(s_sym, @symcore.int(2))) {
    return false
  }
  match factors_expr(num) {
    @symcore.Expr::Add(terms) if terms.length() == 2 => {
      let mut saw_s = false
      let mut saw_neg_log = false
      for term in terms {
        if expr_eq(term, s_sym) {
          saw_s = true
        } else if inverse_laplace_scaled_log_s_plus_one(
            term,
            s_name,
            @symcore.int(-1),
          ) {
          saw_neg_log = true
        } else {
          return false
        }
      }
      saw_s && saw_neg_log
    }
    _ => false
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
  if inverse_laplace_matches_log_plain(expr, s_name) {
    Some(inverse_laplace_heaviside(t, @symelem.log(t)))
  } else {
    None
  }
}

///|
fn inverse_laplace_matches_log_plain(expr : Expr, s_name : String) -> Bool {
  let s_sym = @symcore.Expr::Symbol(s_name)
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(value) => value
    None => return false
  }
  if !expr_eq(den, s_sym) {
    return false
  }
  let numerator = factors_expr(num)
  if inverse_laplace_matches_neg_log_s_minus_euler(numerator, s_name) {
    return true
  }
  let (coeff, factors) = split_mul(numerator, s_name)
  if !expr_is_minus_one(coeff) || factors.length() != 1 {
    return false
  }
  match factors[0] {
    @symcore.Expr::Add(terms) if terms.length() == 2 => {
      let mut saw_log_s = false
      let mut saw_euler = false
      for term in terms {
        if inverse_laplace_is_log_s(term, s_name) {
          saw_log_s = true
        } else if expr_eq(
            term,
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::EulerGamma),
          ) {
          saw_euler = true
        } else {
          return false
        }
      }
      saw_log_s && saw_euler
    }
    _ => false
  }
}

///|
fn inverse_laplace_matches_neg_log_s_minus_euler(
  expr : Expr,
  s_name : String,
) -> Bool {
  match expr {
    @symcore.Expr::Add(terms) if terms.length() == 2 => {
      let mut saw_neg_log_s = false
      let mut saw_neg_euler = false
      for term in terms {
        if inverse_laplace_scaled_log_s(term, s_name, @symcore.int(-1)) {
          saw_neg_log_s = true
        } else if expr_same_simplified(
            term,
            expr_mul(
              @symcore.int(-1),
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::EulerGamma),
            ),
          ) {
          saw_neg_euler = true
        } else {
          return false
        }
      }
      saw_neg_log_s && saw_neg_euler
    }
    _ => false
  }
}

///|
fn inverse_laplace_is_log_s(expr : Expr, s_name : String) -> Bool {
  match unary_application_arg(expr, "log") {
    Some(@symcore.Expr::Symbol(name)) => name == s_name
    _ => false
  }
}

///|
fn inverse_laplace_scaled_log_s(
  expr : Expr,
  s_name : String,
  target_coeff : Expr,
) -> Bool {
  let (coeff, factors) = split_mul_raw(expr, s_name)
  factors.length() == 1 &&
  expr_same_simplified(coeff, target_coeff) &&
  inverse_laplace_is_log_s(factors[0], s_name)
}

///|
fn inverse_laplace_scaled_log_s_plus_one(
  expr : Expr,
  s_name : String,
  target_coeff : Expr,
) -> Bool {
  let (coeff, factors) = split_mul_raw(expr, s_name)
  factors.length() == 1 &&
  expr_same_simplified(coeff, target_coeff) &&
  inverse_laplace_is_log_s_plus_one(factors[0], s_name)
}

///|
fn inverse_laplace_is_log_s_plus_one(expr : Expr, s_name : String) -> Bool {
  match unary_application_arg(expr, "log") {
    Some(inner) =>
      match linear_coeffs(inner, s_name) {
        Some((coeff, offset)) =>
          expr_is_one(coeff) && expr_eq(offset, @symcore.int(1))
        _ => false
      }
    _ => false
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
  if !expr_eq(den, @symcore.Expr::Symbol(s_name)) {
    return None
  }
  let (coeff, factors) = split_mul(factors_expr(num), s_name)
  if !expr_is_minus_one(coeff) || factors.length() != 2 {
    return None
  }
  let mut exp_coeff : Expr? = None
  let mut ei_coeff : Expr? = None
  for factor in factors {
    match named_unary_application(factor) {
      Some(("exp", inner)) =>
        match parse_linear_scale_only(inner, s_name) {
          Some(scale) => exp_coeff = Some(scale)
          _ => return None
        }
      Some(("Ei", inner)) =>
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
      ei_coeff.unwrap_or(@symcore.int(0)),
      expr_mul(@symcore.int(-1), scale),
    ) {
    return None
  }
  let a = expr_simplify(expr_pow(scale, @symcore.int(-1)))
  Some(
    inverse_laplace_heaviside(
      t,
      @symelem.log(expr_add(@symcore.int(1), expr_mul(a, t))),
    ),
  )
}

///|
fn inverse_laplace_atan_term(expr : Expr, s_name : String, t : Expr) -> Expr? {
  let atan_arg = match unary_application_arg(expr, "atan") {
    Some(inner) => Some(inner)
    None => unary_application_arg(expr_simplify(expr), "atan")
  }
  match atan_arg {
    Some(inner) =>
      match parse_scaled_inverse_symbol(inner, s_name) {
        Some(scale) =>
          Some(
            inverse_laplace_heaviside(
              t,
              @symelem.sin(expr_mul(scale, t)) * expr_pow(t, @symcore.int(-1)),
            ),
          )
        None => None
      }
    None => None
  }
}

///|
fn inverse_laplace_sinh_over_t_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (coeff, factors) = split_mul(expr, s_name)
  if !expr_same_simplified(coeff, expr_rat(1, 2)) || factors.length() != 1 {
    return None
  }
  match unary_application_arg(factors[0], "log") {
    Some(inner) =>
      match parse_log_ratio_linear_offsets(inner, s_name) {
        Some((num_offset, den_offset)) =>
          if expr_same_simplified(
              den_offset,
              expr_mul(@symcore.int(-1), num_offset),
            ) {
            Some(
              inverse_laplace_heaviside(
                t,
                @symelem.sinh(expr_mul(num_offset, t)) *
                expr_pow(t, @symcore.int(-1)),
              ),
            )
          } else {
            None
          }
        _ => None
      }
    None => None
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
      match unary_application_arg(factor, "exp") {
        Some(inner) =>
          match parse_laplace_negative_linear_exp_raw(inner, s_name) {
            Some(v) if delay is None => delay = Some(v)
            _ => return None
          }
        None =>
          match parse_symbol_negative_power(factor, s_name) {
            Some(v) if power is None => power = Some(v)
            _ => return None
          }
      }
    }
    match (delay, power) {
      (Some(amount), Some(parsed_power)) =>
        return Some(
          expr_mul(
            @symspec.heaviside(t - amount),
            expr_mul(
              coeff,
              expr_div(
                expr_pow(
                  t - amount,
                  inverse_laplace_power_exponent(parsed_power),
                ),
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
  let exponent = inverse_laplace_power_exponent(power)
  Some(
    inverse_laplace_heaviside(
      t,
      expr_mul(coeff, expr_div(expr_pow(t, exponent), @symspec.gamma(power))),
    ),
  )
}

///|
fn inverse_laplace_shifted_power_law_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (coeff, factors) = split_mul(expr, s_name)
  if factors.length() != 1 || expr_depends_on(coeff, s_name) {
    return None
  }
  let (shift, power) = match
    inverse_laplace_parse_shifted_linear_negative_power(factors[0], s_name) {
    Some(value) => value
    None => return None
  }
  if expr_is_zero(shift) {
    return None
  }
  let exponent = inverse_laplace_power_exponent(power)
  Some(
    inverse_laplace_heaviside(
      t,
      expr_div(
        expr_mul(
          expr_mul(coeff, expr_pow(t, exponent)),
          @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(shift, t))),
        ),
        @symspec.gamma(power),
      ),
    ),
  )
}

///|
fn inverse_laplace_lowergamma_shifted_power_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let parsed = match
    inverse_laplace_lowergamma_shifted_power_from_negative_factors(expr, s_name) {
    Some(value) => Some(value)
    None =>
      inverse_laplace_lowergamma_shifted_power_from_denominator(expr, s_name)
  }
  let (coeff, shift, power) = match parsed {
    Some(value) => value
    None => return None
  }
  if expr_is_zero(shift) {
    return None
  }
  Some(
    inverse_laplace_heaviside(
      t,
      expr_div(
        expr_mul(coeff, @symspec.lowergamma(power, expr_mul(shift, t))),
        expr_mul(expr_pow(shift, power), @symspec.gamma(power)),
      ),
    ),
  )
}

///|
fn inverse_laplace_lowergamma_shifted_power_from_negative_factors(
  expr : Expr,
  s_name : String,
) -> (Expr, Expr, Expr)? {
  let (coeff, factors) = split_mul(expr, s_name)
  if factors.length() != 2 || expr_depends_on(coeff, s_name) {
    return None
  }
  let mut saw_symbol_reciprocal = false
  let mut shifted : (Expr, Expr)? = None
  for factor in factors {
    if inverse_laplace_is_symbol_reciprocal_factor(factor, s_name) {
      if saw_symbol_reciprocal {
        return None
      }
      saw_symbol_reciprocal = true
    } else {
      match
        inverse_laplace_parse_shifted_linear_negative_power(factor, s_name) {
        Some(value) if shifted is None => shifted = Some(value)
        _ => return None
      }
    }
  }
  if !saw_symbol_reciprocal {
    return None
  }
  match shifted {
    Some((shift, power)) => Some((coeff, shift, power))
    None => None
  }
}

///|
fn inverse_laplace_lowergamma_shifted_power_from_denominator(
  expr : Expr,
  s_name : String,
) -> (Expr, Expr, Expr)? {
  let (num_factors, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(value) => value
    None => return None
  }
  let coeff = factors_expr(num_factors)
  if expr_depends_on(coeff, s_name) {
    return None
  }
  let den_factors = match den {
    @symcore.Expr::Mul(args) => args
    _ => [den]
  }
  if den_factors.length() != 2 {
    return None
  }
  let mut saw_symbol = false
  let mut shifted : (Expr, Expr)? = None
  for factor in den_factors {
    if expr_eq(factor, @symcore.Expr::Symbol(s_name)) {
      if saw_symbol {
        return None
      }
      saw_symbol = true
    } else {
      match
        inverse_laplace_parse_shifted_linear_positive_power(factor, s_name) {
        Some(value) if shifted is None => shifted = Some(value)
        _ => return None
      }
    }
  }
  if !saw_symbol {
    return None
  }
  match shifted {
    Some((shift, power)) => Some((coeff, shift, power))
    None => None
  }
}

///|
fn inverse_laplace_is_symbol_reciprocal_factor(
  expr : Expr,
  s_name : String,
) -> Bool {
  match parse_symbol_negative_power(expr, s_name) {
    Some(power) => expr_is_one(power)
    None => false
  }
}

///|
fn inverse_laplace_parse_shifted_linear_negative_power(
  expr : Expr,
  s_name : String,
) -> (Expr, Expr)? {
  retry_with_simplified(expr, expr => {
    match expr {
      @symcore.Expr::Pow(base, exponent) =>
        match extract_explicit_negative_factor(exponent) {
          Some(power) =>
            match inverse_laplace_parse_monic_shifted_linear(base, s_name) {
              Some(shift) if !expr_depends_on(power, s_name) =>
                Some((shift, power))
              _ => None
            }
          None => None
        }
      _ => None
    }
  })
}

///|
fn inverse_laplace_parse_shifted_linear_positive_power(
  expr : Expr,
  s_name : String,
) -> (Expr, Expr)? {
  retry_with_simplified(expr, expr => {
    match expr {
      @symcore.Expr::Pow(base, power) =>
        match inverse_laplace_parse_monic_shifted_linear(base, s_name) {
          Some(shift) if !expr_depends_on(power, s_name) => Some((shift, power))
          _ => None
        }
      _ => None
    }
  })
}

///|
fn inverse_laplace_parse_monic_shifted_linear(
  expr : Expr,
  s_name : String,
) -> Expr? {
  match linear_coeffs(expr, s_name) {
    Some((coeff, shift)) if expr_is_one(coeff) &&
      !expr_depends_on(shift, s_name) => Some(shift)
    _ => None
  }
}

///|
fn inverse_laplace_power_law_candidate(expr : Expr, s_name : String) -> Bool {
  match expr {
    @symcore.Expr::Pow(@symcore.Expr::Symbol(name), power) if name == s_name =>
      extract_explicit_negative_factor(power) is Some(_)
    @symcore.Expr::Mul(args) => {
      let mut saw_power = false
      for arg in args {
        match unary_application_arg(arg, "exp") {
          Some(inner) =>
            if parse_laplace_negative_linear_exp_raw(inner, s_name) is None {
              return false
            }
          None =>
            match arg {
              @symcore.Expr::Pow(@symcore.Expr::Symbol(name), power) =>
                if name == s_name &&
                  extract_explicit_negative_factor(power) is Some(_) {
                  saw_power = true
                } else {
                  return false
                }
              _ => if expr_depends_on(arg, s_name) { return false }
            }
        }
      }
      saw_power
    }
    _ => false
  }
}

///|
fn inverse_laplace_power_exponent(power : Expr) -> Expr {
  match expr_is_int_value(power) {
    Some(value) => @symcore.int(value - 1)
    None => expr_sub(power, @symcore.int(1))
  }
}

///|
fn inverse_laplace_generic_head_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  match inverse_laplace_generic_head_core(expr, s_name, t) {
    Some(v) => Some(v)
    None => {
      if !inverse_laplace_generic_delay_candidate(expr, s_name) {
        return None
      }
      let simplified = expr_simplify(expr)
      match inverse_laplace_generic_head_core(simplified, s_name, t) {
        Some(v) => return Some(v)
        None => ()
      }
      match simplified {
        @symcore.Expr::Mul(args) => {
          let t_name = match symbol_name(t) {
            Some(v) => v
            None => return None
          }
          let mut delay : Expr? = None
          let mut exp_const = @symcore.int(0)
          let rest : Array[Expr] = []
          for factor in args {
            match unary_application_arg(factor, "exp") {
              Some(inner) =>
                match linear_coeffs(inner, s_name) {
                  Some((coeff, offset)) =>
                    if expr_is_negative(coeff) {
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
                    } else {
                      rest.push(factor)
                    }
                  _ => rest.push(factor)
                }
              None => rest.push(factor)
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
}

///|
fn inverse_laplace_generic_delay_candidate(
  expr : Expr,
  s_name : String,
) -> Bool {
  match expr {
    @symcore.Expr::Mul(args) => {
      let mut has_delay = false
      let mut has_head = false
      for arg in args {
        match unary_application_arg(arg, "exp") {
          Some(inner) =>
            if parse_laplace_negative_linear_exp_raw(inner, s_name) is Some(_) {
              has_delay = true
            }
          None =>
            if inverse_laplace_generic_factor_candidate(arg) {
              has_head = true
            }
        }
      }
      has_delay && has_head
    }
    _ => false
  }
}

///|
fn inverse_laplace_generic_factor_candidate(expr : Expr) -> Bool {
  if @symcore.derivative_parts(expr) is Some(_) {
    return true
  }
  match @symcore.application_parts(expr) {
    Some((head, _)) =>
      match @symcore.function_head_name(head) {
        Some("exp") => false
        Some(name) => !inverse_laplace_known_function_name(name)
        None => true
      }
    None => false
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
    Some(v) => Some(expr_mul(coeff, v))
    None => None
  }
}

///|
fn inverse_laplace_generic_head_factor(
  factor : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  match named_unary_application(factor) {
    Some((name, arg)) =>
      inverse_laplace_generic_function_term(name, arg, s_name, t)
    None =>
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
  if inverse_laplace_known_function_name(name) {
    return None
  }
  match linear_coeffs(arg, s_name) {
    Some((coeff, offset)) if expr_is_one(coeff) => {
      let base = @symcore.raw_function("InverseLaplaceTransform", [
        @symcore.raw_function(name, [@symcore.Expr::Symbol(s_name)]),
        @symcore.Expr::Symbol(s_name),
        t,
      ])
      if expr_is_zero(offset) {
        Some(base)
      } else if expr_is_negative(offset) {
        Some(expr_mul(@symelem.exp(expr_mul(offset, t)), base))
      } else {
        None
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
  let sign = if order % 2 == 0 { @symcore.int(1) } else { @symcore.int(-1) }
  Some(expr_mul(sign, expr_mul(expr_pow(t, @symcore.int(order)), base)))
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
  let factors = match expr {
    @symcore.Expr::Mul(args) => args
    _ =>
      match expr_simplify(expr) {
        @symcore.Expr::Mul(args) => args
        _ => return None
      }
  }
  if factors.length() == 0 {
    return None
  }
  let mut coeff = @symcore.int(1)
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
    inverse_laplace_heaviside(
      t,
      if parsed_is_diff {
        @symspec.besseli(parsed_order, arg)
      } else {
        @symspec.besselj(parsed_order, arg)
      },
    ),
  )
}

///|
fn inverse_laplace_square_over_quadratic_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  let (num, den_opt) = split_division_raw(expr)
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
  let coeffs = match poly_coeffs_upto2(den, s_name) {
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
    let freq = expr_sqrt_positive(expr_mul(@symcore.int(-1), ratio))
    expr_mul(
      expr_div(expr_mul(coeff, freq), lead),
      @symelem.sinh(expr_mul(freq, t)),
    )
  } else {
    let freq = expr_sqrt_positive(ratio)
    expr_mul(
      expr_div(expr_mul(@symcore.int(-1), expr_mul(coeff, freq)), lead),
      @symelem.sin(expr_mul(freq, t)),
    )
  }
  Some(
    expr_add(
      expr_mul(delta_coeff, @symcore.raw_function("DiracDelta", [t])),
      inverse_laplace_heaviside(t, wave),
    ),
  )
}

///|
fn inverse_laplace_irrational_algebraic_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  // Source map: SymPy's _inverse_laplace_irrational Bateman 5.3 table is
  // implemented by shape helpers below rather than by rule number.
  //
  // 5.3.4/10/13/16 -> reciprocal powers of (sqrt(s)+a)
  // 5.3.35/44 -> reciprocal sqrt quadratic Bessel branch
  // 5.3.14 -> sqrt(az*s)/(ap*sqrt(s)+bp)^3
  // 5.3.22 -> sqrt(az*s+bz)/(ap*s+bp)
  // 5.3.1/2/5/7/8/9/11/12/15/23 -> mixed linear and sqrt-linear denominators
  // 5.3.6/17/18/19 -> scaled sqrt-ratio families
  let ctx = match laplace_irrational_context(expr, s_name) {
    Some(value) => value
    None => return None
  }
  match inverse_laplace_reciprocal_sqrt_affine_term(ctx, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_reciprocal_sqrt_quadratic_term(ctx, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match inverse_laplace_reciprocal_sqrt_linear_plus_const_term(ctx, t) {
    Some(v) => return Some(v)
    None => ()
  }
  match laplace_irrational_den_factors(ctx).length() {
    1 => {
      match inverse_laplace_shifted_sqrt_over_linear_term(ctx, t) {
        Some(v) => return Some(v)
        None => ()
      }
      inverse_laplace_sqrt_linear_power_term(ctx, t)
    }
    2 => {
      match inverse_laplace_s_over_scaled_sqrt_linear_term(ctx, t) {
        Some(v) => return Some(v)
        None => ()
      }
      match inverse_laplace_scaled_sqrt_ratio_term(ctx, t) {
        Some(v) => return Some(v)
        None => ()
      }
      match inverse_laplace_sqrt_over_sqrt_linear_shifted_linear_term(ctx, t) {
        Some(v) => return Some(v)
        None => ()
      }
      match inverse_laplace_sqrt_linear_power_term(ctx, t) {
        Some(v) => return Some(v)
        None => ()
      }
      match
        inverse_laplace_reciprocal_sqrt_times_sqrt_linear_plus_const_term(
          ctx, t,
        ) {
        Some(v) => return Some(v)
        None => ()
      }
      match inverse_laplace_reciprocal_sqrt_shifted_over_s_term(ctx, t) {
        Some(v) => return Some(v)
        None => ()
      }
      inverse_laplace_reciprocal_sqrt_shifted_linear_term(ctx, t)
    }
    3 => {
      match inverse_laplace_sqrt_linear_over_s_pow_three_halves_term(ctx, t) {
        Some(v) => return Some(v)
        None => ()
      }
      match
        inverse_laplace_reciprocal_sqrt_sqrt_linear_shifted_linear_term(ctx, t) {
        Some(v) => return Some(v)
        None => ()
      }
      inverse_laplace_reciprocal_sqrt_shifted_linear_over_s_term(ctx, t)
    }
    _ => None
  }
}

///|
priv struct LaplaceIrrationalContext {
  s_name : String
  numerator : Expr
  den : Expr
  unit_numerator : Bool
  mut den_factors_cache : Array[Expr]?
  mut den_factor_infos_cache : Array[LaplaceIrrFactorInfo]?
}

///|
priv struct LaplaceIrrFactorInfo {
  linear : (Expr, Expr, Int)?
  sqrt_linear : Expr?
  sqrt_affine : (Expr, Expr)?
  sqrt_affine_plus_const : (Expr, Expr, Expr)?
  scaled_sqrt_linear_plus_const : (Expr, Expr)?
  scaled_sqrt_linear_plus_const_power : (Expr, Expr, Int)?
}

///|
fn laplace_irrational_context(
  expr : Expr,
  s_name : String,
) -> LaplaceIrrationalContext? {
  let (num, den_opt, preserved_den_factors) = split_division_raw_preserve_factors(
    expr,
  )
  let den = match den_opt {
    Some(value) => value
    None => return None
  }
  let unit_numerator = num.length() == 0 ||
    (num.length() == 1 && expr_is_one(num[0]))
  Some(LaplaceIrrationalContext::{
    s_name,
    numerator: factors_expr(num),
    den,
    unit_numerator,
    den_factors_cache: preserved_den_factors,
    den_factor_infos_cache: None,
  })
}

///|
fn laplace_irrational_den_factors(
  ctx : LaplaceIrrationalContext,
) -> Array[Expr] {
  match ctx.den_factors_cache {
    Some(factors) => factors
    None => {
      let factors = match ctx.den {
        @symcore.Expr::Mul(args) => args
        _ =>
          match expr_simplify(ctx.den) {
            @symcore.Expr::Mul(args) => args
            simplified => [simplified]
          }
      }
      ctx.den_factors_cache = Some(factors)
      factors
    }
  }
}

///|
fn laplace_irrational_den_factor_infos(
  ctx : LaplaceIrrationalContext,
) -> Array[LaplaceIrrFactorInfo] {
  match ctx.den_factor_infos_cache {
    Some(infos) => infos
    None => {
      let infos : Array[LaplaceIrrFactorInfo] = []
      for factor in laplace_irrational_den_factors(ctx) {
        infos.push(LaplaceIrrFactorInfo::{
          linear: split_linear_power_denom_direct(factor, ctx.s_name),
          sqrt_linear: parse_sqrt_linear_raw(factor, ctx.s_name),
          sqrt_affine: parse_sqrt_affine_raw(factor, ctx.s_name),
          sqrt_affine_plus_const: parse_sqrt_affine_plus_const_raw(
            factor,
            ctx.s_name,
          ),
          scaled_sqrt_linear_plus_const: parse_scaled_sqrt_linear_plus_const_raw(
            factor,
            ctx.s_name,
          ),
          scaled_sqrt_linear_plus_const_power: parse_scaled_sqrt_linear_plus_const_power_raw(
            factor,
            ctx.s_name,
          ),
        })
      }
      ctx.den_factor_infos_cache = Some(infos)
      infos
    }
  }
}

///|
fn inverse_laplace_reciprocal_sqrt_affine_term(
  ctx : LaplaceIrrationalContext,
  t : Expr,
) -> Expr? {
  if !ctx.unit_numerator {
    return None
  }
  match parse_sqrt_affine(ctx.den, ctx.s_name) {
    Some((scale, offset)) =>
      if expr_is_zero(scale) {
        None
      } else {
        let normalized_offset = expr_simplify(expr_div(offset, scale))
        Some(
          inverse_laplace_heaviside(
            t,
            expr_div(
              @symelem.exp(
                expr_mul(@symcore.int(-1), expr_mul(normalized_offset, t)),
              ),
              expr_mul(
                preferred_positive_sqrt(scale),
                expr_mul(sqrt_pi(), @symelem.sqrt(t)),
              ),
            ),
          ),
        )
      }
    None => None
  }
}

///|
fn inverse_laplace_reciprocal_sqrt_quadratic_term(
  ctx : LaplaceIrrationalContext,
  t : Expr,
) -> Expr? {
  if !ctx.unit_numerator {
    return None
  }
  match unary_application_arg(ctx.den, "sqrt") {
    Some(inner) =>
      match poly_coeffs_upto2(inner, ctx.s_name) {
        Some(coeffs) =>
          if expr_is_zero(coeffs[1]) &&
            !expr_is_zero(coeffs[2]) &&
            !expr_depends_on(coeffs[0], ctx.s_name) &&
            !expr_depends_on(coeffs[2], ctx.s_name) {
            let normalized_constant = expr_simplify(
              expr_div(coeffs[0], coeffs[2]),
            )
            match
              inverse_laplace_reciprocal_sqrt_quadratic_body(
                normalized_constant, t,
              ) {
              Some(body) =>
                Some(
                  expr_simplify(
                    expr_div(body, preferred_positive_sqrt(coeffs[2])),
                  ),
                )
              None => None
            }
          } else {
            None
          }
        _ => None
      }
    None => None
  }
}

///|
fn inverse_laplace_reciprocal_sqrt_quadratic_body(
  constant : Expr,
  t : Expr,
) -> Expr? {
  if expr_is_zero(constant) {
    None
  } else {
    match extract_explicit_negative_factor(constant) {
      Some(pos_constant) =>
        Some(
          inverse_laplace_heaviside(
            t,
            @symspec.besseli(
              @symcore.int(0),
              expr_mul(preferred_positive_sqrt(pos_constant), t),
            ),
          ),
        )
      None =>
        Some(
          inverse_laplace_heaviside(
            t,
            @symspec.besselj(
              @symcore.int(0),
              expr_mul(preferred_positive_sqrt(constant), t),
            ),
          ),
        )
    }
  }
}

///|
fn laplace_source_positive(expr : Expr) -> Bool {
  let simplified = expr_simplify(expr)
  if expr_is_positive(simplified) {
    true
  } else {
    match unary_application_arg(simplified, "sqrt") {
      Some(inner) => expr_is_positive(expr_simplify(inner))
      None => false
    }
  }
}

///|
fn inverse_laplace_reciprocal_sqrt_linear_plus_const_term(
  ctx : LaplaceIrrationalContext,
  t : Expr,
) -> Expr? {
  if !ctx.unit_numerator {
    return None
  }
  let parsed = match parse_sqrt_affine_plus_const(ctx.den, ctx.s_name) {
    Some((scale, offset, constant)) =>
      if expr_is_zero(scale) || !expr_is_zero(offset) {
        None
      } else {
        Some((preferred_positive_sqrt(scale), constant))
      }
    None => parse_scaled_sqrt_linear_plus_const(ctx.den, ctx.s_name)
  }
  match parsed {
    Some((sqrt_coeff, constant)) => {
      if expr_is_zero(sqrt_coeff) {
        return None
      }
      let normalized_const = expr_simplify(expr_div(constant, sqrt_coeff))
      if !laplace_source_positive(normalized_const) &&
        !(laplace_source_positive(constant) &&
        laplace_source_positive(sqrt_coeff)) {
        return None
      }
      let sqrt_t = @symelem.sqrt(t)
      Some(
        inverse_laplace_heaviside(
          t,
          expr_add(
            expr_div(
              @symcore.int(1),
              expr_mul(sqrt_pi(), expr_mul(sqrt_coeff, sqrt_t)),
            ),
            expr_mul(
              expr_mul(
                @symcore.int(-1),
                expr_div(constant, expr_pow(sqrt_coeff, @symcore.int(2))),
              ),
              expr_mul(
                @symelem.exp(
                  expr_mul(expr_pow(normalized_const, @symcore.int(2)), t),
                ),
                @symspec.erfc(expr_mul(normalized_const, sqrt_t)),
              ),
            ),
          ),
        ),
      )
    }
    None => None
  }
}

///|
fn inverse_laplace_s_over_scaled_sqrt_linear_term(
  ctx : LaplaceIrrationalContext,
  t : Expr,
) -> Expr? {
  if laplace_irrational_den_factors(ctx).length() != 2 {
    return None
  }
  let infos = laplace_irrational_den_factor_infos(ctx)
  let mut linear_coeff : Expr? = None
  let mut scale : Expr? = None
  let mut constant : Expr? = None
  for info in infos {
    match info.linear {
      Some((coeff, offset, 1)) =>
        if expr_is_zero(offset) &&
          !expr_is_zero(coeff) &&
          !expr_depends_on(coeff, ctx.s_name) &&
          linear_coeff is None {
          linear_coeff = Some(coeff)
        } else {
          return None
        }
      _ =>
        match info.scaled_sqrt_linear_plus_const {
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
  let parsed_linear_coeff = match linear_coeff {
    Some(v) => v
    None => return None
  }
  let parsed_scale = match scale {
    Some(v) if !expr_is_zero(v) => v
    _ => return None
  }
  let parsed_const = match constant {
    Some(v) if !expr_is_zero(v) && !expr_depends_on(ctx.numerator, ctx.s_name) =>
      v
    _ => return None
  }
  let normalized_const = expr_simplify(expr_div(parsed_const, parsed_scale))
  if !laplace_source_positive(normalized_const) {
    return None
  }
  let sqrt_t = @symelem.sqrt(t)
  let scale_factor = expr_simplify(
    expr_div(ctx.numerator, expr_mul(parsed_linear_coeff, parsed_const)),
  )
  let scaled_term = expr_mul(
    @symelem.exp(
      expr_div(
        expr_mul(expr_pow(parsed_const, @symcore.int(2)), t),
        expr_pow(parsed_scale, @symcore.int(2)),
      ),
    ),
    @symspec.erfc(expr_div(expr_mul(parsed_const, sqrt_t), parsed_scale)),
  )
  Some(
    expr_mul(
      scale_factor,
      inverse_laplace_heaviside(
        t,
        expr_add(@symcore.int(1), expr_mul(@symcore.int(-1), scaled_term)),
      ),
    ),
  )
}

///|
fn inverse_laplace_sqrt_linear_over_s_pow_three_halves_term(
  ctx : LaplaceIrrationalContext,
  t : Expr,
) -> Expr? {
  if laplace_irrational_den_factors(ctx).length() != 3 {
    return None
  }
  let infos = laplace_irrational_den_factor_infos(ctx)
  let mut linear_coeff : Expr? = None
  let mut root_scale : Expr? = None
  let mut shifted_sqrt_scale : Expr? = None
  let mut constant : Expr? = None
  for info in infos {
    match info.linear {
      Some((coeff, offset, 1)) =>
        if expr_is_zero(offset) && linear_coeff is None {
          linear_coeff = Some(coeff)
        } else {
          return None
        }
      _ =>
        match info.sqrt_affine {
          Some((scale, offset)) =>
            if expr_is_zero(offset) && root_scale is None {
              root_scale = Some(scale)
            } else {
              return None
            }
          _ =>
            match info.scaled_sqrt_linear_plus_const {
              Some((scale, parsed_const)) =>
                if shifted_sqrt_scale is None {
                  shifted_sqrt_scale = Some(scale)
                  constant = Some(parsed_const)
                } else {
                  return None
                }
              None =>
                match info.sqrt_affine_plus_const {
                  Some((scale, offset, parsed_const)) =>
                    if expr_is_zero(offset) && shifted_sqrt_scale is None {
                      shifted_sqrt_scale = Some(preferred_positive_sqrt(scale))
                      constant = Some(parsed_const)
                    } else {
                      return None
                    }
                  None => return None
                }
            }
        }
    }
  }
  let parsed_linear_coeff = match linear_coeff {
    Some(v) if !expr_is_zero(v) => v
    _ => return None
  }
  let parsed_root_scale = match root_scale {
    Some(v) if !expr_is_zero(v) => v
    _ => return None
  }
  let parsed_shifted_sqrt_scale = match shifted_sqrt_scale {
    Some(v) if !expr_is_zero(v) => v
    _ => return None
  }
  let parsed_const = match constant {
    Some(v) => v
    _ => return None
  }
  let normalized_const = expr_simplify(
    expr_div(parsed_const, parsed_shifted_sqrt_scale),
  )
  let scale_factor = expr_simplify(
    expr_div(
      ctx.numerator,
      expr_mul(
        parsed_linear_coeff,
        expr_mul(
          preferred_positive_sqrt(parsed_root_scale),
          expr_mul(
            parsed_shifted_sqrt_scale,
            expr_pow(normalized_const, @symcore.int(2)),
          ),
        ),
      ),
    ),
  )
  let sqrt_t = @symelem.sqrt(t)
  let c2t = expr_mul(expr_pow(normalized_const, @symcore.int(2)), t)
  Some(
    expr_mul(
      scale_factor,
      inverse_laplace_heaviside(
        t,
        expr_add(
          expr_add(
            expr_div(
              expr_mul(@symcore.int(2), expr_mul(normalized_const, sqrt_t)),
              sqrt_pi(),
            ),
            expr_mul(
              @symelem.exp(c2t),
              @symspec.erfc(expr_mul(normalized_const, sqrt_t)),
            ),
          ),
          @symcore.int(-1),
        ),
      ),
    ),
  )
}

///|
fn inverse_laplace_scaled_sqrt_ratio_term(
  ctx : LaplaceIrrationalContext,
  t : Expr,
) -> Expr? {
  if laplace_irrational_den_factors(ctx).length() != 2 {
    return None
  }
  let infos = laplace_irrational_den_factor_infos(ctx)
  let mut linear_coeff : Expr? = None
  let mut scale : Expr? = None
  let mut constant : Expr? = None
  for info in infos {
    match info.linear {
      Some((coeff, offset, 1)) =>
        if expr_is_zero(offset) && !expr_is_zero(coeff) && linear_coeff is None {
          linear_coeff = Some(coeff)
        } else {
          return None
        }
      _ =>
        match info.scaled_sqrt_linear_plus_const {
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
  let parsed_linear_coeff = match linear_coeff {
    Some(v) => if expr_is_zero(v) { return None } else { v }
    None => return None
  }
  let parsed_scale = match scale {
    Some(v) if !expr_is_zero(v) => v
    _ => return None
  }
  let parsed_const = match constant {
    Some(v) => v
    None => return None
  }
  let normalized_const = expr_simplify(expr_div(parsed_const, parsed_scale))
  match parse_scaled_sqrt_linear_plus_const(ctx.numerator, ctx.s_name) {
    Some((num_scale, num_const)) => {
      if expr_is_zero(num_scale) {
        return None
      }
      let normalized_num_const = expr_simplify(expr_div(num_const, num_scale))
      if expr_same_simplified(
          normalized_num_const,
          expr_mul(@symcore.int(-1), normalized_const),
        ) {
        let sqrt_t = @symelem.sqrt(t)
        let scaled_term = expr_mul(
          @symelem.exp(expr_mul(expr_pow(normalized_const, @symcore.int(2)), t)),
          @symspec.erfc(expr_mul(normalized_const, sqrt_t)),
        )
        Some(
          expr_mul(
            expr_simplify(
              expr_div(num_scale, expr_mul(parsed_linear_coeff, parsed_scale)),
            ),
            inverse_laplace_heaviside(
              t,
              expr_add(expr_mul(@symcore.int(2), scaled_term), @symcore.int(-1)),
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
fn inverse_laplace_sqrt_over_sqrt_linear_shifted_linear_term(
  ctx : LaplaceIrrationalContext,
  t : Expr,
) -> Expr? {
  let numerator_coeff = match parse_sqrt_affine(ctx.numerator, ctx.s_name) {
    Some((scale, offset)) =>
      if expr_is_zero(offset) && !expr_is_zero(scale) {
        preferred_positive_sqrt(scale)
      } else {
        return None
      }
    None =>
      match parse_sqrt_linear(ctx.numerator, ctx.s_name) {
        Some(v) => v
        None => return None
      }
  }
  if laplace_irrational_den_factors(ctx).length() != 2 {
    return None
  }
  let infos = laplace_irrational_den_factor_infos(ctx)
  let mut alpha : Expr? = None
  let mut shifted_sqrt_scale : Expr? = None
  let mut beta_sq : Expr? = None
  let mut linear_coeff : Expr? = None
  for info in infos {
    match info.scaled_sqrt_linear_plus_const {
      Some((scale, parsed_const)) =>
        if !expr_is_zero(scale) && alpha is None {
          shifted_sqrt_scale = Some(scale)
          alpha = Some(expr_simplify(expr_div(parsed_const, scale)))
        } else {
          return None
        }
      None =>
        match info.linear {
          Some((coeff, offset, 1)) =>
            if !expr_is_zero(coeff) && beta_sq is None {
              linear_coeff = Some(coeff)
              beta_sq = Some(
                expr_simplify(
                  expr_div(expr_mul(@symcore.int(-1), offset), coeff),
                ),
              )
            } else {
              return None
            }
          _ => return None
        }
    }
  }
  let parsed_alpha = match alpha {
    Some(v) => v
    None => return None
  }
  let parsed_shifted_sqrt_scale = match shifted_sqrt_scale {
    Some(v) => if expr_is_zero(v) { return None } else { v }
    None => return None
  }
  let parsed_beta_sq = match beta_sq {
    Some(v) => if expr_is_zero(v) { return None } else { v }
    None => return None
  }
  let parsed_linear_coeff = match linear_coeff {
    Some(v) => if expr_is_zero(v) { return None } else { v }
    None => return None
  }
  let parsed_alpha_sq = expr_simplify(expr_mul(parsed_alpha, parsed_alpha))
  let diff = expr_simplify(expr_sub(parsed_alpha_sq, parsed_beta_sq))
  if expr_is_zero(diff) {
    return None
  }
  let scale_factor = expr_simplify(
    expr_div(
      numerator_coeff,
      expr_mul(parsed_linear_coeff, expr_mul(parsed_shifted_sqrt_scale, diff)),
    ),
  )
  let parsed_beta = preferred_positive_sqrt(parsed_beta_sq)
  let sqrt_t = @symelem.sqrt(t)
  Some(
    expr_mul(
      scale_factor,
      inverse_laplace_heaviside(
        t,
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
            @symcore.int(-1),
            expr_mul(parsed_beta_sq, @symelem.exp(expr_mul(parsed_beta_sq, t))),
          ),
        ),
      ),
    ),
  )
}

///|
fn inverse_laplace_reciprocal_sqrt_sqrt_linear_shifted_linear_term(
  ctx : LaplaceIrrationalContext,
  t : Expr,
) -> Expr? {
  if laplace_irrational_den_factors(ctx).length() != 3 {
    return None
  }
  let infos = laplace_irrational_den_factor_infos(ctx)
  let mut alpha : Expr? = None
  let mut shifted_sqrt_scale : Expr? = None
  let mut beta_sq : Expr? = None
  let mut linear_coeff : Expr? = None
  let mut root_scale : Expr? = None
  for info in infos {
    match info.scaled_sqrt_linear_plus_const {
      Some((scale, parsed_const)) =>
        if !expr_is_zero(scale) && alpha is None {
          shifted_sqrt_scale = Some(scale)
          alpha = Some(expr_simplify(expr_div(parsed_const, scale)))
        } else {
          return None
        }
      None =>
        match info.sqrt_affine {
          Some((scale, offset)) =>
            if expr_is_zero(offset) &&
              !expr_is_zero(scale) &&
              root_scale is None {
              root_scale = Some(scale)
            } else {
              return None
            }
          None =>
            match info.sqrt_linear {
              Some(scale) =>
                if !expr_is_zero(scale) && root_scale is None {
                  root_scale = Some(expr_pow(scale, @symcore.int(2)))
                } else {
                  return None
                }
              _ =>
                match info.linear {
                  Some((coeff, offset, 1)) =>
                    if !expr_is_zero(coeff) && linear_coeff is None {
                      linear_coeff = Some(coeff)
                      beta_sq = Some(
                        expr_simplify(
                          expr_div(expr_mul(@symcore.int(-1), offset), coeff),
                        ),
                      )
                    } else {
                      return None
                    }
                  _ => return None
                }
            }
        }
    }
  }
  let parsed_alpha = match alpha {
    Some(v) => v
    _ => return None
  }
  let parsed_shifted_sqrt_scale = match shifted_sqrt_scale {
    Some(v) if !expr_is_zero(v) => v
    _ => return None
  }
  let parsed_beta_sq = match beta_sq {
    Some(v) => if expr_is_zero(v) { return None } else { v }
    None => return None
  }
  let parsed_linear_coeff = match linear_coeff {
    Some(v) if !expr_is_zero(v) => v
    _ => return None
  }
  let parsed_root_scale = match root_scale {
    Some(v) => if expr_is_zero(v) { return None } else { v }
    None => return None
  }
  let parsed_alpha_sq = expr_simplify(expr_mul(parsed_alpha, parsed_alpha))
  let parsed_beta = preferred_positive_sqrt(parsed_beta_sq)
  let diff = expr_simplify(expr_sub(parsed_alpha_sq, parsed_beta_sq))
  if expr_is_zero(diff) {
    return None
  }
  let scale_factor = expr_simplify(
    expr_div(
      ctx.numerator,
      expr_mul(
        parsed_linear_coeff,
        expr_mul(
          parsed_shifted_sqrt_scale,
          expr_mul(
            preferred_positive_sqrt(parsed_root_scale),
            expr_mul(diff, parsed_beta),
          ),
        ),
      ),
    ),
  )
  let sqrt_t = @symelem.sqrt(t)
  Some(
    expr_mul(
      scale_factor,
      inverse_laplace_heaviside(
        t,
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
            @symcore.int(-1),
            expr_mul(parsed_beta, @symelem.exp(expr_mul(parsed_beta_sq, t))),
          ),
        ),
      ),
    ),
  )
}

///|
fn inverse_laplace_shifted_sqrt_over_linear_term(
  ctx : LaplaceIrrationalContext,
  t : Expr,
) -> Expr? {
  let (num_scale, num_offset) = match
    parse_sqrt_affine(ctx.numerator, ctx.s_name) {
    Some(v) => v
    None => return None
  }
  if expr_is_zero(num_scale) {
    return None
  }
  match split_linear_power_denom(ctx.den, ctx.s_name) {
    Some((coeff, offset, 1)) => {
      if expr_is_zero(coeff) ||
        expr_depends_on(coeff, ctx.s_name) ||
        expr_depends_on(offset, ctx.s_name) {
        return None
      }
      let normalized_num_offset = expr_simplify(expr_div(num_offset, num_scale))
      let normalized_den_offset = expr_simplify(expr_div(offset, coeff))
      let diff = expr_simplify(
        expr_sub(normalized_num_offset, normalized_den_offset),
      )
      let sqrt_t = @symelem.sqrt(t)
      let front = expr_div(preferred_positive_sqrt(num_scale), coeff)
      let first = expr_mul(
        @symelem.exp(
          expr_mul(@symcore.int(-1), expr_mul(normalized_num_offset, t)),
        ),
        expr_div(@symcore.int(1), expr_mul(sqrt_pi(), sqrt_t)),
      )
      let second = expr_mul(
        preferred_positive_sqrt(diff),
        expr_mul(
          @symelem.exp(
            expr_mul(@symcore.int(-1), expr_mul(normalized_den_offset, t)),
          ),
          @symspec.erf(expr_mul(preferred_positive_sqrt(diff), sqrt_t)),
        ),
      )
      Some(
        expr_mul(front, inverse_laplace_heaviside(t, expr_add(first, second))),
      )
    }
    _ => None
  }
}

///|
fn inverse_laplace_sqrt_linear_power_term(
  ctx : LaplaceIrrationalContext,
  t : Expr,
) -> Expr? {
  match parse_scaled_sqrt_linear_plus_const_power(ctx.den, ctx.s_name) {
    Some((scale, constant, 2)) =>
      if ctx.unit_numerator && !expr_is_zero(scale) {
        let normalized = expr_simplify(expr_div(constant, scale))
        if laplace_source_positive(normalized) {
          return match
            inverse_laplace_sqrt_linear_squared_family(normalized, t) {
            Some(value) =>
              Some(
                expr_simplify(
                  expr_mul(expr_pow(scale, @symcore.int(-2)), value),
                ),
              )
            None => None
          }
        }
      }
    Some((scale, constant, 3)) =>
      if ctx.unit_numerator && !expr_is_zero(scale) {
        let normalized = expr_simplify(expr_div(constant, scale))
        if laplace_source_positive(normalized) {
          return match inverse_laplace_sqrt_linear_cubed_family(normalized, t) {
            Some(value) =>
              Some(
                expr_simplify(
                  expr_mul(expr_pow(scale, @symcore.int(-3)), value),
                ),
              )
            None => None
          }
        }
      }
    Some((scale, constant, 4)) =>
      if !expr_is_zero(scale) && !expr_depends_on(ctx.numerator, ctx.s_name) {
        let normalized = expr_simplify(expr_div(constant, scale))
        if laplace_source_positive(normalized) {
          return match
            inverse_laplace_sqrt_linear_quartic_family(normalized, t) {
            Some(value) =>
              Some(
                expr_simplify(
                  expr_mul(
                    ctx.numerator,
                    expr_mul(expr_pow(scale, @symcore.int(-4)), value),
                  ),
                ),
              )
            None => None
          }
        }
      }
    _ => ()
  }
  match parse_scaled_sqrt_linear_plus_const_power(ctx.den, ctx.s_name) {
    Some((scale, constant, 3)) if !expr_is_zero(scale) =>
      match inverse_laplace_sqrt_s_numerator_coeff(ctx.numerator, ctx.s_name) {
        Some(num_coeff) =>
          return inverse_laplace_scaled_sqrt_over_sqrt_linear_cubed_family(
            num_coeff, scale, constant, t,
          )
        _ => ()
      }
    _ => ()
  }
  if laplace_irrational_den_factors(ctx).length() != 2 {
    return None
  }
  let infos = laplace_irrational_den_factor_infos(ctx)
  let mut power_info : (Expr, Expr, Int)? = None
  let mut linear_coeff : Expr? = None
  let mut root_scale : Expr? = None
  for info in infos {
    match info.scaled_sqrt_linear_plus_const_power {
      Some((scale, constant, power)) =>
        if !expr_is_zero(scale) && power_info is None {
          power_info = Some((scale, constant, power))
        } else {
          return None
        }
      None =>
        match info.linear {
          Some((coeff, offset, 1)) =>
            if expr_is_zero(offset) && linear_coeff is None {
              linear_coeff = Some(coeff)
            } else {
              return None
            }
          _ =>
            match info.sqrt_affine {
              Some((scale, offset)) =>
                if expr_is_zero(offset) &&
                  !expr_is_zero(scale) &&
                  root_scale is None {
                  root_scale = Some(scale)
                } else {
                  return None
                }
              _ =>
                match info.sqrt_linear {
                  Some(scale) =>
                    if !expr_is_zero(scale) && root_scale is None {
                      root_scale = Some(scale)
                    } else {
                      return None
                    }
                  _ => return None
                }
            }
        }
    }
  }
  match power_info {
    Some((scale, constant, 2)) => {
      let normalized = expr_simplify(expr_div(constant, scale))
      match linear_coeff {
        Some(parsed_linear_coeff) if !expr_is_zero(parsed_linear_coeff) => {
          let denominator_scale = expr_mul(
            parsed_linear_coeff,
            expr_pow(scale, @symcore.int(2)),
          )
          let scaled_value = fn(value : Expr, numerator_scale : Expr) -> Expr {
            expr_simplify(
              expr_mul(expr_div(numerator_scale, denominator_scale), value),
            )
          }
          let ratio_value = match
            parse_scaled_sqrt_linear_plus_const_power(ctx.numerator, ctx.s_name) {
            Some((num_scale, num_const, 2)) =>
              if expr_same_simplified(
                  expr_div(num_const, num_scale),
                  expr_mul(@symcore.int(-1), normalized),
                ) {
                Some(
                  scaled_value(
                    inverse_laplace_scaled_sqrt_ratio_squared_family(
                      normalized, t,
                    ).unwrap(),
                    expr_pow(num_scale, @symcore.int(2)),
                  ),
                )
              } else {
                None
              }
            Some((num_scale, num_const, 3)) =>
              if expr_same_simplified(
                  expr_div(num_const, num_scale),
                  expr_mul(@symcore.int(-1), normalized),
                ) {
                Some(
                  scaled_value(
                    inverse_laplace_scaled_sqrt_ratio_cubed_family(
                      normalized, t,
                    ).unwrap(),
                    expr_pow(num_scale, @symcore.int(3)),
                  ),
                )
              } else {
                None
              }
            _ => None
          }
          match ratio_value {
            Some(v) => Some(v)
            None =>
              if !expr_depends_on(ctx.numerator, ctx.s_name) {
                Some(
                  scaled_value(
                    inverse_laplace_sqrt_linear_squared_over_s_family(
                      normalized, t,
                    ).unwrap(),
                    ctx.numerator,
                  ),
                )
              } else {
                None
              }
          }
        }
        _ =>
          match root_scale {
            Some(parsed_root_scale) if !expr_is_zero(parsed_root_scale) &&
              !expr_depends_on(ctx.numerator, ctx.s_name) =>
              Some(
                expr_simplify(
                  expr_mul(
                    expr_div(
                      ctx.numerator,
                      expr_mul(
                        preferred_positive_sqrt(parsed_root_scale),
                        expr_pow(scale, @symcore.int(2)),
                      ),
                    ),
                    inverse_laplace_sqrt_linear_squared_over_sqrt_family(
                      normalized, t,
                    ).unwrap(),
                  ),
                ),
              )
            _ => None
          }
      }
    }
    Some((scale, constant, 3)) => {
      let normalized = expr_simplify(expr_div(constant, scale))
      match linear_coeff {
        Some(parsed_linear_coeff) if !expr_is_zero(parsed_linear_coeff) =>
          match
            parse_scaled_sqrt_linear_plus_const_power(ctx.numerator, ctx.s_name) {
            Some((num_scale, num_const, 3)) =>
              if expr_same_simplified(
                  expr_div(num_const, num_scale),
                  expr_mul(@symcore.int(-1), normalized),
                ) {
                Some(
                  expr_simplify(
                    expr_mul(
                      expr_div(
                        expr_pow(num_scale, @symcore.int(3)),
                        expr_mul(
                          parsed_linear_coeff,
                          expr_pow(scale, @symcore.int(3)),
                        ),
                      ),
                      inverse_laplace_scaled_sqrt_ratio_cubed_family(
                        normalized, t,
                      ).unwrap(),
                    ),
                  ),
                )
              } else {
                None
              }
            _ => None
          }
        _ =>
          match root_scale {
            Some(parsed_root_scale) if !expr_is_zero(parsed_root_scale) &&
              !expr_depends_on(ctx.numerator, ctx.s_name) =>
              Some(
                expr_simplify(
                  expr_mul(
                    expr_div(
                      ctx.numerator,
                      expr_mul(
                        preferred_positive_sqrt(parsed_root_scale),
                        scale,
                      ),
                    ),
                    inverse_laplace_sqrt_linear_cubed_over_sqrt_family(
                      constant, t,
                    ).unwrap(),
                  ),
                ),
              )
            _ => None
          }
      }
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
  let c2t = expr_mul(expr_pow(constant, @symcore.int(2)), t)
  Some(
    inverse_laplace_heaviside(
      t,
      expr_add(
        @symcore.int(1),
        expr_add(
          expr_mul(
            expr_sub(@symcore.int(1), expr_mul(@symcore.int(2), c2t)),
            expr_mul(
              expr_add(
                @symspec.erf(expr_mul(constant, sqrt_t)),
                @symcore.int(-1),
              ),
              @symelem.exp(c2t),
            ),
          ),
          expr_mul(
            @symcore.int(-1),
            expr_div(
              expr_mul(@symcore.int(2), expr_mul(constant, sqrt_t)),
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
  let c2t = expr_mul(expr_pow(constant, @symcore.int(2)), t)
  Some(
    inverse_laplace_heaviside(
      t,
      expr_add(
        @symcore.int(1),
        expr_add(
          expr_mul(
            @symcore.int(8),
            expr_mul(
              c2t,
              expr_mul(
                @symelem.exp(c2t),
                @symspec.erfc(expr_mul(constant, sqrt_t)),
              ),
            ),
          ),
          expr_mul(
            @symcore.int(-1),
            expr_div(
              expr_mul(@symcore.int(8), expr_mul(constant, sqrt_t)),
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
  let c2 = expr_pow(constant, @symcore.int(2))
  let c2t = expr_mul(c2, t)
  let e_term = expr_mul(
    @symelem.exp(c2t),
    @symspec.erfc(expr_mul(constant, sqrt_t)),
  )
  Some(
    inverse_laplace_heaviside(
      t,
      expr_add(
        expr_add(
          expr_mul(
            @symcore.int(2),
            expr_mul(
              expr_add(
                expr_mul(
                  @symcore.int(8),
                  expr_mul(
                    expr_pow(c2, @symcore.int(2)),
                    expr_pow(t, @symcore.int(2)),
                  ),
                ),
                expr_add(expr_mul(@symcore.int(8), c2t), @symcore.int(1)),
              ),
              e_term,
            ),
          ),
          expr_mul(
            @symcore.int(-1),
            expr_div(
              expr_mul(
                @symcore.int(8),
                expr_mul(
                  constant,
                  expr_mul(
                    sqrt_t,
                    expr_add(expr_mul(@symcore.int(2), c2t), @symcore.int(1)),
                  ),
                ),
              ),
              sqrt_pi(),
            ),
          ),
        ),
        @symcore.int(-1),
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
  let c2 = expr_pow(constant, @symcore.int(2))
  let c2t = expr_mul(c2, t)
  let e_term = expr_mul(
    @symelem.exp(c2t),
    @symspec.erfc(expr_mul(constant, sqrt_t)),
  )
  Some(
    inverse_laplace_heaviside(
      t,
      expr_add(
        expr_add(
          expr_mul(
            expr_add(
              expr_mul(@symcore.int(2), t),
              expr_mul(@symcore.int(-1), expr_pow(c2, @symcore.int(-1))),
            ),
            e_term,
          ),
          expr_pow(c2, @symcore.int(-1)),
        ),
        expr_mul(
          @symcore.int(-1),
          expr_div(
            expr_mul(@symcore.int(2), sqrt_t),
            expr_mul(sqrt_pi(), constant),
          ),
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
    @symelem.exp(expr_mul(expr_pow(constant, @symcore.int(2)), t)),
    @symspec.erfc(expr_mul(constant, sqrt_t)),
  )
  Some(
    inverse_laplace_heaviside(
      t,
      expr_add(
        expr_mul(
          @symcore.int(-1),
          expr_mul(@symcore.int(2), expr_mul(constant, expr_mul(t, e_term))),
        ),
        expr_div(expr_mul(@symcore.int(2), sqrt_t), sqrt_pi()),
      ),
    ),
  )
}

///|
fn inverse_laplace_sqrt_linear_cubed_family(constant : Expr, t : Expr) -> Expr? {
  let sqrt_t = @symelem.sqrt(t)
  let c2 = expr_pow(constant, @symcore.int(2))
  let c2t = expr_mul(c2, t)
  let e_term = expr_mul(
    @symelem.exp(c2t),
    @symspec.erfc(expr_mul(constant, sqrt_t)),
  )
  Some(
    inverse_laplace_heaviside(
      t,
      expr_add(
        expr_mul(
          @symcore.int(-1),
          expr_mul(
            expr_mul(constant, t),
            expr_mul(
              expr_add(expr_mul(@symcore.int(2), c2t), @symcore.int(3)),
              e_term,
            ),
          ),
        ),
        expr_div(
          expr_mul(
            @symcore.int(2),
            expr_mul(sqrt_t, expr_add(c2t, @symcore.int(1))),
          ),
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
  let c2 = expr_pow(constant, @symcore.int(2))
  let c2t = expr_mul(c2, t)
  let c4 = expr_pow(constant, @symcore.int(4))
  let t2 = expr_pow(t, @symcore.int(2))
  let t2_sqrt_t = expr_mul(t2, sqrt_t)
  let e_term = expr_mul(
    @symelem.exp(c2t),
    @symspec.erfc(expr_mul(constant, sqrt_t)),
  )
  let poly = expr_add(
    expr_add(
      expr_mul(@symcore.int(4), expr_mul(c4, t2)),
      expr_mul(@symcore.int(12), c2t),
    ),
    @symcore.int(3),
  )
  Some(
    inverse_laplace_heaviside(
      t,
      expr_add(
        expr_div(expr_mul(t, expr_mul(poly, e_term)), @symcore.int(3)),
        expr_mul(
          @symcore.int(-1),
          expr_div(
            expr_mul(
              @symcore.int(2),
              expr_mul(
                expr_pow(constant, @symcore.int(3)),
                expr_mul(
                  t2_sqrt_t,
                  expr_add(expr_mul(@symcore.int(2), c2t), @symcore.int(5)),
                ),
              ),
            ),
            expr_mul(@symcore.int(3), sqrt_pi()),
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
  let c2t = expr_mul(expr_pow(constant, @symcore.int(2)), t)
  let e_term = expr_mul(
    @symelem.exp(c2t),
    @symspec.erfc(expr_mul(constant, sqrt_t)),
  )
  let scaled_erfc = expr_sub(
    expr_mul(sqrt_pi(), expr_mul(constant, expr_mul(sqrt_t, e_term))),
    @symcore.int(1),
  )
  Some(
    inverse_laplace_heaviside(
      t,
      expr_div(
        expr_mul(
          sqrt_t,
          expr_add(
            expr_mul(
              expr_add(expr_mul(@symcore.int(2), c2t), @symcore.int(1)),
              scaled_erfc,
            ),
            @symcore.int(1),
          ),
        ),
        expr_mul(sqrt_pi(), constant),
      ),
    ),
  )
}

///|
fn inverse_laplace_sqrt_s_numerator_coeff(
  numerator : Expr,
  s_name : String,
) -> Expr? {
  match parse_sqrt_linear(numerator, s_name) {
    Some(coeff) => Some(coeff)
    None =>
      match parse_sqrt_affine(numerator, s_name) {
        Some((scale, offset)) if expr_is_zero(offset) =>
          Some(preferred_positive_sqrt(scale))
        _ => None
      }
  }
}

///|
fn inverse_laplace_scaled_sqrt_over_sqrt_linear_cubed_family(
  numerator_coeff : Expr,
  scale : Expr,
  constant : Expr,
  t : Expr,
) -> Expr? {
  if expr_is_zero(scale) || expr_is_zero(constant) {
    return None
  }
  let sqrt_t = @symelem.sqrt(t)
  let c2 = expr_pow(constant, @symcore.int(2))
  let c2t = expr_mul(c2, t)
  let c4t2 = expr_mul(
    expr_pow(c2, @symcore.int(2)),
    expr_pow(t, @symcore.int(2)),
  )
  let erfc_poly = expr_add(
    expr_add(expr_mul(@symcore.int(2), c4t2), expr_mul(@symcore.int(5), c2t)),
    @symcore.int(1),
  )
  let erfc_part = expr_div(
    expr_mul(
      erfc_poly,
      expr_mul(@symelem.exp(c2t), @symspec.erfc(expr_mul(constant, sqrt_t))),
    ),
    scale,
  )
  let sqrt_part = expr_div(
    expr_mul(
      @symcore.int(2),
      expr_mul(constant, expr_mul(sqrt_t, expr_add(c2t, @symcore.int(2)))),
    ),
    sqrt_pi(),
  )
  Some(
    inverse_laplace_heaviside(
      t,
      expr_mul(numerator_coeff, expr_sub(erfc_part, sqrt_part)),
    ),
  )
}

///|
fn inverse_laplace_reciprocal_sqrt_times_sqrt_linear_plus_const_term(
  ctx : LaplaceIrrationalContext,
  t : Expr,
) -> Expr? {
  // SymPy's irrational helper gates this Bateman-table shape on positivity,
  // but the inverse-Laplace front door can still evaluate explicit negative
  // constants through the later integration fallback.
  if !ctx.unit_numerator {
    return None
  }
  if laplace_irrational_den_factors(ctx).length() != 2 {
    return None
  }
  let infos = laplace_irrational_den_factor_infos(ctx)
  let mut root_scale : Expr? = None
  let mut shifted_sqrt_scale : Expr? = None
  let mut constant : Expr? = None
  for info in infos {
    match info.sqrt_affine {
      Some((sqrt_scale, offset)) =>
        if expr_is_zero(offset) && root_scale is None {
          root_scale = Some(sqrt_scale)
        } else {
          return None
        }
      None =>
        match info.sqrt_affine_plus_const {
          Some((parsed_scale, offset, parsed_const)) =>
            if expr_is_zero(offset) && shifted_sqrt_scale is None {
              shifted_sqrt_scale = Some(preferred_positive_sqrt(parsed_scale))
              constant = Some(parsed_const)
            } else {
              return None
            }
          None =>
            match info.scaled_sqrt_linear_plus_const {
              Some((parsed_scale, parsed_const)) =>
                if shifted_sqrt_scale is None {
                  shifted_sqrt_scale = Some(parsed_scale)
                  constant = Some(parsed_const)
                } else {
                  return None
                }
              None => return None
            }
        }
    }
  }
  let parsed_root_scale = match root_scale {
    Some(v) if !expr_is_zero(v) => v
    _ => return None
  }
  let parsed_shifted_sqrt_scale = match shifted_sqrt_scale {
    Some(v) if !expr_is_zero(v) => v
    _ => return None
  }
  let parsed_const = match constant {
    Some(v) => v
    None => return None
  }
  let normalized_const = expr_simplify(
    expr_div(parsed_const, parsed_shifted_sqrt_scale),
  )
  let sqrt_root_scale = preferred_positive_sqrt(parsed_root_scale)
  let sqrt_t = @symelem.sqrt(t)
  Some(
    inverse_laplace_heaviside(
      t,
      expr_div(
        expr_mul(
          @symelem.exp(expr_mul(expr_pow(normalized_const, @symcore.int(2)), t)),
          @symspec.erfc(expr_mul(normalized_const, sqrt_t)),
        ),
        expr_mul(parsed_shifted_sqrt_scale, sqrt_root_scale),
      ),
    ),
  )
}

///|
fn inverse_laplace_reciprocal_sqrt_shifted_linear_term(
  ctx : LaplaceIrrationalContext,
  t : Expr,
) -> Expr? {
  if !ctx.unit_numerator {
    return None
  }
  if laplace_irrational_den_factors(ctx).length() != 2 {
    return None
  }
  let infos = laplace_irrational_den_factor_infos(ctx)
  let mut root_scale : Expr? = None
  let mut root_offset : Expr? = None
  let mut linear_coeff : Expr? = None
  let mut linear_offset : Expr? = None
  for info in infos {
    match info.sqrt_affine {
      Some((scale, offset)) =>
        if !expr_is_zero(scale) && root_offset is None {
          root_scale = Some(scale)
          root_offset = Some(offset)
        } else {
          return None
        }
      None =>
        match info.linear {
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
    inverse_laplace_heaviside(
      t,
      expr_mul(
        expr_div(
          @symcore.int(1),
          expr_mul(parsed_linear_coeff, sqrt_root_scale),
        ),
        expr_mul(
          @symelem.exp(
            expr_mul(@symcore.int(-1), expr_mul(normalized_linear_offset, t)),
          ),
          expr_div(@symspec.erf(expr_mul(sqrt_diff, sqrt_t)), sqrt_diff),
        ),
      ),
    ),
  )
}

///|
fn inverse_laplace_reciprocal_sqrt_shifted_over_s_term(
  ctx : LaplaceIrrationalContext,
  t : Expr,
) -> Expr? {
  if !ctx.unit_numerator {
    return None
  }
  if laplace_irrational_den_factors(ctx).length() != 2 {
    return None
  }
  let infos = laplace_irrational_den_factor_infos(ctx)
  let mut root_scale : Expr? = None
  let mut root_offset : Expr? = None
  let mut saw_s = false
  for info in infos {
    match info.sqrt_affine {
      Some((scale, offset)) =>
        if !expr_is_zero(scale) && root_scale is None {
          root_scale = Some(scale)
          root_offset = Some(offset)
        } else {
          return None
        }
      None =>
        match info.linear {
          Some((coeff, offset, 1)) =>
            if expr_same_simplified(coeff, @symcore.int(1)) &&
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
    expr_div(expr_mul(@symcore.int(2), sqrt_t), expr_mul(sqrt_pi(), sqrt_scale))
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
  Some(inverse_laplace_heaviside(t, body))
}

///|
fn inverse_laplace_reciprocal_sqrt_shifted_linear_over_s_term(
  ctx : LaplaceIrrationalContext,
  t : Expr,
) -> Expr? {
  if !ctx.unit_numerator {
    return None
  }
  if laplace_irrational_den_factors(ctx).length() != 3 {
    return None
  }
  let infos = laplace_irrational_den_factor_infos(ctx)
  let mut root_scale : Expr? = None
  let mut zero_linear_coeff : Expr? = None
  let mut linear_coeff : Expr? = None
  let mut linear_offset : Expr? = None
  for info in infos {
    match info.sqrt_affine {
      Some((scale, offset)) =>
        if expr_is_zero(offset) && !expr_is_zero(scale) && root_scale is None {
          root_scale = Some(scale)
        } else {
          return None
        }
      None =>
        match info.linear {
          Some((coeff, offset, 1)) =>
            if expr_is_zero(offset) && zero_linear_coeff is None {
              zero_linear_coeff = Some(coeff)
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
    Some(v) if !expr_is_zero(v) => v
    _ => return None
  }
  let parsed_zero_linear_coeff = match zero_linear_coeff {
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
  let diff = expr_simplify(
    expr_mul(
      @symcore.int(-1),
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
    @symcore.int(-1),
    expr_div(expr_mul(@symcore.int(2), sqrt_t), expr_mul(sqrt_pi(), diff)),
  )
  Some(
    inverse_laplace_heaviside(
      t,
      expr_mul(
        expr_div(
          @symcore.int(1),
          expr_mul(
            parsed_zero_linear_coeff,
            expr_mul(parsed_linear_coeff, sqrt_root_scale),
          ),
        ),
        expr_add(exp_erf_term, sqrt_term),
      ),
    ),
  )
}

///|
fn matches_log_one_plus_linear(expr : Expr, s_name : String) -> Bool {
  match unary_application_arg(expr, "log") {
    Some(inner) =>
      match linear_coeffs(inner, s_name) {
        Some((coeff, offset)) => expr_is_one(coeff) && expr_is_one(offset)
        None => false
      }
    None =>
      match
        retry_with_simplified(expr, expr => unary_application_arg(expr, "log")) {
        Some(inner) =>
          match linear_coeffs(inner, s_name) {
            Some((coeff, offset)) => expr_is_one(coeff) && expr_is_one(offset)
            None => false
          }
        None => false
      }
  }
}

///|
fn parse_scaled_inverse_symbol(expr : Expr, var_name : String) -> Expr? {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  if !expr_eq(den, @symcore.Expr::Symbol(var_name)) {
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
  retry_with_simplified(expr, expr => {
    match expr {
      @symcore.Expr::Pow(@symcore.Expr::Symbol(name), power) if name == var_name =>
        extract_explicit_negative_factor(power)
      _ => None
    }
  })
}

///|
fn parse_general_negative_power_base(expr : Expr) -> (Expr, Expr)? {
  retry_with_simplified(expr, expr => {
    match expr {
      @symcore.Expr::Pow(base, power) =>
        match extract_explicit_negative_factor(power) {
          Some(v) => Some((base, v))
          None => None
        }
      _ => None
    }
  })
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
fn parse_coeff_power_with_order(expr : Expr, order : Expr) -> Expr? {
  retry_with_simplified(expr, expr => {
    match expr {
      @symcore.Expr::Pow(base, exp) if expr_same_simplified(exp, order) =>
        Some(base)
      _ => None
    }
  })
}

///|
fn parse_symbol_plus_sqrt_quadratic_raw(
  expr : Expr,
  var_name : String,
) -> (Expr, Bool)? {
  match expr {
    @symcore.Expr::Add(args) if args.length() == 2 => {
      let mut saw_symbol = false
      let mut kernel_sq : Expr? = None
      let mut is_diff : Bool? = None
      for arg in args {
        if arg == @symcore.Expr::Symbol(var_name) {
          saw_symbol = true
        } else {
          match unary_application_arg(arg, "sqrt") {
            Some(inner) =>
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
            None => return None
          }
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
fn parse_symbol_plus_sqrt_quadratic(
  expr : Expr,
  var_name : String,
) -> (Expr, Bool)? {
  retry_with_simplified(expr, expr => {
    parse_symbol_plus_sqrt_quadratic_raw(expr, var_name)
  })
}

///|
fn make_expr_derivative(expr : Expr, wrt : Expr, order : Int) -> Expr {
  if order <= 0 {
    expr
  } else if order == 1 {
    @symcore.raw_function("Derivative", [expr, wrt])
  } else {
    @symcore.raw_function("Derivative", [expr, wrt, @symcore.int(order)])
  }
}

///|
fn parse_linear_scale_only(expr : Expr, var_name : String) -> Expr? {
  let (coeff, factors) = split_mul(expr, var_name)
  if factors.length() != 1 {
    return None
  }
  match parse_power_factor(factors[0], var_name) {
    Some(power) if expr_is_one(power) => Some(coeff)
    _ => None
  }
}

///|
fn parse_sqrt_affine_raw(expr : Expr, var_name : String) -> (Expr, Expr)? {
  match unary_application_arg(expr, "sqrt") {
    Some(inner) =>
      match split_linear_coeff_direct(inner, var_name) {
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
    None => None
  }
}

///|
fn parse_sqrt_affine(expr : Expr, var_name : String) -> (Expr, Expr)? {
  retry_with_simplified(expr, expr => parse_sqrt_affine_raw(expr, var_name))
}

///|
fn parse_sqrt_affine_plus_const_raw(
  expr : Expr,
  var_name : String,
) -> (Expr, Expr, Expr)? {
  match expr {
    @symcore.Expr::Add(args) if args.length() == 2 => {
      let mut sqrt_scale : Expr? = None
      let mut sqrt_offset : Expr? = None
      let mut constant : Expr? = None
      for arg in args {
        match parse_sqrt_affine_raw(arg, var_name) {
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
fn parse_sqrt_affine_plus_const(
  expr : Expr,
  var_name : String,
) -> (Expr, Expr, Expr)? {
  retry_with_simplified(expr, expr => {
    parse_sqrt_affine_plus_const_raw(expr, var_name)
  })
}

///|
fn parse_scaled_sqrt_linear_plus_const_raw(
  expr : Expr,
  var_name : String,
) -> (Expr, Expr)? {
  match expr {
    @symcore.Expr::Add(args) if args.length() == 2 => {
      let mut scale : Expr? = None
      let mut constant : Expr? = None
      for arg in args {
        match parse_sqrt_linear_raw(arg, var_name) {
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
fn parse_scaled_sqrt_linear_plus_const(
  expr : Expr,
  var_name : String,
) -> (Expr, Expr)? {
  retry_with_simplified(expr, expr => {
    parse_scaled_sqrt_linear_plus_const_raw(expr, var_name)
  })
}

///|
fn parse_scaled_sqrt_linear_plus_const_power(
  expr : Expr,
  var_name : String,
) -> (Expr, Expr, Int)? {
  match parse_scaled_sqrt_linear_plus_const_power_raw(expr, var_name) {
    Some(value) => Some(value)
    None =>
      retry_with_simplified(expr, expr => {
        parse_scaled_sqrt_linear_plus_const_power_raw(expr, var_name)
      })
  }
}

///|
fn parse_scaled_sqrt_linear_plus_const_power_raw(
  expr : Expr,
  var_name : String,
) -> (Expr, Expr, Int)? {
  match expr {
    @symcore.Expr::Pow(base, exp) =>
      match expr_is_int_value(exp) {
        Some(power) if power > 0 =>
          match parse_scaled_sqrt_linear_plus_const_raw(base, var_name) {
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
fn inverse_laplace_positive_time_shift_object_term(
  expr : Expr,
  s_name : String,
  t : Expr,
) -> Expr? {
  if inverse_laplace_has_nonnegative_time_shift_exp(expr, s_name) {
    Some(make_inverse_laplace_object(expr, s_name, t))
  } else {
    None
  }
}

///|
fn inverse_laplace_has_nonnegative_time_shift_exp(
  expr : Expr,
  s_name : String,
) -> Bool {
  match unary_application_arg(expr, "exp") {
    Some(inner) =>
      match linear_coeffs(inner, s_name) {
        Some((coeff, _)) if expr_depends_on(coeff, s_name) => false
        Some((coeff, offset)) =>
          expr_is_zero(offset) &&
          !expr_is_zero(coeff) &&
          !expr_is_negative(coeff)
        None => false
      }
    None =>
      match expr {
        @symcore.Expr::Mul(args) => {
          let mut seen = false
          for arg in args {
            match unary_application_arg(arg, "exp") {
              Some(inner) =>
                match linear_coeffs(inner, s_name) {
                  Some((coeff, _)) if expr_depends_on(coeff, s_name) =>
                    return false
                  Some((coeff, offset)) =>
                    if expr_is_zero(coeff) {
                      ()
                    } else if !expr_is_zero(offset) {
                      return false
                    } else if expr_is_negative(coeff) {
                      return false
                    } else if seen {
                      return false
                    } else {
                      seen = true
                    }
                  None => ()
                }
              None => ()
            }
          }
          seen
        }
        _ => false
      }
  }
}

///|
fn inverse_laplace_delay_term(expr : Expr, s_name : String, t : Expr) -> Expr? {
  let t_name = match symbol_name(t) {
    Some(v) => v
    None => return None
  }
  let factors = match expr {
    @symcore.Expr::Mul(args) => args
    _ if unary_application_arg(expr, "exp") is Some(_) => [expr]
    _ =>
      match expr_simplify(expr) {
        @symcore.Expr::Mul(args) => args
        simplified if unary_application_arg(simplified, "exp") is Some(_) =>
          [simplified]
        _ => return None
      }
  }
  if factors.length() == 0 {
    return None
  }
  let mut delay : Expr? = None
  let mut exp_const = @symcore.int(0)
  let rest : Array[Expr] = []
  for factor in factors {
    match unary_application_arg(factor, "exp") {
      Some(inner) =>
        match linear_coeffs(inner, s_name) {
          Some((coeff, offset)) =>
            if expr_is_negative(coeff) {
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
            } else {
              rest.push(factor)
            }
          _ => rest.push(factor)
        }
      None => rest.push(factor)
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
  match inverse_laplace_linear_power_no_var_direct(coeff, den, t, s_name) {
    Some(v) => return Some(v)
    None => ()
  }
  match
    inverse_laplace_shifted_diff_square_power(
      @symcore.int(0),
      coeff,
      den,
      t,
      s_name,
    ) {
    Some(v) => Some(v)
    None =>
      match
        inverse_laplace_shifted_square_power(
          @symcore.int(0),
          coeff,
          den,
          t,
          s_name,
        ) {
        Some(v) => Some(v)
        None =>
          match
            inverse_laplace_quadratic_power(
              @symcore.int(0),
              coeff,
              den,
              t,
              s_name,
            ) {
            Some(v) => Some(v)
            None =>
              match
                inverse_laplace_quadratic_repeated_root_term(
                  @symcore.int(0),
                  coeff,
                  den,
                  t,
                  s_name,
                ) {
                Some(v) => Some(v)
                None =>
                  match
                    inverse_laplace_two_linear_factors(
                      @symcore.int(0),
                      coeff,
                      den,
                      t,
                      s_name,
                    ) {
                    Some(v) => Some(v)
                    None =>
                      match
                        inverse_laplace_shifted_diff_square_term(
                          @symcore.int(0),
                          coeff,
                          den,
                          t,
                          s_name,
                        ) {
                        Some(v) => Some(v)
                        None =>
                          match
                            inverse_laplace_shifted_square_term(
                              @symcore.int(0),
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
                                    inverse_laplace_heaviside(
                                      t,
                                      expr_mul(
                                        expr_div(coeff, freq),
                                        @symelem.sinh(expr_mul(freq, t)),
                                      ),
                                    ),
                                  )
                                None =>
                                  inverse_laplace_linear_power_no_var(
                                    coeff, den, t, s_name,
                                  )
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
fn inverse_laplace_linear_power_no_var_direct(
  coeff : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  match split_linear_power_denom_direct(den, s_name) {
    Some((a, b, power)) =>
      inverse_laplace_linear_power_no_var_from_parts(coeff, a, b, power, t)
    None => None
  }
}

///|
fn inverse_laplace_linear_power_no_var(
  coeff : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  match split_linear_power_denom(den, s_name) {
    Some((a, b, power)) =>
      inverse_laplace_linear_power_no_var_from_parts(coeff, a, b, power, t)
    None => None
  }
}

///|
fn inverse_laplace_linear_power_no_var_from_parts(
  coeff : Expr,
  a : Expr,
  b : Expr,
  power : Int,
  t : Expr,
) -> Expr? {
  if expr_is_zero(a) {
    None
  } else {
    let scale = expr_div(
      coeff,
      expr_mul(
        expr_pow(a, @symcore.int(power)),
        factorial_expr(@symcore.int(power - 1)),
      ),
    )
    let tpow = if power == 1 {
      @symcore.int(1)
    } else {
      expr_pow(t, @symcore.int(power - 1))
    }
    Some(
      inverse_laplace_heaviside(
        t,
        expr_mul(
          expr_mul(scale, tpow),
          @symelem.exp(expr_mul(expr_div(@symcore.int(-1), a), expr_mul(b, t))),
        ),
      ),
    )
  }
}

///|
fn inverse_laplace_linear_power_with_var(
  num_linear : Expr,
  num_const : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  let (a, b, power) = match split_linear_power_denom(den, s_name) {
    Some(value) => value
    None => return None
  }
  if expr_is_zero(a) {
    return None
  }
  let quotient_coeff = expr_div(num_linear, a)
  let residual_const = expr_sub(num_const, expr_mul(quotient_coeff, b))
  let residual_part = inverse_laplace_linear_power_no_var(
    residual_const, den, t, s_name,
  )
  let quotient_part = if power == 1 {
    Some(expr_mul(quotient_coeff, @symspec.dirac_delta(t)))
  } else {
    let linear_base = expr_add(expr_mul(a, @symcore.Expr::Symbol(s_name)), b)
    let reduced_den = if power == 2 {
      linear_base
    } else {
      expr_pow(linear_base, @symcore.int(power - 1))
    }
    inverse_laplace_linear_power_no_var(quotient_coeff, reduced_den, t, s_name)
  }
  match (quotient_part, residual_part) {
    (Some(left), Some(right)) => Some(expr_add(left, right))
    _ => None
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
        inverse_laplace_linear_power_with_var(
          num_linear, num_const, den, t, s_name,
        ) {
        Some(v) => return Some(v)
        None => ()
      }
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
                    inverse_laplace_quadratic_repeated_root_term(
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
                                        inverse_laplace_heaviside(
                                          t,
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
    }
    None => None
  }
}

///|
fn inverse_laplace_quadratic_repeated_root_term(
  num_linear : Expr,
  num_const : Expr,
  den : Expr,
  t : Expr,
  s_name : String,
) -> Expr? {
  match split_quadratic_repeated_root_denom(den, s_name) {
    Some((lead, shift)) => {
      let l = expr_div(num_linear, lead)
      let m = expr_div(num_const, lead)
      Some(
        inverse_laplace_heaviside(
          t,
          expr_mul(
            expr_add(
              expr_mul(m, t),
              expr_mul(l, expr_sub(@symcore.int(1), expr_mul(shift, t))),
            ),
            @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(shift, t))),
          ),
        ),
      )
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
          @symcore.int(0)
        } else {
          expr_mul(num_linear, @symelem.cosh(expr_mul(freq, t)))
        }
        let sinh_part = if expr_is_zero(centered_const) {
          @symcore.int(0)
        } else {
          expr_mul(
            inverse_laplace_div_by_quadratic_freq(centered_const, freq),
            @symelem.sinh(expr_mul(freq, t)),
          )
        }
        Some(
          inverse_laplace_heaviside(
            t,
            expr_mul(
              expr_mul(
                expr_div(@symcore.int(1), lead),
                @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(shift, t))),
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
          @symcore.int(0)
        } else {
          expr_mul(num_linear, @symelem.cos(expr_mul(freq, t)))
        }
        let sin_part = if expr_is_zero(centered_const) {
          @symcore.int(0)
        } else {
          expr_mul(
            inverse_laplace_div_by_quadratic_freq(centered_const, freq),
            @symelem.sin(expr_mul(freq, t)),
          )
        }
        Some(
          inverse_laplace_heaviside(
            t,
            expr_mul(
              expr_mul(
                expr_div(@symcore.int(1), lead),
                @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(shift, t))),
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
fn inverse_laplace_div_by_quadratic_freq(numer : Expr, freq : Expr) -> Expr {
  match @symcore.application_parts(freq) {
    Some((head, [inner])) if @symcore.function_head_name(head) == Some("sqrt") =>
      if expr_same_simplified(numer, inner) {
        return freq
      } else if expr_same_simplified(numer, expr_mul(@symcore.int(-1), inner)) {
        return expr_mul(@symcore.int(-1), freq)
      }
    _ => ()
  }
  let freq_sq = expr_simplify(expr_pow(freq, @symcore.int(2)))
  if expr_same_simplified(numer, freq_sq) {
    freq
  } else if expr_same_simplified(numer, expr_mul(@symcore.int(-1), freq_sq)) {
    expr_mul(@symcore.int(-1), freq)
  } else {
    expr_simplify(expr_div(numer, freq))
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
      let lead_scale = expr_pow(lead, @symcore.int(2))
      let centered_const = expr_sub(num_const, expr_mul(num_linear, shift))
      let const_part = if expr_is_zero(centered_const) {
        @symcore.int(0)
      } else {
        expr_mul(
          expr_div(
            centered_const,
            expr_mul(
              @symcore.int(2),
              expr_mul(lead_scale, expr_pow(freq, @symcore.int(3))),
            ),
          ),
          expr_sub(
            expr_mul(expr_mul(freq, t), @symelem.cosh(expr_mul(freq, t))),
            @symelem.sinh(expr_mul(freq, t)),
          ),
        )
      }
      let linear_part = if expr_is_zero(num_linear) {
        @symcore.int(0)
      } else {
        expr_mul(
          expr_div(
            num_linear,
            expr_mul(@symcore.int(2), expr_mul(lead_scale, freq)),
          ),
          expr_mul(t, @symelem.sinh(expr_mul(freq, t))),
        )
      }
      Some(
        inverse_laplace_heaviside(
          t,
          expr_mul(
            @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(shift, t))),
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
      let lead_scale = expr_pow(lead, @symcore.int(2))
      let centered_const = expr_sub(num_const, expr_mul(num_linear, shift))
      let const_part = if expr_is_zero(centered_const) {
        @symcore.int(0)
      } else {
        expr_mul(
          expr_div(
            centered_const,
            expr_mul(
              @symcore.int(2),
              expr_mul(lead_scale, expr_pow(freq, @symcore.int(3))),
            ),
          ),
          expr_sub(
            @symelem.sin(expr_mul(freq, t)),
            expr_mul(expr_mul(freq, t), @symelem.cos(expr_mul(freq, t))),
          ),
        )
      }
      let linear_part = if expr_is_zero(num_linear) {
        @symcore.int(0)
      } else {
        expr_mul(
          expr_div(
            num_linear,
            expr_mul(@symcore.int(2), expr_mul(lead_scale, freq)),
          ),
          expr_mul(t, @symelem.sin(expr_mul(freq, t))),
        )
      }
      Some(
        inverse_laplace_heaviside(
          t,
          expr_mul(
            @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(shift, t))),
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
      let lead_scale = expr_pow(lead, @symcore.int(2))
      let const_part = if expr_is_zero(num_const) {
        @symcore.int(0)
      } else if is_diff {
        expr_mul(
          expr_div(
            num_const,
            expr_mul(
              @symcore.int(2),
              expr_mul(lead_scale, expr_pow(freq, @symcore.int(3))),
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
              @symcore.int(2),
              expr_mul(lead_scale, expr_pow(freq, @symcore.int(3))),
            ),
          ),
          expr_sub(
            @symelem.sin(expr_mul(freq, t)),
            expr_mul(freq * t, @symelem.cos(expr_mul(freq, t))),
          ),
        )
      }
      let linear_part = if expr_is_zero(num_linear) {
        @symcore.int(0)
      } else if is_diff {
        expr_mul(
          expr_div(
            num_linear,
            expr_mul(@symcore.int(2), expr_mul(lead_scale, freq)),
          ),
          expr_mul(t, @symelem.sinh(expr_mul(freq, t))),
        )
      } else {
        expr_mul(
          expr_div(
            num_linear,
            expr_mul(@symcore.int(2), expr_mul(lead_scale, freq)),
          ),
          expr_mul(t, @symelem.sin(expr_mul(freq, t))),
        )
      }
      Some(inverse_laplace_heaviside(t, expr_add(const_part, linear_part)))
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
          inverse_laplace_heaviside(
            t,
            expr_add(
              expr_mul(
                expr_div(left_coeff, a1),
                @symelem.exp(
                  expr_mul(expr_div(@symcore.int(-1), a1), expr_mul(b1, t)),
                ),
              ),
              expr_mul(
                expr_div(right_coeff, a2),
                @symelem.exp(
                  expr_mul(expr_div(@symcore.int(-1), a2), expr_mul(b2, t)),
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
/// Apply the forward Fourier rule table.
///
/// - Does: Evaluates a forward Fourier transform when a local closed form is available.
/// - Input: One source `Expr`, one space variable `x`, and one frequency variable `k`.
/// - Returns: `Some(Expr)` for a computed transform or `None`.
/// - Limits: Unsupported cases return `None`.
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
  match unary_application_arg(expr, "Heaviside") {
    Some(arg) =>
      match parse_one_minus_abs_linear(arg, x_name) {
        Some(scale) =>
          Some(
            expr_div(
              @symelem.sin(
                expr_div(
                  expr_mul(
                    @symcore.int(2),
                    expr_mul(
                      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                      k,
                    ),
                  ),
                  scale,
                ),
              ),
              expr_mul(
                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                k,
              ),
            ),
          )
        None => None
      }
    None =>
      match unary_application_arg(expr, "exp") {
        Some(inner) =>
          match parse_negative_abs_linear(inner, x_name) {
            Some(a) =>
              Some(
                expr_div(
                  expr_mul(@symcore.int(2), a),
                  expr_add(
                    expr_pow(a, @symcore.int(2)),
                    expr_mul(
                      @symcore.int(4),
                      expr_mul(
                        expr_pow(
                          @symcore.Expr::NumberSymbol(
                            @symcore.NumberSymbolKind::Pi,
                          ),
                          @symcore.int(2),
                        ),
                        expr_pow(k, @symcore.int(2)),
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
                        fourier_gaussian_exponent(
                          scale, linear, constant, k, false,
                        ),
                      ),
                    ),
                  )
                None => None
              }
          }
        None => None
      }
  }
}

///|
/// Apply the inverse Fourier rule table.
///
/// - Does: Evaluates an inverse Fourier transform when a local closed form is available.
/// - Input: One source `Expr`, one frequency variable `k`, and one space variable `x`.
/// - Returns: `Some(Expr)` for a computed transform or `None`.
/// - Limits: Unsupported cases return `None`.
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
        match unary_application_arg(factors[0], "exp") {
          Some(inner) =>
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
          None => None
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
            (@symcore.int(1) - @symelem.abs(expr_mul(scale, x))),
          )
        None => None
      }
  }
}

///|
fn inverse_fourier_box_window(scale : Expr, x : Expr) -> Expr {
  @symspec.heaviside(@symcore.int(1) - @symelem.abs(expr_mul(scale, x)))
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
    @symcore.int(1)
  } else if num.length() == 1 {
    num[0]
  } else {
    expr_simplify(@symcore.mul(num))
  }
  let heaviside = @symspec.heaviside(x)
  match parse_inverse_fourier_abs_decay_rate(numerator, den, k_name) {
    Some(a) =>
      return Some(
        @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(a, @symelem.abs(x)))),
      )
    _ => ()
  }
  match parse_fourier_shift_power(den, k_name) {
    Some((a, 1)) if expr_is_one(numerator) =>
      Some(heaviside * @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(a, x))))
    Some((a, 2)) if expr_is_one(numerator) =>
      Some(
        heaviside * x * @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(a, x))),
      )
    _ =>
      match parse_fourier_shifted_sine_denominator(den, k_name) {
        Some((a, b)) if expr_eq(numerator, b) =>
          Some(
            heaviside *
            @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(a, x))) *
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
  let mut power = @symcore.int(0)
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
    match unary_application_arg(factor, "exp") {
      Some(inner) =>
        match parse_negative_linear_exp_raw(inner, x_name) {
          Some(a) =>
            if exp_rate is None {
              exp_rate = Some(a)
            } else {
              return None
            }
          None => return None
        }
      None =>
        match unary_application_arg(factor, "Heaviside") {
          Some(arg) =>
            match parse_heaviside_limit(arg, x_name) {
              Some((bound, is_le)) if expr_is_zero(bound) && !is_le =>
                saw_heaviside = true
              _ => return None
            }
          None =>
            match unary_application_arg(factor, "sin") {
              Some(inner) =>
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
              None => return None
            }
        }
    }
  }
  if !saw_heaviside || exp_rate is None {
    return None
  }
  let a = exp_rate.unwrap()
  let shift = fourier_linear_shift(a, k)
  match (expr_is_zero(power), expr_eq(power, @symcore.int(1)), sine_rate) {
    (true, _, None) => Some(expr_pow(shift, @symcore.int(-1)))
    (_, true, None) => Some(expr_pow(shift, @symcore.int(-2)))
    (true, _, Some(b)) =>
      Some(
        expr_div(
          b,
          expr_add(
            expr_pow(b, @symcore.int(2)),
            expr_pow(shift, @symcore.int(2)),
          ),
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
    match unary_application_arg(factor, "Heaviside") {
      Some(arg) =>
        match parse_one_minus_abs_linear(arg, x_name) {
          Some(scale) => box_scale = Some(scale)
          None => return None
        }
      None =>
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
              @symelem.sin(
                expr_div(
                  expr_mul(
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                    k,
                  ),
                  c1,
                ),
              ),
              @symcore.int(2),
            ),
          ),
          expr_mul(
            expr_pow(
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
              @symcore.int(2),
            ),
            expr_pow(k, @symcore.int(2)),
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
      @symcore.int(2),
      expr_mul(
        expr_mul(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
        ),
        k,
      ),
    ),
  )
}

///|
fn fourier_linear_shift_coeff() -> Expr {
  expr_mul(
    @symcore.int(2),
    expr_mul(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
    ),
  )
}

///|
fn parse_fourier_linear_shift(expr : Expr, k_name : String) -> Expr? {
  match linear_coeffs(expr, k_name) {
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
  retry_with_simplified(expr, expr => {
    match expr {
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
  })
}

///|
fn parse_fourier_shifted_sine_denominator(
  expr : Expr,
  k_name : String,
) -> (Expr, Expr)? {
  retry_with_simplified(expr, expr => {
    match expr {
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
  })
}

///|
fn parse_inverse_fourier_abs_decay_rate(
  numerator : Expr,
  den : Expr,
  k_name : String,
) -> Expr? {
  match poly_coeffs_upto2(den, k_name) {
    Some(coeffs) =>
      if expr_is_zero(coeffs[1]) &&
        !expr_depends_on(coeffs[0], k_name) &&
        !expr_depends_on(coeffs[2], k_name) &&
        !expr_is_zero(coeffs[2]) {
        let quad_base = expr_mul(
          @symcore.int(4),
          expr_pow(
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
            @symcore.int(2),
          ),
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
              expr_mul(scale, expr_mul(@symcore.int(2), rate)),
            )
            if expr_same_simplified(numerator, expected_num) {
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
      if !expr_eq(
          coeff,
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        ) ||
        !expr_is_zero(offset) {
        return None
      }
    _ => return None
  }
  match unary_application_arg(num[0], "sin") {
    Some(arg) =>
      match linear_coeffs(arg, k_name) {
        Some((coeff, offset)) if expr_is_zero(offset) =>
          Some(
            expr_simplify(
              expr_div(
                expr_mul(
                  @symcore.int(2),
                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                ),
                coeff,
              ),
            ),
          )
        _ => None
      }
    None => None
  }
}

///|
fn parse_inverse_fourier_box_sinc_scale(expr : Expr, k_name : String) -> Expr? {
  let (coeff, factors) = split_mul(expr, k_name)
  if factors.length() != 1 {
    return None
  }
  match unary_application_arg(factors[0], "sinc") {
    Some(arg) =>
      match parse_scaled_symbol(arg, k_name) {
        Some(freq) =>
          match inverse_fourier_sinc_scale(coeff, freq, 2) {
            Some(scale) => Some(scale)
            None => None
          }
        None => None
      }
    None => None
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
      @symcore.Expr::Pow(base, exp) if expr_eq(exp, @symcore.int(-1)) =>
        match poly_coeffs_upto2(base, k_name) {
          Some(coeffs) =>
            if expr_is_zero(coeffs[0]) &&
              expr_is_zero(coeffs[1]) &&
              expr_eq(
                coeffs[2],
                expr_pow(
                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                  @symcore.int(2),
                ),
              ) {
              den_ok = true
            } else {
              return None
            }
          _ => return None
        }
      _ =>
        match pow_named_unary_application(factor) {
          Some(("sin", arg, exp)) if expr_eq(exp, @symcore.int(2)) =>
            match linear_coeffs(arg, k_name) {
              Some((freq, offset)) if expr_is_zero(offset) =>
                if expr_eq(
                    expr_simplify(expr_mul(coeff, freq)),
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
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
  match pow_named_unary_application(factors[0]) {
    Some(("sinc", arg, exp)) if expr_eq(exp, @symcore.int(2)) =>
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
  let ratio = expr_simplify(expr_mul(coeff, expr_pow(freq, @symcore.int(-1))))
  if expr_eq(ratio, @symcore.int(1)) || expr_eq(ratio, @symcore.int(-1)) {
    Some(expr_simplify(expr_div(@symcore.int(width), freq)))
  } else {
    None
  }
}

///|
fn parse_scaled_symbol(expr : Expr, var_name : String) -> Expr? {
  retry_with_simplified(expr, expr => {
    match expr {
      @symcore.Expr::Symbol(name) =>
        if name == var_name {
          Some(@symcore.int(1))
        } else {
          None
        }
      @symcore.Expr::Mul(args) => {
        let mut coeff = @symcore.int(1)
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
  })
}

///|
/// Apply the forward sine-transform rule table.
///
/// - Does: Evaluates a forward sine transform when a local closed form is available.
/// - Input: One source `Expr`, one space variable `x`, and one frequency variable `k`.
/// - Returns: `Some(Expr)` for a computed transform or `None`.
/// - Limits: Unsupported cases return `None`.
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
  let mut x_pow = @symcore.int(0)
  for factor in factors {
    match parse_power_factor(factor, x_name) {
      Some(power) => x_pow = expr_add(x_pow, power)
      None =>
        match unary_application_arg(factor, "exp") {
          Some(inner) =>
            match parse_negative_quadratic_exp(inner, x_name) {
              Some(scale) =>
                if exp_quad is None {
                  exp_quad = Some(scale)
                } else {
                  return None
                }
              None => return None
            }
          None => return None
        }
    }
  }
  match exp_quad {
    Some(scale) if expr_eq(x_pow, @symcore.int(1)) =>
      Some(
        expr_div(
          expr_mul(
            expr_mul(
              expr_mul(expr_sqrt_two(), k),
              @symelem.exp(
                expr_div(
                  expr_mul(@symcore.int(-1), expr_pow(k, @symcore.int(2))),
                  expr_mul(@symcore.int(4), scale),
                ),
              ),
            ),
            @symcore.int(1),
          ),
          expr_mul(@symcore.int(4), expr_pow(scale, expr_rat(3, 2))),
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
    match unary_application_arg(factor, "log") {
      Some(Expr::Symbol(name)) if name == x_name => saw_log = true
      _ =>
        match parse_negative_power(factor, x_name) {
          Some(power) if expr_eq(power, @symcore.int(1)) => saw_inverse_x = true
          _ => return None
        }
    }
  }
  if saw_log && saw_inverse_x {
    Some(
      expr_div(
        expr_mul(
          expr_mul(@symcore.int(-1), expr_mul(expr_sqrt_two(), sqrt_pi())),
          expr_add(
            @symelem.log(expr_pow(k, @symcore.int(2))),
            expr_mul(
              @symcore.int(2),
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::EulerGamma),
            ),
          ),
        ),
        @symcore.int(4),
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
              @symcore.int(2),
              expr_add(
                expr_div(@symcore.int(1), @symcore.int(2)),
                expr_mul(@symcore.int(-1), a),
              ),
            ),
            expr_mul(
              expr_pow(k, expr_sub(a, @symcore.int(1))),
              @symspec.gamma(
                expr_sub(@symcore.int(1), expr_div(a, @symcore.int(2))),
              ),
            ),
          ),
          @symspec.gamma(
            expr_div(expr_add(a, @symcore.int(1)), @symcore.int(2)),
          ),
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
                expr_add(
                  expr_pow(a, @symcore.int(2)),
                  expr_pow(k, @symcore.int(2)),
                ),
              ),
            ),
          )
        None => None
      }
  }
}

///|
/// Apply the inverse sine-transform rule table.
///
/// - Does: Evaluates an inverse sine transform when a local closed form is available.
/// - Input: One source `Expr`, one frequency variable `k`, and one space variable `x`.
/// - Returns: `Some(Expr)` for a computed transform or `None`.
/// - Limits: Unsupported cases return `None`.
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
          let mut const_coeff = @symcore.int(1)
          for item in coeff {
            if expr_eq(item, @symcore.Expr::Symbol(k_name)) {
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
                Some(@symelem.exp(expr_mul(@symcore.int(-1), expr_mul(a, x))))
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
    if expr_eq(factor, @symcore.Expr::Symbol(k_name)) {
      k_seen = true
    } else {
      match unary_application_arg(factor, "exp") {
        Some(inner) =>
          match parse_negative_quadratic_exp(inner, k_name) {
            Some(scale) => exp_scale = Some(scale)
            None => return None
          }
        None => return None
      }
    }
  }
  if !k_seen {
    return None
  }
  match exp_scale {
    Some(scale) => {
      let a = expr_div(@symcore.int(1), expr_mul(@symcore.int(4), scale))
      let expected = expr_div(
        expr_sqrt_two(),
        expr_mul(@symcore.int(4), expr_pow(a, expr_rat(3, 2))),
      )
      if expr_eq(coeff, expected) {
        Some(
          expr_mul(
            x,
            @symelem.exp(
              expr_mul(
                @symcore.int(-1),
                expr_mul(a, expr_pow(x, @symcore.int(2))),
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

///|
/// Apply the forward cosine-transform rule table.
///
/// - Does: Evaluates a forward cosine transform when a local closed form is available.
/// - Input: One source `Expr`, one space variable `x`, and one frequency variable `k`.
/// - Returns: `Some(Expr)` for a computed transform or `None`.
/// - Limits: Unsupported cases return `None`.
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
      match unary_application_arg(factor, "exp") {
        Some(inner) =>
          match parse_sqrt_linear(expr_mul(@symcore.int(-1), inner), x_name) {
            Some(a) => exp_coeff = Some(a)
            None => return None
          }
        None =>
          match unary_application_arg(factor, "cos") {
            Some(inner) =>
              match parse_sqrt_linear(inner, x_name) {
                Some(a) => cos_coeff = Some(a)
                None => return None
              }
            None => return None
          }
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
                  expr_mul(@symcore.int(-1), expr_pow(a1, @symcore.int(2))),
                  expr_mul(@symcore.int(2), k),
                ),
              ),
            ),
            expr_mul(@symcore.int(2), expr_pow(k, expr_rat(3, 2))),
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
              @symcore.int(2),
              expr_add(
                expr_div(@symcore.int(1), @symcore.int(2)),
                expr_mul(@symcore.int(-1), a),
              ),
            ),
            expr_mul(
              expr_pow(k, expr_sub(a, @symcore.int(1))),
              @symspec.gamma(
                expr_div(expr_sub(@symcore.int(1), a), @symcore.int(2)),
              ),
            ),
          ),
          @symspec.gamma(expr_div(a, @symcore.int(2))),
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
                expr_add(
                  expr_pow(a, @symcore.int(2)),
                  expr_pow(k, @symcore.int(2)),
                ),
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
                    @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(a, k))),
                  ),
                  expr_mul(@symcore.int(2), a),
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
                                @symcore.Expr::NumberSymbol(
                                  @symcore.NumberSymbolKind::Pi,
                                ),
                                expr_mul(
                                  @symcore.int(2),
                                  @symspec.si(expr_mul(a, k)),
                                ),
                              ),
                              @symcore.int(2),
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
                              [@symcore.int(0), @symcore.int(0)],
                              [expr_rat(1, 2)],
                              expr_div(
                                expr_mul(a_sq, expr_pow(k, @symcore.int(2))),
                                @symcore.int(4),
                              ),
                            ),
                          ),
                          expr_mul(@symcore.int(2), sqrt_pi()),
                        ),
                      )
                    None =>
                      match unary_application_arg(expr, "exp") {
                        Some(inner) =>
                          match parse_negative_quadratic_exp(inner, x_name) {
                            Some(a) =>
                              Some(
                                expr_div(
                                  expr_mul(
                                    expr_sqrt_two(),
                                    @symelem.exp(
                                      expr_div(
                                        expr_mul(
                                          @symcore.int(-1),
                                          expr_pow(k, @symcore.int(2)),
                                        ),
                                        expr_mul(@symcore.int(4), a),
                                      ),
                                    ),
                                  ),
                                  expr_mul(
                                    @symcore.int(2),
                                    expr_sqrt_positive(a),
                                  ),
                                ),
                              )
                            None => None
                          }
                        None => None
                      }
                  }
              }
          }
      }
  }
}

///|
fn parse_sqrt_linear(expr : Expr, var_name : String) -> Expr? {
  retry_with_simplified(expr, expr => parse_sqrt_linear_raw(expr, var_name))
}

///|
fn parse_sqrt_linear_raw(expr : Expr, var_name : String) -> Expr? {
  match unary_application_arg(expr, "sqrt") {
    Some(Expr::Symbol(name)) if name == var_name => Some(@symcore.int(1))
    _ =>
      match expr {
        @symcore.Expr::Mul(args) => {
          let mut coeff = @symcore.int(1)
          let mut saw_sqrt = false
          for arg in args {
            match unary_application_arg(arg, "sqrt") {
              Some(Expr::Symbol(name)) =>
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
}

///|
/// Apply the inverse cosine-transform rule table.
///
/// - Does: Evaluates an inverse cosine transform when a local closed form is available.
/// - Input: One source `Expr`, one frequency variable `k`, and one space variable `x`.
/// - Returns: `Some(Expr)` for a computed transform or `None`.
/// - Limits: Unsupported cases return `None`.
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
        @symcore.int(1)
      } else if num.length() == 1 {
        num[0]
      } else {
        expr_simplify(@symcore.mul(num))
      }
      match denom_to_square_freq(den, k_name) {
        Some(a) => {
          let expected = expr_div(expr_mul(expr_sqrt_two(), a), sqrt_pi())
          if expr_eq(coeff, expected) {
            Some(@symelem.exp(expr_mul(@symcore.int(-1), expr_mul(a, x))))
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
        expr_mul(
          @symcore.int(2),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        ),
      )
      if expr_eq(coeff, expected) {
        Some(expr_pow(expr_add(x, expr_sqrt_positive(a_sq)), @symcore.int(-1)))
      } else {
        None
      }
    }
    None =>
      match parse_cosine_sqrt_meijerg(factors[0], k_name) {
        Some(a_sq) => {
          let expected = expr_div(
            expr_sqrt_two(),
            expr_mul(@symcore.int(2), sqrt_pi()),
          )
          if expr_eq(coeff, expected) {
            Some(
              expr_div(
                @symcore.int(1),
                expr_mul(
                  x,
                  @symelem.sqrt(
                    expr_add(
                      expr_div(a_sq, expr_pow(x, @symcore.int(2))),
                      @symcore.int(1),
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
        expr_mul(@symcore.int(2), a),
      )
      if expr_eq(coeff, expected) {
        Some(
          expr_div(
            @symcore.int(1),
            expr_add(expr_pow(a, @symcore.int(2)), expr_pow(x, @symcore.int(2))),
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
  match unary_application_arg(factors[0], "exp") {
    Some(inner) =>
      match parse_negative_quadratic_exp(inner, k_name) {
        Some(scale) => {
          let a = expr_div(@symcore.int(1), expr_mul(@symcore.int(4), scale))
          let forward_coeff = expr_div(
            expr_sqrt_two(),
            expr_mul(@symcore.int(2), expr_sqrt_positive(a)),
          )
          let simplified_coeff = expr_mul(
            expr_sqrt_two(),
            expr_sqrt_positive(scale),
          )
          if expr_eq(coeff, forward_coeff) ||
            expr_eq(coeff, simplified_coeff) ||
            expr_eq(
              expr_pow(coeff, @symcore.int(2)),
              expr_mul(@symcore.int(2), scale),
            ) {
            Some(
              @symelem.exp(
                expr_mul(
                  @symcore.int(-1),
                  expr_mul(a, expr_pow(x, @symcore.int(2))),
                ),
              ),
            )
          } else {
            None
          }
        }
        None => None
      }
    None => None
  }
}

///|
/// Apply the forward Hankel-transform rule table.
///
/// - Does: Evaluates a forward Hankel transform of order `nu` when a local closed form is available.
/// - Input: One source `Expr`, radial variable `r`, frequency variable `k`, and order `nu`.
/// - Returns: `Some(Expr)` for a computed transform or `None`.
/// - Limits: Unsupported cases return `None`.
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
          match unary_application_arg(factor, "exp") {
            Some(inner) =>
              match parse_negative_linear_exp_raw(inner, r_name) {
                Some(a) => decay = Some(a)
                None => return None
              }
            None => return None
          }
      }
    }
    match (power, decay) {
      (Some(p), Some(a)) if expr_eq(p, nu) =>
        Some(
          expr_div(
            expr_mul(
              expr_mul(
                expr_pow(@symcore.int(2), expr_add(nu, @symcore.int(1))),
                a,
              ),
              @symspec.gamma(expr_add(nu, expr_rat(3, 2))),
            ) *
            expr_pow(
              k,
              expr_sub(@symcore.int(-1), expr_add(nu, @symcore.int(2))),
            ),
            expr_mul(
              sqrt_pi(),
              expr_pow(
                expr_add(
                  expr_div(
                    expr_pow(a, @symcore.int(2)),
                    expr_pow(k, @symcore.int(2)),
                  ),
                  @symcore.int(1),
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
  let mut power = @symcore.int(0)
  let mut decay : Expr? = None
  for factor in factors {
    match parse_power_factor(factor, r_name) {
      Some(p) => power = expr_add(power, p)
      None =>
        match unary_application_arg(factor, "exp") {
          Some(inner) =>
            match parse_negative_quadratic_exp(inner, r_name) {
              Some(a) =>
                if decay is None {
                  decay = Some(a)
                } else {
                  return None
                }
              None => return None
            }
          None => return None
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
              expr_div(@symcore.int(1), expr_mul(@symcore.int(2), a)),
              expr_add(nu, @symcore.int(1)),
            ),
          ),
          @symelem.exp(
            expr_div(
              expr_mul(@symcore.int(-1), expr_pow(k, @symcore.int(2))),
              expr_mul(@symcore.int(4), a),
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
          expr_pow(@symcore.int(2), expr_sub(@symcore.int(1), m)),
          expr_div(
            expr_mul(
              expr_pow(k, expr_sub(m, @symcore.int(2))),
              @symspec.gamma(
                expr_add(
                  expr_sub(@symcore.int(1), expr_div(m, @symcore.int(2))),
                  expr_div(nu, @symcore.int(2)),
                ),
              ),
            ),
            @symspec.gamma(
              expr_add(
                expr_div(m, @symcore.int(2)),
                expr_div(nu, @symcore.int(2)),
              ),
            ),
          ),
        ),
      )
    None => None
  }
}

///|
/// Apply the inverse Hankel-transform rule table.
///
/// - Does: Evaluates an inverse Hankel transform of order `nu` when a local closed form is available.
/// - Input: One source `Expr`, frequency variable `k`, radial variable `r`, and order `nu`.
/// - Returns: `Some(Expr)` for a computed transform or `None`.
/// - Limits: Unsupported cases return `None`.
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
/// Apply the forward Mellin rule table.
///
/// - Does: Evaluates a forward Mellin transform and keeps only the transformed value.
/// - Input: One source `Expr`, one variable `x`, and one Mellin variable `s`.
/// - Returns: `Some(Expr)` for a computed transform or `None`.
/// - Limits: Strip and condition metadata are not returned here.
pub fn do_mellin_doit(_expr : Expr, x : Expr, s : Expr) -> Expr? {
  match (symbol_name(x), symbol_name(s)) {
    (Some(x_name), Some(s_name)) =>
      match
        mellin_info_doit(
          expr_simplify(_expr),
          x_name,
          @symcore.Expr::Symbol(s_name),
        ) {
        Some(info) => Some(info.0)
        None =>
          mellin_doit(
            expr_simplify(_expr),
            x_name,
            @symcore.Expr::Symbol(s_name),
          )
      }
    _ => None
  }
}

///|
/// Apply the inverse Mellin rule table.
///
/// - Does: Evaluates an inverse Mellin transform and returns only the recovered value.
/// - Input: One source `Expr`, one Mellin variable `s`, and one target variable `x`.
/// - Returns: `Some(Expr)` for a computed transform or `None`.
/// - Limits: Unsupported cases return `None`.
pub fn do_inverse_mellin_doit(_expr : Expr, s : Expr, x : Expr) -> Expr? {
  match (symbol_name(s), symbol_name(x)) {
    (Some(s_name), Some(_)) =>
      inverse_mellin_doit(expr_simplify(_expr), s_name, x)
    _ => None
  }
}

///|
/// Evaluate a Mellin transform with optional metadata.
///
/// - Does: Runs the Mellin rule engine and optionally keeps strip and condition metadata.
/// - Input: One source `Expr`, one variable `x`, one Mellin variable `s`, and an optional `noconds` flag.
/// - Returns: Either the transformed `Expr` or a tuple `(value, (left, right), condition)`.
/// - Limits: Returns an unevaluated `MellinTransform(...)` when no rule applies.
pub fn mellin_transform_result(
  expr : Expr,
  x : Expr,
  s : Expr,
  noconds? : Bool = false,
) -> Expr {
  match (symbol_name(x), symbol_name(s)) {
    (Some(x_name), Some(s_name)) =>
      match
        mellin_info_doit(
          expr_simplify(expr),
          x_name,
          @symcore.Expr::Symbol(s_name),
        ) {
        Some((value, lower, upper, cond)) =>
          if noconds {
            value
          } else {
            Expr::Tuple([value, Expr::Tuple([lower, upper]), cond])
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
            lower.unwrap_or(
              expr_mul(
                @symcore.int(-1),
                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
              ),
            ),
            upper.unwrap_or(
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
            ),
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
  @symcore.raw_function("MellinTransform", [
    expr,
    @symcore.Expr::Symbol(x_name),
    s,
  ])
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
  match named_binary_application(expr) {
    Some(("besselj", order, arg)) =>
      match parse_sqrt_linear(arg, x_name) {
        Some(coeff) =>
          Some(
            (
              expr_mul(
                mellin_bessel_sqrt_scale(coeff, s),
                expr_div(
                  @symspec.gamma(expr_add(s, expr_div(order, @symcore.int(2)))),
                  @symspec.gamma(
                    expr_add(
                      @symcore.int(1),
                      expr_sub(expr_div(order, @symcore.int(2)), s),
                    ),
                  ),
                ),
              ),
              expr_div(
                expr_mul(@symcore.int(-1), @symelem.re(order)),
                @symcore.int(2),
              ),
              expr_rat(3, 4),
              true_expr(),
            ),
          )
        None => None
      }
    Some(("bessely", order, arg)) =>
      match parse_sqrt_linear(arg, x_name) {
        Some(coeff) => {
          let half_order = expr_div(order, @symcore.int(2))
          Some(
            (
              expr_mul(
                mellin_bessel_sqrt_scale(coeff, s),
                expr_div(
                  expr_mul(
                    @symcore.int(-1),
                    expr_mul(
                      @symelem.cos(
                        expr_mul(
                          @symcore.Expr::NumberSymbol(
                            @symcore.NumberSymbolKind::Pi,
                          ),
                          expr_sub(half_order, s),
                        ),
                      ),
                      expr_mul(
                        @symspec.gamma(expr_sub(s, half_order)),
                        @symspec.gamma(expr_add(s, half_order)),
                      ),
                    ),
                  ),
                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                ),
              ),
              max_expr(
                expr_div(
                  expr_mul(@symcore.int(-1), @symelem.re(order)),
                  @symcore.int(2),
                ),
                expr_div(@symelem.re(order), @symcore.int(2)),
              ),
              expr_rat(3, 4),
              true_expr(),
            ),
          )
        }
        None => None
      }
    Some(("besselk", order, arg)) =>
      match parse_sqrt_linear(arg, x_name) {
        Some(coeff) => {
          let half_order = expr_div(order, @symcore.int(2))
          Some(
            (
              expr_mul(
                mellin_bessel_sqrt_scale(coeff, s),
                expr_div(
                  expr_mul(
                    @symspec.gamma(expr_sub(s, half_order)),
                    @symspec.gamma(expr_add(s, half_order)),
                  ),
                  @symcore.int(2),
                ),
              ),
              max_expr(
                expr_div(
                  expr_mul(@symcore.int(-1), @symelem.re(order)),
                  @symcore.int(2),
                ),
                expr_div(@symelem.re(order), @symcore.int(2)),
              ),
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
              true_expr(),
            ),
          )
        }
        None => None
      }
    Some(("expint", n, Expr::Symbol(name))) =>
      if name == x_name && expr_is_constant(n, x_name) {
        Some(
          (
            expr_div(
              @symspec.gamma(s),
              expr_sub(expr_add(n, s), @symcore.int(1)),
            ),
            max_expr(expr_sub(@symcore.int(1), n), @symcore.int(0)),
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
            true_expr(),
          ),
        )
      } else {
        None
      }
    _ =>
      match named_unary_application(expr) {
        Some(("E1", Expr::Symbol(name))) =>
          if name == x_name {
            Some(
              (
                expr_div(@symspec.gamma(s), s),
                @symcore.int(0),
                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
                true_expr(),
              ),
            )
          } else {
            None
          }
        Some(("Si", Expr::Symbol(name))) =>
          if name == x_name {
            Some(
              (
                expr_div(
                  expr_mul(
                    @symcore.int(-1),
                    expr_mul(
                      expr_pow(@symcore.int(2), s),
                      expr_mul(
                        sqrt_pi(),
                        @symspec.gamma(
                          expr_div(
                            expr_add(s, @symcore.int(1)),
                            @symcore.int(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  expr_mul(
                    @symcore.int(2),
                    expr_mul(
                      s,
                      @symspec.gamma(
                        expr_sub(@symcore.int(1), expr_div(s, @symcore.int(2))),
                      ),
                    ),
                  ),
                ),
                @symcore.int(-1),
                @symcore.int(0),
                true_expr(),
              ),
            )
          } else {
            None
          }
        Some(("erf", inner)) =>
          match unary_application_arg(inner, "sqrt") {
            Some(Expr::Symbol(name)) if name == x_name =>
              Some(
                (
                  expr_div(
                    expr_mul(
                      @symcore.int(-1),
                      @symspec.gamma(expr_add(s, expr_rat(1, 2))),
                    ),
                    expr_mul(sqrt_pi(), s),
                  ),
                  expr_mul(@symcore.int(-1), expr_rat(1, 2)),
                  @symcore.int(0),
                  true_expr(),
                ),
              )
            _ => None
          }
        Some(("Ci", inner)) =>
          match unary_application_arg(inner, "sqrt") {
            Some(Expr::Symbol(name)) if name == x_name =>
              Some(
                (
                  expr_div(
                    expr_mul(
                      @symcore.int(-1),
                      expr_mul(
                        expr_pow(
                          @symcore.int(2),
                          expr_sub(
                            expr_mul(@symcore.int(2), s),
                            @symcore.int(1),
                          ),
                        ),
                        expr_mul(sqrt_pi(), @symspec.gamma(s)),
                      ),
                    ),
                    expr_mul(s, @symspec.gamma(expr_sub(expr_rat(1, 2), s))),
                  ),
                  @symcore.int(0),
                  @symcore.int(1),
                  true_expr(),
                ),
              )
            _ => None
          }
        _ => None
      }
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
                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                expr_mul(
                  expr_pow(scale, expr_add(expr_sub(power, @symcore.int(1)), s)),
                  @symelem.sin(
                    expr_mul(
                      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                      power,
                    ),
                  ),
                ),
              ),
              expr_mul(
                @symelem.sin(
                  expr_mul(
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                    s,
                  ),
                ),
                @symelem.sin(
                  expr_mul(
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                    expr_add(power, s),
                  ),
                ),
              ),
            ),
          ),
          max_expr(
            @symcore.int(0),
            expr_mul(@symcore.int(-1), @symelem.re(power)),
          ),
          min_expr(
            @symcore.int(1),
            expr_sub(@symcore.int(1), @symelem.re(power)),
          ),
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
        expr_sub(expr_add(power, expr_mul(@symcore.int(2), s)), @symcore.int(1))
      } else {
        expr_add(power, expr_mul(@symcore.int(2), s))
      }
      let gamma_arg = if with_recip_sqrt {
        expr_sub(@symcore.int(1), expr_add(power, expr_mul(@symcore.int(2), s)))
      } else {
        expr_mul(
          @symcore.int(-1),
          expr_add(power, expr_mul(@symcore.int(2), s)),
        )
      }
      let numerator = expr_mul(
        expr_pow(@symcore.int(2), expr_add(power, expr_mul(@symcore.int(2), s))),
        expr_mul(
          expr_pow(scale, scale_pow),
          expr_mul(@symspec.gamma(s), @symspec.gamma(gamma_arg)),
        ),
      )
      let value = if with_recip_sqrt {
        expr_div(
          numerator,
          @symspec.gamma(expr_sub(@symcore.int(1), expr_add(power, s))),
        )
      } else {
        expr_mul(
          @symcore.int(-1),
          expr_div(
            expr_mul(power, numerator),
            @symspec.gamma(expr_sub(@symcore.int(1), expr_add(power, s))),
          ),
        )
      }
      let upper = if with_recip_sqrt {
        expr_add(
          expr_mul(
            @symcore.int(-1),
            expr_div(@symelem.re(power), @symcore.int(2)),
          ),
          expr_rat(1, 2),
        )
      } else {
        expr_mul(
          @symcore.int(-1),
          expr_div(@symelem.re(power), @symcore.int(2)),
        )
      }
      Some((expr_simplify(value), @symcore.int(0), upper, true_expr()))
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
  match retry_with_simplified(expr, expr => pow_named_unary_application(expr)) {
    Some(("Abs", arg, exp)) =>
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
                  @symcore.int(2),
                  expr_mul(
                    @symelem.sin(
                      expr_div(
                        expr_mul(
                          @symcore.Expr::NumberSymbol(
                            @symcore.NumberSymbolKind::Pi,
                          ),
                          rho,
                        ),
                        @symcore.int(2),
                      ),
                    ),
                    expr_mul(
                      @symspec.gamma(expr_sub(@symcore.int(1), rho)),
                      expr_mul(
                        @symelem.cos(
                          expr_mul(
                            @symcore.Expr::NumberSymbol(
                              @symcore.NumberSymbolKind::Pi,
                            ),
                            expr_sub(s, expr_div(rho, @symcore.int(2))),
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
                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
              ),
              @symcore.int(0),
              @symelem.re(rho),
              @symcore.function("Lt", [@symelem.re(rho), @symcore.int(1)]),
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
  match unary_application_arg(expr, "log") {
    Some(inner) =>
      if parse_one_plus_linear(inner, x_name) {
        Some(
          (
            expr_div(
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
              expr_mul(
                s,
                @symelem.sin(
                  expr_mul(
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                    s,
                  ),
                ),
              ),
            ),
            @symcore.int(-1),
            @symcore.int(0),
            true_expr(),
          ),
        )
      } else if parse_one_plus_inverse(inner, x_name) {
        Some(
          (
            expr_div(
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
              expr_mul(
                s,
                @symelem.sin(
                  expr_mul(
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                    s,
                  ),
                ),
              ),
            ),
            @symcore.int(0),
            @symcore.int(1),
            true_expr(),
          ),
        )
      } else if parse_abs_one_minus_linear(inner, x_name) {
        Some(
          (
            expr_div(
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
              expr_mul(
                s,
                @symelem.tan(
                  expr_mul(
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                    s,
                  ),
                ),
              ),
            ),
            @symcore.int(-1),
            @symcore.int(0),
            true_expr(),
          ),
        )
      } else if parse_abs_one_minus_inverse(inner, x_name) {
        Some(
          (
            expr_div(
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
              expr_mul(
                s,
                @symelem.tan(
                  expr_mul(
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                    s,
                  ),
                ),
              ),
            ),
            @symcore.int(0),
            @symcore.int(1),
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
              @symcore.int(0),
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
  if expr_eq(coeff, @symcore.int(2)) {
    @symcore.int(1)
  } else {
    expr_pow(expr_div(@symcore.int(4), expr_pow(coeff, @symcore.int(2))), s)
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
    match unary_application_arg(factor, "exp") {
      Some(inner) =>
        match parse_mellin_exp(inner, x_name) {
          Some((coef, degree)) =>
            if exp_opt is None {
              exp_opt = Some((coef, degree))
            } else {
              return None
            }
          None => return None
        }
      None =>
        match unary_application_arg(factor, "Heaviside") {
          Some(arg) =>
            match parse_heaviside_limit(arg, x_name) {
              Some((bound, is_le)) =>
                if heav_opt is None {
                  heav_opt = Some((bound, is_le))
                } else {
                  return None
                }
              None => other_count += 1
            }
          None =>
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
  }
  if other_count != 0 {
    return None
  }
  let pow = match pow_opt {
    Some(v) => v
    None => @symcore.int(0)
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
    match unary_application_arg(factor, "exp") {
      Some(inner) =>
        match parse_mellin_exp(inner, x_name) {
          Some((coef, degree)) =>
            if exp_opt is None {
              exp_opt = Some((coef, degree))
            } else {
              return None
            }
          None => return None
        }
      None =>
        match unary_application_arg(factor, "Heaviside") {
          Some(arg) =>
            match parse_heaviside_limit(arg, x_name) {
              Some((bound, is_le)) =>
                if heav_opt is None {
                  heav_opt = Some((bound, is_le))
                } else {
                  return None
                }
              None => other_count += 1
            }
          None =>
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
  }
  if other_count != 0 {
    return None
  }
  let pow = pow_opt.unwrap_or(@symcore.int(0))
  match (exp_opt, heav_opt) {
    (Some((coef, degree)), None) => mellin_exp_info(pow, coef, degree, s)
    (None, Some((bound, is_le))) => {
      let value = mellin_heaviside_term(pow, bound, is_le, s)
      if is_le {
        Some(
          (
            value,
            expr_mul(@symcore.int(-1), pow),
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
            true_expr(),
          ),
        )
      } else {
        Some(
          (
            value,
            expr_mul(
              @symcore.int(-1),
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
            ),
            expr_mul(@symcore.int(-1), pow),
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
    match unary_application_arg(factor, "Heaviside") {
      Some(arg) =>
        match parse_heaviside_limit(arg, x_name) {
          Some(info) =>
            if heav_data is None {
              heav_data = Some(info)
            } else {
              return None
            }
          None => return None
        }
      None =>
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
        let beta = expr_add(exp, @symcore.int(1))
        Some(
          (
            expr_div(
              expr_mul(@symspec.gamma(beta), @symspec.gamma(s)),
              @symspec.gamma(expr_add(beta, s)),
            ),
            @symcore.int(0),
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
            @symcore.function("Gt", [@symelem.re(beta), @symcore.int(0)]),
          ),
        )
      } else if expr_is_one(bound) &&
        expr_is_one(pow_coeff) &&
        expr_is_minus_one(pow_offset) &&
        !is_le {
        let beta = expr_add(exp, @symcore.int(1))
        Some(
          (
            expr_div(
              expr_mul(
                @symspec.gamma(beta),
                @symspec.gamma(expr_sub(expr_sub(@symcore.int(1), beta), s)),
              ),
              @symspec.gamma(expr_sub(@symcore.int(1), s)),
            ),
            @symcore.Expr::NumberSymbol(
              @symcore.NumberSymbolKind::NegativeInfinity,
            ),
            expr_sub(@symcore.int(1), @symelem.re(beta)),
            @symcore.function("Gt", [@symelem.re(beta), @symcore.int(0)]),
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
    match unary_application_arg(factor, "Heaviside") {
      Some(arg) =>
        match parse_heaviside_limit(arg, x_name) {
          Some(info) =>
            if heav is None {
              heav = Some(info)
            } else {
              return None
            }
          None => return None
        }
      None =>
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
          @symcore.int(1)
        } else {
          @symcore.int(-1)
        }
      } else if n % 2 == 0 {
        @symcore.int(-1)
      } else {
        @symcore.int(1)
      }
      let value = expr_mul(
        sign,
        expr_mul(
          factorial_expr(@symcore.int(n)),
          expr_pow(s, @symcore.int(-(n + 1))),
        ),
      )
      if is_le {
        Some(
          (
            value,
            @symcore.int(0),
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
            true_expr(),
          ),
        )
      } else {
        Some(
          (
            value,
            @symcore.Expr::NumberSymbol(
              @symcore.NumberSymbolKind::NegativeInfinity,
            ),
            @symcore.int(0),
            true_expr(),
          ),
        )
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
    match named_binary_application(factor) {
      Some(("besselj", order, arg)) =>
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
      Some(("bessely", order, arg)) =>
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
      _ =>
        match named_unary_application(factor) {
          Some(("sin", arg)) =>
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
          Some(("cos", arg)) =>
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
          _ => return None
        }
    }
  }
  match (trig_name, trig_coeff, bessel_kind, bessel_order, bessel_coeff) {
    (Some(trig), Some(coeff1), Some(kind), Some(order), Some(coeff2)) =>
      if !expr_eq(coeff1, coeff2) {
        None
      } else {
        let scale = mellin_bessel_pair_scale(coeff1, s)
        let half_order = expr_div(order, @symcore.int(2))
        let common_strip = max_expr(
          expr_div(
            expr_mul(@symcore.int(-1), @symelem.re(order)),
            @symcore.int(2),
          ),
          expr_div(@symelem.re(order), @symcore.int(2)),
        )
        match (trig, kind) {
          ("sin", "besselj") =>
            Some(
              (
                expr_mul(
                  scale,
                  expr_div(
                    expr_mul(
                      expr_pow(@symcore.int(2), order),
                      expr_mul(
                        @symspec.gamma(
                          expr_sub(expr_rat(1, 2), expr_mul(@symcore.int(2), s)),
                        ),
                        @symspec.gamma(
                          expr_add(half_order, expr_add(s, expr_rat(1, 2))),
                        ),
                      ),
                    ),
                    expr_mul(
                      @symspec.gamma(
                        expr_add(
                          expr_mul(@symcore.int(-1), half_order),
                          expr_sub(@symcore.int(1), s),
                        ),
                      ),
                      @symspec.gamma(
                        expr_add(
                          order,
                          expr_sub(
                            @symcore.int(1),
                            expr_mul(@symcore.int(2), s),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                expr_sub(
                  expr_div(
                    expr_mul(@symcore.int(-1), @symelem.re(order)),
                    @symcore.int(2),
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
                      expr_pow(@symcore.int(2), order),
                      expr_mul(
                        @symspec.gamma(expr_add(half_order, s)),
                        @symspec.gamma(
                          expr_sub(expr_rat(1, 2), expr_mul(@symcore.int(2), s)),
                        ),
                      ),
                    ),
                    expr_mul(
                      @symspec.gamma(
                        expr_add(
                          expr_sub(expr_rat(1, 2), half_order),
                          expr_mul(@symcore.int(-1), s),
                        ),
                      ),
                      @symspec.gamma(
                        expr_add(
                          order,
                          expr_sub(
                            @symcore.int(1),
                            expr_mul(@symcore.int(2), s),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                expr_div(
                  expr_mul(@symcore.int(-1), @symelem.re(order)),
                  @symcore.int(2),
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
                      @symcore.int(-1),
                      expr_mul(
                        expr_pow(@symcore.int(4), s),
                        expr_mul(
                          @symelem.sin(
                            expr_mul(
                              @symcore.Expr::NumberSymbol(
                                @symcore.NumberSymbolKind::Pi,
                              ),
                              expr_sub(half_order, s),
                            ),
                          ),
                          expr_mul(
                            @symspec.gamma(
                              expr_sub(
                                expr_rat(1, 2),
                                expr_mul(@symcore.int(2), s),
                              ),
                            ),
                            expr_mul(
                              @symspec.gamma(
                                expr_add(
                                  expr_div(
                                    expr_sub(@symcore.int(1), order),
                                    @symcore.int(2),
                                  ),
                                  s,
                                ),
                              ),
                              @symspec.gamma(
                                expr_add(
                                  expr_div(
                                    expr_add(@symcore.int(1), order),
                                    @symcore.int(2),
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
                          expr_sub(@symcore.int(1), expr_add(s, half_order)),
                        ),
                        @symspec.gamma(
                          expr_add(expr_sub(@symcore.int(1), s), half_order),
                        ),
                      ),
                    ),
                  ),
                ),
                max_expr(
                  expr_div(
                    expr_sub(
                      expr_mul(@symcore.int(-1), @symelem.re(order)),
                      @symcore.int(1),
                    ),
                    @symcore.int(2),
                  ),
                  expr_div(
                    expr_sub(@symelem.re(order), @symcore.int(1)),
                    @symcore.int(2),
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
                      @symcore.int(-1),
                      expr_mul(
                        expr_pow(@symcore.int(4), s),
                        expr_mul(
                          @symelem.cos(
                            expr_mul(
                              @symcore.Expr::NumberSymbol(
                                @symcore.NumberSymbolKind::Pi,
                              ),
                              expr_sub(half_order, s),
                            ),
                          ),
                          expr_mul(
                            @symspec.gamma(expr_sub(s, half_order)),
                            expr_mul(
                              @symspec.gamma(expr_add(s, half_order)),
                              @symspec.gamma(
                                expr_sub(
                                  expr_rat(1, 2),
                                  expr_mul(@symcore.int(2), s),
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
      @symcore.Expr::Pow(base, exp) if expr_eq(exp, @symcore.int(2)) => {
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
  if expr_eq(coeff, @symcore.int(1)) {
    @symcore.int(1)
  } else {
    expr_pow(expr_pow(coeff, @symcore.int(2)), expr_mul(@symcore.int(-1), s))
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
    match named_binary_application(factor) {
      Some(("besselj", order, arg)) =>
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
                    @symspec.gamma(expr_sub(@symcore.int(1), s)),
                    @symspec.gamma(
                      expr_add(expr_sub(order1, s), @symcore.int(1)),
                    ),
                  ),
                ),
              ),
            ),
            expr_mul(@symcore.int(-1), @symelem.re(order1)),
            expr_rat(1, 2),
            true_expr(),
          ),
        )
      } else if expr_eq(order2, expr_mul(@symcore.int(-1), order1)) {
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
                        expr_mul(@symcore.int(-1), order1),
                        expr_sub(@symcore.int(1), s),
                      ),
                    ),
                    @symspec.gamma(
                      expr_add(order1, expr_sub(@symcore.int(1), s)),
                    ),
                  ),
                ),
              ),
            ),
            @symcore.int(0),
            expr_rat(1, 2),
            true_expr(),
          ),
        )
      } else if expr_eq(order1, expr_mul(@symcore.int(-1), order2)) {
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
                        expr_mul(@symcore.int(-1), order2),
                        expr_sub(@symcore.int(1), s),
                      ),
                    ),
                    @symspec.gamma(
                      expr_add(order2, expr_sub(@symcore.int(1), s)),
                    ),
                  ),
                ),
              ),
            ),
            @symcore.int(0),
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
                  expr_pow(@symcore.int(4), s),
                  expr_mul(
                    @symspec.gamma(
                      expr_sub(@symcore.int(1), expr_mul(@symcore.int(2), s)),
                    ),
                    @symspec.gamma(
                      expr_add(
                        expr_div(expr_add(order1, order2), @symcore.int(2)),
                        s,
                      ),
                    ),
                  ),
                ),
                expr_mul(
                  @symspec.gamma(
                    expr_add(
                      expr_sub(@symcore.int(1), s),
                      expr_div(expr_sub(order2, order1), @symcore.int(2)),
                    ),
                  ),
                  expr_mul(
                    @symspec.gamma(
                      expr_add(
                        expr_sub(@symcore.int(1), s),
                        expr_div(expr_sub(order1, order2), @symcore.int(2)),
                      ),
                    ),
                    @symspec.gamma(
                      expr_add(
                        expr_sub(@symcore.int(1), s),
                        expr_div(expr_add(order1, order2), @symcore.int(2)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            expr_div(
              expr_mul(
                @symcore.int(-1),
                expr_add(@symelem.re(order1), @symelem.re(order2)),
              ),
              @symcore.int(2),
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
    match named_binary_application(factor) {
      Some(("besselj", order, arg)) =>
        match parse_sqrt_linear(arg, x_name) {
          Some(coeff) =>
            if j_data is None {
              j_data = Some((order, coeff))
            } else {
              return None
            }
          None => return None
        }
      Some(("bessely", order, arg)) =>
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
                  @symcore.int(-1),
                  expr_mul(
                    @symelem.cos(
                      expr_mul(
                        @symcore.Expr::NumberSymbol(
                          @symcore.NumberSymbolKind::Pi,
                        ),
                        s,
                      ),
                    ),
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
                  expr_mul(
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                    sqrt_pi(),
                  ),
                  @symspec.gamma(
                    expr_add(expr_sub(order_j, s), @symcore.int(1)),
                  ),
                ),
              ),
            ),
            max_expr(
              expr_mul(@symcore.int(-1), @symelem.re(order_j)),
              @symcore.int(0),
            ),
            expr_rat(1, 2),
            true_expr(),
          ),
        )
      } else if expr_eq(coeff_j, coeff_y) {
        let scale = mellin_bessel_pair_scale(coeff_j, s)
        let half_diff = expr_div(expr_sub(order_j, order_y), @symcore.int(2))
        let half_sum = expr_div(expr_add(order_j, order_y), @symcore.int(2))
        Some(
          (
            expr_mul(
              scale,
              expr_div(
                expr_mul(
                  @symcore.int(-1),
                  expr_mul(
                    expr_pow(@symcore.int(4), s),
                    expr_mul(
                      @symelem.cos(
                        expr_mul(
                          @symcore.Expr::NumberSymbol(
                            @symcore.NumberSymbolKind::Pi,
                          ),
                          expr_add(half_diff, s),
                        ),
                      ),
                      expr_mul(
                        @symspec.gamma(
                          expr_sub(
                            @symcore.int(1),
                            expr_mul(@symcore.int(2), s),
                          ),
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
                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                  expr_mul(
                    @symspec.gamma(
                      expr_add(expr_sub(@symcore.int(1), s), half_diff),
                    ),
                    @symspec.gamma(
                      expr_add(expr_sub(@symcore.int(1), s), half_sum),
                    ),
                  ),
                ),
              ),
            ),
            max_expr(
              expr_div(
                expr_sub(@symelem.re(order_y), @symelem.re(order_j)),
                @symcore.int(2),
              ),
              expr_div(
                expr_mul(
                  @symcore.int(-1),
                  expr_add(@symelem.re(order_j), @symelem.re(order_y)),
                ),
                @symcore.int(2),
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
    match named_binary_application(factor) {
      Some(("besseli", order, arg)) =>
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
      Some(("besselk", order, arg)) =>
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
                  @symcore.int(2),
                  expr_mul(
                    sqrt_pi(),
                    @symspec.gamma(
                      expr_add(expr_sub(order1, s), @symcore.int(1)),
                    ),
                  ),
                ),
              ),
            ),
            max_expr(
              expr_mul(@symcore.int(-1), @symelem.re(order1)),
              @symcore.int(0),
            ),
            expr_rat(1, 2),
            true_expr(),
          ),
        )
      } else if expr_eq(coeff1, coeff2) {
        let scale = mellin_bessel_pair_scale(coeff1, s)
        let half_diff = expr_div(expr_sub(order1, order2), @symcore.int(2))
        let half_sum = expr_div(expr_add(order1, order2), @symcore.int(2))
        Some(
          (
            expr_mul(
              scale,
              expr_div(
                expr_mul(
                  expr_pow(
                    @symcore.int(2),
                    expr_sub(expr_mul(@symcore.int(2), s), @symcore.int(1)),
                  ),
                  expr_mul(
                    @symspec.gamma(
                      expr_sub(@symcore.int(1), expr_mul(@symcore.int(2), s)),
                    ),
                    expr_mul(
                      @symspec.gamma(expr_add(half_diff, s)),
                      @symspec.gamma(expr_add(half_sum, s)),
                    ),
                  ),
                ),
                expr_mul(
                  @symspec.gamma(
                    expr_add(expr_sub(@symcore.int(1), s), half_diff),
                  ),
                  @symspec.gamma(
                    expr_add(expr_sub(@symcore.int(1), s), half_sum),
                  ),
                ),
              ),
            ),
            max_expr(
              expr_div(
                expr_sub(
                  expr_mul(@symcore.int(-1), @symelem.re(order1)),
                  @symelem.re(order2),
                ),
                @symcore.int(2),
              ),
              expr_div(
                expr_sub(@symelem.re(order2), @symelem.re(order1)),
                @symcore.int(2),
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
          expr_mul(@symcore.int(-1), pow),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
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
        expr_mul(
          @symcore.int(-1),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
        expr_mul(@symcore.int(-1), pow),
        true_expr(),
      ),
    )
  } else {
    None
  }
}

///|
fn parse_power_factor(expr : Expr, x_name : String) -> Expr? {
  let direct = match expr {
    @symcore.Expr::Symbol(name) =>
      if name == x_name {
        Some(@symcore.int(1))
      } else {
        None
      }
    @symcore.Expr::Pow(@symcore.Expr::Symbol(name), exp) =>
      if name == x_name {
        Some(exp)
      } else {
        None
      }
    _ => None
  }
  match direct {
    Some(_) => direct
    None =>
      match unary_application_arg(expr, "sqrt") {
        Some(Expr::Symbol(name)) =>
          if name == x_name {
            Some(expr_rat(1, 2))
          } else {
            None
          }
        _ =>
          match pow_named_unary_application(expr) {
            Some(("sqrt", Expr::Symbol(name), exp)) =>
              if name == x_name {
                Some(expr_div(exp, @symcore.int(2)))
              } else {
                None
              }
            _ => None
          }
      }
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
        Some((expr_mul(@symcore.int(-1), offset), false))
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
          expr_mul(
            @symcore.int(-1),
            @symcore.Expr::NumberSymbol(
              @symcore.NumberSymbolKind::ImaginaryUnit,
            ),
          ),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        ),
        shifted,
      )
      let gamma_factor = expr_pow(coef, expr_mul(@symcore.int(-1), shifted))
      let lower = @symspec.lowergamma(
        shifted,
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NegativeInfinity),
      )
      expr_mul(@symelem.exp(phase), expr_mul(gamma_factor, lower))
    } else {
      expr_mul(
        expr_pow(
          expr_mul(@symcore.int(-1), coef),
          expr_mul(@symcore.int(-1), shifted),
        ),
        @symspec.gamma(shifted),
      )
    }
  } else if degree == -1 {
    let norm = expr_mul(@symcore.int(-1), coef)
    let coef_factor = if expr_eq(norm, @symcore.int(1)) {
      @symcore.int(1)
    } else {
      expr_pow(norm, shifted)
    }
    expr_mul(coef_factor, @symspec.gamma(expr_sub(@symcore.int(0), shifted)))
  } else {
    expr_div(
      expr_mul(
        expr_pow(
          coef,
          expr_mul(@symcore.int(-1), expr_div(shifted, @symcore.int(degree))),
        ),
        @symspec.gamma(expr_div(shifted, @symcore.int(degree))),
      ),
      @symcore.int(degree),
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
    expr_mul(@symcore.int(-1), scale)
  }
}

///|
fn expr_is_constant(expr : Expr, symbol_name : String) -> Bool {
  !expr_depends_on(expr, symbol_name)
}

///|
fn inverse_mellin_exponential_scale_factor(
  factor : Expr,
  s_name : String,
) -> (Expr, Expr)? {
  let simplified = expr_simplify(factor)
  match simplified {
    // Source map: the inverse-Laplace integration path reaches this through
    // inverse_mellin_transform. SymPy only turns base**(linear in s) into a
    // time-domain shift when the base is known positive; an unassumed symbolic
    // base such as a**s/s remains an unevaluated InverseLaplaceTransform.
    @symcore.Expr::Pow(base, exp) if !expr_depends_on(base, s_name) &&
      expr_is_positive(base) =>
      match parse_linear_offset_expr(exp, s_name) {
        Some((linear, offset)) =>
          Some((expr_pow(base, linear), expr_pow(base, offset)))
        None => None
      }
    _ =>
      match unary_application_arg(simplified, "exp") {
        Some(inner) =>
          match parse_linear_offset_expr(inner, s_name) {
            Some((linear, offset)) =>
              Some((@symelem.exp(linear), @symelem.exp(offset)))
            None => None
          }
        None => None
      }
  }
}

///|
fn inverse_mellin_scaled_linear_term(
  expr : Expr,
  s_name : String,
  x : Expr,
) -> Expr? {
  let (num_factors, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(v) => v
    None => return None
  }
  let mut coeff = @symcore.int(1)
  let mut scale = @symcore.int(1)
  for factor in num_factors {
    if expr_depends_on(factor, s_name) {
      match inverse_mellin_exponential_scale_factor(factor, s_name) {
        Some((factor_scale, factor_coeff)) => {
          scale = expr_mul(scale, factor_scale)
          coeff = expr_mul(coeff, factor_coeff)
        }
        None => return None
      }
    } else {
      coeff = expr_mul(coeff, factor)
    }
  }
  let mut linear_den : Expr? = None
  for factor in expr_factors(den) {
    if expr_depends_on(factor, s_name) {
      match linear_coeffs(factor, s_name) {
        Some((s_coeff, _)) if !expr_is_zero(s_coeff) =>
          if linear_den is None {
            linear_den = Some(factor)
          } else {
            return None
          }
        _ =>
          match inverse_mellin_exponential_scale_factor(factor, s_name) {
            Some((factor_scale, factor_coeff)) => {
              scale = expr_div(scale, factor_scale)
              coeff = expr_div(coeff, factor_coeff)
            }
            None => return None
          }
      }
    } else {
      coeff = expr_div(coeff, factor)
    }
  }
  if !expr_is_positive(expr_simplify(scale)) {
    return None
  }
  let den_linear = match linear_den {
    Some(v) => v
    None => return None
  }
  let (s_coeff, shift) = match linear_coeffs(den_linear, s_name) {
    Some(v) => v
    None => return None
  }
  let norm_shift = expr_div(shift, s_coeff)
  let norm_num = expr_simplify(expr_div(coeff, s_coeff))
  let (side_is_le, coeff_abs) = if expr_is_negative(norm_num) {
    (false, expr_mul(@symcore.int(-1), norm_num))
  } else if expr_is_positive(norm_num) {
    (true, norm_num)
  } else {
    return None
  }
  let scaled_coeff = expr_mul(
    coeff_abs,
    expr_pow(scale, expr_mul(@symcore.int(-1), norm_shift)),
  )
  let xpow = if expr_is_zero(norm_shift) {
    @symcore.int(1)
  } else {
    expr_pow(x, norm_shift)
  }
  let gate = if side_is_le {
    @symspec.heaviside(expr_sub(scale, x))
  } else {
    @symspec.heaviside(expr_sub(x, scale))
  }
  Some(expr_simplify(expr_mul(scaled_coeff, expr_mul(xpow, gate))))
}

///|
fn inverse_mellin_doit(expr : Expr, s_name : String, x : Expr) -> Expr? {
  let s_sym = @symcore.Expr::Symbol(s_name)
  match expr {
    @symcore.Expr::Add(terms) =>
      transform_add(terms, s_name, fn(term) {
        inverse_mellin_doit(term, s_name, x)
      })
    _ => {
      match inverse_mellin_special_term(expr, s_sym, x) {
        Some(v) => return Some(v)
        None => ()
      }
      let (num, den_opt) = split_division(expr)
      let numerator = if num.length() == 0 {
        @symcore.int(1)
      } else if num.length() == 1 {
        num[0]
      } else {
        expr_simplify(@symcore.mul(num))
      }
      let direct_gamma = match den_opt {
        None =>
          match unary_application_arg(numerator, "gamma") {
            Some(arg) =>
              if expr_eq(arg, s_sym) {
                Some(@symelem.exp(expr_mul(@symcore.int(-1), x)))
              } else if expr_eq(arg, expr_mul(@symcore.int(-1), s_sym)) {
                Some(@symelem.exp(expr_div(@symcore.int(-1), x)))
              } else {
                None
              }
            None => None
          }
        Some(_) => None
      }
      if direct_gamma is Some(gamma_inv) {
        return Some(gamma_inv)
      }
      match inverse_mellin_scaled_linear_term(expr, s_name, x) {
        Some(value) => return Some(value)
        None => ()
      }
      let (num_coeff, vars_opt) = split_mul(numerator, s_name)
      if vars_opt.length() != 0 {
        None
      } else {
        match den_opt {
          None =>
            match unary_application_arg(numerator, "gamma") {
              Some(arg) =>
                if expr_eq(arg, s_sym) {
                  Some(@symelem.exp(expr_mul(@symcore.int(-1), x)))
                } else if expr_eq(arg, expr_mul(@symcore.int(-1), s_sym)) {
                  Some(@symelem.exp(expr_div(@symcore.int(-1), x)))
                } else {
                  None
                }
              None => None
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
                    (false, expr_mul(@symcore.int(-1), norm_num))
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
  let s_name = match symbol_name(s_sym) {
    Some(name) => name
    None => return None
  }
  let flags = transform_head_flags(expr, s_name)
  let has_gamma_like = flags.has_gamma || flags.has_factorial
  let has_piecewise_trig = flags.has_sin || flags.has_tan || flags.has_cot
  let has_s_dependent_trig = expr_has_s_dependent_trig(expr, s_name)
  if flags.has_gamma {
    if has_s_dependent_trig {
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
      match inverse_mellin_besselj_bessely_product_term(expr, s_sym, x) {
        Some(v) => return Some(v)
        None => ()
      }
    } else {
      match inverse_mellin_gamma_linear_term(expr, s_sym, x) {
        Some(v) => return Some(v)
        None => ()
      }
      match inverse_mellin_named_gamma_ratio_term(expr, s_sym, x) {
        Some(v) => return Some(v)
        None => ()
      }
      match inverse_mellin_named_gamma_product_term(expr, s_sym, x) {
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
      match inverse_mellin_besselj_product_term(expr, s_sym, x) {
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
    }
  }
  if has_gamma_like && !has_s_dependent_trig {
    match inverse_mellin_multiplicative_substitution_term(expr, s_sym, x) {
      Some(v) => return Some(v)
      None => ()
    }
  }
  if !has_gamma_like && !has_piecewise_trig && !flags.has_cos {
    match inverse_mellin_log_power_term(expr, s_sym, x) {
      Some(v) => return Some(v)
      None => ()
    }
  }
  if has_piecewise_trig && !has_gamma_like {
    match inverse_mellin_piecewise_log_term(expr, s_sym, x) {
      Some(v) => return Some(v)
      None => ()
    }
  }
  if flags.has_cos {
    let sec_formula = expr_div(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
      @symelem.cos(
        expr_mul(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
          s_sym,
        ),
      ),
    )
    if expr_eq(expr, expr_simplify(sec_formula)) {
      return Some(expr_div(@symelem.sqrt(x), expr_add(x, @symcore.int(1))))
    }
  }
  if flags.has_sin {
    let log_quadratic_formula = expr_div(
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
      expr_mul(
        s_sym,
        @symelem.sin(
          expr_div(
            expr_mul(
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
              s_sym,
            ),
            @symcore.int(2),
          ),
        ),
      ),
    )
    if expr_eq(expr, expr_simplify(log_quadratic_formula)) {
      return Some(
        @symelem.log(expr_add(expr_pow(x, @symcore.int(2)), @symcore.int(1))),
      )
    }
  }
  None
}

///|
fn expr_has_s_dependent_trig(expr : Expr, s_name : String) -> Bool {
  match expr {
    @symcore.Expr::Function(name, args) => {
      if name == "sin" || name == "cos" || name == "tan" || name == "cot" {
        if expr_depends_on(expr, s_name) {
          return true
        }
      }
      for arg in args {
        if expr_has_s_dependent_trig(arg, s_name) {
          return true
        }
      }
      false
    }
    @symcore.Expr::Apply(head, args) => {
      match @symcore.function_head_name(head) {
        Some("sin") | Some("cos") | Some("tan") | Some("cot") =>
          if expr_depends_on(expr, s_name) {
            return true
          }
        _ => ()
      }
      if expr_has_s_dependent_trig(head, s_name) {
        return true
      }
      for arg in args {
        if expr_has_s_dependent_trig(arg, s_name) {
          return true
        }
      }
      false
    }
    @symcore.Expr::Add(args)
    | @symcore.Expr::Mul(args)
    | @symcore.Expr::Tuple(args) => {
      for arg in args {
        if expr_has_s_dependent_trig(arg, s_name) {
          return true
        }
      }
      false
    }
    @symcore.Expr::Pow(base, exp)
    | @symcore.Expr::Mod(base, exp)
    | @symcore.Expr::Relational(_, base, exp) =>
      expr_has_s_dependent_trig(base, s_name) ||
      expr_has_s_dependent_trig(exp, s_name)
    @symcore.Expr::Dict(items) => {
      for item in items {
        let (key, value) = item
        if expr_has_s_dependent_trig(key, s_name) ||
          expr_has_s_dependent_trig(value, s_name) {
          return true
        }
      }
      false
    }
    @symcore.Expr::Derivative(inner, args) => {
      if expr_has_s_dependent_trig(inner, s_name) {
        return true
      }
      for arg in args {
        if expr_has_s_dependent_trig(arg, s_name) {
          return true
        }
      }
      false
    }
    @symcore.Expr::Subs(inner, variable, value) =>
      expr_has_s_dependent_trig(inner, s_name) ||
      expr_has_s_dependent_trig(variable, s_name) ||
      expr_has_s_dependent_trig(value, s_name)
    @symcore.Expr::Lambda(vars, body) =>
      expr_has_s_dependent_trig(vars, s_name) ||
      expr_has_s_dependent_trig(body, s_name)
    _ => false
  }
}

///|
fn inverse_mellin_named_gamma_ratio_term(
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
    Some(value) => value
    None => return None
  }
  let numerator = factors_expr(num)
  let (coeff, factors) = split_mul(numerator, s_name)
  if factors.length() != 1 {
    return None
  }
  let gamma_arg = match unary_application_arg(factors[0], "gamma") {
    Some(arg) => arg
    None => return None
  }
  if expr_eq(coeff, @symcore.int(1)) && expr_eq(gamma_arg, s_sym) {
    match linear_coeffs(den, s_name) {
      Some((den_coeff, den_offset)) if expr_eq(den_coeff, @symcore.int(1)) =>
        if expr_eq(den_offset, @symcore.int(0)) {
          return Some(@symspec.e1(x))
        } else if expr_eq(den_offset, @symcore.int(1)) {
          return Some(@symspec.expint(@symcore.int(2), x))
        }
      _ => ()
    }
  }
  if expr_eq(coeff, @symcore.int(-1)) &&
    expr_same_simplified(gamma_arg, expr_add(s_sym, expr_rat(1, 2))) {
    let den_factors = expr_factors(den)
    if den_factors.length() == 2 {
      let saw_s = expr_eq(den_factors[0], s_sym) ||
        expr_eq(den_factors[1], s_sym)
      let saw_sqrt_pi = expr_is_sqrt_pi(den_factors[0]) ||
        expr_is_sqrt_pi(den_factors[1])
      if saw_s && saw_sqrt_pi {
        return Some(@symspec.erf(@symelem.sqrt(x)))
      }
    }
  }
  None
}

///|
fn inverse_mellin_named_gamma_product_term(
  expr : Expr,
  s_sym : Expr,
  x : Expr,
) -> Expr? {
  if symbol_name(s_sym) is None {
    return None
  }
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(value) => value
    None => return None
  }
  let mut coeff = @symcore.int(1)
  let mut saw_sqrt_pi = false
  let mut power_two_exp : Expr? = None
  let mut gamma_num_arg : Expr? = None
  for factor in expr_factors(factors_expr(num)) {
    match factor {
      @symcore.Expr::Pow(base, exp) if expr_eq(base, @symcore.int(2)) =>
        if power_two_exp is None {
          power_two_exp = Some(exp)
        } else {
          return None
        }
      _ =>
        match unary_application_arg(factor, "gamma") {
          Some(arg) =>
            if gamma_num_arg is None {
              gamma_num_arg = Some(arg)
            } else {
              return None
            }
          None =>
            if expr_is_sqrt_pi(factor) {
              saw_sqrt_pi = true
            } else {
              coeff = expr_mul(coeff, factor)
            }
        }
    }
  }
  let power_two_exp = match power_two_exp {
    Some(value) => value
    None => return None
  }
  let gamma_num_arg = match gamma_num_arg {
    Some(value) => value
    None => return None
  }
  if !saw_sqrt_pi || !expr_same_simplified(coeff, @symcore.int(-1)) {
    return None
  }
  let mut den_coeff = @symcore.int(1)
  let mut saw_s = false
  let mut gamma_den_arg : Expr? = None
  for factor in expr_factors(den) {
    if expr_eq(factor, s_sym) {
      saw_s = true
    } else {
      match unary_application_arg(factor, "gamma") {
        Some(arg) =>
          if gamma_den_arg is None {
            gamma_den_arg = Some(arg)
          } else {
            return None
          }
        None => den_coeff = expr_mul(den_coeff, factor)
      }
    }
  }
  let gamma_den_arg = match gamma_den_arg {
    Some(value) => value
    None => return None
  }
  if !saw_s {
    return None
  }
  if expr_same_simplified(power_two_exp, s_sym) &&
    expr_same_simplified(den_coeff, @symcore.int(2)) &&
    expr_same_simplified(
      gamma_num_arg,
      expr_div(expr_add(s_sym, @symcore.int(1)), @symcore.int(2)),
    ) &&
    expr_same_simplified(
      gamma_den_arg,
      expr_sub(@symcore.int(1), expr_div(s_sym, @symcore.int(2))),
    ) {
    return Some(@symspec.si(x))
  }
  if expr_same_simplified(
      power_two_exp,
      expr_sub(expr_mul(@symcore.int(2), s_sym), @symcore.int(1)),
    ) &&
    expr_same_simplified(den_coeff, @symcore.int(1)) &&
    expr_eq(gamma_num_arg, s_sym) &&
    expr_same_simplified(gamma_den_arg, expr_sub(expr_rat(1, 2), s_sym)) {
    return Some(@symspec.ci(@symelem.sqrt(x)))
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
      _ if unary_application_arg(factor, "gamma") is Some(arg) =>
        gamma_args.push(arg)
      @symcore.Expr::Pow(base, exp) if !expr_depends_on(base, s_name) =>
        match parse_linear_offset_expr(exp, s_name) {
          Some((coeff, _)) if expr_same_simplified(coeff, @symcore.int(1)) =>
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
    if expr_same_simplified(item.0, @symcore.int(1)) &&
      expr_same_simplified(item.1, @symcore.int(0)) {
      saw_gamma_s = true
    } else if expr_same_simplified(item.0, @symcore.int(1)) {
      power = Some(item.1)
    } else if expr_same_simplified(item.0, @symcore.int(-1)) &&
      expr_same_simplified(item.1, @symcore.int(1)) {
      saw_gamma_one_minus_s = true
    } else if expr_same_simplified(item.0, @symcore.int(-1)) {
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
      one_minus_power.unwrap_or(@symcore.int(0)),
      expr_sub(@symcore.int(1), power),
    ) {
    return None
  }
  let expected = expr_simplify(
    expr_div(
      expr_mul(
        expr_pow(scale, expr_add(expr_sub(s_sym, @symcore.int(1)), power)),
        expr_mul(
          @symelem.sin(
            expr_mul(
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
              power,
            ),
          ),
          expr_mul(
            @symspec.gamma(s_sym),
            expr_mul(
              @symspec.gamma(expr_add(s_sym, power)),
              expr_mul(
                @symspec.gamma(expr_sub(@symcore.int(1), s_sym)),
                @symspec.gamma(
                  expr_sub(expr_sub(@symcore.int(1), s_sym), power),
                ),
              ),
            ),
          ),
        ),
      ),
      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
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
    if unary_application_arg(factor, "gamma") is Some(arg) {
      gamma_num_args.push(arg)
    } else {
      match pow_named_unary_application(factor) {
        Some(("gamma", arg, exp)) =>
          if expr_same_simplified(exp, @symcore.int(-1)) {
            gamma_den_args.push(arg)
          } else {
            return None
          }
        _ =>
          match factor {
            @symcore.Expr::Pow(base, exp) if !expr_depends_on(base, s_name) =>
              match parse_linear_offset_expr(exp, s_name) {
                Some((coeff, _)) if expr_same_simplified(coeff, @symcore.int(2)) &&
                  !expr_same_simplified(base, @symcore.int(2)) =>
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
    if expr_same_simplified(item.0, @symcore.int(1)) &&
      expr_same_simplified(item.1, @symcore.int(0)) {
      saw_gamma_s = true
    } else if expr_same_simplified(item.0, @symcore.int(-2)) {
      double_linear = Some(item)
    } else {
      return None
    }
  }
  let offset = match double_linear {
    Some((_, offset)) => offset
    _ => return None
  }
  if !saw_gamma_s || !expr_same_simplified(den_linear.0, @symcore.int(-1)) {
    return None
  }
  let power = if expr_same_simplified(den_linear.1, offset) {
    expr_sub(@symcore.int(1), offset)
  } else if expr_same_simplified(
      den_linear.1,
      expr_add(offset, @symcore.int(1)),
    ) {
    expr_mul(@symcore.int(-1), offset)
  } else {
    return None
  }
  let shift = expr_add(x, expr_pow(scale, @symcore.int(2)))
  let base = expr_add(@symelem.sqrt(shift), scale)
  let denominator_offset = expr_add(offset, @symcore.int(1))
  Some(
    expr_simplify(
      if expr_same_simplified(den_linear.1, denominator_offset) {
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
    simplified =>
      match unary_application_arg(simplified, "gamma") {
        Some(arg) =>
          match split_linear_coeff(arg, s_name) {
            Some((coeff, offset)) if !expr_depends_on(offset, s_name) =>
              if expr_is_one(coeff) {
                let xpow = if expr_is_zero(offset) {
                  @symcore.int(1)
                } else {
                  expr_pow(x, offset)
                }
                Some(
                  expr_mul(xpow, @symelem.exp(expr_mul(@symcore.int(-1), x))),
                )
              } else if expr_is_minus_one(coeff) {
                let xpow = if expr_is_zero(offset) {
                  @symcore.int(1)
                } else {
                  expr_pow(x, expr_mul(@symcore.int(-1), offset))
                }
                Some(
                  expr_mul(xpow, @symelem.exp(expr_div(@symcore.int(-1), x))),
                )
              } else {
                None
              }
            _ => None
          }
        None => None
      }
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
  let expr_simplified = expr_simplify(expr)
  let mut beta_const : Expr? = None
  for factor in num_factors {
    match factor {
      _ if unary_application_arg(factor, "gamma") is Some(arg) =>
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
      if expr_eq(expr_simplified, left_formula) {
        Some(
          expr_mul(
            expr_pow(
              expr_sub(@symcore.int(1), x),
              expr_sub(beta, @symcore.int(1)),
            ),
            @symspec.heaviside(expr_sub(@symcore.int(1), x)),
          ),
        )
      } else {
        let right_formula = expr_simplify(
          @symspec.gamma(beta) *
          @symspec.gamma(@symcore.int(1) - beta - s_sym) *
          (@symspec.gamma(@symcore.int(1) - s_sym) ^ @symcore.int(-1)),
        )
        if expr_eq(expr_simplified, right_formula) {
          Some(
            expr_mul(
              expr_pow(
                expr_sub(x, @symcore.int(1)),
                expr_sub(beta, @symcore.int(1)),
              ),
              @symspec.heaviside(expr_sub(x, @symcore.int(1))),
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
  let rho = match unary_application_arg(den_factors[0], "gamma") {
    Some(arg) if !expr_depends_on(arg, s_name) => arg
    _ => return None
  }
  let mut has_gamma_s = false
  let mut has_gamma_rho_minus_s = false
  for factor in num_factors {
    match factor {
      _ if unary_application_arg(factor, "gamma") is Some(arg) =>
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
    Some(
      expr_pow(expr_add(x, @symcore.int(1)), expr_mul(@symcore.int(-1), rho)),
    )
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
              Some((coeff, offset)) if expr_same_simplified(
                  offset,
                  @symcore.int(0),
                ) =>
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
  if !expr_same_simplified(den_coeff, @symcore.int(1)) ||
    !expr_same_simplified(
      expr_sub(gamma_offset, @symcore.int(1)),
      expr_mul(den_offset, gamma_coeff),
    ) {
    return None
  }
  let scale = match scale_info {
    Some((base, coeff)) =>
      if expr_same_simplified(coeff, expr_mul(@symcore.int(-1), gamma_coeff)) {
        base
      } else {
        return None
      }
    None => @symcore.int(1)
  }
  let power = expr_simplify(expr_div(@symcore.int(1), gamma_coeff))
  let xpow = if expr_same_simplified(den_offset, @symcore.int(0)) {
    @symcore.int(1)
  } else {
    expr_pow(x, den_offset)
  }
  let exp_arg = expr_mul(@symcore.int(-1), expr_mul(scale, expr_pow(x, power)))
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
  let factorial = factorial_expr(@symcore.int(n))
  let log_pow = if n == 1 {
    @symelem.log(x)
  } else {
    expr_pow(@symelem.log(x), @symcore.int(n))
  }
  let left_coeff = expr_simplify(
    if n % 2 == 0 {
      factorial
    } else {
      expr_mul(@symcore.int(-1), factorial)
    },
  )
  let right_coeff = expr_simplify(expr_mul(@symcore.int(-1), left_coeff))
  let coeff_simplified = expr_simplify(coeff)
  if expr_eq(coeff_simplified, left_coeff) {
    Some(expr_mul(log_pow, @symspec.heaviside(expr_sub(@symcore.int(1), x))))
  } else if expr_eq(coeff_simplified, right_coeff) {
    Some(expr_mul(log_pow, @symspec.heaviside(expr_sub(x, @symcore.int(1)))))
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
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  let one = @symcore.int(1)
  if inverse_mellin_matches_pi_over_s_trig(expr, s_sym, "sin", @symcore.int(1)) {
    return Some(
      expr_simplify(
        expr_add(
          expr_mul(
            @symelem.log(expr_add(one, x)),
            @symspec.heaviside(expr_sub(one, x)),
          ),
          expr_mul(
            @symelem.log(expr_add(one, expr_pow(x, @symcore.int(-1)))),
            @symspec.heaviside(expr_sub(x, one)),
          ),
        ),
      ),
    )
  }
  if inverse_mellin_matches_pi_over_s_trig(expr, s_sym, "sin", @symcore.int(2)) {
    let sqrt_x = @symelem.sqrt(x)
    return Some(
      expr_simplify(
        expr_add(
          expr_mul(
            @symelem.log(expr_add(one, sqrt_x)),
            @symspec.heaviside(expr_sub(one, x)),
          ),
          expr_mul(
            @symelem.log(expr_add(one, expr_pow(sqrt_x, @symcore.int(-1)))),
            @symspec.heaviside(expr_sub(x, one)),
          ),
        ),
      ),
    )
  }
  if inverse_mellin_matches_pi_over_s_trig(expr, s_sym, "tan", @symcore.int(1)) ||
    inverse_mellin_matches_pi_cot_over_s(expr, s_sym) {
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
  let expr_simplified = expr_simplify(expr)
  let sin_pi_formula = expr_div(
    pi,
    expr_mul(s_sym, @symelem.sin(expr_mul(pi, s_sym))),
  )
  if expr_eq(expr_simplified, expr_simplify(sin_pi_formula)) {
    return Some(
      expr_simplify(
        expr_add(
          expr_mul(
            @symelem.log(expr_add(one, x)),
            @symspec.heaviside(expr_sub(one, x)),
          ),
          expr_mul(
            @symelem.log(expr_add(one, expr_pow(x, @symcore.int(-1)))),
            @symspec.heaviside(expr_sub(x, one)),
          ),
        ),
      ),
    )
  }
  let sin_two_pi_formula = expr_div(
    pi,
    expr_mul(
      s_sym,
      @symelem.sin(expr_mul(@symcore.int(2), expr_mul(pi, s_sym))),
    ),
  )
  if expr_eq(expr_simplified, expr_simplify(sin_two_pi_formula)) {
    let sqrt_x = @symelem.sqrt(x)
    return Some(
      expr_simplify(
        expr_add(
          expr_mul(
            @symelem.log(expr_add(one, sqrt_x)),
            @symspec.heaviside(expr_sub(one, x)),
          ),
          expr_mul(
            @symelem.log(expr_add(one, expr_pow(sqrt_x, @symcore.int(-1)))),
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
  if expr_eq(expr_simplified, expr_simplify(tan_formula)) ||
    expr_eq(expr_simplified, expr_simplify(cot_formula)) {
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
fn inverse_mellin_pi_s_arg(s_sym : Expr, scale : Expr) -> Expr {
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  if expr_eq(scale, @symcore.int(1)) {
    expr_mul(pi, s_sym)
  } else {
    expr_mul(scale, expr_mul(pi, s_sym))
  }
}

///|
fn inverse_mellin_matches_pi_over_s_trig(
  expr : Expr,
  s_sym : Expr,
  trig_name : String,
  scale : Expr,
) -> Bool {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(value) => value
    None => return false
  }
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  if !expr_same_simplified(factors_expr(num), pi) {
    return false
  }
  let target_arg = inverse_mellin_pi_s_arg(s_sym, scale)
  let den_factors = expr_factors(den)
  if den_factors.length() != 2 {
    return false
  }
  let mut saw_s = false
  let mut saw_trig = false
  for factor in den_factors {
    if expr_eq(factor, s_sym) {
      saw_s = true
    } else {
      match unary_application_arg(factor, trig_name) {
        Some(arg) if expr_same_simplified(arg, target_arg) => saw_trig = true
        _ => ()
      }
    }
  }
  saw_s && saw_trig
}

///|
fn inverse_mellin_matches_pi_cot_over_s(expr : Expr, s_sym : Expr) -> Bool {
  let (num, den_opt) = split_division(expr)
  let den = match den_opt {
    Some(value) => value
    None => return false
  }
  if !expr_eq(den, s_sym) {
    return false
  }
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  let target_arg = inverse_mellin_pi_s_arg(s_sym, @symcore.int(1))
  let num_factors = expr_factors(factors_expr(num))
  if num_factors.length() != 2 {
    return false
  }
  let mut saw_pi = false
  let mut saw_cot = false
  for factor in num_factors {
    if expr_same_simplified(factor, pi) {
      saw_pi = true
    } else {
      match unary_application_arg(factor, "cot") {
        Some(arg) if expr_same_simplified(arg, target_arg) => saw_cot = true
        _ => ()
      }
    }
  }
  saw_pi && saw_cot
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
  let factors = match expr_factors(expr) {
    [single] if @symcore.compare_expr(single, expr) == 0 => return None
    args => args
  }
  let mut coeff = @symcore.int(1)
  let gamma_num_args : Array[Expr] = []
  let gamma_den_args : Array[Expr] = []
  for factor in factors {
    if unary_application_arg(factor, "gamma") is Some(arg) {
      gamma_num_args.push(arg)
    } else {
      match pow_named_unary_application(factor) {
        Some(("gamma", arg, exp)) =>
          if expr_eq(exp, @symcore.int(-1)) {
            gamma_den_args.push(arg)
          } else {
            return None
          }
        _ =>
          match factor {
            @symcore.Expr::Pow(@symcore.Expr::Mul(items), exp) =>
              if expr_eq(exp, @symcore.int(-1)) {
                for item in items {
                  match unary_application_arg(item, "gamma") {
                    Some(arg) => gamma_den_args.push(arg)
                    None =>
                      if expr_depends_on(item, s_name) {
                        return None
                      } else {
                        coeff = expr_mul(
                          coeff,
                          expr_pow(item, @symcore.int(-1)),
                        )
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
    }
  }
  if gamma_num_args.length() != 2 || gamma_den_args.length() != 2 {
    return None
  }
  let order = match parse_power_of_two(coeff, s_name) {
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
  if has_linear_offset(num_linears, @symcore.int(-2), fn(offset) {
      expr_same_simplified(expr_mul(@symcore.int(2), offset), @symcore.int(1))
    }) &&
    has_linear_offset(num_linears, @symcore.int(1), fn(offset) {
      expr_same_simplified(
        expr_mul(@symcore.int(2), offset),
        expr_add(order, @symcore.int(1)),
      )
    }) &&
    has_linear_offset(den_linears, @symcore.int(-1), fn(offset) {
      expr_same_simplified(
        offset,
        expr_sub(@symcore.int(1), expr_mul(expr_rat(1, 2), order)),
      )
    }) &&
    has_linear_offset(den_linears, @symcore.int(-2), fn(offset) {
      expr_same_simplified(offset, expr_add(order, @symcore.int(1)))
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
  if has_linear_offset(num_linears, @symcore.int(-2), fn(offset) {
      expr_same_simplified(expr_mul(@symcore.int(2), offset), @symcore.int(1))
    }) &&
    has_linear_offset(num_linears, @symcore.int(1), fn(offset) {
      expr_same_simplified(expr_mul(@symcore.int(2), offset), order)
    }) &&
    has_linear_offset(den_linears, @symcore.int(-1), fn(offset) {
      expr_same_simplified(
        offset,
        expr_sub(expr_rat(1, 2), expr_mul(expr_rat(1, 2), order)),
      )
    }) &&
    has_linear_offset(den_linears, @symcore.int(-2), fn(offset) {
      expr_same_simplified(offset, expr_add(order, @symcore.int(1)))
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
  let factors = match expr_factors(expr) {
    [single] if @symcore.compare_expr(single, expr) == 0 => return None
    args => args
  }
  let mut coeff = @symcore.int(1)
  let mut s_scale = @symcore.int(1)
  let mut trig_info : (String, Int, Expr)? = None
  let gamma_num_args : Array[Expr] = []
  let gamma_den_args : Array[Expr] = []
  for factor in factors {
    if unary_application_arg(factor, "gamma") is Some(arg) {
      gamma_num_args.push(arg)
    } else {
      match pow_named_unary_application(factor) {
        Some(("gamma", arg, exp)) =>
          if expr_eq(exp, @symcore.int(-1)) {
            gamma_den_args.push(arg)
          } else {
            return None
          }
        _ =>
          match factor {
            @symcore.Expr::Pow(@symcore.Expr::Mul(items), exp) =>
              if expr_eq(exp, @symcore.int(-1)) {
                for item in items {
                  match unary_application_arg(item, "gamma") {
                    Some(arg) => gamma_den_args.push(arg)
                    None =>
                      if expr_depends_on(item, s_name) {
                        return None
                      } else {
                        coeff = expr_mul(
                          coeff,
                          expr_pow(item, @symcore.int(-1)),
                        )
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
                return None
              } else {
                coeff = expr_mul(coeff, factor)
              }
            _ =>
              match named_application(factor) {
                Some((name, _)) if name == "sin" || name == "cos" =>
                  match parse_pi_linear_trig_factor(factor, s_name, name) {
                    Some((trig_coeff, trig_offset)) =>
                      if trig_info is None {
                        trig_info = Some((name, trig_coeff, trig_offset))
                      } else {
                        return None
                      }
                    None => return None
                  }
                Some(_) =>
                  if expr_depends_on(factor, s_name) {
                    return None
                  } else {
                    coeff = expr_mul(coeff, factor)
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
    }
  }
  if gamma_num_args.length() != 3 || gamma_den_args.length() != 2 {
    return None
  }
  if !expr_same_simplified(s_scale, expr_pow(@symcore.int(4), s_sym)) ||
    !expr_same_simplified(
      coeff,
      expr_mul(@symcore.int(-1), expr_div(@symcore.int(1), sqrt_pi())),
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
  let half_order = expr_simplify(
    expr_mul(@symcore.int(-1 * trig_coeff), trig_offset),
  )
  let order = expr_simplify(expr_mul(@symcore.int(2), half_order))
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
  let saw_gamma_half_minus_2s = has_linear_offset(
    num_linears,
    @symcore.int(-2),
    fn(offset) { expr_same_simplified(offset, half) },
  )
  if saw_gamma_half_minus_2s {
    let expected_sin_pos = expr_simplify(expr_add(half, half_order))
    let expected_sin_neg = expr_simplify(expr_sub(half, half_order))
    let expected_den_sin_pos = expr_simplify(
      expr_add(@symcore.int(1), half_order),
    )
    let expected_den_sin_neg = expr_simplify(
      expr_sub(@symcore.int(1), half_order),
    )
    let expected_den_cos_pos = expr_simplify(expr_add(half, half_order))
    let expected_den_cos_neg = expr_simplify(expr_sub(half, half_order))
    let ok = match trig_name {
      "sin" =>
        has_linear_offset(num_linears, @symcore.int(1), fn(offset) {
          expr_same_simplified(offset, expected_sin_pos)
        }) &&
        has_linear_offset(num_linears, @symcore.int(1), fn(offset) {
          expr_same_simplified(offset, expected_sin_neg)
        }) &&
        has_linear_offset(den_linears, @symcore.int(-1), fn(offset) {
          expr_same_simplified(offset, expected_den_sin_pos)
        }) &&
        has_linear_offset(den_linears, @symcore.int(-1), fn(offset) {
          expr_same_simplified(offset, expected_den_sin_neg)
        })
      "cos" =>
        has_linear_offset(num_linears, @symcore.int(1), fn(offset) {
          expr_same_simplified(offset, half_order)
        }) &&
        has_linear_offset(num_linears, @symcore.int(1), fn(offset) {
          expr_same_simplified(offset, expr_mul(@symcore.int(-1), half_order))
        }) &&
        has_linear_offset(den_linears, @symcore.int(-1), fn(offset) {
          expr_same_simplified(offset, expected_den_cos_pos)
        }) &&
        has_linear_offset(den_linears, @symcore.int(-1), fn(offset) {
          expr_same_simplified(offset, expected_den_cos_neg)
        })
      _ => false
    }
    if ok {
      let body = @symspec.bessely(order, @symelem.sqrt(x))
      return Some(
        expr_simplify(
          match trig_name {
            "sin" => expr_mul(@symelem.sin(@symelem.sqrt(x)), body)
            "cos" => expr_mul(@symelem.cos(@symelem.sqrt(x)), body)
            _ => body
          },
        ),
      )
    }
  }
  let sin_formula = expr_simplify(
    expr_mul(
      expr_mul(
        @symcore.int(-1),
        expr_pow(
          @symelem.sqrt(
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
          ),
          @symcore.int(-1),
        ),
      ),
      expr_mul(
        expr_pow(@symcore.int(4), s_sym),
        expr_mul(
          @symelem.sin(
            expr_mul(
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
              expr_sub(expr_mul(order, half), s_sym),
            ),
          ),
          expr_mul(
            @symspec.gamma(expr_sub(half, expr_mul(@symcore.int(2), s_sym))),
            expr_mul(
              @symspec.gamma(
                expr_add(
                  expr_mul(expr_sub(@symcore.int(1), order), half),
                  s_sym,
                ),
              ),
              expr_mul(
                @symspec.gamma(
                  expr_add(
                    expr_mul(expr_add(@symcore.int(1), order), half),
                    s_sym,
                  ),
                ),
                expr_mul(
                  expr_pow(
                    @symspec.gamma(
                      expr_sub(
                        expr_sub(@symcore.int(1), s_sym),
                        expr_mul(order, half),
                      ),
                    ),
                    @symcore.int(-1),
                  ),
                  expr_pow(
                    @symspec.gamma(
                      expr_add(
                        expr_sub(@symcore.int(1), s_sym),
                        expr_mul(order, half),
                      ),
                    ),
                    @symcore.int(-1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  )
  if expr_same_simplified(expr, sin_formula) {
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
        @symcore.int(-1),
        expr_pow(
          @symelem.sqrt(
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
          ),
          @symcore.int(-1),
        ),
      ),
      expr_mul(
        expr_pow(@symcore.int(4), s_sym),
        expr_mul(
          @symelem.cos(
            expr_mul(
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
              expr_sub(expr_mul(order, half), s_sym),
            ),
          ),
          expr_mul(
            @symspec.gamma(expr_sub(s_sym, expr_mul(order, half))),
            expr_mul(
              @symspec.gamma(expr_add(s_sym, expr_mul(order, half))),
              expr_mul(
                @symspec.gamma(expr_sub(half, expr_mul(@symcore.int(2), s_sym))),
                expr_mul(
                  expr_pow(
                    @symspec.gamma(
                      expr_sub(expr_sub(half, s_sym), expr_mul(order, half)),
                    ),
                    @symcore.int(-1),
                  ),
                  expr_pow(
                    @symspec.gamma(
                      expr_add(expr_sub(half, s_sym), expr_mul(order, half)),
                    ),
                    @symcore.int(-1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  )
  if expr_same_simplified(expr, cos_formula) {
    return Some(
      expr_simplify(
        expr_mul(
          @symelem.cos(@symelem.sqrt(x)),
          @symspec.bessely(order, @symelem.sqrt(x)),
        ),
      ),
    )
  }
  None
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
  let factors = match expr_factors(expr) {
    [single] if @symcore.compare_expr(single, expr) == 0 => return None
    args => args
  }
  let mut coeff = @symcore.int(1)
  let mut s_scale = @symcore.int(1)
  let gamma_num_args : Array[Expr] = []
  let gamma_den_args : Array[Expr] = []
  let extra_linears : Array[(Expr, Expr)] = []
  for factor in factors {
    match factor {
      _ if unary_application_arg(factor, "gamma") is Some(arg) =>
        gamma_num_args.push(arg)
      _ =>
        match pow_named_unary_application(factor) {
          Some(("gamma", arg, exp)) =>
            if expr_eq(exp, @symcore.int(-1)) {
              gamma_den_args.push(arg)
            } else {
              return None
            }
          _ =>
            match factor {
              @symcore.Expr::Pow(@symcore.Expr::Mul(items), exp) =>
                if expr_eq(exp, @symcore.int(-1)) {
                  for item in items {
                    match unary_application_arg(item, "gamma") {
                      Some(arg) => gamma_den_args.push(arg)
                      None =>
                        if expr_depends_on(item, s_name) {
                          return None
                        } else {
                          coeff = expr_mul(
                            coeff,
                            expr_pow(item, @symcore.int(-1)),
                          )
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
  if expr_same_simplified(s_scale, @symcore.int(1)) &&
    gamma_den_args.length() == 2 &&
    expr_same_simplified(coeff, expr_div(@symcore.int(1), sqrt_pi())) {
    match inverse_mellin_same_order_besselj_product(num_linears, den_linears) {
      Some(order) =>
        return Some(
          expr_simplify(
            expr_pow(@symspec.besselj(order, sqrt_x), @symcore.int(2)),
          ),
        )
      None => ()
    }
    match inverse_mellin_pm_order_besselj_product(num_linears, den_linears) {
      Some(order) =>
        return Some(
          expr_simplify(
            expr_mul(
              @symspec.besselj(expr_mul(@symcore.int(-1), order), sqrt_x),
              @symspec.besselj(order, sqrt_x),
            ),
          ),
        )
      None => ()
    }
  }
  if expr_same_simplified(s_scale, expr_pow(@symcore.int(4), s_sym)) &&
    gamma_den_args.length() == 3 &&
    expr_same_simplified(coeff, @symcore.int(1)) {
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
  let mut coeff = @symcore.int(1)
  let mut s_scale = @symcore.int(1)
  let mut trig_info : (Int, Expr)? = None
  let gamma_num_args : Array[Expr] = []
  let gamma_den_args : Array[Expr] = []
  let extra_linears : Array[(Expr, Expr)] = []
  for factor in factors {
    if unary_application_arg(factor, "gamma") is Some(arg) {
      gamma_num_args.push(arg)
    } else {
      match pow_named_unary_application(factor) {
        Some(("gamma", arg, exp)) =>
          if expr_eq(exp, @symcore.int(-1)) {
            gamma_den_args.push(arg)
          } else {
            return None
          }
        _ =>
          match factor {
            @symcore.Expr::Pow(@symcore.Expr::Mul(items), exp) =>
              if expr_eq(exp, @symcore.int(-1)) {
                for item in items {
                  match unary_application_arg(item, "gamma") {
                    Some(arg) => gamma_den_args.push(arg)
                    None =>
                      if expr_depends_on(item, s_name) {
                        return None
                      } else {
                        coeff = expr_mul(
                          coeff,
                          expr_pow(item, @symcore.int(-1)),
                        )
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
            _ =>
              if @symcore.application_has_name(factor, "cos") {
                match parse_pi_linear_trig_factor(factor, s_name, "cos") {
                  Some(info) =>
                    if trig_info is None {
                      trig_info = Some(info)
                    } else {
                      return None
                    }
                  None => return None
                }
              } else if expr_depends_on(factor, s_name) {
                match parse_linear_offset_expr(factor, s_name) {
                  Some(info) => extra_linears.push(info)
                  None => return None
                }
              } else {
                coeff = expr_mul(coeff, factor)
              }
          }
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
    expr_same_simplified(s_scale, @symcore.int(1)) &&
    expr_same_simplified(
      coeff,
      expr_mul(
        @symcore.int(-1),
        expr_mul(
          expr_pow(
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
            @symcore.int(-1),
          ),
          expr_div(@symcore.int(1), sqrt_pi()),
        ),
      ),
    ) &&
    trig_coeff == 1 &&
    expr_same_simplified(trig_shift, @symcore.int(0)) {
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
    !expr_same_simplified(s_scale, expr_pow(@symcore.int(4), s_sym)) ||
    !expr_same_simplified(
      coeff,
      expr_mul(
        @symcore.int(-1),
        expr_pow(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
          @symcore.int(-1),
        ),
      ),
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
    if expr_same_simplified(item.0, @symcore.int(1)) &&
      expr_same_simplified(item.1, @symcore.int(0)) {
      saw_zero_num = true
    } else if expr_same_simplified(item.0, @symcore.int(1)) {
      order = Some(item.1)
    } else if expr_same_simplified(item.0, @symcore.int(-1)) &&
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
  if !expr_same_simplified(den_linears[0].0, @symcore.int(-1)) ||
    !expr_same_simplified(den_linears[0].1, expr_add(order, @symcore.int(1))) {
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
    if expr_same_simplified(item.0, @symcore.int(1)) {
      order = Some(item.1)
    } else if expr_same_simplified(item.0, @symcore.int(-1)) &&
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
    if !expr_same_simplified(item.0, @symcore.int(-1)) {
      return None
    }
    if expr_same_simplified(item.1, @symcore.int(1)) {
      saw_one_den = true
    } else if expr_same_simplified(item.1, expr_add(order, @symcore.int(1))) {
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
    if expr_same_simplified(item.0, @symcore.int(1)) &&
      expr_same_simplified(item.1, @symcore.int(0)) {
      saw_zero_num = true
    } else if expr_same_simplified(item.0, @symcore.int(-1)) &&
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
    !expr_same_simplified(den_linears[0].0, @symcore.int(-1)) ||
    !expr_same_simplified(den_linears[1].0, @symcore.int(-1)) {
    return None
  }
  let offset1 = den_linears[0].1
  let offset2 = den_linears[1].1
  if !expr_same_simplified(expr_add(offset1, offset2), @symcore.int(2)) {
    return None
  }
  Some(expr_simplify(expr_sub(offset2, @symcore.int(1))))
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
    if expr_same_simplified(item.0, @symcore.int(-2)) &&
      expr_same_simplified(item.1, @symcore.int(1)) {
      saw_gamma_one_minus_2s = true
    } else if expr_same_simplified(item.0, @symcore.int(1)) {
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
  let sum_offset = expr_simplify(expr_add(@symcore.int(1), half_sum))
  for item in den_linears {
    if !expr_same_simplified(item.0, @symcore.int(-1)) {
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
  let diff_half = expr_simplify(expr_sub(diff_offsets[0], @symcore.int(1)))
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
    if expr_same_simplified(item.0, @symcore.int(-2)) &&
      expr_same_simplified(item.1, @symcore.int(1)) {
      saw_gamma_one_minus_2s = true
    } else if expr_same_simplified(item.0, @symcore.int(1)) {
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
  let expected_den1 = expr_simplify(expr_add(@symcore.int(1), half_diff))
  let expected_den2 = expr_simplify(expr_add(@symcore.int(1), half_sum))
  let mut saw_diff_den = false
  let mut saw_sum_den = false
  for item in den_linears {
    if !expr_same_simplified(item.0, @symcore.int(-1)) {
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
          expr_simplify(expr_add(current.1, @symcore.int(1))),
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
  let factors = match expr_factors(expr) {
    [a, b] => [a, b]
    _ => return None
  }
  let mut gamma_num : Expr? = None
  let mut gamma_den : Expr? = None
  for factor in factors {
    match factor {
      _ if unary_application_arg(factor, "gamma") is Some(arg) =>
        if gamma_num is None {
          gamma_num = Some(arg)
        } else {
          return None
        }
      _ =>
        match pow_named_unary_application(factor) {
          Some(("gamma", arg, exp)) =>
            if expr_eq(exp, @symcore.int(-1)) && gamma_den is None {
              gamma_den = Some(arg)
            } else {
              return None
            }
          _ => return None
        }
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
              @symcore.int(1),
            ) {
            None
          } else {
            let order = expr_simplify(expr_mul(@symcore.int(2), num_offset))
            if expr_depends_on(order, s_name) {
              None
            } else {
              Some(@symspec.besselj(order, @symcore.int(2) * @symelem.sqrt(x)))
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
  let factors = match expr_factors(expr) {
    [a, b] => [a, b]
    [a, b, c] => [a, b, c]
    _ => return None
  }
  let mut coeff = @symcore.int(1)
  let gamma_args : Array[Expr] = []
  let s_name = match symbol_name(s_sym) {
    Some(name) => name
    None => return None
  }
  for factor in factors {
    match factor {
      _ if unary_application_arg(factor, "gamma") is Some(arg) =>
        gamma_args.push(arg)
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
      if !expr_eq(expr_simplify(expr_add(offset1, offset2)), @symcore.int(0)) {
        None
      } else {
        let order = expr_simplify(expr_sub(offset2, offset1))
        if expr_depends_on(order, s_name) {
          None
        } else {
          Some(@symspec.besselk(order, @symcore.int(2) * @symelem.sqrt(x)))
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
            Some((term_sign, @symcore.int(0)))
          } else {
            Some((term_sign, expr_simplify(@symcore.add(offset_terms))))
          }
        None => None
      }
    }
    simplified =>
      match parse_unit_linear_var_term(simplified, var_name) {
        Some(term_sign) => Some((term_sign, @symcore.int(0)))
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
            Some((expr_simplify(term_coeff), @symcore.int(0)))
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
      let mut coeff_scale = @symcore.int(1)
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
        Some(term_coeff) => Some((expr_simplify(term_coeff), @symcore.int(0)))
        None => None
      }
  }
}

///|
fn parse_linear_var_coeff_raw(expr : Expr, var_name : String) -> Expr? {
  match expr {
    @symcore.Expr::Symbol(name) =>
      if name == var_name {
        Some(@symcore.int(1))
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
        Some(@symcore.int(1))
      } else {
        Some(expr_simplify(@symcore.mul(coeff_factors)))
      }
    }
    _ => None
  }
}

///|
fn parse_linear_var_coeff(expr : Expr, var_name : String) -> Expr? {
  retry_with_simplified(expr, expr => parse_linear_var_coeff_raw(expr, var_name))
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
  let factors = match expr_factors(expr) {
    [single] if @symcore.compare_expr(single, expr) == 0 => return None
    args => args
  }
  let mut coeff = @symcore.int(1)
  let mut trig_info : (Int, Expr)? = None
  let gamma_args : Array[Expr] = []
  for factor in factors {
    match factor {
      _ if unary_application_arg(factor, "gamma") is Some(arg) =>
        gamma_args.push(arg)
      _ =>
        if @symcore.application_has_name(factor, "cos") {
          match parse_pi_linear_trig_factor(factor, s_name, "cos") {
            Some(info) =>
              if trig_info is None {
                trig_info = Some(info)
              } else {
                return None
              }
            None => return None
          }
        } else {
          let other = factor
          if expr_depends_on(other, s_name) {
            return None
          } else {
            coeff = expr_mul(coeff, other)
          }
        }
    }
  }
  if gamma_args.length() != 2 ||
    !expr_same_simplified(
      coeff,
      expr_mul(
        @symcore.int(-1),
        expr_pow(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
          @symcore.int(-1),
        ),
      ),
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
      Some((linear, offset)) if expr_same_simplified(linear, @symcore.int(1)) =>
        if expr_same_simplified(offset, half_order) {
          saw_pos = true
        } else if expr_same_simplified(
            offset,
            expr_mul(@symcore.int(-1), half_order),
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
      expr_simplify(expr_mul(@symcore.int(-2 * trig_coeff), half_order)),
      @symcore.int(2) * @symelem.sqrt(x),
    ),
  )
}

///|
fn parse_gamma_like_linear_arg(expr : Expr, var_name : String) -> (Expr, Expr)? {
  retry_with_simplified(expr, expr => {
    match named_unary_application(expr) {
      Some(("gamma", arg)) => parse_linear_offset_expr(arg, var_name)
      Some(("factorial", arg)) =>
        match parse_linear_offset_expr(arg, var_name) {
          Some((coeff, offset)) =>
            Some((coeff, expr_simplify(expr_add(offset, @symcore.int(1)))))
          None => None
        }
      _ => None
    }
  })
}

///|
fn divide_by_pi_if_common(expr : Expr) -> Expr? {
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  retry_with_simplified(expr, expr => {
    match expr {
      expr if expr_same_simplified(expr, pi) => Some(@symcore.int(1))
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
          Some(@symcore.int(1))
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
  })
}

///|
fn parse_pi_linear_trig_factor(
  expr : Expr,
  var_name : String,
  trig_name : String,
) -> (Int, Expr)? {
  retry_with_simplified(expr, expr => {
    match named_unary_application(expr) {
      Some((name, arg)) if name == trig_name =>
        match divide_by_pi_if_common(arg) {
          Some(linear_arg) =>
            match parse_linear_offset_expr(linear_arg, var_name) {
              Some((coeff, offset)) if expr_same_simplified(
                  coeff,
                  @symcore.int(1),
                ) => Some((1, expr_simplify(offset)))
              Some((coeff, offset)) if expr_same_simplified(
                  coeff,
                  @symcore.int(-1),
                ) => Some((-1, expr_simplify(offset)))
              _ => None
            }
          None => None
        }
      _ => None
    }
  })
}

///|
fn parse_unit_linear_var_term_raw(expr : Expr, var_name : String) -> Int? {
  match expr {
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
          @symcore.int(1)
        } else {
          expr_simplify(@symcore.mul(coeff_factors))
        }
        if expr_eq(coeff, @symcore.int(1)) {
          Some(1)
        } else if expr_eq(coeff, @symcore.int(-1)) {
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
fn parse_unit_linear_var_term(expr : Expr, var_name : String) -> Int? {
  retry_with_simplified(expr, expr => {
    parse_unit_linear_var_term_raw(expr, var_name)
  })
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
  if @symcore.compare_expr(left, right) == 0 {
    true
  } else {
    let simplified_left = expr_simplify(left)
    @symcore.compare_expr(simplified_left, right) == 0 ||
    @symcore.compare_expr(simplified_left, expr_simplify(right)) == 0
  }
}

///|
fn parse_power_of_two_raw(expr : Expr, var_name : String) -> Expr? {
  if expr_depends_on(expr, var_name) {
    return None
  }
  if expr_eq(expr, @symcore.int(1)) {
    return Some(@symcore.int(0))
  }
  match expr {
    @symcore.Expr::Pow(base, exp) =>
      if expr_eq(base, @symcore.int(2)) && !expr_depends_on(exp, var_name) {
        Some(exp)
      } else {
        None
      }
    _ => None
  }
}

///|
fn parse_power_of_two(expr : Expr, var_name : String) -> Expr? {
  retry_with_simplified(expr, expr => parse_power_of_two_raw(expr, var_name))
}

///|
fn inverse_mellin_term(pow : Expr, is_le : Bool, x : Expr) -> Expr {
  let xpow = if expr_is_zero(pow) { @symcore.int(1) } else { expr_pow(x, pow) }
  if is_le {
    expr_mul(xpow, @symspec.heaviside(expr_sub(@symcore.int(1), x)))
  } else {
    expr_mul(xpow, @symspec.heaviside(expr_sub(x, @symcore.int(1))))
  }
}

///|
fn expr_factors(expr : Expr) -> Array[Expr] {
  match expr {
    @symcore.Expr::Mul(args) => args
    _ =>
      match expr_simplify(expr) {
        @symcore.Expr::Mul(args) => args
        simplified => [simplified]
      }
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
fn split_mul_raw(expr : Expr, var_name : String) -> (Expr, Array[Expr]) {
  match expr {
    @symcore.Expr::Mul(args) => {
      let mut coeff = @symcore.int(1)
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
      if expr_depends_on(expr, var_name) {
        (@symcore.int(1), [expr])
      } else {
        (expr, [])
      }
  }
}

///|
fn split_mul(expr : Expr, var_name : String) -> (Expr, Array[Expr]) {
  let direct = split_mul_raw(expr, var_name)
  if @symcore.compare_expr(direct.0, expr) != 0 ||
    direct.1.length() > 0 ||
    !expr_depends_on(expr, var_name) {
    direct
  } else {
    let simplified = expr_simplify(expr)
    if @symcore.compare_expr(simplified, expr) == 0 {
      direct
    } else {
      split_mul_raw(simplified, var_name)
    }
  }
}

///|
fn split_division_raw(expr : Expr) -> (Array[Expr], Expr?) {
  match expr {
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
    _ => ([expr], None)
  }
}

///|
fn split_division_raw_preserve_factors(
  expr : Expr,
) -> (Array[Expr], Expr?, Array[Expr]?) {
  match expr {
    @symcore.Expr::Pow(base, exp) if expr_is_int_value(exp) is Some(exp_int) &&
      exp_int < 0 => {
      let n = -exp_int
      let den_factor = if n == 1 { base } else { base ^ @symcore.int(n) }
      let den_factors = match den_factor {
        @symcore.Expr::Mul(args) => args
        _ => [den_factor]
      }
      ([], Some(factors_expr(den_factors)), Some(den_factors))
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
        (num, None, None)
      } else {
        (num, Some(factors_expr(den)), Some(den))
      }
    }
    _ => ([expr], None, None)
  }
}

///|
fn split_division(expr : Expr) -> (Array[Expr], Expr?) {
  let direct = split_division_raw(expr)
  if direct.1 is Some(_) {
    direct
  } else {
    let simplified = expr_simplify(expr)
    if @symcore.compare_expr(simplified, expr) == 0 {
      direct
    } else {
      split_division_raw(simplified)
    }
  }
}

///|
fn split_mul_factor(factors : Array[Expr], var_name : String) -> (Expr, Expr?) {
  let mut coeff = @symcore.int(1)
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
    @symcore.int(1)
  } else if factors.length() == 1 {
    factors[0]
  } else {
    expr_simplify(@symcore.mul(factors))
  }
}

///|
fn split_linear_coeff(expr : Expr, var_name : String) -> (Expr, Expr)? {
  match poly_coeffs_upto2(expr, var_name) {
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
fn split_linear_coeff_direct(expr : Expr, var_name : String) -> (Expr, Expr)? {
  match poly_coeffs_upto2_raw(expr, var_name) {
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
  retry_with_simplified(expr, expr => {
    match expr {
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
  })
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
  if !expr_same_simplified(den_coeff, @symcore.int(1)) {
    return None
  }
  let scale = expr_mul(@symcore.int(-1), den_offset)
  let num = factors_expr(num_factors)
  retry_with_simplified(num, num => {
    match num {
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
                      expr_mul(@symcore.int(-1), expr_pow(scale, p)),
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
  })
}

///|
fn parse_sqrt_shifted_base(expr : Expr, x_name : String) -> (Expr, Expr)? {
  retry_with_simplified(expr, expr => {
    match expr {
      @symcore.Expr::Add(args) if args.length() == 2 => {
        let mut scale : Expr? = None
        let mut shift_sq : Expr? = None
        for arg in args {
          match unary_application_arg(arg, "sqrt") {
            Some(inner) =>
              match split_linear_coeff(inner, x_name) {
                Some((coeff, offset)) if expr_same_simplified(
                    coeff,
                    @symcore.int(1),
                  ) &&
                  !expr_depends_on(offset, x_name) =>
                  if shift_sq is None {
                    shift_sq = Some(offset)
                  } else {
                    return None
                  }
                _ => return None
              }
            None =>
              if expr_depends_on(arg, x_name) {
                return None
              } else if scale is None {
                scale = Some(arg)
              } else {
                return None
              }
          }
        }
        match (scale, shift_sq) {
          (Some(v), Some(shift)) =>
            if expr_same_simplified(expr_pow(v, @symcore.int(2)), shift) ||
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
  })
}

///|
fn parse_reciprocal_sqrt_shift(expr : Expr, x_name : String) -> Expr? {
  retry_with_simplified(expr, expr => {
    match pow_named_unary_application(expr) {
      Some(("sqrt", inner, exp)) =>
        if expr_same_simplified(exp, @symcore.int(-1)) {
          match split_linear_coeff(inner, x_name) {
            Some((coeff, offset)) if expr_same_simplified(
                coeff,
                @symcore.int(1),
              ) &&
              !expr_depends_on(offset, x_name) => Some(offset)
            _ => None
          }
        } else {
          None
        }
      _ => None
    }
  })
}

///|
fn parse_sqrt_shifted_power_expr(
  expr : Expr,
  x_name : String,
) -> (Expr, Expr, Expr, Bool)? {
  retry_with_simplified(expr, expr => {
    match expr {
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
            expr_same_simplified(expr_pow(v, @symcore.int(2)), shift) =>
            Some((v, shift, exp, true))
          _ => None
        }
      }
      _ => None
    }
  })
}

///|
fn parse_log_x_power_raw(expr : Expr, var_name : String) -> Int? {
  match unary_application_arg(expr, "log") {
    Some(Expr::Symbol(name)) => if name == var_name { Some(1) } else { None }
    _ =>
      match pow_named_unary_application(expr) {
        Some(("log", Expr::Symbol(name), exp)) =>
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
}

///|
fn parse_log_x_power(expr : Expr, var_name : String) -> Int? {
  retry_with_simplified(expr, expr => parse_log_x_power_raw(expr, var_name))
}

///|
fn parse_one_plus_linear(expr : Expr, var_name : String) -> Bool {
  match linear_coeffs(expr, var_name) {
    Some((coeff, offset)) => expr_is_one(coeff) && expr_is_one(offset)
    _ => false
  }
}

///|
fn parse_one_minus_linear(expr : Expr, var_name : String) -> Bool {
  match linear_coeffs(expr, var_name) {
    Some((coeff, offset)) =>
      (expr_is_one(coeff) || expr_is_minus_one(coeff)) && expr_is_one(offset)
    _ => false
  }
}

///|
fn parse_one_plus_inverse_raw(expr : Expr, var_name : String) -> Bool {
  match expr {
    @symcore.Expr::Add(args) if args.length() == 2 => {
      let mut saw_one = false
      let mut saw_inv = false
      for arg in args {
        if expr_is_one(arg) {
          saw_one = true
        } else {
          match parse_negative_power(arg, var_name) {
            Some(power) if expr_eq(power, @symcore.int(1)) => saw_inv = true
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
fn parse_one_plus_inverse(expr : Expr, var_name : String) -> Bool {
  retry_with_simplified(expr, expr => {
    if parse_one_plus_inverse_raw(expr, var_name) {
      Some(true)
    } else {
      None
    }
  })
  is Some(_)
}

///|
fn parse_one_minus_inverse_inner_raw(expr : Expr, var_name : String) -> Bool {
  match expr {
    @symcore.Expr::Add(args) if args.length() == 2 => {
      let mut saw_one = false
      let mut saw_neg_inv = false
      for arg in args {
        if expr_is_one(arg) {
          saw_one = true
        } else {
          match
            parse_negative_power(expr_mul(@symcore.int(-1), arg), var_name) {
            Some(power) if expr_eq(power, @symcore.int(1)) => saw_neg_inv = true
            _ => return false
          }
        }
      }
      saw_one && saw_neg_inv
    }
    _ => false
  }
}

///|
fn parse_abs_one_minus_linear(expr : Expr, var_name : String) -> Bool {
  match unary_application_arg(expr, "Abs") {
    Some(inner) => parse_one_minus_linear(inner, var_name)
    None =>
      match
        retry_with_simplified(expr, expr => unary_application_arg(expr, "Abs")) {
        Some(inner) => parse_one_minus_linear(inner, var_name)
        None => false
      }
  }
}

///|
fn parse_abs_one_minus_inverse(expr : Expr, var_name : String) -> Bool {
  match unary_application_arg(expr, "Abs") {
    Some(inner) => parse_one_minus_inverse_inner_raw(inner, var_name)
    None =>
      match
        retry_with_simplified(expr, expr => unary_application_arg(expr, "Abs")) {
        Some(inner) => parse_one_minus_inverse_inner_raw(inner, var_name)
        None => false
      }
  }
}

///|
fn split_linear_power_denom(
  expr : Expr,
  var_name : String,
) -> (Expr, Expr, Int)? {
  retry_with_simplified(expr, expr => {
    match expr {
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
  })
}

///|
fn split_linear_power_denom_direct(
  expr : Expr,
  var_name : String,
) -> (Expr, Expr, Int)? {
  match expr {
    @symcore.Expr::Pow(base, exp) =>
      match expr_is_int_value(exp) {
        Some(power) if power > 0 =>
          match split_linear_coeff_direct(base, var_name) {
            Some((a, b)) => Some((a, b, power))
            None => None
          }
        _ => None
      }
    _ =>
      match split_linear_coeff_direct(expr, var_name) {
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
  match split_shifted_square_denom_direct(den, s_name) {
    Some(value) => Some(value)
    None => {
      let simplified = expr_simplify(den)
      if @symcore.compare_expr(simplified, den) == 0 {
        None
      } else {
        split_shifted_square_denom_direct(simplified, s_name)
      }
    }
  }
}

///|
fn split_shifted_square_denom_direct(
  den : Expr,
  s_name : String,
) -> (Expr, Expr, Expr)? {
  match poly_coeffs_upto2_raw(den, s_name) {
    Some(coeffs) => split_shifted_square_denom_from_coeffs(coeffs, s_name)
    None => None
  }
}

///|
fn split_shifted_square_denom_from_coeffs(
  coeffs : Array[Expr],
  s_name : String,
) -> (Expr, Expr, Expr)? {
  if expr_is_zero(coeffs[2]) ||
    expr_depends_on(coeffs[0], s_name) ||
    expr_depends_on(coeffs[1], s_name) ||
    expr_depends_on(coeffs[2], s_name) {
    None
  } else {
    let lead = coeffs[2]
    let shift = expr_div(coeffs[1], expr_mul(@symcore.int(2), lead))
    let remainder = expr_sub(
      expr_div(coeffs[0], lead),
      expr_pow(shift, @symcore.int(2)),
    )
    if expr_is_negative(remainder) || expr_is_zero(remainder) {
      None
    } else {
      Some((lead, shift, expr_sqrt_positive(remainder)))
    }
  }
}

///|
fn split_shifted_diff_square_denom(
  den : Expr,
  s_name : String,
) -> (Expr, Expr, Expr)? {
  match split_shifted_diff_square_denom_direct(den, s_name) {
    Some(value) => Some(value)
    None => {
      let simplified = expr_simplify(den)
      if @symcore.compare_expr(simplified, den) == 0 {
        None
      } else {
        split_shifted_diff_square_denom_direct(simplified, s_name)
      }
    }
  }
}

///|
fn split_quadratic_repeated_root_denom(
  den : Expr,
  s_name : String,
) -> (Expr, Expr)? {
  match split_quadratic_repeated_root_denom_direct(den, s_name) {
    Some(value) => Some(value)
    None => {
      let simplified = expr_simplify(den)
      if @symcore.compare_expr(simplified, den) == 0 {
        None
      } else {
        split_quadratic_repeated_root_denom_direct(simplified, s_name)
      }
    }
  }
}

///|
fn split_quadratic_repeated_root_denom_direct(
  den : Expr,
  s_name : String,
) -> (Expr, Expr)? {
  match poly_coeffs_upto2_raw(den, s_name) {
    Some(coeffs) => split_quadratic_repeated_root_from_coeffs(coeffs, s_name)
    None => None
  }
}

///|
fn split_quadratic_repeated_root_from_coeffs(
  coeffs : Array[Expr],
  s_name : String,
) -> (Expr, Expr)? {
  if expr_is_zero(coeffs[2]) ||
    expr_depends_on(coeffs[0], s_name) ||
    expr_depends_on(coeffs[1], s_name) ||
    expr_depends_on(coeffs[2], s_name) {
    return None
  }
  let discr = expr_simplify(
    expr_sub(
      expr_pow(coeffs[1], @symcore.int(2)),
      expr_mul(@symcore.int(4), expr_mul(coeffs[2], coeffs[0])),
    ),
  )
  if expr_is_zero(discr) {
    Some((coeffs[2], expr_div(coeffs[1], expr_mul(@symcore.int(2), coeffs[2]))))
  } else {
    None
  }
}

///|
fn split_shifted_diff_square_denom_direct(
  den : Expr,
  s_name : String,
) -> (Expr, Expr, Expr)? {
  match poly_coeffs_upto2_raw(den, s_name) {
    Some(coeffs) => split_shifted_diff_square_denom_from_coeffs(coeffs, s_name)
    None => None
  }
}

///|
fn split_shifted_diff_square_denom_from_coeffs(
  coeffs : Array[Expr],
  s_name : String,
) -> (Expr, Expr, Expr)? {
  if expr_is_zero(coeffs[2]) ||
    expr_depends_on(coeffs[0], s_name) ||
    expr_depends_on(coeffs[1], s_name) ||
    expr_depends_on(coeffs[2], s_name) {
    None
  } else {
    let lead = coeffs[2]
    let shift = expr_div(coeffs[1], expr_mul(@symcore.int(2), lead))
    let remainder = expr_sub(
      expr_div(coeffs[0], lead),
      expr_pow(shift, @symcore.int(2)),
    )
    if expr_is_negative(remainder) {
      Some(
        (lead, shift, expr_sqrt_positive(expr_mul(@symcore.int(-1), remainder))),
      )
    } else {
      None
    }
  }
}

///|
fn split_shifted_square_power_denom(
  den : Expr,
  s_name : String,
) -> (Expr, Expr, Expr, Int)? {
  match split_shifted_square_power_denom_direct(den, s_name) {
    Some(value) => Some(value)
    None => {
      let simplified = expr_simplify(den)
      if @symcore.compare_expr(simplified, den) == 0 {
        None
      } else {
        split_shifted_square_power_denom_direct(simplified, s_name)
      }
    }
  }
}

///|
fn split_shifted_square_power_denom_direct(
  den : Expr,
  s_name : String,
) -> (Expr, Expr, Expr, Int)? {
  match den {
    @symcore.Expr::Pow(base, exp) =>
      match expr_is_int_value(exp) {
        Some(power) if power > 1 =>
          match split_shifted_square_denom_direct(base, s_name) {
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
  match split_shifted_diff_square_power_denom_direct(den, s_name) {
    Some(value) => Some(value)
    None => {
      let simplified = expr_simplify(den)
      if @symcore.compare_expr(simplified, den) == 0 {
        None
      } else {
        split_shifted_diff_square_power_denom_direct(simplified, s_name)
      }
    }
  }
}

///|
fn split_shifted_diff_square_power_denom_direct(
  den : Expr,
  s_name : String,
) -> (Expr, Expr, Expr, Int)? {
  match den {
    @symcore.Expr::Pow(base, exp) =>
      match expr_is_int_value(exp) {
        Some(power) if power > 1 =>
          match split_shifted_diff_square_denom_direct(base, s_name) {
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
  match split_two_linear_factors_direct(den, s_name) {
    Some(value) => Some(value)
    None => {
      let simplified = expr_simplify(den)
      if @symcore.compare_expr(simplified, den) == 0 {
        None
      } else {
        split_two_linear_factors_direct(simplified, s_name)
      }
    }
  }
}

///|
fn split_distinct_linear_factors(
  den : Expr,
  s_name : String,
) -> Array[(Expr, Expr)]? {
  match split_distinct_linear_factors_direct(den, s_name) {
    Some(value) => Some(value)
    None => {
      let simplified = expr_simplify(den)
      if @symcore.compare_expr(simplified, den) == 0 {
        None
      } else {
        split_distinct_linear_factors_direct(simplified, s_name)
      }
    }
  }
}

///|
fn split_repeated_linear_pair(
  den : Expr,
  s_name : String,
) -> ((Expr, Expr, Int), (Expr, Expr))? {
  match split_repeated_linear_pair_direct(den, s_name) {
    Some(value) => Some(value)
    None => {
      let simplified = expr_simplify(den)
      if @symcore.compare_expr(simplified, den) == 0 {
        None
      } else {
        split_repeated_linear_pair_direct(simplified, s_name)
      }
    }
  }
}

///|
fn split_linear_power_factors(
  den : Expr,
  s_name : String,
) -> Array[(Expr, Expr, Int)]? {
  match split_linear_power_factors_direct(den, s_name) {
    Some(value) => Some(value)
    None => {
      let simplified = expr_simplify(den)
      if @symcore.compare_expr(simplified, den) == 0 {
        None
      } else {
        split_linear_power_factors_direct(simplified, s_name)
      }
    }
  }
}

///|
fn split_linear_power_factors_direct(
  den : Expr,
  s_name : String,
) -> Array[(Expr, Expr, Int)]? {
  match den {
    @symcore.Expr::Mul(args) if args.length() >= 2 => {
      let out : Array[(Expr, Expr, Int)] = []
      for arg in args {
        match split_linear_power_denom_direct(arg, s_name) {
          Some((a, b, power)) if power > 0 => out.push((a, b, power))
          _ => return None
        }
      }
      Some(out)
    }
    _ => None
  }
}

///|
fn split_repeated_linear_pair_direct(
  den : Expr,
  s_name : String,
) -> ((Expr, Expr, Int), (Expr, Expr))? {
  match den {
    @symcore.Expr::Mul(args) if args.length() == 2 =>
      match
        (
          split_linear_power_denom_direct(args[0], s_name),
          split_linear_power_denom_direct(args[1], s_name),
        ) {
        (Some((a_rep, b_rep, rep_power)), Some((a_single, b_single, 1))) if rep_power >=
          2 => Some(((a_rep, b_rep, rep_power), (a_single, b_single)))
        (Some((a_single, b_single, 1)), Some((a_rep, b_rep, rep_power))) if rep_power >=
          2 => Some(((a_rep, b_rep, rep_power), (a_single, b_single)))
        _ => None
      }
    _ => None
  }
}

///|
fn split_distinct_linear_factors_direct(
  den : Expr,
  s_name : String,
) -> Array[(Expr, Expr)]? {
  match den {
    @symcore.Expr::Mul(args) if args.length() >= 3 => {
      let out : Array[(Expr, Expr)] = []
      for arg in args {
        match split_linear_power_denom_direct(arg, s_name) {
          Some((a, b, 1)) => out.push((a, b))
          _ => return None
        }
      }
      Some(out)
    }
    _ => None
  }
}

///|
fn split_two_linear_factors_direct(
  den : Expr,
  s_name : String,
) -> ((Expr, Expr), (Expr, Expr))? {
  match den {
    @symcore.Expr::Mul(args) if args.length() == 2 =>
      match
        (
          split_linear_power_denom_direct(args[0], s_name),
          split_linear_power_denom_direct(args[1], s_name),
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
  match split_quadratic_power_denom_direct(den, s_name) {
    Some(value) => Some(value)
    None => {
      let simplified = expr_simplify(den)
      if @symcore.compare_expr(simplified, den) == 0 {
        None
      } else {
        split_quadratic_power_denom_direct(simplified, s_name)
      }
    }
  }
}

///|
fn split_quadratic_power_denom_direct(
  den : Expr,
  s_name : String,
) -> (Expr, Expr, Bool, Int)? {
  match den {
    @symcore.Expr::Pow(base, exp) =>
      match expr_is_int_value(exp) {
        Some(power) if power > 1 =>
          match split_quadratic_base_direct(base, s_name) {
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
  match split_quadratic_base_direct(base, s_name) {
    Some(value) => Some(value)
    None => {
      let simplified = expr_simplify(base)
      if @symcore.compare_expr(simplified, base) == 0 {
        None
      } else {
        split_quadratic_base_direct(simplified, s_name)
      }
    }
  }
}

///|
fn split_quadratic_base_direct(
  base : Expr,
  s_name : String,
) -> (Expr, Expr, Bool)? {
  match poly_coeffs_upto2_raw(base, s_name) {
    Some(c) => split_quadratic_base_from_coeffs(c, s_name)
    _ => None
  }
}

///|
fn split_quadratic_base_from_coeffs(
  coeffs : Array[Expr],
  s_name : String,
) -> (Expr, Expr, Bool)? {
  if expr_is_zero(coeffs[1]) &&
    !expr_depends_on(coeffs[0], s_name) &&
    !expr_depends_on(coeffs[2], s_name) &&
    !expr_is_zero(coeffs[2]) {
    let ratio = expr_div(coeffs[0], coeffs[2])
    if expr_is_negative(ratio) {
      Some(
        (coeffs[2], expr_sqrt_positive(expr_mul(@symcore.int(-1), ratio)), true),
      )
    } else {
      Some((coeffs[2], expr_sqrt_positive(ratio), false))
    }
  } else {
    None
  }
}

///|
fn denom_to_diff_square_freq(den : Expr, s_name : String) -> Expr? {
  match split_quadratic_base(den, s_name) {
    Some((_lead, freq, true)) => Some(freq)
    _ => None
  }
}

///|
fn denom_to_square_freq(den : Expr, s_name : String) -> Expr? {
  let coeffs = poly_coeffs_upto2(den, s_name)
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
  let coeffs = poly_coeffs_upto2(inner, var_name)
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
    expr_div(
      expr_pow(linear, @symcore.int(2)),
      expr_mul(@symcore.int(4), scale),
    ),
  )
  let imag_coeff = expr_div(
    expr_mul(
      expr_mul(
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
      ),
      linear,
    ),
    scale,
  )
  let linear_term = expr_mul(
    if inverse {
      imag_coeff
    } else {
      expr_mul(@symcore.int(-1), imag_coeff)
    },
    var_expr,
  )
  let quad_term = expr_mul(
    expr_div(
      expr_mul(
        @symcore.int(-1),
        expr_pow(
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
          @symcore.int(2),
        ),
      ),
      scale,
    ),
    expr_pow(var_expr, @symcore.int(2)),
  )
  expr_simplify(expr_add(const_term, expr_add(linear_term, quad_term)))
}

///|
fn extract_explicit_negative_factor(expr : Expr) -> Expr? {
  let simplified = expr_simplify(expr)
  match expr_num_value(simplified) {
    Some(value) =>
      if value.compare(@symnum.BigRational::zero()) < 0 {
        Some(@symcore.Expr::Number(value.neg()))
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
                  positive_factors.push(@symcore.Expr::Number(value.neg()))
                } else {
                  positive_factors.push(arg)
                }
              None => positive_factors.push(arg)
            }
          }
          if sign < 0 {
            Some(
              if positive_factors.length() == 0 {
                @symcore.int(1)
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
      let mut out = @symcore.int(1)
      while i <= v {
        out = expr_mul(out, @symcore.int(i))
        i += 1
      }
      out
    }
    Some(v) if v >= 0 => @symcore.int(1)
    _ => @symcore.int(0)
  }
}

///|
fn sqrt_pi() -> Expr {
  @symelem.sqrt(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi))
}

///|
fn expr_is_sqrt_pi(expr : Expr) -> Bool {
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  match unary_application_arg(expr, "sqrt") {
    Some(arg) if expr_eq(arg, pi) => return true
    _ => ()
  }
  match expr {
    @symcore.Expr::Pow(base, exp) if expr_eq(base, pi) =>
      expr_same_simplified(exp, expr_rat(1, 2))
    _ => false
  }
}

///|
fn preferred_positive_sqrt(expr : Expr) -> Expr {
  match expr_exact_sqrt(expr_simplify(expr)) {
    exact if @symcore.application_has_name(exact, "sqrt", arity=1) =>
      expr_sqrt_positive(expr)
    exact => exact
  }
}

///|
fn expr_sqrt_two() -> Expr {
  @symelem.sqrt(@symcore.int(2))
}

///|
fn true_expr() -> Expr {
  @symcore.Expr::Boolean(true)
}

///|
fn false_expr() -> Expr {
  @symcore.Expr::Boolean(false)
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
    return @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
  }
  let filtered : Array[Expr] = []
  for arg in args {
    if !is_neg_infinity_expr(arg) &&
      !filtered.any(fn(item) { expr_eq(item, arg) }) {
      filtered.push(arg)
    }
  }
  if filtered.is_empty() {
    return @symcore.Expr::NumberSymbol(
      @symcore.NumberSymbolKind::NegativeInfinity,
    )
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
    return @symcore.Expr::NumberSymbol(
      @symcore.NumberSymbolKind::NegativeInfinity,
    )
  }
  let filtered : Array[Expr] = []
  for arg in args {
    if !is_pos_infinity_expr(arg) &&
      !filtered.any(fn(item) { expr_eq(item, arg) }) {
      filtered.push(arg)
    }
  }
  if filtered.is_empty() {
    return @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
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
    None => @symcore.function("Ge", [simplified, @symcore.int(0)])
  }
}

///|
fn expr_is_structurally_nonnegative(expr : Expr) -> Bool {
  if @symcore.application_has_name(expr, "exp", arity=1) ||
    @symcore.application_has_name(expr, "sqrt", arity=1) ||
    @symcore.application_has_name(expr, "Abs", arity=1) {
    true
  } else {
    match expr {
      @symcore.Expr::Pow(_, exp) =>
        match expr_is_int_value(exp) {
          Some(value) => value % 2 == 0
          None => false
        }
      _ => false
    }
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
  match unary_application_arg(expr, "exp") {
    Some(inner) => parse_negative_linear_exp_raw(inner, var_name)
    None => None
  }
}

///|
fn parse_negative_abs_linear(inner : Expr, var_name : String) -> Expr? {
  let (coeff, factors) = split_mul(inner, var_name)
  if factors.length() != 1 {
    return None
  }
  match unary_application_arg(factors[0], "Abs") {
    Some(Expr::Symbol(name)) if name == var_name =>
      extract_explicit_negative_factor(coeff)
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
    Some(power) if expr_eq(power, @symcore.int(1)) =>
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
      let mut coeff = @symcore.int(1)
      let mut abs_scale : Expr? = None
      for arg in args {
        match unary_application_arg(arg, "Abs") {
          Some(inner) =>
            match parse_abs_scaled_var(inner, var_name) {
              Some(scale) =>
                if abs_scale is None {
                  abs_scale = Some(scale)
                } else {
                  return None
                }
              None => return None
            }
          None =>
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
    (num, Some(den)) =>
      if num.length() == 0 || (num.length() == 1 && expr_is_one(num[0])) {
        match unary_application_arg(den, "sqrt") {
          Some(inner) =>
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
          None => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn parse_square_scaled_var(expr : Expr, var_name : String) -> Expr? {
  match poly_coeffs_upto2(expr, var_name) {
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

///|
fn parse_cosine_linear_meijerg(expr : Expr, k_name : String) -> Expr? {
  match named_ternary_application(expr) {
    Some(("meijerg", a, b, z)) =>
      match
        (
          @symcore.tuple_items(a),
          @symcore.tuple_items(b),
          parse_square_scaled_var(z, k_name),
        ) {
        (Some([a1, a2]), Some([b1, b2]), Some(scale)) =>
          match
            (
              @symcore.tuple_items(a1),
              @symcore.tuple_items(a2),
              @symcore.tuple_items(b1),
              @symcore.tuple_items(b2),
            ) {
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
                Some(expr_mul(@symcore.int(4), scale))
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
  match named_ternary_application(expr) {
    Some(("meijerg", a, b, z)) =>
      match
        (
          @symcore.tuple_items(a),
          @symcore.tuple_items(b),
          parse_square_scaled_var(z, k_name),
        ) {
        (Some([a1, a2]), Some([b1, b2]), Some(scale)) =>
          match
            (
              @symcore.tuple_items(a1),
              @symcore.tuple_items(a2),
              @symcore.tuple_items(b1),
              @symcore.tuple_items(b2),
            ) {
            (Some(a1s), Some(a2s), Some(b1s), Some(b2s)) =>
              if a1s.length() == 1 &&
                expr_eq(a1s[0], expr_rat(1, 2)) &&
                a2s.is_empty() &&
                b1s.length() == 2 &&
                expr_is_zero(b1s[0]) &&
                expr_is_zero(b1s[1]) &&
                b2s.length() == 1 &&
                expr_eq(b2s[0], expr_rat(1, 2)) {
                Some(expr_mul(@symcore.int(4), scale))
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
  retry_with_simplified(expr, expr => {
    match expr {
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
  })
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
fn parse_laplace_negative_linear_exp_raw(
  inner : Expr,
  var_name : String,
) -> Expr? {
  match linear_coeffs(inner, var_name) {
    Some((a, b)) =>
      if expr_is_zero(b) && expr_is_negative(a) {
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
  let a = expr_add(power, @symcore.int(1))
  let expected = if is_sine {
    expr_div(
      expr_mul(
        expr_pow(
          @symcore.int(2),
          expr_add(
            expr_div(@symcore.int(1), @symcore.int(2)),
            expr_mul(@symcore.int(-1), a),
          ),
        ),
        @symspec.gamma(expr_sub(@symcore.int(1), expr_div(a, @symcore.int(2)))),
      ),
      @symspec.gamma(expr_div(expr_add(a, @symcore.int(1)), @symcore.int(2))),
    )
  } else {
    expr_div(
      expr_mul(
        expr_pow(
          @symcore.int(2),
          expr_add(
            expr_div(@symcore.int(1), @symcore.int(2)),
            expr_mul(@symcore.int(-1), a),
          ),
        ),
        @symspec.gamma(expr_div(expr_sub(@symcore.int(1), a), @symcore.int(2))),
      ),
      @symspec.gamma(expr_div(a, @symcore.int(2))),
    )
  }
  if expr_eq(coeff, expected) {
    Some(expr_pow(x, expr_mul(@symcore.int(-1), a)))
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
  let m = expr_add(power, @symcore.int(2))
  let expected = expr_mul(
    expr_pow(@symcore.int(2), expr_sub(@symcore.int(1), m)),
    expr_div(
      @symspec.gamma(
        expr_add(
          expr_sub(@symcore.int(1), expr_div(m, @symcore.int(2))),
          expr_div(nu, @symcore.int(2)),
        ),
      ),
      @symspec.gamma(
        expr_add(expr_div(m, @symcore.int(2)), expr_div(nu, @symcore.int(2))),
      ),
    ),
  )
  if expr_eq(coeff, expected) {
    Some(expr_pow(r, expr_mul(@symcore.int(-1), m)))
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
        if expr_eq(
            power,
            expr_sub(@symcore.int(-1), expr_add(nu, @symcore.int(2))),
          ) {
          power_ok = true
        } else {
          return None
        }
      None =>
        match factor {
          @symcore.Expr::Pow(base, exp) if expr_eq(
              exp,
              expr_mul(@symcore.int(-1), expr_add(nu, expr_rat(3, 2))),
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
                            @symcore.int(-2),
                          ) &&
                          expr_eq(base2, @symcore.Expr::Symbol(k_name)) =>
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
      expr_mul(expr_pow(@symcore.int(2), expr_add(nu, @symcore.int(1))), a),
      @symspec.gamma(expr_add(nu, expr_rat(3, 2))),
    ),
    sqrt_pi(),
  )
  if expr_eq(coeff, expected) {
    Some(
      expr_mul(
        expr_pow(r, nu),
        @symelem.exp(expr_mul(@symcore.int(-1), expr_mul(a, r))),
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
  let mut power = @symcore.int(0)
  let mut scale : Expr? = None
  for factor in factors {
    match parse_power_factor(factor, k_name) {
      Some(p) => power = expr_add(power, p)
      None =>
        match unary_application_arg(factor, "exp") {
          Some(inner) =>
            match parse_negative_quadratic_exp(inner, k_name) {
              Some(a) =>
                if scale is None {
                  scale = Some(a)
                } else {
                  return None
                }
              None => return None
            }
          None => return None
        }
    }
  }
  match scale {
    Some(v) if expr_eq(power, nu) => {
      let a = expr_div(@symcore.int(1), expr_mul(@symcore.int(4), v))
      let expected = expr_pow(
        expr_mul(@symcore.int(2), v),
        expr_add(nu, @symcore.int(1)),
      )
      let forward_coeff = expr_pow(
        expr_div(@symcore.int(1), expr_mul(@symcore.int(2), a)),
        expr_add(nu, @symcore.int(1)),
      )
      if expr_eq(coeff, expected) || expr_eq(coeff, forward_coeff) {
        Some(
          expr_mul(
            expr_pow(r, nu),
            @symelem.exp(
              expr_mul(
                @symcore.int(-1),
                expr_mul(a, expr_pow(r, @symcore.int(2))),
              ),
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
  match @symcore.application_name(expr) {
    Some(func_name) if func_name == name => true
    _ => @symcore.args(expr).any(fn(arg) { expr_has_function_name(arg, name) })
  }
}

///|
fn expr_is_negative(expr : Expr) -> Bool {
  match expr_num_value(expr) {
    Some(value) => value.compare(@symnum.BigRational::zero()) < 0
    None => false
  }
}

///|
fn expr_is_positive(expr : Expr) -> Bool {
  match expr_num_value(expr) {
    Some(value) => value.compare(@symnum.BigRational::zero()) > 0
    None => false
  }
}
