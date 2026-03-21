///|
pub type DomainMatrixRationalEigenvects = Array[
  (Domain, FieldElem, Int, DomainMatrix),
]

///|
pub type DomainMatrixAlgebraicEigenvects = Array[
  (Domain, Poly, Int, DomainMatrix),
]

///|
fn algext_generator_elem(
  base : Domain,
  minpoly : Poly,
  gen : String,
) -> FieldElem raise PolyError {
  FieldElem::AlgExt(
    base,
    [fe_from_int(0, base), fe_from_int(1, base)],
    minpoly,
    gen,
  )
}

///|
fn diagonal_matrix_with_value(
  size : Int,
  domain : Domain,
  value : FieldElem,
) -> DomainMatrix raise PolyError {
  DomainMatrix::eye(size, domain).scalarmul(value)
}

///|
pub fn DomainMatrix::dom_eigenvects(
  self : DomainMatrix,
  gen? : String = "_lambda",
) -> (DomainMatrixRationalEigenvects, DomainMatrixAlgebraicEigenvects) raise PolyError {
  if self.rows != self.cols {
    raise PolyError::DomainMismatch
  }
  if !domain_is_field_pred(self.domain) {
    raise PolyError::DomainNotField
  }

  let rational : DomainMatrixRationalEigenvects = Array::new()
  let algebraic : DomainMatrixAlgebraicEigenvects = Array::new()
  for factor in self.charpoly_factor_list() {
    let coeffs = factor.0
    let multiplicity = factor.1
    if coeffs.length() == 2 {
      let eigenval = fe_mul(fe_neg(coeffs[1]), fe_inv(coeffs[0]))
      let basis = self
        .sub(diagonal_matrix_with_value(self.rows, self.domain, eigenval))
        .nullspace(divide_last=true)
      rational.push((self.domain, eigenval, multiplicity, basis))
    } else {
      let minpoly = poly_from_dense_desc(coeffs, gen, self.domain)
      let field = build_alg_extension(alg_ext_spec(self.domain, gen, minpoly))
      let aa = self.convert_to(field)
      let eigenval = algext_generator_elem(self.domain, minpoly, gen)
      let basis = aa
        .sub(diagonal_matrix_with_value(self.rows, field, eigenval))
        .nullspace(divide_last=true)
      algebraic.push((field, minpoly, multiplicity, basis))
    }
  }
  (rational, algebraic)
}

///|
pub fn DDM::dom_eigenvects(
  self : DDM,
  gen? : String = "_lambda",
) -> (Array[(Domain, FieldElem, Int, DDM)], Array[(Domain, Poly, Int, DDM)]) raise PolyError {
  let (rational, algebraic) = self.to_domain_matrix().dom_eigenvects(gen~)
  let rational_out : Array[(Domain, FieldElem, Int, DDM)] = Array::new()
  for item in rational {
    rational_out.push((item.0, item.1, item.2, item.3.to_ddm()))
  }
  let algebraic_out : Array[(Domain, Poly, Int, DDM)] = Array::new()
  for item in algebraic {
    algebraic_out.push((item.0, item.1, item.2, item.3.to_ddm()))
  }
  (rational_out, algebraic_out)
}

///|
test "eigen_compat: algebraic eigenvectors over QQ extension" {
  let dm = domain_matrix_from_ints([[0, 2], [1, 0]], Domain::QQ)
  let (rational, algebraic) = dm.dom_eigenvects()
  guard rational.is_empty() else { fail("expected no rational eigenvectors") }
  guard algebraic.length() == 1 else {
    fail("expected one irreducible algebraic factor")
  }
  let item = algebraic[0]
  guard item.1.to_string() == "_lambda**2 + -2" else {
    fail("unexpected minimal polynomial: \{item.1}")
  }
  guard item.3.to_matrix_string() == "Matrix([[_lambda, 1]])" else {
    fail("unexpected algebraic eigenbasis: \{item.3.to_matrix_string()}")
  }
}

///|
test "eigen_compat: shifted algebraic matrix rref over QQ extension" {
  let x = symbol("_lambda")
  let minpoly = PolyBuilder::new(["_lambda"], Domain::QQ).from_expr(
    (x ^ int(2)) - int(2),
  )
  let field = build_alg_extension(alg_ext_spec(Domain::QQ, "_lambda", minpoly))
  let eigenval = algext_generator_elem(Domain::QQ, minpoly, "_lambda")
  guard fe_is_one(fe_mul(fe_neg(eigenval), fe_inv(fe_neg(eigenval)))) else {
    fail("expected algebraic inverse to normalize")
  }
  let shifted = domain_matrix_from_ints([[0, 2], [1, 0]], Domain::QQ)
    .convert_to(field)
    .sub(diagonal_matrix_with_value(2, field, eigenval))
  guard shifted.to_matrix_string() ==
    "Matrix([[-1*_lambda, 2], [1, -1*_lambda]])" else {
    fail("unexpected shifted algebraic matrix: \{shifted.to_matrix_string()}")
  }
  let dense = shifted.to_dense()
  let pivot = dense[0][0]
  let pivot_text = fe_to_string(pivot)
  let inv = fe_inv(pivot)
  guard fe_to_string(pivot) == pivot_text else {
    fail("algebraic inversion should not mutate the source element")
  }
  let pivot_prod = fe_mul(pivot, inv)
  guard fe_is_one(pivot_prod) else {
    fail(
      "unexpected pivot inverse product: pivot=\{fe_to_string(pivot)}, inv=\{fe_to_string(inv)}, prod=\{fe_to_string(pivot_prod)}",
    )
  }
  let row0_col1 = fe_mul(dense[0][1], inv)
  guard fe_to_string(row0_col1) == "-1*_lambda" else {
    fail("unexpected scaled pivot row entry: \{fe_to_string(row0_col1)}")
  }
  let factor = dense[1][0]
  let elim = fe_sub(dense[1][1], fe_mul(factor, row0_col1))
  guard fe_is_zero(elim) else {
    fail("unexpected elimination residue: \{fe_to_string(elim)}")
  }
  let (rref, pivots) = shifted.rref()
  guard pivots == [0] else {
    fail("unexpected algebraic pivots: \{pivots.to_string()}")
  }
  guard rref.to_matrix_string() == "Matrix([[1, -1*_lambda], [0, 0]])" else {
    fail("unexpected algebraic rref: \{rref.to_matrix_string()}")
  }
}
