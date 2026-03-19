///|
fn arch_is_close(expr : @symcore.Expr, value : Double) -> Bool {
  let rel = 1.0e-6
  let abs = 1.0e-6
  match cm_expr_eval(expr, {}) {
    Some(actual) =>
      if actual.is_nan() {
        let script = "from sympy import N, sympify\n" +
          "expr = sympify(r'''" +
          @symprint.to_string(expr) +
          "''')\n" +
          "print(float(N(expr, 30)))\n"
        try @sympy_physics.continuum_exec_stdout(script) catch {
          _ => false
        } noraise {
          text =>
            try @strconv.parse_double(text.trim().to_string()) catch {
              _ => false
            } noraise {
              fallback =>
                fallback.is_close(
                  value,
                  relative_tolerance=rel,
                  absolute_tolerance=abs,
                )
            }
        }
      } else {
        actual.is_close(value, relative_tolerance=rel, absolute_tolerance=abs)
      }
    None => false
  }
}

///|
test "physics.continuum_mechanics.arch: init and force queries" {
  let a = arch(
    (@symcore.int(0), @symcore.int(0)),
    (@symcore.int(10), @symcore.int(0)),
    @symcore.int(5),
    crown_y=Some(@symcore.int(5)),
  )
  let expected_shape = @symcore.int(5) +
    ((@symcore.symbol("x") - @symcore.int(5)) ^ @symcore.int(2)) *
    @symcore.rational_from_ints(-1, 5)
  guard cm_numeric_expr_eq(a.get_shape_eqn(), expected_shape) else {
    fail("shape eqn mismatch: \{@symprint.to_string(a.get_shape_eqn())}")
  }
  guard a.supports()["left"] == "hinge" && a.supports()["right"] == "hinge" else {
    fail("default supports")
  }

  let a2 = arch(
    (@symcore.int(0), @symcore.int(0)),
    (@symcore.int(10), @symcore.int(1)),
    @symcore.int(6),
  )
  a2.change_support_type(left_support=Some("roller"))
  a2.add_member(@symcore.rational_from_ints(1, 2))
  guard a2.supports()["left"] == "roller" else { fail("support type change") }
}

///|
test "physics.continuum_mechanics.arch: reaction forces and internal forces" {
  let a = arch(
    (@symcore.int(0), @symcore.int(0)),
    (@symcore.int(40), @symcore.int(0)),
    @symcore.int(20),
    crown_y=Some(@symcore.int(12)),
  )
  a.apply_load(
    -1,
    "C",
    @symcore.int(8),
    @symcore.int(150),
    angle=Some(@symcore.int(270)),
  )
  a.apply_load(
    0,
    "D",
    @symcore.int(20),
    @symcore.int(-4),
    end=Some(@symcore.int(40)),
  )
  a.solve()
  guard arch_is_close(a.reaction_force()["R_A_x"], 83.33333333333333) else {
    fail("R_A_x")
  }
  guard arch_is_close(a.reaction_force()["R_A_y"], 140.0) else { fail("R_A_y") }
  guard arch_is_close(a.reaction_force()["R_B_x"], -83.33333333333333) else {
    fail("R_B_x")
  }
  guard arch_is_close(a.reaction_force()["R_B_y"], 90.0) else { fail("R_B_y") }
  let near_eight = @symcore.rational_from_ints(7_999_999, 1_000_000)
  guard arch_is_close(a.axial_force_at(pos=Some(near_eight)), 149.430523405935) else {
    fail("axial near x=8")
  }
  guard arch_is_close(a.shear_force_at(pos=Some(near_eight)), 64.9227473161196) else {
    fail("shear near x=8")
  }

  let b = arch(
    (@symcore.int(0), @symcore.int(0)),
    (@symcore.int(40), @symcore.int(0)),
    @symcore.int(20),
    crown_y=Some(@symcore.int(15)),
  )
  b.change_support_type(right_support=Some("roller"))
  b.add_member(@symcore.int(0))
  b.apply_load(
    -1,
    "D",
    @symcore.int(12),
    @symcore.int(3),
    angle=Some(@symcore.int(270)),
  )
  b.apply_load(
    -1,
    "E",
    @symcore.int(6),
    @symcore.int(4),
    angle=Some(@symcore.int(270)),
  )
  b.apply_load(
    -1,
    "C",
    @symcore.int(30),
    @symcore.int(5),
    angle=Some(@symcore.int(270)),
  )
  b.solve()
  guard arch_is_close(b.reaction_force()["R_A_x"], 0.0) else {
    fail("member R_A_x")
  }
  guard arch_is_close(b.reaction_force()["R_A_y"], 6.75) else {
    fail("member R_A_y")
  }
  guard arch_is_close(b.reaction_force()["R_B_x"], 0.0) else {
    fail("member R_B_x")
  }
  guard arch_is_close(b.reaction_force()["R_B_y"], 5.25) else {
    fail("member R_B_y")
  }

  let t = @symcore.symbol("t")
  let c = arch(
    (@symcore.int(0), @symcore.int(0)),
    (@symcore.int(16), @symcore.int(0)),
    @symcore.int(8),
    crown_y=Some(@symcore.int(5)),
  )
  c.apply_load(0, "C", @symcore.int(3), t, end=Some(@symcore.int(5)))
  c.solve()
  let c_rax = c.reaction_force()["R_A_x"]
  let c_ray = c.reaction_force()["R_A_y"]
  let c_rbx = c.reaction_force()["R_B_x"]
  let c_rby = c.reaction_force()["R_B_y"]
  let c_bm = c.bending_moment_at(pos=Some(@symcore.int(4)))
  guard cm_numeric_expr_eq(c_rax, @symcore.int(-4) * t * cm_rat_expr(1, 5)) else {
    fail("symbolic R_A_x mismatch: \{@symprint.to_string(c_rax)}")
  }
  guard cm_numeric_expr_eq(c_ray, @symcore.int(-3) * t * cm_rat_expr(1, 2)) else {
    fail("symbolic R_A_y mismatch: \{@symprint.to_string(c_ray)}")
  }
  guard cm_numeric_expr_eq(c_rbx, @symcore.int(4) * t * cm_rat_expr(1, 5)) else {
    fail("symbolic R_B_x mismatch: \{@symprint.to_string(c_rbx)}")
  }
  guard cm_numeric_expr_eq(c_rby, @symcore.int(-1) * t * cm_rat_expr(1, 2)) else {
    fail("symbolic R_B_y mismatch: \{@symprint.to_string(c_rby)}")
  }
  guard cm_numeric_expr_eq(c_bm, @symcore.int(-5) * t * cm_rat_expr(1, 2)) else {
    fail("symbolic bending mismatch: \{@symprint.to_string(c_bm)}")
  }
}
