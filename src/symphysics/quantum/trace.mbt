///|
/// Trace helpers aligned with the symbolic/matrix core of
/// `sympy.physics.quantum.trace`.

///|
fn quantum_trace_raw(expr : @symcore.Expr, indices : Array[Int]) -> @symcore.Expr {
  if indices.is_empty() {
    @symcore.raw_function("Tr", [expr])
  } else {
    @symcore.raw_function("Tr", [expr, quantum_tuple_expr(indices)])
  }
}

///|
pub fn tr(
  expr : @symcore.Expr,
  indices? : Array[Int] = [],
) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => @symcore.add(args.map(arg => tr(arg, indices=indices)))
    @symcore.Expr::Mul(_) => {
      let (scalar, body) = quantum_split_scalar_factors(expr)
      match body {
        None => scalar
        Some(core) => scalar * quantum_trace_raw(core, indices)
      }
    }
    @symcore.Expr::Pow(base, exp) =>
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
pub fn tr_doit(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function("Tr", args) if args.length() >= 1 =>
      match args[0] {
        @symcore.Expr::Function("OuterProduct", inner) if inner.length() == 2 =>
          if inner[0] == inner[1] { @symcore.int(1) } else { expr }
        _ => expr
      }
    _ => expr
  }
}

///|
pub fn tr_permute(expr : @symcore.Expr, pos : Int) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function("Tr", args) if args.length() >= 1 =>
      match args[0] {
        @symcore.Expr::Mul(body_args) if !body_args.is_empty() => {
          let len = body_args.length()
          let shift = if pos >= 0 { pos % len } else { len - ((-pos) % len) }
          if shift == 0 {
            expr
          } else {
            let rotated : Array[@symcore.Expr] = []
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
pub fn matrix_trace(matrix : @symphysics.ExplicitMatrix) -> @symcore.Expr raise @symphysics.PhysicsError {
  guard matrix.height() == matrix.width() else {
    raise @symphysics.PhysicsError::ShapeError("trace expects a square matrix")
  }
  let mut acc = @symcore.int(0)
  for idx in 0..<matrix.height() {
    acc = acc + (try! matrix.get(idx, idx))
  }
  acc
}
