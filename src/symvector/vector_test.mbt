///|
fn matrix_text(matrix : @symphysics.ExplicitMatrix) -> String {
  matrix
  .rows_copy()
  .map(row => row.map(@symprint.pretty_string).join(","))
  .join("|")
}

///|
fn scalar_map_text(mapping : Map[BaseScalar, @symcore.Expr]) -> String {
  let keys = mapping.keys().to_array()
  keys.sort()
  keys
  .map(key => Show::to_string(key) + "=" + @symprint.pretty_string(mapping[key]))
  .join("|")
}

///|
test "coord systems expose base scalars and vectors" {
  let c = coord_sys3d("C") catch { _ => fail("C") }
  let c2 = coord_sys3d("C") catch { _ => fail("C2") }
  assert_true(c == c2)
  assert_true(Show::to_string(c) == "C")
  assert_true(Show::to_string(c.x()) == "C.x")
  assert_true(Show::to_string(c.y()) == "C.y")
  assert_true(Show::to_string(c.z()) == "C.z")
  assert_true(Show::to_string(c.i()) == "C.i")
  assert_true(Show::to_string(c.j()) == "C.j")
  assert_true(Show::to_string(c.k()) == "C.k")
  assert_true(
    c.base_scalars().map(item => Show::to_string(item)).join("|") ==
    "C.x|C.y|C.z",
  )
  assert_true(
    c.base_vectors().map(item => Show::to_string(item)).join("|") ==
    "C.i|C.j|C.k",
  )
  assert_true(Show::to_string(c.i().kind()) == "VectorKind(NumberKind)")
}

///|
test "vectors support basic arithmetic and axis orientation" {
  let q = @symcore.Expr::Symbol("q")
  let c = coord_sys3d("C") catch { _ => fail("C") }
  let b = c.orient_new_axis("B", q, c.k().to_vector()) catch { _ => fail("B") }

  assert_true(
    matrix_text(c.rotation_matrix(b) catch { _ => fail("rot") }) ==
    "cos(q),-sin(q),0|sin(q),cos(q),0|0,0,1",
  )
  assert_true(
    scalar_map_text(c.scalar_map(b) catch { _ => fail("map") }) ==
    "C.x=B.x*cos(q) - B.y*sin(q)|C.y=B.x*sin(q) + B.y*cos(q)|C.z=B.z",
  )

  let v = vector_from_terms([
    (c.x().expr(), c.i()),
    (c.y().expr(), c.j()),
    (c.z().expr(), c.k()),
  ])
  assert_true(Show::to_string(v) == "C.x*C.i + C.y*C.j + C.z*C.k")
  assert_true(
    matrix_text(v.to_matrix(c) catch { _ => fail("mat") }) == "C.x|C.y|C.z",
  )
  assert_true(
    @symprint.pretty_string(
      dot(v, c.i().to_vector()) catch {
        _ => fail("dot")
      },
    ) ==
    @symprint.pretty_string(c.x().expr()),
  )
  assert_true(
    (c.i().to_vector().cross(c.j().to_vector()) catch { _ => fail("cross") }) ==
    c.k().to_vector(),
  )

  let expressed = express(b.i().to_vector(), c) catch { _ => fail("express") }
  assert_true(Show::to_string(expressed) == "cos(q)*C.i + sin(q)*C.j")
  let normalized = (c.i().to_vector() + c.j().to_vector()).normalize() catch {
    _ => fail("normalize")
  }
  assert_true(
    Show::to_string(normalized) == "sqrt(2)**-1*C.i + sqrt(2)**-1*C.j",
  )
}

///|
test "scalar expressions can be re-expressed through scalar maps" {
  let q = @symcore.Expr::Symbol("q")
  let c = coord_sys3d("C") catch { _ => fail("C") }
  let b = c.orient_new_axis("B", q, c.k().to_vector()) catch { _ => fail("B") }
  let expr = b.x().expr() * b.y().expr() * b.z().expr()
  assert_true(
    @symprint.pretty_string(express_scalar(expr, c, variables=true)) ==
    "C.z*(C.x*C.y*cos(q)**2 + C.y**2*cos(q)*sin(q) - C.x**2*cos(q)*sin(q) - C.x*C.y*sin(q)**2)",
  )
}

///|
fn coords_text(coords : Array[@symcore.Expr]) -> String {
  coords.map(@symprint.pretty_string).join("|")
}

///|
fn expr_eq(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Bool {
  @symcore.is_zero(@symsimplify.simplify(lhs - rhs))
}

///|
fn expr_div_test(num : @symcore.Expr, den : @symcore.Expr) -> @symcore.Expr {
  num * (den ^ @symcore.int(-1))
}

///|
fn matrix_expr_eq(
  matrix : @symphysics.ExplicitMatrix,
  expected : Array[Array[@symcore.Expr]],
) -> Bool {
  let rows = matrix.rows_copy()
  if rows.length() != expected.length() {
    return false
  }
  for i in 0..<rows.length() {
    if rows[i].length() != expected[i].length() {
      return false
    }
    for j in 0..<rows[i].length() {
      if !expr_eq(rows[i][j], expected[i][j]) {
        return false
      }
    }
  }
  true
}

///|
fn matrix3_text(matrix : @symphysics.ExplicitMatrix) -> String {
  matrix
  .rows_copy()
  .map(row => row.map(@symprint.pretty_string).join(","))
  .join("|")
}

///|
fn separate_text(parts : Map[CoordSys3D, Vector]) -> String {
  let systems = parts.keys().to_array()
  systems.sort()
  systems
  .map(fn(system) {
    Show::to_string(system) + ":" + Show::to_string(parts[system])
  })
  .join("|")
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

  assert_true(
    Show::to_string(
      p2.position_wrt(point_reference_coord_system(c)) catch {
        _ => fail("pos")
      },
    ) ==
    "2*C.i + 3*C.j + C.k",
  )
  assert_true(
    coords_text(p2.express_coordinates(c) catch { _ => fail("coords") }) ==
    "2|3|1",
  )
}

///|
test "vector surface includes equals projection separate orthogonalize and laplacian" {
  let c = coord_sys3d("C") catch { _ => fail("C") }
  let half_pi = @symcore.Expr::NumberSymbol(Pi) *
    (@symcore.int(2) ^ @symcore.int(-1))
  let d = c.orient_new_axis("D", half_pi, c.k().to_vector()) catch {
    _ => fail("D")
  }
  let v1 = c.i().to_vector() + c.j().to_vector() + c.k().to_vector()
  let v2 = vector_from_terms([
    (@symcore.int(3), c.i()),
    (@symcore.int(4), c.j()),
  ])

  assert_true(
    (c.i().to_vector().equals(c.i().to_vector()) catch {
      _ => fail("equals-1")
    }) ==
    Some(true),
  )
  assert_true(
    (c.i().to_vector().equals(c.j().to_vector()) catch {
      _ => fail("equals-2")
    }) ==
    Some(false),
  )
  let cross_frame_equal = d.i().to_vector().equals(c.j().to_vector()) catch {
      _ => fail("equals-3")
    }
  assert_true(cross_frame_equal == Some(true))

  let projection_vector = v1.projection(v2) catch {
    _ => fail("projection-vector")
  }
  match projection_vector {
    VectorExpr(value) =>
      assert_true(Show::to_string(value) == "7/3*C.i + 7/3*C.j + 7/3*C.k")
    ScalarExpr(_) => fail("expected vector projection")
  }
  let projection_scalar = v1.projection(v2, scalar=true) catch {
    _ => fail("projection-scalar")
  }
  match projection_scalar {
    ScalarExpr(value) => assert_true(@symprint.pretty_string(value) == "7/3")
    VectorExpr(_) => fail("expected scalar projection")
  }

  assert_true(
    separate_text(
      (c.i().to_vector() + d.i().to_vector().scale(@symcore.int(2)).neg()).separate(),
    ) ==
    "C:C.i|D:-2*D.i",
  )

  let ortho = orthogonalize([
    c.i().to_vector() + c.j().to_vector().scale(@symcore.int(2)),
    c.i().to_vector().scale(@symcore.int(2)) +
    c.j().to_vector().scale(@symcore.int(3)),
  ]) catch {
    _ => fail("orthogonalize")
  }
  assert_true(ortho.length() == 2)
  assert_true(Show::to_string(ortho[0]) == "C.i + 2*C.j")
  assert_true(Show::to_string(ortho[1]) == "2/5*C.i - 1/5*C.j")

  let lap_scalar = laplacian_unevaluated(
    scalar_or_vector_scalar(
      (c.x().expr() ^ @symcore.int(2)) +
      (c.y().expr() ^ @symcore.int(2)) +
      (c.z().expr() ^ @symcore.int(2)),
    ),
  )
  assert_true(
    Show::to_string(lap_scalar) == "Laplacian(C.x**2 + C.y**2 + C.z**2)",
  )
  let lap_scalar_value = lap_scalar.doit() catch { _ => fail("lap-scalar") }
  match lap_scalar_value {
    ScalarExpr(value) => assert_true(@symprint.pretty_string(value) == "6")
    VectorExpr(_) => fail("expected scalar laplacian result")
  }

  let lap_vector = laplacian_unevaluated(
    scalar_or_vector_vector(
      vector_from_terms([
        (c.x().expr() ^ @symcore.int(2), c.i()),
        (c.y().expr() ^ @symcore.int(2), c.j()),
        (c.z().expr() ^ @symcore.int(2), c.k()),
      ]),
    ),
  )
  assert_true(
    Show::to_string(lap_vector) ==
    "Laplacian(C.x**2*C.i + C.y**2*C.j + C.z**2*C.k)",
  )
  let lap_vector_value = lap_vector.doit() catch { _ => fail("lap-vector") }
  match lap_vector_value {
    VectorExpr(value) =>
      assert_true(Show::to_string(value) == "2*C.i + 2*C.j + 2*C.k")
    ScalarExpr(_) => fail("expected vector laplacian result")
  }
}

///|
test "del operator exposes cartesian differential surface" {
  let c = coord_sys3d("C") catch { _ => fail("C") }
  let x = c.x().expr()
  let y = c.y().expr()
  let z = c.z().expr()
  let v = vector_from_terms([
    (x * y * z, c.i()),
    (x * y * z, c.j()),
    (x * y * z, c.k()),
  ])

  assert_true(Show::to_string(delop) == "delop")
  assert_true(
    matrix_text(delop.gradient(x).to_matrix(c) catch { _ => fail("del-grad") }) ==
    "Derivative(C.x, C.x)|Derivative(C.x, C.y)|Derivative(C.x, C.z)",
  )
  assert_true(delop.call(x * y * z) == delop.gradient(x * y * z))
  assert_true(
    Show::to_string(delop.gradient(x * y * z, doit=true)) ==
    "C.y*C.z*C.i + C.x*C.z*C.j + C.x*C.y*C.k",
  )
  assert_true(
    expr_eq(
      delop.dot(v) catch {
        _ => fail("del-dot")
      },
      @symcore.derivative(x * y * z, x) +
      @symcore.derivative(x * y * z, y) +
      @symcore.derivative(x * y * z, z),
    ) ==
    true,
  )
  assert_true(
    Show::to_string(
      delop.cross(
        vector_term(@symcore.int(2) * (x ^ @symcore.int(2)), c.j()),
        doit=true,
      ) catch {
        _ => fail("del-curl")
      },
    ) ==
    "4*C.x*C.k",
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

  assert_true(Show::to_string(gradient(scalar)) == Show::to_string(field))
  assert_true(
    @symprint.pretty_string(divergence(field) catch { _ => fail("div") }) == "0",
  )
  assert_true(Show::to_string(curl(field) catch { _ => fail("curl") }) == "0")
  assert_true(
    (is_conservative(field) catch { _ => fail("conservative") }) == true,
  )
  assert_true((is_solenoidal(field) catch { _ => fail("solenoidal") }) == true)
  assert_true(
    @symprint.pretty_string(
      scalar_potential(field, c) catch {
        _ => fail("potential")
      },
    ) ==
    "C.x*C.y*C.z",
  )
  let dd_scalar = directional_derivative(
    scalar_or_vector_scalar(scalar),
    direction,
  ) catch {
    _ => fail("dd-scalar")
  }
  match dd_scalar {
    ScalarExpr(value) => {
      let expected = c.x().expr() * c.y().expr() +
        @symcore.int(4) * c.x().expr() * c.z().expr() +
        @symcore.int(3) * c.y().expr() * c.z().expr()
      assert_true(expr_eq(value, expected) == true)
    }
    VectorExpr(_) => fail("expected scalar result")
  }
  let lap_scalar = laplacian(
    scalar_or_vector_scalar(c.x().expr() ^ @symcore.int(2)),
  ) catch {
    _ => fail("laplacian")
  }
  match lap_scalar {
    ScalarExpr(value) => assert_true(@symprint.pretty_string(value) == "2")
    VectorExpr(_) => fail("expected scalar laplacian")
  }
  assert_true(
    @symprint.pretty_string(
      scalar_potential_difference(scalar_or_vector_vector(field), c, p1, p2) catch {
        _ => fail("potential-diff")
      },
    ) ==
    "6",
  )
}

///|
test "curvilinear field functions support cylindrical and spherical systems" {
  let a = coord_sys3d(
    "A",
    variable_names=Some(["r", "theta", "phi"]),
    transformation=Some("spherical"),
  ) catch {
    _ => fail("A")
  }
  let b = coord_sys3d(
    "B",
    variable_names=Some(["r", "theta", "z"]),
    transformation=Some("cylindrical"),
  ) catch {
    _ => fail("B")
  }

  assert_true(
    matrix_text(
      gradient(@symcore.int(3) * a.x().expr() + @symcore.int(4) * a.y().expr()).to_matrix(
        a,
      ) catch {
        _ => fail("grad-sph")
      },
    ) ==
    "3|4/A.r|0",
  )
  assert_true(
    matrix_text(
      gradient(b.x().expr() * b.y().expr() * b.z().expr()).to_matrix(b) catch {
        _ => fail("grad-cyl")
      },
    ) ==
    "B.z*B.theta|B.z|B.r*B.theta",
  )
  assert_true(
    expr_eq(
      divergence(
        vector_from_terms([
          (b.x().expr(), b.i()),
          (b.y().expr(), b.j()),
          (b.z().expr(), b.k()),
        ]),
      ) catch {
        _ => fail("div-cyl")
      },
      @symcore.int(3) + (b.x().expr() ^ @symcore.int(-1)),
    ) ==
    true,
  )
  assert_true(
    Show::to_string(
      curl(vector_from_terms([(b.x().expr(), b.j()), (b.z().expr(), b.k())])) catch {
        _ => fail("curl-cyl")
      },
    ) ==
    "2*B.k",
  )
  let scalar_dd = directional_derivative(
    scalar_or_vector_scalar(
      @symcore.int(5) * (a.x().expr() ^ @symcore.int(2)) * a.z().expr(),
    ),
    vector_from_terms([
      (@symcore.int(3), a.i()),
      (@symcore.int(4), a.j()),
      (@symcore.int(1), a.k()),
    ]),
  ) catch {
    _ => fail("dd-sph-scalar")
  }
  match scalar_dd {
    ScalarExpr(value) =>
      assert_true(
        expr_eq(
          value,
          @symcore.int(5) *
          a.x().expr() *
          (@symcore.function("sin", [a.y().expr()]) ^ @symcore.int(-1)) +
          @symcore.int(30) * a.x().expr() * a.z().expr(),
        ) ==
        true,
      )
    VectorExpr(_) => fail("expected scalar result")
  }

  let r = b.x().expr()
  let theta = b.y().expr()
  let zz = b.z().expr()
  let u = @symcore.applied_undefined_function("u", [r, theta, zz])
  let v = @symcore.applied_undefined_function("v", [r, theta, zz])
  let w = @symcore.applied_undefined_function("w", [r, theta, zz])
  let vec = vector_from_terms([(u, b.i()), (v, b.j()), (w, b.k())])
  let grad_vec_cyl = gradient_vector(vec) catch { _ => fail("grad-vec-cyl") }
  assert_true(
    matrix_expr_eq(
      grad_vec_cyl.to_matrix(b) catch {
        _ => fail("grad-vec-cyl-mat")
      },
      [
        [
          @symcore.derivative(u, r),
          @symcore.derivative(v, r),
          @symcore.derivative(w, r),
        ],
        [
          expr_div_test(@symcore.derivative(u, theta) - v, r),
          expr_div_test(u + @symcore.derivative(v, theta), r),
          expr_div_test(@symcore.derivative(w, theta), r),
        ],
        [
          @symcore.derivative(u, zz),
          @symcore.derivative(v, zz),
          @symcore.derivative(w, zz),
        ],
      ],
    ) ==
    true,
  )
}

///|
test "directional derivative covers more scalar and vector cases" {
  let c = coord_sys3d("C") catch { _ => fail("C") }
  let x = c.x().expr()
  let y = c.y().expr()
  let z = c.z().expr()
  let u = @symcore.applied_undefined_function("u", [x, y, z])
  let v = @symcore.applied_undefined_function("v", [x, y, z])
  let w = @symcore.applied_undefined_function("w", [x, y, z])
  let vec = vector_from_terms([(u, c.i()), (v, c.j()), (w, c.k())])
  let dir = c.i().to_vector() + c.j().to_vector() + c.k().to_vector()

  let dd_more_scalar = directional_derivative(
    scalar_or_vector_scalar(@symcore.int(5) * (x ^ @symcore.int(2)) * z),
    vector_from_terms([
      (@symcore.int(3), c.i()),
      (@symcore.int(4), c.j()),
      (@symcore.int(1), c.k()),
    ]),
  ) catch {
    _ => fail("dd-more-scalar")
  }
  match dd_more_scalar {
    ScalarExpr(value) =>
      assert_true(
        expr_eq(
          value,
          @symcore.int(5) * (x ^ @symcore.int(2)) + @symcore.int(30) * x * z,
        ) ==
        true,
      )
    VectorExpr(_) => fail("expected scalar result")
  }

  let dd_zero = directional_derivative(
    scalar_or_vector_scalar(@symcore.int(5) * (x ^ @symcore.int(2)) * z),
    c.j().to_vector().scale(@symcore.int(4)),
  ) catch {
    _ => fail("dd-zero")
  }
  match dd_zero {
    ScalarExpr(value) => assert_true(@symprint.pretty_string(value) == "0")
    VectorExpr(_) => fail("expected scalar result")
  }

  let dd_vector = directional_derivative(scalar_or_vector_vector(vec), dir) catch {
    _ => fail("dd-vector")
  }
  match dd_vector {
    VectorExpr(value) =>
      assert_true(
        matrix_text(value.to_matrix(c) catch { _ => fail("dd-vector-mat") }) ==
        "Derivative(u(C.x, C.y, C.z), C.x) + Derivative(u(C.x, C.y, C.z), C.y) + Derivative(u(C.x, C.y, C.z), C.z)|Derivative(v(C.x, C.y, C.z), C.x) + Derivative(v(C.x, C.y, C.z), C.y) + Derivative(v(C.x, C.y, C.z), C.z)|Derivative(w(C.x, C.y, C.z), C.x) + Derivative(w(C.x, C.y, C.z), C.y) + Derivative(w(C.x, C.y, C.z), C.z)",
      )
    ScalarExpr(_) => fail("expected vector result")
  }
}

///|
test "unevaluated operator wrappers support doit" {
  let c = coord_sys3d("C") catch { _ => fail("C") }
  let scalar = c.x().expr() * c.y().expr() * c.z().expr()
  let vector_field = vector_from_terms([
    (c.y().expr() * c.z().expr(), c.i()),
    (c.x().expr() * c.z().expr(), c.j()),
    (c.x().expr() * c.y().expr(), c.k()),
  ])
  let x = c.x().expr()
  let y = c.y().expr()
  let z = c.z().expr()
  let u = @symcore.applied_undefined_function("u", [x, y, z])
  let v = @symcore.applied_undefined_function("v", [x, y, z])
  let w = @symcore.applied_undefined_function("w", [x, y, z])
  let vec = vector_from_terms([(u, c.i()), (v, c.j()), (w, c.k())])

  let grad_scalar = gradient_unevaluated(scalar_or_vector_scalar(scalar))
  assert_true(Show::to_string(grad_scalar) == "Gradient(C.x*C.y*C.z)")
  let grad_scalar_value = grad_scalar.doit() catch { _ => fail("grad-scalar") }
  match grad_scalar_value {
    VectorValue(value) =>
      assert_true(
        Show::to_string(value) == "C.y*C.z*C.i + C.x*C.z*C.j + C.x*C.y*C.k",
      )
    DyadicValue(_) => fail("expected vector result")
  }

  let grad_vector = gradient_unevaluated(scalar_or_vector_vector(vec))
  assert_true(
    Show::to_string(grad_vector) ==
    "Gradient(u(C.x, C.y, C.z)*C.i + v(C.x, C.y, C.z)*C.j + w(C.x, C.y, C.z)*C.k)",
  )
  let grad_vector_value = grad_vector.doit() catch { _ => fail("grad-vector") }
  match grad_vector_value {
    DyadicValue(value) =>
      assert_true(
        matrix3_text(value.to_matrix(c) catch { _ => fail("grad-mat") }) ==
        "Derivative(u(C.x, C.y, C.z), C.x),Derivative(v(C.x, C.y, C.z), C.x),Derivative(w(C.x, C.y, C.z), C.x)|Derivative(u(C.x, C.y, C.z), C.y),Derivative(v(C.x, C.y, C.z), C.y),Derivative(w(C.x, C.y, C.z), C.y)|Derivative(u(C.x, C.y, C.z), C.z),Derivative(v(C.x, C.y, C.z), C.z),Derivative(w(C.x, C.y, C.z), C.z)",
      )
    VectorValue(_) => fail("expected dyadic result")
  }

  let div = divergence_unevaluated(vector_field)
  assert_true(
    Show::to_string(div) ==
    "Divergence(C.y*C.z*C.i + C.x*C.z*C.j + C.x*C.y*C.k)",
  )
  assert_true(
    @symprint.pretty_string(div.doit() catch { _ => fail("div-doit") }) == "0",
  )

  let curl_op = curl_unevaluated(vector_field)
  assert_true(
    Show::to_string(curl_op) == "Curl(C.y*C.z*C.i + C.x*C.z*C.j + C.x*C.y*C.k)",
  )
  assert_true(
    Show::to_string(curl_op.doit() catch { _ => fail("curl-doit") }) == "0",
  )
}

///|
test "dyadics support outer products and matrix conversion" {
  let q = @symcore.Expr::Symbol("q")
  let c = coord_sys3d("C") catch { _ => fail("C") }
  let b = c.orient_new_axis("B", q, c.k().to_vector()) catch { _ => fail("B") }
  let d1 = c.i().outer(c.i()) catch { _ => fail("d1") }
  let d2 = c.i().outer(c.j()) catch { _ => fail("d2") }
  let v = vector_from_terms([
    (Symbol("a"), c.i()),
    (Symbol("b"), c.j()),
    (Symbol("c"), c.k()),
  ])
  let w = vector_from_terms([
    (Symbol("d"), c.i()),
    (Symbol("e"), c.j()),
    (Symbol("f"), c.k()),
  ])

  assert_true(Show::to_string(d1) == "(C.i|C.i)")
  assert_true(
    (d1.dot_vector(c.i().to_vector()) catch { _ => fail("dotv") }) ==
    c.i().to_vector(),
  )
  assert_true(
    Show::to_string(d1.cross(c.k().to_vector()) catch { _ => fail("cross") }) ==
    "-(C.i|C.j)",
  )
  assert_true(
    matrix3_text(d1.to_matrix(c) catch { _ => fail("mat") }) ==
    "1,0,0|0,0,0|0,0,0",
  )
  assert_true(
    matrix3_text(d1.to_matrix(c, system2=Some(b)) catch { _ => fail("mat2") }) ==
    "cos(q),-sin(q),0|0,0,0|0,0,0",
  )
  assert_true(
    Show::to_string(
      matrix_to_dyadic(
        @symphysics.explicit_matrix_from_rows([
          [@symcore.int(1), @symcore.int(2), @symcore.int(3)],
          [@symcore.int(4), @symcore.int(5), @symcore.int(6)],
          [@symcore.int(7), @symcore.int(8), @symcore.int(9)],
        ]) catch {
          _ => fail("srcmat")
        },
        c,
      ),
    ) ==
    "(C.i|C.i) + 2*(C.i|C.j) + 3*(C.i|C.k) + 4*(C.j|C.i) + 5*(C.j|C.j) + 6*(C.j|C.k) + 7*(C.k|C.i) + 8*(C.k|C.j) + 9*(C.k|C.k)",
  )
  assert_true(
    Show::to_string(v.outer(w) catch { _ => fail("outer") }) ==
    "a*d*(C.i|C.i) + a*e*(C.i|C.j) + a*f*(C.i|C.k) + b*d*(C.j|C.i) + b*e*(C.j|C.j) + b*f*(C.j|C.k) + c*d*(C.k|C.i) + c*e*(C.k|C.j) + c*f*(C.k|C.k)",
  )
  assert_true(
    matrix3_text(
      (express_dyadic(d2, b) catch { _ => fail("express_d") }).to_matrix(b) catch {
        _ => fail("express_d_mat")
      },
    ) ==
    "cos(q)*sin(q),cos(q)**2,0|-sin(q)**2,-cos(q)*sin(q),0|0,0,0",
  )
}

///|
test "basisdependent wrappers expose sympy-style vector surface" {
  let c = coord_sys3d("C") catch { _ => fail("C") }
  let zero = vector_zero_expr()
  assert_true(Show::to_string(zero) == "0")
  assert_true(zero.doit() == vector_zero())

  let mul = vector_mul_expr(c.x().expr(), c.i())
  assert_true(Show::to_string(mul) == "C.x*C.i")
  assert_true(mul.base_vector() == c.i())
  assert_true(@symprint.pretty_string(mul.measure_number()) == "C.x")
  assert_true(mul.doit() == vector_term(c.x().expr(), c.i()))

  let add = vector_add_expr([c.i().to_vector(), c.j().to_vector()])
  assert_true(Show::to_string(add) == "C.i + C.j")
  assert_true(add.doit() == c.i().to_vector() + c.j().to_vector())

  let cross_op = cross_unevaluated(c.j().to_vector(), c.i().to_vector())
  assert_true(Show::to_string(cross_op) == "-Cross(C.i, C.j)")
  assert_true(
    (cross_op.doit() catch { _ => fail("cross-op") }) == c.k().to_vector().neg(),
  )

  let dot_op = dot_unevaluated(c.j().to_vector(), c.i().to_vector())
  assert_true(Show::to_string(dot_op) == "Dot(C.i, C.j)")
  assert_true(
    @symprint.pretty_string(dot_op.doit() catch { _ => fail("dot-op") }) == "0",
  )
}

///|
test "orienters and coordinate transformations follow sympy formulas" {
  let q1 = @symcore.Expr::Symbol("q1")
  let q2 = @symcore.Expr::Symbol("q2")
  let q3 = @symcore.Expr::Symbol("q3")
  let q4 = @symcore.Expr::Symbol("q4")
  let n = coord_sys3d("N") catch { _ => fail("N") }

  let axis = axis_orienter(q1, n.k().to_vector())
  assert_true(
    matrix_text(axis.rotation_matrix(n) catch { _ => fail("axis-mat") }) ==
    "cos(q1),sin(q1),0|-sin(q1),cos(q1),0|0,0,1",
  )

  let body = body_orienter(q1, q2, q3, "123") catch { _ => fail("body") }
  assert_true(
    matrix_expr_eq(body.rotation_matrix(), [
      [
        @symelem.cos(q2) * @symelem.cos(q3),
        @symelem.sin(q1) * @symelem.sin(q2) * @symelem.cos(q3) +
        @symelem.sin(q3) * @symelem.cos(q1),
        @symelem.sin(q1) * @symelem.sin(q3) -
        @symelem.sin(q2) * @symelem.cos(q1) * @symelem.cos(q3),
      ],
      [
        @symcore.int(-1) * @symelem.sin(q3) * @symelem.cos(q2),
        @symcore.int(-1) *
        @symelem.sin(q1) *
        @symelem.sin(q2) *
        @symelem.sin(q3) +
        @symelem.cos(q1) * @symelem.cos(q3),
        @symelem.sin(q1) * @symelem.cos(q3) +
        @symelem.sin(q2) * @symelem.sin(q3) * @symelem.cos(q1),
      ],
      [
        @symelem.sin(q2),
        @symcore.int(-1) * @symelem.sin(q1) * @symelem.cos(q2),
        @symelem.cos(q1) * @symelem.cos(q2),
      ],
    ]),
  )

  let space = space_orienter(q1, q2, q3, "123") catch { _ => fail("space") }
  assert_true(
    matrix_expr_eq(space.rotation_matrix(), [
      [
        @symelem.cos(q2) * @symelem.cos(q3),
        @symelem.sin(q3) * @symelem.cos(q2),
        @symcore.int(-1) * @symelem.sin(q2),
      ],
      [
        @symelem.sin(q1) * @symelem.sin(q2) * @symelem.cos(q3) -
        @symelem.sin(q3) * @symelem.cos(q1),
        @symelem.sin(q1) * @symelem.sin(q2) * @symelem.sin(q3) +
        @symelem.cos(q1) * @symelem.cos(q3),
        @symelem.sin(q1) * @symelem.cos(q2),
      ],
      [
        @symelem.sin(q1) * @symelem.sin(q3) +
        @symelem.sin(q2) * @symelem.cos(q1) * @symelem.cos(q3),
        @symcore.int(-1) * @symelem.sin(q1) * @symelem.cos(q3) +
        @symelem.sin(q2) * @symelem.sin(q3) * @symelem.cos(q1),
        @symelem.cos(q1) * @symelem.cos(q2),
      ],
    ]),
  )

  let quat = quaternion_orienter(q1, q2, q3, q4)
  assert_true(
    matrix_expr_eq(quat.rotation_matrix(), [
      [
        (q1 ^ @symcore.int(2)) +
        (q2 ^ @symcore.int(2)) -
        (q3 ^ @symcore.int(2)) -
        (q4 ^ @symcore.int(2)),
        @symcore.int(2) * (q1 * q4 + q2 * q3),
        @symcore.int(2) * (@symcore.int(-1) * q1 * q3 + q2 * q4),
      ],
      [
        @symcore.int(2) * (@symcore.int(-1) * q1 * q4 + q2 * q3),
        (q1 ^ @symcore.int(2)) -
        (q2 ^ @symcore.int(2)) +
        (q3 ^ @symcore.int(2)) -
        (q4 ^ @symcore.int(2)),
        @symcore.int(2) * (q1 * q2 + q3 * q4),
      ],
      [
        @symcore.int(2) * (q1 * q3 + q2 * q4),
        @symcore.int(2) * (@symcore.int(-1) * q1 * q2 + q3 * q4),
        (q1 ^ @symcore.int(2)) -
        (q2 ^ @symcore.int(2)) -
        (q3 ^ @symcore.int(2)) +
        (q4 ^ @symcore.int(2)),
      ],
    ]),
  )

  let body_sys = n.orient_new_body("B", q1, q2, q3, "123") catch {
    _ => fail("body-sys")
  }
  let space_sys = n.orient_new_space("S", q1, q2, q3, "123") catch {
    _ => fail("space-sys")
  }
  let quat_sys = n.orient_new_quaternion("Q", q1, q2, q3, q4) catch {
    _ => fail("quat-sys")
  }
  assert_true(
    matrix_expr_eq(
      body_sys.rotation_matrix(n) catch {
        _ => fail("body-rot")
      },
      body.rotation_matrix().rows_copy(),
    ),
  )
  assert_true(
    matrix_expr_eq(
      space_sys.rotation_matrix(n) catch {
        _ => fail("space-rot")
      },
      space.rotation_matrix().rows_copy(),
    ),
  )
  assert_true(
    matrix_expr_eq(
      quat_sys.rotation_matrix(n) catch {
        _ => fail("quat-rot")
      },
      quat.rotation_matrix().rows_copy(),
    ),
  )
  assert_true(
    (n.orient_new("A", [orienter_axis(axis_orienter(q1, n.k().to_vector()))]) catch {
      _ => fail("orient-new")
    }) ==
    (n.orient_new_axis("A", q1, n.k().to_vector()) catch {
      _ => fail("orient-axis")
    }),
  )
}

///|
test "create_new exposes transformations and change of basis" {
  let a = coord_sys3d("A") catch { _ => fail("A") }
  let s = a.create_new("S", "spherical") catch { _ => fail("S") }
  let theta = s.y().expr()
  let phi = s.z().expr()

  let to_parent = s.transformation_to_parent()
  assert_true(
    expr_eq(
      to_parent[0],
      s.x().expr() * @symelem.sin(s.y().expr()) * @symelem.cos(s.z().expr()),
    ),
  )
  assert_true(
    expr_eq(
      to_parent[1],
      s.x().expr() * @symelem.sin(s.y().expr()) * @symelem.sin(s.z().expr()),
    ),
  )
  assert_true(expr_eq(to_parent[2], s.x().expr() * @symelem.cos(s.y().expr())))
  let from_parent = s.transformation_from_parent() catch {
    _ => fail("from-parent")
  }
  let radius = @symelem.sqrt(
    (a.x().expr() ^ @symcore.int(2)) +
    (a.y().expr() ^ @symcore.int(2)) +
    (a.z().expr() ^ @symcore.int(2)),
  )
  assert_true(expr_eq(from_parent[0], radius))
  assert_true(
    expr_eq(
      from_parent[1],
      @symelem.acos(a.z().expr() * (radius ^ @symcore.int(-1))),
    ),
  )
  assert_true(
    expr_eq(from_parent[2], @symelem.atan2(a.y().expr(), a.x().expr())),
  )

  let from_parent_fn = s.transformation_from_parent_function() catch {
    _ => fail("from-parent-fn")
  }
  let from_parent_applied = from_parent_fn.call(
    a.x().expr(),
    a.y().expr(),
    a.z().expr(),
  )
  assert_true(expr_eq(from_parent_applied[0], from_parent[0]))
  assert_true(expr_eq(from_parent_applied[1], from_parent[1]))
  assert_true(expr_eq(from_parent_applied[2], from_parent[2]))

  assert_true(
    matrix_expr_eq(
      a.change_of_basis_matrix_from(s) catch {
        _ => fail("cob")
      },
      [
        [
          @symelem.sin(theta) * @symelem.cos(phi),
          @symelem.cos(theta) * @symelem.cos(phi),
          @symcore.int(-1) * @symelem.sin(phi),
        ],
        [
          @symelem.sin(theta) * @symelem.sin(phi),
          @symelem.cos(theta) * @symelem.sin(phi),
          @symelem.cos(phi),
        ],
        [
          @symelem.cos(theta),
          @symcore.int(-1) * @symelem.sin(theta),
          @symcore.int(0),
        ],
      ],
    ),
  )
}

///|
test "generic lambda and tuple transformations follow coordsysrect semantics" {
  let a = coord_sys3d("A") catch { _ => fail("A") }
  let lambda_transform = coord_transform_lambda([
    @symcore.int(2) * Symbol("x"),
    Symbol("z"),
    Symbol("y"),
  ]) catch {
    _ => fail("lambda-transform")
  }
  let root_lambda = coord_sys3d_with_transform(
    "L",
    transformation=Some(lambda_transform),
  ) catch {
    _ => fail("root-lambda")
  }
  assert_true(Show::to_string(root_lambda.x()) == "L.x1")
  assert_true(Show::to_string(root_lambda.y()) == "L.x2")
  assert_true(Show::to_string(root_lambda.z()) == "L.x3")

  let b = a.create_new_with_transform("B", lambda_transform) catch {
    _ => fail("B")
  }
  let b_to_parent = b.transformation_to_parent()
  assert_true(expr_eq(b_to_parent[0], @symcore.int(2) * b.x().expr()))
  assert_true(expr_eq(b_to_parent[1], b.z().expr()))
  assert_true(expr_eq(b_to_parent[2], b.y().expr()))
  let b_from_parent = b.transformation_from_parent() catch {
    _ => fail("B-from-parent")
  }
  assert_true(
    expr_eq(
      b_from_parent[0],
      a.x().expr() * (@symcore.int(2) ^ @symcore.int(-1)),
    ),
  )
  assert_true(expr_eq(b_from_parent[1], a.z().expr()))
  assert_true(expr_eq(b_from_parent[2], a.y().expr()))
  assert_true(
    matrix_expr_eq(
      a.change_of_basis_matrix_from(b) catch {
        _ => fail("A<-B")
      },
      [
        [@symcore.int(2), @symcore.int(0), @symcore.int(0)],
        [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
        [@symcore.int(0), @symcore.int(1), @symcore.int(0)],
      ],
    ),
  )
  assert_true(
    matrix_expr_eq(
      b.change_of_basis_matrix_from(a) catch {
        _ => fail("B<-A")
      },
      [
        [@symcore.int(2) ^ @symcore.int(-1), @symcore.int(0), @symcore.int(0)],
        [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
        [@symcore.int(0), @symcore.int(1), @symcore.int(0)],
      ],
    ),
  )
  assert_true(
    scalar_map_text(b.scalar_map(a) catch { _ => fail("B-map") }) ==
    "B.x1=A.x/2|B.x2=A.z|B.x3=A.y",
  )

  let tuple_transform = coord_transform_tuple(
    @symphysics.explicit_matrix_from_rows([
      [@symcore.int(1), @symcore.int(0), @symcore.int(0)],
      [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
      [@symcore.int(0), @symcore.int(1), @symcore.int(0)],
    ]) catch {
      _ => fail("tuple-matrix")
    },
    vector_from_terms([(@symcore.int(2), a.i()), (@symcore.int(3), a.j())]),
  ) catch {
    _ => fail("tuple-transform")
  }
  let c = a.create_new_with_transform("C", tuple_transform) catch {
    _ => fail("C")
  }
  let c_to_parent = c.transformation_to_parent()
  assert_true(expr_eq(c_to_parent[0], c.x().expr() + @symcore.int(2)))
  assert_true(expr_eq(c_to_parent[1], c.z().expr() + @symcore.int(3)))
  assert_true(expr_eq(c_to_parent[2], c.y().expr()))
  let c_from_parent = c.transformation_from_parent() catch {
    _ => fail("C-from-parent")
  }
  assert_true(expr_eq(c_from_parent[0], a.x().expr() + @symcore.int(-2)))
  assert_true(expr_eq(c_from_parent[1], a.z().expr()))
  assert_true(expr_eq(c_from_parent[2], a.y().expr() + @symcore.int(-3)))
  assert_true(
    matrix_expr_eq(c.rotation_matrix(a) catch { _ => fail("C-rot") }, [
      [@symcore.int(1), @symcore.int(0), @symcore.int(0)],
      [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
      [@symcore.int(0), @symcore.int(1), @symcore.int(0)],
    ]),
  )
  assert_true(
    matrix_expr_eq(
      a.change_of_basis_matrix_from(c) catch {
        _ => fail("A<-C")
      },
      [
        [@symcore.int(1), @symcore.int(0), @symcore.int(0)],
        [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
        [@symcore.int(0), @symcore.int(1), @symcore.int(0)],
      ],
    ),
  )
}

///|
test "basisdependent component-wise expr propagation stays on scalar coefficients" {
  let c = coord_sys3d("C") catch { _ => fail("C") }
  let trig_coeff = (@symelem.sin(c.x().expr()) ^ @symcore.int(2)) +
    (@symelem.cos(c.x().expr()) ^ @symcore.int(2))
  let trig_vector = vector_from_terms([
    (trig_coeff, c.i()),
    (c.x().expr() * (c.x().expr() + @symcore.int(1)), c.j()),
  ])
  assert_true(
    Show::to_string(trig_vector.trigsimp()) == "C.i + C.x*(C.x + 1)*C.j",
  )
  let factored_vector = vector_from_terms([
    ((c.x().expr() ^ @symcore.int(2)) + c.x().expr(), c.j()),
  ])
  assert_true(Show::to_string(factored_vector.factor()) == "C.x*(C.x + 1)*C.j")
  assert_true(
    vector_from_terms([
      (@symelem.sqrt(@symcore.int(2)), c.i()),
      (NumberSymbol(Pi), c.j()),
    ])
    .evalf(prec=80)
    .components()
    .length() ==
    2,
  )

  let trig_dyadic = (c.i().outer(c.j()) catch { _ => fail("outer") }).scale(
    trig_coeff,
  )
  assert_true(Show::to_string(trig_dyadic.trigsimp()) == "(C.i|C.j)")
  let factored_dyadic = (c.i().outer(c.j()) catch { _ => fail("outer-2") }).scale(
    (c.x().expr() ^ @symcore.int(2)) + c.x().expr(),
  )
  assert_true(
    Show::to_string(factored_dyadic.factor()) == "C.x*(C.x + 1)*(C.i|C.j)",
  )
  assert_true(trig_dyadic.evalf(prec=80).components().length() == 1)
}
