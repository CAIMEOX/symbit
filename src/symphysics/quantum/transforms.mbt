///|
/// Canonical multiplication transforms for bras, kets, operators, and tensor products.
///
/// SymPy applies these rules when a product of quantum expressions is built:
/// `bra*ket` becomes `InnerProduct`, `ket*bra` becomes `OuterProduct`, and
/// matching tensor products are combined componentwise. MoonBit does not have
/// constructor postprocessors, so the rules are exposed as explicit functions.

///|
fn tensor_product_args(expr : @symcore.Expr) -> Array[@symcore.Expr]? {
  match expr {
    @symcore.Expr::Function("TensorProduct", args) => Some(args)
    _ => None
  }
}

///|
pub fn quantum_transform_state_pair(
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
) -> Array[@symcore.Expr]? raise @symphysics.PhysicsError {
  match (lhs, rhs) {
    (@symcore.Expr::Function("IdentityOperator", _), _) => Some([rhs])
    (_, @symcore.Expr::Function("IdentityOperator", _)) => Some([lhs])
    _ if quantum_is_bra_expr(lhs) && quantum_is_ket_expr(rhs) =>
      Some([inner_product(lhs, rhs, evaluate=false)])
    _ if quantum_is_ket_expr(lhs) && quantum_is_bra_expr(rhs) =>
      Some([outer_product(lhs, rhs)])
    (@symcore.Expr::Function("OuterProduct", args), _) if args.length() == 2 && quantum_is_ket_expr(args[0]) && quantum_is_bra_expr(args[1]) && quantum_is_ket_expr(rhs) =>
      Some([inner_product(args[1], rhs, evaluate=false), args[0]])
    (_, @symcore.Expr::Function("OuterProduct", args)) if args.length() == 2 && quantum_is_bra_expr(lhs) && quantum_is_ket_expr(args[0]) && quantum_is_bra_expr(args[1]) =>
      Some([inner_product(lhs, args[0], evaluate=false), args[1]])
    (@symcore.Expr::Function("OuterProduct", lhs_args), @symcore.Expr::Function("OuterProduct", rhs_args)) if lhs_args.length() == 2 && rhs_args.length() == 2 =>
      Some([
        inner_product(lhs_args[1], rhs_args[0], evaluate=false),
        outer_product(lhs_args[0], rhs_args[1]),
      ])
    _ =>
      match (tensor_product_args(lhs), tensor_product_args(rhs)) {
        (Some(lhs_items), Some(rhs_items)) if lhs_items.length() == rhs_items.length() => {
          let lhs_kind = quantum_kind(lhs)
          let rhs_kind = quantum_kind(rhs)
          if lhs_kind == QuantumKind::QBra && rhs_kind == QuantumKind::QKet {
            let out : Array[@symcore.Expr] = []
            for idx in 0..<lhs_items.length() {
              out.push(inner_product(lhs_items[idx], rhs_items[idx], evaluate=false))
            }
            Some(out)
          } else {
            let out : Array[@symcore.Expr] = []
            for idx in 0..<lhs_items.length() {
              out.push(quantum_canonical_mul(@symcore.raw_mul([lhs_items[idx], rhs_items[idx]])))
            }
            Some([@symcore.raw_function("TensorProduct", out)])
          }
        }
        (Some(_), None) if quantum_kind(lhs) == QuantumKind::QKet && quantum_is_ket_expr(rhs) =>
          raise @symphysics.PhysicsError::ValueError(
            "Multiplication of TensorProduct(*kets)*ket is invalid.",
          )
        (None, Some(_)) if quantum_is_ket_expr(lhs) && quantum_kind(rhs) == QuantumKind::QKet =>
          raise @symphysics.PhysicsError::ValueError(
            "Multiplication of ket*TensorProduct(*kets) is invalid.",
          )
        (Some(_), None) if quantum_kind(lhs) == QuantumKind::QBra && quantum_is_bra_expr(rhs) =>
          raise @symphysics.PhysicsError::ValueError(
            "Multiplication of TensorProduct(*bras)*bra is invalid.",
          )
        (None, Some(_)) if quantum_is_bra_expr(lhs) && quantum_kind(rhs) == QuantumKind::QBra =>
          raise @symphysics.PhysicsError::ValueError(
            "Multiplication of bra*TensorProduct(*bras) is invalid.",
          )
        _ =>
          if quantum_is_ket_expr(lhs) && quantum_is_ket_expr(rhs) {
            raise @symphysics.PhysicsError::ValueError(
              "Multiplication of two kets is not allowed. Use TensorProduct instead.",
            )
          } else if quantum_is_bra_expr(lhs) && quantum_is_bra_expr(rhs) {
            raise @symphysics.PhysicsError::ValueError(
              "Multiplication of two bras is not allowed. Use TensorProduct instead.",
            )
          } else {
            None
          }
      }
  }
}

///|
pub fn quantum_canonical_mul(expr : @symcore.Expr) -> @symcore.Expr raise @symphysics.PhysicsError {
  let work = match expr {
    @symcore.Expr::Mul(items) => items.copy()
    _ => [expr]
  }
  let result : Array[@symcore.Expr] = []
  while work.length() > 1 {
    let first = work[0]
    let second = work[1]
    match quantum_transform_state_pair(first, second) {
      Some(transformed) => {
        for idx in 0..<(transformed.length() - 1) {
          result.push(transformed[idx])
        }
        let rebuilt : Array[@symcore.Expr] = [transformed[transformed.length() - 1]]
        for idx in 2..<work.length() {
          rebuilt.push(work[idx])
        }
        work.clear()
        for item in rebuilt {
          work.push(item)
        }
      }
      None => {
        result.push(first)
        let rebuilt : Array[@symcore.Expr] = []
        for idx in 1..<work.length() {
          rebuilt.push(work[idx])
        }
        work.clear()
        for item in rebuilt {
          work.push(item)
        }
      }
    }
  }
  if !work.is_empty() {
    result.push(work[0])
  }
  quantum_mul_from_args_preserve(result)
}

///|
pub fn quantum_canonical_pow(
  base : @symcore.Expr,
  exp : @symcore.Expr,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  let kind = quantum_kind(base)
  if kind == QuantumKind::QKet || kind == QuantumKind::QBra {
    raise @symphysics.PhysicsError::ValueError(
      "A bra or ket to a power is invalid, use TensorProduct instead.",
    )
  }
  @symcore.raw_pow(base, exp)
}
