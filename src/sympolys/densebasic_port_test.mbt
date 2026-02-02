///|
fn fez(n : Int) -> FieldElem {
  try! fe_from_int(n, Domain::ZZ)
}

///|
fn br_int(n : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_int(n)
}

///|
fn br_rat(num : Int, den : Int) -> @symnum.BigRational {
  try! @symnum.BigRational::new(BigInt::from_int(num), BigInt::from_int(den))
}

///|
fn dup_repr(coeffs : Array[FieldElem]) -> String {
  let parts = coeffs.map(c => c.to_string()).join(",")
  "[\{parts}]"
}

///|
fn tuple_int_repr(exps : Array[Int]) -> String {
  if exps.length() == 0 {
    return "()"
  }
  if exps.length() == 1 {
    return "(\{exps[0]})"
  }
  let parts = exps.map(x => x.to_string()).join(",")
  "(\{parts})"
}

///|
fn list_int_repr(xs : Array[Int]) -> String {
  let parts = xs.map(x => x.to_string()).join(",")
  "[\{parts}]"
}

///|
fn term_list_repr(terms : Array[(Array[Int], FieldElem)]) -> String {
  let parts : Array[String] = Array::new()
  for term in terms {
    let (exps, coeff) = term
    parts.push("(\{tuple_int_repr(exps)},\{coeff})")
  }
  let joined = parts.join(",")
  "[\{joined}]"
}

///|
fn dense_data_of(p : DensePoly) -> @sympy.DenseData {
  match p {
    DensePoly::Coef(c) => @sympy.DenseData::Coef(try! fe_expect_rational(c))
    DensePoly::Poly(items) => {
      let out : Array[@sympy.DenseData] = Array::new()
      for it in items {
        out.push(dense_data_of(it))
      }
      @sympy.DenseData::Poly(out)
    }
  }
}

///|
fn dense_data_of_rat(p : DenseRat) -> @sympy.DenseData {
  match p {
    DenseRat::Coef(c) => @sympy.DenseData::Coef(c)
    DenseRat::Poly(items) => {
      let out : Array[@sympy.DenseData] = Array::new()
      for it in items {
        out.push(dense_data_of_rat(it))
      }
      @sympy.DenseData::Poly(out)
    }
  }
}

///|
fn dpp_from_polys(polys : Array[Poly]) -> DensePolyPoly {
  let out : Array[DensePolyPoly] = Array::new()
  for p in polys {
    out.push(dense_poly_poly_coef(p))
  }
  dense_poly_poly(out)
}

///|
fn dpp_repr(p : DensePolyPoly) -> String {
  match p {
    DensePolyPoly::Coef(poly) => poly.to_string()
    DensePolyPoly::Poly(items) => {
      let parts : Array[String] = Array::new()
      for it in items {
        parts.push(dpp_repr(it))
      }
      let joined = parts.join(",")
      "[\{joined}]"
    }
  }
}

///|
fn coef(n : Int) -> DensePoly {
  dense_coef(fez(n))
}

///|
fn poly(xs : Array[DensePoly]) -> DensePoly {
  dense_poly(xs)
}

///|
fn monom_poly(exps : Array[Int]) -> DensePoly {
  if exps.length() == 0 {
    return coef(1)
  }
  let e0 = exps[0]
  let rest : Array[Int] = Array::new()
  for i in 1..<exps.length() {
    rest.push(exps[i])
  }
  let depth = exps.length() - 1
  if depth == 0 {
    let items : Array[DensePoly] = Array::make(e0 + 1, coef(0))
    items.set(0, coef(1))
    return poly(items)
  }
  let child = monom_poly(rest)
  let zero_child = dmp_zero(depth - 1)
  let items : Array[DensePoly] = Array::make(e0 + 1, zero_child)
  items.set(0, child)
  poly(items)
}

///|
fn dense_repr(p : DensePoly) -> String {
  match p {
    DensePoly::Coef(c) => c.to_string()
    DensePoly::Poly(items) => {
      let parts : Array[String] = Array::new()
      for it in items {
        parts.push(dense_repr(it))
      }
      let joined = parts.join(",")
      "[\{joined}]"
    }
  }
}

///|
fn dense_list_repr(xs : Array[DensePoly]) -> String {
  let parts : Array[String] = Array::new()
  for it in xs {
    parts.push(dense_repr(it))
  }
  let joined = parts.join(",")
  "[\{joined}]"
}

///|
fn monom_key(m : Monomial) -> String {
  m.to_array().map(x => x.to_string()).join(",")
}

///|
fn map_monom_repr(map : Map[Monomial, FieldElem]) -> String {
  let items : Array[(String, String)] = Array::new()
  for m, c in map {
    items.push((monom_key(m), c.to_string()))
  }
  items.sort_by((a, b) => a.0.compare(b.0))
  let parts = items.map(t => "\{t.0}:\{t.1}").join(",")
  "{\{parts}}"
}

///|
fn map_int_repr(map : Map[Int, FieldElem]) -> String {
  let items : Array[(Int, String)] = Array::new()
  for k, v in map {
    items.push((k, v.to_string()))
  }
  items.sort_by((a, b) => a.0 - b.0)
  let parts = items.map(t => "\{t.0}:\{t.1}").join(",")
  "{\{parts}}"
}

///|
fn expr_from_coeffs_desc(coeffs : Array[Int]) -> String {
  let deg = coeffs.length() - 1
  let parts : Array[String] = Array::new()
  for i in 0..<coeffs.length() {
    let c = coeffs[i]
    if c == 0 {
      continue
    }
    let abs_c = if c < 0 { -c } else { c }
    let sign = if c < 0 { "-" } else { "" }
    let power = deg - i
    let term = if power == 0 {
      "\{sign}\{abs_c}"
    } else if power == 1 {
      if abs_c == 1 {
        "\{sign}x"
      } else {
        "\{sign}\{abs_c}*x"
      }
    } else if abs_c == 1 {
      "\{sign}x**\{power}"
    } else {
      "\{sign}\{abs_c}*x**\{power}"
    }
    parts.push(term)
  }
  if parts.is_empty() {
    "0"
  } else {
    let joined = parts.join(" + ")
    joined.replace_all(old="+ -", new="- ")
  }
}

///|
test "densebasic: LC/TC/degree/strip/reverse" {
  let a : Array[FieldElem] = [fez(2), fez(3), fez(0), fez(0), fez(5)]
  let lc = dup_LC(a)
  inspect(lc, content="2")
  let tc = dup_TC(a)
  inspect(tc, content="5")
  let deg = dup_degree(a)
  inspect(deg, content="4")
  let stripped = dup_strip(a)
  inspect(stripped.length(), content="5")
  inspect(stripped[4], content="5")
  let zeros : Array[FieldElem] = [fez(0), fez(0)]
  let degz = dup_degree(zeros)
  inspect(degz, content="1")
  let stripped_zero = dup_strip(zeros)
  inspect(stripped_zero.length(), content="0")
  let rev = dup_reverse(a)
  inspect(rev[0], content="5")
  inspect(rev[4], content="2")
}

///|
test "densebasic: univariate LC/TC/degree parity via SymPy" {
  let coeffs : Array[Int] = [2, 3, 0, 0, 5]
  let elems : Array[FieldElem] = coeffs.map(n => fez(n))
  let lc = dup_LC(elems)
  let tc = dup_TC(elems)
  let deg = dup_degree(elems)
  let expr = expr_from_coeffs_desc(coeffs)
  inspect(expr, content="2*x**4 + 3*x**3 + 5")
  let lc_oracle = @sympy.poly_lc(expr, gens=["x"])
  let tc_oracle = @sympy.poly_tc(expr, gens=["x"])
  let degs = @sympy.poly_degree_list(expr, gens=["x"])
  inspect(lc, content=lc_oracle)
  inspect(tc, content=tc_oracle)
  inspect(deg, content=degs[0].to_string())
}

///|
test "densebasic: dmp_LC/TC zero and nested shapes" {
  let z1 = poly([poly([])])
  inspect(dense_repr(dmp_LC(z1)), content="[]")
  inspect(dense_repr(dmp_TC(z1)), content="[]")
  let f = poly([poly([coef(2), coef(3), coef(4)]), poly([coef(5)])])
  inspect(dense_repr(dmp_LC(f)), content="[2,3,4]")
  inspect(dense_repr(dmp_TC(f)), content="[5]")
  let z2 = poly([poly([poly([])])])
  inspect(dense_repr(dmp_LC(z2)), content="[[]]")
  inspect(dense_repr(dmp_TC(z2)), content="[[]]")
  let g = poly([
    poly([poly([coef(2)]), poly([coef(3), coef(4)])]),
    poly([poly([coef(5)])]),
  ])
  inspect(dense_repr(dmp_LC(g)), content="[[2],[3,4]]")
  inspect(dense_repr(dmp_TC(g)), content="[[5]]")
}

///|
test "densebasic: multivariate LC/TC/degree list and true_LT" {
  // Represent [[2,3,4],[5]] as DensePoly
  let f = poly([poly([coef(2), coef(3), coef(4)]), poly([coef(5)])])
  inspect(
    match dmp_LC(f) {
      DensePoly::Poly(_) => "poly"
      _ => "coef"
    },
    content="poly",
  )
  let glc = dmp_ground_LC(f, 1)
  inspect(glc, content="2")
  let gtc = dmp_ground_TC(f, 1)
  inspect(gtc, content="5")
  inspect(dmp_degree(f, 1), content="1")
  inspect(dmp_degree_in(f, 1, 1), content="2")
  let degs = dmp_degree_list(f, 1)
  inspect(degs, content="[1, 2]")
  let lt = dmp_true_LT(f, 1)
  let (exps, coeff) = lt
  inspect(exps, content="[1, 2]")
  inspect(coeff, content="2")

  // zero polynomial [[[]]]
  let z = poly([poly([poly([])])])
  inspect(dmp_degree(z, 2), content="-1")
  let lt_z = dmp_true_LT(z, 2)
  inspect(lt_z.0, content="[0, 0, 0]")
  inspect(lt_z.1, content="0")
}

///|
test "densebasic: dmp_strip and dmp_reverse edge cases" {
  let u0 = poly([coef(0)])
  let u0s = dmp_strip(u0)
  inspect(dense_repr(u0s), content="[]")
  let u1 = poly([coef(0), coef(0)])
  let u1s = dmp_strip(u1)
  inspect(dense_repr(u1s), content="[]")
  let u1b = poly([coef(0), coef(0), coef(0)])
  let u1bs = dmp_strip(u1b)
  inspect(dense_repr(u1bs), content="[]")
  let u2 = poly([coef(0), coef(1), coef(0)])
  let u2s = dmp_strip(u2)
  inspect(dense_repr(u2s), content="[1,0]")
  let u3 = poly([coef(0), coef(0), coef(1), coef(2), coef(0)])
  let u3s = dmp_strip(u3)
  inspect(dense_repr(u3s), content="[1,2,0]")
  let u4 = poly([coef(0), coef(0), coef(0), coef(1), coef(2), coef(0)])
  let u4s = dmp_strip(u4)
  inspect(dense_repr(u4s), content="[1,2,0]")
  let z1 = poly([])
  let zstrip = dmp_strip(z1)
  inspect(dense_repr(zstrip), content="[]")
  let zlen = match zstrip {
    DensePoly::Poly(items) => items.length().to_string()
    _ => "0"
  }
  inspect(zlen, content="0")
  let f = poly([coef(0), coef(0), coef(1), coef(2)])
  let fstrip = dmp_strip(f)
  let flen = match fstrip {
    DensePoly::Poly(items) => items.length().to_string()
    _ => "0"
  }
  inspect(flen, content="2")
  let rev = dmp_reverse(f)
  let rev_lc = match dmp_LC(rev) {
    DensePoly::Coef(c) => c.to_string()
    _ => "0"
  }
  inspect(rev_lc, content="2")
  let rev1 = dmp_reverse(poly([coef(1), coef(2), coef(3), coef(0)]))
  inspect(dense_repr(rev1), content="[3,2,1]")
  let rev2 = dmp_reverse(poly([coef(1), coef(2), coef(0), coef(3)]))
  inspect(dense_repr(rev2), content="[3,0,2,1]")
  let revz = dmp_reverse(poly([]))
  inspect(dense_repr(revz), content="[]")
  let revc = dmp_reverse(coef(3))
  inspect(dense_repr(revc), content="3")
  let mv = poly([
    poly([poly([coef(1), coef(0)]), poly([coef(2)])]),
    poly([poly([coef(3)])]),
    poly([]),
  ])
  let mv_rev = dmp_reverse(mv)
  inspect(dense_repr(mv_rev), content="[[[3]],[[2],[1]]]")
  let rz1 = dmp_reverse(poly([poly([]), poly([])]))
  inspect(dense_repr(rz1), content="[[]]")
  let rz0 = dmp_reverse(poly([poly([]), poly([]), poly([])]))
  inspect(dense_repr(rz0), content="[[]]")
  let rz2 = dmp_reverse(poly([poly([]), poly([coef(1)])]))
  inspect(dense_repr(rz2), content="[[1],[]]")
}

///|
test "densebasic: dmp_strip multivariate sympy cases" {
  let z1 = poly([poly([])])
  inspect(dense_repr(dmp_strip(z1)), content="[[]]")
  let z2 = poly([poly([]), poly([])])
  inspect(dense_repr(dmp_strip(z2)), content="[[]]")
  let z3 = poly([poly([]), poly([]), poly([])])
  inspect(dense_repr(dmp_strip(z3)), content="[[]]")
  let z4 = poly([poly([poly([])])])
  inspect(dense_repr(dmp_strip(z4)), content="[[[]]]")
  let z5 = poly([poly([poly([])]), poly([poly([])])])
  inspect(dense_repr(dmp_strip(z5)), content="[[[]]]")
  let z6 = poly([poly([poly([])]), poly([poly([])]), poly([poly([])])])
  inspect(dense_repr(dmp_strip(z6)), content="[[[]]]")
  let o1 = poly([poly([poly([coef(1)])])])
  inspect(dense_repr(dmp_strip(o1)), content="[[[1]]]")
  let o2 = poly([poly([poly([])]), poly([poly([coef(1)])])])
  inspect(dense_repr(dmp_strip(o2)), content="[[[1]]]")
  let o3 = poly([poly([poly([])]), poly([poly([coef(1)])]), poly([poly([])])])
  inspect(dense_repr(dmp_strip(o3)), content="[[[1]],[[]]]")
}

///|
test "densebasic: dmp_degree_list deeper cases" {
  let deep_zero = poly([poly([poly([poly([])])])])
  let degz = dmp_degree_list(deep_zero, 3)
  inspect(degz, content="[-1, -1, -1, -1]")
  let deep_one = poly([poly([poly([poly([coef(1)])])])])
  let dego = dmp_degree_list(deep_one, 3)
  inspect(dego, content="[0, 0, 0, 0]")
}

///|
test "densebasic: dmp_degree_in/list sympy f_polys degrees" {
  let f0 = monom_poly([2, 2, 2])
  inspect(dmp_degree_list(f0, 2), content="[2, 2, 2]")
  let f1 = monom_poly([3, 3, 3])
  inspect(dmp_degree_list(f1, 2), content="[3, 3, 3]")
  let f2 = monom_poly([5, 3, 3])
  inspect(dmp_degree_list(f2, 2), content="[5, 3, 3]")
  let f3 = monom_poly([5, 4, 7])
  inspect(dmp_degree_list(f3, 2), content="[5, 4, 7]")
  let f4 = monom_poly([9, 12, 8])
  inspect(dmp_degree_in(f4, 0, 2), content="9")
  inspect(dmp_degree_in(f4, 1, 2), content="12")
  inspect(dmp_degree_in(f4, 2, 2), content="8")
  inspect(dmp_degree_list(f4, 2), content="[9, 12, 8]")
  let f5 = monom_poly([3, 3, 3])
  inspect(dmp_degree_list(f5, 2), content="[3, 3, 3]")
  let f6 = monom_poly([4, 4, 6, 3])
  inspect(dmp_degree_in(f6, 0, 3), content="4")
  inspect(dmp_degree_in(f6, 1, 3), content="4")
  inspect(dmp_degree_in(f6, 2, 3), content="6")
  inspect(dmp_degree_in(f6, 3, 3), content="3")
  inspect(dmp_degree_list(f6, 3), content="[4, 4, 6, 3]")
}

///|
test "densebasic: dmp_ground_LC/TC nested structures" {
  let z1 = poly([poly([])])
  let glc1 = dmp_ground_LC(z1, 1)
  let gtc1 = dmp_ground_TC(z1, 1)
  inspect(glc1, content="0")
  inspect(gtc1, content="0")
  let z2 = poly([poly([poly([])])])
  let glc2 = dmp_ground_LC(z2, 2)
  let gtc2 = dmp_ground_TC(z2, 2)
  inspect(glc2, content="0")
  inspect(gtc2, content="0")
  let f = poly([
    poly([poly([coef(2)]), poly([coef(3), coef(4)])]),
    poly([poly([coef(5)])]),
  ])
  let glc = dmp_ground_LC(f, 2)
  let gtc = dmp_ground_TC(f, 2)
  inspect(glc, content="2")
  inspect(gtc, content="5")
}

///|
test "densebasic: dmp_strip canonical zero shapes" {
  let z1 = poly([poly([])])
  let z1s = dmp_strip(z1)
  inspect(dense_repr(z1s), content="[[]]")
  let z2 = poly([poly([]), poly([])])
  let z2s = dmp_strip(z2)
  inspect(dense_repr(z2s), content="[[]]")
  let z3 = poly([poly([poly([])])])
  let z3s = dmp_strip(z3)
  inspect(dense_repr(z3s), content="[[[]]]")
  let z4 = poly([poly([poly([])]), poly([poly([])])])
  let z4s = dmp_strip(z4)
  inspect(dense_repr(z4s), content="[[[]]]")
  let z5 = poly([poly([coef(1)])])
  let z5s = dmp_strip(z5)
  inspect(dense_repr(z5s), content="[[1]]")
  let z6 = poly([poly([poly([])]), poly([coef(1)])])
  let z6s = dmp_strip(z6)
  inspect(dense_repr(z6s), content="[[1]]")
  let z7 = poly([poly([poly([])]), poly([coef(1)]), poly([poly([])])])
  let z7s = dmp_strip(z7)
  inspect(dense_repr(z7s), content="[[1],[[]]]")
}

///|
test "densebasic: dmp_validate" {
  let v0 = dmp_validate(poly([]))
  inspect(dense_repr(v0.0), content="[]")
  inspect(v0.1, content="0")
  let v1 = dmp_validate(poly([coef(0), coef(0), coef(0), coef(1), coef(0)]))
  inspect(dense_repr(v1.0), content="[1,0]")
  inspect(v1.1, content="0")
  let v2 = dmp_validate(poly([poly([poly([])])]))
  inspect(dense_repr(v2.0), content="[[[]]]")
  inspect(v2.1, content="2")
  let v3 = dmp_validate(
    poly([
      poly([coef(0)]),
      poly([]),
      poly([coef(0)]),
      poly([coef(1)]),
      poly([coef(0)]),
    ]),
  )
  inspect(dense_repr(v3.0), content="[[1],[]]")
  inspect(v3.1, content="1")
  let bad : Result[(DensePoly, Int), PolyError] = try? dmp_validate(
    poly([
      poly([coef(0)]),
      coef(0),
      poly([coef(0)]),
      poly([coef(1)]),
      poly([coef(0)]),
    ]),
  )
  guard bad is Err(PolyError::NonPolynomial) else {
    fail("expected NonPolynomial")
  }
}

///|
test "densebasic: dmp_degree_in/list coverage" {
  let z1 = poly([poly([])])
  inspect(dmp_degree(z1, 1), content="-1")
  inspect(dmp_degree_in(z1, 0, 1), content="-1")
  inspect(dmp_degree_in(z1, 1, 1), content="-1")
  let c0 = poly([poly([coef(1)])])
  inspect(dmp_degree(c0, 1), content="0")
  inspect(dmp_degree_in(c0, 0, 1), content="0")
  inspect(dmp_degree_in(c0, 1, 1), content="0")
  let f0 = poly([poly([coef(2)]), poly([coef(1)])])
  inspect(dmp_degree(f0, 1), content="1")
  let f = poly([poly([coef(1)]), poly([coef(0)]), poly([coef(2), coef(0)])])
  inspect(dmp_degree(f, 1), content="2")
  inspect(dmp_degree_in(f, 1, 1), content="1")
  let degs = dmp_degree_list(f, 1)
  inspect(degs, content="[2, 1]")
  let z = poly([])
  inspect(dmp_degree_in(z, 1, 1), content="-1")
  let f2 = poly([
    poly([coef(1), coef(0), coef(0), coef(0)]),
    poly([coef(1), coef(0)]),
    poly([]),
  ])
  inspect(dmp_degree(f2, 1), content="2")
  inspect(dmp_degree_in(f2, 1, 1), content="3")
  let degs2 = dmp_degree_list(f2, 1)
  inspect(degs2, content="[2, 3]")
  let f3 = poly([
    poly([poly([coef(1), coef(0)]), poly([coef(2)])]),
    poly([poly([coef(3)])]),
  ])
  inspect(dmp_degree(f3, 2), content="1")
  inspect(dmp_degree_in(f3, 0, 2), content="1")
  inspect(dmp_degree_in(f3, 1, 2), content="1")
  inspect(dmp_degree_in(f3, 2, 2), content="1")
  let degs3 = dmp_degree_list(f3, 2)
  inspect(degs3, content="[1, 1, 1]")
  let z3 = poly([poly([poly([])])])
  inspect(dmp_degree_in(z3, 0, 2), content="-1")
  inspect(dmp_degree_in(z3, 1, 2), content="-1")
  inspect(dmp_degree_in(z3, 2, 2), content="-1")
  let c1 = poly([poly([poly([coef(1)])])])
  inspect(dmp_degree_in(c1, 0, 2), content="0")
  inspect(dmp_degree_in(c1, 1, 2), content="0")
  inspect(dmp_degree_in(c1, 2, 2), content="0")
}

///|
test "densebasic: dmp_degree_in bounds" {
  let f = poly([poly([coef(1)])])
  let neg : Result[Int, PolyError] = try? dmp_degree_in(f, -1, 1)
  guard neg is Err(PolyError::BadExponent) else { fail("expected BadExponent") }
  let high : Result[Int, PolyError] = try? dmp_degree_in(f, 2, 1)
  guard high is Err(PolyError::BadExponent) else {
    fail("expected BadExponent")
  }
}

///|
test "densebasic: dmp_true_LT examples" {
  let z = poly([poly([])])
  let lt0 = dmp_true_LT(z, 1)
  inspect(lt0.0, content="[0, 0]")
  inspect(lt0.1, content="0")
  let a = poly([poly([coef(7)])])
  let lt1 = dmp_true_LT(a, 1)
  inspect(lt1.0, content="[0, 0]")
  inspect(lt1.1, content="7")
  let b = poly([poly([coef(1), coef(0)])])
  let lt2 = dmp_true_LT(b, 1)
  inspect(lt2.0, content="[0, 1]")
  inspect(lt2.1, content="1")
  let c = poly([poly([coef(1)]), poly([])])
  let lt3 = dmp_true_LT(c, 1)
  inspect(lt3.0, content="[1, 0]")
  inspect(lt3.1, content="1")
  let d = poly([poly([coef(1), coef(0)]), poly([])])
  let lt4 = dmp_true_LT(d, 1)
  inspect(lt4.0, content="[1, 1]")
  inspect(lt4.1, content="1")
}

///|
test "densebasic: dup_strip and dup_reverse variants" {
  let a : Array[FieldElem] = [fez(0)]
  inspect(dup_strip(a).length(), content="0")
  let b : Array[FieldElem] = [fez(0), fez(0), fez(0)]
  inspect(dup_strip(b).length(), content="0")
  let c : Array[FieldElem] = [fez(0), fez(1)]
  let cstrip = dup_strip(c)
  inspect(cstrip.map(x => x.to_string()).join(","), content="1")
  let r1 = dup_reverse([fez(1), fez(2), fez(0), fez(3)])
  inspect(r1.map(x => x.to_string()).join(","), content="3,0,2,1")
  let r2 = dup_reverse([fez(1), fez(2), fez(3), fez(0)])
  inspect(r2.map(x => x.to_string()).join(","), content="3,2,1")
}

///|
test "densebasic: dup_copy/dmp_copy" {
  let f : Array[FieldElem] = [fez(1), fez(0), fez(2)]
  let g = dup_copy(f)
  g.set(0, fez(7))
  g.set(2, fez(0))
  inspect(f[0], content="1")
  inspect(f[2], content="2")
  let f2 = poly([poly([coef(1)]), poly([coef(2), coef(0)])])
  let g2 = dmp_copy(f2, 1)
  match g2 {
    DensePoly::Poly(items) =>
      match items[0] {
        DensePoly::Poly(inner) => inner.set(0, coef(7))
        _ => ()
      }
    _ => ()
  }
  inspect(dense_repr(f2), content="[[1],[2,0]]")
}

///|
test "densebasic: dup_normal/dmp_normal" {
  let f : Array[FieldElem] = [
    fez(0),
    fez(0),
    fez(2),
    fez(1),
    fez(0),
    fez(11),
    fez(0),
  ]
  let norm = dup_normal(f)
  let parts = norm.map(c => c.to_string()).join(",")
  inspect(parts, content="2,1,0,11,0")
  let f2 = poly([
    poly([coef(0)]),
    poly([]),
    poly([coef(0), coef(2), coef(1)]),
    poly([coef(0)]),
    poly([coef(11)]),
    poly([]),
  ])
  let norm2 = dmp_normal(f2, 1)
  inspect(dense_repr(norm2), content="[[2,1],[],[11],[]]")
}

///|
test "densebasic: dup_convert/dmp_convert" {
  let f : Array[FieldElem] = [fez(1), fez(2), fez(0), fez(3)]
  let c1 = dup_convert(f, Domain::ZZ, Domain::ZZ)
  let parts = c1.map(c => c.to_string()).join(",")
  inspect(parts, content="1,2,0,3")
  let f2 = poly([poly([coef(1)]), poly([coef(2)]), poly([]), poly([coef(3)])])
  let c2 = dmp_convert(f2, 1, Domain::ZZ, Domain::ZZ)
  inspect(dense_repr(c2), content="[[1],[2],[],[3]]")
}

///|
test "densebasic: dup_nth/dmp_nth/dmp_ground_nth" {
  inspect(dup_nth([fez(1), fez(2), fez(3)], 0), content="3")
  inspect(dup_nth([fez(1), fez(2), fez(3)], 1), content="2")
  inspect(dup_nth([fez(1), fez(2), fez(3)], 2), content="1")
  inspect(dup_nth([fez(1), fez(2), fez(3)], 9), content="0")
  let neg : Result[FieldElem, PolyError] = try? dup_nth(
    [fez(3), fez(4), fez(5)],
    -1,
  )
  guard neg is Err(PolyError::BadExponent) else { fail("expected BadExponent") }
  let f = poly([poly([coef(1)]), poly([coef(2)]), poly([coef(3)])])
  inspect(dense_repr(dmp_nth(f, 0, 1)), content="[3]")
  inspect(dense_repr(dmp_nth(f, 1, 1)), content="[2]")
  inspect(dense_repr(dmp_nth(f, 2, 1)), content="[1]")
  inspect(dense_repr(dmp_nth(f, 9, 1)), content="[]")
  let neg2 : Result[DensePoly, PolyError] = try? dmp_nth(f, -1, 1)
  guard neg2 is Err(PolyError::BadExponent) else {
    fail("expected BadExponent")
  }
  let f3 = poly([poly([])])
  inspect(dmp_ground_nth(f3, [0, 0], 1, Domain::ZZ), content="0")
  let f4 = poly([poly([coef(1)]), poly([coef(2)]), poly([coef(3)])])
  inspect(dmp_ground_nth(f4, [0, 0], 1, Domain::ZZ), content="3")
  inspect(dmp_ground_nth(f4, [1, 0], 1, Domain::ZZ), content="2")
  inspect(dmp_ground_nth(f4, [2, 0], 1, Domain::ZZ), content="1")
  inspect(dmp_ground_nth(f4, [2, 1], 1, Domain::ZZ), content="0")
  inspect(dmp_ground_nth(f4, [3, 0], 1, Domain::ZZ), content="0")
  let neg3 : Result[FieldElem, PolyError] = try? dmp_ground_nth(
    f4,
    [2, -1],
    1,
    Domain::ZZ,
  )
  guard neg3 is Err(PolyError::BadExponent) else {
    fail("expected BadExponent")
  }
}

///|
test "densebasic: zero/one/ground helpers" {
  let z0 = dmp_zero(0)
  let z2 = dmp_zero(2)
  inspect(dense_repr(z0), content="[]")
  inspect(dense_repr(z2), content="[[[]]]")
  inspect(dmp_zero_p(poly([]), 0), content="true")
  inspect(dmp_zero_p(poly([poly([])]), 1), content="true")
  inspect(dmp_zero_p(poly([poly([poly([])])]), 2), content="true")
  inspect(dmp_zero_p(poly([poly([poly([coef(1)])])]), 2), content="false")
  let one0 = dmp_one(0, Domain::ZZ)
  let one2 = dmp_one(2, Domain::ZZ)
  inspect(dense_repr(one0), content="[1]")
  inspect(dense_repr(one2), content="[[[1]]]")
  inspect(dmp_one_p(poly([coef(1)]), 0, Domain::ZZ), content="true")
  inspect(dmp_one_p(poly([poly([coef(1)])]), 1, Domain::ZZ), content="true")
  inspect(
    dmp_one_p(poly([poly([poly([coef(1)])])]), 2, Domain::ZZ),
    content="true",
  )
  inspect(
    dmp_one_p(poly([poly([poly([coef(12)])])]), 2, Domain::ZZ),
    content="false",
  )
  inspect(dmp_ground_p(poly([]), Some(fez(0)), 0), content="true")
  inspect(dmp_ground_p(poly([poly([])]), Some(fez(0)), 1), content="true")
  inspect(dmp_ground_p(poly([poly([])]), Some(fez(1)), 1), content="false")
  inspect(
    dmp_ground_p(poly([poly([coef(1)])]), Some(fez(1)), 1),
    content="true",
  )
  inspect(
    dmp_ground_p(poly([poly([poly([coef(2)])])]), Some(fez(2)), 2),
    content="true",
  )
  inspect(
    dmp_ground_p(poly([poly([poly([coef(2)])])]), Some(fez(3)), 2),
    content="false",
  )
  inspect(
    dmp_ground_p(poly([poly([poly([coef(3)]), poly([])])]), Some(fez(3)), 2),
    content="false",
  )
  inspect(dmp_ground_p(poly([]), None, 0), content="true")
  inspect(dmp_ground_p(poly([poly([])]), None, 1), content="true")
  inspect(dmp_ground_p(poly([coef(1)]), None, 0), content="true")
  inspect(
    dmp_ground_p(poly([poly([poly([coef(1)])])]), None, 2),
    content="true",
  )
  inspect(
    dmp_ground_p(poly([poly([poly([coef(3)]), poly([])])]), None, 2),
    content="false",
  )
  inspect(dense_repr(dmp_ground(fez(0), 2)), content="[[[]]]")
  inspect(dense_repr(dmp_ground(fez(7), -1)), content="7")
  inspect(dense_repr(dmp_ground(fez(7), 0)), content="[7]")
  inspect(dense_repr(dmp_ground(fez(7), 2)), content="[[[7]]]")
  let zeros0 = dmp_zeros(4, 0, Domain::ZZ)
  inspect(dense_list_repr(zeros0), content="[[],[],[],[]]")
  let zeros1 = dmp_zeros(0, 2, Domain::ZZ)
  inspect(dense_list_repr(zeros1), content="[]")
  let zeros2 = dmp_zeros(1, 2, Domain::ZZ)
  inspect(dense_list_repr(zeros2), content="[[[[]]]]")
  let zeros3 = dmp_zeros(2, 2, Domain::ZZ)
  inspect(dense_list_repr(zeros3), content="[[[[]]],[[[]]]]")
  let zeros4 = dmp_zeros(3, 2, Domain::ZZ)
  inspect(dense_list_repr(zeros4), content="[[[[]]],[[[]]],[[[]]]]")
  let zeros5 = dmp_zeros(3, -1, Domain::ZZ)
  inspect(dense_list_repr(zeros5), content="[0,0,0]")
  let grounds0 = dmp_grounds(fez(7), 0, 2, Domain::ZZ)
  inspect(dense_list_repr(grounds0), content="[]")
  let grounds1 = dmp_grounds(fez(7), 1, 2, Domain::ZZ)
  inspect(dense_list_repr(grounds1), content="[[[[7]]]]")
  let grounds2 = dmp_grounds(fez(7), 2, 2, Domain::ZZ)
  inspect(dense_list_repr(grounds2), content="[[[[7]]],[[[7]]]]")
  let grounds3 = dmp_grounds(fez(7), 3, 2, Domain::ZZ)
  inspect(dense_list_repr(grounds3), content="[[[[7]]],[[[7]]],[[[7]]]]")
  let grounds4 = dmp_grounds(fez(7), 3, -1, Domain::ZZ)
  inspect(dense_list_repr(grounds4), content="[7,7,7]")
}

///|
test "densebasic: negative/positive helpers" {
  let z = poly([poly([poly([])])])
  inspect(dmp_negative_p(z, 2), content="false")
  inspect(dmp_positive_p(z, 2), content="false")
  let p1 = poly([poly([coef(1)]), poly([coef(2)])])
  inspect(dmp_negative_p(p1, 1), content="false")
  inspect(dmp_positive_p(p1, 1), content="true")
  let p2 = poly([poly([coef(-1)]), poly([coef(2)])])
  inspect(dmp_negative_p(p2, 1), content="true")
  inspect(dmp_positive_p(p2, 1), content="false")
}

///|
test "densebasic: dup_from/to_dict and raw dict" {
  let raw : Map[Int, FieldElem] = Map::new()
  raw.set(8, fez(3))
  raw.set(5, fez(2))
  raw.set(0, fez(8))
  let f = dup_from_raw_dict(raw, Domain::ZZ)
  inspect(f.map(c => c.to_string()).join(","), content="3,0,0,2,0,0,0,0,8")
  let raw_back = dup_to_raw_dict(f, Domain::ZZ)
  inspect(map_int_repr(raw_back), content="{0:8,5:2,8:3}")
  let dict : Map[Monomial, FieldElem] = Map::new()
  dict.set(monomial_from_array([8]), fez(3))
  dict.set(monomial_from_array([5]), fez(2))
  dict.set(monomial_from_array([0]), fez(8))
  let f2 = dup_from_dict(dict, Domain::ZZ)
  inspect(f2.map(c => c.to_string()).join(","), content="3,0,0,2,0,0,0,0,8")
  let dict_back = dup_to_dict(f2, Domain::ZZ)
  inspect(map_monom_repr(dict_back), content="{0:8,5:2,8:3}")
}

///|
test "densebasic: dmp_from/to_dict" {
  let dict : Map[Monomial, FieldElem] = Map::new()
  dict.set(monomial_from_array([8, 0]), fez(3))
  dict.set(monomial_from_array([5, 0]), fez(2))
  dict.set(monomial_from_array([0, 0]), fez(8))
  let f = dmp_from_dict(dict, 1, Domain::ZZ)
  inspect(dense_repr(f), content="[[3],[],[],[2],[],[],[],[],[8]]")
  let back = dmp_to_dict(f, 1, Domain::ZZ)
  inspect(map_monom_repr(back), content="{0,0:8,5,0:2,8,0:3}")
  let empty : Map[Monomial, FieldElem] = Map::new()
  let z = dmp_from_dict(empty, 1, Domain::ZZ)
  inspect(dense_repr(z), content="[[]]")
}

///|
test "densebasic: dmp_swap and dmp_permute" {
  let dict : Map[Monomial, FieldElem] = Map::new()
  dict.set(monomial_from_array([1, 0]), fez(2))
  dict.set(monomial_from_array([0, 1]), fez(3))
  let f = dmp_from_dict(dict, 1, Domain::ZZ)
  let swapped = dmp_swap(f, 0, 1, 1, Domain::ZZ)
  let swapped_dict = dmp_to_dict(swapped, 1, Domain::ZZ)
  inspect(map_monom_repr(swapped_dict), content="{0,1:2,1,0:3}")
  let perm = dmp_permute(f, [1, 0], 1, Domain::ZZ)
  let perm_dict = dmp_to_dict(perm, 1, Domain::ZZ)
  inspect(map_monom_repr(perm_dict), content="{0,1:2,1,0:3}")
}

///|
test "densebasic: dmp_nest and dmp_raise" {
  let a = poly([coef(1)])
  let nested = dmp_nest(a, 2, Domain::ZZ)
  inspect(dense_repr(nested), content="[[[1]]]")
  let raised0 = dmp_raise(poly([]), 2, 0, Domain::ZZ)
  inspect(dense_repr(raised0), content="[[[]]]")
  let raised1 = dmp_raise(poly([poly([coef(1)])]), 0, 1, Domain::ZZ)
  inspect(dense_repr(raised1), content="[[1]]")
  let f = poly([
    poly([coef(1), coef(2), coef(3)]),
    poly([]),
    poly([coef(2), coef(3)]),
  ])
  let raised2 = dmp_raise(f, 2, 1, Domain::ZZ)
  inspect(
    dense_repr(raised2),
    content="[[[[1]],[[2]],[[3]]],[[[]]],[[[2]],[[3]]]]",
  )
}

///|
test "densebasic: deflate/inflate helpers" {
  let f : Array[FieldElem] = [
    fez(1),
    fez(0),
    fez(0),
    fez(1),
    fez(0),
    fez(0),
    fez(1),
  ]
  let (g, def) = dup_deflate(f, Domain::ZZ)
  inspect(g, content="3")
  inspect(def.map(c => c.to_string()).join(","), content="1,1,1")
  let ff = poly([
    poly([coef(1), coef(0), coef(0)]),
    poly([]),
    poly([coef(1), coef(0)]),
    poly([]),
    poly([coef(1)]),
  ])
  let (b, def2) = dmp_deflate(ff, 1, Domain::ZZ)
  inspect(b, content="[2, 1]")
  inspect(dense_repr(def2), content="[[1,0,0],[1,0],[1]]")
  let polys : Array[Array[FieldElem]] = [
    [fez(1), fez(0), fez(2), fez(0), fez(3)],
    [fez(4), fez(0), fez(0)],
  ]
  let (g2, defs) = dup_multi_deflate(polys, Domain::ZZ)
  inspect(g2, content="2")
  inspect(defs[0].map(c => c.to_string()).join(","), content="1,2,3")
  inspect(defs[1].map(c => c.to_string()).join(","), content="4,0")
  let p1 = poly([poly([coef(2)])])
  let p2 = poly([poly([coef(2), coef(0), coef(0)])])
  let (m2, defs2) = dmp_multi_deflate([p1, p2], 1, Domain::ZZ)
  inspect(m2, content="[1, 2]")
  inspect(dense_repr(defs2[0]), content="[[2]]")
  inspect(dense_repr(defs2[1]), content="[[2,0]]")
  let infl = dup_inflate([fez(1), fez(1), fez(1)], 3, Domain::ZZ)
  inspect(infl.map(c => c.to_string()).join(","), content="1,0,0,1,0,0,1")
  let f3 = poly([poly([coef(1), coef(2)]), poly([coef(3), coef(4)])])
  let infl2 = dmp_inflate(f3, [2, 3], 1, Domain::ZZ)
  inspect(dense_repr(infl2), content="[[1,0,0,2],[],[3,0,0,4]]")
}

///|
test "densebasic: dmp_true_LT sympy cases" {
  let lt0 = dmp_true_LT(poly([poly([])]), 1)
  inspect(lt0.0, content="[0, 0]")
  inspect(lt0.1, content="0")
  let lt1 = dmp_true_LT(poly([poly([coef(7)])]), 1)
  inspect(lt1.0, content="[0, 0]")
  inspect(lt1.1, content="7")
  let lt2 = dmp_true_LT(poly([poly([coef(1), coef(0)])]), 1)
  inspect(lt2.0, content="[0, 1]")
  inspect(lt2.1, content="1")
  let lt3 = dmp_true_LT(poly([poly([coef(1)]), poly([])]), 1)
  inspect(lt3.0, content="[1, 0]")
  inspect(lt3.1, content="1")
  let lt4 = dmp_true_LT(poly([poly([coef(1), coef(0)]), poly([])]), 1)
  inspect(lt4.0, content="[1, 1]")
  inspect(lt4.1, content="1")
}

///|
test "densebasic: dup_reverse sympy cases" {
  let f1 = dup_reverse([fez(1), fez(2), fez(0), fez(3)])
  inspect(f1.map(c => c.to_string()).join(","), content="3,0,2,1")
  let f2 = dup_reverse([fez(1), fez(2), fez(3), fez(0)])
  inspect(f2.map(c => c.to_string()).join(","), content="3,2,1")
}

///|
test "densebasic: dmp_degree_in bad index" {
  let bad : Result[Int, PolyError] = try? dmp_degree_in(poly([coef(1)]), -1, 0)
  guard bad is Err(_) else { fail("expected error for negative index") }
}

///|
test "densebasic: dup_to_tuple/dmp_to_tuple copy" {
  let f : Array[FieldElem] = [fez(1), fez(2), fez(3)]
  let t = dup_to_tuple(f)
  t.set(0, fez(9))
  inspect(f[0], content="1")
  let g = poly([coef(1), coef(2)])
  let t2 = dmp_to_tuple(g, 0)
  match t2 {
    DensePoly::Poly(items) =>
      match items[0] {
        DensePoly::Coef(c) => inspect(c, content="1")
        _ => fail("unexpected dmp_to_tuple")
      }
    _ => fail("unexpected dmp_to_tuple")
  }
}

///|
test "densebasic: dup_from_sympy/dmp_from_sympy parity" {
  let f1 = [br_int(1), br_int(2)]
  let ours1 = dup_repr(dup_from_sympy(f1, Domain::ZZ))
  let oracle1 = @sympy.dup_from_sympy(f1, domain="ZZ")
  guard ours1 == oracle1 else { fail("dup_from_sympy ZZ mismatch") }

  let f2 = [br_rat(1, 2), br_int(3)]
  let ours2 = dup_repr(dup_from_sympy(f2, Domain::QQ))
  let oracle2 = @sympy.dup_from_sympy(f2, domain="QQ")
  guard ours2 == oracle2 else { fail("dup_from_sympy QQ mismatch") }

  let d1 = dense_rat_poly([
    dense_rat_poly([dense_rat_coef(br_int(1)), dense_rat_coef(br_int(2))]),
    dense_rat_poly([dense_rat_coef(br_int(0))]),
  ])
  let ours3 = dense_repr(dmp_from_sympy(d1, 1, Domain::ZZ))
  let oracle3 = @sympy.dmp_from_sympy(dense_data_of_rat(d1), 1, domain="ZZ")
  guard ours3 == oracle3 else { fail("dmp_from_sympy ZZ mismatch") }

  let d2 = dense_rat_poly([
    dense_rat_poly([dense_rat_coef(br_rat(1, 2)), dense_rat_coef(br_int(2))]),
  ])
  let ours4 = dense_repr(dmp_from_sympy(d2, 1, Domain::QQ))
  let oracle4 = @sympy.dmp_from_sympy(dense_data_of_rat(d2), 1, domain="QQ")
  guard ours4 == oracle4 else { fail("dmp_from_sympy QQ mismatch") }
}

///|
fn exclude_repr(res : (Array[Int], DensePoly, Int)) -> String {
  let (jlist, f, u) = res
  "(\{list_int_repr(jlist)},\{dense_repr(f)},\{u})"
}

///|
test "densebasic: dmp_exclude/include parity" {
  let f0 = poly([poly([poly([])])])
  let ours0 = exclude_repr(dmp_exclude(f0, 2, Domain::ZZ))
  let oracle0 = @sympy.dmp_exclude(dense_data_of(f0), 2, domain="ZZ")
  guard ours0 == oracle0 else { fail("dmp_exclude zero mismatch") }

  let f1 = poly([poly([poly([coef(7)])])])
  let ours1 = exclude_repr(dmp_exclude(f1, 2, Domain::ZZ))
  let oracle1 = @sympy.dmp_exclude(dense_data_of(f1), 2, domain="ZZ")
  guard ours1 == oracle1 else { fail("dmp_exclude const mismatch") }

  let f2 = poly([coef(1), coef(2), coef(3)])
  let ours2 = exclude_repr(dmp_exclude(f2, 0, Domain::ZZ))
  let oracle2 = @sympy.dmp_exclude(dense_data_of(f2), 0, domain="ZZ")
  guard ours2 == oracle2 else { fail("dmp_exclude u=0 mismatch") }

  let f3 = poly([poly([coef(1), coef(2), coef(3)])])
  let ours3 = exclude_repr(dmp_exclude(f3, 1, Domain::ZZ))
  let oracle3 = @sympy.dmp_exclude(dense_data_of(f3), 1, domain="ZZ")
  guard ours3 == oracle3 else { fail("dmp_exclude leading level mismatch") }

  let include_base = poly([coef(1), coef(2), coef(3)])
  let inc0 = dmp_include(include_base, [], 0, Domain::ZZ)
  inspect(dense_repr(inc0), content="[1,2,3]")
  let inc1 = dmp_include(include_base, [0], 0, Domain::ZZ)
  inspect(dense_repr(inc1), content="[[1,2,3]]")
  let inc2 = dmp_include(include_base, [1], 0, Domain::ZZ)
  inspect(dense_repr(inc2), content="[[1],[2],[3]]")
  let inc3 = dmp_include(include_base, [0, 1], 0, Domain::ZZ)
  inspect(dense_repr(inc3), content="[[[1,2,3]]]")
}

///|
test "densebasic: dmp_inject/dmp_eject roundtrip" {
  let b = PolyBuilder::new(["x", "y"], Domain::ZZ)
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let poly1 = b.from_expr(@symcore.int(1))
  let poly2 = b.from_expr(@symcore.int(2) * x + @symcore.int(3) * y + @symcore.int(4))
  let f = dpp_from_polys([poly1, poly2])
  let (inj, u2) = dmp_inject(f, 0, ["x", "y"], Domain::ZZ)
  inspect(u2, content="2")
  inspect(dense_repr(inj), content="[[[1]],[[2],[3,4]]]")
  let out = dmp_eject(inj, u2, ["x", "y"], Domain::ZZ)
  inspect(dpp_repr(out), content=dpp_repr(f))
}

///|
fn terms_gcd_repr(res : (Int, Array[FieldElem])) -> String {
  let (k, f) = res
  "(\{k},\{dup_repr(f)})"
}

///|
fn dmp_terms_gcd_repr(res : (Array[Int], DensePoly)) -> String {
  let (exps, f) = res
  "(\{tuple_int_repr(exps)},\{dense_repr(f)})"
}

///|
test "densebasic: terms_gcd parity" {
  let f1 : Array[FieldElem] = []
  let ours1 = terms_gcd_repr(dup_terms_gcd(f1, Domain::ZZ))
  let oracle1 = @sympy.dup_terms_gcd([])
  guard ours1 == oracle1 else { fail("dup_terms_gcd empty mismatch") }

  let f2 : Array[FieldElem] = [fez(1), fez(0), fez(1)]
  let ours2 = terms_gcd_repr(dup_terms_gcd(f2, Domain::ZZ))
  let oracle2 = @sympy.dup_terms_gcd([br_int(1), br_int(0), br_int(1)])
  guard ours2 == oracle2 else { fail("dup_terms_gcd mismatch") }

  let f3 = poly([poly([coef(1)]), poly([]), poly([coef(1)]), poly([])])
  let ours3 = dmp_terms_gcd_repr(dmp_terms_gcd(f3, 1, Domain::ZZ))
  let oracle3 = @sympy.dmp_terms_gcd(dense_data_of(f3), 1, domain="ZZ")
  guard ours3 == oracle3 else { fail("dmp_terms_gcd mismatch") }
}

///|
test "densebasic: dmp_list_terms parity" {
  let f0 = poly([poly([poly([])])])
  let ours0 = term_list_repr(dmp_list_terms(f0, 2, Domain::ZZ))
  let oracle0 = @sympy.dmp_list_terms(dense_data_of(f0), 2, domain="ZZ")
  guard ours0 == oracle0 else { fail("dmp_list_terms zero mismatch") }

  let f1 = poly([coef(1), coef(2), coef(4), coef(3), coef(5)])
  let ours1 = term_list_repr(dmp_list_terms(f1, 0, Domain::ZZ))
  let oracle1 = @sympy.dmp_list_terms(dense_data_of(f1), 0, domain="ZZ")
  guard ours1 == oracle1 else { fail("dmp_list_terms u=0 mismatch") }

  let f2 = poly([poly([coef(1)]), poly([coef(2), coef(4)]), poly([coef(3), coef(5), coef(0)])])
  let ours2 = term_list_repr(dmp_list_terms(f2, 1, Domain::ZZ))
  let oracle2 = @sympy.dmp_list_terms(dense_data_of(f2), 1, domain="ZZ")
  guard ours2 == oracle2 else { fail("dmp_list_terms u=1 mismatch") }

  let f3 = poly([poly([coef(2), coef(0), coef(0), coef(0)]), poly([coef(1), coef(0), coef(0), coef(0), coef(0), coef(0)])])
  let ours3 = term_list_repr(dmp_list_terms(f3, 1, Domain::ZZ, order=TermOrder::Lex))
  let oracle3 = @sympy.dmp_list_terms(dense_data_of(f3), 1, order="lex", domain="ZZ")
  guard ours3 == oracle3 else { fail("dmp_list_terms lex mismatch") }
}

///|
fn h_mul(a : FieldElem, b : FieldElem, _args : Array[FieldElem]) -> FieldElem {
  try! fe_mul(a, b)
}

///|
test "densebasic: apply_pairs" {
  let f = [fez(1), fez(2), fez(3)]
  let g = [fez(4), fez(5), fez(6)]
  let res = dup_apply_pairs(f, g, h_mul, [], Domain::ZZ)
  inspect(dup_repr(res), content="[4,10,18]")
  let f2 = poly([poly([coef(1), coef(2)]), poly([coef(3)])])
  let g2 = poly([poly([coef(4), coef(5)]), poly([coef(6)])])
  let res2 = dmp_apply_pairs(f2, g2, h_mul, [], 1, Domain::ZZ)
  inspect(dense_repr(res2), content="[[4,10],[18]]")
}

///|
test "densebasic: dup_slice/dmp_slice parity" {
  let f = [fez(1), fez(2), fez(3), fez(4)]
  let ours0 = dup_repr(dup_slice(f, 0, 2, Domain::ZZ))
  let oracle0 = @sympy.dup_slice([br_int(1), br_int(2), br_int(3), br_int(4)], 0, 2)
  guard ours0 == oracle0 else { fail("dup_slice mismatch") }

  let g = poly([poly([coef(1)]), poly([coef(2), coef(3)]), poly([coef(4)])])
  let ours1 = dense_repr(dmp_slice(g, 0, 2, 1, Domain::ZZ))
  let oracle1 = @sympy.dmp_slice(dense_data_of(g), 0, 2, 1, domain="ZZ")
  guard ours1 == oracle1 else { fail("dmp_slice mismatch") }

  let ours2 = dense_repr(dmp_slice_in(g, 1, 2, 1, 1, Domain::ZZ))
  let oracle2 = @sympy.dmp_slice_in(dense_data_of(g), 1, 2, 1, 1, domain="ZZ")
  guard ours2 == oracle2 else { fail("dmp_slice_in mismatch") }
}

///|
test "densebasic: dup_random range/degree" {
  let f0 = dup_random(0, -10, 10, Domain::ZZ)
  inspect(dup_degree(f0), content="0")
  for c in f0 {
    let r = try! fe_expect_rational(c)
    guard r.compare(br_int(-10)) >= 0 && r.compare(br_int(10)) <= 0 else {
      fail("dup_random bounds")
    }
  }
  let f1 = dup_random(2, -5, 5, Domain::ZZ)
  inspect(dup_degree(f1), content="2")
}
