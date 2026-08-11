///|
fn euclid_wb_qq(num : Int, den : Int) -> FieldElem raise PolyError {
  fe_from_rational(
    @symnum.BigRational::from_ints(num, den) catch {
      _ => raise DivisionByZero
    },
    QQ,
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
  "[" + coeffs.map(c => Show::to_string(c)).join(",") + "]"
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
fn euclid_wb_dmp_triple_repr(
  triple : (DensePoly, DensePoly, DensePoly),
) -> String {
  "(\{euclid_wb_dmp_repr(triple.0)},\{euclid_wb_dmp_repr(triple.1)},\{euclid_wb_dmp_repr(triple.2)})"
}

///|
fn euclid_wb_ground_primitive_repr(value : (FieldElem, DensePoly)) -> String {
  "(\{value.0},\{euclid_wb_dmp_repr(value.1)})"
}

///|
fn euclid_wb_dmp_pair_repr(value : (DensePoly, DensePoly)) -> String {
  "(\{euclid_wb_dmp_repr(value.0)},\{euclid_wb_dmp_repr(value.1)})"
}

///|
fn euclid_wb_dup_list_repr(polys : Array[Array[FieldElem]]) -> String {
  "[" + polys.map(poly => euclid_wb_dup_repr(poly)).join(",") + "]"
}

///|
fn euclid_wb_field_list_repr(values : Array[FieldElem]) -> String {
  "[" + values.map(value => Show::to_string(value)).join(",") + "]"
}

///|
fn euclid_wb_inner_subres_repr(
  value : (Array[Array[FieldElem]], Array[FieldElem]),
) -> String {
  "(\{euclid_wb_dup_list_repr(value.0)},\{euclid_wb_field_list_repr(value.1)})"
}

///|
fn euclid_wb_prs_resultant_repr(
  value : (FieldElem, Array[Array[FieldElem]]),
) -> String {
  "(\{value.0},\{euclid_wb_dup_list_repr(value.1)})"
}

///|
fn euclid_wb_dmp_repr(poly : DensePoly) -> String {
  match poly {
    Coef(c) => Show::to_string(c)
    Poly(items) =>
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
    euclid_wb_dup_pair_repr(dup_half_gcdex(f, g, QQ)),
    content="([-1/5,3/5],[1,1])",
  )
  inspect(
    euclid_wb_dup_triple_repr(dup_gcdex(f, g, QQ)),
    content="([-1/5,3/5],[1/5,-6/5,2],[1,1])",
  )
  sympolys_assert_error(
    fn() raise PolyError { dup_half_gcdex(f, g, ZZ) },
    "DomainNotField",
  )
}

///|
test "euclidtools wb: modular inverse frontdoors" {
  let f = [euclid_wb_qq(1, 1), euclid_wb_qq(0, 1), euclid_wb_qq(-1, 1)]
  let g = [euclid_wb_qq(2, 1), euclid_wb_qq(-1, 1)]
  inspect(euclid_wb_dup_repr(dup_invert(f, g, QQ)), content="[-4/3]")
  let bad = [euclid_wb_qq(1, 1), euclid_wb_qq(-1, 1)]
  sympolys_assert_error(
    fn() raise PolyError { dup_invert(f, bad, QQ) },
    "ExactQuotientFailed",
  )
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
    euclid_wb_dup_list_repr(dup_euclidean_prs(f, g, QQ)),
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
  inspect(euclid_wb_dmp_repr(dmp_invert(f, g, 0, QQ)), content="[-4/3]")
  sympolys_assert_error(
    fn() raise PolyError { dmp_half_gcdex(f, g, 1, QQ) },
    "NotUnivariate",
  )
}

///|
test "euclidtools wb: primitive and subresultant frontdoors" {
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
    euclid_wb_dup_list_repr(dup_primitive_prs(f, g, ZZ)),
    content=(
      #|[[1,0,1,0,-3,-3,8,2,-5],[3,0,5,0,-4,-9,21],[-5,0,1,0,-3],[13,25,-49],[4663,-6150],[1]]
    ),
  )
  let a = [euclid_wb_qq(1, 1), euclid_wb_qq(0, 1), euclid_wb_qq(1, 1)]
  let b = [euclid_wb_qq(1, 1), euclid_wb_qq(0, 1), euclid_wb_qq(-1, 1)]
  inspect(
    euclid_wb_inner_subres_repr(dup_inner_subresultants(a, b, ZZ)),
    content="([[1,0,1],[1,0,-1],[-2]],[1,1,4])",
  )
  inspect(
    euclid_wb_dup_list_repr(dup_subresultants(a, b, ZZ)),
    content="[[1,0,1],[1,0,-1],[-2]]",
  )
  inspect(
    euclid_wb_prs_resultant_repr(dup_prs_resultant(a, b, ZZ)),
    content="(4,[[1,0,1],[1,0,-1],[-2]])",
  )
  inspect(dup_resultant(a, b, ZZ), content="4")
}

///|
test "euclidtools wb: discriminant and dmp resultant wrappers" {
  let f = [euclid_wb_qq(1, 1), euclid_wb_qq(2, 1), euclid_wb_qq(3, 1)]
  inspect(dup_discriminant(f, ZZ), content="-8")
  let a = euclid_wb_poly([
    euclid_wb_qq(1, 1),
    euclid_wb_qq(0, 1),
    euclid_wb_qq(1, 1),
  ])
  let b = euclid_wb_poly([
    euclid_wb_qq(1, 1),
    euclid_wb_qq(0, 1),
    euclid_wb_qq(-1, 1),
  ])
  inspect(euclid_wb_dmp_repr(dmp_resultant(a, b, 0, ZZ)), content="4")
  inspect(
    euclid_wb_dmp_repr(dmp_zz_modular_resultant(a, b, 5, 0, ZZ)),
    content="-1",
  )
  inspect(
    euclid_wb_dmp_repr(dmp_zz_collins_resultant(a, b, 0, ZZ)),
    content="4",
  )
  let qf = euclid_wb_poly([euclid_wb_qq(1, 2), euclid_wb_qq(1, 1)])
  let qg = euclid_wb_poly([euclid_wb_qq(2, 1), euclid_wb_qq(3, 1)])
  inspect(
    euclid_wb_dmp_repr(dmp_qq_collins_resultant(qf, qg, 0, QQ)),
    content="-1/2",
  )
  let nested = dense_poly([a, b])
  sympolys_assert_error(
    fn() raise PolyError { dmp_zz_collins_resultant(nested, nested, 1, ZZ) },
    "NotUnivariate",
  )
  inspect(
    euclid_wb_dmp_repr(dmp_discriminant(euclid_wb_poly(f), 0, ZZ)),
    content="-8",
  )
}

///|
test "euclidtools wb: gcd lcm and cancel frontdoors" {
  let f = [euclid_wb_qq(1, 1), euclid_wb_qq(0, 1), euclid_wb_qq(-1, 1)]
  let g = [euclid_wb_qq(1, 1), euclid_wb_qq(-3, 1), euclid_wb_qq(2, 1)]
  inspect(
    euclid_wb_dup_triple_repr(dup_rr_prs_gcd(f, g, ZZ)),
    content="([1,-1],[1,1],[1,-2])",
  )
  inspect(
    euclid_wb_dup_triple_repr(dup_inner_gcd(f, g, ZZ)),
    content="([1,-1],[1,1],[1,-2])",
  )
  inspect(
    euclid_wb_dup_triple_repr(dup_zz_heu_gcd(f, g, ZZ)),
    content="([1,-1],[1,1],[1,-2])",
  )
  inspect(euclid_wb_dup_repr(dup_gcd(f, g, ZZ)), content="[1,-1]")
  inspect(euclid_wb_dup_repr(dup_lcm(f, g, ZZ)), content="[1,-2,-1,2]")
  inspect(
    euclid_wb_dup_pair_repr(
      dup_cancel(
        [euclid_wb_qq(2, 1), euclid_wb_qq(0, 1), euclid_wb_qq(-2, 1)],
        [euclid_wb_qq(1, 1), euclid_wb_qq(-2, 1), euclid_wb_qq(1, 1)],
        ZZ,
      ),
    ),
    content="([2,2],[1,-1])",
  )
  let fd = euclid_wb_poly(f)
  let gd = euclid_wb_poly(g)
  inspect(
    euclid_wb_dmp_triple_repr(dmp_zz_heu_gcd(fd, gd, 0, ZZ)),
    content="([1,-1],[1,1],[1,-2])",
  )
}

///|
test "euclidtools wb: field gcd lcm and dmp wrappers" {
  let f = [euclid_wb_qq(1, 2), euclid_wb_qq(7, 4), euclid_wb_qq(3, 2)]
  let g = [euclid_wb_qq(1, 2), euclid_wb_qq(1, 1), euclid_wb_qq(0, 1)]
  inspect(
    euclid_wb_dup_triple_repr(dup_ff_prs_gcd(f, g, QQ)),
    content="([1,2],[1/2,3/4],[1/2,0])",
  )
  inspect(
    euclid_wb_dup_triple_repr(dup_qq_heu_gcd(f, g, QQ)),
    content="([1,2],[1/2,3/4],[1/2,0])",
  )
  inspect(euclid_wb_dup_repr(dup_gcd(f, g, QQ)), content="[1,2]")
  inspect(euclid_wb_dup_repr(dup_lcm(f, g, QQ)), content="[1,7/2,3,0]")
  let fd = euclid_wb_poly(f)
  let gd = euclid_wb_poly(g)
  inspect(
    euclid_wb_dmp_triple_repr(dmp_inner_gcd(fd, gd, 0, QQ)),
    content="([1,2],[1/2,3/4],[1/2,0])",
  )
  inspect(
    euclid_wb_dmp_triple_repr(dmp_qq_heu_gcd(fd, gd, 0, QQ)),
    content="([1,2],[1/2,3/4],[1/2,0])",
  )
  inspect(euclid_wb_dmp_repr(dmp_gcd(fd, gd, 0, QQ)), content="[1,2]")
  inspect(euclid_wb_dmp_repr(dmp_lcm(fd, gd, 0, QQ)), content="[1,7/2,3,0]")
}

///|
test "euclidtools wb: dense content and primitive frontdoors" {
  let f = [euclid_wb_qq(6, 1), euclid_wb_qq(8, 1), euclid_wb_qq(12, 1)]
  inspect(Show::to_string(dup_content(f, ZZ)), content="2")
  let (content, primitive) = dup_primitive(f, ZZ)
  inspect(
    "(\{content},\{euclid_wb_dup_repr(primitive)})",
    content="(2,[3,4,6])",
  )
  let xy = dense_poly([
    euclid_wb_poly([euclid_wb_qq(2, 1), euclid_wb_qq(6, 1)]),
    euclid_wb_poly([euclid_wb_qq(4, 1), euclid_wb_qq(12, 1)]),
  ])
  inspect(Show::to_string(dmp_ground_content(xy, 1, ZZ)), content="2")
  inspect(
    euclid_wb_ground_primitive_repr(dmp_ground_primitive(xy, 1, ZZ)),
    content="(2,[[1,3],[2,6]])",
  )
  inspect(euclid_wb_dmp_repr(dmp_content(xy, 1, ZZ)), content="[2,6]")
  inspect(
    euclid_wb_dmp_pair_repr(dmp_primitive(xy, 1, ZZ)),
    content="([2,6],[[1],[2]])",
  )
}
