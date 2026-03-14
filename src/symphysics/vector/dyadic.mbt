///|
/// Dyadic algebra aligned with `sympy.physics.vector.dyadic`.

///|
pub impl Eq for Dyadic with equal(self, other : Dyadic) -> Bool {
  dyadic_equal(self, other)
}

///|
pub impl Eq for Dyadic with not_equal(self, other : Dyadic) -> Bool {
  !dyadic_equal(self, other)
}

///|
pub impl Add for Dyadic with add(self, other : Dyadic) {
  dyadic_add(self, other)
}

///|
pub impl Sub for Dyadic with sub(self, other : Dyadic) {
  dyadic_add(self, other.neg())
}

///|
pub fn dyadic_zero() -> Dyadic {
  Dyadic::{ args: [] }
}

///|
pub fn dyadic_basis(
  left : ReferenceFrame,
  left_axis : Int,
  right : ReferenceFrame,
  right_axis : Int,
) -> Dyadic {
  dyadic_normalize([
    (one_expr(), left.index_, left_axis, right.index_, right_axis),
  ])
}

///|
fn dyadic_key(coeff : (@symcore.Expr, Int, Int, Int, Int)) -> String {
  coeff.1.to_string() +
  ":" +
  coeff.2.to_string() +
  ":" +
  coeff.3.to_string() +
  ":" +
  coeff.4.to_string()
}

///|
fn dyadic_normalize(
  items : Array[(@symcore.Expr, Int, Int, Int, Int)],
) -> Dyadic {
  let combined : Map[String, (@symcore.Expr, Int, Int, Int, Int)] = {}
  for item in items {
    let key = dyadic_key(item)
    match combined.get(key) {
      Some(prev) =>
        combined.set(key, (prev.0 + item.0, prev.1, prev.2, prev.3, prev.4))
      None => combined.set(key, item)
    }
  }
  let keys : Array[String] = []
  for entry in combined {
    keys.push(entry.0)
  }
  keys.sort()
  let out : Array[(@symcore.Expr, Int, Int, Int, Int)] = []
  for key in keys {
    let value = combined[key]
    let coeff = simplify_expr(value.0)
    if !expr_is_zero(coeff) {
      out.push((coeff, value.1, value.2, value.3, value.4))
    }
  }
  Dyadic::{ args: out }
}

///|
pub fn Dyadic::scale(self : Dyadic, scalar : @symcore.Expr) -> Dyadic {
  let out : Array[(@symcore.Expr, Int, Int, Int, Int)] = []
  for item in self.args {
    out.push((item.0 * scalar, item.1, item.2, item.3, item.4))
  }
  dyadic_normalize(out)
}

///|
pub fn Dyadic::neg(self : Dyadic) -> Dyadic {
  self.scale(neg_one_expr())
}

///|
fn dyadic_add(lhs : Dyadic, rhs : Dyadic) -> Dyadic {
  let out : Array[(@symcore.Expr, Int, Int, Int, Int)] = []
  for item in lhs.args {
    out.push(item)
  }
  for item in rhs.args {
    out.push(item)
  }
  dyadic_normalize(out)
}

///|
pub fn Dyadic::dot_vector(
  self : Dyadic,
  other : Vector,
) -> Vector raise VectorError {
  let mut out = vector_zero()
  for item in self.args {
    let coeff = item.0
    let left = frame_registry_get(item.1).basis(item.2)
    let right = frame_registry_get(item.3).basis(item.4)
    out = out + left.scale(coeff * right.dot(other))
  }
  out
}

///|
pub fn Dyadic::dot_dyadic(
  self : Dyadic,
  other : Dyadic,
) -> Dyadic raise VectorError {
  let mut out = dyadic_zero()
  for left_item in self.args {
    let coeff = left_item.0
    let left = frame_registry_get(left_item.1).basis(left_item.2)
    let right = frame_registry_get(left_item.3).basis(left_item.4)
    for right_item in other.args {
      let coeff2 = right_item.0
      let left2 = frame_registry_get(right_item.1).basis(right_item.2)
      let right2 = frame_registry_get(right_item.3).basis(right_item.4)
      out = out + left.outer(right2).scale(coeff * coeff2 * right.dot(left2))
    }
  }
  out
}

///|
pub fn Dyadic::cross_vector(
  self : Dyadic,
  other : Vector,
) -> Dyadic raise VectorError {
  let mut out = dyadic_zero()
  for item in self.args {
    let coeff = item.0
    let left = frame_registry_get(item.1).basis(item.2)
    let right = frame_registry_get(item.3).basis(item.4)
    out = out + left.outer(right.cross(other)).scale(coeff)
  }
  out
}

///|
pub fn Dyadic::express(
  self : Dyadic,
  frame1 : ReferenceFrame,
  frame2? : ReferenceFrame? = None,
  variables? : Bool = false,
) -> Dyadic raise VectorError {
  let right_frame = frame2.unwrap_or(frame1)
  let mut out = dyadic_zero()
  for item in self.args {
    let scalar = if variables {
      express_scalar(item.0, frame1, variables=true)
    } else {
      item.0
    }
    let left = frame_registry_get(item.1)
      .basis(item.2)
      .express(frame1, variables~)
    let right = frame_registry_get(item.3)
      .basis(item.4)
      .express(right_frame, variables~)
    out = out + left.outer(right).scale(scalar)
  }
  out
}

///|
pub fn Dyadic::to_matrix(
  self : Dyadic,
  frame1 : ReferenceFrame,
  frame2? : ReferenceFrame? = None,
) -> @symphysics.ExplicitMatrix raise VectorError {
  let right_frame = frame2.unwrap_or(frame1)
  let expressed = self.express(frame1, frame2=Some(right_frame))
  let rows : Array[Array[@symcore.Expr]] = [
    [zero_expr(), zero_expr(), zero_expr()],
    [zero_expr(), zero_expr(), zero_expr()],
    [zero_expr(), zero_expr(), zero_expr()],
  ]
  for item in expressed.args {
    if item.1 == frame1.index_ && item.3 == right_frame.index_ {
      rows[item.2][item.4] = rows[item.2][item.4] + item.0
    }
  }
  matrix_from_rows(rows)
}

///|
pub fn Dyadic::dt(
  self : Dyadic,
  frame : ReferenceFrame,
  order? : Int = 1,
) -> Dyadic raise VectorError {
  if order < 0 {
    raise VectorError::ValueError("order must be non-negative")
  }
  if order == 0 || self.args.is_empty() {
    return self
  }
  let mut out = dyadic_zero()
  for item in self.args {
    let coeff = item.0
    let left = frame_registry_get(item.1).basis(item.2)
    let right = frame_registry_get(item.3).basis(item.4)
    let coeff_dt = @symcalculus.diff(
      express_scalar(coeff, frame, variables=true),
      dynamicsymbols_t,
    )
    out = out + left.outer(right).scale(coeff_dt)
    out = out + left.dt(frame).outer(right).scale(coeff)
    out = out + left.outer(right.dt(frame)).scale(coeff)
  }
  out.dt(frame, order=order - 1)
}

///|
fn dyadic_equal(lhs : Dyadic, rhs : Dyadic) -> Bool {
  if lhs.args.is_empty() && rhs.args.is_empty() {
    return true
  }
  let left_frame = if !lhs.args.is_empty() {
    frame_registry_get(lhs.args[0].1)
  } else {
    frame_registry_get(rhs.args[0].1)
  }
  let right_frame = if !lhs.args.is_empty() {
    frame_registry_get(lhs.args[0].3)
  } else {
    frame_registry_get(rhs.args[0].3)
  }
  let lm = lhs.to_matrix(left_frame, frame2=Some(right_frame)) catch {
    _ => return false
  }
  let rm = rhs.to_matrix(left_frame, frame2=Some(right_frame)) catch {
    _ => return false
  }
  for i in 0..<3 {
    for j in 0..<3 {
      let lhs_cell = try! lm.get(i, j)
      let rhs_cell = try! rm.get(i, j)
      if !expr_eq(lhs_cell, rhs_cell) {
        return false
      }
    }
  }
  true
}

///|
pub fn _check_dyadic(dyadic : Dyadic) -> Dyadic {
  dyadic
}
