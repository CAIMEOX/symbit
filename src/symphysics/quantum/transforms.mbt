///|
/// Canonical multiplication transforms for bras, kets, operators, and tensor products.
///
/// SymPy applies these rules when a product of quantum expressions is built:
/// `bra*ket` becomes `InnerProduct`, `ket*bra` becomes `OuterProduct`, and
/// matching tensor products are combined componentwise. MoonBit does not have
/// constructor postprocessors, so the rules are exposed as explicit functions.

///|
fn tensor_product_args(expr : Expr) -> Array[Expr]? {
  if quantum_expr_has_name(expr, "TensorProduct") {
    quantum_expr_args(expr)
  } else {
    None
  }
}

///|
fn quantum_distribute_mul(
  factors : Array[Expr],
) -> Expr? raise @symphysics.PhysicsError {
  for idx in 0..<factors.length() {
    match factors[idx] {
      Add(terms) => {
        let expanded : Array[Expr] = []
        for term in terms {
          let rebuilt : Array[Expr] = []
          for jdx in 0..<factors.length() {
            rebuilt.push(if idx == jdx { term } else { factors[jdx] })
          }
          expanded.push(quantum_canonical_mul(@symcore.raw_mul(rebuilt)))
        }
        return Some(quantum_add_from_args_preserve(expanded))
      }
      _ => ()
    }
  }
  None
}

///|
pub fn quantum_transform_state_pair(
  lhs : Expr,
  rhs : Expr,
) -> Array[Expr]? raise @symphysics.PhysicsError {
  match quantum_operator_pair_simplify(lhs, rhs) {
    Some(simplified) => Some([simplified])
    None =>
      match (lhs, rhs) {
        _ if quantum_is_bra_expr(lhs) && quantum_is_ket_expr(rhs) =>
          Some([inner_product(lhs, rhs, evaluate=false)])
        _ if quantum_is_ket_expr(lhs) && quantum_is_bra_expr(rhs) =>
          Some([outer_product(lhs, rhs)])
        _ if @symcore.application_has_name(lhs, "OuterProduct", arity=2) &&
          quantum_is_ket_expr(rhs) =>
          match quantum_expr_args(lhs) {
            Some([ket_arg, bra_arg]) if quantum_is_ket_expr(ket_arg) &&
              quantum_is_bra_expr(bra_arg) =>
              Some([inner_product(bra_arg, rhs, evaluate=false), ket_arg])
            _ => None
          }
        _ if @symcore.application_has_name(rhs, "OuterProduct", arity=2) &&
          quantum_is_bra_expr(lhs) =>
          match quantum_expr_args(rhs) {
            Some([ket_arg, bra_arg]) if quantum_is_ket_expr(ket_arg) &&
              quantum_is_bra_expr(bra_arg) =>
              Some([inner_product(lhs, ket_arg, evaluate=false), bra_arg])
            _ => None
          }
        _ if @symcore.application_has_name(lhs, "OuterProduct", arity=2) &&
          @symcore.application_has_name(rhs, "OuterProduct", arity=2) =>
          match (quantum_expr_args(lhs), quantum_expr_args(rhs)) {
            (Some([lhs_ket, lhs_bra]), Some([rhs_ket, rhs_bra])) =>
              Some([
                inner_product(lhs_bra, rhs_ket, evaluate=false),
                outer_product(lhs_ket, rhs_bra),
              ])
            _ => None
          }
        _ =>
          match (tensor_product_args(lhs), tensor_product_args(rhs)) {
            (Some(lhs_items), Some(rhs_items)) if lhs_items.length() ==
              rhs_items.length() => {
              let lhs_kind = quantum_kind(lhs)
              let rhs_kind = quantum_kind(rhs)
              if lhs_kind == QBra && rhs_kind == QKet {
                let out : Array[Expr] = []
                for idx in 0..<lhs_items.length() {
                  out.push(
                    inner_product(
                      lhs_items[idx],
                      rhs_items[idx],
                      evaluate=false,
                    ),
                  )
                }
                Some(out)
              } else {
                let out : Array[Expr] = []
                for idx in 0..<lhs_items.length() {
                  out.push(
                    quantum_canonical_mul(
                      @symcore.raw_mul([lhs_items[idx], rhs_items[idx]]),
                    ),
                  )
                }
                Some([@symcore.raw_function("TensorProduct", out)])
              }
            }
            (Some(_), None) if quantum_kind(lhs) == QKet &&
              quantum_is_ket_expr(rhs) =>
              raise ValueError(
                "Multiplication of TensorProduct(*kets)*ket is invalid.",
              )
            (None, Some(_)) if quantum_is_ket_expr(lhs) &&
              quantum_kind(rhs) == QKet =>
              raise ValueError(
                "Multiplication of ket*TensorProduct(*kets) is invalid.",
              )
            (Some(_), None) if quantum_kind(lhs) == QBra &&
              quantum_is_bra_expr(rhs) =>
              raise ValueError(
                "Multiplication of TensorProduct(*bras)*bra is invalid.",
              )
            (None, Some(_)) if quantum_is_bra_expr(lhs) &&
              quantum_kind(rhs) == QBra =>
              raise ValueError(
                "Multiplication of bra*TensorProduct(*bras) is invalid.",
              )
            _ =>
              if quantum_is_ket_expr(lhs) && quantum_is_ket_expr(rhs) {
                raise ValueError(
                  "Multiplication of two kets is not allowed. Use TensorProduct instead.",
                )
              } else if quantum_is_bra_expr(lhs) && quantum_is_bra_expr(rhs) {
                raise ValueError(
                  "Multiplication of two bras is not allowed. Use TensorProduct instead.",
                )
              } else {
                None
              }
          }
      }
  }
}

///|
pub fn quantum_canonical_mul(
  expr : Expr,
) -> Expr raise @symphysics.PhysicsError {
  let factors = match expr {
    Mul(items) => items
    _ => [expr]
  }
  match quantum_distribute_mul(factors) {
    Some(expanded) => return expanded
    None => ()
  }
  let work = match expr {
    Mul(items) => items.copy()
    _ => [expr]
  }
  let result : Array[Expr] = []
  while work.length() > 1 {
    let first = work[0]
    let second = work[1]
    match quantum_transform_state_pair(first, second) {
      Some(transformed) => {
        for idx in 0..<(transformed.length() - 1) {
          result.push(transformed[idx])
        }
        let rebuilt : Array[Expr] = [transformed[transformed.length() - 1]]
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
        let rebuilt : Array[Expr] = []
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
  base : Expr,
  exp : Expr,
) -> Expr raise @symphysics.PhysicsError {
  let kind = quantum_kind(base)
  if kind == QKet || kind == QBra {
    raise ValueError(
      "A bra or ket to a power is invalid, use TensorProduct instead.",
    )
  }
  match quantum_integer_value(exp) {
    Some(0) => int(1)
    Some(1) => base
    Some(power) if quantum_expr_has_name(base, "FermionOp") && power < 0 =>
      raise ValueError("Negative powers of fermion operators are undefined")
    Some(power) if quantum_expr_has_name(base, "FermionOp") && power > 1 =>
      int(0)
    Some(power) =>
      match gate_pow_simplify(base, power) {
        Some(simplified) if simplified != @symcore.raw_pow(base, exp) =>
          simplified
        _ =>
          match power {
            n if n > 1 =>
              match base {
                Add(_) => {
                  let mut acc = base
                  for _ in 1..<n {
                    acc = quantum_canonical_mul(@symcore.raw_mul([acc, base]))
                  }
                  acc
                }
                _ => @symcore.raw_pow(base, exp)
              }
            _ => @symcore.raw_pow(base, exp)
          }
      }
    _ => @symcore.raw_pow(base, exp)
  }
}
