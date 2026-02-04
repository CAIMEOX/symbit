///|
fn bi_f(value : Int) -> BigInt {
  @bigint.BigInt::from_int(value)
}

///|
fn map_pairs_string(map : Map[BigInt, Int]) -> String {
  let keys : Array[BigInt] = Array::new()
  for k, _ in map {
    keys.push(k)
  }
  keys.sort()
  let parts : Array[String] = Array::new()
  for k in keys {
    parts.push("(\{k.to_string()}, \{map[k]})")
  }
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
fn array_bigint_to_pylist_f(values : Array[BigInt]) -> String {
  let parts = values.map(v => v.to_string())
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
fn option_power_string(value : (BigInt, Int)?) -> String {
  match value {
    Some((base, exp)) => "(\{base.to_string()}, \{exp})"
    None => "None"
  }
}

///|
test "ntheory factorint/divisors parity" {
  let f1 = factorint(bi_f(360))
  assert_eq(map_pairs_string(f1), @sympy_nt.factorint_pairs_str(360))
  let f2 = factorint(bi_f(-12))
  assert_eq(map_pairs_string(f2), @sympy_nt.factorint_pairs_str(-12))
  let divs = divisors(bi_f(28))
  assert_eq(array_bigint_to_pylist_f(divs), @sympy_nt.divisors_str(28))
  let pdivs = proper_divisors(bi_f(28))
  assert_eq(array_bigint_to_pylist_f(pdivs), @sympy_nt.proper_divisors_str(28))
}

///|
test "ntheory factorint misc parity" {
  let m1 = multiplicity(bi_f(2), bi_f(24))
  assert_eq(m1.to_string(), @sympy_nt.multiplicity_str(2, 24))
  let m2 = multiplicity_in_factorial(bi_f(2), bi_f(10))
  assert_eq(m2.to_string(), @sympy_nt.multiplicity_in_factorial_str(2, 10))
  let pp = perfect_power(bi_f(16))
  assert_eq(option_power_string(pp), @sympy_nt.perfect_power_str(16))
  let pf = primefactors(bi_f(84))
  assert_eq(array_bigint_to_pylist_f(pf), @sympy_nt.primefactors_str(84))
}

///|
test "ntheory factorint totient/sigma parity" {
  let t1 = totient(bi_f(36))
  assert_eq(t1.to_string(), @sympy_nt.totient_str(36))
  let dc = divisor_count(bi_f(36))
  assert_eq(dc.to_string(), @sympy_nt.divisor_count_str(36))
  let pdc = proper_divisor_count(bi_f(36))
  assert_eq(pdc.to_string(), @sympy_nt.proper_divisor_count_str(36))
  let ds1 = divisor_sigma(bi_f(12))
  assert_eq(ds1.to_string(), @sympy_nt.divisor_sigma_str(12))
  let ds0 = divisor_sigma(bi_f(12), k=0)
  assert_eq(ds0.to_string(), @sympy_nt.divisor_sigma_str(12, k=0))
}

///|
test "ntheory factorint higher parity" {
  let fr = factorrat(bi_f(8), den=bi_f(9))
  assert_eq(map_pairs_string(fr), @sympy_nt.factorrat_pairs_str(8, den=9))
  let rt = reduced_totient(bi_f(36))
  assert_eq(rt.to_string(), @sympy_nt.reduced_totient_str(36))
  let pn = primenu(bi_f(30))
  assert_eq(pn.to_string(), @sympy_nt.primenu_str(30))
  let po = primeomega(bi_f(20))
  assert_eq(po.to_string(), @sympy_nt.primeomega_str(20))
  let mpe = mersenne_prime_exponent(1)
  assert_eq(mpe.to_string(), @sympy_nt.mersenne_prime_exponent_str(1))
}

///|
test "ntheory factorint classification parity" {
  let p6 = is_perfect(bi_f(6))
  assert_eq(if p6 { "True" } else { "False" }, @sympy_nt.is_perfect_str(6))
  let ab12 = is_abundant(bi_f(12))
  assert_eq(if ab12 { "True" } else { "False" }, @sympy_nt.is_abundant_str(12))
  let df15 = is_deficient(bi_f(15))
  assert_eq(if df15 { "True" } else { "False" }, @sympy_nt.is_deficient_str(15))
  let am = is_amicable(bi_f(220), bi_f(284))
  assert_eq(
    if am {
      "True"
    } else {
      "False"
    },
    @sympy_nt.is_amicable_str(220, 284),
  )
  let carm = is_carmichael(bi_f(561))
  assert_eq(
    if carm {
      "True"
    } else {
      "False"
    },
    @sympy_nt.is_carmichael_str(561),
  )
}

///|
test "ntheory factorint digital roots parity" {
  let ab = abundance(bi_f(10))
  assert_eq(ab.to_string(), @sympy_nt.abundance_str(10))
  let dr = dra(bi_f(3110), bi_f(12))
  assert_eq(dr.to_string(), @sympy_nt.dra_str(3110, 12))
  let dm = drm(bi_f(49), bi_f(10))
  assert_eq(dm.to_string(), @sympy_nt.drm_str(49, 10))
}
