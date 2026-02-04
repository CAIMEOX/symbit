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
  let ours_strip = gf_repr(gf_strip([0, 0, 3, 1]))
  let oracle_strip = @sympy_polys.gf_strip([0, 0, 3, 1])
  guard ours_strip == oracle_strip else { fail("gf_strip mismatch") }
  let ours_trunc = gf_repr(gf_trunc([7, -2, 3], p))
  let oracle_trunc = @sympy_polys.gf_trunc([7, -2, 3], p)
  guard ours_trunc == oracle_trunc else { fail("gf_trunc mismatch") }
  let ours_add = gf_repr(gf_add(f, g, p))
  let oracle_add = @sympy_polys.gf_add(f, g, p)
  guard ours_add == oracle_add else { fail("gf_add mismatch") }
  let ours_sub = gf_repr(gf_sub(f, g, p))
  let oracle_sub = @sympy_polys.gf_sub(f, g, p)
  guard ours_sub == oracle_sub else { fail("gf_sub mismatch") }
  let ours_mul = gf_repr(gf_mul(f, g, p))
  let oracle_mul = @sympy_polys.gf_mul(f, g, p)
  guard ours_mul == oracle_mul else { fail("gf_mul mismatch") }
}

///|
test "galoistools div/gcd" {
  let f = [1, 0, 4, 2]
  let g = [1, 2]
  let p = 5
  let ours_div = gf_pair_repr(gf_div(f, g, p))
  let oracle_div = @sympy_polys.gf_div(f, g, p)
  guard ours_div == oracle_div else { fail("gf_div mismatch") }
  let ours_gcd = gf_repr(gf_gcd(f, g, p))
  let oracle_gcd = @sympy_polys.gf_gcd(f, g, p)
  guard ours_gcd == oracle_gcd else { fail("gf_gcd mismatch") }
}
