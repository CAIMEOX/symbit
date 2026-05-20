///|
fn subres_port_fe_row(
  values : Array[Int],
) -> Array[@sympolys.FieldElem] raise @sympolys.PolyError {
  let row : Array[@sympolys.FieldElem] = []
  for value in values {
    row.push(@sympolys.fe_from_int(value, @sympolys.Domain::ZZ))
  }
  row
}

///|
test "subresultants_qq_zz: res parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(
    (x ^ @symcore.int(3)) - @symcore.int(7) * x + @symcore.int(7),
  )
  let q = b.from_expr(@symcore.int(3) * (x ^ @symcore.int(2)) - @symcore.int(7))
  let ours = @sympolys.res(p, q).to_string()
  let oracle = res_qq_zz(p.to_expr(), q.to_expr(), x="x")
  assert_eq(ours, oracle)
  let ours_q = @sympolys.res_q(p, q).to_string()
  let oracle_q = res_q_qq_zz(p.to_expr(), q.to_expr(), x="x")
  assert_eq(ours_q, oracle_q)
  let ours_z = @sympolys.res_z(p, q).to_string()
  let oracle_z = res_z_qq_zz(p.to_expr(), q.to_expr(), x="x")
  assert_eq(ours_z, oracle_z)
}

///|
test "subresultants_qq_zz: res parity (extra)" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(2))
  let q = b.from_expr(x - @symcore.int(1))
  let ours = @sympolys.res(p, q).to_string()
  let oracle = res_qq_zz(p.to_expr(), q.to_expr(), x="x")
  assert_eq(ours, oracle)
}

///|
test "subresultants_qq_zz: subresultants_rem parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr((x ^ @symcore.int(4)) - @symcore.int(1))
  let q = b.from_expr((x ^ @symcore.int(3)) - @symcore.int(1))
  let ours = poly_list_to_string(@sympolys.subresultants_rem(p, q))
  let oracle = subresultants_rem_qq_zz(p.to_expr(), q.to_expr(), x="x")
  assert_eq(ours, oracle)
}

///|
test "subresultants_qq_zz: subresultants_rem parity (extra)" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr((x ^ @symcore.int(3)) - @symcore.int(1))
  let q = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(1))
  let ours = poly_list_to_string(@sympolys.subresultants_rem(p, q))
  let oracle = subresultants_rem_qq_zz(p.to_expr(), q.to_expr(), x="x")
  assert_eq(ours, oracle)
}

///|
test "subresultants_qq_zz: euclid_q/sturm_q parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr((x ^ @symcore.int(4)) - @symcore.int(1))
  let q = b.from_expr((x ^ @symcore.int(3)) - @symcore.int(1))
  let ours_e = poly_list_to_string(@sympolys.euclid_q(p, q))
  let oracle_e = euclid_q_qq_zz(p.to_expr(), q.to_expr(), x="x")
  assert_eq(ours_e, oracle_e)
  let ours_s = poly_list_to_string(@sympolys.sturm_q(p, q))
  let oracle_s = sturm_q_qq_zz(p.to_expr(), q.to_expr(), x="x")
  assert_eq(ours_s, oracle_s)
}

///|
test "subresultants_qq_zz: helper parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr((x ^ @symcore.int(3)) - @symcore.int(2) * x)
  let q = b.from_expr(
    @symcore.int(-1) * ((x ^ @symcore.int(2)) + @symcore.int(1)),
  )
  let zero = Poly::zero(["x"], Domain::ZZ)
  let ours_sign = @sympolys.sign_seq([p, q, zero])
    .map(v => v.to_string())
    .join(",")
  let oracle_sign = sign_seq_qq_zz([p.to_expr(), q.to_expr(), zero.to_expr()])
  assert_eq(ours_sign, oracle_sign)

  let r = b.from_expr(x + @symcore.int(1))
  let same_degree = b.from_expr(@symcore.int(2) * x + @symcore.int(3))
  let ours_process = poly_list_to_string(
    @sympolys.process_matrix_output([p, q, zero, r, same_degree]),
  )
  let oracle_process = process_matrix_output_qq_zz([
    p.to_expr(),
    q.to_expr(),
    zero.to_expr(),
    r.to_expr(),
    same_degree.to_expr(),
  ])
  assert_eq(ours_process, oracle_process)

  assert_eq(
    @sympolys.compute_sign(-2, 4).to_string(),
    compute_sign_qq_zz(-2, 4),
  )
  assert_eq(
    @sympolys.compute_sign(-2, 5).to_string(),
    compute_sign_qq_zz(-2, 5),
  )
}

///|
test "subresultants_qq_zz: matrix helper parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  let q = b.from_expr(x + @symcore.int(1))
  assert_eq(@sympolys.backward_eye(3).to_matrix_string(), backward_eye_qq_zz(3))
  assert_eq(
    @sympolys.sylvester(p, q).to_matrix_string(),
    sylvester_qq_zz(p.to_expr(), q.to_expr(), x="x"),
  )
  assert_eq(
    @sympolys.sylvester(p, q, kind=2).to_matrix_string(),
    sylvester_qq_zz(p.to_expr(), q.to_expr(), x="x", kind=2),
  )
  assert_eq(
    @sympolys.bezout(p, q).to_matrix_string(),
    bezout_qq_zz(p.to_expr(), q.to_expr(), x="x"),
  )
  assert_eq(
    @sympolys.bezout(p, q, kind="prs").to_matrix_string(),
    bezout_qq_zz(p.to_expr(), q.to_expr(), x="x", kind="prs"),
  )
  let f = b.from_expr(
    (x ^ @symcore.int(3)) - @symcore.int(2) * x + @symcore.int(1),
  )
  let g = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(1))
  let s1 = @sympolys.sylvester(f, g)
  assert_eq(
    @sympolys.correct_sign(3, 2, s1, 1, 0).to_string(),
    correct_sign_qq_zz(f.to_expr(), g.to_expr(), x="x", rdel=1, cdel=0),
  )
  assert_eq(
    @sympolys.correct_sign(3, 2, s1, 1, 1).to_string(),
    correct_sign_qq_zz(f.to_expr(), g.to_expr(), x="x", rdel=1, cdel=1),
  )
  assert_eq(
    @sympolys.create_ma(
      4,
      2,
      subres_port_fe_row([1, 2, 3, 4, 5, 6]),
      subres_port_fe_row([6, 5, 4, 3, 2, 1]),
      6,
    ).to_matrix_string(),
    create_ma_qq_zz(4, 2, [1, 2, 3, 4, 5, 6], [6, 5, 4, 3, 2, 1], 6),
  )
}

///|
test "subresultants_qq_zz: euclid_q/sturm_q normalization parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(
    @symcore.int(-1) * ((x ^ @symcore.int(2)) - @symcore.int(1)),
  )
  let q = b.from_expr(x - @symcore.int(1))
  let ours_e = poly_list_to_string(@sympolys.euclid_q(q, p))
  let oracle_e = euclid_q_qq_zz(q.to_expr(), p.to_expr(), x="x")
  assert_eq(ours_e, oracle_e)
  let ours_s = poly_list_to_string(@sympolys.sturm_q(q, p))
  let oracle_s = sturm_q_qq_zz(q.to_expr(), p.to_expr(), x="x")
  assert_eq(ours_s, oracle_s)
}

///|
test "subresultants_qq_zz: rem_z/quo_z parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr((x ^ @symcore.int(5)) + @symcore.int(1))
  let q = b.from_expr(x + @symcore.int(1))
  let ours_rem = sympy_normalize(@sympolys.rem_z(p, q).to_string())
  let oracle_rem = rem_z_qq_zz(p.to_expr(), q.to_expr(), x="x")
  assert_eq(ours_rem, oracle_rem)
  let ours_quo = sympy_normalize(@sympolys.quo_z(p, q).to_string())
  let oracle_quo = quo_z_qq_zz(p.to_expr(), q.to_expr(), x="x")
  assert_eq(ours_quo, oracle_quo)
}

///|
test "subresultants_qq_zz: error and QQ domain branches" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")

  // ensure_univar_pair -> NotUnivariate
  let b2 = PolyBuilder::new(["x", "y"], Domain::ZZ)
  let p2 = b2.from_expr(x + y)
  let q2 = b2.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  let non_uni : Result[@symnum.BigRational, PolyError] = try? @sympolys.res(
    p2, q2,
  )
  assert_true(non_uni is Err(PolyError::NotUnivariate))

  // lift_pair_to_qq -> DomainMismatch (different domains)
  let bzz = PolyBuilder::new(["x"], Domain::ZZ)
  let bqq = PolyBuilder::new(["x"], Domain::QQ)
  let pzz = bzz.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  let qqq = bqq.from_expr(x + @symcore.int(1))
  let mismatch : Result[Array[Poly], PolyError] = try? @sympolys.euclid_q(
    pzz, qqq,
  )
  assert_true(mismatch is Err(PolyError::DomainMismatch))

  // lift_pair_to_qq -> Domain::QQ branch
  let pqq = bqq.from_expr((x ^ @symcore.int(3)) + x + @symcore.int(1))
  let qqq2 = bqq.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  let seq = @sympolys.euclid_q(pqq, qqq2)
  assert_true(seq.length() >= 2)

  // lift_pair_to_qq -> fallback DomainMismatch branch for unsupported domains.
  let bgf = PolyBuilder::new(["x"], Domain::GF(5))
  let pgf = bgf.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  let qgf = bgf.from_expr(x + @symcore.int(1))
  let unsupported : Result[Array[Poly], PolyError] = try? @sympolys.euclid_q(
    pgf, qgf,
  )
  assert_true(unsupported is Err(PolyError::DomainMismatch))
}
