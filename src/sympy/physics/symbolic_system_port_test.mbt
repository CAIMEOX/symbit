///|
fn symbolic_system_entries_string(
  matrix : @symphysics.ExplicitMatrix,
) -> String {
  let rows = matrix.rows_copy()
  let items : Array[String] = []
  for i in 0..<matrix.height() {
    for j in 0..<matrix.width() {
      items.push(@symprint.to_string(rows[i][j]))
    }
  }
  "[" + items.join(", ") + "]"
}

///|
fn symbolic_system_summary_items(summary : String) -> Array[String] {
  let trimmed = summary.trim()
  if trimmed == "[]" {
    return []
  }
  let body = trimmed[1:trimmed.length() - 1].to_string()
  body.split(",").to_array().map(fn(part) { part.trim().to_string() })
}

///|
fn symbolic_system_oracle_prefix() -> String {
  [
    "from sympy import Matrix, atan, symbols\n", "from sympy.physics.mechanics import dynamicsymbols, Particle, Point, ReferenceFrame, SymbolicSystem\n",
    "x, y, u, v, lam = dynamicsymbols('x y u v lambda')\n", "m, l, g = symbols('m l g')\n",
    "dyn_implicit_mat = Matrix([[1, 0, -x/m], [0, 1, -y/m], [0, 0, l**2/m]])\n",
    "dyn_implicit_rhs = Matrix([0, 0, u**2 + v**2 - g*y])\n", "comb_implicit_mat = Matrix([[1, 0, 0, 0, 0], [0, 1, 0, 0, 0], [0, 0, 1, 0, -x/m], [0, 0, 0, 1, -y/m], [0, 0, 0, 0, l**2/m]])\n",
    "comb_implicit_rhs = Matrix([u, v, 0, 0, u**2 + v**2 - g*y])\n", "kin_explicit_rhs = Matrix([u, v])\n",
    "comb_explicit_rhs = comb_implicit_mat.LUsolve(comb_implicit_rhs)\n", "N = ReferenceFrame('SSN')\n",
    "O = Point('SSO')\n", "O.set_vel(N, 0)\n", "Pa = Particle('Pa', O, m)\n", "PE = symbols('PE')\n",
    "out_eqns = {PE: m*g*(l + y)}\n",
  ].join("")
}

///|
test "physics.mechanics parity symbolic system forms" {
  let (
    coordinates,
    speeds,
    states,
    dyn_implicit_mat,
    dyn_implicit_rhs,
    comb_implicit_mat,
    comb_implicit_rhs,
    kin_explicit_rhs,
    output_eqns,
    bodies,
    loads,
  ) = symbolic_system_fixture()
  let symsystem2 = symbolic_system(
    coordinates,
    comb_implicit_rhs,
    speeds=Some(speeds),
    mass_matrix=Some(comb_implicit_mat),
    alg_con=Some([4]),
    output_eqns~,
    bodies=Some(bodies),
    loads=Some(loads),
  )
  symsystem2.compute_explicit_form()
  let symsystem1 = symbolic_system(
    states,
    symsystem2.comb_explicit_rhs(),
    alg_con=Some([4]),
    output_eqns~,
    coord_idxs=Some([0, 1]),
    speed_idxs=Some([2, 3]),
    bodies=Some(bodies),
    loads=Some(loads),
  )
  let symsystem3 = symbolic_system(
    states,
    dyn_implicit_rhs,
    mass_matrix=Some(dyn_implicit_mat),
    coordinate_derivatives=Some(kin_explicit_rhs),
    alg_con=Some([2]),
    coord_idxs=Some([0, 1]),
    speed_idxs=Some([2, 3]),
    bodies=Some(bodies),
    loads=Some(loads),
  )

  let prefix = symbolic_system_oracle_prefix()
  assert_true(
    mechanics_matrix_equal(
        @symphysics.explicit_matrix_rows_string(symsystem1.coordinates()),
        prefix +
        "symsystem = SymbolicSystem((x, y, u, v, lam), comb_explicit_rhs, alg_con=[4], output_eqns=out_eqns, coord_idxs=(0, 1), speed_idxs=(2, 3), bodies=[Pa], loads=[(O, g*m*N.x)]); symsystem.coordinates",
      )
  )
  let ours_states = symbolic_system_entries_string(symsystem2.states())
  let oracle_states = mechanics_summary(
    prefix +
    "symsystem = SymbolicSystem((x, y, lam), comb_implicit_rhs, speeds=(u, v), mass_matrix=comb_implicit_mat, alg_con=[4], output_eqns=out_eqns, bodies=[Pa], loads=[(O, g*m*N.x)]); [str(x) for x in symsystem.states]",
  )
  assert_eq(ours_states, oracle_states)
  assert_true(
    mechanics_matrix_equal(
        @symphysics.explicit_matrix_rows_string(symsystem3.dyn_implicit_mat()),
        prefix +
        "symsystem = SymbolicSystem((x, y, u, v, lam), dyn_implicit_rhs, mass_matrix=dyn_implicit_mat, coordinate_derivatives=kin_explicit_rhs, alg_con=[2], coord_idxs=(0, 1), speed_idxs=(2, 3), bodies=[Pa], loads=[(O, g*m*N.x)]); symsystem.dyn_implicit_mat",
      )
  )
  assert_true(
    mechanics_matrix_equal(
        @symphysics.explicit_matrix_rows_string(symsystem3.comb_implicit_mat()),
        prefix +
        "symsystem = SymbolicSystem((x, y, u, v, lam), dyn_implicit_rhs, mass_matrix=dyn_implicit_mat, coordinate_derivatives=kin_explicit_rhs, alg_con=[2], coord_idxs=(0, 1), speed_idxs=(2, 3), bodies=[Pa], loads=[(O, g*m*N.x)]); symsystem.comb_implicit_mat",
      )
  )
  symsystem3.compute_explicit_form()
  assert_true(
    mechanics_matrix_equal(
        @symphysics.explicit_matrix_rows_string(symsystem3.comb_explicit_rhs()),
        prefix +
        "symsystem = SymbolicSystem((x, y, u, v, lam), dyn_implicit_rhs, mass_matrix=dyn_implicit_mat, coordinate_derivatives=kin_explicit_rhs, alg_con=[2], coord_idxs=(0, 1), speed_idxs=(2, 3), bodies=[Pa], loads=[(O, g*m*N.x)]); symsystem.compute_explicit_form(); symsystem.comb_explicit_rhs",
      )
  )
  let ours_dyn_items = symsystem3.dynamic_symbols().map(@symprint.to_string)
  let oracle_dyn = mechanics_summary(
    prefix +
    "symsystem = SymbolicSystem((x, y, u, v, lam), dyn_implicit_rhs, mass_matrix=dyn_implicit_mat, coordinate_derivatives=kin_explicit_rhs, alg_con=[2], coord_idxs=(0, 1), speed_idxs=(2, 3), bodies=[Pa], loads=[(O, g*m*N.x)]); sorted(str(x) for x in symsystem.dynamic_symbols())",
  )
  let oracle_dyn_items = symbolic_system_summary_items(oracle_dyn)
  assert_true(
    ours_dyn_items.length() == oracle_dyn_items.length() &&
        ours_dyn_items.all(fn(item) { oracle_dyn_items.contains(item) })
  )
  let ours_const_items = symsystem3.constant_symbols().map(@symprint.to_string)
  ours_const_items.sort_by((a, b) => a.compare(b))
  let ours_consts = "[" + ours_const_items.join(", ") + "]"
  let oracle_consts = mechanics_summary(
    prefix +
    "symsystem = SymbolicSystem((x, y, u, v, lam), dyn_implicit_rhs, mass_matrix=dyn_implicit_mat, coordinate_derivatives=kin_explicit_rhs, alg_con=[2], coord_idxs=(0, 1), speed_idxs=(2, 3), bodies=[Pa], loads=[(O, g*m*N.x)]); sorted(str(x) for x in symsystem.constant_symbols())",
  )
  assert_eq(ours_consts, oracle_consts)
  assert_true(symsystem2.alg_con() == Some([4]) && symsystem3.alg_con() == Some([4]))
  let oracle_body_name = mechanics_summary(
    prefix +
    "symsystem = SymbolicSystem((x, y, lam), comb_implicit_rhs, speeds=(u, v), mass_matrix=comb_implicit_mat, alg_con=[4], output_eqns=out_eqns, bodies=[Pa], loads=[(O, g*m*N.x)]); symsystem.bodies[0].name",
  )
  assert_eq(symsystem2.bodies()[0].name(), oracle_body_name)
}
