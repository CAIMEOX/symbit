///|
fn bi_g(value : Int) -> BigInt {
  @bigint.BigInt::from_int(value)
}

///|
fn array_bigint_to_pylist(values : Array[BigInt]) -> String {
  let parts = values.map(v => v.to_string())
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
fn cycle_result_to_str(value : CycleLengthResult) -> String {
  match value {
    CycleLengthResult::Params(lambda_, mu) =>
      match mu {
        Some(v) => "(\{lambda_}, \{v})"
        None => "(\{lambda_}, None)"
      }
    CycleLengthResult::Values(values) =>
      array_bigint_to_pylist(values.map(v => bi_g(v)))
  }
}

///|
fn cycle_values_to_str(values : Array[Int]) -> String {
  let parts = values.map(v => v.to_string())
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
fn f_cycle(x : Int) -> Int {
  (x * x + 1) % 51
}

///|
test "ntheory primetest parity" {
  let nums = [2, 3, 4, 5, 9, 11, 15, 17, 19, 21]
  for n in nums {
    let res = isprime(bi_g(n))
    assert_eq(if res { "True" } else { "False" }, @sympy_nt.isprime_str(n))
  }
  let gauss_cases = [(3, 0), (5, 0), (1, 1), (2, 1)]
  for pair in gauss_cases {
    let (a, b) = pair
    let res = is_gaussian_prime(bi_g(a), b=bi_g(b))
    assert_eq(
      if res {
        "True"
      } else {
        "False"
      },
      @sympy_nt.is_gaussian_prime_str(a, b~),
    )
  }
  let mersenne_cases = [3, 7, 15, 31, 63]
  for n in mersenne_cases {
    let res = is_mersenne_prime(bi_g(n))
    assert_eq(
      if res {
        "True"
      } else {
        "False"
      },
      @sympy_nt.is_mersenne_prime_str(n),
    )
  }
}

///|
test "ntheory generate prime/next/prev parity" {
  let primes = [1, 2, 3, 4, 5, 6]
  for n in primes {
    let res = prime(n)
    assert_eq(res.to_string(), @sympy_nt.prime_str(n))
  }
  let next_cases = [0, 2, 3, 10]
  for n in next_cases {
    let res = nextprime(bi_g(n))
    assert_eq(res.to_string(), @sympy_nt.nextprime_str(n))
  }
  let prev_cases = [3, 4, 5, 10]
  for n in prev_cases {
    let res = prevprime(bi_g(n))
    assert_eq(res.to_string(), @sympy_nt.prevprime_str(n))
  }
}

///|
test "ntheory generate ranges and counts parity" {
  let range1 = primerange(bi_g(10))
  assert_eq(array_bigint_to_pylist(range1), @sympy_nt.primerange_str(10))
  let range2 = primerange(bi_g(10), b=bi_g(30))
  assert_eq(array_bigint_to_pylist(range2), @sympy_nt.primerange_str(10, b=30))
  let pi_cases = [0, 1, 2, 10, 20]
  for n in pi_cases {
    let res = primepi(bi_g(n))
    assert_eq(res.to_string(), @sympy_nt.primepi_str(n))
  }
}

///|
test "ntheory generate misc parity" {
  let primorial_cases = [(4, true), (4, false)]
  for pair in primorial_cases {
    let (n, nth) = pair
    let res = primorial(n, nth~)
    assert_eq(res.to_string(), @sympy_nt.primorial_str(n, nth~))
  }
  let composite_cases = [1, 5, 10]
  for n in composite_cases {
    let res = composite(n)
    assert_eq(res.to_string(), @sympy_nt.composite_str(n))
  }
  let composite_pi_cases = [4, 10, 20]
  for n in composite_pi_cases {
    let res = compositepi(bi_g(n))
    assert_eq(res.to_string(), @sympy_nt.compositepi_str(n))
  }
}

///|
test "ntheory generate cycle_length parity" {
  let res = cycle_length(f_cycle, 4)
  assert_eq(cycle_result_to_str(res), @sympy_nt.cycle_length_str(4))
  let res2 = cycle_length(f_cycle, 4, nmax=4)
  assert_eq(cycle_result_to_str(res2), @sympy_nt.cycle_length_str(4, nmax=4))
  let res_values = cycle_length(f_cycle, 4, values=true)
  let values_str = match res_values {
    CycleLengthResult::Values(values) => cycle_values_to_str(values)
    _ => "[]"
  }
  assert_eq(values_str, @sympy_nt.cycle_length_str(4, values=true))
}
