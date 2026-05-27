///|
fn sqf_wb_fe(n : Int) -> FieldElem raise PolyError {
  fe_from_int(n, Domain::ZZ)
}

///|
fn sqf_wb_gf(n : Int, p : Int) -> FieldElem raise PolyError {
  fe_from_int(n, Domain::GF(p))
}

///|
fn sqf_wb_dup(vals : Array[Int]) -> Array[FieldElem] raise PolyError {
  vals.map(v => sqf_wb_fe(v))
}

///|
fn sqf_wb_gf_dup(
  vals : Array[Int],
  p : Int,
) -> Array[FieldElem] raise PolyError {
  vals.map(v => sqf_wb_gf(v, p))
}

///|
fn sqf_wb_poly(vals : Array[Int]) -> DensePoly raise PolyError {
  DensePoly::Poly(vals.map(v => DensePoly::Coef(sqf_wb_fe(v))))
}

///|
fn sqf_wb_dup_repr(f : Array[FieldElem]) -> String {
  "[" + f.map(c => c.to_string()).join(",") + "]"
}

///|
fn sqf_wb_dmp_repr(f : DensePoly) -> String {
  match f {
    DensePoly::Coef(c) => c.to_string()
    DensePoly::Poly(items) =>
      "[" + items.map(item => sqf_wb_dmp_repr(item)).join(",") + "]"
  }
}

///|
fn sqf_wb_dup_factor_repr(
  value : (FieldElem, Array[(Array[FieldElem], Int)]),
) -> String {
  let (coeff, factors) = value
  let parts = factors.map(item => "(\{sqf_wb_dup_repr(item.0)},\{item.1})")
  "(\{coeff},[" + parts.join(",") + "])"
}

///|
fn sqf_wb_dup_include_repr(items : Array[(Array[FieldElem], Int)]) -> String {
  "[" +
  items.map(item => "(\{sqf_wb_dup_repr(item.0)},\{item.1})").join(",") +
  "]"
}

///|
fn sqf_wb_dmp_factor_repr(
  value : (FieldElem, Array[(DensePoly, Int)]),
) -> String {
  let (coeff, factors) = value
  let parts = factors.map(item => "(\{sqf_wb_dmp_repr(item.0)},\{item.1})")
  "(\{coeff},[" + parts.join(",") + "])"
}

///|
fn sqf_wb_dmp_include_repr(items : Array[(DensePoly, Int)]) -> String {
  "[" +
  items.map(item => "(\{sqf_wb_dmp_repr(item.0)},\{item.1})").join(",") +
  "]"
}

///|
fn sqf_wb_alg_minpoly_sqrt3() -> Poly raise PolyError {
  let a = Expr::Symbol("a")
  PolyBuilder::new(["a"], Domain::QQ).from_expr((a ^ int(2)) - int(3))
}

///|
fn sqf_wb_alg_domain_sqrt3() -> Domain raise PolyError {
  let minpoly = sqf_wb_alg_minpoly_sqrt3()
  Domain::AlgExt(Domain::QQ, ["a"], [minpoly.to_expr()])
}

///|
fn sqf_wb_alg_coeff(c0 : Int, c1 : Int) -> FieldElem raise PolyError {
  FieldElem::AlgExt(
    Domain::QQ,
    [fe_from_int(c0, Domain::QQ), fe_from_int(c1, Domain::QQ)],
    sqf_wb_alg_minpoly_sqrt3(),
    "a",
  )
}

///|
test "sqfreetools dense wb: square-free predicate and part" {
  let repeated = sqf_wb_dup([1, -2, 1])
  let squarefree = sqf_wb_dup([1, 0, -1])
  inspect(dup_sqf_p(repeated, Domain::ZZ), content="false")
  inspect(dup_sqf_p(squarefree, Domain::ZZ), content="true")
  inspect(dup_sqf_p([], Domain::ZZ), content="true")
  inspect(
    sqf_wb_dup_repr(dup_sqf_part(sqf_wb_dup([1, 0, -3, -2]), Domain::ZZ)),
    content="[1,-1,-2]",
  )
  inspect(
    sqf_wb_dup_repr(dup_sqf_part(sqf_wb_dup([-1, 0, 3, 2]), Domain::ZZ)),
    content="[1,-1,-2]",
  )
}

///|
test "sqfreetools dense wb: square-free list and include" {
  let f = sqf_wb_dup([2, 16, 50, 76, 56, 16])
  inspect(
    sqf_wb_dup_factor_repr(dup_sqf_list(f, Domain::ZZ)),
    content="(2,[([1,1],2),([1,2],3)])",
  )
  inspect(
    sqf_wb_dup_factor_repr(dup_sqf_list(f, Domain::ZZ, all=true)),
    content="(2,[([1],1),([1,1],2),([1,2],3)])",
  )
  inspect(
    sqf_wb_dup_include_repr(dup_sqf_list_include(f, Domain::ZZ)),
    content="[([2],1),([1,1],2),([1,2],3)]",
  )
  inspect(
    sqf_wb_dup_factor_repr(dup_sqf_list([], Domain::ZZ)),
    content="(0,[])",
  )
}

///|
test "sqfreetools dense wb: finite field path" {
  let f = sqf_wb_gf_dup([1, 0, 1], 2)
  inspect(dup_sqf_p(f, Domain::GF(2)), content="false")
  inspect(sqf_wb_dup_repr(dup_gf_sqf_part(f, Domain::GF(2))), content="[1,1]")
  inspect(
    sqf_wb_dup_factor_repr(dup_gf_sqf_list(f, Domain::GF(2))),
    content="(1,[([1,1],2)])",
  )
}

///|
test "sqfreetools dense wb: dmp univariate wrappers" {
  let f = sqf_wb_poly([2, 16, 50, 76, 56, 16])
  inspect(dmp_sqf_p(sqf_wb_poly([1, -2, 1]), 0, Domain::ZZ), content="false")
  inspect(
    sqf_wb_dmp_repr(dmp_sqf_part(sqf_wb_poly([1, 0, -3, -2]), 0, Domain::ZZ)),
    content="[1,-1,-2]",
  )
  inspect(
    sqf_wb_dmp_factor_repr(dmp_sqf_list(f, 0, Domain::ZZ)),
    content="(2,[([1,1],2),([1,2],3)])",
  )
  inspect(
    sqf_wb_dmp_include_repr(dmp_sqf_list_include(f, 0, Domain::ZZ)),
    content="[([2],1),([1,1],2),([1,2],3)]",
  )
  let bad : Result[Bool, PolyError] = try? dmp_sqf_p(
    DensePoly::Poly([sqf_wb_poly([1, 0]), sqf_wb_poly([1])]),
    1,
    Domain::ZZ,
  )
  assert_true(bad is Err(PolyError::NotUnivariate))
}

///|
test "sqfreetools dense wb: greatest factorial factorization" {
  let f = sqf_wb_dup([1, 2, -1, -2, 0, 0])
  inspect(
    sqf_wb_dup_include_repr(dup_gff_list(f, Domain::ZZ)),
    content="[([1,0],1),([1,2],4)]",
  )
  inspect(
    sqf_wb_dmp_include_repr(
      dmp_gff_list(sqf_wb_poly([1, 2, -1, -2, 0, 0]), 0, Domain::ZZ),
    ),
    content="[([1,0],1),([1,2],4)]",
  )
  let zero : Result[Array[(Array[FieldElem], Int)], PolyError] = try? dup_gff_list(
    [],
    Domain::ZZ,
  )
  assert_true(zero is Err(PolyError::BadExponent))
}

///|
test "sqfreetools dense wb: algebraic norm frontdoors" {
  let domain = sqf_wb_alg_domain_sqrt3()
  let x_plus_a = [fe_from_int(1, domain), sqf_wb_alg_coeff(0, 1)]
  inspect(
    sqf_wb_dmp_repr(
      dmp_norm(
        DensePoly::Poly(x_plus_a.map(c => DensePoly::Coef(c))),
        0,
        domain,
      ),
    ),
    content="[1,0,-3]",
  )
  let f = [
    fe_from_int(1, domain),
    fe_from_int(0, domain),
    fe_from_int(-2, domain),
  ]
  let normed = dup_sqf_norm(f, domain)
  inspect(normed.0, content="1")
  inspect(sqf_wb_dup_repr(normed.1), content="[1,-2*a,1]")
  inspect(sqf_wb_dup_repr(normed.2), content="[1,0,-10,0,1]")
  let dmp_normed = dmp_sqf_norm(
    DensePoly::Poly(f.map(c => DensePoly::Coef(c))),
    0,
    domain,
  )
  debug_inspect(dmp_normed.0, content="[1]")
  inspect(sqf_wb_dmp_repr(dmp_normed.1), content="[1,-2*a,1]")
  inspect(sqf_wb_dmp_repr(dmp_normed.2), content="[1,0,-10,0,1]")
}
