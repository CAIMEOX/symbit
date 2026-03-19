///|
fn method_expr_list_summary(exprs : Array[@symcore.Expr]) -> String {
  "[" + exprs.map(@symprint.to_string).join(", ") + "]"
}

///|
fn method_matrix_rows(matrix : @symphysics.ExplicitMatrix) -> String {
  @symphysics.explicit_matrix_rows_string(matrix)
}

///|
test "physics.mechanics parity linearizer from kane and lagrange" {
  let kprefix = [
    "q = dynamicsymbols('q')", "u = dynamicsymbols('u')", "F = dynamicsymbols('F')",
    "k, c, m = symbols('k c m')", "N = ReferenceFrame('KNP')", "P = Point('KPP')",
    "P.set_vel(N, u*N.x)", "Pa = Particle('Pa', P, m)", "KM = KanesMethod(N, [q], [u], [q.diff(t) - u])",
    "KM.kanes_equations([Pa], [(P, (F - k*q - c*u)*N.x)])", "klin = KM.to_linearizer()",
  ].join("; ")

  let q = @symvector.dynamicsymbol("q")
  let u = @symvector.dynamicsymbol("u")
  let f = @symvector.dynamicsymbol("F")
  let n = @symvector.reference_frame("KNP")
  let p = @symvector.point("KPP")
  p.set_vel(n, n.x().scale(u))
  let pa = particle("Pa", point=Some(p), mass=Some(@symcore.symbol("m")))
  let km = kanes_method(n, [q], [u], [
    @symcalculus.diff(q, @symvector.dynamicsymbols_t) - u,
  ])
  ignore(
    km.kanes_equations([pa.as_bodylike()], [
      force_load(
        p,
        n.x().scale(f - @symcore.symbol("k") * q - @symcore.symbol("c") * u),
      ),
    ]),
  )
  let klin = km.to_linearizer()
  let oracle_kq = @sympy_physics.mechanics_eval(kprefix + "; list(klin.q)")
  guard method_expr_list_summary(klin.q()) == oracle_kq else {
    fail("kane linearizer q parity mismatch")
  }
  let oracle_ku = @sympy_physics.mechanics_eval(kprefix + "; list(klin.u)")
  guard method_expr_list_summary(klin.u()) == oracle_ku else {
    fail("kane linearizer u parity mismatch")
  }
  let oracle_kr = @sympy_physics.mechanics_eval(kprefix + "; list(klin.r)")
  guard method_expr_list_summary(klin.r()) == oracle_kr else {
    fail("kane linearizer r parity mismatch")
  }
  guard @sympy_physics.mechanics_matrix_equal(
    method_matrix_rows(klin.f_0()),
    kprefix + "; klin.f_0",
  ) else {
    fail("kane linearizer f_0 parity mismatch")
  }
  guard @sympy_physics.mechanics_matrix_equal(
    method_matrix_rows(klin.f_1()),
    kprefix + "; klin.f_1",
  ) else {
    fail("kane linearizer f_1 parity mismatch")
  }
  let (km_m, km_a) = klin.linearize()
  guard @sympy_physics.mechanics_matrix_equal(
    method_matrix_rows(km_m),
    kprefix + "; klin.linearize()[0]",
  ) else {
    fail("kane linearizer implicit M parity mismatch")
  }
  guard @sympy_physics.mechanics_matrix_equal(
    method_matrix_rows(km_a),
    kprefix + "; klin.linearize()[1]",
  ) else {
    fail("kane linearizer implicit A parity mismatch")
  }
  let (_, _, km_b) = klin.linearize_mab()
  guard @sympy_physics.mechanics_matrix_equal(
    method_matrix_rows(km_b),
    kprefix + "; klin.linearize()[2]",
  ) else {
    fail("kane linearizer implicit B parity mismatch")
  }
  let (km_ae, km_be) = klin.linearize(a_and_b=true)
  guard @sympy_physics.mechanics_matrix_equal(
    method_matrix_rows(km_ae),
    kprefix + "; klin.linearize(A_and_B=True)[0]",
  ) else {
    fail("kane linearizer explicit A parity mismatch")
  }
  guard @sympy_physics.mechanics_matrix_equal(
    method_matrix_rows(km_be),
    kprefix + "; klin.linearize(A_and_B=True)[1]",
  ) else {
    fail("kane linearizer explicit B parity mismatch")
  }

  let lprefix = [
    "q = dynamicsymbols('q')", "l, m, g = symbols('l m g')", "N = ReferenceFrame('LNP')",
    "A = N.orientnew('A', 'axis', [q, N.z])", "A.set_ang_vel(N, q.diff(t)*N.z)",
    "O = Point('LOP')", "O.set_vel(N, 0)", "P = O.locatenew('LPP', l*A.x)", "P.v2pt_theory(O, N, A)",
    "Pa = Particle('LPa', P, m)", "Pa.potential_energy = -m*g*l*cos(q)", "Lag = Lagrangian(N, Pa)",
    "LM = LagrangesMethod(Lag, [q], forcelist=[], frame=N)", "LM.form_lagranges_equations()",
    "llin = LM.to_linearizer(q_ind=[q], qd_ind=[q.diff(t)])",
  ].join("; ")

  let ql = @symvector.dynamicsymbol("q")
  let nn = @symvector.reference_frame("LNP")
  let aa = @symvector.reference_frame("A")
  aa.orient_axis(nn, nn.z(), ql)
  aa.set_ang_vel(
    nn,
    nn.z().scale(@symcalculus.diff(ql, @symvector.dynamicsymbols_t)),
  )
  let oo = @symvector.point("LOP")
  oo.set_vel(nn, @symvector.vector_zero())
  let pp = oo.locatenew("LPP", aa.x().scale(@symcore.symbol("l")))
  ignore(pp.v2pt_theory(oo, nn, aa))
  let lpa = particle("LPa", point=Some(pp), mass=Some(@symcore.symbol("m")))
  lpa.set_potential_energy(
    @symcore.int(-1) *
    @symcore.symbol("m") *
    @symcore.symbol("g") *
    @symcore.symbol("l") *
    @symelem.cos(ql),
  )
  let lagr = lagrangian(nn, [lpa.as_bodylike()])
  let lm = lagranges_method(
    lagr,
    [ql],
    bodies=[lpa.as_bodylike()],
    frame=Some(nn),
  )
  ignore(lm.form_lagranges_equations())
  let llin = lm.to_linearizer()
  let oracle_lq = @sympy_physics.mechanics_eval(lprefix + "; list(llin.q)")
  guard method_expr_list_summary(llin.q()) == oracle_lq else {
    fail("lagrange linearizer q parity mismatch")
  }
  let oracle_lu = @sympy_physics.mechanics_eval(lprefix + "; list(llin.u)")
  guard method_expr_list_summary(llin.u()) == oracle_lu else {
    fail("lagrange linearizer u parity mismatch")
  }
  let (lm_m, lm_a) = llin.linearize()
  guard @sympy_physics.mechanics_matrix_equal(
    method_matrix_rows(lm_m),
    lprefix + "; llin.linearize()[0]",
  ) else {
    fail("lagrange linearizer implicit M parity mismatch")
  }
  guard @sympy_physics.mechanics_matrix_equal(
    method_matrix_rows(lm_a),
    lprefix + "; llin.linearize()[1]",
  ) else {
    fail("lagrange linearizer implicit A parity mismatch")
  }
  let (lm_ae, lm_be) = llin.linearize(a_and_b=true)
  guard @sympy_physics.mechanics_matrix_equal(
    method_matrix_rows(lm_ae),
    lprefix + "; llin.linearize(A_and_B=True)[0]",
  ) else {
    fail("lagrange linearizer explicit A parity mismatch")
  }
  guard @sympy_physics.mechanics_matrix_equal(
    method_matrix_rows(lm_be),
    lprefix + "; llin.linearize(A_and_B=True)[1]",
  ) else {
    fail("lagrange linearizer explicit B parity mismatch")
  }
}
