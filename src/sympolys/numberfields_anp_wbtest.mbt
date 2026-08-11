///|
fn nf_anp_wb_fe(n : Int) -> FieldElem {
  FieldElem::QQ(@symnum.BigRational::from_int(n))
}

///|
fn nf_anp_wb_dup(values : Array[Int]) -> Array[FieldElem] {
  values.map(nf_anp_wb_fe)
}

///|
test "numberfields: init_normal_ANP normalizes and reduces representative" {
  let anp = init_normal_ANP(
    nf_anp_wb_dup([0, 1, 0]),
    nf_anp_wb_dup([1, 0, -2]),
    Domain::QQ,
  )
  inspect(anp.to_string(), content="ANP([1, 0], [1, 0, -2], QQ)")
  let reduced = init_normal_ANP(
    nf_anp_wb_dup([1, 0, 0]),
    nf_anp_wb_dup([1, 0, -2]),
    Domain::QQ,
  )
  inspect(reduced.to_string(), content="ANP([2], [1, 0, -2], QQ)")
}

///|
test "numberfields: init_normal_ANP keeps zero representative empty" {
  let anp = init_normal_ANP(
    nf_anp_wb_dup([0, 0]),
    nf_anp_wb_dup([1, 0, -2]),
    Domain::QQ,
  )
  inspect(anp.to_string(), content="ANP([], [1, 0, -2], QQ)")
  sympolys_assert_error(
    fn() raise PolyError { init_normal_ANP(nf_anp_wb_dup([1]), [], Domain::QQ) },
    "DivisionByZero",
  )
}
