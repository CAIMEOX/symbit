///|
/// Vector algebra aligned with `sympy.physics.vector.vector`.

///|
pub impl Eq for Vector with equal(self, other : Vector) -> Bool {
  vector_equal(self, other)
}

///|
pub impl Eq for Vector with not_equal(self, other : Vector) -> Bool {
  !vector_equal(self, other)
}

///|
pub impl Add for Vector with add(self, other : Vector) {
  vector_add(self, other)
}

///|
pub impl Sub for Vector with sub(self, other : Vector) {
  vector_add(self, other.neg())
}

///|
pub fn vector_zero() -> Vector {
  Vector::{ args: [] }
}

///|
pub fn vector_from_components(
  frame : ReferenceFrame,
  comps : Array[Expr],
) -> Vector {
  vector_normalize([(frame.index_, clone_expr_array(comps))])
}

///|
fn vector_normalize(items : Array[(Int, Array[Expr])]) -> Vector {
  let combined : Map[Int, Array[Expr]] = {}
  for item in items {
    let frame_id = item.0
    let comps = item.1
    match combined.get(frame_id) {
      Some(prev) => combined.set(frame_id, components_add(prev, comps))
      None => combined.set(frame_id, clone_expr_array(comps))
    }
  }
  let ids : Array[Int] = []
  for entry in combined {
    ids.push(entry.0)
  }
  ids.sort()
  let out : Array[(Int, Array[Expr])] = []
  for frame_id in ids {
    let comps = combined[frame_id]
    if !(expr_is_zero(comps[0]) &&
      expr_is_zero(comps[1]) &&
      expr_is_zero(comps[2])) {
      out.push(
        (
          frame_id,
          [
            simplify_expr(comps[0]),
            simplify_expr(comps[1]),
            simplify_expr(comps[2]),
          ],
        ),
      )
    }
  }
  Vector::{ args: out }
}

///|
pub fn Vector::is_zero(self : Vector) -> Bool {
  self.args.is_empty()
}

///|
pub fn Vector::scale(self : Vector, scalar : Expr) -> Vector {
  let out : Array[(Int, Array[Expr])] = []
  for item in self.args {
    let frame_id = item.0
    let comps = item.1
    out.push((frame_id, components_scale(scalar, comps)))
  }
  vector_normalize(out)
}

///|
pub fn Vector::neg(self : Vector) -> Vector {
  self.scale(neg_one_expr())
}

///|
fn vector_add(lhs : Vector, rhs : Vector) -> Vector {
  let out : Array[(Int, Array[Expr])] = []
  for item in lhs.args {
    out.push(item)
  }
  for item in rhs.args {
    out.push(item)
  }
  vector_normalize(out)
}

///|
pub fn Vector::components_in(
  self : Vector,
  frame : ReferenceFrame,
) -> Array[Expr] raise VectorError {
  if self.is_zero() {
    return zero_components()
  }
  let mut acc = zero_components()
  for item in self.args {
    let frame_id = item.0
    let comps = item.1
    let source = frame_registry_get(frame_id)
    let mapped = matrix_mul_vec(frame.dcm(source), comps)
    acc = components_add(acc, mapped)
  }
  [simplify_expr(acc[0]), simplify_expr(acc[1]), simplify_expr(acc[2])]
}

///|
pub fn Vector::to_matrix(
  self : Vector,
  frame : ReferenceFrame,
) -> @symphysics.ExplicitMatrix raise VectorError {
  let comps = self.components_in(frame)
  matrix_from_rows([[comps[0]], [comps[1]], [comps[2]]])
}

///|
pub fn Vector::express(
  self : Vector,
  frame : ReferenceFrame,
  variables? : Bool = false,
) -> Vector raise VectorError {
  let comps = self.components_in(frame)
  let normalized = if variables {
    [
      express_scalar(comps[0], frame, variables=true),
      express_scalar(comps[1], frame, variables=true),
      express_scalar(comps[2], frame, variables=true),
    ]
  } else {
    comps
  }
  vector_from_components(frame, normalized)
}

///|
pub fn Vector::dot(self : Vector, other : Vector) -> Expr raise VectorError {
  if self.is_zero() || other.is_zero() {
    return zero_expr()
  }
  let anchor = frame_registry_get(self.args[0].0)
  let lhs = self.components_in(anchor)
  let rhs = other.components_in(anchor)
  simplify_expr(components_dot(lhs, rhs))
}

///|
pub fn Vector::cross(self : Vector, other : Vector) -> Vector raise VectorError {
  if self.is_zero() || other.is_zero() {
    return vector_zero()
  }
  let anchor = frame_registry_get(self.args[0].0)
  let lhs = self.components_in(anchor)
  let rhs = other.components_in(anchor)
  vector_from_components(anchor, components_cross(lhs, rhs))
}

///|
pub fn Vector::outer(self : Vector, other : Vector) -> Dyadic raise VectorError {
  if self.is_zero() || other.is_zero() {
    return dyadic_zero()
  }
  let left = if self.args.length() == 1 {
    self.args[0]
  } else {
    let frame = frame_registry_get(self.args[0].0)
    (frame.index_, self.components_in(frame))
  }
  let right = if other.args.length() == 1 {
    other.args[0]
  } else {
    let frame = frame_registry_get(other.args[0].0)
    (frame.index_, other.components_in(frame))
  }
  let out : Array[(Expr, Int, Int, Int, Int)] = []
  for i in 0..<3 {
    for j in 0..<3 {
      let coeff = left.1[i] * right.1[j]
      if !expr_is_zero(coeff) {
        out.push((coeff, left.0, i, right.0, j))
      }
    }
  }
  dyadic_normalize(out)
}

///|
pub fn Vector::normalize(self : Vector) -> Vector raise VectorError {
  if self.is_zero() {
    raise VectorError::ValueError("cannot normalize zero vector")
  }
  let anchor = frame_registry_get(self.args[0].0)
  let comps = self.components_in(anchor)
  let norm_sq = components_norm_sq(comps)
  if expr_is_zero(norm_sq) {
    raise VectorError::ValueError("cannot normalize zero vector")
  }
  self.express(anchor).scale(@symelem.sqrt(norm_sq) ^ neg_one_expr())
}

///|
pub fn Vector::subs(self : Vector, env : Map[String, Expr]) -> Vector {
  let out : Array[(Int, Array[Expr])] = []
  for item in self.args {
    let frame_id = item.0
    let comps = item.1
    out.push(
      (
        frame_id,
        [
          @symcore.subst(comps[0], env),
          @symcore.subst(comps[1], env),
          @symcore.subst(comps[2], env),
        ],
      ),
    )
  }
  vector_normalize(out)
}

///|
pub fn Vector::applyfunc(self : Vector, f : (Expr) -> Expr) -> Vector {
  let out : Array[(Int, Array[Expr])] = []
  for item in self.args {
    let frame_id = item.0
    let comps = item.1
    out.push((frame_id, [f(comps[0]), f(comps[1]), f(comps[2])]))
  }
  vector_normalize(out)
}

///|
pub fn Vector::simplify(self : Vector) -> Vector {
  self.applyfunc(simplify_expr)
}

///|
pub fn Vector::diff(
  self : Vector,
  wrt : Expr,
  frame : ReferenceFrame,
  var_in_dcm? : Bool = true,
) -> Vector raise VectorError {
  if var_in_dcm {
    let comps = self.components_in(frame)
    return vector_from_components(frame, [
      @symcalculus.diff(comps[0], wrt),
      @symcalculus.diff(comps[1], wrt),
      @symcalculus.diff(comps[2], wrt),
    ])
  }
  let out : Array[(Int, Array[Expr])] = []
  for item in self.args {
    let frame_id = item.0
    let comps = item.1
    out.push(
      (
        frame_id,
        [
          @symcalculus.diff(comps[0], wrt),
          @symcalculus.diff(comps[1], wrt),
          @symcalculus.diff(comps[2], wrt),
        ],
      ),
    )
  }
  vector_normalize(out)
}

///|
pub fn Vector::dt(
  self : Vector,
  frame : ReferenceFrame,
  order? : Int = 1,
) -> Vector raise VectorError {
  if order < 0 {
    raise VectorError::ValueError("order must be non-negative")
  }
  if order == 0 || self.is_zero() {
    return self
  }
  let mut out = vector_zero()
  for item in self.args {
    let frame_id = item.0
    let comps = item.1
    let local_frame = frame_registry_get(frame_id)
    let term = vector_from_components(local_frame, comps)
    let next = if local_frame == frame {
      vector_from_components(frame, [
        @symcalculus.diff(
          express_scalar(comps[0], frame, variables=true),
          dynamicsymbols_t,
        ),
        @symcalculus.diff(
          express_scalar(comps[1], frame, variables=true),
          dynamicsymbols_t,
        ),
        @symcalculus.diff(
          express_scalar(comps[2], frame, variables=true),
          dynamicsymbols_t,
        ),
      ])
    } else {
      let omega = local_frame.ang_vel_in(frame).express(local_frame)
      term.dt(local_frame) + omega.cross(term)
    }
    out = out + next
  }
  out.dt(frame, order=order - 1)
}

///|
pub fn Vector::separate(self : Vector) -> Array[(ReferenceFrame, Vector)] {
  let out : Array[(ReferenceFrame, Vector)] = []
  for item in self.args {
    let frame_id = item.0
    let comps = item.1
    let frame = frame_registry_get(frame_id)
    out.push((frame, vector_from_components(frame, comps)))
  }
  out
}

///|
fn vector_equal(lhs : Vector, rhs : Vector) -> Bool {
  if lhs.is_zero() && rhs.is_zero() {
    return true
  }
  let anchor = if !lhs.is_zero() {
    frame_registry_get(lhs.args[0].0)
  } else if !rhs.is_zero() {
    frame_registry_get(rhs.args[0].0)
  } else {
    return true
  }
  let lhs_comps = lhs.components_in(anchor) catch { _ => return false }
  let rhs_comps = rhs.components_in(anchor) catch { _ => return false }
  expr_eq(lhs_comps[0], rhs_comps[0]) &&
  expr_eq(lhs_comps[1], rhs_comps[1]) &&
  expr_eq(lhs_comps[2], rhs_comps[2])
}

///|
pub fn _check_vector(vec : Vector) -> Vector {
  vec
}
