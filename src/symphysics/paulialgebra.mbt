///|
/// Algebraic Pauli operators aligned with `sympy.physics.paulialgebra`.
///
/// In SymPy, Pauli matrices are noncommutative symbols. `symcore` does not
/// track commutativity, so ordered products should be built with
/// `pauli_product(...)` instead of the generic `*` operator.

///|
pub fn delta(i : Int, j : Int) -> Int {
  if i == j {
    1
  } else {
    0
  }
}

///|
pub fn epsilon(i : Int, j : Int, k : Int) -> Int {
  if (i == 1 && j == 2 && k == 3) ||
    (i == 2 && j == 3 && k == 1) ||
    (i == 3 && j == 1 && k == 2) {
    1
  } else if (i == 1 && j == 3 && k == 2) ||
    (i == 3 && j == 2 && k == 1) ||
    (i == 2 && j == 1 && k == 3) {
    -1
  } else {
    0
  }
}

///|
fn pauli_symbol_name(index : Int, label : String) -> String {
  label + index.to_string()
}

///|
fn pauli_symbol_expr(index : Int, label : String) -> Expr {
  Expr::Symbol(pauli_symbol_name(index, label))
}

///|
fn pauli_symbol_parts(expr : Expr) -> (Int, String)? {
  match expr {
    Expr::Symbol(name) => {
      if name.length() < 2 {
        return None
      }
      let last = name[name.length() - 1:name.length()].to_string()
      let label = name[:name.length() - 1].to_string()
      if label == "" {
        return None
      }
      match last {
        "1" => Some((1, label))
        "2" => Some((2, label))
        "3" => Some((3, label))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn pauli_power_atom(expr : Expr) -> (Int, String)? {
  match pauli_symbol_parts(expr) {
    Some(atom) => Some(atom)
    None =>
      match expr {
        Expr::Pow(base, exp) =>
          match (pauli_symbol_parts(base), expr_integer_value(exp)) {
            (Some(atom), Some(n)) if n % 2 != 0 => Some(atom)
            (Some(_), Some(_)) => Some((0, ""))
            _ => None
          }
        _ => None
      }
  }
}

///|
fn ncsymbol_expr_name(expr : Expr) -> String? {
  match expr {
    Expr::Function("NCSymbol", [Expr::Symbol(name)]) => Some(name)
    _ => None
  }
}

///|
fn is_tensor_product(expr : Expr) -> Bool {
  match expr {
    Expr::Function("TensorProduct", _) => true
    _ => false
  }
}

///|
fn expr_has_ordered_factor(expr : Expr) -> Bool {
  if pauli_symbol_parts(expr) is Some(_) ||
    ncsymbol_expr_name(expr) is Some(_) ||
    is_tensor_product(expr) {
    return true
  }
  match expr {
    Expr::Add(parts) | Expr::Mul(parts) => {
      for part in parts {
        if expr_has_ordered_factor(part) {
          return true
        }
      }
      false
    }
    Expr::Pow(base, exp) =>
      expr_has_ordered_factor(base) || expr_has_ordered_factor(exp)
    Expr::Function(_, parts) => {
      for part in parts {
        if expr_has_ordered_factor(part) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn is_zero_expr(expr : Expr) -> Bool {
  expr == int(0)
}

///|
fn is_one_expr(expr : Expr) -> Bool {
  expr == int(1)
}

///|
fn pauli_flush_segment(
  out : Array[Expr],
  basis : Int,
  coeff : Expr,
  label : String,
) -> Unit {
  if is_zero_expr(coeff) {
    return
  }
  let term = if basis == 0 {
    coeff
  } else if is_one_expr(coeff) {
    pauli_symbol_expr(basis, label)
  } else {
    @symcore.mul([coeff, pauli_symbol_expr(basis, label)])
  }
  if !is_one_expr(term) || out.is_empty() {
    out.push(term)
  }
}

///|
fn pauli_absorb_atom(basis : Int, coeff : Expr, next : Int) -> (Int, Expr) {
  if basis == 0 {
    (next, coeff)
  } else if basis == next {
    (0, coeff)
  } else {
    let mut target = 0
    for k in [1, 2, 3] {
      if epsilon(basis, next, k) != 0 {
        target = k
      }
    }
    let sign = epsilon(basis, next, target)
    (target, @symcore.mul([coeff, i_expr(), int(sign)]))
  }
}

///|
pub fn pauli(index : Int, label? : String = "sigma") -> Expr raise PhysicsError {
  guard index == 1 || index == 2 || index == 3 else {
    raise PhysicsError::IndexError("Invalid Pauli index")
  }
  pauli_symbol_expr(index, label)
}

///|
pub fn pauli_power(base : Expr, exp : Int) -> Expr {
  @symcore.raw_pow(base, int(exp))
}

///|
pub fn pauli_product(factors : Array[Expr]) -> Expr {
  @symcore.raw_mul(factors)
}

///|
pub fn tensor_product(factors : Array[Expr]) -> Expr {
  let scalars : Array[Expr] = Array::new()
  let args : Array[Expr] = Array::new()
  for factor in factors {
    if expr_has_ordered_factor(factor) {
      args.push(factor)
    } else {
      scalars.push(factor)
      args.push(int(1))
    }
  }
  let base = @symcore.function("TensorProduct", args)
  let scalar = @symcore.mul(scalars)
  if is_one_expr(scalar) {
    base
  } else {
    @symcore.mul([scalar, base])
  }
}

///|
pub fn ncsymbol(name : String) -> Expr {
  @symcore.function("NCSymbol", [Expr::Symbol(name)])
}

///|
pub fn pauli_mul(lhs : Expr, rhs : Expr) -> Expr {
  match (pauli_symbol_parts(lhs), pauli_symbol_parts(rhs)) {
    (Some((i, li)), Some((j, lj))) =>
      if li != lj {
        pauli_product([lhs, rhs])
      } else if i == j {
        int(1)
      } else {
        let mut k = 1
        while k <= 3 {
          let sign = epsilon(i, j, k)
          if sign != 0 {
            return @symcore.mul([i_expr(), int(sign), pauli_symbol_expr(k, li)])
          }
          k = k + 1
        }
        int(0)
      }
    _ => pauli_product([lhs, rhs])
  }
}

///|
pub fn evaluate_pauli_product(arg : Expr) -> Expr {
  match arg {
    Expr::Pow(base, exp) =>
      match (pauli_symbol_parts(base), expr_integer_value(exp)) {
        (Some((i, label)), Some(n)) =>
          if n % 2 == 0 {
            int(1)
          } else {
            pauli_symbol_expr(i, label)
          }
        _ =>
          @symcore.raw_pow(
            evaluate_pauli_product(base),
            evaluate_pauli_product(exp),
          )
      }
    Expr::Add(parts) => @symcore.add(parts.map(evaluate_pauli_product))
    Expr::Function("TensorProduct", parts) =>
      tensor_product(parts.map(evaluate_pauli_product))
    Expr::Mul(parts) => {
      let scalars : Array[Expr] = Array::new()
      let ordered : Array[Expr] = Array::new()
      let mut current_label = ""
      let mut current_basis = 0
      let mut current_coeff = int(1)
      let flush_current = () => {
        if current_label != "" ||
          current_basis != 0 ||
          !is_one_expr(current_coeff) {
          pauli_flush_segment(
            ordered, current_basis, current_coeff, current_label,
          )
          current_label = ""
          current_basis = 0
          current_coeff = int(1)
        }
      }
      for part in parts {
        match pauli_power_atom(part) {
          Some((0, _)) => ()
          Some((index, label)) =>
            if current_label == "" {
              current_label = label
              current_basis = index
            } else if current_label == label {
              let next = pauli_absorb_atom(current_basis, current_coeff, index)
              current_basis = next.0
              current_coeff = next.1
            } else {
              flush_current()
              current_label = label
              current_basis = index
            }
          None =>
            match part {
              Expr::Function("TensorProduct", inner) => {
                flush_current()
                ordered.push(tensor_product(inner.map(evaluate_pauli_product)))
              }
              _ =>
                match ncsymbol_expr_name(part) {
                  Some(_) => {
                    flush_current()
                    match ncsymbol_expr_name(part) {
                      Some(name) => ordered.push(Expr::Symbol(name))
                      None => ()
                    }
                  }
                  None => scalars.push(part)
                }
            }
        }
      }
      flush_current()
      let scalar = @symcore.mul(scalars)
      if is_zero_expr(scalar) {
        int(0)
      } else if ordered.is_empty() {
        scalar
      } else {
        let out : Array[Expr] = Array::new()
        if !is_one_expr(scalar) {
          out.push(scalar)
        }
        for part in ordered {
          if is_one_expr(part) {
            ()
          } else {
            out.push(part)
          }
        }
        if out.is_empty() {
          int(1)
        } else if out.length() == 1 {
          out[0]
        } else {
          @symcore.raw_mul(out)
        }
      }
    }
    _ => arg
  }
}
