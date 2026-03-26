///|
fn matrix_array_text(mats : Array[Matrix]) -> String {
  "[" + mats.map(fn(m) { m.to_string() }).join(", ") + "]"
}

///|
test "matrices special jordan and rotations" {
  let lam = @symcore.Expr::Symbol("lam")
  inspect(
    jordan_cell(lam, 3).to_string(),
    content="Matrix([[lam, 1, 0], [0, lam, 1], [0, 0, lam]])",
  )
  let theta = @symcore.Expr::Symbol("theta")
  inspect(
    rot_axis3(theta).to_string(),
    content="Matrix([[cos(theta), sin(theta), 0], [-1*sin(theta), cos(theta), 0], [0, 0, 1]])",
  )
}

///|
test "matrices special gram schmidt" {
  let v1 = matrix([[@symcore.int(1)], [@symcore.int(1)]])
  let v2 = matrix([[@symcore.int(1)], [@symcore.int(0)]])
  let basis = gram_schmidt([v1, v2])
  inspect(
    matrix_array_text(basis),
    content="[Matrix([[1], [1]]), Matrix([[1/2], [-1/2]])]",
  )
}

///|
test "matrices special hessian wronskian and casoratian" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f = (x ^ @symcore.int(2)) + x * y + (y ^ @symcore.int(2))
  inspect(hessian(f, [x, y]).to_string(), content="Matrix([[2, 1], [1, 2]])")
  inspect(
    @symprint.to_string(wronskian([x, x ^ @symcore.int(2)], x)),
    content="x**2",
  )
  let n = @symcore.Expr::Symbol("n")
  inspect(@symprint.to_string(casoratian([@symcore.int(1), n], n)), content="1")
}
