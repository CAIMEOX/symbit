///|
/// Vector-calculus helpers aligned with `sympy.physics.vector.fieldfunctions`.

///|
fn expr_depends_on(expr : Expr, wrt : Expr) -> Bool {
  if @symcore.compare_expr(expr, wrt) == 0 {
    return true
  }
  match expr {
    Expr::Add(args)
    | Expr::Mul(args)
    | Expr::Function(_, args) =>
      args.any(fn(arg) { expr_depends_on(arg, wrt) })
    Expr::Pow(base, exp) =>
      expr_depends_on(base, wrt) || expr_depends_on(exp, wrt)
    _ => false
  }
}

///|
fn expr_int_value(expr : Expr) -> Int? {
  match expr {
    Expr::Number(n) if n.is_integral() => Some(n.numerator().to_int())
    _ => None
  }
}

///|
fn integrate_scalar(
  expr : Expr,
  wrt : Expr,
) -> Expr raise VectorError {
  if !expr_depends_on(expr, wrt) {
    return simplify_expr(expr * wrt)
  }
  if @symcore.compare_expr(expr, wrt) == 0 {
    return simplify_expr(
      (wrt ^ int_expr(2)) * rational_expr(1, 2),
    )
  }
  match expr {
    Expr::Add(args) => {
      let out : Array[Expr] = []
      for arg in args {
        out.push(integrate_scalar(arg, wrt))
      }
      simplify_expr(@symcore.add(out))
    }
    Expr::Mul(args) => {
      let indep : Array[Expr] = []
      let dep : Array[Expr] = []
      for arg in args {
        if expr_depends_on(arg, wrt) {
          dep.push(arg)
        } else {
          indep.push(arg)
        }
      }
      let coeff = if indep.is_empty() {
        one_expr()
      } else {
        @symcore.mul(indep)
      }
      if dep.length() == 1 {
        return simplify_expr(coeff * integrate_scalar(dep[0], wrt))
      }
      raise VectorError::ValueError("unsupported antiderivative")
    }
    Expr::Pow(base, exp) if @symcore.compare_expr(base, wrt) == 0 =>
      match expr_int_value(exp) {
        Some(-1) =>
          raise VectorError::ValueError("log antiderivative not implemented")
        Some(n) => {
          let next = n + 1
          let coeff = rational_expr(1, next)
          simplify_expr(coeff * (wrt ^ int_expr(next)))
        }
        None =>
          raise VectorError::ValueError("unsupported power antiderivative")
      }
    Expr::Function("sin", args) if args.length() == 1 &&
      @symcore.compare_expr(args[0], wrt) == 0 =>
      simplify_expr(expr_neg(@symelem.cos(wrt)))
    Expr::Function("cos", args) if args.length() == 1 &&
      @symcore.compare_expr(args[0], wrt) == 0 =>
      simplify_expr(@symelem.sin(wrt))
    _ => raise VectorError::ValueError("unsupported antiderivative")
  }
}

///|
pub fn gradient(scalar : Expr, frame : ReferenceFrame) -> Vector {
  let x = coordinate_symbol(frame, 0)
  let y = coordinate_symbol(frame, 1)
  let z = coordinate_symbol(frame, 2)
  frame
  .x()
  .scale(@symcalculus.diff(express_scalar(scalar, frame, variables=true), x)) +
  frame
  .y()
  .scale(@symcalculus.diff(express_scalar(scalar, frame, variables=true), y)) +
  frame
  .z()
  .scale(@symcalculus.diff(express_scalar(scalar, frame, variables=true), z))
}

///|
pub fn divergence(
  vect : Vector,
  frame : ReferenceFrame,
) -> Expr raise VectorError {
  if vect.is_zero() {
    return zero_expr()
  }
  let comps = vect.express(frame, variables=true).components_in(frame)
  let x = coordinate_symbol(frame, 0)
  let y = coordinate_symbol(frame, 1)
  let z = coordinate_symbol(frame, 2)
  simplify_expr(
    @symcalculus.diff(comps[0], x) +
    @symcalculus.diff(comps[1], y) +
    @symcalculus.diff(comps[2], z),
  )
}

///|
pub fn curl(vect : Vector, frame : ReferenceFrame) -> Vector raise VectorError {
  if vect.is_zero() {
    return vector_zero()
  }
  let comps = vect.express(frame, variables=true).components_in(frame)
  let x = coordinate_symbol(frame, 0)
  let y = coordinate_symbol(frame, 1)
  let z = coordinate_symbol(frame, 2)
  let cx = @symcalculus.diff(comps[2], y) - @symcalculus.diff(comps[1], z)
  let cy = @symcalculus.diff(comps[0], z) - @symcalculus.diff(comps[2], x)
  let cz = @symcalculus.diff(comps[1], x) - @symcalculus.diff(comps[0], y)
  vector_from_components(frame, [
    simplify_expr(cx),
    simplify_expr(cy),
    simplify_expr(cz),
  ])
}

///|
pub fn is_conservative(field : Vector) -> Bool raise VectorError {
  if field.is_zero() {
    return true
  }
  let frame = frame_registry_get(field.args[0].0)
  curl(field, frame).is_zero()
}

///|
pub fn is_solenoidal(field : Vector) -> Bool raise VectorError {
  if field.is_zero() {
    return true
  }
  let frame = frame_registry_get(field.args[0].0)
  expr_is_zero(divergence(field, frame))
}

///|
pub fn scalar_potential(
  field : Vector,
  frame : ReferenceFrame,
) -> Expr raise VectorError {
  if field.is_zero() {
    return zero_expr()
  }
  let comps = field.express(frame, variables=true).components_in(frame)
  let x = coordinate_symbol(frame, 0)
  let y = coordinate_symbol(frame, 1)
  let z = coordinate_symbol(frame, 2)
  let mut phi = integrate_scalar(comps[0], x)
  let ry = simplify_expr(comps[1] - @symcalculus.diff(phi, y))
  if !expr_is_zero(ry) {
    phi = simplify_expr(phi + integrate_scalar(ry, y))
  }
  let rz = simplify_expr(comps[2] - @symcalculus.diff(phi, z))
  if !expr_is_zero(rz) {
    phi = simplify_expr(phi + integrate_scalar(rz, z))
  }
  let check = gradient(phi, frame) - field.express(frame, variables=true)
  if !check.is_zero() {
    raise VectorError::ValueError(
      "field is not conservative in the requested frame",
    )
  }
  simplify_expr(phi)
}

///|
pub fn scalar_potential_difference(
  scalar : Expr,
  frame : ReferenceFrame,
  point1 : Point,
  point2 : Point,
  origin : Point,
) -> Expr raise VectorError {
  let p1 = point1
    .pos_from(origin)
    .express(frame, variables=true)
    .components_in(frame)
  let p2 = point2
    .pos_from(origin)
    .express(frame, variables=true)
    .components_in(frame)
  let env1 : Map[String, Expr] = {}
  env1.set(coordinate_symbol_name(frame, 0), p1[0])
  env1.set(coordinate_symbol_name(frame, 1), p1[1])
  env1.set(coordinate_symbol_name(frame, 2), p1[2])
  let env2 : Map[String, Expr] = {}
  env2.set(coordinate_symbol_name(frame, 0), p2[0])
  env2.set(coordinate_symbol_name(frame, 1), p2[1])
  env2.set(coordinate_symbol_name(frame, 2), p2[2])
  simplify_expr(@symcore.subst(scalar, env2) - @symcore.subst(scalar, env1))
}

///|
pub fn scalar_potential_difference_field(
  field : Vector,
  frame : ReferenceFrame,
  point1 : Point,
  point2 : Point,
  origin : Point,
) -> Expr raise VectorError {
  scalar_potential_difference(
    scalar_potential(field, frame),
    frame,
    point1,
    point2,
    origin,
  )
}
