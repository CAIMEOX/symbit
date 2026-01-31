///|
fn m(xs : Array[Int]) -> Monomial {
  monomial_from_array(xs)
}

///|
test "monomial arithmetic basics" {
  let a = m([3, 4, 1])
  let b = m([1, 2, 0])
  let prod = try! monomial_mul(a, b)
  json_inspect(prod.to_array(), content=[4, 6, 1])
  let div = try! monomial_div(a, b)
  guard div is Some(q) else { fail("division failed") }
  json_inspect(q.to_array(), content=[2, 2, 1])
  let gcd = try! monomial_gcd(a, b)
  json_inspect(gcd.to_array(), content=[1, 2, 0])
  let lcm = try! monomial_lcm(a, b)
  json_inspect(lcm.to_array(), content=[3, 4, 1])
  let pow = try! monomial_pow(m([1, 2, 3]), 3)
  json_inspect(pow.to_array(), content=[3, 6, 9])
}

///|
test "monomial min/max and count" {
  let m1 = m([3, 4, 5])
  let m2 = m([0, 5, 1])
  let m3 = m([6, 3, 9])
  let maxm = try! monomial_max([m1, m2, m3])
  json_inspect(maxm.to_array(), content=[6, 5, 9])
  let minm = try! monomial_min([m1, m2, m3])
  json_inspect(minm.to_array(), content=[0, 3, 1])
  inspect(monomial_count(2, 2).to_string(), content="6")
  inspect(monomial_count(2, 3).to_string(), content="10")
}
