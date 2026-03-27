///|
/// Delta-collapsing integration helpers for `sympy.physics.quantum.represent`.
///
/// SymPy's `integrate_result(...)` is mainly used after inserting continuous
/// basis unities such as `|x_1><x_1|`. The full Python implementation calls
/// into general integration. The MoonBit port implements the exact high-value
/// subset used by the cartesian basis machinery: repeated elimination of
/// `DiracDelta(coord - expr)` / `DiracDelta(expr - coord)` factors by symbolic
/// substitution.

///|
fn represent_expr_contains_symbol(expr : Expr, name : String) -> Bool {
  match expr {
    Expr::Symbol(sym) => sym == name
    Expr::Add(args) | Expr::Mul(args) =>
      args.any(arg => represent_expr_contains_symbol(arg, name))
    Expr::Pow(base, exp) =>
      represent_expr_contains_symbol(base, name) ||
      represent_expr_contains_symbol(exp, name)
    _ =>
      @symcore.args(expr).any(arg => represent_expr_contains_symbol(arg, name))
  }
}

///|
fn represent_linear_term_expr(base : Expr, coeff : @symnum.BigRational) -> Expr {
  if coeff.is_one() {
    base
  } else if coeff.neg_r().is_one() {
    int(-1) * base
  } else {
    @symcore.Expr::Number(coeff) * base
  }
}

///|
fn represent_linear_sum_expr(
  terms : Array[(Expr, @symnum.BigRational)],
  const_coeff : @symnum.BigRational,
) -> Expr {
  let args : Array[Expr] = []
  if !const_coeff.is_zero() {
    args.push(@symcore.Expr::Number(const_coeff))
  }
  for term in terms {
    if !term.1.is_zero() {
      args.push(represent_linear_term_expr(term.0, term.1))
    }
  }
  quantum_add_from_args_preserve(args)
}

///|
fn represent_delta_replacement(coord_name : String, arg : Expr) -> Expr? {
  match quantum_collect_linear_terms(arg) {
    Some((terms, const_coeff)) => {
      let others : Array[(Expr, @symnum.BigRational)] = []
      let mut coord_coeff : @symnum.BigRational? = None
      for term in terms {
        match term.0 {
          Expr::Symbol(name) if name == coord_name => coord_coeff = Some(term.1)
          _ => others.push(term)
        }
      }
      match coord_coeff {
        Some(coeff) if coeff.is_one() || coeff.neg_r().is_one() => {
          let rest = represent_linear_sum_expr(others, const_coeff)
          if coeff.is_one() {
            Some(int(-1) * rest)
          } else {
            Some(rest)
          }
        }
        _ => None
      }
    }
    None => None
  }
}

///|
fn represent_integrate_coord_once(
  expr : Expr,
  coord_name : String,
) -> (Expr, Bool) {
  match expr {
    Expr::Mul(args) => {
      for idx in 0..<args.length() {
        match @symcore.application_args(args[idx]) {
          Some(delta_args) if @symcore.application_has_name(
              args[idx],
              "DiracDelta",
              arity=1,
            ) =>
            match represent_delta_replacement(coord_name, delta_args[0]) {
              Some(replacement) => {
                let rebuilt : Array[Expr] = []
                for j in 0..<args.length() {
                  if j != idx {
                    rebuilt.push(args[j])
                  }
                }
                let env : Map[String, Expr] = {}
                env[coord_name] = replacement
                return (
                  @symcore.subst(quantum_mul_from_args_preserve(rebuilt), env),
                  true,
                )
              }
              None => ()
            }
          _ => ()
        }
      }
      (expr, false)
    }
    _ => (expr, false)
  }
}

///|
fn represent_integrate_coord(expr : Expr, coord_name : String) -> Expr {
  if !represent_expr_contains_symbol(expr, coord_name) {
    return expr
  }
  match expr {
    Expr::Add(args) =>
      quantum_add_from_args_preserve(
        args.map(arg => represent_integrate_coord(arg, coord_name)),
      )
    _ => {
      let mut current = expr
      let mut changed = true
      while changed {
        let (next, did_change) = represent_integrate_coord_once(
          current, coord_name,
        )
        current = next
        changed = did_change
      }
      current
    }
  }
}

///|
fn represent_state_coordinates(state_expr : Expr) -> Array[String] {
  match
    (
      @symcore.application_name(state_expr),
      @symcore.application_args(state_expr),
    ) {
    (Some("XKet"), Some([Expr::Symbol(name)]))
    | (Some("XBra"), Some([Expr::Symbol(name)]))
    | (Some("PxKet"), Some([Expr::Symbol(name)]))
    | (Some("PxBra"), Some([Expr::Symbol(name)])) => [name]
    (Some("PositionKet3D"), Some(args)) | (Some("PositionBra3D"), Some(args)) => {
      let out : Array[String] = []
      for arg in args {
        match arg {
          Expr::Symbol(name) => out.push(name)
          _ => ()
        }
      }
      out
    }
    _ => []
  }
}

///|
fn represent_resolve_integration_basis(
  orig_expr : Expr,
  basis : Expr?,
) -> Expr? {
  match basis {
    Some(value) => get_basis(orig_expr, basis=Some(value), replace_none=true)
    None =>
      match orig_expr {
        Expr::Mul(args) if !args.is_empty() =>
          match get_basis(args[args.length() - 1], replace_none=true) {
            Some(value) => Some(value)
            None => get_basis(orig_expr, replace_none=true)
          }
        _ => get_basis(orig_expr, replace_none=true)
      }
  }
}

///|
pub fn integrate_result(
  orig_expr : Expr,
  result : Expr,
  basis? : Expr? = None,
  unities? : Array[Int] = [],
) -> Expr {
  if unities.is_empty() {
    return result
  }
  match represent_resolve_integration_basis(orig_expr, basis) {
    Some(basis_state) => {
      let states = Some(enumerate_states(basis_state, index_list=unities)) catch {
        _ => None
      }
      match states {
        Some(states) => {
          let mut out = result
          for state in states {
            for coord_name in represent_state_coordinates(state) {
              out = represent_integrate_coord(out, coord_name)
            }
          }
          out
        }
        None => result
      }
    }
    None => result
  }
}
