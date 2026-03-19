///|
fn wrapping_compact(text : String) -> String {
  text.replace(old=" ", new="")
}

///|
fn wrapping_assert_summary(
  lhs : String,
  rhs : String,
  context : String,
) -> Unit raise {
  guard wrapping_compact(lhs) == wrapping_compact(rhs) else {
    fail(context + ": ours=" + lhs + "; oracle=" + rhs)
  }
}

///|
fn wrapping_assert_vector(
  lhs : @symvector.Vector,
  frame : @symvector.ReferenceFrame,
  rhs_x : String,
  rhs_y : String,
  rhs_z : String,
  context : String,
) -> Unit raise {
  let comps = lhs.to_matrix(frame)
  let ours_x = @symprint.to_string(try! comps.get(0, 0))
  let ours_y = @symprint.to_string(try! comps.get(1, 0))
  let ours_z = @symprint.to_string(try! comps.get(2, 0))
  guard (try! @sympy_physics.mechanics_expr_equal(ours_x, rhs_x)) else {
    fail(context + ": x mismatch " + ours_x)
  }
  guard (try! @sympy_physics.mechanics_expr_equal(ours_y, rhs_y)) else {
    fail(context + ": y mismatch " + ours_y)
  }
  guard (try! @sympy_physics.mechanics_expr_equal(ours_z, rhs_z)) else {
    fail(context + ": z mismatch " + ours_z)
  }
}

///|
test "physics.mechanics parity wrapping geometry" {
  let n = @symvector.reference_frame("GWN")
  let p_o = @symvector.point("GpO")
  let r = @symcore.int(2)

  let sphere = wrapping_sphere(r, p_o)
  let p_1 = @symvector.point("Gp1")
  let p_2 = @symvector.point("Gp2")
  p_1.set_pos(p_o, n.x().scale(r))
  p_2.set_pos(p_o, n.y().scale(r))
  let sphere_len_oracle = @sympy_physics.mechanics_summary(
    "N=ReferenceFrame('GWN'); pO=Point('GpO'); p1=Point('Gp1'); p2=Point('Gp2'); r=2; p1.set_pos(pO, r*N.x); p2.set_pos(pO, r*N.y); WrappingSphere(r, pO).geodesic_length(p1, p2)",
  )
  guard @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(sphere.geodesic_length(p_1, p_2)),
    sphere_len_oracle,
  ) else {
    fail("sphere geodesic length parity")
  }
  let (sv1, sv2) = sphere.geodesic_end_vectors(p_1, p_2)
  wrapping_assert_vector(
    sv1.simplify(),
    n,
    "0",
    "1",
    "0",
    "sphere geodesic end vector 0 parity",
  )
  wrapping_assert_vector(
    sv2.simplify(),
    n,
    "1",
    "0",
    "0",
    "sphere geodesic end vector 1 parity",
  )

  let cylinder = wrapping_cylinder(r, p_o, n.z())
  let p_3 = @symvector.point("Gp3")
  p_3.set_pos(p_o, n.y().scale(r))
  let cylinder_len_oracle = @sympy_physics.mechanics_summary(
    "N=ReferenceFrame('GWN'); pO=Point('GpO'); p1=Point('Gp1'); p3=Point('Gp3'); r=2; p1.set_pos(pO, r*N.x); p3.set_pos(pO, r*N.y); WrappingCylinder(r, pO, N.z).geodesic_length(p1, p3)",
  )
  guard @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(cylinder.geodesic_length(p_1, p_3)),
    cylinder_len_oracle,
  ) else {
    fail("cylinder geodesic length parity")
  }
  let (cv1, cv2) = cylinder.geodesic_end_vectors(p_1, p_3)
  wrapping_assert_vector(
    cv1.simplify(),
    n,
    "0",
    "1",
    "0",
    "cylinder geodesic end vector 0 parity",
  )
  wrapping_assert_vector(
    cv2.simplify(),
    n,
    "1",
    "0",
    "0",
    "cylinder geodesic end vector 1 parity",
  )
}
