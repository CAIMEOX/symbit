///|
fn matrix_text(matrix : @symphysics.ExplicitMatrix) -> String {
  matrix
  .rows_copy()
  .map(row => row.map(@symprint.to_string).join(","))
  .join("|")
}

///|
fn scalar_map_text(mapping : Map[BaseScalar, @symcore.Expr]) -> String {
  let keys = mapping.keys().to_array()
  keys.sort()
  keys
  .map(key => key.to_string() + "=" + @symprint.to_string(mapping[key]))
  .join("|")
}

///|
test "coord systems expose base scalars and vectors" {
  let c = coord_sys3d("C") catch { _ => fail("C") }
  let c2 = coord_sys3d("C") catch { _ => fail("C2") }
  assert_eq(c, c2)
  assert_eq(c.to_string(), "C")
  assert_eq(c.x().to_string(), "C.x")
  assert_eq(c.y().to_string(), "C.y")
  assert_eq(c.z().to_string(), "C.z")
  assert_eq(c.i().to_string(), "C.i")
  assert_eq(c.j().to_string(), "C.j")
  assert_eq(c.k().to_string(), "C.k")
  assert_eq(
    c.base_scalars().map(item => item.to_string()).join("|"),
    "C.x|C.y|C.z",
  )
  assert_eq(
    c.base_vectors().map(item => item.to_string()).join("|"),
    "C.i|C.j|C.k",
  )
  assert_eq(c.i().kind().to_string(), "VectorKind(NumberKind)")
}

///|
test "vectors support basic arithmetic and axis orientation" {
  let q = @symcore.Expr::Symbol("q")
  let c = coord_sys3d("C") catch { _ => fail("C") }
  let b = c.orient_new_axis("B", q, c.k().to_vector()) catch { _ => fail("B") }

  assert_eq(
    matrix_text(c.rotation_matrix(b) catch { _ => fail("rot") }),
    "cos(q),-sin(q),0|sin(q),cos(q),0|0,0,1",
  )
  assert_eq(
    scalar_map_text(c.scalar_map(b) catch { _ => fail("map") }),
    "C.x=B.x*cos(q) - B.y*sin(q)|C.y=B.x*sin(q) + B.y*cos(q)|C.z=B.z",
  )

  let v = vector_from_terms([
    (c.x().expr(), c.i()),
    (c.y().expr(), c.j()),
    (c.z().expr(), c.k()),
  ])
  assert_eq(v.to_string(), "C.x*C.i + C.y*C.j + C.z*C.k")
  assert_eq(
    matrix_text(v.to_matrix(c) catch { _ => fail("mat") }),
    "C.x|C.y|C.z",
  )
  assert_eq(
    @symprint.to_string(dot(v, c.i().to_vector()) catch { _ => fail("dot") }),
    @symprint.to_string(c.x().expr()),
  )
  assert_eq(
    c.i().to_vector().cross(c.j().to_vector()) catch {
      _ => fail("cross")
    },
    c.k().to_vector(),
  )

  let expressed = express(b.i().to_vector(), c) catch { _ => fail("express") }
  assert_eq(expressed.to_string(), "cos(q)*C.i + sin(q)*C.j")
  let normalized = (c.i().to_vector() + c.j().to_vector()).normalize() catch {
    _ => fail("normalize")
  }
  assert_eq(normalized.to_string(), "sqrt(2)**-1*C.i + sqrt(2)**-1*C.j")
}

///|
test "scalar expressions can be re-expressed through scalar maps" {
  let q = @symcore.Expr::Symbol("q")
  let c = coord_sys3d("C") catch { _ => fail("C") }
  let b = c.orient_new_axis("B", q, c.k().to_vector()) catch { _ => fail("B") }
  let expr = b.x().expr() * b.y().expr() * b.z().expr()
  assert_eq(
    @symprint.to_string(express_scalar(expr, c, variables=true)),
    "C.z*(C.x*C.y*cos(q)**2 + C.y**2*cos(q)*sin(q) - C.x**2*cos(q)*sin(q) - C.x*C.y*sin(q)**2)",
  )
}

///|
fn coords_text(coords : Array[@symcore.Expr]) -> String {
  coords.map(@symprint.to_string).join("|")
}

///|
test "points expose relative position and coordinates" {
  let c = coord_sys3d("C") catch { _ => fail("C") }
  let p1 = c
    .origin()
    .locate_new(
      "p1",
      vector_from_terms([(@symcore.int(2), c.i()), (@symcore.int(3), c.j())]),
    ) catch {
      _ => fail("p1")
    }
  let p2 = p1.locate_new("p2", c.k().to_vector()) catch { _ => fail("p2") }

  assert_eq(
    (p2.position_wrt(point_reference_coord_system(c)) catch {
      _ => fail("pos")
    }).to_string(),
    "2*C.i + 3*C.j + C.k",
  )
  assert_eq(
    coords_text(p2.express_coordinates(c) catch { _ => fail("coords") }),
    "2|3|1",
  )
}

///|
test "field functions align with top-level vector surface" {
  let c = coord_sys3d("C") catch { _ => fail("C") }
  let scalar = c.x().expr() * c.y().expr() * c.z().expr()
  let field = vector_from_terms([
    (c.y().expr() * c.z().expr(), c.i()),
    (c.x().expr() * c.z().expr(), c.j()),
    (c.x().expr() * c.y().expr(), c.k()),
  ])
  let direction = vector_from_terms([
    (@symcore.int(3), c.i()),
    (@symcore.int(4), c.j()),
    (@symcore.int(1), c.k()),
  ])
  let p1 = c
    .origin()
    .locate_new(
      "p1",
      vector_from_terms([(@symcore.int(2), c.i()), (@symcore.int(3), c.j())]),
    ) catch {
      _ => fail("p1")
    }
  let p2 = p1.locate_new("p2", c.k().to_vector()) catch { _ => fail("p2") }

  assert_eq(gradient(scalar).to_string(), field.to_string())
  assert_eq(
    @symprint.to_string(divergence(field) catch { _ => fail("div") }),
    "0",
  )
  assert_eq((curl(field) catch { _ => fail("curl") }).to_string(), "0")
  assert_eq(is_conservative(field) catch { _ => fail("conservative") }, true)
  assert_eq(is_solenoidal(field) catch { _ => fail("solenoidal") }, true)
  assert_eq(
    @symprint.to_string(
      scalar_potential(field, c) catch {
        _ => fail("potential")
      },
    ),
    "C.x*C.y*C.z",
  )
  let dd_scalar = directional_derivative(
    scalar_or_vector_scalar(scalar),
    direction,
  ) catch {
    _ => fail("dd-scalar")
  }
  match dd_scalar {
    ScalarOrVector::ScalarExpr(value) => {
      let expected = c.x().expr() * c.y().expr() +
        @symcore.int(4) * c.x().expr() * c.z().expr() +
        @symcore.int(3) * c.y().expr() * c.z().expr()
      assert_eq(@symcore.compare_expr(value, expected), 0)
    }
    ScalarOrVector::VectorExpr(_) => fail("expected scalar result")
  }
  let lap_scalar = laplacian(
    scalar_or_vector_scalar(c.x().expr() ^ @symcore.int(2)),
  ) catch {
    _ => fail("laplacian")
  }
  match lap_scalar {
    ScalarOrVector::ScalarExpr(value) =>
      assert_eq(@symprint.to_string(value), "2")
    ScalarOrVector::VectorExpr(_) => fail("expected scalar laplacian")
  }
  assert_eq(
    @symprint.to_string(
      scalar_potential_difference(scalar_or_vector_vector(field), c, p1, p2) catch {
        _ => fail("potential-diff")
      },
    ),
    "6",
  )
}
