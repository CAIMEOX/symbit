///|
fn expr_sym(name : String) -> @symcore.Expr {
  @symcore.symbol(name)
}

///|
fn expr_int(n : Int) -> @symcore.Expr {
  @symcore.int(n)
}

///|
fn expr_pow(base : @symcore.Expr, exp : Int) -> @symcore.Expr {
  @symcore.pow(base, @symcore.int(exp))
}

///|
fn expr_add(args : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.add(args)
}

///|
fn expr_mul(args : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.mul(args)
}

///|
///|
fn sympy_normalize(expr_str : String) -> String {
  try! @sympy.sympy_normalize(expr_str)
}

///|
fn canonical_cmp(s : String) -> String {
  @sympy.canonical_cmp(s)
}

///|
fn sort_factor_repr(repr_str : String) -> String {
  try! @sympy.sympy_sort_factor_repr(repr_str)
}

///|
fn expr_equal(lhs : String, rhs : String) -> Bool {
  try! @sympy.expr_equal(lhs, rhs)
}

///|
fn poly_canon_str(p : Poly) -> String {
  sympy_normalize(p.to_string())
}

///|
fn factor_list_to_string(
  content_str : String,
  factors : Array[(Poly, Int)],
) -> String {
  let c_norm = content_str
  let triples : Array[(Int, String, Int)] = Array::new()
  for pair in factors {
    let (f, m) = pair
    let s = f.to_string()
    if s == "1" || s == "-1" {
      continue
    }
    triples.push((f.degree(0), s, m))
  }
  // Sort by degree descending, then lexicographic string to stabilize order.
  for i in 0..<triples.length() {
    for j in (i + 1)..<triples.length() {
      let (di, si, mi) = triples[i]
      let (dj, sj, mj) = triples[j]
      if dj > di || (dj == di && sj.compare(si) < 0) {
        triples.set(i, (dj, sj, mj))
        triples.set(j, (di, si, mi))
      }
    }
  }
  let formatted = triples.map(t => {
    let (_, s, m) = t
    "(\{s}, \{m})"
  })
  let joined = formatted.join(",")
  "(\{c_norm}, [\{joined}])"
}

///|
fn groebner_to_string(basis : Array[Poly]) -> String {
  let parts : Array[String] = {
    let arr = Array::new()
    for p in basis {
      let monic_res : Result[String, Error] = try? @sympy_polys.monic(
        p.to_expr(),
      )
      match monic_res {
        Ok(s) => arr.push(s)
        Err(_) => arr.push(p.to_string())
      }
    }
    arr
  }
  parts.sort()
  parts.join(" | ")
}

///|
fn div_pair_to_string(quo : Poly, rem : Poly) -> String {
  "\{poly_canon_str(quo)}||\{poly_canon_str(rem)}"
}
