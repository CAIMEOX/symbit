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
fn represent_expr_contains_symbol(expr : @symcore.Expr, name : String) -> Bool {
  match expr {
    @symcore.Expr::Symbol(sym) => sym == name
    @symcore.Expr::Add(args)
    | @symcore.Expr::Mul(args)
    | @symcore.Expr::Function(_, args) =>
      args.any(arg => represent_expr_contains_symbol(arg, name))
    @symcore.Expr::Pow(base, exp) =>
      represent_expr_contains_symbol(base, name) ||
      represent_expr_contains_symbol(exp, name)
    _ => false
  }
}

///|
fn represent_linear_term_expr(
  base : @symcore.Expr,
  coeff : @symnum.BigRational,
) -> @symcore.Expr {
  if coeff.is_one() {
    base
  } else if coeff.neg_r().is_one() {
    @symcore.int(-1) * base
  } else {
    @symcore.number(coeff) * base
  }
}

///|
fn represent_linear_sum_expr(
  terms : Array[(@symcore.Expr, @symnum.BigRational)],
  const_coeff : @symnum.BigRational,
) -> @symcore.Expr {
  let args : Array[@symcore.Expr] = []
  if !const_coeff.is_zero() {
    args.push(@symcore.number(const_coeff))
  }
  for term in terms {
    if !term.1.is_zero() {
      args.push(represent_linear_term_expr(term.0, term.1))
    }
  }
  quantum_add_from_args_preserve(args)
}

///|
fn represent_delta_replacement(
  coord_name : String,
  arg : @symcore.Expr,
) -> @symcore.Expr? {
  match quantum_collect_linear_terms(arg) {
    Some((terms, const_coeff)) => {
      let others : Array[(@symcore.Expr, @symnum.BigRational)] = []
      let mut coord_coeff : @symnum.BigRational? = None
      for term in terms {
        match term.0 {
          @symcore.Expr::Symbol(name) if name == coord_name => coord_coeff = Some(term.1)
          _ => others.push(term)
        }
      }
      match coord_coeff {
        Some(coeff) if coeff.is_one() || coeff.neg_r().is_one() => {
          let rest = represent_linear_sum_expr(others, const_coeff)
          if coeff.is_one() {
            Some(@symcore.int(-1) * rest)
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
  expr : @symcore.Expr,
  coord_name : String,
) -> (@symcore.Expr, Bool) {
  match expr {
    @symcore.Expr::Mul(args) => {
      for idx in 0..<args.length() {
        match args[idx] {
          @symcore.Expr::Function("DiracDelta", delta_args) if delta_args.length() == 1 =>
            match represent_delta_replacement(coord_name, delta_args[0]) {
              Some(replacement) => {
                let rebuilt : Array[@symcore.Expr] = []
                for j in 0..<args.length() {
                  if j != idx {
                    rebuilt.push(args[j])
                  }
                }
                let env : Map[String, @symcore.Expr] = {}
                env[coord_name] = replacement
                return (
                  @symcore.subst(
                    quantum_mul_from_args_preserve(rebuilt),
                    env,
                  ),
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
fn represent_integrate_coord(
  expr : @symcore.Expr,
  coord_name : String,
) -> @symcore.Expr {
  if !represent_expr_contains_symbol(expr, coord_name) {
    return expr
  }
  match expr {
    @symcore.Expr::Add(args) =>
      quantum_add_from_args_preserve(args.map(arg => represent_integrate_coord(arg, coord_name)))
    _ => {
      let mut current = expr
      let mut changed = true
      while changed {
        let (next, did_change) = represent_integrate_coord_once(current, coord_name)
        current = next
        changed = did_change
      }
      current
    }
  }
}

///|
fn represent_state_coordinates(state_expr : @symcore.Expr) -> Array[String] {
  match state_expr {
    @symcore.Expr::Function("XKet", [@symcore.Expr::Symbol(name)])
    | @symcore.Expr::Function("XBra", [@symcore.Expr::Symbol(name)])
    | @symcore.Expr::Function("PxKet", [@symcore.Expr::Symbol(name)])
    | @symcore.Expr::Function("PxBra", [@symcore.Expr::Symbol(name)]) => [name]
    @symcore.Expr::Function("PositionKet3D", args)
    | @symcore.Expr::Function("PositionBra3D", args) => {
      let out : Array[String] = []
      for arg in args {
        match arg {
          @symcore.Expr::Symbol(name) => out.push(name)
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
  orig_expr : @symcore.Expr,
  basis : @symcore.Expr?,
) -> @symcore.Expr? {
  match basis {
    Some(value) => get_basis(orig_expr, basis=Some(value), replace_none=true)
    None =>
      match orig_expr {
        @symcore.Expr::Mul(args) if !args.is_empty() =>
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
  orig_expr : @symcore.Expr,
  result : @symcore.Expr,
  basis? : @symcore.Expr? = None,
  unities? : Array[Int] = [],
) -> @symcore.Expr {
  if unities.is_empty() {
    return result
  }
  match represent_resolve_integration_basis(orig_expr, basis) {
    Some(basis_state) =>
      match (try? enumerate_states(basis_state, index_list=unities)) {
        Ok(states) => {
          let mut out = result
          for state in states {
            for coord_name in represent_state_coordinates(state) {
              out = represent_integrate_coord(out, coord_name)
            }
          }
          out
        }
        Err(_) => result
      }
    None => result
  }
}
