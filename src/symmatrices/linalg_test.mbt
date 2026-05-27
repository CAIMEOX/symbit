///|
fn vecs_to_string(values : Array[Array[Expr]]) -> String {
  let rows : Array[String] = []
  for row in values {
    rows.push("[" + row.map(@symprint.pretty_string).join(", ") + "]")
  }
  "[" + rows.join(", ") + "]"
}

///|
fn expr_symbolically_equal(lhs : Expr, rhs : Expr) -> Bool {
  @symsimplify.simplify(lhs + @symcore.int(-1) * rhs) == @symcore.int(0)
}

///|
fn matrix_symbolically_equal(lhs : Matrix, rhs : Matrix) -> Bool {
  if lhs.shape() != rhs.shape() {
    return false
  }
  for i in 0..<lhs.rows {
    for j in 0..<lhs.cols {
      if !expr_symbolically_equal(lhs.data[i][j], rhs.data[i][j]) {
        return false
      }
    }
  }
  true
}

///|
fn exact_float_expr(num : Int, den : Int, prec? : Int = 90) -> Expr {
  let rat = @symnum.BigRational::from_ints(num, den) catch {
    _ => @symnum.BigRational::zero()
  }
  @symcore.Expr::Float(
    @symcore.Float::from_exact(rat, prec~) catch {
      _ => @symcore.Float::from_int(0, prec~)
    },
  )
}

///|
fn exact_complex_float_expr(
  real_num : Int,
  real_den : Int,
  imag_num : Int,
  imag_den : Int,
  prec? : Int = 90,
) -> Expr {
  let real = @symnum.BigRational::from_ints(real_num, real_den) catch {
    _ => @symnum.BigRational::zero()
  }
  let imag = @symnum.BigRational::from_ints(imag_num, imag_den) catch {
    _ => @symnum.BigRational::zero()
  }
  @symcore.Expr::ComplexFloat(
    @symcore.ComplexFloat::from_exact_parts(real, imag, prec~),
  )
}

///|
fn diag_dominant_matrix(size : Int) -> Matrix {
  let rows : Array[Array[Expr]] = []
  for i in 0..<size {
    let row : Array[Expr] = []
    for j in 0..<size {
      if i == j {
        row.push(@symcore.int(3 * size + i + 5))
      } else {
        row.push(@symcore.int((i + j) % 2 + 1))
      }
    }
    rows.push(row)
  }
  matrix(rows) catch {
    _ => abort("diag_dominant_matrix failed")
  }
}

///|
test "matrices determinant inverse and solve" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ])
  inspect(@symprint.pretty_string(a.det()), content="-2")
  inspect(a.inv().to_string(), content="Matrix([[-2, 1], [3/2, -1/2]])")
  let rhs = matrix([[@symcore.int(5)], [@symcore.int(11)]])
  inspect(a.solve(rhs).to_string(), content="Matrix([[1], [2]])")
}

///|
test "matrices rref rank rowspace columnspace nullspace" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(2), @symcore.int(3)],
    [@symcore.int(2), @symcore.int(4), @symcore.int(6)],
  ])
  let (rref, pivots) = a.rref()
  inspect(rref.to_string(), content="Matrix([[1, 2, 3], [0, 0, 0]])")
  debug_inspect(pivots, content="[0]")
  assert_true(a.rank() == 1)
  inspect(vecs_to_string(a.rowspace()), content="[[1, 2, 3]]")
  inspect(vecs_to_string(a.columnspace()), content="[[1, 2]]")
  inspect(vecs_to_string(a.nullspace()), content="[[-2, 1, 0], [-3, 0, 1]]")
}

///|
test "matrices lu and qr decomposition" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ])
  let (l, u, swaps) = a.lu()
  inspect(l.to_string(), content="Matrix([[1, 0], [3, 1]])")
  inspect(u.to_string(), content="Matrix([[1, 2], [0, -2]])")
  debug_inspect(swaps, content="[]")
  let (q, r) = a.qr()
  assert_true(q.shape() == (2, 2))
  assert_true(r.shape() == (2, 2))
  assert_true(eigen_matrix_equal(q * r, a))
  assert_true(eigen_matrix_equal(q.transpose() * q, eye(2)))
}

///|
test "matrices minors cofactors adjugate and echelon helpers" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(2), @symcore.int(3)],
    [@symcore.int(0), @symcore.int(4), @symcore.int(5)],
    [@symcore.int(1), @symcore.int(0), @symcore.int(6)],
  ])
  inspect(
    a.minor_submatrix(0, 1).to_string(),
    content="Matrix([[0, 5], [1, 6]])",
  )
  inspect(@symprint.pretty_string(a.minor(0, 1)), content="-5")
  inspect(@symprint.pretty_string(a.cofactor(0, 1)), content="5")
  inspect(
    a.adjugate().to_string(),
    content="Matrix([[24, -12, -2], [5, 3, -5], [-4, 2, 4]])",
  )
  let (echelon, pivots) = a.echelon_form_with_pivots()
  assert_true(echelon.is_echelon())
  debug_inspect(pivots, content="[0, 1, 2]")
}

///|
test "matrices triangular solves rref rhs cholesky and ldl" {
  let lower = matrix([
    [@symcore.int(1), @symcore.int(0)],
    [@symcore.int(2), @symcore.int(3)],
  ])
  let rhs = matrix([[@symcore.int(4)], [@symcore.int(11)]])
  inspect(
    lower.lower_triangular_solve(rhs).to_string(),
    content="Matrix([[4], [1]])",
  )
  let upper = matrix([
    [@symcore.int(2), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(3)],
  ])
  let rhs2 = matrix([[@symcore.int(5)], [@symcore.int(6)]])
  inspect(
    upper.upper_triangular_solve(rhs2).to_string(),
    content="Matrix([[3/2], [2]])",
  )
  let coeff = matrix([
    [@symcore.int(1), @symcore.int(1)],
    [@symcore.int(2), @symcore.int(1)],
  ])
  let vars = matrix([
    [@symcore.Expr::Symbol("r1")],
    [@symcore.Expr::Symbol("r2")],
  ])
  let (rref_lhs, rref_rhs) = coeff.rref_rhs(vars)
  inspect(rref_lhs.to_string(), content="Matrix([[1, 0], [0, 1]])")
  assert_true(
    matrix_symbolically_equal(
      rref_rhs,
      matrix([
        [
          @symcore.int(-1) * @symcore.Expr::Symbol("r1") +
          @symcore.Expr::Symbol("r2"),
        ],
        [
          @symcore.int(-1) *
          (
            @symcore.int(-2) * @symcore.Expr::Symbol("r1") +
            @symcore.Expr::Symbol("r2")
          ),
        ],
      ]),
    ),
  )
  let spd = matrix([
    [@symcore.int(4), @symcore.int(2)],
    [@symcore.int(2), @symcore.int(3)],
  ])
  debug_inspect(spd.cholesky().shape(), content="(2, 2)")
  let (l, d) = spd.ldl()
  assert_true(l.shape() == (2, 2))
  assert_true(d.shape() == (2, 2))
}

///|
test "matrices numeric backend keeps float and complex-float results" {
  let half = exact_float_expr(1, 2)
  let two = exact_float_expr(2, 1)
  let zero = exact_float_expr(0, 1)
  let a = matrix([[half, zero], [zero, two]])
  let inv = a.inv()
  match (inv.getitem(0, 0), inv.getitem(1, 1)) {
    (@symcore.Expr::Float(f0), @symcore.Expr::Float(f1)) => {
      assert_true(f0.format(dps=12).has_prefix("2.0"))
      assert_true(f1.format(dps=12).has_prefix("0.5"))
    }
    _ => fail("expected float inverse entries")
  }
  let (rref, pivots) = a.rref()
  debug_inspect(pivots, content="[0, 1]")
  match rref.getitem(0, 0) {
    @symcore.Expr::Float(f) => assert_true(f.format(dps=8).has_prefix("1.0"))
    _ => fail("expected float rref pivot")
  }

  let i = exact_complex_float_expr(0, 1, 1, 1)
  let one = exact_float_expr(1, 1)
  let rhs = matrix([[one], [one]])
  let cm = matrix([[one, i], [one, exact_float_expr(-1, 1)]])
  let sol = cm.solve(rhs)
  match sol.getitem(0, 0) {
    @symcore.Expr::ComplexFloat(z) => assert_true(z.is_finite())
    @symcore.Expr::Float(f) => assert_true(f.is_finite())
    _ => fail("expected numeric complex solution")
  }

  let spd = matrix([
    [exact_float_expr(4, 1), exact_float_expr(1, 1)],
    [exact_float_expr(1, 1), exact_float_expr(3, 1)],
  ])
  let chol = spd.cholesky()
  match chol.getitem(0, 0) {
    @symcore.Expr::Float(f) => assert_true(f.format(dps=8).has_prefix("2.0"))
    _ => fail("expected float cholesky diagonal")
  }
}

///|
test "matrices exact rational fast path preserves benchmark family results" {
  let a = diag_dominant_matrix(4)
  inspect(@symprint.pretty_string(a.det()), content="110702")
  let inv = a.inv()
  inspect(
    inv.to_string(),
    content="Matrix([[6677/110702, -342/55351, -215/110702, -306/55351], [-342/55351, 3152/55351, -304/55351, -93/55351], [-215/110702, -304/55351, 5959/110702, -272/55351], [-306/55351, -93/55351, -272/55351, 2830/55351]])",
  )
  let rhs = matrix([
    [@symcore.int(1)],
    [@symcore.int(2)],
    [@symcore.int(3)],
    [@symcore.int(4)],
  ])
  inspect(
    a.solve(rhs).to_string(),
    content="Matrix([[1108/55351], [4678/55351], [7135/55351], [10012/55351]])",
  )
}
