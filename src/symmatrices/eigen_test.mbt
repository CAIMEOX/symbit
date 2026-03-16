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
  let a = try! matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ])
  inspect(
    @symprint.to_string(try! a.charpoly()),
    content="lambda**2 + -5*lambda + -2",
  )
  inspect(
    eigenvals_text(try! a.eigenvals()),
    content="[(1/2*(-1*sqrt(33) + 5), 1), (1/2*(sqrt(33) + 5), 1)]",
  )
}

///|
test "matrices eigenvects diagonalizable and diagonalize" {
  let a = try! matrix([
    [@symcore.int(2), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(3)],
  ])
  inspect(
    eigenvects_text(try! a.eigenvects()),
    content="[(2, 1, [[1, 0]]), (3, 1, [[0, 1]])]",
  )
  assert_true(a.is_diagonalizable())
  let (p, d) = try! a.diagonalize()
  inspect(p.to_string(), content="Matrix([[1, 0], [0, 1]])")
  inspect(d.to_string(), content="Matrix([[2, 0], [0, 3]])")
}

///|
test "matrices eigen triangular repeated roots" {
  let a = try! matrix([
    [@symcore.int(4), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(4)],
  ])
  inspect(eigenvals_text(try! a.eigenvals()), content="[(4, 2)]")
  assert_false(a.is_diagonalizable())
}

///|
test "matrices jordan cells and jordan form" {
  let defective = try! matrix([
    [@symcore.int(4), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(4)],
  ])
  let cells = try! defective.jordan_cells()
  assert_eq(cells.length(), 1)
  inspect(cells[0].to_string(), content="Matrix([[4, 1], [0, 4]])")
  let (p, j) = try! defective.jordan_form()
  inspect(j.to_string(), content="Matrix([[4, 1], [0, 4]])")
  inspect((defective * p).to_string(), content=(p * j).to_string())
  let diagonal = try! matrix([
    [@symcore.int(2), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(3)],
  ])
  let (_, jd) = try! diagonal.jordan_form(calc_transform=false)
  inspect(jd.to_string(), content="Matrix([[2, 0], [0, 3]])")
}

///|
test "matrices jordan form handles longer generalized eigenvector chains" {
  let upper = try! matrix([
    [@symcore.int(5), @symcore.int(1), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(5), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(5)],
  ])
  let cells = try! upper.jordan_cells()
  assert_eq(cells.length(), 1)
  inspect(
    cells[0].to_string(),
    content="Matrix([[5, 1, 0], [0, 5, 1], [0, 0, 5]])",
  )
  let (p, j) = try! upper.jordan_form()
  inspect(j.to_string(), content="Matrix([[5, 1, 0], [0, 5, 1], [0, 0, 5]])")
  inspect((upper * p).to_string(), content=(p * j).to_string())
}

///|
test "matrices jordan form handles mixed Jordan block sizes" {
  let mixed = try! matrix([
    [@symcore.int(5), @symcore.int(1), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(5), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(5)],
  ])
  let cells = try! mixed.jordan_cells()
  inspect(
    "[" + cells.map(fn(item) { item.to_string() }).join(", ") + "]",
    content="[Matrix([[5, 1], [0, 5]]), Matrix([[5]])]",
  )
  let (p, j) = try! mixed.jordan_form()
  inspect(j.to_string(), content="Matrix([[5, 1, 0], [0, 5, 0], [0, 0, 5]])")
  inspect((mixed * p).to_string(), content=(p * j).to_string())
}
