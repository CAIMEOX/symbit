///|
fn bi_r(value : Int) -> BigInt {
  @bigint.BigInt::from_int(value)
}

///|
fn bi_array_r(values : Array[Int]) -> Array[BigInt] {
  let out : Array[BigInt] = Array::new()
  for v in values {
    out.push(bi_r(v))
  }
  out
}

///|
fn array_to_pylist(values : Array[BigInt]) -> String {
  let parts = values.map(v => v.to_string())
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
fn option_bigint_string(value : BigInt?) -> String {
  match value {
    Some(v) => v.to_string()
    None => "None"
  }
}

///|
fn bool_to_py(value : Bool) -> String {
  if value {
    "True"
  } else {
    "False"
  }
}

///|
test "ntheory residue n_order/primitive_root parity" {
  let cases = [(2, 9), (10, 21), (3, 11)]
  for pair in cases {
    let (a, n) = pair
    let res = n_order(bi_r(a), bi_r(n))
    assert_eq(res.to_string(), @sympy_nt.n_order_str(a, n))
  }
  let roots = [2, 3, 5, 7, 10]
  for n in roots {
    let res = primitive_root(bi_r(n))
    assert_eq(option_bigint_string(res), @sympy_nt.primitive_root_str(n))
  }
  let ipr_cases = [(2, 5), (3, 7), (10, 13)]
  for pair in ipr_cases {
    let (a, n) = pair
    let res = is_primitive_root(bi_r(a), bi_r(n))
    assert_eq(bool_to_py(res), @sympy_nt.is_primitive_root_str(a, n))
  }
}

///|
test "ntheory residue symbols parity" {
  let leg_cases = [(2, 3), (5, 11), (10, 13)]
  for pair in leg_cases {
    let (a, p) = pair
    let res = legendre_symbol(bi_r(a), bi_r(p))
    assert_eq(res.to_string(), @sympy_nt.legendre_symbol_str(a, p))
  }
  let jac_cases = [(2, 9), (5, 21), (10, 33)]
  for pair in jac_cases {
    let (a, n) = pair
    let res = jacobi_symbol(bi_r(a), bi_r(n))
    assert_eq(res.to_string(), @sympy_nt.jacobi_symbol_str(a, n))
  }
}

///|
test "ntheory residue quadratic parity" {
  let qr_cases = [(2, 7), (10, 13), (5, 17)]
  for pair in qr_cases {
    let (a, n) = pair
    let res = is_quad_residue(bi_r(a), bi_r(n))
    assert_eq(bool_to_py(res), @sympy_nt.is_quad_residue_str(a, n))
  }
  let qrs = [7, 11, 13]
  for n in qrs {
    let res = quadratic_residues(bi_r(n))
    assert_eq(array_to_pylist(res), @sympy_nt.quadratic_residues_str(n))
  }
  let sqrt_cases = [(10, 13), (5, 41), (3, 11)]
  for pair in sqrt_cases {
    let (a, n) = pair
    let res = sqrt_mod(bi_r(a), bi_r(n), all_roots=true)
    assert_eq(
      array_to_pylist(res),
      @sympy_nt.sqrt_mod_str(a, n, all_roots=true),
    )
  }
}

///|
test "ntheory residue nth roots parity" {
  let nth_cases = [(2, 3, 5), (10, 4, 17), (3, 5, 11)]
  for triple in nth_cases {
    let (a, n, m) = triple
    let res = nthroot_mod(bi_r(a), bi_r(n), bi_r(m), all_roots=true)
    assert_eq(
      array_to_pylist(res),
      @sympy_nt.nthroot_mod_str(a, n, m, all_roots=true),
    )
    let ok = is_nthpow_residue(bi_r(a), bi_r(n), bi_r(m))
    assert_eq(bool_to_py(ok), @sympy_nt.is_nthpow_residue_str(a, n, m))
  }
}

///|
test "ntheory residue misc parity" {
  let mob_cases = [1, 2, 3, 4, 6, 12]
  for n in mob_cases {
    let res = mobius(bi_r(n))
    assert_eq(res.to_string(), @sympy_nt.mobius_str(n))
  }
  let dl_cases = [(13, 9, 2), (19, 4, 2)]
  for triple in dl_cases {
    let (modulus, a, base) = triple
    let res = discrete_log(bi_r(modulus), bi_r(a), bi_r(base))
    assert_eq(
      option_bigint_string(res),
      @sympy_nt.discrete_log_str(modulus, a, base),
    )
  }
  let quad_cases = [(1, 0, -1, 11), (2, 3, 1, 7)]
  for quad in quad_cases {
    let (a, b, c, n) = quad
    let res = quadratic_congruence(bi_r(a), bi_r(b), bi_r(c), bi_r(n))
    assert_eq(
      array_to_pylist(res),
      @sympy_nt.quadratic_congruence_str(a, b, c, n),
    )
  }
  let poly_cases = [([1, 0, -1], 11), ([1, 0, 0, -1], 7)]
  for pair in poly_cases {
    let (coeffs, m) = pair
    let res = polynomial_congruence(bi_array_r(coeffs), bi_r(m))
    assert_eq(
      array_to_pylist(res),
      @sympy_nt.polynomial_congruence_str(coeffs, m),
    )
  }
  let binom_cases = [(10, 3, 7), (12, 6, 5)]
  for triple in binom_cases {
    let (n, k, m) = triple
    let res = binomial_mod(bi_r(n), bi_r(k), bi_r(m))
    assert_eq(res.to_string(), @sympy_nt.binomial_mod_str(n, k, m))
  }
}
