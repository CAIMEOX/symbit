///|
fn p5a5_rat(value : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_int(value)
}

///|
test "polys P5a5 structured polytools preserve shapes and shared identity" {
  let x = @symcore.Expr::Symbol("x")
  assert_eq(
    reduced(
      (x ^ @symcore.int(3)) - @symcore.int(1),
      [x - @symcore.int(1), x + @symcore.int(1)],
      gens=["x"],
    ),
    "x**2 + x + 1 | 0||0",
  )
  assert_eq(
    compose((x ^ @symcore.int(2)) + @symcore.int(1), x + @symcore.int(1), gens=[
      "x",
    ]),
    "x**2 + 2*x + 2",
  )
  assert_eq(
    decompose(((x ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(2)),
    "x**2 + 2*x + 1 | x**2",
  )
  assert_eq(
    sturm((x ^ @symcore.int(3)) - x, gens=["x"]),
    "x**3 - x | 3*x**2 - 1 | 2*x/3 | 1",
  )
  assert_eq(discriminant((x ^ @symcore.int(3)) - x, gens=["x"]), "4")
  assert_eq(
    subresultants(
      (x ^ @symcore.int(3)) - @symcore.int(1),
      (x ^ @symcore.int(2)) - @symcore.int(1),
      gens=["x"],
    ),
    "x**3 - 1 | x**2 - 1 | x - 1",
  )
  let dummy = @symcore.Expr::Dummy("d", 1901)
  assert_eq(reduced(dummy, [dummy]), "1||0")
}

///|
test "polys P5a5 interpolation preserves data collections and kwargs" {
  let points = [
    (p5a5_rat(1), p5a5_rat(1)),
    (p5a5_rat(2), p5a5_rat(4)),
    (p5a5_rat(3), p5a5_rat(9)),
  ]
  assert_eq(interpolate(points), "x**2")
  assert_eq(interpolate_values([p5a5_rat(1), p5a5_rat(4), p5a5_rat(9)]), "x**2")
  assert_eq(
    interpolate_dict([
      (p5a5_rat(1), p5a5_rat(2)),
      (p5a5_rat(1), p5a5_rat(3)),
      (p5a5_rat(2), p5a5_rat(5)),
    ]),
    "2*x + 1",
  )
  let rational_points = [
    (p5a5_rat(1), p5a5_rat(-210)),
    (p5a5_rat(2), p5a5_rat(-35)),
    (p5a5_rat(3), p5a5_rat(105)),
    (p5a5_rat(4), p5a5_rat(231)),
    (p5a5_rat(5), p5a5_rat(350)),
    (p5a5_rat(6), p5a5_rat(465)),
  ]
  assert_eq(
    rational_interpolate(rational_points, 2, x="y"),
    "105*y**2 - 525||y + 1",
  )
  assert_eq(
    rational_interpolate(rational_points, 2, x=""),
    "105*x**2 - 525||x + 1",
  )
}

///|
test "polys P5a5 symmetrize preserves formal and nonformal shapes" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expression = (x ^ @symcore.int(2)) + (y ^ @symcore.int(2))
  assert_eq(symmetrize(expression, gens=["x", "y"]), "-2*x*y + (x + y)**2||0")
  assert_eq(
    symmetrize(expression, gens=["x", "y"], formal=true, symbols=["u0", "u1"]),
    "u0**2 - 2*u1||0||[(u0, x + y), (u1, x*y)]",
  )
  assert_eq(
    symmetrize_list([x + y, x - y], gens=["x", "y"]),
    "[(x + y, 0), (x + y, -2*y)]",
  )
  assert_eq(
    symmetrize_list([x + y, x - y], gens=["x", "y"], formal=true, symbols=[
      "u0", "u1",
    ]),
    "[(u0, 0), (u0, -2*y)]||[(u0, x + y), (u1, x*y)]",
  )
  let dummy = @symcore.Expr::Dummy("d", 1902)
  assert_eq(symmetrize_list([dummy, dummy]), "[(_d, 0), (_d, 0)]")
}

///|
test "polys P5a5 horner and viete keep literal and positional contracts" {
  let x = @symcore.Expr::Symbol("x")
  assert_eq(
    horner(
      @symcore.int(2) * (x ^ @symcore.int(2)) +
      @symcore.int(3) * x +
      @symcore.int(1),
      gens=["x"],
    ),
    "x*(2*x + 3) + 1",
  )
  let polynomial = (x ^ @symcore.int(2)) + @symcore.int(3) * x + @symcore.int(2)
  assert_eq(viete(polynomial, gen="x"), "[(r1 + r2, -3), (r1*r2, 2)]")
  assert_eq(
    viete(polynomial, roots=["u", "v"], gen="x"),
    "[(u + v, -3), (u*v, 2)]",
  )
}

///|
test "polys P5a5 string Poly inspectors sympify strictly and keep gens literal" {
  let literal = "x y,z"
  assert_eq(poly_degree_list("1", gens=[literal]), [0])
  assert_eq(poly_lc("1", gens=[literal]), "1")
  assert_eq(poly_tc("1", gens=[literal]), "1")
  let hostile_expression = "Symbol('x y,z')**2 + 2*Symbol('x y,z') + 3"
  assert_eq(poly_degree_list(hostile_expression, gens=[literal]), [2])
  assert_eq(poly_lc(hostile_expression, gens=[literal]), "1")
  assert_eq(poly_tc(hostile_expression, gens=[literal]), "3")
  let rejected = try {
    poly_lc("x +", gens=["x"]) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(poly_lc("x**2 + 2*x + 1", gens=["x"]), "1")
}
