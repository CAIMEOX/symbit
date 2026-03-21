///|
fn symbolic_system_fixture() -> (
  Array[@symcore.Expr],
  Array[@symcore.Expr],
  Array[@symcore.Expr],
  @symphysics.ExplicitMatrix,
  @symphysics.ExplicitMatrix,
  @symphysics.ExplicitMatrix,
  @symphysics.ExplicitMatrix,
  @symphysics.ExplicitMatrix,
  Array[OutputEquation],
  Array[BodyLike],
  Array[Load],
) raise {
  let x = @symvector.dynamicsymbol("x")
  let y = @symvector.dynamicsymbol("y")
  let u = @symvector.dynamicsymbol("u")
  let v = @symvector.dynamicsymbol("v")
  let lam = @symvector.dynamicsymbol("lambda")
  let m = @symcore.symbol("m")
  let l = @symcore.symbol("l")
  let g = @symcore.symbol("g")
  let inv_m = m ^ @symcore.int(-1)
  let dyn_implicit_mat = @symphysics.explicit_matrix_from_rows([
    [@symcore.int(1), @symcore.int(0), @symcore.int(-1) * x * inv_m],
    [@symcore.int(0), @symcore.int(1), @symcore.int(-1) * y * inv_m],
    [@symcore.int(0), @symcore.int(0), (l ^ @symcore.int(2)) * inv_m],
  ])
  let dyn_rhs_last = (u ^ @symcore.int(2)) + (v ^ @symcore.int(2)) - g * y
  let dyn_implicit_rhs = @symphysics.explicit_matrix_from_rows([
    [@symcore.int(0)],
    [@symcore.int(0)],
    [dyn_rhs_last],
  ])
  let comb_implicit_mat = @symphysics.explicit_matrix_from_rows([
    [
      @symcore.int(1),
      @symcore.int(0),
      @symcore.int(0),
      @symcore.int(0),
      @symcore.int(0),
    ],
    [
      @symcore.int(0),
      @symcore.int(1),
      @symcore.int(0),
      @symcore.int(0),
      @symcore.int(0),
    ],
    [
      @symcore.int(0),
      @symcore.int(0),
      @symcore.int(1),
      @symcore.int(0),
      @symcore.int(-1) * x * inv_m,
    ],
    [
      @symcore.int(0),
      @symcore.int(0),
      @symcore.int(0),
      @symcore.int(1),
      @symcore.int(-1) * y * inv_m,
    ],
    [
      @symcore.int(0),
      @symcore.int(0),
      @symcore.int(0),
      @symcore.int(0),
      (l ^ @symcore.int(2)) * inv_m,
    ],
  ])
  let comb_implicit_rhs = @symphysics.explicit_matrix_from_rows([
    [u],
    [v],
    [@symcore.int(0)],
    [@symcore.int(0)],
    [dyn_rhs_last],
  ])
  let kin_explicit_rhs = @symphysics.explicit_matrix_from_rows([[u], [v]])
  let n = @symvector.reference_frame("SSN")
  let o = @symvector.point("SSO")
  o.set_vel(n, @symvector.vector_zero())
  let pa = particle("Pa", point=Some(o), mass=Some(m))
  let loads = [force_load(o, n.x().scale(g * m))]
  (
    [x, y, lam],
    [u, v],
    [x, y, u, v, lam],
    dyn_implicit_mat,
    dyn_implicit_rhs,
    comb_implicit_mat,
    comb_implicit_rhs,
    kin_explicit_rhs,
    [(@symcore.symbol("PE"), m * g * (l + y))],
    [pa.as_bodylike()],
    loads,
  )
}

///|
test "physics.mechanics symbolic system forms" {
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

  assert_eq(symsystem1.coordinates().height(), 2)
  assert_eq(symsystem2.states().height(), 5)
  assert_eq(symsystem3.kin_explicit_rhs().height(), 2)
  assert_eq(symsystem3.alg_con(), Some([4]))
  inspect(
    symsystem1.dynamic_symbols().map(@symprint.to_string).join(","),
    content="u(t),v(t),x(t),y(t),lambda(t)",
  )
  inspect(
    symsystem3.constant_symbols().map(@symprint.to_string).join(","),
    content="g,l,m",
  )
  assert_true(
    symsystem2.bodies().length() == 1 && symsystem2.loads().length() == 1,
  )
  assert_eq(symsystem2.output_eqns().length(), 1)
  assert_eq(
    @symprint.to_string(symsystem2.output_eqns()[0].1),
    "g*m*(l + y(t))",
  )
}

///|
test "physics.mechanics symbolic system errors" {
  let (
    _coordinates,
    _speeds,
    states,
    _dyn_implicit_mat,
    _dyn_implicit_rhs,
    _comb_implicit_mat,
    comb_implicit_rhs,
    _kin_explicit_rhs,
    _output_eqns,
    _bodies,
    _loads,
  ) = symbolic_system_fixture()
  let symsystem = symbolic_system(states, comb_implicit_rhs)
  let implicit_system = symbolic_system(
    [states[0], states[1], states[4]],
    comb_implicit_rhs,
    speeds=Some([states[2], states[3]]),
    mass_matrix=Some(@symphysics.explicit_matrix_eye(5)),
  )
  let bad_coords : Result[@symphysics.ExplicitMatrix, @symphysics.PhysicsError] = try? symsystem.coordinates()
  assert_true(bad_coords is Err(@symphysics.PhysicsError::ValueError(_)))
  let bad_loads : Result[Array[Load], @symphysics.PhysicsError] = try? symsystem.loads()
  assert_true(bad_loads is Err(@symphysics.PhysicsError::ValueError(_)))
  let bad_explicit : Result[
    @symphysics.ExplicitMatrix,
    @symphysics.PhysicsError,
  ] = try? implicit_system.comb_explicit_rhs()
  assert_true(bad_explicit is Err(@symphysics.PhysicsError::ValueError(_)))
}
