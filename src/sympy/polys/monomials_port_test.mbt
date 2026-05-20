///|
fn m(xs : Array[Int]) -> Monomial {
  @sympolys.monomial_from_array(xs)
}

///|
fn monom_tuple_text(monom : Monomial) -> String {
  let parts : Array[String] = []
  for exp in monom.to_array() {
    parts.push(exp.to_string())
  }
  let joined = parts.join(",")
  "(\{joined})"
}

///|
fn term_text(term : (Monomial, FieldElem)?) -> String {
  match term {
    None => "None"
    Some((monom, coeff)) => {
      let monom_text = monom_tuple_text(monom)
      "(\{monom_text},\{coeff})"
    }
  }
}

///|
test "monomial arithmetic basics" {
  let a = m([3, 4, 1])
  let b = m([1, 2, 0])
  let prod = @sympolys.monomial_mul(a, b)
  json_inspect(prod.to_array(), content=[4, 6, 1])
  let div = @sympolys.monomial_div(a, b)
  guard div is Some(q) else { fail("division failed") }
  json_inspect(q.to_array(), content=[2, 2, 1])
  let gcd = @sympolys.monomial_gcd(a, b)
  json_inspect(gcd.to_array(), content=[1, 2, 0])
  let lcm = @sympolys.monomial_lcm(a, b)
  json_inspect(lcm.to_array(), content=[3, 4, 1])
  let pow = @sympolys.monomial_pow(m([1, 2, 3]), 3)
  json_inspect(pow.to_array(), content=[3, 6, 9])
}

///|
test "monomial checked division helpers match sympy" {
  let ldiv = @sympolys.monomial_ldiv(m([3, 4, 1]), m([1, 2, 2]))
  assert_eq(
    remove_spaces(monom_tuple_text(ldiv)),
    remove_spaces(monomial_ldiv([3, 4, 1], [1, 2, 2])),
  )
  assert_eq(
    @sympolys.monomial_deg(m([3, 4, 1])).to_string(),
    monomial_deg([3, 4, 1]),
  )
  let exact = @sympolys.term_div(
    (m([3, 2]), @sympolys.fe_from_int(6, Domain::ZZ)),
    (m([1, 1]), @sympolys.fe_from_int(3, Domain::ZZ)),
    Domain::ZZ,
  )
  assert_eq(
    remove_spaces(term_text(exact)),
    remove_spaces(term_div_zz([3, 2], 6, [1, 1], 3)),
  )
  let inexact = @sympolys.term_div(
    (m([3, 2]), @sympolys.fe_from_int(5, Domain::ZZ)),
    (m([1, 1]), @sympolys.fe_from_int(3, Domain::ZZ)),
    Domain::ZZ,
  )
  assert_eq(
    remove_spaces(term_text(inexact)),
    remove_spaces(term_div_zz([3, 2], 5, [1, 1], 3)),
  )
}

///|
test "monomial min/max and count" {
  let m1 = m([3, 4, 5])
  let m2 = m([0, 5, 1])
  let m3 = m([6, 3, 9])
  let maxm = @sympolys.monomial_max([m1, m2, m3])
  json_inspect(maxm.to_array(), content=[6, 5, 9])
  let minm = @sympolys.monomial_min([m1, m2, m3])
  json_inspect(minm.to_array(), content=[0, 3, 1])
  inspect(@sympolys.monomial_count(2, 2), content="6")
  inspect(@sympolys.monomial_count(2, 3), content="10")
}
