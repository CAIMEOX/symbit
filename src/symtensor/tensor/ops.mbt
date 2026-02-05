///|
/// Operations on tensor expressions.

///|
fn is_zero_expr(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_zero()
    _ => false
  }
}

///|
fn is_one_expr(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_one()
    _ => false
  }
}

///|
fn flatten_add(args : Array[TensorExpr]) -> Array[TensorExpr] {
  let out : Array[TensorExpr] = Array::new()
  for arg in args {
    match arg {
      TensorExpr::Add(items) =>
        for item in items {
          out.push(item)
        }
      _ => out.push(arg)
    }
  }
  out
}

///|
fn flatten_mul(args : Array[TensorExpr]) -> Array[TensorExpr] {
  let out : Array[TensorExpr] = Array::new()
  for arg in args {
    match arg {
      TensorExpr::Mul(items) =>
        for item in items {
          out.push(item)
        }
      _ => out.push(arg)
    }
  }
  out
}

///|
pub fn add(args : Array[TensorExpr]) -> TensorExpr {
  let flat = flatten_add(args)
  let scalars : Array[@symcore.Expr] = Array::new()
  let others : Array[TensorExpr] = Array::new()
  for arg in flat {
    match arg {
      TensorExpr::Scalar(expr) => scalars.push(expr)
      _ => others.push(arg)
    }
  }
  if !scalars.is_empty() {
    let sum = @symcore.add(scalars)
    if !is_zero_expr(sum) {
      others.push(TensorExpr::Scalar(sum))
    }
  }
  match others.length() {
    0 => TensorExpr::Scalar(@symcore.int(0))
    1 => others[0]
    _ => TensorExpr::Add(others)
  }
}

///|
pub fn mul(args : Array[TensorExpr]) -> TensorExpr {
  let flat = flatten_mul(args)
  let scalars : Array[@symcore.Expr] = Array::new()
  let others : Array[TensorExpr] = Array::new()
  for arg in flat {
    match arg {
      TensorExpr::Scalar(expr) => {
        if is_zero_expr(expr) {
          return TensorExpr::Scalar(@symcore.int(0))
        }
        scalars.push(expr)
      }
      _ => others.push(arg)
    }
  }
  if !scalars.is_empty() {
    let prod = @symcore.mul(scalars)
    if !is_one_expr(prod) {
      others.push(TensorExpr::Scalar(prod))
    }
  }
  match others.length() {
    0 => TensorExpr::Scalar(@symcore.int(1))
    1 => others[0]
    _ => TensorExpr::Mul(others)
  }
}
