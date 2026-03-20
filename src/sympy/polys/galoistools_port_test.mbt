///|
fn gf_repr(f : Array[Int]) -> String {
  if f.is_empty() {
    return "[]"
  }
  let parts = f.map(x => x.to_string()).join(",")
  "[\{parts}]"
}

///|
fn gf_pair_repr(pair : (Array[Int], Array[Int])) -> String {
  let (q, r) = pair
  "(\{gf_repr(q)},\{gf_repr(r)})"
}

///|
test "galoistools basic ops" {
  let f = [1, 2, 3]
  let g = [4, 0, 1]
  let p = 5
  let ours_strip = gf_repr(@sympolys.gf_strip([0, 0, 3, 1]))
  let oracle_strip = gf_strip([0, 0, 3, 1])
  assert_eq(ours_strip, oracle_strip)
  let ours_trunc = gf_repr(@sympolys.gf_trunc([7, -2, 3], p))
  let oracle_trunc = gf_trunc([7, -2, 3], p)
  assert_eq(ours_trunc, oracle_trunc)
  let ours_add = gf_repr(@sympolys.gf_add(f, g, p))
  let oracle_add = gf_add(f, g, p)
  assert_eq(ours_add, oracle_add)
  let ours_sub = gf_repr(@sympolys.gf_sub(f, g, p))
  let oracle_sub = gf_sub(f, g, p)
  assert_eq(ours_sub, oracle_sub)
  let ours_mul = gf_repr(@sympolys.gf_mul(f, g, p))
  let oracle_mul = gf_mul(f, g, p)
  assert_eq(ours_mul, oracle_mul)
}

///|
test "galoistools div/gcd" {
  let f = [1, 0, 4, 2]
  let g = [1, 2]
  let p = 5
  let ours_div = gf_pair_repr(@sympolys.gf_div(f, g, p))
  let oracle_div = gf_div(f, g, p)
  assert_eq(ours_div, oracle_div)
  let ours_gcd = gf_repr(@sympolys.gf_gcd(f, g, p))
  let oracle_gcd = gf_gcd(f, g, p)
  assert_eq(ours_gcd, oracle_gcd)
}
