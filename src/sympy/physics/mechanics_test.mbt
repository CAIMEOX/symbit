///|
fn mechanics_assert_expr(
  lhs : @symcore.Expr,
  rhs : String,
  _context : String,
) -> Unit raise {
  assert_true(expr_equal(@symprint.to_string(lhs), rhs))
}

///|
test "physics.mechanics inertia core" {
  let n = @symvector.reference_frame("MN")
  let ixx = @symcore.symbol("ixx")
  let iyy = @symcore.symbol("iyy")
  let izz = @symcore.symbol("izz")
  let ixy = @symcore.symbol("ixy")
  let iyz = @symcore.symbol("iyz")
  let izx = @symcore.symbol("izx")
  let d = inertia(n, ixx, iyy, izz, ixy~, iyz~, izx~)
  inspect(
    @symvector.vsprint_dyadic(d),
    content="ixx*(MN.x|MN.x) + ixy*(MN.x|MN.y) + izx*(MN.x|MN.z) + ixy*(MN.y|MN.x) + iyy*(MN.y|MN.y) + iyz*(MN.y|MN.z) + izx*(MN.z|MN.x) + iyz*(MN.z|MN.y) + izz*(MN.z|MN.z)",
  )

  let r = @symcore.symbol("r")
  let m = @symcore.symbol("m")
  let point_mass = inertia_of_point_mass(m, n.x().scale(r), n)
  inspect(
    @symvector.vsprint_dyadic(point_mass),
    content="m*r**2*(MN.y|MN.y) + m*r**2*(MN.z|MN.z)",
  )

  let o = @symvector.point("MO")
  let iobj = inertia_tuple(inertia(n, ixx, iyy, izz), o)
  inspect(
    iobj.repr(),
    content="Inertia(dyadic=ixx*(MN.x|MN.x) + iyy*(MN.y|MN.y) + izz*(MN.z|MN.z), point=MO)",
  )
}

///|
test "physics.mechanics particle and rigidbody core" {
  let n = @symvector.reference_frame("PN")
  let o = @symvector.point("PO")
  let p = o.locatenew("PP", n.x().scale(@symcore.symbol("r")))
  p.set_vel(
    n,
    n.x().scale(@symcore.symbol("v1")) + n.z().scale(@symcore.symbol("v3")),
  )

  let part = particle("pa", point=Some(p), mass=Some(@symcore.symbol("m")))
  inspect(part.repr(), content="Particle('pa', masscenter=PP, mass=m)")
  inspect(
    @symvector.vsprint(part.linear_momentum(n)),
    content="m*v1*PN.x + m*v3*PN.z",
  )
  inspect(
    @symvector.vsprint(part.angular_momentum(o, n)),
    content="-m*r*v3*PN.y",
  )

  let b = @symvector.reference_frame("PB")
  b.set_ang_vel(n, b.x().scale(@symcore.symbol("omega")))
  let rb = rigid_body(
    "B",
    masscenter=Some(p),
    frame=Some(b),
    mass=Some(@symcore.symbol("m")),
    inertia=Some(inertia_tuple(@symvector.outer(b.x(), b.x()), p)),
  )
  inspect(
    rb.repr(),
    content="RigidBody('B', masscenter=PP, frame=PB, mass=m, inertia=Inertia(dyadic=(PB.x|PB.x), point=PP))",
  )
  inspect(@symvector.vsprint(rb.angular_momentum(p, n)), content="omega*PB.x")
}

///|
test "physics.mechanics wrapper functions and substitutions" {
  let n = @symvector.reference_frame("FN")
  let o = @symvector.point("FO")
  o.set_vel(n, @symvector.vector_zero())
  let p = o.locatenew("FP", n.x())
  p.set_vel(n, n.x().scale(@symcore.int(10)))
  let pa = particle("Pa", point=Some(p), mass=Some(@symcore.int(1)))
  pa.set_potential_energy(@symcore.symbol("g") * @symcore.symbol("h"))

  let ac = o.locatenew("FAc", n.y().scale(@symcore.int(2)))
  ac.set_vel(n, n.y().scale(@symcore.int(5)))
  let a = @symvector.reference_frame("Fa")
  a.set_ang_vel(n, n.z().scale(@symcore.int(10)))
  let rb = rigid_body(
    "A",
    masscenter=Some(ac),
    frame=Some(a),
    mass=Some(@symcore.int(20)),
    inertia=Some(inertia_tuple(@symvector.outer(n.z(), n.z()), ac)),
  )
  rb.set_potential_energy(
    @symcore.symbol("M") * @symcore.symbol("g") * @symcore.symbol("h"),
  )

  inspect(
    @symvector.vsprint(linear_momentum(n, [rb.as_bodylike(), pa.as_bodylike()])),
    content="10*FN.x + 100*FN.y",
  )
  mechanics_assert_expr(
    kinetic_energy(n, [pa.as_bodylike(), rb.as_bodylike()]),
    "350",
    "kinetic_energy",
  )
  inspect(
    @symprint.to_string(potential_energy([pa.as_bodylike(), rb.as_bodylike()])),
    content="M*g*h + g*h",
  )
  inspect(
    @symvector.vsprint(center_of_mass(o, [pa.as_bodylike(), rb.as_bodylike()])),
    content="1/21*FN.x + 40/21*FN.y",
  )

  let x = @symvector.dynamicsymbol("x")
  let y = @symvector.dynamicsymbol("y")
  let expr = @symelem.cos(x + y) * @symelem.tan(x + y) +
    @symcore.symbol("b") * @symcalculus.diff(x, @symvector.dynamicsymbols_t)
  let replaced = msubs_expr(
    expr,
    [
      (x, @symcore.int(0)),
      (y, @symcore.rational_from_ints(1, 2) * @symcore.pi()),
      (@symcalculus.diff(x, @symvector.dynamicsymbols_t), @symcore.int(1)),
    ],
    smart=true,
  )
  let txt = @symprint.to_string(replaced)
  assert_true(txt == "b + 1" || txt == "1 + b")

  let found = find_dynamicsymbols_expr(
    x * @symcalculus.diff(y, @symvector.dynamicsymbols_t) + y,
  )
  inspect(
    found.map(@symprint.to_string).join(","),
    content="x(t),y(t),Derivative(y(t), t)",
  )
}

///|
test "physics.mechanics body loads and helpers" {
  let n = @symvector.reference_frame("BN")
  let b1 = body("B1")
  let b2 = body("B2")
  let p1 = @symvector.point("P1")
  let p2 = @symvector.point("P2")
  p1.set_vel(b1.frame(), b1.x())
  p2.set_vel(b2.frame(), b2.x())
  let f = n.z().scale(@symcore.symbol("f"))
  b1.apply_force(
    f,
    point=Some(p1),
    reaction_body=Some(b2),
    reaction_point=Some(p2),
  )
  assert_true(b1.loads().length() == 1 && b2.loads().length() == 1)
  b1.apply_torque(n.x(), reaction_body=Some(b2))
  assert_true(b1.loads().length() == 2 && b2.loads().length() == 2)
  b1.remove_load(about=Some(p1))
  assert_eq(b1.loads().length(), 1)
  b1.clear_loads()
  assert_true(b1.loads().is_empty())
}
