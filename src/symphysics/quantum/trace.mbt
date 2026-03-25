///|
/// Trace helpers aligned with the symbolic/matrix core of
/// `sympy.physics.quantum.trace`.

///|
fn quantum_trace_raw(expr : Expr, indices : Array[Int]) -> Expr {
  if indices.is_empty() {
    @symcore.raw_function("Tr", [expr])
  } else {
    @symcore.raw_function("Tr", [expr, quantum_tuple_expr(indices)])
  }
}

///|
fn trace_indices_from_expr(expr : Expr) -> Array[Int]? {
  match @symcore.tuple_items(expr) {
    Some(args) => {
      let out : Array[Int] = []
      for arg in args {
        match quantum_integer_value(arg) {
          Some(idx) => out.push(idx)
          None => return None
        }
      }
      Some(out)
    }
    None =>
      match quantum_integer_value(expr) {
        Some(idx) => Some([idx])
        None => None
      }
  }
}

///|
fn trace_tensor_product_items(
  items : Array[Expr],
  indices : Array[Int],
) -> Expr {
  let factors : Array[Expr] = []
  for idx in 0..<items.length() {
    if indices.is_empty() || indices.contains(idx) {
      factors.push(tr_doit(tr(items[idx])))
    } else {
      factors.push(items[idx])
    }
  }
  quantum_mul_from_args_preserve(factors)
}

///|
pub fn tr(expr : Expr, indices? : Array[Int] = []) -> Expr {
  match expr {
    Expr::Add(args) => @symcore.add(args.map(arg => tr(arg, indices~)))
    Expr::Mul(_) => {
      let (scalar, body) = quantum_split_scalar_factors(expr)
      match body {
        None => scalar
        Some(core) => scalar * quantum_trace_raw(core, indices)
      }
    }
    Expr::Pow(base, exp) =>
      if quantum_is_scalar_like(base) && quantum_is_scalar_like(exp) {
        expr
      } else {
        quantum_trace_raw(expr, indices)
      }
    _ =>
      if quantum_is_scalar_like(expr) {
        expr
      } else {
        quantum_trace_raw(expr, indices)
      }
  }
}

///|
pub fn tr_doit(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) =>
      quantum_add_from_args_preserve(args.map(arg => tr_doit(arg)))
    Expr::Mul(args) =>
      quantum_mul_from_args_preserve(args.map(arg => tr_doit(arg)))
    Expr::Function("Tr", args) if args.length() >= 1 => {
      let indices = if args.length() >= 2 {
        trace_indices_from_expr(args[1]).unwrap_or([])
      } else {
        []
      }
      match args[0] {
        _ if density_from_expr(args[0]) is Some(density_expr) =>
          density_expr.trace(indices~)
        Expr::Function("OuterProduct", inner) if inner.length() == 2 &&
          indices.is_empty() => inner_product(inner[1], inner[0])
        Expr::Function("TensorProduct", items) =>
          trace_tensor_product_items(items, indices)
        _ => expr
      }
    }
    _ => expr
  }
}

///|
pub fn tr_permute(expr : Expr, pos : Int) -> Expr {
  match expr {
    Expr::Function("Tr", args) if args.length() >= 1 =>
      match args[0] {
        Expr::Mul(body_args) if !body_args.is_empty() => {
          let len = body_args.length()
          let shift = if pos >= 0 { pos % len } else { len - -pos % len }
          if shift == 0 {
            expr
          } else {
            let rotated : Array[Expr] = []
            for idx in 0..<len {
              rotated.push(body_args[(len - shift + idx) % len])
            }
            if args.length() == 1 {
              @symcore.raw_function("Tr", [@symcore.raw_mul(rotated)])
            } else {
              @symcore.raw_function("Tr", [@symcore.raw_mul(rotated), args[1]])
            }
          }
        }
        _ => expr
      }
    _ => expr
  }
}

///|
pub fn matrix_trace(
  matrix : @symphysics.ExplicitMatrix,
) -> Expr raise @symphysics.PhysicsError {
  guard matrix.height() == matrix.width() else {
    raise @symphysics.PhysicsError::ShapeError("trace expects a square matrix")
  }
  let mut acc = int(0)
  for idx in 0..<matrix.height() {
    acc = acc + matrix.get(idx, idx)
  }
  acc
}
