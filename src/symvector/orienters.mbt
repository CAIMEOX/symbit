///|
fn rotation_order_normalize(
  rotation_order : String,
) -> String raise @rawvec.VectorError {
  let order = rotation_order.to_upper()
  if order.length() != 3 {
    @rawvec.raise_value_error("rotation order must have length 3")
  }
  let normalized = order
    .replace(old="X", new="1")
    .replace(old="Y", new="2")
    .replace(old="Z", new="3")
  let approved = [
    "123", "231", "312", "132", "213", "321", "121", "131", "212", "232", "313",
    "323",
  ]
  if !approved.contains(normalized) {
    @rawvec.raise_value_error("Invalid rot_type parameter")
  }
  normalized
}

///|
fn rotation_axis_matrix(
  axis : Int,
  angle : @symcore.Expr,
) -> @symphysics.ExplicitMatrix {
  let c = @symelem.cos(angle)
  let s = @symelem.sin(angle)
  matrix_simplify_entries(
    @symphysics.explicit_matrix_from_rows(
      match axis {
        0 =>
          [
            [@symcore.int(1), @symcore.int(0), @symcore.int(0)],
            [@symcore.int(0), c, @symcore.int(-1) * s],
            [@symcore.int(0), s, c],
          ]
        1 =>
          [
            [c, @symcore.int(0), s],
            [@symcore.int(0), @symcore.int(1), @symcore.int(0)],
            [@symcore.int(-1) * s, @symcore.int(0), c],
          ]
        _ =>
          [
            [c, @symcore.int(-1) * s, @symcore.int(0)],
            [s, c, @symcore.int(0)],
            [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
          ]
      },
    ) catch {
      _ => abort("rotation_axis_matrix")
    },
  )
}

///|
fn rotation_order_axis(ch : UInt16) -> Int {
  match ch {
    49 => 0
    50 => 1
    _ => 2
  }
}

///|
pub fn axis_orienter(angle : @symcore.Expr, axis : Vector) -> AxisOrienter {
  { angle_: angle, axis_: axis }
}

///|
pub fn body_orienter(
  angle1 : @symcore.Expr,
  angle2 : @symcore.Expr,
  angle3 : @symcore.Expr,
  rotation_order : String,
) -> BodyOrienter raise @rawvec.VectorError {
  let normalized = rotation_order_normalize(rotation_order) catch {
    err => raise err
  }
  let axes = [
    rotation_order_axis(normalized[0]),
    rotation_order_axis(normalized[1]),
    rotation_order_axis(normalized[2]),
  ]
  let step1 = rotation_axis_matrix(axes[0], angle1).mul(
    rotation_axis_matrix(axes[1], angle2),
  ) catch {
    _ => abort("body_orienter-mul-1")
  }
  let step2 = step1.mul(rotation_axis_matrix(axes[2], angle3)) catch {
    _ => abort("body_orienter-mul-2")
  }
  let matrix = step2.transpose()
  {
    angle1_: angle1,
    angle2_: angle2,
    angle3_: angle3,
    rotation_order_: rotation_order,
    parent_orient_: matrix_simplify_entries(matrix),
  }
}

///|
pub fn space_orienter(
  angle1 : @symcore.Expr,
  angle2 : @symcore.Expr,
  angle3 : @symcore.Expr,
  rotation_order : String,
) -> SpaceOrienter raise @rawvec.VectorError {
  let normalized = rotation_order_normalize(rotation_order) catch {
    err => raise err
  }
  let axes = [
    rotation_order_axis(normalized[0]),
    rotation_order_axis(normalized[1]),
    rotation_order_axis(normalized[2]),
  ]
  let step1 = rotation_axis_matrix(axes[2], angle3).mul(
    rotation_axis_matrix(axes[1], angle2),
  ) catch {
    _ => abort("space_orienter-mul-1")
  }
  let step2 = step1.mul(rotation_axis_matrix(axes[0], angle1)) catch {
    _ => abort("space_orienter-mul-2")
  }
  let matrix = step2.transpose()
  {
    angle1_: angle1,
    angle2_: angle2,
    angle3_: angle3,
    rotation_order_: rotation_order,
    parent_orient_: matrix_simplify_entries(matrix),
  }
}

///|
pub fn quaternion_orienter(
  q0 : @symcore.Expr,
  q1 : @symcore.Expr,
  q2 : @symcore.Expr,
  q3 : @symcore.Expr,
) -> QuaternionOrienter {
  let matrix = @symphysics.explicit_matrix_from_rows([
    [
      (q0 ^ @symcore.int(2)) +
      (q1 ^ @symcore.int(2)) -
      (q2 ^ @symcore.int(2)) -
      (q3 ^ @symcore.int(2)),
      @symcore.int(2) * (q1 * q2 + q0 * q3),
      @symcore.int(2) * (@symcore.int(-1) * q0 * q2 + q1 * q3),
    ],
    [
      @symcore.int(2) * (@symcore.int(-1) * q0 * q3 + q1 * q2),
      (q0 ^ @symcore.int(2)) -
      (q1 ^ @symcore.int(2)) +
      (q2 ^ @symcore.int(2)) -
      (q3 ^ @symcore.int(2)),
      @symcore.int(2) * (q0 * q1 + q2 * q3),
    ],
    [
      @symcore.int(2) * (q0 * q2 + q1 * q3),
      @symcore.int(2) * (@symcore.int(-1) * q0 * q1 + q2 * q3),
      (q0 ^ @symcore.int(2)) -
      (q1 ^ @symcore.int(2)) -
      (q2 ^ @symcore.int(2)) +
      (q3 ^ @symcore.int(2)),
    ],
  ]) catch {
    _ => abort("quaternion_orienter")
  }
  {
    q0_: q0,
    q1_: q1,
    q2_: q2,
    q3_: q3,
    parent_orient_: matrix_simplify_entries(matrix),
  }
}

///|
pub fn orienter_axis(value : AxisOrienter) -> Orienter {
  Orienter::Axis(value)
}

///|
pub fn orienter_body(value : BodyOrienter) -> Orienter {
  Orienter::Body(value)
}

///|
pub fn orienter_space(value : SpaceOrienter) -> Orienter {
  Orienter::Space(value)
}

///|
pub fn orienter_quaternion(value : QuaternionOrienter) -> Orienter {
  Orienter::Quaternion(value)
}

///|
pub fn AxisOrienter::angle(self : AxisOrienter) -> @symcore.Expr {
  self.angle_
}

///|
pub fn AxisOrienter::axis(self : AxisOrienter) -> Vector {
  self.axis_
}

///|
pub fn AxisOrienter::rotation_matrix(
  self : AxisOrienter,
  system : CoordSys3D,
) -> @symphysics.ExplicitMatrix raise @rawvec.VectorError {
  let axis = self.axis_.express(system).normalize() catch { err => raise err }
  let axis_rows = (axis.to_matrix(system) catch { err => raise err }).rows_copy()
  let u0 = axis_rows[0][0]
  let u1 = axis_rows[1][0]
  let u2 = axis_rows[2][0]
  let theta = self.angle_
  let c = @symelem.cos(theta)
  let s = @symelem.sin(theta)
  let omc = @symcore.int(1) - c
  matrix_simplify_entries(
    (@symphysics.explicit_matrix_from_rows([
      [c + u0 * u0 * omc, u0 * u1 * omc - u2 * s, u0 * u2 * omc + u1 * s],
      [u1 * u0 * omc + u2 * s, c + u1 * u1 * omc, u1 * u2 * omc - u0 * s],
      [u2 * u0 * omc - u1 * s, u2 * u1 * omc + u0 * s, c + u2 * u2 * omc],
    ]) catch {
      _ => abort("AxisOrienter::rotation_matrix")
    }).transpose(),
  )
}

///|
pub fn BodyOrienter::rotation_matrix(
  self : BodyOrienter,
) -> @symphysics.ExplicitMatrix {
  self.parent_orient_
}

///|
pub fn SpaceOrienter::rotation_matrix(
  self : SpaceOrienter,
) -> @symphysics.ExplicitMatrix {
  self.parent_orient_
}

///|
pub fn QuaternionOrienter::rotation_matrix(
  self : QuaternionOrienter,
) -> @symphysics.ExplicitMatrix {
  self.parent_orient_
}

///|
fn orienter_rotation_matrix(
  orienter : Orienter,
  system : CoordSys3D,
) -> @symphysics.ExplicitMatrix raise @rawvec.VectorError {
  match orienter {
    Orienter::Axis(value) =>
      value.rotation_matrix(system) catch {
        err => raise err
      }
    Orienter::Body(value) => value.rotation_matrix()
    Orienter::Space(value) => value.rotation_matrix()
    Orienter::Quaternion(value) => value.rotation_matrix()
  }
}
