///|
fn cm_collect_symbols(expr : @symcore.Expr, names : Map[String, Bool]) -> Unit {
  match expr {
    @symcore.Expr::Symbol(name) => names[name] = true
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      for arg in args {
        cm_collect_symbols(arg, names)
      }
    @symcore.Expr::Pow(base, exp) => {
      cm_collect_symbols(base, names)
      cm_collect_symbols(exp, names)
    }
    @symcore.Expr::Function(_, args) =>
      for arg in args {
        cm_collect_symbols(arg, names)
      }
    _ => ()
  }
}

///|
fn cm_double_pow(base : Double, exp : Int) -> Double {
  if exp == 0 {
    return 1.0
  }
  if exp < 0 {
    return 1.0 / cm_double_pow(base, -exp)
  }
  let mut acc = 1.0
  let mut b = base
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      acc = acc * b
    }
    e = e / 2
    if e > 0 {
      b = b * b
    }
  }
  acc
}

///|
fn cm_expr_eval(expr : @symcore.Expr, env : Map[String, Double]) -> Double? {
  match expr {
    @symcore.Expr::Number(n) => {
      let num = Double::from_int(n.numerator().to_int())
      let den = Double::from_int(n.denominator().to_int())
      Some(num / den)
    }
    @symcore.Expr::Symbol(name) => env.get(name)
    @symcore.Expr::Add(args) => {
      let mut acc = 0.0
      for arg in args {
        match cm_expr_eval(arg, env) {
          Some(value) => acc = acc + value
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Mul(args) => {
      let mut acc = 1.0
      for arg in args {
        match cm_expr_eval(arg, env) {
          Some(value) => acc = acc * value
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Pow(base, exp) =>
      match (cm_expr_eval(base, env), exp) {
        (Some(base_value), @symcore.Expr::Number(n)) if n.is_integral() =>
          Some(cm_double_pow(base_value, n.numerator().to_int()))
        _ => None
      }
    @symcore.Expr::Function("sqrt", args) if args.length() == 1 =>
      match cm_expr_eval(args[0], env) {
        Some(value) => Some(value.sqrt())
        None => None
      }
    _ => None
  }
}

///|
fn cm_expr_eq(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Bool {
  let diff = @symsimplify.ratsimp(
    @symsimplify.simplify(lhs - rhs, max_passes=8),
    max_passes=8,
  )
  if diff == @symcore.int(0) {
    return true
  }

  let names : Map[String, Bool] = {}
  cm_collect_symbols(lhs, names)
  cm_collect_symbols(rhs, names)
  let ordered = names.keys().to_array()
  for seed in [2, 5, 9] {
    let env : Map[String, Double] = {}
    for i in 0..<ordered.length() {
      env[ordered[i]] = Double::from_int(seed + i)
    }
    match (cm_expr_eval(lhs, env), cm_expr_eval(rhs, env)) {
      (Some(lhs_value), Some(rhs_value)) =>
        if !lhs_value.is_close(
            rhs_value,
            relative_tolerance=1.0e-8,
            absolute_tolerance=1.0e-8,
          ) {
          return false
        }
      _ => return false
    }
  }
  true
}

///|
test "physics.continuum_mechanics.truss: node/member/load/support workflow" {
  let a = "A"
  let b = "B"
  let c = "C"
  let d = "D"
  let ab = "AB"
  let bc = "BC"
  let ac = "AC"
  let cd = "CD"
  let p = @symcore.symbol("P")
  let quarter = try! @symcore.rational_from_ints(1, 4)
  let half = try! @symcore.rational_from_ints(1, 2)

  let t = truss()
  guard t.nodes().is_empty() else { fail("initial nodes") }
  guard t.members().is_empty() else { fail("initial members") }
  guard t.loads().is_empty() else { fail("initial loads") }
  guard t.supports().is_empty() else { fail("initial supports") }
  guard t.reaction_loads().is_empty() else { fail("initial reaction loads") }
  guard t.internal_forces().is_empty() else { fail("initial internal forces") }

  try! t.add_node([
    (a, @symcore.int(0), @symcore.int(0)),
    (b, @symcore.int(2), @symcore.int(2)),
    (c, @symcore.int(3), @symcore.int(0)),
  ])
  guard t.node_labels() == [a, b, c] else { fail("node labels after add") }
  guard t.node_positions() ==
    [
      (@symcore.int(0), @symcore.int(0)),
      (@symcore.int(2), @symcore.int(2)),
      (@symcore.int(3), @symcore.int(0)),
    ] else {
    fail("node positions after add")
  }

  try! t.remove_node([c])
  guard t.node_labels() == [a, b] else { fail("node labels after remove") }
  try! t.add_node([(c, @symcore.int(3), @symcore.int(0))])

  try! t.add_member([(ab, a, b), (bc, b, c), (ac, a, c)])
  guard t.members()[ab] == [a, b] else { fail("AB member endpoints") }
  guard t.members()[bc] == [b, c] else { fail("BC member endpoints") }
  guard t.members()[ac] == [a, c] else { fail("AC member endpoints") }
  guard t.internal_forces()[ab] == @symcore.int(0) else {
    fail("AB internal force init")
  }

  try! t.remove_member([bc])
  guard t.members().get(bc) is None else { fail("BC removed") }
  try! t.add_member([(bc, b, c)])

  try! t.change_node_label([(b, d)])
  guard t.node_labels() == [a, d, c] else { fail("node labels after rename") }
  guard t.members()[ab] == [a, d] else {
    fail("AB endpoints after node rename")
  }
  guard t.members()[bc] == [d, c] else {
    fail("BC endpoints after node rename")
  }
  try! t.change_member_label([(bc, cd)])
  guard t.members().get(bc) is None else { fail("old member label removed") }
  guard t.members()[cd] == [d, c] else { fail("new member label inserted") }
  guard t.internal_forces()[cd] == @symcore.int(0) else {
    fail("renamed member force init")
  }

  try! t.apply_load([
    (a, p, @symcore.int(90)),
    (a, p * quarter, @symcore.int(90)),
    (a, @symcore.int(2) * p, @symcore.int(45)),
    (d, p * half, @symcore.int(90)),
  ])
  guard t.loads()[a].length() == 3 else { fail("A loads count after apply") }
  guard t.loads()[d].length() == 1 else { fail("D loads count after apply") }

  try! t.remove_load([(a, p * quarter, @symcore.int(90))])
  guard t.loads()[a].length() == 2 else { fail("A loads count after remove") }

  try! t.apply_support([(a, "pinned"), (d, "roller")])
  guard t.supports()[a] == "pinned" else { fail("A support") }
  guard t.supports()[d] == "roller" else { fail("D support") }
  guard t.loads()[a].length() == 4 else { fail("A loads include reactions") }
  guard t.loads()[d].length() == 2 else { fail("D loads include reactions") }

  try! t.remove_support([a])
  guard t.supports().get(a) is None else { fail("A support removed") }
  guard t.loads()[a].length() == 2 else { fail("A reaction loads removed") }
  try! t.apply_support([(a, "pinned")])

  try! t.solve()
  let rx = t.reaction_loads()["R_A_x"]
  let ry = t.reaction_loads()["R_A_y"]
  let rdy = t.reaction_loads()["R_D_y"]
  guard cm_expr_eq(rx, @symcore.int(-1) * @symelem.sqrt(@symcore.int(2)) * p) else {
    fail("R_A_x wrong: \{@symprint.to_string(rx)}")
  }
  guard cm_expr_eq(
    ry,
    @symcore.int(-1) * @symelem.sqrt(@symcore.int(2)) * p - p,
  ) else {
    fail("R_A_y wrong: \{@symprint.to_string(ry)}")
  }
  guard cm_expr_eq(rdy, @symcore.int(-1) * p * half) else {
    fail("R_D_y wrong: \{@symprint.to_string(rdy)}")
  }
  guard cm_expr_eq(t.internal_forces()[ab], @symcore.int(0)) else {
    fail("AB force")
  }
  guard cm_expr_eq(t.internal_forces()[cd], @symcore.int(0)) else {
    fail("CD force")
  }
  guard cm_expr_eq(t.internal_forces()[ac], @symcore.int(0)) else {
    fail("AC force")
  }
}

///|
test "physics.continuum_mechanics.truss: solves a determinate truss with nonzero member forces" {
  let third = try! @symcore.rational_from_ints(1, 3)
  let t = truss()
  try! t.add_node([
    ("node_1", @symcore.int(0), @symcore.int(0)),
    ("node_2", @symcore.int(6), @symcore.int(0)),
    ("node_3", @symcore.int(2), @symcore.int(2)),
    ("node_4", @symcore.int(2), @symcore.int(0)),
  ])
  try! t.add_member([
    ("member_1", "node_1", "node_4"),
    ("member_2", "node_2", "node_4"),
    ("member_3", "node_1", "node_3"),
    ("member_4", "node_2", "node_3"),
    ("member_5", "node_3", "node_4"),
  ])
  try! t.apply_load([("node_4", @symcore.int(10), @symcore.int(270))])
  try! t.apply_support([("node_1", "pinned"), ("node_2", "roller")])

  try! t.solve()
  let member_1_force = t.internal_forces()["member_1"]

  guard cm_expr_eq(t.reaction_loads()["R_node_1_x"], @symcore.int(0)) else {
    fail("R_node_1_x wrong")
  }
  guard cm_expr_eq(t.reaction_loads()["R_node_1_y"], @symcore.int(20) * third) else {
    fail("R_node_1_y wrong")
  }
  guard cm_expr_eq(t.reaction_loads()["R_node_2_y"], @symcore.int(10) * third) else {
    fail("R_node_2_y wrong")
  }
  guard cm_expr_eq(member_1_force, @symcore.int(20) * third) else {
    fail("member_1 force wrong: \{@symprint.to_string(member_1_force)}")
  }
  guard cm_expr_eq(t.internal_forces()["member_2"], @symcore.int(20) * third) else {
    fail("member_2 force wrong")
  }
  guard cm_expr_eq(
    t.internal_forces()["member_3"],
    @symcore.int(-20) * @symelem.sqrt(@symcore.int(2)) * third,
  ) else {
    fail("member_3 force wrong")
  }
  guard cm_expr_eq(
    t.internal_forces()["member_4"],
    @symcore.int(-10) * @symelem.sqrt(@symcore.int(5)) * third,
  ) else {
    fail("member_4 force wrong")
  }
  guard cm_expr_eq(t.internal_forces()["member_5"], @symcore.int(10)) else {
    fail("member_5 force wrong")
  }
}

///|
test "physics.continuum_mechanics.truss: validation errors" {
  let t = truss()
  try! t.add_node([("A", @symcore.int(0), @symcore.int(0))])
  guard (try? t.add_node([("A", @symcore.int(1), @symcore.int(0))])) is Err(_) else {
    fail("duplicate node label should fail")
  }
  guard (try? t.add_node([("B", @symcore.int(0), @symcore.int(0))])) is Err(_) else {
    fail("duplicate node position should fail")
  }
  try! t.add_node([("B", @symcore.int(1), @symcore.int(0))])
  guard (try? t.add_member([("AB", "A", "A")])) is Err(_) else {
    fail("self-edge member should fail")
  }
  try! t.add_member([("AB", "A", "B")])
  guard (try? t.remove_node(["A"])) is Err(_) else {
    fail("removing attached node should fail")
  }
  guard (try? t.apply_support([("Z", "pinned")])) is Err(_) else {
    fail("support on missing node should fail")
  }
  guard (try? t.apply_support([("A", "hinge")])) is Err(_) else {
    fail("unknown support kind should fail")
  }
}
