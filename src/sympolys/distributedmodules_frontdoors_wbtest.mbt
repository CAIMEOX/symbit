///|
fn sdm_wb_m(exps : Array[Int]) -> Monomial {
  monomial_from_array(exps)
}

///|
fn sdm_wb_q(n : Int) -> FieldElem raise PolyError {
  fe_from_int(n, Domain::QQ)
}

///|
fn sdm_wb_tuple(exps : Array[Int]) -> String {
  if exps.length() == 1 {
    "(\{exps[0]},)"
  } else {
    let body = exps.map(v => v.to_string()).join(", ")
    "(\{body})"
  }
}

///|
fn sdm_wb_string(f : Sdm) -> String {
  let parts : Array[String] = []
  for term in f {
    parts.push("(\{sdm_wb_tuple(term.0.to_array())}, \{term.1})")
  }
  let body = parts.join(", ")
  "[\{body}]"
}

///|
test "distributedmodules wb: module monomial helpers" {
  inspect(
    sdm_monomial_mul(sdm_wb_m([1, 1, 0]), sdm_wb_m([1, 3])).to_array(),
    content="[1, 2, 3]",
  )
  inspect(sdm_monomial_deg(sdm_wb_m([5, 2, 1])), content="3")
  inspect(
    sdm_monomial_lcm(sdm_wb_m([1, 2, 3]), sdm_wb_m([1, 0, 5])).to_array(),
    content="[1, 2, 5]",
  )
  inspect(
    sdm_monomial_divides(sdm_wb_m([5, 1, 1]), sdm_wb_m([5, 2, 1])),
    content="true",
  )
  inspect(
    sdm_monomial_divides(sdm_wb_m([5, 1, 2]), sdm_wb_m([5, 0, 1])),
    content="false",
  )
}

///|
test "distributedmodules wb: sort strip dict and leading terms" {
  let d : Map[Monomial, FieldElem] = Map([])
  d[sdm_wb_m([1, 1, 0])] = sdm_wb_q(1)
  d[sdm_wb_m([1, 0, 0])] = sdm_wb_q(2)
  d[sdm_wb_m([0, 1, 0])] = sdm_wb_q(0)
  let f = sdm_from_dict(d, lex())
  inspect(sdm_wb_string(f), content="[((1, 1, 0), 1), ((1, 0, 0), 2)]")
  inspect(sdm_LC(f, Domain::QQ).to_string(), content="1")
  inspect(sdm_LM(f).to_array(), content="[1, 1, 0]")
  inspect(
    "(\{sdm_wb_tuple(sdm_LT(f).0.to_array())}, \{sdm_LT(f).1})",
    content="((1, 1, 0), 1)",
  )
}

///|
test "distributedmodules wb: add and multiply term" {
  let xyf1 : Sdm = [(sdm_wb_m([1, 1, 1]), sdm_wb_q(1))]
  let f2 : Sdm = [(sdm_wb_m([2, 0, 0]), sdm_wb_q(1))]
  inspect(
    sdm_wb_string(sdm_add(xyf1, f2, lex(), Domain::QQ)),
    content="[((2, 0, 0), 1), ((1, 1, 1), 1)]",
  )
  inspect(
    sdm_wb_string(
      sdm_add(xyf1, [(sdm_wb_m([1, 1, 1]), sdm_wb_q(-1))], lex(), Domain::QQ),
    ),
    content="[]",
  )
  let f : Sdm = [
    (sdm_wb_m([2, 0, 1]), sdm_wb_q(4)),
    (sdm_wb_m([1, 1, 0]), sdm_wb_q(3)),
  ]
  inspect(
    sdm_wb_string(
      sdm_mul_term(f, (sdm_wb_m([1, 1]), sdm_wb_q(2)), lex(), Domain::QQ),
    ),
    content="[((2, 1, 2), 8), ((1, 2, 1), 6)]",
  )
  inspect(sdm_wb_string(sdm_zero()), content="[]")
}

///|
test "distributedmodules wb: degree and ecart" {
  let f : Sdm = [
    (sdm_wb_m([1, 2, 3]), sdm_wb_q(1)),
    (sdm_wb_m([10, 0, 1]), sdm_wb_q(1)),
    (sdm_wb_m([2, 3, 4]), sdm_wb_q(4)),
  ]
  inspect(sdm_deg(f), content="7")
  let g : Sdm = [
    (sdm_wb_m([2, 2, 1]), sdm_wb_q(1)),
    (sdm_wb_m([1, 5, 1]), sdm_wb_q(1)),
  ]
  inspect(sdm_ecart(g), content="3")
}
