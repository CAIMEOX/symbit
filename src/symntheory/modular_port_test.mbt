///|
fn bi(value : Int) -> BigInt {
  @bigint.BigInt::from_int(value)
}

///|
fn bi_array(values : Array[Int]) -> Array[BigInt] {
  let out : Array[BigInt] = Array::new()
  for v in values {
    out.push(bi(v))
  }
  out
}

///|
fn pair_string(result : (BigInt, BigInt)) -> String {
  let (a, m) = result
  "(\{a.to_string()}, \{m.to_string()})"
}

///|
fn option_pair_string(result : (BigInt, BigInt)?) -> String {
  match result {
    Some(v) => pair_string(v)
    None => "None"
  }
}

///|
fn zip_pairs_test(
  remainders : Array[BigInt],
  moduli : Array[BigInt],
) -> Array[(BigInt, BigInt)] {
  let out : Array[(BigInt, BigInt)] = Array::new()
  for i in 0..<remainders.length() {
    out.push((remainders[i], moduli[i]))
  }
  out
}

///|
test "ntheory modular crt parity" {
  let m1 = [2, 3, 5]
  let v1 = [0, 0, 0]
  let res1 = crt(bi_array(m1), bi_array(v1))
  assert_eq(option_pair_string(res1), @sympy_nt.crt_str(m1, v1))
  let v2 = [1, 1, 1]
  let res2 = crt(bi_array(m1), bi_array(v2))
  assert_eq(option_pair_string(res2), @sympy_nt.crt_str(m1, v2))
  let v3 = [-1, -1, -1]
  let res3 = crt(bi_array(m1), bi_array(v3), symmetric=true)
  assert_eq(option_pair_string(res3), @sympy_nt.crt_str(m1, v3, symmetric=true))
  let v4 = [-1, -1, -1]
  let res4 = crt(bi_array(m1), bi_array(v4))
  assert_eq(option_pair_string(res4), @sympy_nt.crt_str(m1, v4))
  let m2 = [656, 350]
  let v2b = [811, 133]
  let res5 = crt(bi_array(m2), bi_array(v2b), symmetric=true)
  assert_eq(
    option_pair_string(res5),
    @sympy_nt.crt_str(m2, v2b, symmetric=true),
  )
}

///|
test "ntheory modular crt1/crt2 parity" {
  let m = [99, 97, 95]
  let v = [49, 76, 65]
  let m_bi = bi_array(m)
  let v_bi = bi_array(v)
  let (mm, e, s) = crt1(m_bi)
  let res = crt2(m_bi, v_bi, mm, e, s)
  assert_eq(pair_string(res), @sympy_nt.crt_str(m, v))
}

///|
test "ntheory modular solve_congruence basic parity (case1)" {
  let r1 = [3, 4, 2]
  let m1 = [12, 35, 17]
  let res1 = solve_congruence(zip_pairs_test(bi_array(r1), bi_array(m1)))
  assert_eq(option_pair_string(res1), @sympy_nt.solve_congruence_str(r1, m1))
}

///|
test "ntheory modular solve_congruence basic parity (case2)" {
  let r2 = [3, 4, 2]
  let m2 = [12, 6, 17]
  let res2 = solve_congruence(zip_pairs_test(bi_array(r2), bi_array(m2)))
  assert_eq(option_pair_string(res2), @sympy_nt.solve_congruence_str(r2, m2))
}

///|
test "ntheory modular solve_congruence basic parity (case3)" {
  let r3 = [3, 4, 2]
  let m3 = [13, 7, 17]
  let res3 = solve_congruence(zip_pairs_test(bi_array(r3), bi_array(m3)))
  assert_eq(option_pair_string(res3), @sympy_nt.solve_congruence_str(r3, m3))
}

///|
test "ntheory modular solve_congruence negatives parity" {
  let r4 = [-10, -3, -15]
  let m4 = [13, 7, 17]
  let res4 = solve_congruence(zip_pairs_test(bi_array(r4), bi_array(m4)))
  assert_eq(option_pair_string(res4), @sympy_nt.solve_congruence_str(r4, m4))
  let r5 = [-10, -3, 1, -15]
  let m5 = [13, 7, 7, 17]
  let res5 = solve_congruence(zip_pairs_test(bi_array(r5), bi_array(m5)))
  assert_eq(option_pair_string(res5), @sympy_nt.solve_congruence_str(r5, m5))
}

///|
test "ntheory modular solve_congruence duplicates parity" {
  let r6 = [-10, -5, 2, -15]
  let m6 = [13, 7, 7, 17]
  let res6 = solve_congruence(zip_pairs_test(bi_array(r6), bi_array(m6)))
  assert_eq(option_pair_string(res6), @sympy_nt.solve_congruence_str(r6, m6))
  let r7 = [-10, -5, 2, -15]
  let m7 = [13, 7, 14, 17]
  let res7 = solve_congruence(zip_pairs_test(bi_array(r7), bi_array(m7)))
  assert_eq(option_pair_string(res7), @sympy_nt.solve_congruence_str(r7, m7))
  let r8 = [-10, 2, 2, -15]
  let m8 = [13, 7, 14, 17]
  let res8 = solve_congruence(zip_pairs_test(bi_array(r8), bi_array(m8)))
  assert_eq(option_pair_string(res8), @sympy_nt.solve_congruence_str(r8, m8))
  let r9 = [1, 1, 2]
  let m9 = [3, 2, 4]
  let res9 = solve_congruence(zip_pairs_test(bi_array(r9), bi_array(m9)))
  assert_eq(option_pair_string(res9), @sympy_nt.solve_congruence_str(r9, m9))
}
