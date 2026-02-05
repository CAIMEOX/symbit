///|
test "polyhedron standard parity" {
  let names : Array[String] = [
    "tetrahedron", "cube", "octahedron", "dodecahedron", "icosahedron",
  ]
  let polys : Array[Polyhedron] = [
    tetrahedron.copy(),
    cube.copy(),
    octahedron.copy(),
    dodecahedron.copy(),
    icosahedron.copy(),
  ]
  for i in 0..<names.length() {
    let name = names[i]
    let poly = polys[i]
    let corner_strs : Array[String] = Array::new()
    for c in poly.corners() {
      corner_strs.push(@symprint.to_string(c))
    }
    assert_true(
      @sympy_combinatorics.polyhedron_corners_equiv(name, corner_strs),
    )
    assert_true(@sympy_combinatorics.polyhedron_faces_equiv(name, poly.faces()))
    assert_true(@sympy_combinatorics.polyhedron_edges_equiv(name, poly.edges()))
    let elems = poly.pgroup().elements()
    let elem_arrays : Array[Array[Int]] = Array::new()
    for p in elems {
      elem_arrays.push(p.array_form())
    }
    assert_true(
      @sympy_combinatorics.polyhedron_pgroup_elements_equiv(name, elem_arrays),
    )
  }
}

///|
test "polyhedron rotation parity" {
  let t = tetrahedron.copy()
  t.rotate(PolyRotate::Index(0))
  assert_true(
    @sympy_combinatorics.polyhedron_array_form_equiv_index(
      "tetrahedron",
      0,
      t.array_form(),
    ),
  )
  assert_true(
    @sympy_combinatorics.polyhedron_cyclic_form_equiv_index(
      "tetrahedron",
      0,
      t.cyclic_form(),
    ),
  )
  let perm = Permutation::from_array([0, 1, 3, 2])
  let t2 = tetrahedron.copy()
  t2.rotate(PolyRotate::Perm(perm))
  assert_true(
    @sympy_combinatorics.polyhedron_array_form_equiv_perm(
      "tetrahedron",
      perm.array_form(),
      t2.array_form(),
    ),
  )
}

///|
test "polyhedron reset" {
  let c = cube.copy()
  let original : Array[String] = Array::new()
  for v in c.corners() {
    original.push(@symprint.to_string(v))
  }
  c.rotate(PolyRotate::Index(0))
  c.reset()
  let after : Array[String] = Array::new()
  for v in c.corners() {
    after.push(@symprint.to_string(v))
  }
  assert_true(original == after)
}
