fn pathway_assert_force(
  load : Force,
  point_name : String,
  frame : @symvector.ReferenceFrame,
  rhs_x : String,
  rhs_y : String,
  rhs_z : String,
  _context : String,
) -> Unit raise {
  assert_eq(load.point.name(), point_name)
  let comps = load.force.to_matrix(frame)
  let ours_x = @symprint.to_string(try! comps.get(0, 0))
  let ours_y = @symprint.to_string(try! comps.get(1, 0))
  let ours_z = @symprint.to_string(try! comps.get(2, 0))
  assert_true((try! mechanics_expr_equal(ours_x, rhs_x)))
  assert_true((try! mechanics_expr_equal(ours_y, rhs_y)))
  assert_true((try! mechanics_expr_equal(ours_z, rhs_z)))
}

///|
test "physics.mechanics parity pathways" {
  let n = @symvector.reference_frame("QPN")
  let p_a = @symvector.point("QpA")
  let p_b = @symvector.point("QpB")
  let q = @symvector.dynamicsymbol("q")
  let f = @symcore.symbol("F")
  p_b.set_pos(p_a, n.x().scale(q))
  let linear = linear_pathway(p_a, p_b)
  let linear_length_oracle = mechanics_summary(
    "N=ReferenceFrame('QPN'); pA=Point('QpA'); pB=Point('QpB'); q=dynamicsymbols('q'); pB.set_pos(pA, q*N.x); LinearPathway(pA, pB).length",
  )
  assert_true(
    mechanics_expr_equal(
        @symprint.to_string(linear.length()),
        linear_length_oracle,
      )
  )
  let linear_loads = linear.to_loads(f)
  pathway_assert_force(
    linear_loads[0],
    "QpA",
    n,
    "-F*q(t)/sqrt(q(t)**2)",
    "0",
    "0",
    "linear load 0 parity",
  )
  pathway_assert_force(
    linear_loads[1],
    "QpB",
    n,
    "F*q(t)/sqrt(q(t)**2)",
    "0",
    "0",
    "linear load 1 parity",
  )

  let p_c = @symvector.point("QpC")
  p_c.set_pos(p_b, n.y())
  let obstacle = obstacle_set_pathway([p_a, p_b, p_c])
  let obstacle_length_oracle = mechanics_summary(
    "N=ReferenceFrame('QPN'); pA=Point('QpA'); pB=Point('QpB'); pC=Point('QpC'); q=dynamicsymbols('q'); pB.set_pos(pA, q*N.x); pC.set_pos(pB, N.y); ObstacleSetPathway(pA, pB, pC).length",
  )
  assert_true(
    mechanics_expr_equal(
        @symprint.to_string(obstacle.length()),
        obstacle_length_oracle,
      )
  )
  let obstacle_loads = obstacle.to_loads(f)
  pathway_assert_force(
    obstacle_loads[0],
    "QpA",
    n,
    "-F*q(t)/sqrt(q(t)**2)",
    "0",
    "0",
    "obstacle load 0 parity",
  )
  pathway_assert_force(
    obstacle_loads[1],
    "QpB",
    n,
    "F*q(t)/sqrt(q(t)**2)",
    "0",
    "0",
    "obstacle load 1 parity",
  )
  pathway_assert_force(
    obstacle_loads[2],
    "QpB",
    n,
    "0",
    "-F",
    "0",
    "obstacle load 2 parity",
  )
  pathway_assert_force(
    obstacle_loads[3],
    "QpC",
    n,
    "0",
    "F",
    "0",
    "obstacle load 3 parity",
  )
}
