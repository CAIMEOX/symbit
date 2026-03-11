///|
/// Algebraic Pauli operators aligned with `sympy.physics.paulialgebra`.
///
/// In SymPy, Pauli matrices are noncommutative symbols. `symcore` does not
/// track commutativity, so ordered products should be built with
/// `pauli_product(...)` instead of the generic `*` operator.

///|
pub fn delta(i : Int, j : Int) -> Int {
  if i == j { 1 } else { 0 }
}

///|
pub fn epsilon(i : Int, j : Int, k : Int) -> Int {
  if (i == 1 && j == 2 && k == 3) ||
    (i == 2 && j == 3 && k == 1) ||
    (i == 3 && j == 1 && k == 2) {
    1
  } else if
    (i == 1 && j == 3 && k == 2) ||
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
fn pauli_symbol_expr(index : Int, label : String) -> @symcore.Expr {
  @symcore.symbol(pauli_symbol_name(index, label))
}

///|
fn pauli_symbol_parts(expr : @symcore.Expr) -> (Int, String)? {
  match expr {
    @symcore.Expr::Symbol(name) => {
      if name.length() < 2 {
        return None
      }
      let last = (try! name[name.length() - 1:name.length()]).to_string()
      let label = (try! name[:name.length() - 1]).to_string()
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
fn pauli_power_atom(expr : @symcore.Expr) -> (Int, String)? {
  match pauli_symbol_parts(expr) {
    Some(atom) => Some(atom)
    None =>
      match expr {
        @symcore.Expr::Pow(base, exp) =>
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
fn ncsymbol_expr_name(expr : @symcore.Expr) -> String? {
  match expr {
    @symcore.Expr::Function("NCSymbol", [@symcore.Expr::Symbol(name)]) => Some(name)
    _ => None
  }
}

///|
fn is_tensor_product(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Function("TensorProduct", _) => true
    _ => false
  }
}

///|
fn expr_has_ordered_factor(expr : @symcore.Expr) -> Bool {
  if pauli_symbol_parts(expr) is Some(_) || ncsymbol_expr_name(expr) is Some(_) || is_tensor_product(expr) {
    return true
  }
  match expr {
    @symcore.Expr::Add(parts) | @symcore.Expr::Mul(parts) => {
      for part in parts {
        if expr_has_ordered_factor(part) {
          return true
        }
      }
      false
    }
    @symcore.Expr::Pow(base, exp) => expr_has_ordered_factor(base) || expr_has_ordered_factor(exp)
    @symcore.Expr::Function(_, parts) => {
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
fn is_zero_expr(expr : @symcore.Expr) -> Bool {
  expr == @symcore.int(0)
}

///|
fn is_one_expr(expr : @symcore.Expr) -> Bool {
  expr == @symcore.int(1)
}

///|
fn pauli_flush_segment(
  out : Array[@symcore.Expr],
  basis : Int,
  coeff : @symcore.Expr,
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
fn pauli_absorb_atom(
  basis : Int,
  coeff : @symcore.Expr,
  next : Int,
) -> (Int, @symcore.Expr) {
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
    (target, @symcore.mul([coeff, i_expr(), @symcore.int(sign)]))
  }
}

///|
pub fn pauli(index : Int, label? : String = "sigma") -> @symcore.Expr raise PhysicsError {
  guard index == 1 || index == 2 || index == 3 else {
    raise PhysicsError::IndexError("Invalid Pauli index")
  }
  pauli_symbol_expr(index, label)
}

///|
pub fn pauli_power(base : @symcore.Expr, exp : Int) -> @symcore.Expr {
  @symcore.raw_pow(base, @symcore.int(exp))
}

///|
pub fn pauli_product(factors : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.raw_mul(factors)
}

///|
pub fn tensor_product(factors : Array[@symcore.Expr]) -> @symcore.Expr {
  let scalars : Array[@symcore.Expr] = Array::new()
  let args : Array[@symcore.Expr] = Array::new()
  for factor in factors {
    if expr_has_ordered_factor(factor) {
      args.push(factor)
    } else {
      scalars.push(factor)
      args.push(@symcore.int(1))
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
pub fn ncsymbol(name : String) -> @symcore.Expr {
  @symcore.function("NCSymbol", [@symcore.symbol(name)])
}

///|
pub fn pauli_mul(
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
) -> @symcore.Expr {
  match (pauli_symbol_parts(lhs), pauli_symbol_parts(rhs)) {
    (Some((i, li)), Some((j, lj))) => {
      if li != lj {
        pauli_product([lhs, rhs])
      } else if i == j {
        @symcore.int(1)
      } else {
        let mut k = 1
        while k <= 3 {
          let sign = epsilon(i, j, k)
          if sign != 0 {
            return @symcore.mul([i_expr(), @symcore.int(sign), pauli_symbol_expr(k, li)])
          }
          k = k + 1
        }
        @symcore.int(0)
      }
    }
    _ => pauli_product([lhs, rhs])
  }
}

///|
pub fn evaluate_pauli_product(arg : @symcore.Expr) -> @symcore.Expr {
  match arg {
    @symcore.Expr::Pow(base, exp) =>
      match (pauli_symbol_parts(base), expr_integer_value(exp)) {
        (Some((i, label)), Some(n)) =>
          if n % 2 == 0 {
            @symcore.int(1)
          } else {
            pauli_symbol_expr(i, label)
          }
        _ => @symcore.raw_pow(evaluate_pauli_product(base), evaluate_pauli_product(exp))
      }
    @symcore.Expr::Add(parts) => @symcore.add(parts.map(evaluate_pauli_product))
    @symcore.Expr::Function("TensorProduct", parts) =>
      tensor_product(parts.map(evaluate_pauli_product))
    @symcore.Expr::Mul(parts) => {
      let scalars : Array[@symcore.Expr] = Array::new()
      let ordered : Array[@symcore.Expr] = Array::new()
      let mut current_label = ""
      let mut current_basis = 0
      let mut current_coeff = @symcore.int(1)
      let flush_current = () => {
        if current_label != "" || current_basis != 0 || !is_one_expr(current_coeff) {
          pauli_flush_segment(ordered, current_basis, current_coeff, current_label)
          current_label = ""
          current_basis = 0
          current_coeff = @symcore.int(1)
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
              @symcore.Expr::Function("TensorProduct", inner) => {
                flush_current()
                ordered.push(tensor_product(inner.map(evaluate_pauli_product)))
              }
              _ =>
                match ncsymbol_expr_name(part) {
                  Some(_) => {
                    flush_current()
                    match ncsymbol_expr_name(part) {
                      Some(name) => ordered.push(@symcore.symbol(name))
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
        @symcore.int(0)
      } else if ordered.is_empty() {
        scalar
      } else {
        let out : Array[@symcore.Expr] = Array::new()
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
          @symcore.int(1)
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
