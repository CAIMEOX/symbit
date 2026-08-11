///|
fn intpoly_test_point2(x : Int, y : Int) -> @symgeometry.Point raise {
  @symgeometry.point2d(@symcore.int(x), @symcore.int(y))
}

///|
fn intpoly_test_point3(x : Int, y : Int, z : Int) -> @symgeometry.Point raise {
  @symgeometry.point3d(@symcore.int(x), @symcore.int(y), @symcore.int(z))
}

///|
fn intpoly_test_cube_vertices() -> Array[@symgeometry.Point] raise {
  [
    intpoly_test_point3(0, 0, 0),
    intpoly_test_point3(0, 0, 5),
    intpoly_test_point3(0, 5, 0),
    intpoly_test_point3(0, 5, 5),
    intpoly_test_point3(5, 0, 0),
    intpoly_test_point3(5, 0, 5),
    intpoly_test_point3(5, 5, 0),
    intpoly_test_point3(5, 5, 5),
  ]
}

///|
fn intpoly_test_cube_facets() -> Array[Array[Int]] {
  [
    [2, 6, 7, 3],
    [3, 7, 5, 1],
    [7, 6, 4, 5],
    [1, 5, 4, 0],
    [3, 1, 0, 2],
    [0, 4, 6, 2],
  ]
}

///|
fn intpoly_test_cube_hyperplanes() -> Array[
  (Array[@symcore.Expr], @symcore.Expr),
] {
  [
    ([@symcore.int(0), @symcore.int(-1), @symcore.int(0)], @symcore.int(-5)),
    ([@symcore.int(0), @symcore.int(0), @symcore.int(-1)], @symcore.int(-5)),
    ([@symcore.int(-1), @symcore.int(0), @symcore.int(0)], @symcore.int(-5)),
    ([@symcore.int(0), @symcore.int(1), @symcore.int(0)], @symcore.int(0)),
    ([@symcore.int(1), @symcore.int(0), @symcore.int(0)], @symcore.int(0)),
    ([@symcore.int(0), @symcore.int(0), @symcore.int(1)], @symcore.int(0)),
  ]
}

///|
test "symintegrals intpoly helper strip splits coefficient and monomial" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let (coeff, monom) = strip(@symcore.int(3) * x * y)
  assert_true(@symcore.compare_expr(coeff, @symcore.int(3)) == 0)
  assert_true(@symcore.compare_expr(monom, x * y) == 0)
  let (zero_coeff, zero_monom) = strip(@symcore.int(0))
  assert_true(@symcore.compare_expr(zero_coeff, @symcore.int(0)) == 0)
  assert_true(@symcore.compare_expr(zero_monom, @symcore.int(0)) == 0)
}

///|
test "symintegrals intpoly decompose groups homogeneous polynomial pieces" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let x2 = x ^ @symcore.int(2)
  let x3 = x ^ @symcore.int(3)
  let y2 = y ^ @symcore.int(2)
  let y5 = y ^ @symcore.int(5)
  let expr = x2 + x * y + x + y + x3 * y2 + y5
  let pieces = decompose(expr)
  assert_true(pieces.length() == 3)
  assert_true(pieces[0].0 == 1)
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(pieces[0].1 - (x + y)),
      @symcore.int(0),
    ) ==
    0,
  )
  assert_true(pieces[1].0 == 2)
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(pieces[1].1 - (x2 + x * y)),
      @symcore.int(0),
    ) ==
    0,
  )
  assert_true(pieces[2].0 == 5)
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(pieces[2].1 - (x3 * y2 + y5)),
      @symcore.int(0),
    ) ==
    0,
  )

  let separate = decompose(expr, separate=true)
  assert_true(separate.length() == 6)
}

///|
test "symintegrals intpoly helpers compute point geometry quantities" {
  let p = intpoly_test_point2(2, 7)
  assert_true(is_vertex(p))
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(norm(p) - @symelem.sqrt(@symcore.int(53))),
      @symcore.int(0),
    ) ==
    0,
  )

  let cp = cross_product(
    intpoly_test_point3(0, 0, 0),
    intpoly_test_point3(1, 0, 0),
    intpoly_test_point3(0, 1, 0),
  )
  assert_true(cp.length() == 3)
  assert_true(@symcore.compare_expr(cp[0], @symcore.int(0)) == 0)
  assert_true(@symcore.compare_expr(cp[1], @symcore.int(0)) == 0)
  assert_true(@symcore.compare_expr(cp[2], @symcore.int(1)) == 0)
}

///|
test "symintegrals intpoly helpers generate 2D gradient and hyperplane data" {
  let terms = gradient_terms(binomial_power=2)
  assert_true(terms.length() == 6)
  assert_true(@symcore.compare_expr(terms[0][0], @symcore.int(1)) == 0)
  assert_true(@symcore.compare_expr(terms[1][0], Symbol("y")) == 0)
  assert_true(
    @symcore.compare_expr(terms[5][0], Symbol("x") ^ @symcore.int(2)) == 0,
  )

  let square = match
    @symgeometry.polygon([
      intpoly_test_point2(0, 0),
      intpoly_test_point2(1, 0),
      intpoly_test_point2(1, 1),
      intpoly_test_point2(0, 1),
    ]) {
    Polygon(item) => item
    _ => fail("expected square polygon")
  }
  let params = hyperplane_parameters(square)
  assert_true(params.length() == 4)
  assert_true(@symcore.compare_expr(params[0].0[0], @symcore.int(0)) == 0)
  assert_true(@symcore.compare_expr(params[0].0[1], @symcore.int(1)) == 0)
  assert_true(@symcore.compare_expr(params[0].1, @symcore.int(0)) == 0)
  assert_true(@symcore.compare_expr(params[1].0[0], @symcore.int(-1)) == 0)
  assert_true(@symcore.compare_expr(params[1].0[1], @symcore.int(0)) == 0)
  assert_true(@symcore.compare_expr(params[1].1, @symcore.int(-1)) == 0)
}

///|
test "symintegrals intpoly point_sort orders planar vertices" {
  let sorted = point_sort([
    intpoly_test_point2(0, 0),
    intpoly_test_point2(1, 0),
    intpoly_test_point2(1, 1),
  ])
  assert_true(sorted.length() == 3)
  assert_true(@symcore.compare_expr(sorted[0].x(), @symcore.int(1)) == 0)
  assert_true(@symcore.compare_expr(sorted[0].y(), @symcore.int(1)) == 0)
  assert_true(@symcore.compare_expr(sorted[1].x(), @symcore.int(1)) == 0)
  assert_true(@symcore.compare_expr(sorted[1].y(), @symcore.int(0)) == 0)
  assert_true(@symcore.compare_expr(sorted[2].x(), @symcore.int(0)) == 0)
  assert_true(@symcore.compare_expr(sorted[2].y(), @symcore.int(0)) == 0)
}

///|
test "symintegrals intpoly best_origin chooses axis intersection" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let origin = best_origin(
    [@symcore.int(2), @symcore.int(1)],
    @symcore.int(3),
    @symgeometry.segment(intpoly_test_point2(0, 3), intpoly_test_point2(1, 1)),
    (x ^ @symcore.int(3)) * (y ^ @symcore.int(7)),
  )
  assert_true(@symcore.compare_expr(origin.x(), @symcore.int(0)) == 0)
  assert_true(@symcore.compare_expr(origin.y(), @symcore.int(3)) == 0)
}

///|
test "symintegrals intpoly 2D reduction integrates over polygon facets" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let square = match
    @symgeometry.polygon([
      intpoly_test_point2(0, 0),
      intpoly_test_point2(1, 0),
      intpoly_test_point2(1, 1),
      intpoly_test_point2(0, 1),
    ]) {
    Polygon(item) => item
    _ => fail("expected square polygon")
  }
  let facets = square.sides()
  let params = hyperplane_parameters(square)
  let left = left_integral2D(
    facets.length(),
    0,
    facets,
    facets[0].p1(),
    @symcore.int(1),
    [x, y],
  )
  assert_true(@symcore.compare_expr(left, @symcore.int(1)) == 0)

  let reduced = integration_reduction(
    facets,
    0,
    params[0].0,
    params[0].1,
    @symcore.int(1),
    [x, y],
    0,
  )
  assert_true(@symcore.compare_expr(reduced, @symcore.int(1)) == 0)

  let dynamic = integration_reduction_dynamic(
    facets,
    0,
    params[0].0,
    params[0].1,
    x,
    1,
    [x, y],
    1,
    0,
    1,
    facets[0].p1(),
    [
      [@symcore.int(0), @symcore.int(0), @symcore.int(0), @symcore.int(0)],
      [@symcore.int(1), @symcore.int(0), @symcore.int(0), @symcore.int(1)],
      [y, @symcore.int(0), @symcore.int(1), @symcore.rational_from_ints(1, 2)],
      [x, @symcore.int(1), @symcore.int(0), @symcore.int(0)],
    ],
    3,
  )
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(dynamic - @symcore.rational_from_ints(1, 2)),
      @symcore.int(0),
    ) ==
    0,
  )

  let value = main_integrate(x * y, facets, params)
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(value - @symcore.rational_from_ints(-1, 4)),
      @symcore.int(0),
    ) ==
    0,
  )
}

///|
test "symintegrals intpoly 3D reduction integrates cube examples" {
  let vertices = intpoly_test_cube_vertices()
  let facets = intpoly_test_cube_facets()
  let hp_params = intpoly_test_cube_hyperplanes()

  let edge = @symgeometry.segment(vertices[2], vertices[6])
  let edge_value = lineseg_integrate(
    [vertices[2], vertices[6], vertices[7], vertices[3]],
    0,
    edge,
    @symcore.int(1),
    0,
  )
  assert_true(@symcore.compare_expr(edge_value, @symcore.int(5)) == 0)

  let left = left_integral3D(
    facets,
    3,
    @symcore.int(1),
    vertices,
    hp_params[0],
    0,
  )
  assert_true(@symcore.compare_expr(left, @symcore.int(-50)) == 0)

  let face_value = polygon_integrate(
    facets[0],
    ([@symcore.int(0), @symcore.int(1), @symcore.int(0)], @symcore.int(5)),
    0,
    facets,
    vertices,
    @symcore.int(1),
    0,
  )
  assert_true(@symcore.compare_expr(face_value, @symcore.int(-25)) == 0)

  let volume = main_integrate3d(@symcore.int(1), facets, vertices, hp_params)
  assert_true(@symcore.compare_expr(volume, @symcore.int(-125)) == 0)
}

///|
test "symintegrals intpoly plotting helpers build plot objects" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let square = match
    @symgeometry.polygon([
      intpoly_test_point2(0, 0),
      intpoly_test_point2(1, 0),
      intpoly_test_point2(1, 1),
      intpoly_test_point2(0, 1),
    ]) {
    Polygon(item) => item
    _ => fail("expected square polygon")
  }
  let poly_plot = plot_polytope(square)
  assert_true(poly_plot.series().length() == 4)
  let expr_plot = plot_polynomial(x * y)
  assert_true(expr_plot.series().length() == 1)
}

///|
test "symintegrals intpoly helpers compute side distance and segment intersection" {
  let distance = distance_to_side(
    intpoly_test_point3(0, 0, 0),
    @symgeometry.segment(
      intpoly_test_point3(0, 0, 1),
      intpoly_test_point3(0, 1, 0),
    ),
    intpoly_test_point3(1, 0, 0),
  )
  let expected_distance = @symcore.int(-1) *
    (@symelem.sqrt(@symcore.int(2)) ^ @symcore.int(-1))
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(distance - expected_distance),
      @symcore.int(0),
    ) ==
    0,
  )

  let hit = intersection(
    @symgeometry.segment(intpoly_test_point2(1, 1), intpoly_test_point2(3, 5)),
    @symgeometry.segment(intpoly_test_point2(2, 0), intpoly_test_point2(2, 5)),
    "segment2D",
  )
  guard hit is Some(point) else {
    fail("expected a unique segment intersection")
  }
  assert_true(@symcore.compare_expr(point.x(), @symcore.int(2)) == 0)
  assert_true(@symcore.compare_expr(point.y(), @symcore.int(3)) == 0)
}
