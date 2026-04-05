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
  .map(row => row.map(@symprint.to_string).join(","))
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

  assert_eq(delop.to_string(), "delop")
  assert_eq(
    matrix_text(delop.gradient(x).to_matrix(c) catch { _ => fail("del-grad") }),
    "Derivative(C.x, C.x)|Derivative(C.x, C.y)|Derivative(C.x, C.z)",
  )
  assert_eq(delop.call(x * y * z), delop.gradient(x * y * z))
  assert_eq(
    delop.gradient(x * y * z, doit=true).to_string(),
    "C.y*C.z*C.i + C.x*C.z*C.j + C.x*C.y*C.k",
  )
  assert_eq(
    expr_eq(
      delop.dot(v) catch {
        _ => fail("del-dot")
      },
      @symcore.derivative(x * y * z, x) +
      @symcore.derivative(x * y * z, y) +
      @symcore.derivative(x * y * z, z),
    ),
    true,
  )
  assert_eq(
    (delop.cross(
      vector_term(@symcore.int(2) * (x ^ @symcore.int(2)), c.j()),
      doit=true,
    ) catch {
      _ => fail("del-curl")
    }).to_string(),
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
      assert_eq(expr_eq(value, expected), true)
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

  assert_eq(
    matrix_text(
      gradient(@symcore.int(3) * a.x().expr() + @symcore.int(4) * a.y().expr()).to_matrix(
        a,
      ) catch {
        _ => fail("grad-sph")
      },
    ),
    "3|4/A.r|0",
  )
  assert_eq(
    matrix_text(
      gradient(b.x().expr() * b.y().expr() * b.z().expr()).to_matrix(b) catch {
        _ => fail("grad-cyl")
      },
    ),
    "B.z*B.theta|B.z|B.r*B.theta",
  )
  assert_eq(
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
    ),
    true,
  )
  assert_eq(
    (curl(vector_from_terms([(b.x().expr(), b.j()), (b.z().expr(), b.k())])) catch {
      _ => fail("curl-cyl")
    }).to_string(),
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
    ScalarOrVector::ScalarExpr(value) =>
      assert_eq(
        expr_eq(
          value,
          @symcore.int(5) *
          a.x().expr() *
          (@symcore.function("sin", [a.y().expr()]) ^ @symcore.int(-1)) +
          @symcore.int(30) * a.x().expr() * a.z().expr(),
        ),
        true,
      )
    ScalarOrVector::VectorExpr(_) => fail("expected scalar result")
  }

  let r = b.x().expr()
  let theta = b.y().expr()
  let zz = b.z().expr()
  let u = @symcore.applied_undefined_function("u", [r, theta, zz])
  let v = @symcore.applied_undefined_function("v", [r, theta, zz])
  let w = @symcore.applied_undefined_function("w", [r, theta, zz])
  let vec = vector_from_terms([(u, b.i()), (v, b.j()), (w, b.k())])
  let grad_vec_cyl = gradient_vector(vec) catch { _ => fail("grad-vec-cyl") }
  assert_eq(
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
    ),
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
    ScalarOrVector::ScalarExpr(value) =>
      assert_eq(
        expr_eq(
          value,
          @symcore.int(5) * (x ^ @symcore.int(2)) + @symcore.int(30) * x * z,
        ),
        true,
      )
    ScalarOrVector::VectorExpr(_) => fail("expected scalar result")
  }

  let dd_zero = directional_derivative(
    scalar_or_vector_scalar(@symcore.int(5) * (x ^ @symcore.int(2)) * z),
    c.j().to_vector().scale(@symcore.int(4)),
  ) catch {
    _ => fail("dd-zero")
  }
  match dd_zero {
    ScalarOrVector::ScalarExpr(value) =>
      assert_eq(@symprint.to_string(value), "0")
    ScalarOrVector::VectorExpr(_) => fail("expected scalar result")
  }

  let dd_vector = directional_derivative(scalar_or_vector_vector(vec), dir) catch {
    _ => fail("dd-vector")
  }
  match dd_vector {
    ScalarOrVector::VectorExpr(value) =>
      assert_eq(
        matrix_text(value.to_matrix(c) catch { _ => fail("dd-vector-mat") }),
        "Derivative(u(C.x, C.y, C.z), C.x) + Derivative(u(C.x, C.y, C.z), C.y) + Derivative(u(C.x, C.y, C.z), C.z)|Derivative(v(C.x, C.y, C.z), C.x) + Derivative(v(C.x, C.y, C.z), C.y) + Derivative(v(C.x, C.y, C.z), C.z)|Derivative(w(C.x, C.y, C.z), C.x) + Derivative(w(C.x, C.y, C.z), C.y) + Derivative(w(C.x, C.y, C.z), C.z)",
      )
    ScalarOrVector::ScalarExpr(_) => fail("expected vector result")
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
  assert_eq(grad_scalar.to_string(), "Gradient(C.x*C.y*C.z)")
  let grad_scalar_value = grad_scalar.doit() catch { _ => fail("grad-scalar") }
  match grad_scalar_value {
    GradientValue::VectorValue(value) =>
      assert_eq(value.to_string(), "C.y*C.z*C.i + C.x*C.z*C.j + C.x*C.y*C.k")
    GradientValue::DyadicValue(_) => fail("expected vector result")
  }

  let grad_vector = gradient_unevaluated(scalar_or_vector_vector(vec))
  assert_eq(
    grad_vector.to_string(),
    "Gradient(u(C.x, C.y, C.z)*C.i + v(C.x, C.y, C.z)*C.j + w(C.x, C.y, C.z)*C.k)",
  )
  let grad_vector_value = grad_vector.doit() catch { _ => fail("grad-vector") }
  match grad_vector_value {
    GradientValue::DyadicValue(value) =>
      assert_eq(
        matrix3_text(value.to_matrix(c) catch { _ => fail("grad-mat") }),
        "Derivative(u(C.x, C.y, C.z), C.x),Derivative(v(C.x, C.y, C.z), C.x),Derivative(w(C.x, C.y, C.z), C.x)|Derivative(u(C.x, C.y, C.z), C.y),Derivative(v(C.x, C.y, C.z), C.y),Derivative(w(C.x, C.y, C.z), C.y)|Derivative(u(C.x, C.y, C.z), C.z),Derivative(v(C.x, C.y, C.z), C.z),Derivative(w(C.x, C.y, C.z), C.z)",
      )
    GradientValue::VectorValue(_) => fail("expected dyadic result")
  }

  let div = divergence_unevaluated(vector_field)
  assert_eq(
    div.to_string(),
    "Divergence(C.y*C.z*C.i + C.x*C.z*C.j + C.x*C.y*C.k)",
  )
  assert_eq(
    @symprint.to_string(div.doit() catch { _ => fail("div-doit") }),
    "0",
  )

  let curl_op = curl_unevaluated(vector_field)
  assert_eq(
    curl_op.to_string(),
    "Curl(C.y*C.z*C.i + C.x*C.z*C.j + C.x*C.y*C.k)",
  )
  assert_eq((curl_op.doit() catch { _ => fail("curl-doit") }).to_string(), "0")
}

///|
test "dyadics support outer products and matrix conversion" {
  let q = @symcore.Expr::Symbol("q")
  let c = coord_sys3d("C") catch { _ => fail("C") }
  let b = c.orient_new_axis("B", q, c.k().to_vector()) catch { _ => fail("B") }
  let d1 = c.i().outer(c.i()) catch { _ => fail("d1") }
  let d2 = c.i().outer(c.j()) catch { _ => fail("d2") }
  let v = vector_from_terms([
    (@symcore.Expr::Symbol("a"), c.i()),
    (@symcore.Expr::Symbol("b"), c.j()),
    (@symcore.Expr::Symbol("c"), c.k()),
  ])
  let w = vector_from_terms([
    (@symcore.Expr::Symbol("d"), c.i()),
    (@symcore.Expr::Symbol("e"), c.j()),
    (@symcore.Expr::Symbol("f"), c.k()),
  ])

  assert_eq(d1.to_string(), "(C.i|C.i)")
  assert_eq(
    d1.dot_vector(c.i().to_vector()) catch {
      _ => fail("dotv")
    },
    c.i().to_vector(),
  )
  assert_eq(
    (d1.cross(c.k().to_vector()) catch { _ => fail("cross") }).to_string(),
    "-(C.i|C.j)",
  )
  assert_eq(
    matrix3_text(d1.to_matrix(c) catch { _ => fail("mat") }),
    "1,0,0|0,0,0|0,0,0",
  )
  assert_eq(
    matrix3_text(d1.to_matrix(c, system2=Some(b)) catch { _ => fail("mat2") }),
    "cos(q),-sin(q),0|0,0,0|0,0,0",
  )
  assert_eq(
    matrix_to_dyadic(
      @symphysics.explicit_matrix_from_rows([
        [@symcore.int(1), @symcore.int(2), @symcore.int(3)],
        [@symcore.int(4), @symcore.int(5), @symcore.int(6)],
        [@symcore.int(7), @symcore.int(8), @symcore.int(9)],
      ]) catch {
        _ => fail("srcmat")
      },
      c,
    ).to_string(),
    "(C.i|C.i) + 2*(C.i|C.j) + 3*(C.i|C.k) + 4*(C.j|C.i) + 5*(C.j|C.j) + 6*(C.j|C.k) + 7*(C.k|C.i) + 8*(C.k|C.j) + 9*(C.k|C.k)",
  )
  assert_eq(
    (v.outer(w) catch { _ => fail("outer") }).to_string(),
    "a*d*(C.i|C.i) + a*e*(C.i|C.j) + a*f*(C.i|C.k) + b*d*(C.j|C.i) + b*e*(C.j|C.j) + b*f*(C.j|C.k) + c*d*(C.k|C.i) + c*e*(C.k|C.j) + c*f*(C.k|C.k)",
  )
  assert_eq(
    matrix3_text(
      (express_dyadic(d2, b) catch { _ => fail("express_d") }).to_matrix(b) catch {
        _ => fail("express_d_mat")
      },
    ),
    "cos(q)*sin(q),cos(q)**2,0|-sin(q)**2,-cos(q)*sin(q),0|0,0,0",
  )
}
