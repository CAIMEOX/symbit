///|
test "polys subresultants worker keeps generator punctuation literal" {
  let x = @symcore.Expr::Symbol("x y,z")
  let p = (x ^ @symcore.int(2)) - @symcore.int(1)
  let q = x - @symcore.int(2)
  assert_eq(res_qq_zz(p, q, x="x y,z"), "3")
  assert_eq(
    subresultants_rem_qq_zz(p, q, x="x y,z"),
    "x y,z**2 - 1 | x y,z - 2 | 3",
  )
  assert_eq(row2poly_qq_zz([0, 1, 2, 0], 2, x="x y,z"), "x y,z**2 + 2*x y,z")
}

///|
fn subresultants_worker_pair() -> (@symcore.Expr, @symcore.Expr) {
  let x = @symcore.Expr::Symbol("x")
  ((x ^ @symcore.int(2)) - @symcore.int(1), x - @symcore.int(2))
}

///|
test "polys subresultants worker shares Expr identity across pairs and lists" {
  let x = @symcore.Expr::Symbol("x")
  let dummy = @symcore.Expr::Dummy("d", 1201)
  let polynomial = x + dummy
  assert_eq(res_qq_zz(polynomial, polynomial), "0")
  assert_eq(sign_seq_qq_zz([polynomial, polynomial]), "1,1")
  assert_eq(
    process_matrix_output_qq_zz([polynomial, polynomial]),
    "_d + x | _d + x",
  )
}

///|
test "polys subresultants worker preserves polynomial-aware scalar codecs" {
  let (p, q) = subresultants_worker_pair()
  assert_eq(res_qq_zz(p, q), "3")
  assert_eq(res_q_qq_zz(p, q), "3")
  assert_eq(res_z_qq_zz(p, q), "3")
  assert_eq(rem_z_qq_zz(p, q), "3")
  assert_eq(quo_z_qq_zz(p, q), "x + 2")
}

///|
test "polys subresultants worker preserves polynomial sequence codecs" {
  let (p, q) = subresultants_worker_pair()
  let positive = "x**2 - 1 | x - 2 | 3"
  let negative = "x**2 - 1 | x - 2 | -3"
  assert_eq(subresultants_rem_qq_zz(p, q), positive)
  assert_eq(subresultants_sylv_qq_zz(p, q), positive)
  assert_eq(subresultants_bezout_qq_zz(p, q), positive)
  assert_eq(subresultants_amv_qq_zz(p, q), positive)
  assert_eq(subresultants_amv_q_qq_zz(p, q), positive)
  assert_eq(subresultants_vv_qq_zz(p, q), positive)
  assert_eq(subresultants_vv_2_qq_zz(p, q), positive)
  assert_eq(modified_subresultants_sylv_qq_zz(p, q), negative)
  assert_eq(modified_subresultants_bezout_qq_zz(p, q), negative)
  assert_eq(modified_subresultants_amv_qq_zz(p, q), negative)
  assert_eq(euclid_q_qq_zz(p, q), positive)
  assert_eq(euclid_pg_qq_zz(p, q), positive)
  assert_eq(euclid_amv_qq_zz(p, q), positive)
  assert_eq(sturm_q_qq_zz(p, q), negative)
  assert_eq(sturm_pg_qq_zz(p, q), negative)
  assert_eq(sturm_amv_qq_zz(p, q), negative)
}

///|
test "polys subresultants worker preserves raw sequence and option codecs" {
  let (p, q) = subresultants_worker_pair()
  let x = @symcore.Expr::Symbol("x")
  assert_eq(sign_seq_qq_zz([p, q, @symcore.int(3)]), "1,1,1")
  assert_eq(
    process_matrix_output_qq_zz([
      p,
      q,
      @symcore.int(0),
      x + @symcore.int(1),
      @symcore.int(2) * x + @symcore.int(3),
    ]),
    "x**2 - 1 | x - 2",
  )
  assert_eq(compute_sign_qq_zz(-2, 5), "-1")
  assert_eq(
    sylvester_qq_zz(p, q),
    "Matrix([[1, 0, -1], [1, -2, 0], [0, 1, -2]])",
  )
  assert_eq(
    sylvester_qq_zz(p, q, kind=2),
    "Matrix([[1, 0, -1, 0], [0, 1, -2, 0], [0, 1, 0, -1], [0, 0, 1, -2]])",
  )
  assert_eq(correct_sign_qq_zz(p, q, rdel=1, cdel=0), "1")
  assert_eq(correct_sign_qq_zz(p, q, rdel=1, cdel=1), "-2")
  assert_eq(bezout_qq_zz(p, q), "Matrix([[1, -2], [-2, 1]])")
  assert_eq(bezout_qq_zz(p, q, kind="prs"), "Matrix([[1, -2], [-2, 1]])")
}

///|
test "polys subresultants worker builds row and nested matrices in one request" {
  assert_eq(backward_eye_qq_zz(2), "Matrix([[0, 1], [1, 0]])")
  assert_eq(
    create_ma_qq_zz(2, 1, [1, 2, 3], [3, 2, 1], 3),
    "Matrix([[1, 2, 3], [3, 1, 2], [3, 2, 1]])",
  )
  assert_eq(rotate_r_qq_zz([1, 2, 3, 4], 2), "[3, 4, 1, 2]")
  assert_eq(rotate_l_qq_zz([1, 2, 3, 4], 2), "[3, 1, 2, 4]")
  assert_eq(row2poly_qq_zz([0, 1, 2, 0], 2), "x**2 + 2*x")
  assert_eq(pivot_qq_zz([[2, 1], [4, 5]], 0, 0), "Matrix([[2, 1], [0, 6]])")
  assert_eq(find_degree_qq_zz([[1, 2, 0], [0, 0, 3]], 2), "0")
  assert_eq(
    final_touches_qq_zz([[0, 0], [0, 1]], 1, 1),
    "Matrix([[0, 0], [0, 0]])",
  )
}

///|
test "polys subresultants worker propagates strict failures and recovers" {
  let none_rejected = try {
    find_degree_qq_zz([[0, 0], [0, 0]], 2) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(none_rejected)
  let ragged_rejected = try {
    pivot_qq_zz([[1, 2], [3]], 0, 0) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(ragged_rejected)
  assert_eq(compute_sign_qq_zz(-2, 4), "1")
}
