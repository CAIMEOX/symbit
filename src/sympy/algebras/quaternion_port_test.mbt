///|
fn expr_int(n : Int) -> Expr {
  @symcore.int(n)
}

///|
fn expr_zero() -> Expr {
  expr_int(0)
}

///|
fn expr_rational(num : Int, den : Int) -> Expr raise {
  @symcore.rational_from_ints(num, den)
}

///|
fn expr_pi() -> Expr {
  NumberSymbol(Pi)
}

///|
fn expr_equal_expr(expr : Expr, oracle_str : String) -> Bool raise {
  let res = expr_equal(@symprint.pretty_string(expr), oracle_str)
  res
}

///|
fn assert_quat_components(q : Quaternion, oracle : Array[String]) -> Unit raise {
  assert_eq(oracle.length(), 4)
  assert_true(expr_equal_expr(q.a(), oracle[0]))
  assert_true(expr_equal_expr(q.b(), oracle[1]))
  assert_true(expr_equal_expr(q.c(), oracle[2]))
  assert_true(expr_equal_expr(q.d(), oracle[3]))
}

///|
fn matrix_flat_str(m : Matrix) -> Array[String] {
  let out : Array[String] = Array::new()
  for row in m {
    for item in row {
      out.push(@symprint.pretty_string(item))
    }
  }
  out
}

///|
test "quaternion: add/mul parity" {
  let q1 = Quaternion::new(expr_int(1), expr_int(2), expr_int(3), expr_int(4))
  let q2 = Quaternion::new(expr_int(5), expr_int(6), expr_int(7), expr_int(8))
  let add = q1.add(q2)
  let add_oracle = quat_add(
    q1.a(),
    q1.b(),
    q1.c(),
    q1.d(),
    q2.a(),
    q2.b(),
    q2.c(),
    q2.d(),
  )
  assert_quat_components(add, add_oracle)
  let mul = q1.mul(q2)
  let mul_oracle = quat_mul(
    q1.a(),
    q1.b(),
    q1.c(),
    q1.d(),
    q2.a(),
    q2.b(),
    q2.c(),
    q2.d(),
  )
  assert_quat_components(mul, mul_oracle)
}

///|
test "quaternion: scalar add/mul parity" {
  let q = Quaternion::new(expr_int(1), expr_int(2), expr_int(3), expr_int(4))
  let add = q.add_scalar(expr_int(5))
  let add_oracle = quat_add(
    q.a(),
    q.b(),
    q.c(),
    q.d(),
    expr_int(5),
    expr_zero(),
    expr_zero(),
    expr_zero(),
  )
  assert_quat_components(add, add_oracle)
  let mul = q.mul_scalar(expr_int(2))
  let mul_oracle = quat_mul(
    q.a(),
    q.b(),
    q.c(),
    q.d(),
    expr_int(2),
    expr_zero(),
    expr_zero(),
    expr_zero(),
  )
  assert_quat_components(mul, mul_oracle)
}

///|
test "quaternion: conjugate parity" {
  let q = Quaternion::new(expr_int(1), expr_int(2), expr_int(3), expr_int(4))
  let conj = q.conjugate()
  let conj_oracle = quat_conjugate(q.a(), q.b(), q.c(), q.d())
  assert_quat_components(conj, conj_oracle)
}

///|
test "quaternion: norm parity" {
  let q = Quaternion::new(expr_int(1), expr_int(2), expr_int(3), expr_int(4))
  let norm_oracle = quat_norm(q.a(), q.b(), q.c(), q.d())
  assert_true(expr_equal_expr(q.norm(), norm_oracle))
}

///|
test "quaternion: inverse parity" {
  let q = Quaternion::new(expr_int(1), expr_int(2), expr_int(3), expr_int(4))
  let inv = q.inverse()
  let inv_oracle = quat_inverse(q.a(), q.b(), q.c(), q.d())
  assert_quat_components(inv, inv_oracle)
}

///|
test "quaternion: pow parity" {
  let q = Quaternion::new(expr_int(1), expr_int(2), expr_int(0), expr_int(0))
  let pow = q.pow(2)
  let pow_oracle = quat_pow(q.a(), q.b(), q.c(), q.d(), 2)
  assert_quat_components(pow, pow_oracle)
}

///|
test "quaternion: exp parity" {
  let q = Quaternion::new(expr_int(1), expr_int(2), expr_int(0), expr_int(0))
  let expq = q.exp()
  let exp_oracle = quat_exp(q.a(), q.b(), q.c(), q.d())
  assert_quat_components(expq, exp_oracle)
}

///|
test "quaternion: log parity" {
  let q = Quaternion::new(expr_int(1), expr_int(2), expr_int(0), expr_int(0))
  let logq = q.log()
  let log_oracle = quat_log(q.a(), q.b(), q.c(), q.d())
  assert_quat_components(logq, log_oracle)
}

///|
test "quaternion: axis-angle parity" {
  let angle = expr_pi() * expr_rational(1, 2)
  let q = Quaternion::from_axis_angle(
    (expr_int(1), expr_zero(), expr_zero()),
    angle,
  )
  let oracle = quat_from_axis_angle(
    expr_int(1),
    expr_zero(),
    expr_zero(),
    angle,
  )
  assert_quat_components(q, oracle)
  let axis_angle = q.to_axis_angle()
  let oracle_axis = quat_to_axis_angle(q.a(), q.b(), q.c(), q.d())
  assert_eq(oracle_axis.length(), 4)
  assert_true(expr_equal_expr(axis_angle.0.0, oracle_axis[0]))
  assert_true(expr_equal_expr(axis_angle.0.1, oracle_axis[1]))
  assert_true(expr_equal_expr(axis_angle.0.2, oracle_axis[2]))
  assert_true(expr_equal_expr(axis_angle.1, oracle_axis[3]))
}

///|
test "quaternion: rotation matrix parity" {
  let angle = expr_pi() * expr_rational(1, 2)
  let q = Quaternion::from_axis_angle(
    (expr_int(1), expr_zero(), expr_zero()),
    angle,
  )
  let mat = q.to_rotation_matrix()
  let oracle = quat_to_rotation_matrix(q.a(), q.b(), q.c(), q.d())
  let ours = matrix_flat_str(mat)
  assert_eq(ours.length(), oracle.length())
  for i in 0..<ours.length() {
    assert_true(expr_equal(ours[i], oracle[i]))
  }
}
