///|
fn eigenvals_text(items : Array[EigenValueMult]) -> String {
  "[" +
  items
  .map(fn(item) {
    "(" + @symprint.to_string(item.0) + ", " + item.1.to_string() + ")"
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
    @symprint.to_string(item.0) +
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
test "matrices charpoly and eigenvals" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ])
  inspect(
    @symprint.to_string(a.charpoly()),
    content="lambda**2 + -5*lambda + -2",
  )
  inspect(
    eigenvals_text(a.eigenvals()),
    content="[(1/2*(-1*sqrt(33) + 5), 1), (1/2*(sqrt(33) + 5), 1)]",
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
  inspect(p.to_string(), content="Matrix([[1, 0], [0, 1]])")
  inspect(d.to_string(), content="Matrix([[2, 0], [0, 3]])")
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
  assert_eq(cells.length(), 1)
  inspect(cells[0].to_string(), content="Matrix([[4, 1], [0, 4]])")
  let (p, j) = defective.jordan_form()
  inspect(j.to_string(), content="Matrix([[4, 1], [0, 4]])")
  inspect((defective * p).to_string(), content=(p * j).to_string())
  let diagonal = matrix([
    [@symcore.int(2), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(3)],
  ])
  let (_, jd) = diagonal.jordan_form(calc_transform=false)
  inspect(jd.to_string(), content="Matrix([[2, 0], [0, 3]])")
}

///|
test "matrices jordan form handles longer generalized eigenvector chains" {
  let upper = matrix([
    [@symcore.int(5), @symcore.int(1), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(5), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(5)],
  ])
  let cells = upper.jordan_cells()
  assert_eq(cells.length(), 1)
  inspect(
    cells[0].to_string(),
    content="Matrix([[5, 1, 0], [0, 5, 1], [0, 0, 5]])",
  )
  let (p, j) = upper.jordan_form()
  inspect(j.to_string(), content="Matrix([[5, 1, 0], [0, 5, 1], [0, 0, 5]])")
  inspect((upper * p).to_string(), content=(p * j).to_string())
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
    "[" + cells.map(fn(item) { item.to_string() }).join(", ") + "]",
    content="[Matrix([[5, 1], [0, 5]]), Matrix([[5]])]",
  )
  let (p, j) = mixed.jordan_form()
  inspect(j.to_string(), content="Matrix([[5, 1, 0], [0, 5, 0], [0, 0, 5]])")
  inspect((mixed * p).to_string(), content=(p * j).to_string())
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
    d.to_string(),
    content="Matrix([[1, 0, 0, 0], [0, 2, 0, 0], [0, 0, 3, 0], [0, 0, 0, 4]])",
  )
  inspect((companion * p).to_string(), content=(p * d).to_string())
}

///|
test "matrices exact eigen path supports general non-companion algebraic 3x3" {
  let algebraic = matrix([
    [@symcore.int(1), @symcore.int(1), @symcore.int(0)],
    [@symcore.int(1), @symcore.int(1), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(1), @symcore.int(1)],
  ])
  inspect(
    eigenvals_text(algebraic.eigenvals()),
    content="[(1, 1), (1/2*(-1*8**(1/2) + 2), 1), (1/2*(8**(1/2) + 2), 1)]",
  )
  let (p, d) = algebraic.diagonalize()
  inspect(
    p.to_string(),
    content="Matrix([[-1, 1, 1], [0, 1/2*(-1*8**(1/2) + 2) + -1, 1/2*(8**(1/2) + 2) + -1], [1, 1, 1]])",
  )
  inspect(
    d.to_string(),
    content="Matrix([[1, 0, 0], [0, 1/2*(-1*8**(1/2) + 2), 0], [0, 0, 1/2*(8**(1/2) + 2)]])",
  )
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
  inspect(j.to_string(), content="Matrix([[5, 1, 0], [0, 5, 1], [0, 0, 5]])")
  inspect((transformed * p).to_string(), content=(p * j).to_string())
}
