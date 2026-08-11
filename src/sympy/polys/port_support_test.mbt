///|
using @sympolys {
  type DDM,
  type DensePoly,
  type DensePolyPoly,
  type DenseRat,
  type Domain,
  type DomainExprTree,
  type DomainMatrix,
  type DomainMatrixAlgebraicEigenvects,
  type DomainMatrixDOD,
  type DomainMatrixDOK,
  type DomainMatrixRationalEigenvects,
  type DomainMatrixRep,
  type DomainScalar,
  type FieldElem,
  type LinearSolveResult,
  type Matrix,
  type MatrixExpr,
  type Monomial,
  type Poly,
  type PolyBuilder,
  type PolyError,
  type SDM,
  type SymmetrizeListResult,
  type SymmetrizeResult,
  type SympyEigenvects,
  type TermOrder,
}

///|
fn[T] expect_poly_error(action : () -> T raise PolyError) -> PolyError raise {
  try action() catch {
    error => error
  } noraise {
    _ => fail("expected PolyError to be raised")
  }
}

///|
fn expr_sym(name : String) -> @symcore.Expr {
  @symcore.Expr::Symbol(name)
}

///|
fn expr_int(n : Int) -> @symcore.Expr {
  @symcore.int(n)
}

///|
fn expr_rat(n : Int, d : Int) -> @symcore.Expr raise {
  @symcore.Expr::Number(
    @symnum.BigRational::from_ints(n, d) catch {
      _ => raise PolyError::DivisionByZero
    },
  )
}

///|
fn sort_factor_repr(repr_str : String) -> String raise {
  sympy_sort_factor_repr(repr_str)
}

///|
fn poly_canon_str(p : Poly) -> String raise {
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
      let rendered = try monic(p.to_expr()) catch {
        _ => p.to_string()
      } noraise {
        s => s
      }
      arr.push(rendered)
    }
    arr
  }
  parts.sort()
  parts.join(" | ")
}

///|
fn poly_list_to_string(polys : Array[Poly]) -> String raise {
  polys.map(p => poly_canon_str(p)).join(" | ")
}

///|
fn reduced_pair_to_string(qs : Array[Poly], rem : Poly) -> String raise {
  "\{poly_list_to_string(qs)}||\{poly_canon_str(rem)}"
}

///|
fn div_pair_to_string(quo : Poly, rem : Poly) -> String raise {
  "\{poly_canon_str(quo)}||\{poly_canon_str(rem)}"
}

///|
fn fe_to_string(value : FieldElem) -> String {
  value.to_string()
}
