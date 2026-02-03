///|
pub type Expr = @symcore.Expr

///|
pub type Matrix = Array[Array[Expr]]

///|
pub(all) suberror QuaternionError {
  InvalidSeq(String)
  InvalidMatrix(String)
  InvalidAxis(String)
  InvalidNorm(String)
  ZeroNorm
  NotPure
}

///|
pub impl Show for QuaternionError with output(self, logger : &Logger) -> Unit {
  match self {
    QuaternionError::InvalidSeq(msg) => logger.write_string("InvalidSeq(\{msg})")
    QuaternionError::InvalidMatrix(msg) =>
      logger.write_string("InvalidMatrix(\{msg})")
    QuaternionError::InvalidAxis(msg) =>
      logger.write_string("InvalidAxis(\{msg})")
    QuaternionError::InvalidNorm(msg) =>
      logger.write_string("InvalidNorm(\{msg})")
    QuaternionError::ZeroNorm => logger.write_string("ZeroNorm")
    QuaternionError::NotPure => logger.write_string("NotPure")
  }
}

///|
fn expr_zero() -> Expr {
  @symcore.int(0)
}

///|
fn expr_one() -> Expr {
  @symcore.int(1)
}

///|
fn expr_int(n : Int) -> Expr {
  @symcore.int(n)
}

///|
fn expr_rational(num : Int, den : Int) -> Expr {
  try! @symcore.rational_from_ints(num, den)
}

///|
fn expr_pow(base : Expr, exp : Int) -> Expr {
  base ^ expr_int(exp)
}

///|
fn expr_neg(x : Expr) -> Expr {
  expr_int(-1) * x
}

///|
fn expr_div(a : Expr, b : Expr) -> Expr {
  a * (b ^ expr_int(-1))
}

///|
fn expr_sqrt(x : Expr) -> Expr {
  @symcore.function("sqrt", [x])
}

///|
fn expr_sin(x : Expr) -> Expr {
  @symcore.function("sin", [x])
}

///|
fn expr_cos(x : Expr) -> Expr {
  @symcore.function("cos", [x])
}

///|
fn expr_asin(x : Expr) -> Expr {
  @symcore.function("asin", [x])
}

///|
fn expr_acos(x : Expr) -> Expr {
  @symcore.function("acos", [x])
}

///|
fn expr_atan2(y : Expr, x : Expr) -> Expr {
  @symcore.function("atan2", [y, x])
}

///|
fn expr_exp(x : Expr) -> Expr {
  @symcore.function("exp", [x])
}

///|
fn expr_log(x : Expr) -> Expr {
  @symcore.function("log", [x])
}

///|
fn expr_sign(x : Expr) -> Expr {
  @symcore.function("sign", [x])
}

///|
fn expr_pi() -> Expr {
  @symcore.symbol("pi")
}

///|
fn expr_number_value(expr : Expr) -> @symnum.BigRational? {
  match expr {
    @symcore.Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
fn expr_is_zero(expr : Expr) -> Bool? {
  match expr_number_value(expr) {
    Some(n) => Some(n.is_zero())
    None => None
  }
}

///|
fn expr_is_negative(expr : Expr) -> Bool? {
  match expr_number_value(expr) {
    Some(n) => Some(n.compare(@symnum.BigRational::zero()) < 0)
    None => None
  }
}

///|
fn expr_is_positive(expr : Expr) -> Bool? {
  match expr_number_value(expr) {
    Some(n) => Some(n.compare(@symnum.BigRational::zero()) > 0)
    None => None
  }
}

///|
fn fuzzy_not(value : Bool?) -> Bool? {
  match value {
    Some(true) => Some(false)
    Some(false) => Some(true)
    None => None
  }
}

///|
fn fuzzy_or(values : Array[Bool?]) -> Bool? {
  let mut any_unknown = false
  for v in values {
    match v {
      Some(true) => return Some(true)
      Some(false) => ()
      None => any_unknown = true
    }
  }
  if any_unknown { None } else { Some(false) }
}

///|
fn matrix_det3(m : Matrix) -> Expr raise QuaternionError {
  if m.length() != 3 {
    raise QuaternionError::InvalidMatrix("expected 3x3")
  }
  if m[0].length() != 3 || m[1].length() != 3 || m[2].length() != 3 {
    raise QuaternionError::InvalidMatrix("expected 3x3")
  }
  let a = m[0][0]
  let b = m[0][1]
  let c = m[0][2]
  let d = m[1][0]
  let e = m[1][1]
  let f = m[1][2]
  let g = m[2][0]
  let h = m[2][1]
  let i = m[2][2]
  a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
}

///|
fn check_norm(elements : Array[Expr], norm : Expr?) -> Unit raise QuaternionError {
  match norm {
    None => ()
    Some(n) => {
      match expr_is_positive(n) {
        Some(false) => raise QuaternionError::InvalidNorm("norm must be positive")
        _ => ()
      }
      let mut numeric = true
      let mut sum = @symnum.BigRational::zero()
      for el in elements {
        match expr_number_value(el) {
          Some(v) => sum = sum.add_r(v.mul_r(v))
          None => numeric = false
        }
      }
      if numeric {
        match expr_number_value(n) {
          Some(vn) => {
            let n2 = vn.mul_r(vn)
            if n2.compare(sum) != 0 {
              raise QuaternionError::InvalidNorm("incompatible norm")
            }
          }
          None => ()
        }
      }
    }
  }
}

///|
pub struct Quaternion {
  a : Expr
  b : Expr
  c : Expr
  d : Expr
  real_field : Bool
  norm_override : Expr?
}

///|
fn quat_unchecked(
  a : Expr,
  b : Expr,
  c : Expr,
  d : Expr,
  real_field : Bool,
  norm_override : Expr?,
) -> Quaternion {
  Quaternion::{
    a: a,
    b: b,
    c: c,
    d: d,
    real_field: real_field,
    norm_override: norm_override,
  }
}

///|
pub fn Quaternion::new(
  a : Expr,
  b : Expr,
  c : Expr,
  d : Expr,
  real_field? : Bool = true,
  norm? : Expr,
) -> Quaternion raise QuaternionError {
  check_norm([a, b, c, d], norm)
  quat_unchecked(a, b, c, d, real_field, norm)
}

///|
pub fn Quaternion::with_norm(self : Quaternion, norm : Expr?) -> Quaternion raise QuaternionError {
  check_norm([self.a, self.b, self.c, self.d], norm)
  quat_unchecked(self.a, self.b, self.c, self.d, self.real_field, norm)
}

///|
pub fn Quaternion::a(self : Quaternion) -> Expr {
  self.a
}

///|
pub fn Quaternion::b(self : Quaternion) -> Expr {
  self.b
}

///|
pub fn Quaternion::c(self : Quaternion) -> Expr {
  self.c
}

///|
pub fn Quaternion::d(self : Quaternion) -> Expr {
  self.d
}

///|
pub fn Quaternion::real_field(self : Quaternion) -> Bool {
  self.real_field
}

///|
fn split_sign(expr : Expr) -> (Bool, Expr) {
  match expr {
    @symcore.Expr::Number(n) =>
      if n.compare(@symnum.BigRational::zero()) < 0 {
        (true, @symcore.number(n.neg_r()))
      } else {
        (false, expr)
      }
    _ => (false, expr)
  }
}

///|
pub fn Quaternion::to_string(self : Quaternion) -> String {
  let a_str = @symprint.to_string(self.a)
  let (b_neg, b_abs) = split_sign(self.b)
  let (c_neg, c_abs) = split_sign(self.c)
  let (d_neg, d_abs) = split_sign(self.d)
  let b_str = "\{@symprint.to_string(b_abs)}*i"
  let c_str = "\{@symprint.to_string(c_abs)}*j"
  let d_str = "\{@symprint.to_string(d_abs)}*k"
  let mut out = a_str
  out = out + (if b_neg { " - " } else { " + " }) + b_str
  out = out + (if c_neg { " - " } else { " + " }) + c_str
  out = out + (if d_neg { " - " } else { " + " }) + d_str
  out
}

///|
impl Show for Quaternion with to_string(self) {
  self.to_string()
}

///|
impl Show for Quaternion with output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub fn Quaternion::add(self : Quaternion, other : Quaternion) -> Quaternion {
  quat_unchecked(
    self.a + other.a,
    self.b + other.b,
    self.c + other.c,
    self.d + other.d,
    self.real_field && other.real_field,
    None,
  )
}

///|
pub fn Quaternion::add_scalar(self : Quaternion, other : Expr) -> Quaternion {
  quat_unchecked(self.a + other, self.b, self.c, self.d, self.real_field, None)
}

///|
pub fn Quaternion::sub(self : Quaternion, other : Quaternion) -> Quaternion {
  quat_unchecked(
    self.a - other.a,
    self.b - other.b,
    self.c - other.c,
    self.d - other.d,
    self.real_field && other.real_field,
    None,
  )
}

///|
pub fn Quaternion::neg(self : Quaternion) -> Quaternion {
  quat_unchecked(
    expr_neg(self.a),
    expr_neg(self.b),
    expr_neg(self.c),
    expr_neg(self.d),
    self.real_field,
    self.norm_override,
  )
}

///|
pub fn Quaternion::mul(self : Quaternion, other : Quaternion) -> Quaternion {
  let norm = match (self.norm_override, other.norm_override) {
    (None, None) => None
    _ => Some(self.norm() * other.norm())
  }
  quat_unchecked(
    self.a * other.a - self.b * other.b - self.c * other.c - self.d * other.d,
    self.b * other.a + self.c * other.d - self.d * other.c + self.a * other.b,
    self.c * other.a + self.d * other.b + self.a * other.c - self.b * other.d,
    self.b * other.c - self.c * other.b + self.d * other.a + self.a * other.d,
    self.real_field && other.real_field,
    norm,
  )
}

///|
pub fn Quaternion::mul_scalar(self : Quaternion, other : Expr) -> Quaternion {
  quat_unchecked(other * self.a, other * self.b, other * self.c, other * self.d, self.real_field, None)
}

///|
pub fn Quaternion::div(self : Quaternion, other : Quaternion) -> Quaternion raise QuaternionError {
  self.mul(other.inverse())
}

///|
pub fn Quaternion::div_scalar(self : Quaternion, other : Expr) -> Quaternion {
  self.mul_scalar(expr_div(expr_one(), other))
}

///|
pub fn Quaternion::conjugate(self : Quaternion) -> Quaternion {
  quat_unchecked(
    self.a,
    expr_neg(self.b),
    expr_neg(self.c),
    expr_neg(self.d),
    self.real_field,
    self.norm_override,
  )
}

///|
pub fn Quaternion::norm(self : Quaternion) -> Expr {
  match self.norm_override {
    Some(n) => n
    None =>
      expr_sqrt(
        expr_pow(self.a, 2) +
        expr_pow(self.b, 2) +
        expr_pow(self.c, 2) +
        expr_pow(self.d, 2),
      )
  }
}

///|
fn vector_is_zero_numeric(b : Expr, c : Expr, d : Expr) -> Bool? {
  match (expr_number_value(b), expr_number_value(c), expr_number_value(d)) {
    (Some(bn), Some(cn), Some(dn)) =>
      Some(bn.is_zero() && cn.is_zero() && dn.is_zero())
    _ => None
  }
}

///|
fn quat_is_zero_numeric(q : Quaternion) -> Bool? {
  match (
    expr_number_value(q.a),
    expr_number_value(q.b),
    expr_number_value(q.c),
    expr_number_value(q.d),
  ) {
    (Some(a), Some(b), Some(c), Some(d)) =>
      Some(a.is_zero() && b.is_zero() && c.is_zero() && d.is_zero())
    _ => None
  }
}

///|
pub fn Quaternion::normalize(self : Quaternion) -> Quaternion {
  self.mul_scalar(expr_div(expr_one(), self.norm()))
}

///|
pub fn Quaternion::inverse(self : Quaternion) -> Quaternion raise QuaternionError {
  match quat_is_zero_numeric(self) {
    Some(true) => raise QuaternionError::ZeroNorm
    _ => ()
  }
  self.conjugate().mul_scalar(expr_div(expr_one(), expr_pow(self.norm(), 2)))
}

///|
pub fn Quaternion::pow(self : Quaternion, p : Int) -> Quaternion raise QuaternionError {
  let mut q = self
  let mut pow = p
  if pow < 0 {
    q = q.inverse()
    pow = -pow
  }
  if pow == 1 {
    return q
  }
  let mut res = quat_unchecked(expr_one(), expr_zero(), expr_zero(), expr_zero(), true, None)
  let mut n = pow
  while n > 0 {
    if (n & 1) == 1 {
      res = res.mul(q)
    }
    q = q.mul(q)
    n = n >> 1
  }
  res
}

///|
pub fn Quaternion::exp(self : Quaternion) -> Quaternion {
  let vnorm = expr_sqrt(
    expr_pow(self.b, 2) + expr_pow(self.c, 2) + expr_pow(self.d, 2),
  )
  let ev = expr_exp(self.a)
  match vector_is_zero_numeric(self.b, self.c, self.d) {
    Some(true) => quat_unchecked(ev, expr_zero(), expr_zero(), expr_zero(), self.real_field, None)
    _ => quat_unchecked(
      ev * expr_cos(vnorm),
      expr_div(ev * expr_sin(vnorm) * self.b, vnorm),
      expr_div(ev * expr_sin(vnorm) * self.c, vnorm),
      expr_div(ev * expr_sin(vnorm) * self.d, vnorm),
      self.real_field,
      None,
    )
  }
}

///|
pub fn Quaternion::log(self : Quaternion) -> Quaternion raise QuaternionError {
  let vnorm = expr_sqrt(
    expr_pow(self.b, 2) + expr_pow(self.c, 2) + expr_pow(self.d, 2),
  )
  let qnorm = self.norm()
  match quat_is_zero_numeric(self) {
    Some(true) => raise QuaternionError::ZeroNorm
    _ => ()
  }
  let a = expr_log(qnorm)
  match vector_is_zero_numeric(self.b, self.c, self.d) {
    Some(true) => quat_unchecked(a, expr_zero(), expr_zero(), expr_zero(), self.real_field, None)
    _ => {
      let angle = expr_div(expr_acos(expr_div(self.a, qnorm)), vnorm)
      quat_unchecked(a, self.b * angle, self.c * angle, self.d * angle, self.real_field, None)
    }
  }
}

///|
pub fn Quaternion::pow_cos_sin(self : Quaternion, p : Int) -> Quaternion raise QuaternionError {
  let (axis, angle) = self.to_axis_angle()
  let q2 = Quaternion::from_axis_angle(axis, expr_int(p) * angle)
  q2.mul_scalar(self.norm() ^ expr_int(p))
}

///|
pub fn Quaternion::product_matrix_left(self : Quaternion) -> Matrix {
  [
    [self.a, expr_neg(self.b), expr_neg(self.c), expr_neg(self.d)],
    [self.b, self.a, expr_neg(self.d), self.c],
    [self.c, self.d, self.a, expr_neg(self.b)],
    [self.d, expr_neg(self.c), self.b, self.a],
  ]
}

///|
pub fn Quaternion::product_matrix_right(self : Quaternion) -> Matrix {
  [
    [self.a, expr_neg(self.b), expr_neg(self.c), expr_neg(self.d)],
    [self.b, self.a, self.d, expr_neg(self.c)],
    [self.c, expr_neg(self.d), self.a, self.b],
    [self.d, self.c, expr_neg(self.b), self.a],
  ]
}

///|
pub fn Quaternion::to_matrix(self : Quaternion, vector_only? : Bool = false) -> Matrix {
  if vector_only {
    [[self.b], [self.c], [self.d]]
  } else {
    [[self.a], [self.b], [self.c], [self.d]]
  }
}

///|
pub fn Quaternion::from_elements(elements : Array[Expr]) -> Quaternion raise QuaternionError {
  let n = elements.length()
  if n == 3 {
    Quaternion::new(expr_zero(), elements[0], elements[1], elements[2])
  } else if n == 4 {
    Quaternion::new(elements[0], elements[1], elements[2], elements[3])
  } else {
    raise QuaternionError::InvalidMatrix("expected 3 or 4 elements")
  }
}

///|
pub fn Quaternion::from_matrix(elements : Matrix) -> Quaternion raise QuaternionError {
  let rows = elements.length()
  if rows == 3 || rows == 4 {
    if elements[0].length() == 1 {
      let flat : Array[Expr] = Array::new()
      for row in elements {
        if row.length() != 1 {
          raise QuaternionError::InvalidMatrix("expected column matrix")
        }
        flat.push(row[0])
      }
      Quaternion::from_elements(flat)
    } else {
      raise QuaternionError::InvalidMatrix("expected column matrix")
    }
  } else {
    raise QuaternionError::InvalidMatrix("expected 3x1 or 4x1 matrix")
  }
}

///|
fn is_extrinsic(seq : String) -> Bool raise QuaternionError {
  if seq.length() != 3 {
    raise QuaternionError::InvalidSeq("expected 3 axes")
  }
  let mut intrinsic = true
  let mut extrinsic = true
  for c in seq {
    if !c.is_ascii_uppercase() {
      intrinsic = false
    }
    if !c.is_ascii_lowercase() {
      extrinsic = false
    }
  }
  if !(intrinsic || extrinsic) {
    raise QuaternionError::InvalidSeq("seq must be all lower or all upper")
  }
  let chars : Array[Char] = Array::new()
  for c in seq {
    chars.push(c)
  }
  let a = chars[0]
  let b = chars[1]
  let c = chars[2]
  if a == b || b == c {
    raise QuaternionError::InvalidSeq("consecutive axes must be different")
  }
  for ch in chars {
    if ch != 'x' && ch != 'y' && ch != 'z' && ch != 'X' && ch != 'Y' && ch != 'Z' {
      raise QuaternionError::InvalidSeq("axes must be x,y,z")
    }
  }
  extrinsic
}

///|
pub fn Quaternion::from_axis_angle(
  vector : (Expr, Expr, Expr),
  angle : Expr,
) -> Quaternion {
  let (x0, y0, z0) = vector
  let norm = expr_sqrt(expr_pow(x0, 2) + expr_pow(y0, 2) + expr_pow(z0, 2))
  let x = expr_div(x0, norm)
  let y = expr_div(y0, norm)
  let z = expr_div(z0, norm)
  let half = expr_rational(1, 2)
  let s = expr_sin(angle * half)
  let a = expr_cos(angle * half)
  quat_unchecked(a, x * s, y * s, z * s, true, None)
}

///|
pub fn Quaternion::from_euler(angles : Array[Expr], seq : String) -> Quaternion raise QuaternionError {
  if angles.length() != 3 {
    raise QuaternionError::InvalidSeq("expected 3 angles")
  }
  let extrinsic = is_extrinsic(seq)
  let axes : Array[Char] = Array::new()
  for c in seq {
    axes.push(c)
  }
  let lower = axes.map(ch => ch.to_ascii_lowercase())
  let i = lower[0]
  let j = lower[1]
  let k = lower[2]
  let e = (axis : Char) => match axis {
    'x' => (expr_one(), expr_zero(), expr_zero())
    'y' => (expr_zero(), expr_one(), expr_zero())
    _ => (expr_zero(), expr_zero(), expr_one())
  }
  let qi = Quaternion::from_axis_angle(e(i), angles[0])
  let qj = Quaternion::from_axis_angle(e(j), angles[1])
  let qk = Quaternion::from_axis_angle(e(k), angles[2])
  if extrinsic {
    qk.mul(qj).mul(qi)
  } else {
    qi.mul(qj).mul(qk)
  }
}

///|
pub fn Quaternion::to_euler(
  self : Quaternion,
  seq : String,
  angle_addition? : Bool = true,
  avoid_square_root? : Bool = false,
) -> (Expr, Expr, Expr) raise QuaternionError {
  match self.is_zero_quaternion() {
    Some(true) => raise QuaternionError::ZeroNorm
    _ => ()
  }
  let extrinsic = is_extrinsic(seq)
  let chars : Array[Char] = Array::new()
  for c in seq {
    chars.push(c.to_ascii_lowercase())
  }
  let i1 = chars[0]
  let j1 = chars[1]
  let k1 = chars[2]
  let idx = (ch : Char) => match ch {
    'x' => 1
    'y' => 2
    _ => 3
  }
  let mut i = idx(i1)
  let j = idx(j1)
  let mut k = idx(k1)
  if !extrinsic {
    let tmp = i
    i = k
    k = tmp
  }
  let symmetric = i == k
  if symmetric {
    k = 6 - i - j
  }
  let sign = (i - j) * (j - k) * (k - i) / 2
  let elems = [self.a, self.b, self.c, self.d]
  let mut a = elems[0]
  let mut b = elems[i]
  let mut c = elems[j]
  let mut d = elems[k] * expr_int(sign)
  if !symmetric {
    let aa = a - c
    let bb = b + d
    let cc = c + a
    let dd = d - b
    a = aa
    b = bb
    c = cc
    d = dd
  }
  let mut angles1 : Expr = expr_zero()
  if avoid_square_root {
    if symmetric {
      let n2 = expr_pow(self.norm(), 2)
      angles1 = expr_acos(
        expr_div(expr_pow(a, 2) + expr_pow(b, 2) - expr_pow(c, 2) - expr_pow(d, 2), n2),
      )
    } else {
      let n2 = expr_int(2) * expr_pow(self.norm(), 2)
      angles1 = expr_asin(
        expr_div(expr_pow(c, 2) + expr_pow(d, 2) - expr_pow(a, 2) - expr_pow(b, 2), n2),
      )
    }
  } else {
    angles1 = expr_int(2) * expr_atan2(
      expr_sqrt(expr_pow(c, 2) + expr_pow(d, 2)),
      expr_sqrt(expr_pow(a, 2) + expr_pow(b, 2)),
    )
    if !symmetric {
      angles1 = angles1 - expr_pi() * expr_rational(1, 2)
    }
  }
  let mut case = 0
  if expr_is_zero(c) == Some(true) && expr_is_zero(d) == Some(true) {
    case = 1
  }
  if expr_is_zero(a) == Some(true) && expr_is_zero(b) == Some(true) {
    case = 2
  }
  let mut angles0 : Expr = expr_zero()
  let mut angles2 : Expr = expr_zero()
  if case == 0 {
    if angle_addition {
      angles0 = expr_atan2(b, a) + expr_atan2(d, c)
      angles2 = expr_atan2(b, a) - expr_atan2(d, c)
    } else {
      angles0 = expr_atan2(b * c + a * d, a * c - b * d)
      angles2 = expr_atan2(b * c - a * d, a * c + b * d)
    }
  } else if case == 1 {
    if extrinsic {
      angles0 = expr_zero()
      angles2 = expr_int(2) * expr_atan2(b, a)
    } else {
      angles0 = expr_int(2) * expr_atan2(b, a)
      angles2 = expr_zero()
    }
  } else {
    if extrinsic {
      angles0 = expr_zero()
      angles2 = expr_int(-2) * expr_atan2(d, c)
    } else {
      angles0 = expr_int(2) * expr_atan2(d, c)
      angles2 = expr_zero()
    }
  }
  if !symmetric {
    angles0 = angles0 * expr_int(sign)
  }
  if extrinsic {
    (angles2, angles1, angles0)
  } else {
    (angles0, angles1, angles2)
  }
}

///|
pub fn Quaternion::to_axis_angle(self : Quaternion) -> ((Expr, Expr, Expr), Expr) raise QuaternionError {
  let mut q = self
  match expr_is_negative(q.a) {
    Some(true) => q = q.neg()
    _ => ()
  }
  match quat_is_zero_numeric(q) {
    Some(true) => raise QuaternionError::ZeroNorm
    _ => ()
  }
  q = q.normalize()
  let angle = expr_int(2) * expr_acos(q.a)
  let s = expr_sqrt(expr_one() - q.a * q.a)
  match vector_is_zero_numeric(q.b, q.c, q.d) {
    Some(true) => ((expr_zero(), expr_zero(), expr_zero()), expr_zero())
    _ => ((expr_div(q.b, s), expr_div(q.c, s), expr_div(q.d, s)), angle)
  }
}

///|
pub fn Quaternion::rotate_point(
  pin : (Expr, Expr, Expr),
  r : RotationArg,
) -> (Expr, Expr, Expr) {
  let q = match r {
    RotationArg::AxisAngle(axis, angle) => Quaternion::from_axis_angle(axis, angle)
    RotationArg::Quat(q) => q.normalize()
  }
  let p = quat_unchecked(expr_zero(), pin.0, pin.1, pin.2, true, None)
  let out = q.mul(p).mul(q.conjugate())
  (out.b, out.c, out.d)
}

///|
pub fn Quaternion::to_rotation_matrix(
  self : Quaternion,
  v? : (Expr, Expr, Expr),
  homogeneous? : Bool = true,
) -> Matrix {
  let s = self.norm() ^ expr_int(-2)
  let (m00, m11, m22) = if homogeneous {
    (
      s * (self.a * self.a + self.b * self.b - self.c * self.c - self.d * self.d),
      s * (self.a * self.a - self.b * self.b + self.c * self.c - self.d * self.d),
      s * (self.a * self.a - self.b * self.b - self.c * self.c + self.d * self.d),
    )
  } else {
    (
      expr_one() - expr_int(2) * s * (self.c * self.c + self.d * self.d),
      expr_one() - expr_int(2) * s * (self.b * self.b + self.d * self.d),
      expr_one() - expr_int(2) * s * (self.b * self.b + self.c * self.c),
    )
  }
  let m01 = expr_int(2) * s * (self.b * self.c - self.d * self.a)
  let m02 = expr_int(2) * s * (self.b * self.d + self.c * self.a)
  let m10 = expr_int(2) * s * (self.b * self.c + self.d * self.a)
  let m12 = expr_int(2) * s * (self.c * self.d - self.b * self.a)
  let m20 = expr_int(2) * s * (self.b * self.d - self.c * self.a)
  let m21 = expr_int(2) * s * (self.c * self.d + self.b * self.a)
  match v {
    None => [
      [m00, m01, m02],
      [m10, m11, m12],
      [m20, m21, m22],
    ]
    Some((x, y, z)) => {
      let m03 = x - x * m00 - y * m01 - z * m02
      let m13 = y - x * m10 - y * m11 - z * m12
      let m23 = z - x * m20 - y * m21 - z * m22
      let m30 = expr_zero()
      let m31 = expr_zero()
      let m32 = expr_zero()
      let m33 = expr_one()
      [
        [m00, m01, m02, m03],
        [m10, m11, m12, m13],
        [m20, m21, m22, m23],
        [m30, m31, m32, m33],
      ]
    }
  }
}

///|
pub fn Quaternion::from_rotation_matrix(m : Matrix) -> Quaternion raise QuaternionError {
  if m.length() != 3 {
    raise QuaternionError::InvalidMatrix("expected 3x3")
  }
  if m[0].length() != 3 || m[1].length() != 3 || m[2].length() != 3 {
    raise QuaternionError::InvalidMatrix("expected 3x3")
  }
  let det = matrix_det3(m)
  let absq = det ^ expr_rational(1, 3)
  let a = expr_div(expr_sqrt(absq + m[0][0] + m[1][1] + m[2][2]), expr_int(2))
  let b = expr_div(expr_sqrt(absq + m[0][0] - m[1][1] - m[2][2]), expr_int(2))
  let c = expr_div(expr_sqrt(absq - m[0][0] + m[1][1] - m[2][2]), expr_int(2))
  let d = expr_div(expr_sqrt(absq - m[0][0] - m[1][1] + m[2][2]), expr_int(2))
  let b1 = b * expr_sign(m[2][1] - m[1][2])
  let c1 = c * expr_sign(m[0][2] - m[2][0])
  let d1 = d * expr_sign(m[1][0] - m[0][1])
  Quaternion::new(a, b1, c1, d1)
}

///|
pub fn Quaternion::scalar_part(self : Quaternion) -> Expr {
  self.a
}

///|
pub fn Quaternion::vector_part(self : Quaternion) -> Quaternion {
  quat_unchecked(expr_zero(), self.b, self.c, self.d, self.real_field, None)
}

///|
pub fn Quaternion::axis(self : Quaternion) -> Quaternion {
  let axis = self.vector_part().normalize()
  quat_unchecked(expr_zero(), axis.b, axis.c, axis.d, self.real_field, None)
}

///|
pub fn Quaternion::is_pure(self : Quaternion) -> Bool? {
  expr_is_zero(self.a)
}

///|
pub fn Quaternion::is_zero_quaternion(self : Quaternion) -> Bool? {
  quat_is_zero_numeric(self)
}

///|
pub fn Quaternion::angle(self : Quaternion) -> Expr {
  expr_int(2) * expr_atan2(self.vector_part().norm(), self.scalar_part())
}

///|
pub fn Quaternion::arc_coplanar(self : Quaternion, other : Quaternion) -> Bool? raise QuaternionError {
  if self.is_zero_quaternion() == Some(true) || other.is_zero_quaternion() == Some(true) {
    raise QuaternionError::ZeroNorm
  }
  let axis1 = self.axis()
  let axis2 = other.axis()
  fuzzy_or([
    axis1.sub(axis2).is_zero_quaternion(),
    axis1.add(axis2).is_zero_quaternion(),
  ])
}

///|
pub fn Quaternion::vector_coplanar(
  q1 : Quaternion,
  q2 : Quaternion,
  q3 : Quaternion,
) -> Bool? raise QuaternionError {
  if fuzzy_not(q1.is_pure()) == Some(true) ||
     fuzzy_not(q2.is_pure()) == Some(true) ||
     fuzzy_not(q3.is_pure()) == Some(true) {
    raise QuaternionError::NotPure
  }
  let det = matrix_det3([
    [q1.b, q1.c, q1.d],
    [q2.b, q2.c, q2.d],
    [q3.b, q3.c, q3.d],
  ])
  expr_is_zero(det)
}

///|
pub fn Quaternion::parallel(self : Quaternion, other : Quaternion) -> Bool? raise QuaternionError {
  if fuzzy_not(self.is_pure()) == Some(true) ||
     fuzzy_not(other.is_pure()) == Some(true) {
    raise QuaternionError::NotPure
  }
  (self.mul(other).sub(other.mul(self))).is_zero_quaternion()
}

///|
pub fn Quaternion::orthogonal(self : Quaternion, other : Quaternion) -> Bool? raise QuaternionError {
  if fuzzy_not(self.is_pure()) == Some(true) ||
     fuzzy_not(other.is_pure()) == Some(true) {
    raise QuaternionError::NotPure
  }
  (self.mul(other).add(other.mul(self))).is_zero_quaternion()
}

///|
pub fn Quaternion::index_vector(self : Quaternion) -> Quaternion {
  self.axis().mul_scalar(self.norm())
}

///|
pub fn Quaternion::mensor(self : Quaternion) -> Expr {
  expr_log(self.norm())
}

///|
pub enum RotationArg {
  Quat(Quaternion)
  AxisAngle((Expr, Expr, Expr), Expr)
}
