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
