///|
fn bi_misc(value : Int) -> BigInt {
  @bigint.BigInt::from_int(value)
}

///|
fn array_int_to_pylist(values : Array[Int]) -> String {
  let parts = values.map(v => v.to_string())
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
fn map_pairs_string_int(map : Map[Int, Int]) -> String {
  let keys : Array[Int] = Array::new()
  for k, _ in map {
    keys.push(k)
  }
  keys.sort()
  let parts : Array[String] = Array::new()
  for k in keys {
    parts.push("(\{k}, \{map[k]})")
  }
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
fn tuple_array_to_string(values : Array[(Array[Int], BigInt)]) -> String {
  let items = values.copy()
  for i in 0..<items.length() {
    let mut j = i + 1
    while j < items.length() {
      let (a, _) = items[i]
      let (b, _) = items[j]
      let mut less = false
      let mut k = 0
      while k < a.length() && k < b.length() {
        if a[k] < b[k] {
          less = false
          break
        }
        if a[k] > b[k] {
          less = true
          break
        }
        k += 1
      }
      if !less && a.length() > b.length() {
        less = true
      }
      if less {
        let temp = items[i]
        items[i] = items[j]
        items[j] = temp
      }
      j += 1
    }
  }
  let parts : Array[String] = Array::new()
  for item in items {
    let (tuple, coeff) = item
    let tparts = tuple.map(v => v.to_string())
    let tjoined = tparts.join(", ")
    parts.push("((\{tjoined}), \{coeff.to_string()})")
  }
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
fn rational_string(num : BigInt, den : BigInt) -> String {
  if den == bi_misc(1) {
    num.to_string()
  } else {
    "\{num.to_string()}/\{den.to_string()}"
  }
}

///|
fn convergents_string(values : Array[(BigInt, BigInt)]) -> String {
  let parts : Array[String] = Array::new()
  for item in values {
    let (num, den) = item
    parts.push(rational_string(num, den))
  }
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
test "ntheory digits parity" {
  let d1 = digits(bi_misc(35))
  assert_eq(array_int_to_pylist(d1), @sympy_nt.digits_str(35))
  let d2 = digits(bi_misc(-35))
  assert_eq(array_int_to_pylist(d2), @sympy_nt.digits_str(-35))
  let d3 = digits(bi_misc(27), b=bi_misc(2))
  assert_eq(array_int_to_pylist(d3), @sympy_nt.digits_str(27, b=2))
  let d4 = digits(bi_misc(35), digits=4)
  assert_eq(array_int_to_pylist(d4), @sympy_nt.digits_str(35, digits=4))
  let cd = count_digits(bi_misc(1111339))
  assert_eq(map_pairs_string_int(cd), @sympy_nt.count_digits_pairs_str(1111339))
  let pal1 = is_palindromic(bi_misc(-11))
  assert_eq(
    if pal1 {
      "True"
    } else {
      "False"
    },
    @sympy_nt.is_palindromic_str(-11),
  )
  let pal2 = is_palindromic(bi_misc(88), b=bi_misc(8))
  assert_eq(
    if pal2 {
      "True"
    } else {
      "False"
    },
    @sympy_nt.is_palindromic_str(88, b=8),
  )
}

///|
test "ntheory multinomial parity" {
  let bc = binomial_coefficients_list(5)
  let bc_str = array_int_to_pylist(bc.map(v => v.to_int()))
  assert_eq(bc_str, @sympy_nt.binomial_coefficients_list_str(5))
  let bcd = binomial_coefficients(5)
  assert_eq(tuple_array_to_string(bcd), @sympy_nt.binomial_coefficients_str(5))
  let mc = multinomial_coefficients(3, 2)
  assert_eq(
    tuple_array_to_string(mc),
    @sympy_nt.multinomial_coefficients_str(3, 2),
  )
}

///|
test "ntheory partitions parity" {
  let p5 = npartitions(5)
  assert_eq(p5.to_string(), @sympy_nt.npartitions_str(5))
  let p10 = npartitions(10)
  assert_eq(p10.to_string(), @sympy_nt.npartitions_str(10))
}

///|
test "ntheory continued fraction parity" {
  let cf = continued_fraction(bi_misc(43), den=bi_misc(19))
  assert_eq(
    array_int_to_pylist(cf),
    @sympy_nt.continued_fraction_str(43, den=19),
  )
  let cfp = continued_fraction_periodic(bi_misc(4), bi_misc(3))
  assert_eq(
    array_int_to_pylist(cfp),
    @sympy_nt.continued_fraction_periodic_str(4, 3),
  )
  let reduced = continued_fraction_reduce([1, 2])
  assert_eq(
    rational_string(reduced.0, reduced.1),
    @sympy_nt.continued_fraction_reduce_str([1, 2]),
  )
  let conv = continued_fraction_convergents([1, 2, 2])
  assert_eq(
    convergents_string(conv),
    @sympy_nt.continued_fraction_convergents_str([1, 2, 2]),
  )
}

///|
test "ntheory egyptian fraction parity" {
  let ef1 = egyptian_fraction(bi_misc(2), bi_misc(3))
  assert_eq(
    array_int_to_pylist(ef1.map(v => v.to_int())),
    @sympy_nt.egyptian_fraction_str(2, 3),
  )
  let ef2 = egyptian_fraction(bi_misc(43), bi_misc(48))
  assert_eq(
    array_int_to_pylist(ef2.map(v => v.to_int())),
    @sympy_nt.egyptian_fraction_str(43, 48),
  )
}
