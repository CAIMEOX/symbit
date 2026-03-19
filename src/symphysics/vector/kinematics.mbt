///|
/// Kinematic helpers aligned with `sympy.physics.vector.functions`.

///|
fn vector_substitute_time(vec : Vector, value : Expr) -> Vector {
  let env : Map[String, Expr] = { "t": value }
  vec.subs(env)
}

///|
fn motion_integral_symbolic(
  expr : Expr,
  lower : Expr,
  upper : Expr,
) -> Expr {
  @symcore.function("Integral", [
    expr,
    @symcore.function("Tuple", [dynamicsymbols_t, lower, upper]),
  ])
}

///|
fn motion_integral_scalar(
  expr : Expr,
  lower : Expr,
  upper : Expr,
) -> Expr {
  if expr_is_zero(expr) {
    return zero_expr()
  }
  if !expr_depends_on(expr, dynamicsymbols_t) {
    return simplify_expr(expr * (upper - lower))
  }
  match expr {
    Expr::Add(args) => {
      let out : Array[Expr] = []
      for arg in args {
        out.push(motion_integral_scalar(arg, lower, upper))
      }
      simplify_expr(@symcore.add(out))
    }
    Expr::Mul(args) => {
      let indep : Array[Expr] = []
      let dep : Array[Expr] = []
      for arg in args {
        if expr_depends_on(arg, dynamicsymbols_t) {
          dep.push(arg)
        } else {
          indep.push(arg)
        }
      }
      if dep.is_empty() {
        simplify_expr(expr * (upper - lower))
      } else if dep.length() == 1 {
        let coeff = if indep.is_empty() {
          one_expr()
        } else {
          @symcore.mul(indep)
        }
        simplify_expr(coeff * motion_integral_scalar(dep[0], lower, upper))
      } else {
        motion_integral_symbolic(expr, lower, upper)
      }
    }
    Expr::Symbol(name) if name == "t" => {
      let half = try! @symcore.rational_from_ints(1, 2)
      simplify_expr(half * ((upper ^ int_expr(2)) - (lower ^ int_expr(2))))
    }
    Expr::Pow(base, exp) if @symcore.compare_expr(
        base, dynamicsymbols_t,
      ) ==
      0 =>
      match exp {
        Expr::Number(n) if n.is_integral() => {
          let power = n.numerator().to_int()
          if power == -1 {
            motion_integral_symbolic(expr, lower, upper)
          } else {
            let next = power + 1
            let coeff = try! @symcore.rational_from_ints(1, next)
            simplify_expr(
              coeff * ((upper ^ int_expr(next)) - (lower ^ int_expr(next))),
            )
          }
        }
        _ => motion_integral_symbolic(expr, lower, upper)
      }
    Expr::Function("sin", args) if args.length() == 1 &&
      @symcore.compare_expr(args[0], dynamicsymbols_t) == 0 =>
      simplify_expr(@symelem.cos(lower) - @symelem.cos(upper))
    Expr::Function("cos", args) if args.length() == 1 &&
      @symcore.compare_expr(args[0], dynamicsymbols_t) == 0 =>
      simplify_expr(@symelem.sin(upper) - @symelem.sin(lower))
    _ => motion_integral_symbolic(expr, lower, upper)
  }
}

///|
fn vector_integral_between(
  vec : Vector,
  frame : ReferenceFrame,
  lower : Expr,
  upper : Expr,
) -> Vector raise VectorError {
  let comps = vec.express(frame, variables=true).components_in(frame)
  vector_from_components(frame, [
    motion_integral_scalar(comps[0], lower, upper),
    motion_integral_scalar(comps[1], lower, upper),
    motion_integral_scalar(comps[2], lower, upper),
  ])
}

///|
fn normalize_rotation_order(order : String) -> String {
  let out : Array[Char] = []
  for ch in order {
    out.push(
      match ch {
        'X' | 'x' => '1'
        'Y' | 'y' => '2'
        'Z' | 'z' => '3'
        _ => ch
      },
    )
  }
  out.map(ch => ch.to_string()).join("")
}

///|
pub fn partial_velocity(
  vel_vecs : Array[Vector],
  gen_speeds : Array[Expr],
  frame : ReferenceFrame,
) -> Array[Array[Vector]] raise VectorError {
  let out : Array[Array[Vector]] = []
  for vel in vel_vecs {
    let partials : Array[Vector] = []
    for speed in gen_speeds {
      partials.push(vel.diff(speed, frame, var_in_dcm=false))
    }
    out.push(partials)
  }
  out
}

///|
pub fn kinematic_equations(
  speeds : Array[Expr],
  coords : Array[Expr],
  rot_type : String,
  rot_order? : String = "",
) -> Array[Expr] raise VectorError {
  let rot_kind = rot_type.to_lower()
  let order = normalize_rotation_order(rot_order)
  let approved = [
    "123", "231", "312", "132", "213", "321", "121", "131", "212", "232", "313",
    "323", "1", "2", "3", "",
  ]
  if speeds.length() != 3 {
    raise VectorError::TypeError("Need to supply 3 body-fixed speeds")
  }
  if rot_kind == "body" || rot_kind == "space" {
    if !approved.contains(order) {
      raise VectorError::ValueError("Not an acceptable rotation order")
    }
    if coords.length() != 3 {
      raise VectorError::ValueError("Need 3 coordinates for body or space")
    }
    let w1 = speeds[0]
    let w2 = speeds[1]
    let w3 = speeds[2]
    if expr_is_zero(w1) && expr_is_zero(w2) && expr_is_zero(w3) {
      return [zero_expr(), zero_expr(), zero_expr()]
    }
    let q1 = coords[0]
    let q2 = coords[1]
    let q3 = coords[2]
    let q1d = @symcalculus.diff(q1, dynamicsymbols_t)
    let q2d = @symcalculus.diff(q2, dynamicsymbols_t)
    let q3d = @symcalculus.diff(q3, dynamicsymbols_t)
    let s1 = @symelem.sin(q1)
    let s2 = @symelem.sin(q2)
    let s3 = @symelem.sin(q3)
    let c1 = @symelem.cos(q1)
    let c2 = @symelem.cos(q2)
    let c3 = @symelem.cos(q3)
    let inv_c2 = c2 ^ neg_one_expr()
    let inv_s2 = s2 ^ neg_one_expr()
    let mw1 = expr_neg(w1)
    let mw2 = expr_neg(w2)
    let out = match rot_kind {
      "body" =>
        match order {
          "123" =>
            [
              q1d - (w1 * c3 - w2 * s3) * inv_c2,
              q2d - w1 * s3 - w2 * c3,
              q3d - (mw1 * c3 + w2 * s3) * s2 * inv_c2 - w3,
            ]
          "231" =>
            [
              q1d - (w2 * c3 - w3 * s3) * inv_c2,
              q2d - w2 * s3 - w3 * c3,
              q3d - w1 - (mw2 * c3 + w3 * s3) * s2 * inv_c2,
            ]
          "312" =>
            [
              q1d - (mw1 * s3 + w3 * c3) * inv_c2,
              q2d - w1 * c3 - w3 * s3,
              q3d - (w1 * s3 - w3 * c3) * s2 * inv_c2 - w2,
            ]
          "132" =>
            [
              q1d - (w1 * c3 + w3 * s3) * inv_c2,
              q2d + w1 * s3 - w3 * c3,
              q3d - (w1 * c3 + w3 * s3) * s2 * inv_c2 - w2,
            ]
          "213" =>
            [
              q1d - (w1 * s3 + w2 * c3) * inv_c2,
              q2d - w1 * c3 + w2 * s3,
              q3d - (w1 * s3 + w2 * c3) * s2 * inv_c2 - w3,
            ]
          "321" =>
            [
              q1d - (w2 * s3 + w3 * c3) * inv_c2,
              q2d - w2 * c3 + w3 * s3,
              q3d - w1 - (w2 * s3 + w3 * c3) * s2 * inv_c2,
            ]
          "121" =>
            [
              q1d - (w2 * s3 + w3 * c3) * inv_s2,
              q2d - w2 * c3 + w3 * s3,
              q3d - w1 + (w2 * s3 + w3 * c3) * c2 * inv_s2,
            ]
          "131" =>
            [
              q1d - (mw2 * c3 + w3 * s3) * inv_s2,
              q2d - w2 * s3 - w3 * c3,
              q3d - w1 - (w2 * c3 - w3 * s3) * c2 * inv_s2,
            ]
          "212" =>
            [
              q1d - (w1 * s3 - w3 * c3) * inv_s2,
              q2d - w1 * c3 - w3 * s3,
              q3d - (mw1 * s3 + w3 * c3) * c2 * inv_s2 - w2,
            ]
          "232" =>
            [
              q1d - (w1 * c3 + w3 * s3) * inv_s2,
              q2d + w1 * s3 - w3 * c3,
              q3d + (w1 * c3 + w3 * s3) * c2 * inv_s2 - w2,
            ]
          "313" =>
            [
              q1d - (w1 * s3 + w2 * c3) * inv_s2,
              q2d - w1 * c3 + w2 * s3,
              q3d + (w1 * s3 + w2 * c3) * c2 * inv_s2 - w3,
            ]
          "323" =>
            [
              q1d - (mw1 * c3 + w2 * s3) * inv_s2,
              q2d - w1 * s3 - w2 * c3,
              q3d - (w1 * c3 - w2 * s3) * c2 * inv_s2 - w3,
            ]
          _ => raise VectorError::ValueError("Not an acceptable rotation order")
        }
      "space" =>
        match order {
          "123" =>
            [
              q1d - w1 - (w2 * s1 + w3 * c1) * s2 * inv_c2,
              q2d - w2 * c1 + w3 * s1,
              q3d - (w2 * s1 + w3 * c1) * inv_c2,
            ]
          "231" =>
            [
              q1d - (w1 * c1 + w3 * s1) * s2 * inv_c2 - w2,
              q2d + w1 * s1 - w3 * c1,
              q3d - (w1 * c1 + w3 * s1) * inv_c2,
            ]
          "312" =>
            [
              q1d - (w1 * s1 + w2 * c1) * s2 * inv_c2 - w3,
              q2d - w1 * c1 + w2 * s1,
              q3d - (w1 * s1 + w2 * c1) * inv_c2,
            ]
          "132" =>
            [
              q1d - w1 - (mw2 * c1 + w3 * s1) * s2 * inv_c2,
              q2d - w2 * s1 - w3 * c1,
              q3d - (w2 * c1 - w3 * s1) * inv_c2,
            ]
          "213" =>
            [
              q1d - (w1 * s1 - w3 * c1) * s2 * inv_c2 - w2,
              q2d - w1 * c1 - w3 * s1,
              q3d - (mw1 * s1 + w3 * c1) * inv_c2,
            ]
          "321" =>
            [
              q1d - (mw1 * c1 + w2 * s1) * s2 * inv_c2 - w3,
              q2d - w1 * s1 - w2 * c1,
              q3d - (w1 * c1 - w2 * s1) * inv_c2,
            ]
          "121" =>
            [
              q1d - w1 + (w2 * s1 + w3 * c1) * c2 * inv_s2,
              q2d - w2 * c1 + w3 * s1,
              q3d - (w2 * s1 + w3 * c1) * inv_s2,
            ]
          "131" =>
            [
              q1d - w1 - (w2 * c1 - w3 * s1) * c2 * inv_s2,
              q2d - w2 * s1 - w3 * c1,
              q3d - (mw2 * c1 + w3 * s1) * inv_s2,
            ]
          "212" =>
            [
              q1d - (mw1 * s1 + w3 * c1) * c2 * inv_s2 - w2,
              q2d - w1 * c1 - w3 * s1,
              q3d - (w1 * s1 - w3 * c1) * inv_s2,
            ]
          "232" =>
            [
              q1d + (w1 * c1 + w3 * s1) * c2 * inv_s2 - w2,
              q2d + w1 * s1 - w3 * c1,
              q3d - (w1 * c1 + w3 * s1) * inv_s2,
            ]
          "313" =>
            [
              q1d + (w1 * s1 + w2 * c1) * c2 * inv_s2 - w3,
              q2d - w1 * c1 + w2 * s1,
              q3d - (w1 * s1 + w2 * c1) * inv_s2,
            ]
          "323" =>
            [
              q1d - (w1 * c1 - w2 * s1) * c2 * inv_s2 - w3,
              q2d - w1 * s1 - w2 * c1,
              q3d - (mw1 * c1 + w2 * s1) * inv_s2,
            ]
          _ => raise VectorError::ValueError("Not an acceptable rotation order")
        }
      _ => raise VectorError::ValueError("Not an approved rotation type")
    }
    return out.map(simplify_expr)
  }
  if rot_kind != "quaternion" {
    raise VectorError::ValueError("Not an approved rotation type")
  }
  if order != "" {
    raise VectorError::ValueError("Cannot have rotation order for quaternion")
  }
  if coords.length() != 4 {
    raise VectorError::ValueError("Need 4 coordinates for quaternion")
  }
  let q0 = coords[0]
  let q1 = coords[1]
  let q2 = coords[2]
  let q3 = coords[3]
  let q0d = @symcalculus.diff(q0, dynamicsymbols_t)
  let q1d = @symcalculus.diff(q1, dynamicsymbols_t)
  let q2d = @symcalculus.diff(q2, dynamicsymbols_t)
  let q3d = @symcalculus.diff(q3, dynamicsymbols_t)
  let half = try! @symcore.rational_from_ints(1, 2)
  [
    q1d - half * q0 * speeds[0] - half * q2 * speeds[2] + half * q3 * speeds[1],
    q2d - half * q0 * speeds[1] + half * q1 * speeds[2] - half * q3 * speeds[0],
    q3d - half * q0 * speeds[2] - half * q1 * speeds[1] + half * q2 * speeds[0],
    q0d + half * q1 * speeds[0] + half * q2 * speeds[1] + half * q3 * speeds[2],
  ].map(simplify_expr)
}

///|
pub fn get_motion_params(
  frame : ReferenceFrame,
  acceleration? : Vector? = None,
  velocity? : Vector? = None,
  position? : Vector? = None,
  timevalue1? : Expr = zero_expr(),
  timevalue2? : Expr = zero_expr(),
) -> (Vector, Vector, Vector) raise VectorError {
  let zero = vector_zero()
  match acceleration {
    Some(accel) => {
      let velocity_bc = vector_substitute_time(
        match velocity {
          Some(value) => value
          None => zero
        },
        timevalue2,
      )
      let vel = velocity_bc +
        vector_integral_between(accel, frame, timevalue2, dynamicsymbols_t)
      let position_bc = vector_substitute_time(
        match position {
          Some(value) => value
          None => zero
        },
        timevalue1,
      )
      let pos = position_bc +
        vector_integral_between(vel, frame, timevalue1, dynamicsymbols_t)
      (accel, vel, pos)
    }
    None =>
      match velocity {
        Some(vel) => {
          let position_bc = vector_substitute_time(
            match position {
              Some(value) => value
              None => zero
            },
            timevalue1,
          )
          let pos = position_bc +
            vector_integral_between(vel, frame, timevalue1, dynamicsymbols_t)
          (vel.dt(frame), vel, pos)
        }
        None => {
          let pos = match position {
            Some(value) => value
            None => zero
          }
          let vel = pos.dt(frame)
          (vel.dt(frame), vel, pos)
        }
      }
  }
}
