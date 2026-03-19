///|
/// Normal-ordering helpers for bosonic and fermionic operator products.
///
/// This follows the same recursive strategy as
/// `sympy.physics.quantum.operatorordering`, but it operates on the explicit
/// constructor expressions `BosonOp(...)` and `FermionOp(...)` used in this
/// MoonBit port.

///|
fn quantum_expand_powers(
  factors : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = Array::new()
  for factor in factors {
    match factor {
      @symcore.Expr::Pow(base, exp) =>
        match quantum_integer_value(exp) {
          Some(n) if n > 0 =>
            for _ in 0..<n {
              out.push(base)
            }
          _ => out.push(factor)
        }
      _ => out.push(factor)
    }
  }
  out
}

///|
fn quantum_op_sort_key(expr : @symcore.Expr) -> (Int, String) {
  match expr {
    @symcore.Expr::Function("BosonOp", args)
    | @symcore.Expr::Function("FermionOp", args) if args.length() == 2 => {
      let annihilation_rank = if args[1] == @symcore.int(0) { 0 } else { 1 }
      (annihilation_rank, @symprint.to_string(args[0]))
    }
    @symcore.Expr::Function("CreateBoson", args) if args.length() == 1 =>
      (0, @symprint.to_string(args[0]))
    @symcore.Expr::Function("AnnihilateBoson", args) if args.length() == 1 =>
      (1, @symprint.to_string(args[0]))
    _ => (2, @symprint.to_string(expr))
  }
}

///|
fn quantum_same_species(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Bool {
  match (lhs, rhs) {
    (@symcore.Expr::Function(name1, _), @symcore.Expr::Function(name2, _)) =>
      name1 == name2
    _ => false
  }
}

///|
fn quantum_operatorordering_pair(
  current : @symcore.Expr,
  next : @symcore.Expr,
  ordered_form : Bool,
  independent : Bool,
) -> @symcore.Expr? {
  guard quantum_expr_has_any_name(current, [
      "BosonOp", "FermionOp", "AnnihilateBoson", "CreateBoson",
    ]) &&
    quantum_expr_has_any_name(next, [
      "BosonOp", "FermionOp", "AnnihilateBoson", "CreateBoson",
    ]) else {
    return None
  }
  let current_key = quantum_op_sort_key(current)
  let next_key = quantum_op_sort_key(next)
  if current_key <= next_key {
    return None
  }
  let same_species = quantum_same_species(current, next)
  let same_name = match (current, next) {
    (@symcore.Expr::Function(_, cargs), @symcore.Expr::Function(_, nargs)) if cargs.length() >=
      1 &&
      nargs.length() >= 1 => cargs[0] == nargs[0]
    _ => false
  }
  if quantum_expr_has_any_name(current, [
      "BosonOp", "AnnihilateBoson", "CreateBoson",
    ]) &&
    quantum_expr_has_any_name(next, [
      "BosonOp", "AnnihilateBoson", "CreateBoson",
    ]) {
    if ordered_form {
      if same_name {
        Some(next * current + @symcore.int(1))
      } else if independent {
        Some(next * current)
      } else {
        Some(next * current + commutator(next, current, evaluate=false))
      }
    } else {
      Some(next * current)
    }
  } else if quantum_expr_has_name(current, "FermionOp") &&
    quantum_expr_has_name(next, "FermionOp") {
    if same_species {
      let swapped = @symcore.int(-1) * next * current
      if ordered_form {
        if same_name &&
          quantum_op_sort_key(current).0 == 1 &&
          quantum_op_sort_key(next).0 == 0 {
          Some(@symcore.int(1) + swapped)
        } else if independent && !same_name {
          Some(swapped)
        } else if !same_name &&
          !independent &&
          quantum_op_sort_key(current).0 == 1 &&
          quantum_op_sort_key(next).0 == 0 {
          Some(swapped + anticommutator(next, current, evaluate=false))
        } else {
          Some(swapped)
        }
      } else {
        Some(swapped)
      }
    } else {
      None
    }
  } else {
    Some(next * current)
  }
}

///|
fn quantum_reorder_product(
  expr : @symcore.Expr,
  ordered_form : Bool,
  independent : Bool,
  recursive_limit : Int,
  recursive_depth : Int,
) -> @symcore.Expr {
  guard recursive_depth <= recursive_limit else { return expr }
  match expr {
    @symcore.Expr::Mul(args) => {
      let factors = quantum_expand_powers(args)
      let rebuilt : Array[@symcore.Expr] = Array::new()
      let mut idx = 0
      let mut changed = false
      while idx < factors.length() {
        if idx + 1 < factors.length() {
          match
            quantum_operatorordering_pair(
              factors[idx],
              factors[idx + 1],
              ordered_form,
              independent,
            ) {
            Some(replacement) => {
              rebuilt.push(replacement)
              idx += 2
              changed = true
            }
            None => {
              rebuilt.push(factors[idx])
              idx += 1
            }
          }
        } else {
          rebuilt.push(factors[idx])
          idx += 1
        }
      }
      if !changed {
        expr
      } else {
        quantum_reorder_expression(
          quantum_mul_from_args_preserve(rebuilt),
          ordered_form,
          independent,
          recursive_limit,
          recursive_depth + 1,
        )
      }
    }
    _ => expr
  }
}

///|
fn quantum_reorder_expression(
  expr : @symcore.Expr,
  ordered_form : Bool,
  independent : Bool,
  recursive_limit : Int,
  recursive_depth : Int,
) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) =>
      quantum_add_from_args_preserve(
        args.map(term => {
          quantum_reorder_product(
            term, ordered_form, independent, recursive_limit, recursive_depth,
          )
        }),
      )
    @symcore.Expr::Mul(_) =>
      quantum_reorder_product(
        expr, ordered_form, independent, recursive_limit, recursive_depth,
      )
    _ => expr
  }
}

///|
pub fn normal_ordered_form(
  expr : @symcore.Expr,
  independent? : Bool = false,
  recursive_limit? : Int = 10,
) -> @symcore.Expr {
  quantum_reorder_expression(expr, true, independent, recursive_limit, 0)
}

///|
pub fn normal_order(
  expr : @symcore.Expr,
  independent? : Bool = false,
  recursive_limit? : Int = 10,
) -> @symcore.Expr {
  quantum_reorder_expression(expr, false, independent, recursive_limit, 0)
}
