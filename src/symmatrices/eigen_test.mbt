///|
fn eigenvals_text(items : Array[EigenValueMult]) -> String {
  "[" +
  items
  .map(fn(item) {
    "(" + @symprint.pretty_string(item.0) + ", " + item.1.to_string() + ")"
  })
  .join(", ") +
  "]"
}

///|
fn eigenvects_text(items : Array[EigenVectData]) -> String {
  "[" +
  items
  .map(fn(item) {
    "(" +
    @symprint.pretty_string(item.0) +
    ", " +
    item.1.to_string() +
    ", " +
    vecs_to_string(item.2) +
    ")"
  })
  .join(", ") +
  "]"
}

///|
fn eigen_expr_equal(lhs : Expr, rhs : Expr) -> Bool {
  let diff = @symsimplify.simplify(lhs + @symcore.int(-1) * rhs)
  if diff == @symcore.int(0) {
    return true
  }
  if !@symcore.free_symbols(diff).is_empty() {
    return false
  }
  match @symcore.evalf(diff, prec=120) {
    Number(value) => value == @symnum.BigRational::zero()
    Float(value) =>
      (value.to_double() catch { _ => return false }).abs() <= 1.0e-12
    ComplexFloat(value) =>
      (value.real_part().to_double() catch { _ => return false }).abs() <=
      1.0e-12 &&
      (value.imag_part().to_double() catch { _ => return false }).abs() <=
      1.0e-12
    _ => false
  }
}

///|
fn eigen_matrix_equal(lhs : Matrix, rhs : Matrix) -> Bool {
  if lhs.shape() != rhs.shape() {
    return false
  }
  for i in 0..<lhs.rows {
    for j in 0..<lhs.cols {
      if !eigen_expr_equal(lhs.data[i][j], rhs.data[i][j]) {
        return false
      }
    }
  }
  true
}

///|
test "matrices charpoly and eigenvals" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ])
  assert_true(
    eigen_expr_equal(
      a.charpoly(),
      (Symbol("lambda") ^ @symcore.int(2)) +
      @symcore.int(-5) * Symbol("lambda") +
      @symcore.int(-2),
    ),
  )
  let eigenvals = a.eigenvals()
  assert_true(eigenvals.length() == 2)
  assert_true(
    eigenvals[0].1 == 1 &&
    eigen_expr_equal(
      eigenvals[0].0,
      @symcore.rational_from_ints(1, 2) *
      (
        @symcore.int(-1) * @symcore.function("sqrt", [@symcore.int(33)]) +
        @symcore.int(5)
      ),
    ),
  )
  assert_true(
    eigenvals[1].1 == 1 &&
    eigen_expr_equal(
      eigenvals[1].0,
      @symcore.rational_from_ints(1, 2) *
      (@symcore.function("sqrt", [@symcore.int(33)]) + @symcore.int(5)),
    ),
  )
}

///|
test "matrices charpoly preserves dense diagonally dominant benchmark family" {
  let a = diag_dominant_matrix(4)
  assert_true(
    eigen_expr_equal(
      a.charpoly(x=Symbol("x")),
      @symcore.add([
        @symcore.pow(Symbol("x"), @symcore.int(4)),
        @symcore.mul([
          @symcore.int(-74),
          @symcore.pow(Symbol("x"), @symcore.int(3)),
        ]),
        @symcore.mul([
          @symcore.int(2033),
          @symcore.pow(Symbol("x"), @symcore.int(2)),
        ]),
        @symcore.mul([@symcore.int(-24600), Symbol("x")]),
        @symcore.int(110702),
      ]),
    ),
  )
}

///|
test "matrices eigenvects diagonalizable and diagonalize" {
  let a = matrix([
    [@symcore.int(2), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(3)],
  ])
  inspect(
    eigenvects_text(a.eigenvects()),
    content="[(2, 1, [[1, 0]]), (3, 1, [[0, 1]])]",
  )
  assert_true(a.is_diagonalizable())
  let (p, d) = a.diagonalize()
  inspect(Show::to_string(p), content="Matrix([[1, 0], [0, 1]])")
  inspect(Show::to_string(d), content="Matrix([[2, 0], [0, 3]])")
}

///|
test "matrices eigen triangular repeated roots" {
  let a = matrix([
    [@symcore.int(4), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(4)],
  ])
  inspect(eigenvals_text(a.eigenvals()), content="[(4, 2)]")
  assert_false(a.is_diagonalizable())
}

///|
test "matrices jordan cells and jordan form" {
  let defective = matrix([
    [@symcore.int(4), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(4)],
  ])
  let cells = defective.jordan_cells()
  assert_true(cells.length() == 1)
  inspect(Show::to_string(cells[0]), content="Matrix([[4, 1], [0, 4]])")
  let (p, j) = defective.jordan_form()
  inspect(Show::to_string(j), content="Matrix([[4, 1], [0, 4]])")
  inspect(Show::to_string(defective * p), content=Show::to_string(p * j))
  let diagonal = matrix([
    [@symcore.int(2), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(3)],
  ])
  let (_, jd) = diagonal.jordan_form(calc_transform=false)
  inspect(Show::to_string(jd), content="Matrix([[2, 0], [0, 3]])")
}

///|
test "matrices jordan form handles longer generalized eigenvector chains" {
  let upper = matrix([
    [@symcore.int(5), @symcore.int(1), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(5), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(5)],
  ])
  let cells = upper.jordan_cells()
  assert_true(cells.length() == 1)
  inspect(
    Show::to_string(cells[0]),
    content="Matrix([[5, 1, 0], [0, 5, 1], [0, 0, 5]])",
  )
  let (p, j) = upper.jordan_form()
  inspect(
    Show::to_string(j),
    content="Matrix([[5, 1, 0], [0, 5, 1], [0, 0, 5]])",
  )
  inspect(Show::to_string(upper * p), content=Show::to_string(p * j))
}

///|
test "matrices jordan form handles mixed Jordan block sizes" {
  let mixed = matrix([
    [@symcore.int(5), @symcore.int(1), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(5), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(5)],
  ])
  let cells = mixed.jordan_cells()
  inspect(
    "[" + cells.map(fn(item) { Show::to_string(item) }).join(", ") + "]",
    content="[Matrix([[5, 1], [0, 5]]), Matrix([[5]])]",
  )
  let (p, j) = mixed.jordan_form()
  inspect(
    Show::to_string(j),
    content="Matrix([[5, 1, 0], [0, 5, 0], [0, 0, 5]])",
  )
  inspect(Show::to_string(mixed * p), content=Show::to_string(p * j))
}

///|
test "matrices eigenvals and eigenvects support general non-triangular 3x3" {
  let companion = matrix([
    [@symcore.int(0), @symcore.int(0), @symcore.int(6)],
    [@symcore.int(1), @symcore.int(0), @symcore.int(-11)],
    [@symcore.int(0), @symcore.int(1), @symcore.int(6)],
  ])
  inspect(
    eigenvals_text(companion.eigenvals()),
    content="[(1, 1), (2, 1), (3, 1)]",
  )
  inspect(
    eigenvects_text(companion.eigenvects()),
    content="[(1, 1, [[6, -5, 1]]), (2, 1, [[3, -4, 1]]), (3, 1, [[2, -3, 1]])]",
  )
  assert_true(companion.is_diagonalizable())
}

///|
test "matrices diagonalize supports general non-triangular 4x4 companion" {
  let companion = matrix([
    [@symcore.int(0), @symcore.int(0), @symcore.int(0), @symcore.int(-24)],
    [@symcore.int(1), @symcore.int(0), @symcore.int(0), @symcore.int(50)],
    [@symcore.int(0), @symcore.int(1), @symcore.int(0), @symcore.int(-35)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(1), @symcore.int(10)],
  ])
  inspect(
    eigenvals_text(companion.eigenvals()),
    content="[(1, 1), (2, 1), (3, 1), (4, 1)]",
  )
  let (p, d) = companion.diagonalize()
  inspect(
    Show::to_string(d),
    content="Matrix([[1, 0, 0, 0], [0, 2, 0, 0], [0, 0, 3, 0], [0, 0, 0, 4]])",
  )
  inspect(Show::to_string(companion * p), content=Show::to_string(p * d))
}

///|
test "matrices exact eigen path supports general non-companion algebraic 3x3" {
  let algebraic = matrix([
    [@symcore.int(1), @symcore.int(1), @symcore.int(0)],
    [@symcore.int(1), @symcore.int(1), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(1), @symcore.int(1)],
  ])
  let eigenvals = algebraic.eigenvals()
  assert_true(eigenvals.length() == 3)
  assert_true(
    eigenvals[0].1 == 1 && eigen_expr_equal(eigenvals[0].0, @symcore.int(1)),
  )
  assert_true(
    eigenvals[1].1 == 1 &&
    eigen_expr_equal(
      eigenvals[1].0,
      @symcore.int(1) - @symcore.function("sqrt", [@symcore.int(2)]),
    ),
  )
  assert_true(
    eigenvals[2].1 == 1 &&
    eigen_expr_equal(
      eigenvals[2].0,
      @symcore.int(1) + @symcore.function("sqrt", [@symcore.int(2)]),
    ),
  )
  let (p, d) = algebraic.diagonalize()
  assert_true(eigen_matrix_equal(algebraic * p, p * d))
}

///|
test "matrices jordan form supports defective non-triangular 3x3 after exact eigen solve" {
  let transformed = matrix([
    [@symcore.int(5), @symcore.int(1), @symcore.int(0)],
    [
      @symcore.rational_from_ints(-1, 2),
      @symcore.rational_from_ints(11, 2),
      @symcore.rational_from_ints(1, 2),
    ],
    [
      @symcore.rational_from_ints(1, 2),
      @symcore.rational_from_ints(1, 2),
      @symcore.rational_from_ints(9, 2),
    ],
  ])
  let (p, j) = transformed.jordan_form()
  inspect(
    Show::to_string(j),
    content="Matrix([[5, 1, 0], [0, 5, 1], [0, 0, 5]])",
  )
  inspect(Show::to_string(transformed * p), content=Show::to_string(p * j))
}
