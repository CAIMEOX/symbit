///|
fn strip_parens(text : String) -> String {
  text.replace_all(old="(", new="").replace_all(old=")", new="")
}

///|
fn matrix_text(matrix : @symphysics.ExplicitMatrix) -> String {
  matrix
  .rows_copy()
  .map(row => row.map(@symprint.to_string).join(","))
  .join("|")
}

///|
fn matrix_py_expr(matrix : @symphysics.ExplicitMatrix) -> String {
  let rows = matrix.rows_copy()
  "sympy.Matrix([" +
  rows.map(row => "[" + row.map(@symprint.to_string).join(",") + "]").join(",") +
  "])"
}

///|
fn matrix_matches_sympy(
  matrix : @symphysics.ExplicitMatrix,
  system_name : String,
  system_expr : String,
  py_expected : String,
) -> Bool raise {
  vector_eval_str(
    "(lambda " +
    system_name +
    ", Derivative, u, v, w: str(all(sympy.simplify(x) == 0 for row in ((" +
    matrix_py_expr(matrix) +
    ") - (" +
    py_expected +
    ")).tolist() for x in row)))(" +
    system_expr +
    ", sympy.Derivative, sympy.Function('u'), sympy.Function('v'), sympy.Function('w')" +
    ")",
  ) ==
  "True"
}

///|
fn scalar_map_text(
  mapping : Map[@symvector.BaseScalar, @symcore.Expr],
) -> String {
  let keys = mapping.keys().to_array()
  keys.sort()
  keys
  .map(key => key.to_string() + "=" + @symprint.to_string(mapping[key]))
  .join("|")
}

///|
test "vector root objects parity for names and basis" {
  let c = @symvector.coord_sys3d("C") catch { _ => fail("C") }
  assert_eq(
    c.x().to_string(),
    vector_eval_str(
      "str(__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C').x)",
    ),
  )
  assert_eq(
    c.i().to_string(),
    vector_eval_str(
      "str(__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C').i)",
    ),
  )
  assert_eq(
    c.k().kind().to_string(),
    vector_eval_str(
      "repr(__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C').i.kind)",
    ),
  )
}

///|
test "axis orientation parity for rotation matrix scalar map and express" {
  let q = @symcore.Expr::Symbol("q")
  let c = @symvector.coord_sys3d("C") catch { _ => fail("C") }
  let b = c.orient_new_axis("B", q, c.k().to_vector()) catch { _ => fail("B") }

  assert_eq(
    matrix_text(c.rotation_matrix(b) catch { _ => fail("rot") }),
    vector_eval_str(
      "(lambda V, C, q: '|'.join(','.join(str(x) for x in row) for row in C.rotation_matrix(V).tolist()))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C').orient_new_axis('B', sympy.Symbol('q'), __import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C').k)," +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C'), sympy.Symbol('q'))",
    ),
  )

  assert_eq(
    scalar_map_text(c.scalar_map(b) catch { _ => fail("map") }),
    vector_eval_str(
      "(lambda C, B: '|'.join(str(k) + '=' + str(v) for k, v in sorted(C.scalar_map(B).items(), key=lambda kv: str(kv[0]))))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C')," +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C').orient_new_axis('B', sympy.Symbol('q'), __import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C').k))",
    ),
  )

  assert_eq(
    strip_parens(
      (@symvector.express(b.i().to_vector(), c) catch { _ => fail("express") }).to_string(),
    ),
    strip_parens(
      vector_eval_str(
        "(lambda V: str(V.express(V.CoordSys3D('C').orient_new_axis('B', sympy.Symbol('q'), V.CoordSys3D('C').k).i, V.CoordSys3D('C'))))(" +
        "__import__('sympy.vector', fromlist=['CoordSys3D', 'express']))",
      ),
    ),
  )
}

///|
test "point and field-function parity against repo sympy" {
  let c = @symvector.coord_sys3d("C") catch { _ => fail("C") }
  let p1 = c
    .origin()
    .locate_new(
      "p1",
      @symvector.vector_from_terms([
        (@symcore.int(2), c.i()),
        (@symcore.int(3), c.j()),
      ]),
    ) catch {
      _ => fail("p1")
    }
  let p2 = p1.locate_new("p2", c.k().to_vector()) catch { _ => fail("p2") }
  let field = @symvector.vector_from_terms([
    (c.y().expr() * c.z().expr(), c.i()),
    (c.x().expr() * c.z().expr(), c.j()),
    (c.x().expr() * c.y().expr(), c.k()),
  ])
  let direction = @symvector.vector_from_terms([
    (@symcore.int(3), c.i()),
    (@symcore.int(4), c.j()),
    (@symcore.int(1), c.k()),
  ])

  assert_eq(
    (p2.position_wrt(@symvector.point_reference_coord_system(c)) catch {
      _ => fail("pos")
    }).to_string(),
    vector_eval_str(
      "(lambda C: str(C.origin.locate_new('p1', 2*C.i + 3*C.j).locate_new('p2', C.k).position_wrt(C)))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C'))",
    ),
  )
  assert_eq(
    (p2.express_coordinates(c) catch { _ => fail("coords") })
    .map(@symprint.to_string)
    .join("|"),
    vector_eval_str(
      "(lambda C: '|'.join(str(v) for v in C.origin.locate_new('p1', 2*C.i + 3*C.j).locate_new('p2', C.k).express_coordinates(C)))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C'))",
    ),
  )
  assert_eq(
    @symvector.gradient(c.x().expr() * c.y().expr() * c.z().expr()).to_string(),
    vector_eval_str(
      "(lambda C: str(__import__('sympy.vector', fromlist=['gradient']).gradient(C.x*C.y*C.z)))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C'))",
    ),
  )
  assert_eq(
    @symprint.to_string(@symvector.divergence(field) catch { _ => fail("div") }),
    vector_eval_str(
      "(lambda C: str(__import__('sympy.vector', fromlist=['divergence']).divergence(C.y*C.z*C.i + C.x*C.z*C.j + C.x*C.y*C.k)))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C'))",
    ),
  )
  let dd = @symvector.directional_derivative(
    @symvector.scalar_or_vector_scalar(
      c.x().expr() * c.y().expr() * c.z().expr(),
    ),
    direction,
  ) catch {
    _ => fail("dd")
  }
  match dd {
    @symvector.ScalarOrVector::ScalarExpr(value) =>
      assert_eq(
        vector_eval_str(
          "(lambda C: str(sympy.simplify((" +
          @symprint.to_string(value) +
          ") - (__import__('sympy.vector', fromlist=['directional_derivative']).directional_derivative(C.x*C.y*C.z, 3*C.i + 4*C.j + C.k)))))(" +
          "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C'))",
        ),
        "0",
      )
    @symvector.ScalarOrVector::VectorExpr(_) => fail("expected scalar result")
  }
  assert_eq(
    @symprint.to_string(
      @symvector.scalar_potential_difference(
        @symvector.scalar_or_vector_vector(field),
        c,
        p1,
        p2,
      ) catch {
        _ => fail("potential-diff")
      },
    ),
    vector_eval_str(
      "(lambda C: str(__import__('sympy.vector', fromlist=['scalar_potential_difference']).scalar_potential_difference(" +
      "C.y*C.z*C.i + C.x*C.z*C.j + C.x*C.y*C.k, C, C.origin.locate_new('p1', 2*C.i + 3*C.j), C.origin.locate_new('p1', 2*C.i + 3*C.j).locate_new('p2', C.k))))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C'))",
    ),
  )
}

///|
test "del operator parity against repo sympy" {
  let c = @symvector.coord_sys3d("C") catch { _ => fail("C") }
  let x = c.x().expr()
  let y = c.y().expr()
  let z = c.z().expr()
  let v = @symvector.vector_from_terms([
    (x * y * z, c.i()),
    (x * y * z, c.j()),
    (x * y * z, c.k()),
  ])

  assert_eq(@symvector.delop.to_string(), "delop")
  assert_eq(
    matrix_text(
      @symvector.delop.gradient(x).to_matrix(c) catch {
        _ => fail("del-grad")
      },
    ),
    vector_eval_str(
      "(lambda C, D: '|'.join(str(x[0]) for x in D().gradient(C.x).to_matrix(C).tolist()))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C')," +
      "__import__('sympy.vector.deloperator', fromlist=['Del']).Del)",
    ),
  )
  assert_eq(
    @symprint.to_string(@symvector.delop.dot(v) catch { _ => fail("del-dot") }),
    vector_eval_str(
      "(lambda C, D: str(D().dot(C.x*C.y*C.z*(C.i + C.j + C.k))))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C')," +
      "__import__('sympy.vector.deloperator', fromlist=['Del']).Del)",
    ),
  )
  assert_eq(
    (@symvector.delop.cross(
      @symvector.vector_term(@symcore.int(2) * (x ^ @symcore.int(2)), c.j()),
      doit=true,
    ) catch {
      _ => fail("del-cross")
    }).to_string(),
    vector_eval_str(
      "(lambda C, D: str(D().cross(2*C.x**2*C.j, doit=True)))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C')," +
      "__import__('sympy.vector.deloperator', fromlist=['Del']).Del)",
    ),
  )
}

///|
test "curvilinear field-function parity against repo sympy" {
  let a = @symvector.coord_sys3d(
    "A",
    transformation=Some("spherical"),
    variable_names=Some(["r", "theta", "phi"]),
  ) catch {
    _ => fail("A")
  }
  let b = @symvector.coord_sys3d(
    "B",
    transformation=Some("cylindrical"),
    variable_names=Some(["r", "theta", "z"]),
  ) catch {
    _ => fail("B")
  }
  let r = b.x().expr()
  let theta = b.y().expr()
  let zz = b.z().expr()
  let u = @symcore.applied_undefined_function("u", [r, theta, zz])
  let v = @symcore.applied_undefined_function("v", [r, theta, zz])
  let w = @symcore.applied_undefined_function("w", [r, theta, zz])
  let vec = @symvector.vector_from_terms([(u, b.i()), (v, b.j()), (w, b.k())])
  let a_py = "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('A', transformation='spherical', variable_names=['r', 'theta', 'phi'])"
  let b_py = "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('B', transformation='cylindrical', variable_names=['r', 'theta', 'z'])"
  let grad_sph = @symvector.gradient(
    @symcore.int(3) * a.x().expr() + @symcore.int(4) * a.y().expr(),
  ).to_matrix(a) catch {
    _ => fail("grad-sph")
  }
  let div_cyl = @symvector.divergence(
    @symvector.vector_from_terms([
      (b.x().expr(), b.i()),
      (b.y().expr(), b.j()),
      (b.z().expr(), b.k()),
    ]),
  ) catch {
    _ => fail("div-cyl")
  }
  let grad_vec_cyl = (@symvector.gradient_vector(vec) catch {
    _ => fail("grad-vec-cyl")
  }).to_matrix(b) catch {
    _ => fail("grad-vec-cyl-mat")
  }

  assert_eq(
    matrix_matches_sympy(
      grad_sph, "A", a_py, "__import__('sympy.vector', fromlist=['gradient']).gradient(3*A.r + 4*A.theta).to_matrix(A)",
    ) catch {
      _ => fail("grad-sph-parity")
    },
    true,
  )
  assert_eq(
    vector_eval_str(
      "(lambda B: str(sympy.simplify((" +
      @symprint.to_string(div_cyl) +
      ") - (__import__('sympy.vector', fromlist=['divergence']).divergence(B.r*B.i + B.theta*B.j + B.z*B.k)))))(" +
      b_py +
      ")",
    ),
    "0",
  )
  assert_eq(
    (@symvector.curl(
      @symvector.vector_from_terms([
        (b.x().expr(), b.j()),
        (b.z().expr(), b.k()),
      ]),
    ) catch {
      _ => fail("curl-cyl")
    }).to_string(),
    vector_eval_str(
      "(lambda B: str(__import__('sympy.vector', fromlist=['curl']).curl(B.r*B.j + B.z*B.k)))(" +
      b_py +
      ")",
    ),
  )
  let scalar_dd = @symvector.directional_derivative(
    @symvector.scalar_or_vector_scalar(
      @symcore.int(5) * (a.x().expr() ^ @symcore.int(2)) * a.z().expr(),
    ),
    @symvector.vector_from_terms([
      (@symcore.int(3), a.i()),
      (@symcore.int(4), a.j()),
      (@symcore.int(1), a.k()),
    ]),
  ) catch {
    _ => fail("dd-sph")
  }
  match scalar_dd {
    @symvector.ScalarOrVector::ScalarExpr(value) =>
      assert_eq(
        vector_eval_str(
          "(lambda A: str(sympy.simplify((" +
          @symprint.to_string(value) +
          ") - (__import__('sympy.vector', fromlist=['directional_derivative']).directional_derivative(5*A.r**2*A.phi, 3*A.i + 4*A.j + A.k)))))(" +
          a_py +
          ")",
        ),
        "0",
      )
    @symvector.ScalarOrVector::VectorExpr(_) => fail("expected scalar result")
  }
  assert_eq(
    matrix_matches_sympy(
      grad_vec_cyl,
      "B",
      b_py,
      "__import__('sympy.vector', fromlist=['gradient']).gradient(" +
      "sympy.Function('u')(B.r, B.theta, B.z)*B.i + sympy.Function('v')(B.r, B.theta, B.z)*B.j + sympy.Function('w')(B.r, B.theta, B.z)*B.k).to_matrix(B)",
    ) catch {
      _ => fail("grad-vec-cyl-parity")
    },
    true,
  )
}

///|
test "operator wrappers and vector gradient parity against repo sympy" {
  let c = @symvector.coord_sys3d("C") catch { _ => fail("C") }
  let x = c.x().expr()
  let y = c.y().expr()
  let z = c.z().expr()
  let u = @symcore.applied_undefined_function("u", [x, y, z])
  let v = @symcore.applied_undefined_function("v", [x, y, z])
  let w = @symcore.applied_undefined_function("w", [x, y, z])
  let vec = @symvector.vector_from_terms([(u, c.i()), (v, c.j()), (w, c.k())])
  let scalar_grad = @symvector.gradient_unevaluated(
    @symvector.scalar_or_vector_scalar(x * y * z),
  )
  let vector_grad = @symvector.gradient_unevaluated(
    @symvector.scalar_or_vector_vector(vec),
  )
  let div = @symvector.divergence_unevaluated(
    @symvector.vector_from_terms([
      (y * z, c.i()),
      (x * z, c.j()),
      (x * y, c.k()),
    ]),
  )
  let curl_op = @symvector.curl_unevaluated(
    @symvector.vector_from_terms([
      (y * z, c.i()),
      (x * z, c.j()),
      (x * y, c.k()),
    ]),
  )

  assert_eq(
    scalar_grad.to_string(),
    vector_eval_str(
      "(lambda C: str(__import__('sympy.vector.operators', fromlist=['Gradient']).Gradient(C.x*C.y*C.z)))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C'))",
    ),
  )
  assert_eq(
    div.to_string(),
    vector_eval_str(
      "(lambda C: str(__import__('sympy.vector.operators', fromlist=['Divergence']).Divergence(C.y*C.z*C.i + C.x*C.z*C.j + C.x*C.y*C.k)))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C'))",
    ),
  )
  assert_eq(
    curl_op.to_string(),
    vector_eval_str(
      "(lambda C: str(__import__('sympy.vector.operators', fromlist=['Curl']).Curl(C.y*C.z*C.i + C.x*C.z*C.j + C.x*C.y*C.k)))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C'))",
    ),
  )
  let scalar_grad_value = scalar_grad.doit() catch {
    _ => fail("scalar-grad-doit")
  }
  match scalar_grad_value {
    @symvector.GradientValue::VectorValue(value) =>
      assert_eq(
        value.to_string(),
        vector_eval_str(
          "(lambda C: str(__import__('sympy.vector.operators', fromlist=['Gradient']).Gradient(C.x*C.y*C.z).doit()))(" +
          "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C'))",
        ),
      )
    @symvector.GradientValue::DyadicValue(_) => fail("expected vector result")
  }
  let vector_grad_value = vector_grad.doit() catch {
    _ => fail("vector-grad-doit")
  }
  match vector_grad_value {
    @symvector.GradientValue::DyadicValue(value) =>
      assert_eq(
        matrix_text(value.to_matrix(c) catch { _ => fail("vector-grad-mat") }),
        vector_eval_str(
          "(lambda C: '|'.join(','.join(str(x) for x in row) for row in __import__('sympy.vector', fromlist=['gradient']).gradient(" +
          "sympy.Function('u')(C.x, C.y, C.z)*C.i + sympy.Function('v')(C.x, C.y, C.z)*C.j + sympy.Function('w')(C.x, C.y, C.z)*C.k).to_matrix(C).tolist()))(" +
          "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C'))",
        ),
      )
    @symvector.GradientValue::VectorValue(_) => fail("expected dyadic result")
  }
}

///|
test "dyadic parity against repo sympy" {
  let q = @symcore.Expr::Symbol("q")
  let c = @symvector.coord_sys3d("C") catch { _ => fail("C") }
  let b = c.orient_new_axis("B", q, c.k().to_vector()) catch { _ => fail("B") }
  let d1 = c.i().outer(c.i()) catch { _ => fail("d1") }
  let d2 = c.i().outer(c.j()) catch { _ => fail("d2") }

  assert_eq(
    d1.to_string(),
    vector_eval_str(
      "(lambda C: str(C.i.outer(C.i)))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C'))",
    ),
  )
  assert_eq(
    matrix_text(d1.to_matrix(c, system2=Some(b)) catch { _ => fail("mat") }),
    vector_eval_str(
      "(lambda C, B: '|'.join(','.join(str(x) for x in row) for row in C.i.outer(C.i).to_matrix(C, B).tolist()))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C')," +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C').orient_new_axis('B', sympy.Symbol('q'), __import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C').k))",
    ),
  )
  assert_eq(
    @symvector.matrix_to_dyadic(
      @symphysics.explicit_matrix_from_rows([
        [@symcore.int(1), @symcore.int(2), @symcore.int(3)],
        [@symcore.int(4), @symcore.int(5), @symcore.int(6)],
        [@symcore.int(7), @symcore.int(8), @symcore.int(9)],
      ]) catch {
        _ => fail("srcmat")
      },
      c,
    ).to_string(),
    vector_eval_str(
      "(lambda C: str(__import__('sympy.vector', fromlist=['matrix_to_dyadic']).matrix_to_dyadic(sympy.Matrix([[1,2,3],[4,5,6],[7,8,9]]), C)))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C'))",
    ),
  )
  assert_eq(
    vector_eval_str(
      "(lambda C, B, q: '|'.join(str(sympy.simplify(x)) for row in ((" +
      matrix_py_expr(
        (@symvector.express_dyadic(d2, b) catch { _ => fail("express_d") }).to_matrix(
          b,
        ) catch {
          _ => fail("express_d_mat")
        },
      ) +
      ") - __import__('sympy.vector', fromlist=['express']).express(C.i.outer(C.j), B).to_matrix(B)).tolist() for x in row))(" +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C')," +
      "__import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C').orient_new_axis('B', sympy.Symbol('q'), __import__('sympy.vector', fromlist=['CoordSys3D']).CoordSys3D('C').k)," +
      "sympy.Symbol('q'))",
    ),
    "0|0|0|0|0|0|0|0|0",
  )
}
