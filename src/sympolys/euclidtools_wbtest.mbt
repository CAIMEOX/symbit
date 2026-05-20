///|
fn euclid_wb_qq(num : Int, den : Int) -> FieldElem raise PolyError {
  fe_from_rational(
    @symnum.BigRational::from_ints(num, den) catch {
      _ => raise PolyError::DivisionByZero
    },
    Domain::QQ,
  )
}

///|
fn euclid_wb_poly(vals : Array[FieldElem]) -> DensePoly {
  let items : Array[DensePoly] = []
  for value in vals {
    items.push(dense_coef(value))
  }
  dense_poly(items)
}

///|
fn euclid_wb_dup_repr(coeffs : Array[FieldElem]) -> String {
  "[" + coeffs.map(c => c.to_string()).join(",") + "]"
}

///|
fn euclid_wb_dup_pair_repr(
  pair : (Array[FieldElem], Array[FieldElem]),
) -> String {
  "(\{euclid_wb_dup_repr(pair.0)},\{euclid_wb_dup_repr(pair.1)})"
}

///|
fn euclid_wb_dup_triple_repr(
  triple : (Array[FieldElem], Array[FieldElem], Array[FieldElem]),
) -> String {
  "(\{euclid_wb_dup_repr(triple.0)},\{euclid_wb_dup_repr(triple.1)},\{euclid_wb_dup_repr(triple.2)})"
}

///|
fn euclid_wb_dup_list_repr(polys : Array[Array[FieldElem]]) -> String {
  "[" + polys.map(poly => euclid_wb_dup_repr(poly)).join(",") + "]"
}

///|
fn euclid_wb_dmp_repr(poly : DensePoly) -> String {
  match poly {
    DensePoly::Coef(c) => c.to_string()
    DensePoly::Poly(items) =>
      "[" + items.map(item => euclid_wb_dmp_repr(item)).join(",") + "]"
  }
}

///|
test "euclidtools wb: extended Euclidean frontdoors" {
  let f = [
    euclid_wb_qq(1, 1),
    euclid_wb_qq(-2, 1),
    euclid_wb_qq(-6, 1),
    euclid_wb_qq(12, 1),
    euclid_wb_qq(15, 1),
  ]
  let g = [
    euclid_wb_qq(1, 1),
    euclid_wb_qq(1, 1),
    euclid_wb_qq(-4, 1),
    euclid_wb_qq(-4, 1),
  ]
  inspect(
    euclid_wb_dup_pair_repr(dup_half_gcdex(f, g, Domain::QQ)),
    content="([-1/5,3/5],[1,1])",
  )
  inspect(
    euclid_wb_dup_triple_repr(dup_gcdex(f, g, Domain::QQ)),
    content="([-1/5,3/5],[1/5,-6/5,2],[1,1])",
  )
  let non_field : Result[(Array[FieldElem], Array[FieldElem]), PolyError] = try? dup_half_gcdex(
    f,
    g,
    Domain::ZZ,
  )
  assert_true(non_field is Err(PolyError::DomainNotField))
}

///|
test "euclidtools wb: modular inverse frontdoors" {
  let f = [euclid_wb_qq(1, 1), euclid_wb_qq(0, 1), euclid_wb_qq(-1, 1)]
  let g = [euclid_wb_qq(2, 1), euclid_wb_qq(-1, 1)]
  inspect(euclid_wb_dup_repr(dup_invert(f, g, Domain::QQ)), content="[-4/3]")
  let bad = [euclid_wb_qq(1, 1), euclid_wb_qq(-1, 1)]
  let not_invertible : Result[Array[FieldElem], PolyError] = try? dup_invert(
    f,
    bad,
    Domain::QQ,
  )
  assert_true(not_invertible is Err(PolyError::ExactQuotientFailed))
}

///|
test "euclidtools wb: Euclidean PRS frontdoors" {
  let f = [
    euclid_wb_qq(1, 1),
    euclid_wb_qq(0, 1),
    euclid_wb_qq(1, 1),
    euclid_wb_qq(0, 1),
    euclid_wb_qq(-3, 1),
    euclid_wb_qq(-3, 1),
    euclid_wb_qq(8, 1),
    euclid_wb_qq(2, 1),
    euclid_wb_qq(-5, 1),
  ]
  let g = [
    euclid_wb_qq(3, 1),
    euclid_wb_qq(0, 1),
    euclid_wb_qq(5, 1),
    euclid_wb_qq(0, 1),
    euclid_wb_qq(-4, 1),
    euclid_wb_qq(-9, 1),
    euclid_wb_qq(21, 1),
  ]
  inspect(
    euclid_wb_dup_list_repr(dup_euclidean_prs(f, g, Domain::QQ)),
    content=(
      #|[[1,0,1,0,-3,-3,8,2,-5],[3,0,5,0,-4,-9,21],[-5/9,0,1/9,0,-1/3],[-117/25,-9,441/25],[233150/19773,-102500/6591],[-1288744821/543589225]]
    ),
  )
}

///|
test "euclidtools wb: dmp univariate wrappers" {
  let f = euclid_wb_poly([
    euclid_wb_qq(1, 1),
    euclid_wb_qq(0, 1),
    euclid_wb_qq(-1, 1),
  ])
  let g = euclid_wb_poly([euclid_wb_qq(2, 1), euclid_wb_qq(-1, 1)])
  inspect(euclid_wb_dmp_repr(dmp_invert(f, g, 0, Domain::QQ)), content="[-4/3]")
  let bad_u : Result[(DensePoly, DensePoly), PolyError] = try? dmp_half_gcdex(
    f,
    g,
    1,
    Domain::QQ,
  )
  assert_true(bad_u is Err(PolyError::NotUnivariate))
}
