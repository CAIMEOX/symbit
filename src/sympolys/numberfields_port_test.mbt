///|
fn nf_norm(expr : @symcore.Expr) -> String {
  (try! @sympy_polys.sympy_normalize(@symprint.to_string(expr)).trim().to_string())
    .replace_all(old=" ", new="")
}

///|
test "numberfields: minpoly parity for rationals and radicals" {
  let q = try! @symcore.rational_from_ints(3, 2)
  let q_mp = minpoly(q, gen="x")
  let q_ours = nf_norm(q_mp.to_expr())
  let q_oracle = try! @sympy_polys.sympy_normalize(
    @sympy_polys.numberfield_minpoly("3/2", gen="x"),
  )
    .trim()
    .to_string()
    .replace_all(old=" ", new="")
  guard q_ours == q_oracle else {
    fail("minpoly(3/2) mismatch: ours=\{q_ours}, oracle=\{q_oracle}")
  }

  let half = try! @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let s_mp = minpoly(sqrt2, gen="x")
  let s_ours = nf_norm(s_mp.to_expr())
  let s_oracle = try! @sympy_polys.sympy_normalize(
    @sympy_polys.numberfield_minpoly("sqrt(2)", gen="x"),
  )
    .trim()
    .to_string()
    .replace_all(old=" ", new="")
  guard s_ours == s_oracle else {
    fail("minpoly(sqrt(2)) mismatch: ours=\{s_ours}, oracle=\{s_oracle}")
  }
}

///|
test "numberfields: to_number_field and primitive_element basics" {
  let half = try! @symcore.rational_from_ints(1, 2)
  let sqrt2 = @symcore.int(2) ^ half
  let k = to_number_field(sqrt2, gen="a")
  match k {
    Domain::AlgExt(base, gens, rels) => {
      guard base is Domain::QQ && gens.equal(["a"]) && rels.length() == 1 else {
        fail("unexpected number field descriptor")
      }
      let rel = nf_norm(rels[0])
      guard rel == "a**2-2" else {
        fail("unexpected defining relation: \{rel}")
      }
    }
    _ => fail("expected algebraic extension domain")
  }

  let (prim, coeffs) = primitive_element([sqrt2])
  guard prim == sqrt2 && coeffs == [1] else {
    fail("primitive element fallback mismatch")
  }
}
