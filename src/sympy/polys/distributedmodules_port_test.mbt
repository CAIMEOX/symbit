///|
fn sdm_port_m(exps : Array[Int]) -> @sympolys.Monomial {
  @sympolys.monomial_from_array(exps)
}

///|
fn sdm_port_q(n : Int) -> @sympolys.FieldElem raise @sympolys.PolyError {
  @sympolys.fe_from_int(n, @sympolys.Domain::QQ)
}

///|
fn sdm_port_tuple(exps : Array[Int]) -> String {
  let body = exps.map(v => v.to_string()).join(",")
  "(\{body})"
}

///|
fn sdm_port_string(f : @sympolys.Sdm) -> String {
  let parts : Array[String] = []
  for term in f {
    parts.push("(\{sdm_port_tuple(term.0.to_array())},\{term.1})")
  }
  let body = parts.join(",")
  "[\{body}]"
}

///|
fn sdm_port_terms(
  terms : Array[(Array[Int], Int)],
) -> @sympolys.Sdm raise @sympolys.PolyError {
  let out : @sympolys.Sdm = []
  for term in terms {
    out.push((sdm_port_m(term.0), sdm_port_q(term.1)))
  }
  out
}

///|
fn sdm_port_dict(
  terms : Array[(Array[Int], Int)],
) -> Map[@sympolys.Monomial, @sympolys.FieldElem] raise @sympolys.PolyError {
  let out : Map[@sympolys.Monomial, @sympolys.FieldElem] = Map([])
  for term in terms {
    out[sdm_port_m(term.0)] = sdm_port_q(term.1)
  }
  out
}

///|
fn sdm_port_map_string(
  values : Map[@sympolys.Monomial, @sympolys.FieldElem],
) -> String {
  let parts : Array[String] = []
  for key, value in values {
    parts.push("\{sdm_port_tuple(key.to_array())}:\{value}")
  }
  let body = parts.join(",")
  "{\{body}}"
}

///|
test "distributedmodules: module monomial frontdoors parity" {
  assert_eq(
    sdm_port_tuple(
      @sympolys.sdm_monomial_mul(sdm_port_m([1, 1, 0]), sdm_port_m([1, 3])).to_array(),
    ),
    sdm_monomial_mul([1, 1, 0], [1, 3]),
  )
  assert_eq(
    @sympolys.sdm_monomial_deg(sdm_port_m([5, 2, 1])),
    sdm_monomial_deg([5, 2, 1]),
  )
  assert_eq(
    sdm_port_tuple(
      @sympolys.sdm_monomial_lcm(sdm_port_m([1, 2, 3]), sdm_port_m([1, 0, 5])).to_array(),
    ),
    sdm_monomial_lcm([1, 2, 3], [1, 0, 5]),
  )
  assert_eq(
    @sympolys.sdm_monomial_divides(sdm_port_m([5, 1, 1]), sdm_port_m([5, 2, 1])),
    sdm_monomial_divides([5, 1, 1], [5, 2, 1]),
  )
  assert_eq(
    @sympolys.sdm_monomial_divides(sdm_port_m([5, 1, 2]), sdm_port_m([5, 0, 1])),
    sdm_monomial_divides([5, 1, 2], [5, 0, 1]),
  )
}

///|
test "distributedmodules: conversion and leading term parity" {
  let terms = [([1, 1, 0], 1), ([1, 0, 0], 2), ([0, 1, 0], 0)]
  let f = @sympolys.sdm_from_dict(sdm_port_dict(terms), @sympolys.lex())
  assert_eq(sdm_port_string(f), sdm_from_dict(terms))
  assert_eq(
    @sympolys.sdm_LC(f, @sympolys.Domain::QQ).to_string(),
    sdm_LC(terms),
  )
  assert_eq(sdm_port_tuple(@sympolys.sdm_LM(f).to_array()), sdm_LM(terms))
  let lt = @sympolys.sdm_LT(f)
  assert_eq("(\{sdm_port_tuple(lt.0.to_array())},\{lt.1})", sdm_LT(terms))
  assert_eq(
    sdm_port_string(@sympolys.sdm_strip(sdm_port_terms(terms))),
    sdm_strip(terms),
  )
  assert_eq(
    sdm_port_string(@sympolys.sdm_sort(sdm_port_terms(terms), @sympolys.lex())),
    sdm_sort(terms),
  )
  assert_eq(
    sdm_port_map_string(@sympolys.sdm_to_dict(f)),
    sdm_to_dict([([1, 1, 0], 1), ([1, 0, 0], 2)]),
  )
}

///|
test "distributedmodules: add multiply zero and degree parity" {
  let f = [([1, 1, 1], 1)]
  let g = [([2, 0, 0], 1)]
  assert_eq(
    sdm_port_string(
      @sympolys.sdm_add(
        sdm_port_terms(f),
        sdm_port_terms(g),
        @sympolys.lex(),
        @sympolys.Domain::QQ,
      ),
    ),
    sdm_add(f, g),
  )
  let cancel = [([1, 1, 1], -1)]
  assert_eq(
    sdm_port_string(
      @sympolys.sdm_add(
        sdm_port_terms(f),
        sdm_port_terms(cancel),
        @sympolys.lex(),
        @sympolys.Domain::QQ,
      ),
    ),
    sdm_add(f, cancel),
  )
  let h = [([2, 0, 1], 4), ([1, 1, 0], 3)]
  assert_eq(
    sdm_port_string(
      @sympolys.sdm_mul_term(
        sdm_port_terms(h),
        (sdm_port_m([1, 1]), sdm_port_q(2)),
        @sympolys.lex(),
        @sympolys.Domain::QQ,
      ),
    ),
    sdm_mul_term(h, [1, 1], 2),
  )
  assert_eq(sdm_port_string(@sympolys.sdm_zero()), sdm_zero())
  let deg_terms = [([1, 2, 3], 1), ([10, 0, 1], 1), ([2, 3, 4], 4)]
  assert_eq(@sympolys.sdm_deg(sdm_port_terms(deg_terms)), sdm_deg(deg_terms))
  let ecart_terms = [([2, 2, 1], 1), ([1, 5, 1], 1)]
  assert_eq(
    @sympolys.sdm_ecart(sdm_port_terms(ecart_terms)),
    sdm_ecart(ecart_terms),
  )
}
