///|
/// Basis-discovery and helper representations aligned with the public helper
/// layer in `sympy.physics.quantum.represent`.
///
/// The matrix-producing `represent(...)` entry point already covers the
/// concrete qubit/gate/spin families. This file fills in the symbolic helper
/// surface that SymPy exposes around it:
///
/// - `get_basis(...)` selects a basis state from an explicit basis argument or
///   from the state/operator family itself;
/// - `enumerate_states(...)` manufactures indexed dummy basis states such as
///   `|x_1>` and `|x_2>`;
/// - `rep_innerproduct(...)` and `rep_expectation(...)` build the symbolic
///   `<basis|state>` / `<basis|A|basis>` forms that SymPy falls back to when
///   no direct matrix representation exists.

///|
fn represent_default_basis_state(expr : Expr) -> Expr? {
  if quantum_expr_has_name(expr, "XKet") ||
    quantum_expr_has_name(expr, "XBra") ||
    quantum_expr_has_name(expr, "XOp") {
    return Some(x_ket())
  }
  if quantum_expr_has_name(expr, "PxKet") ||
    quantum_expr_has_name(expr, "PxBra") ||
    quantum_expr_has_name(expr, "PxOp") {
    return Some(px_ket())
  }
  if quantum_expr_has_name(expr, "PositionKet3D") ||
    quantum_expr_has_name(expr, "PositionBra3D") {
    return Some(position_ket_3d())
  }
  match quantum_expr_args(expr) {
    Some([j, _]) if quantum_expr_has_name(expr, "JzKet") ||
      quantum_expr_has_name(expr, "JzBra") =>
      Some(jz_ket(j, Symbol("m")).as_expr())
    _ =>
      match state_from_expr(expr) {
        Some(state) =>
          match state.flavor {
            Ket | Bra => Some(ket([Symbol("psi")]).as_expr())
            TimeDepKet | TimeDepBra =>
              Some(time_dep_ket([Symbol("psi")], time=Symbol("t")).as_expr())
            OrthogonalKet | OrthogonalBra =>
              Some(orthogonal_ket([Symbol("n")]).as_expr())
          }
        None =>
          if quantum_is_operator_expr(expr) {
            operators_to_state(expr)
          } else {
            None
          }
      }
  }
}

///|
fn represent_index_symbol(label : Expr, index : Int, fallback : String) -> Expr {
  match label {
    Symbol(name) => Symbol("\{name}_\{index.to_string()}")
    _ => Symbol("\{fallback}_\{index.to_string()}")
  }
}

///|
fn represent_enumerate_with_index(state_expr : Expr, index : Int) -> Expr? {
  match quantum_expr_args(state_expr) {
    Some(args) if quantum_expr_has_name(state_expr, "Ket") =>
      Some(
        ket(args.map(arg => represent_index_symbol(arg, index, "psi"))).as_expr(),
      )
    Some(args) if quantum_expr_has_name(state_expr, "Bra") =>
      Some(
        bra(args.map(arg => represent_index_symbol(arg, index, "psi"))).as_expr(),
      )
    Some(args) if quantum_expr_has_name(state_expr, "TimeDepKet") &&
      args.length() >= 1 => {
      let labels : Array[Expr] = []
      for i in 0..<(args.length() - 1) {
        labels.push(represent_index_symbol(args[i], index, "psi"))
      }
      Some(time_dep_ket(labels, time=args[args.length() - 1]).as_expr())
    }
    Some(args) if quantum_expr_has_name(state_expr, "TimeDepBra") &&
      args.length() >= 1 => {
      let labels : Array[Expr] = []
      for i in 0..<(args.length() - 1) {
        labels.push(represent_index_symbol(args[i], index, "psi"))
      }
      Some(time_dep_bra(labels, time=args[args.length() - 1]).as_expr())
    }
    Some(args) if quantum_expr_has_name(state_expr, "OrthogonalKet") =>
      Some(
        orthogonal_ket(args.map(arg => represent_index_symbol(arg, index, "n"))).as_expr(),
      )
    Some(args) if quantum_expr_has_name(state_expr, "OrthogonalBra") =>
      Some(
        orthogonal_bra(args.map(arg => represent_index_symbol(arg, index, "n"))).as_expr(),
      )
    Some([position]) if quantum_expr_has_name(state_expr, "XKet") =>
      Some(x_ket(position=represent_index_symbol(position, index, "x")))
    Some([position]) if quantum_expr_has_name(state_expr, "XBra") =>
      Some(x_bra(position=represent_index_symbol(position, index, "x")))
    Some([momentum]) if quantum_expr_has_name(state_expr, "PxKet") =>
      Some(px_ket(momentum=represent_index_symbol(momentum, index, "px")))
    Some([momentum]) if quantum_expr_has_name(state_expr, "PxBra") =>
      Some(px_bra(momentum=represent_index_symbol(momentum, index, "px")))
    Some([x, y, z]) if quantum_expr_has_name(state_expr, "PositionKet3D") =>
      Some(
        position_ket_3d(
          x=represent_index_symbol(x, index, "x"),
          y=represent_index_symbol(y, index, "y"),
          z=represent_index_symbol(z, index, "z"),
        ),
      )
    Some([x, y, z]) if quantum_expr_has_name(state_expr, "PositionBra3D") =>
      Some(
        position_bra_3d(
          x=represent_index_symbol(x, index, "x"),
          y=represent_index_symbol(y, index, "y"),
          z=represent_index_symbol(z, index, "z"),
        ),
      )
    Some([j, m]) if quantum_expr_has_name(state_expr, "JzKet") =>
      Some(jz_ket(j, represent_index_symbol(m, index, "m")).as_expr())
    Some([j, m]) if quantum_expr_has_name(state_expr, "JzBra") =>
      Some(jz_bra(j, represent_index_symbol(m, index, "m")).as_expr())
    _ => None
  }
}

///|
pub fn get_basis(
  expr : Expr,
  basis? : Expr? = None,
  replace_none? : Bool = true,
) -> Expr? {
  match basis {
    Some(value) =>
      if quantum_is_operator_expr(value) {
        operators_to_state(value)
      } else if quantum_is_bra_expr(value) {
        Some(dagger(value))
      } else if quantum_is_state_expr(value) {
        Some(value)
      } else {
        None
      }
    None =>
      if replace_none {
        represent_default_basis_state(expr)
      } else {
        None
      }
  }
}

///|
pub fn enumerate_states(
  state_expr : Expr,
  start_index? : Int = 1,
  count? : Int = 0,
  index_list? : Array[Int] = [],
) -> Array[Expr] raise @symphysics.PhysicsError {
  guard quantum_is_state_expr(state_expr) else {
    raise ValueError("enumerate_states expects a state expression")
  }
  let indices : Array[Int] = []
  if count > 0 {
    for idx in 0..<count {
      indices.push(start_index + idx)
    }
  } else {
    for idx in index_list {
      indices.push(idx)
    }
  }
  let out : Array[Expr] = []
  for index in indices {
    match represent_enumerate_with_index(state_expr, index) {
      Some(next) => out.push(next)
      None => ()
    }
  }
  out
}

///|
pub fn rep_innerproduct(
  expr : Expr,
  basis? : Expr? = None,
  index? : Int = 1,
) -> Expr raise @symphysics.PhysicsError {
  guard quantum_is_ket_expr(expr) || quantum_is_bra_expr(expr) else {
    raise ValueError("rep_innerproduct expects a bra or ket expression")
  }
  let basis_state = get_basis(expr, basis~, replace_none=true).unwrap_or_else(() => {
    raise @symphysics.PhysicsError::ValueError(
      "Can't form this representation!",
    )
  })
  let basis_kets = enumerate_states(basis_state, start_index=index, count=2)
  guard basis_kets.length() == 2 else {
    raise ValueError("Could not enumerate basis states for representation")
  }
  if quantum_is_bra_expr(expr) {
    let ket_value = if dagger(basis_kets[0]) == expr {
      basis_kets[1]
    } else {
      basis_kets[0]
    }
    inner_product(expr, ket_value)
  } else {
    let bra_value = if basis_kets[0] == expr {
      dagger(basis_kets[1])
    } else {
      dagger(basis_kets[0])
    }
    inner_product(bra_value, expr)
  }
}

///|
fn rep_contract_bra_state(bra_expr : Expr, state_expr : Expr) -> Expr {
  match state_expr {
    Add(args) =>
      quantum_add_from_args_preserve(
        args.map(term => rep_contract_bra_state(bra_expr, term)),
      )
    _ => {
      let (scalar, body) = quantum_split_scalar_factors(state_expr)
      match body {
        Some(body_expr) if quantum_is_ket_expr(body_expr) =>
          quantum_mul_from_args_preserve([
            scalar,
            inner_product(bra_expr, body_expr),
          ])
        Some(body_expr) =>
          qapply(quantum_mul_from_args_preserve([bra_expr, scalar, body_expr]))
        None => scalar
      }
    }
  }
}

///|
pub fn rep_expectation(
  expr : Expr,
  basis? : Expr? = None,
  index? : Int = 1,
) -> Expr raise @symphysics.PhysicsError {
  guard quantum_is_operator_expr(expr) else {
    raise ValueError("rep_expectation expects an operator expression")
  }
  let basis_state = get_basis(expr, basis~, replace_none=true).unwrap_or_else(() => {
    raise @symphysics.PhysicsError::ValueError(
      "Could not get basis kets for this operator",
    )
  })
  let basis_kets = enumerate_states(basis_state, start_index=index, count=2)
  guard basis_kets.length() == 2 else {
    raise ValueError("Could not enumerate basis states for expectation value")
  }
  let bra_expr = dagger(basis_kets[1])
  let applied = qapply(quantum_mul_from_args_preserve([expr, basis_kets[0]]))
  rep_contract_bra_state(bra_expr, applied)
}
