///|
fn expr_int(n : Int) -> Expr {
  @symcore.int(n)
}

///|
fn expr_zero() -> Expr {
  expr_int(0)
}

///|
fn expr_rational(num : Int, den : Int) -> Expr {
  try! @symcore.rational_from_ints(num, den)
}

///|
fn expr_pi() -> Expr {
  @symcore.symbol("pi")
}

///|
fn expr_equal_expr(expr : Expr, oracle_str : String) -> Bool raise {
  let res : Result[Bool, Error] = try? @sympy_algebras.expr_equal(
    @symprint.to_string(expr),
    oracle_str,
  )
  match res {
    Ok(v) => v
    Err(e) =>
      fail(
        "expr_equal error: ours=\{@symprint.to_string(expr)} oracle=\{oracle_str} err=\{e}",
      )
  }
}

///|
fn assert_quat_components(q : Quaternion, oracle : Array[String]) -> Unit raise {
  guard oracle.length() == 4 else { fail("oracle arity") }
  guard expr_equal_expr(q.a(), oracle[0]) else {
    fail("a mismatch: ours=\{@symprint.to_string(q.a())}, oracle=\{oracle[0]}")
  }
  guard expr_equal_expr(q.b(), oracle[1]) else {
    fail("b mismatch: ours=\{@symprint.to_string(q.b())}, oracle=\{oracle[1]}")
  }
  guard expr_equal_expr(q.c(), oracle[2]) else {
    fail("c mismatch: ours=\{@symprint.to_string(q.c())}, oracle=\{oracle[2]}")
  }
  guard expr_equal_expr(q.d(), oracle[3]) else {
    fail("d mismatch: ours=\{@symprint.to_string(q.d())}, oracle=\{oracle[3]}")
  }
}

///|
fn matrix_flat_str(m : Matrix) -> Array[String] {
  let out : Array[String] = Array::new()
  for row in m {
    for item in row {
      out.push(@symprint.to_string(item))
    }
  }
  out
}

///|
test "quaternion: add/mul parity" {
  let q1 = try! Quaternion::new(
    expr_int(1),
    expr_int(2),
    expr_int(3),
    expr_int(4),
  )
  let q2 = try! Quaternion::new(
    expr_int(5),
    expr_int(6),
    expr_int(7),
    expr_int(8),
  )
  let add = q1.add(q2)
  let add_oracle = try! @sympy_algebras.quat_add(
    q1.a(),
    q1.b(),
    q1.c(),
    q1.d(),
    q2.a(),
    q2.b(),
    q2.c(),
    q2.d(),
  )
  try! assert_quat_components(add, add_oracle)
  let mul = q1.mul(q2)
  let mul_oracle = try! @sympy_algebras.quat_mul(
    q1.a(),
    q1.b(),
    q1.c(),
    q1.d(),
    q2.a(),
    q2.b(),
    q2.c(),
    q2.d(),
  )
  try! assert_quat_components(mul, mul_oracle)
}

///|
test "quaternion: scalar add/mul parity" {
  let q = try! Quaternion::new(
    expr_int(1),
    expr_int(2),
    expr_int(3),
    expr_int(4),
  )
  let add = q.add_scalar(expr_int(5))
  let add_oracle = try! @sympy_algebras.quat_add(
    q.a(),
    q.b(),
    q.c(),
    q.d(),
    expr_int(5),
    expr_zero(),
    expr_zero(),
    expr_zero(),
  )
  try! assert_quat_components(add, add_oracle)
  let mul = q.mul_scalar(expr_int(2))
  let mul_oracle = try! @sympy_algebras.quat_mul(
    q.a(),
    q.b(),
    q.c(),
    q.d(),
    expr_int(2),
    expr_zero(),
    expr_zero(),
    expr_zero(),
  )
  try! assert_quat_components(mul, mul_oracle)
}

///|
test "quaternion: conjugate parity" {
  let q = try! Quaternion::new(
    expr_int(1),
    expr_int(2),
    expr_int(3),
    expr_int(4),
  )
  let conj = q.conjugate()
  let conj_oracle = try! @sympy_algebras.quat_conjugate(
    q.a(),
    q.b(),
    q.c(),
    q.d(),
  )
  try! assert_quat_components(conj, conj_oracle)
}

///|
test "quaternion: norm parity" {
  let q = try! Quaternion::new(
    expr_int(1),
    expr_int(2),
    expr_int(3),
    expr_int(4),
  )
  let norm_oracle = try! @sympy_algebras.quat_norm(q.a(), q.b(), q.c(), q.d())
  guard (try! expr_equal_expr(q.norm(), norm_oracle)) else {
    fail(
      "norm mismatch: ours=\{@symprint.to_string(q.norm())}, oracle=\{norm_oracle}",
    )
  }
}

///|
test "quaternion: inverse parity" {
  let q = try! Quaternion::new(
    expr_int(1),
    expr_int(2),
    expr_int(3),
    expr_int(4),
  )
  let inv = try! q.inverse()
  let inv_oracle = try! @sympy_algebras.quat_inverse(q.a(), q.b(), q.c(), q.d())
  try! assert_quat_components(inv, inv_oracle)
}

///|
test "quaternion: pow parity" {
  let q = try! Quaternion::new(
    expr_int(1),
    expr_int(2),
    expr_int(0),
    expr_int(0),
  )
  let pow = try! q.pow(2)
  let pow_oracle = try! @sympy_algebras.quat_pow(q.a(), q.b(), q.c(), q.d(), 2)
  try! assert_quat_components(pow, pow_oracle)
}

///|
test "quaternion: exp parity" {
  let q = try! Quaternion::new(
    expr_int(1),
    expr_int(2),
    expr_int(0),
    expr_int(0),
  )
  let expq = q.exp()
  let exp_oracle = try! @sympy_algebras.quat_exp(q.a(), q.b(), q.c(), q.d())
  try! assert_quat_components(expq, exp_oracle)
}

///|
test "quaternion: log parity" {
  let q = try! Quaternion::new(
    expr_int(1),
    expr_int(2),
    expr_int(0),
    expr_int(0),
  )
  let logq = try! q.log()
  let log_oracle = try! @sympy_algebras.quat_log(q.a(), q.b(), q.c(), q.d())
  try! assert_quat_components(logq, log_oracle)
}

///|
test "quaternion: axis-angle parity" {
  let angle = expr_pi() * expr_rational(1, 2)
  let q = Quaternion::from_axis_angle(
    (expr_int(1), expr_zero(), expr_zero()),
    angle,
  )
  let oracle_res : Result[Array[String], Error] = try? @sympy_algebras.quat_from_axis_angle(
    expr_int(1),
    expr_zero(),
    expr_zero(),
    angle,
  )
  let oracle = match oracle_res {
    Ok(v) => v
    Err(e) => fail("quat_from_axis_angle error: \{e}")
  }
  try! assert_quat_components(q, oracle)
  let axis_angle = try! q.to_axis_angle()
  let oracle_axis = try! @sympy_algebras.quat_to_axis_angle(
    q.a(),
    q.b(),
    q.c(),
    q.d(),
  )
  guard oracle_axis.length() == 4 else { fail("oracle axis len") }
  guard expr_equal_expr(axis_angle.0.0, oracle_axis[0]) else {
    fail("axis x mismatch")
  }
  guard expr_equal_expr(axis_angle.0.1, oracle_axis[1]) else {
    fail("axis y mismatch")
  }
  guard expr_equal_expr(axis_angle.0.2, oracle_axis[2]) else {
    fail("axis z mismatch")
  }
  guard expr_equal_expr(axis_angle.1, oracle_axis[3]) else {
    fail("angle mismatch")
  }
}

///|
test "quaternion: rotation matrix parity" {
  let angle = expr_pi() * expr_rational(1, 2)
  let q = Quaternion::from_axis_angle(
    (expr_int(1), expr_zero(), expr_zero()),
    angle,
  )
  let mat = q.to_rotation_matrix()
  let oracle = try! @sympy_algebras.quat_to_rotation_matrix(
    q.a(),
    q.b(),
    q.c(),
    q.d(),
  )
  let ours = matrix_flat_str(mat)
  guard ours.length() == oracle.length() else { fail("matrix size mismatch") }
  for i in 0..<ours.length() {
    guard (try! @sympy_algebras.expr_equal(ours[i], oracle[i])) else {
      fail("matrix mismatch at \{i}: ours=\{ours[i]} oracle=\{oracle[i]}")
    }
  }
}
