///|
fn bi_qs(value : Int) -> BigInt {
  @bigint.BigInt::from_int(value)
}

///|
fn map_pairs_string_qs(map : Map[BigInt, Int]) -> String {
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
fn bigint_array_to_pylist_qs(values : Array[BigInt]) -> String {
  let parts = values.map(v => v.to_string())
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
test "ntheory qs_factor parity" {
  let f1 = qs_factor(bi_qs(91))
  assert_eq(map_pairs_string_qs(f1), @sympy_nt.qs_factor_str(91))
}

///|
test "ntheory qs parity" {
  let f1 = qs(bi_qs(91))
  assert_eq(bigint_array_to_pylist_qs(f1), @sympy_nt.qs_str(91))
}
