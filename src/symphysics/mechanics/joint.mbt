///|
/// Joint kinematics aligned with the high-value surface of
/// `sympy.physics.mechanics.joint`.

///|
pub enum JointAttachment {
  Point(@symvector.Point)
  Offset(@symvector.Vector)
} derive(Eq)

///|
pub enum JointInterframe {
  Frame(@symvector.ReferenceFrame)
  Axis(@symvector.Vector)
} derive(Eq)

///|
pub struct PinJoint {
  name_ : String
  parent_ : BodyLike
  child_ : BodyLike
  coordinates_ : Array[Expr]
  speeds_ : Array[Expr]
  parent_point_ : @symvector.Point
  child_point_ : @symvector.Point
  parent_interframe_ : @symvector.ReferenceFrame
  child_interframe_ : @symvector.ReferenceFrame
  parent_frame_ : @symvector.ReferenceFrame
  child_frame_ : @symvector.ReferenceFrame
  joint_axis_ : @symvector.Vector
  kdes_ : Array[Expr]
} derive(Eq)

///|
pub struct PrismaticJoint {
  name_ : String
  parent_ : BodyLike
  child_ : BodyLike
  coordinates_ : Array[Expr]
  speeds_ : Array[Expr]
  parent_point_ : @symvector.Point
  child_point_ : @symvector.Point
  parent_interframe_ : @symvector.ReferenceFrame
  child_interframe_ : @symvector.ReferenceFrame
  parent_frame_ : @symvector.ReferenceFrame
  child_frame_ : @symvector.ReferenceFrame
  joint_axis_ : @symvector.Vector
  kdes_ : Array[Expr]
} derive(Eq)

///|
pub struct CylindricalJoint {
  name_ : String
  parent_ : BodyLike
  child_ : BodyLike
  coordinates_ : Array[Expr]
  speeds_ : Array[Expr]
  parent_point_ : @symvector.Point
  child_point_ : @symvector.Point
  parent_interframe_ : @symvector.ReferenceFrame
  child_interframe_ : @symvector.ReferenceFrame
  parent_frame_ : @symvector.ReferenceFrame
  child_frame_ : @symvector.ReferenceFrame
  joint_axis_ : @symvector.Vector
  kdes_ : Array[Expr]
} derive(Eq)

///|
pub struct PlanarJoint {
  name_ : String
  parent_ : BodyLike
  child_ : BodyLike
  coordinates_ : Array[Expr]
  speeds_ : Array[Expr]
  parent_point_ : @symvector.Point
  child_point_ : @symvector.Point
  parent_interframe_ : @symvector.ReferenceFrame
  child_interframe_ : @symvector.ReferenceFrame
  parent_frame_ : @symvector.ReferenceFrame
  child_frame_ : @symvector.ReferenceFrame
  rotation_axis_ : @symvector.Vector
  planar_vectors_ : Array[@symvector.Vector]
  kdes_ : Array[Expr]
} derive(Eq)

///|
pub struct SphericalJoint {
  name_ : String
  parent_ : BodyLike
  child_ : BodyLike
  coordinates_ : Array[Expr]
  speeds_ : Array[Expr]
  parent_point_ : @symvector.Point
  child_point_ : @symvector.Point
  parent_interframe_ : @symvector.ReferenceFrame
  child_interframe_ : @symvector.ReferenceFrame
  parent_frame_ : @symvector.ReferenceFrame
  child_frame_ : @symvector.ReferenceFrame
  rot_type_ : String
  rot_order_ : String
  kdes_ : Array[Expr]
} derive(Eq)

///|
pub struct WeldJoint {
  name_ : String
  parent_ : BodyLike
  child_ : BodyLike
  parent_point_ : @symvector.Point
  child_point_ : @symvector.Point
  parent_interframe_ : @symvector.ReferenceFrame
  child_interframe_ : @symvector.ReferenceFrame
  parent_frame_ : @symvector.ReferenceFrame
  child_frame_ : @symvector.ReferenceFrame
} derive(Eq)

///|
pub enum JointLike {
  Pin(PinJoint)
  Prismatic(PrismaticJoint)
  Cylindrical(CylindricalJoint)
  Planar(PlanarJoint)
  Spherical(SphericalJoint)
  Weld(WeldJoint)
} derive(Eq)

///|
pub fn joint_attachment_point(point : @symvector.Point) -> JointAttachment {
  JointAttachment::Point(point)
}

///|
pub fn joint_attachment_offset(offset : @symvector.Vector) -> JointAttachment {
  JointAttachment::Offset(offset)
}

///|
pub fn joint_interframe_frame(
  frame : @symvector.ReferenceFrame,
) -> JointInterframe {
  JointInterframe::Frame(frame)
}

///|
pub fn joint_interframe_axis(axis : @symvector.Vector) -> JointInterframe {
  JointInterframe::Axis(axis)
}

///|
fn joint_default_coordinate(name : String) -> Expr {
  @symvector.dynamicsymbol("q_" + name)
}

///|
fn joint_default_speed(name : String) -> Expr {
  @symvector.dynamicsymbol("u_" + name)
}

///|
fn joint_default_coordinate_index(name : String, index : Int) -> Expr {
  @symvector.dynamicsymbol("q" + index.to_string() + "_" + name)
}

///|
fn joint_default_speed_index(name : String, index : Int) -> Expr {
  @symvector.dynamicsymbol("u" + index.to_string() + "_" + name)
}

///|
fn joint_default_frame(
  joint_name : String,
  body : BodyLike,
  suffix : String,
) -> @symvector.ReferenceFrame raise @symvector.VectorError {
  @symvector.reference_frame(
    joint_name + "_" + mech_bodylike_name(body) + "_" + suffix,
  )
}

///|
fn joint_locate_attachment(
  joint_name : String,
  body : BodyLike,
  role : String,
  attachment : JointAttachment?,
) -> @symvector.Point raise @symvector.VectorError {
  let masscenter = mech_bodylike_masscenter(body)
  match attachment {
    Some(JointAttachment::Point(point)) => point
    Some(JointAttachment::Offset(offset)) =>
      masscenter.locatenew(
        joint_name + "_" + mech_bodylike_name(body) + "_" + role,
        offset,
      )
    None => masscenter
  }
}

///|
fn joint_locate_interframe(
  joint_name : String,
  body : BodyLike,
  role : String,
  frame : @symvector.ReferenceFrame,
  interframe : JointInterframe?,
) -> @symvector.ReferenceFrame raise @symvector.VectorError {
  match interframe {
    Some(JointInterframe::Frame(value)) => value
    Some(JointInterframe::Axis(axis)) => {
      let aligned = @symvector.reference_frame(
        joint_name + "_" + mech_bodylike_name(body) + "_" + role + "_interframe",
      )
      let axis_unit = axis.normalize()
      let base_x = frame.x()
      let rotation_axis = base_x.cross(axis_unit)
      if rotation_axis.is_zero() {
        let dot = base_x.dot(axis_unit)
        if mech_expr_is_zero(dot + int(1)) {
          aligned.orient_axis(
            frame,
            frame.y(),
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
          )
        } else {
          aligned.orient_axis(frame, frame.x(), int(0))
        }
      } else {
        aligned.orient_axis(
          frame,
          rotation_axis,
          @symelem.acos(base_x.dot(axis_unit)),
        )
      }
      aligned
    }
    None => frame
  }
}

///|
fn joint_resolve_frame(
  joint_name : String,
  body : BodyLike,
  role : String,
  interframe : JointInterframe?,
) -> @symvector.ReferenceFrame raise @symvector.VectorError {
  match mech_bodylike_frame(body) {
    Some(frame) => frame
    None =>
      match interframe {
        Some(JointInterframe::Frame(frame)) => frame
        _ => joint_default_frame(joint_name, body, role + "_frame")
      }
  }
}

///|
fn joint_kdes(coordinates : Array[Expr], speeds : Array[Expr]) -> Array[Expr] {
  let out : Array[Expr] = []
  for i in 0..<coordinates.length() {
    out.push(
      mech_simplify_expr(
        speeds[i] -
        @symcalculus.diff(coordinates[i], @symvector.dynamicsymbols_t),
      ),
    )
  }
  out
}

///|
fn joint_qdot_subs(
  coordinates : Array[Expr],
  speeds : Array[Expr],
) -> Array[Substitution] {
  let out : Array[Substitution] = []
  for i in 0..<coordinates.length() {
    out.push(
      (
        @symcalculus.diff(coordinates[i], @symvector.dynamicsymbols_t),
        speeds[i],
      ),
    )
  }
  out
}

///|
fn joint_matrix_time_diff(
  matrix : @symphysics.ExplicitMatrix,
) -> @symphysics.ExplicitMatrix {
  matrix.map(fn(expr) {
    mech_simplify_expr(@symcalculus.diff(expr, @symvector.dynamicsymbols_t))
  })
}

///|
fn joint_omega_from_dcm_in_child(
  child : @symvector.ReferenceFrame,
  dcm : @symphysics.ExplicitMatrix,
) -> @symvector.Vector raise @symphysics.PhysicsError {
  let skew = joint_matrix_time_diff(dcm).mul(dcm.transpose()).neg()
  let wx = skew.get(2, 1)
  let wy = skew.get(0, 2)
  let wz = skew.get(1, 0)
  child.x().scale(wx) + child.y().scale(wy) + child.z().scale(wz)
}

///|
fn joint_resolve_axis(
  axis : @symvector.Vector?,
  frame : @symvector.ReferenceFrame,
) -> @symvector.Vector {
  match axis {
    Some(value) => value
    None => frame.x()
  }
}

///|
pub fn pin_joint(
  name : String,
  parent : BodyLike,
  child : BodyLike,
  coordinates? : Array[Expr]? = None,
  speeds? : Array[Expr]? = None,
  parent_point? : JointAttachment? = None,
  child_point? : JointAttachment? = None,
  parent_interframe? : JointInterframe? = None,
  child_interframe? : JointInterframe? = None,
  joint_axis? : @symvector.Vector? = None,
) -> PinJoint raise {
  let parent_frame = joint_resolve_frame(
    name, parent, "parent", parent_interframe,
  )
  let child_frame = joint_resolve_frame(name, child, "child", child_interframe)
  let resolved_parent_interframe = joint_locate_interframe(
    name, parent, "parent", parent_frame, parent_interframe,
  )
  let resolved_child_interframe = joint_locate_interframe(
    name, child, "child", child_frame, child_interframe,
  )
  let coord_list = coordinates.unwrap_or([joint_default_coordinate(name)])
  let speed_list = speeds.unwrap_or([joint_default_speed(name)])
  validate_coordinates(coordinates=coord_list, speeds=speed_list)
  let kdes = joint_kdes(coord_list, speed_list)
  let resolved_axis = joint_resolve_axis(joint_axis, resolved_parent_interframe)
  let parent_joint_point = joint_locate_attachment(
    name, parent, "parent_point", parent_point,
  )
  let child_joint_point = joint_locate_attachment(
    name, child, "child_point", child_point,
  )

  resolved_child_interframe.orient_axis(
    resolved_parent_interframe,
    resolved_axis,
    coord_list[0],
  )
  resolved_child_interframe.set_ang_vel(
    resolved_parent_interframe,
    resolved_axis.normalize().scale(speed_list[0]),
  )
  child_joint_point.set_pos(parent_joint_point, @symvector.vector_zero())
  parent_joint_point.set_vel(parent_frame, @symvector.vector_zero())
  child_joint_point.set_vel(child_frame, @symvector.vector_zero())
  ignore(
    mech_bodylike_masscenter(child).v2pt_theory(
      parent_joint_point, parent_frame, child_frame,
    ),
  )

  PinJoint::{
    name_: name,
    parent_: parent,
    child_: child,
    coordinates_: coord_list,
    speeds_: speed_list,
    parent_point_: parent_joint_point,
    child_point_: child_joint_point,
    parent_interframe_: resolved_parent_interframe,
    child_interframe_: resolved_child_interframe,
    parent_frame_: parent_frame,
    child_frame_: child_frame,
    joint_axis_: resolved_axis,
    kdes_: kdes,
  }
}

///|
pub fn PinJoint::name(self : PinJoint) -> String {
  self.name_
}

///|
pub fn PinJoint::parent(self : PinJoint) -> BodyLike {
  self.parent_
}

///|
pub fn PinJoint::child(self : PinJoint) -> BodyLike {
  self.child_
}

///|
pub fn PinJoint::coordinates(self : PinJoint) -> Array[Expr] {
  self.coordinates_.copy()
}

///|
pub fn PinJoint::speeds(self : PinJoint) -> Array[Expr] {
  self.speeds_.copy()
}

///|
pub fn PinJoint::kdes(self : PinJoint) -> Array[Expr] {
  self.kdes_.copy()
}

///|
pub fn PinJoint::parent_point(self : PinJoint) -> @symvector.Point {
  self.parent_point_
}

///|
pub fn PinJoint::child_point(self : PinJoint) -> @symvector.Point {
  self.child_point_
}

///|
pub fn PinJoint::parent_interframe(
  self : PinJoint,
) -> @symvector.ReferenceFrame {
  self.parent_interframe_
}

///|
pub fn PinJoint::child_interframe(self : PinJoint) -> @symvector.ReferenceFrame {
  self.child_interframe_
}

///|
pub fn PinJoint::parent_frame(self : PinJoint) -> @symvector.ReferenceFrame {
  self.parent_frame_
}

///|
pub fn PinJoint::child_frame(self : PinJoint) -> @symvector.ReferenceFrame {
  self.child_frame_
}

///|
pub fn PinJoint::joint_axis(self : PinJoint) -> @symvector.Vector {
  self.joint_axis_
}

///|
pub fn PinJoint::repr(self : PinJoint) -> String {
  "PinJoint: " +
  self.name_ +
  "  parent: " +
  mech_bodylike_name(self.parent_) +
  "  child: " +
  mech_bodylike_name(self.child_)
}

///|
pub fn PinJoint::as_joint(self : PinJoint) -> JointLike {
  JointLike::Pin(self)
}

///|
pub fn prismatic_joint(
  name : String,
  parent : BodyLike,
  child : BodyLike,
  coordinates? : Array[Expr]? = None,
  speeds? : Array[Expr]? = None,
  parent_point? : JointAttachment? = None,
  child_point? : JointAttachment? = None,
  parent_interframe? : JointInterframe? = None,
  child_interframe? : JointInterframe? = None,
  joint_axis? : @symvector.Vector? = None,
) -> PrismaticJoint raise {
  let parent_frame = joint_resolve_frame(
    name, parent, "parent", parent_interframe,
  )
  let child_frame = joint_resolve_frame(name, child, "child", child_interframe)
  let resolved_parent_interframe = joint_locate_interframe(
    name, parent, "parent", parent_frame, parent_interframe,
  )
  let resolved_child_interframe = joint_locate_interframe(
    name, child, "child", child_frame, child_interframe,
  )
  let coord_list = coordinates.unwrap_or([joint_default_coordinate(name)])
  let speed_list = speeds.unwrap_or([joint_default_speed(name)])
  validate_coordinates(coordinates=coord_list, speeds=speed_list)
  let kdes = joint_kdes(coord_list, speed_list)
  let resolved_axis = joint_resolve_axis(joint_axis, resolved_parent_interframe).normalize()
  let parent_joint_point = joint_locate_attachment(
    name, parent, "parent_point", parent_point,
  )
  let child_joint_point = joint_locate_attachment(
    name, child, "child_point", child_point,
  )

  resolved_child_interframe.orient_axis(
    resolved_parent_interframe,
    resolved_axis,
    int(0),
  )
  resolved_child_interframe.set_ang_vel(
    resolved_parent_interframe,
    @symvector.vector_zero(),
  )
  child_joint_point.set_pos(
    parent_joint_point,
    resolved_axis.scale(coord_list[0]),
  )
  parent_joint_point.set_vel(parent_frame, @symvector.vector_zero())
  child_joint_point.set_vel(child_frame, @symvector.vector_zero())
  child_joint_point.set_vel(parent_frame, resolved_axis.scale(speed_list[0]))
  ignore(
    mech_bodylike_masscenter(child).v2pt_theory(
      child_joint_point, parent_frame, child_frame,
    ),
  )

  PrismaticJoint::{
    name_: name,
    parent_: parent,
    child_: child,
    coordinates_: coord_list,
    speeds_: speed_list,
    parent_point_: parent_joint_point,
    child_point_: child_joint_point,
    parent_interframe_: resolved_parent_interframe,
    child_interframe_: resolved_child_interframe,
    parent_frame_: parent_frame,
    child_frame_: child_frame,
    joint_axis_: resolved_axis,
    kdes_: kdes,
  }
}

///|
pub fn PrismaticJoint::name(self : PrismaticJoint) -> String {
  self.name_
}

///|
pub fn PrismaticJoint::parent(self : PrismaticJoint) -> BodyLike {
  self.parent_
}

///|
pub fn PrismaticJoint::child(self : PrismaticJoint) -> BodyLike {
  self.child_
}

///|
pub fn PrismaticJoint::coordinates(self : PrismaticJoint) -> Array[Expr] {
  self.coordinates_.copy()
}

///|
pub fn PrismaticJoint::speeds(self : PrismaticJoint) -> Array[Expr] {
  self.speeds_.copy()
}

///|
pub fn PrismaticJoint::kdes(self : PrismaticJoint) -> Array[Expr] {
  self.kdes_.copy()
}

///|
pub fn PrismaticJoint::parent_point(self : PrismaticJoint) -> @symvector.Point {
  self.parent_point_
}

///|
pub fn PrismaticJoint::child_point(self : PrismaticJoint) -> @symvector.Point {
  self.child_point_
}

///|
pub fn PrismaticJoint::parent_interframe(
  self : PrismaticJoint,
) -> @symvector.ReferenceFrame {
  self.parent_interframe_
}

///|
pub fn PrismaticJoint::child_interframe(
  self : PrismaticJoint,
) -> @symvector.ReferenceFrame {
  self.child_interframe_
}

///|
pub fn PrismaticJoint::parent_frame(
  self : PrismaticJoint,
) -> @symvector.ReferenceFrame {
  self.parent_frame_
}

///|
pub fn PrismaticJoint::child_frame(
  self : PrismaticJoint,
) -> @symvector.ReferenceFrame {
  self.child_frame_
}

///|
pub fn PrismaticJoint::joint_axis(self : PrismaticJoint) -> @symvector.Vector {
  self.joint_axis_
}

///|
pub fn PrismaticJoint::repr(self : PrismaticJoint) -> String {
  "PrismaticJoint: " +
  self.name_ +
  "  parent: " +
  mech_bodylike_name(self.parent_) +
  "  child: " +
  mech_bodylike_name(self.child_)
}

///|
pub fn PrismaticJoint::as_joint(self : PrismaticJoint) -> JointLike {
  JointLike::Prismatic(self)
}

///|
pub fn cylindrical_joint(
  name : String,
  parent : BodyLike,
  child : BodyLike,
  rotation_coordinate? : Expr? = None,
  translation_coordinate? : Expr? = None,
  rotation_speed? : Expr? = None,
  translation_speed? : Expr? = None,
  parent_point? : JointAttachment? = None,
  child_point? : JointAttachment? = None,
  parent_interframe? : JointInterframe? = None,
  child_interframe? : JointInterframe? = None,
  joint_axis? : @symvector.Vector? = None,
) -> CylindricalJoint raise {
  let parent_frame = joint_resolve_frame(
    name, parent, "parent", parent_interframe,
  )
  let child_frame = joint_resolve_frame(name, child, "child", child_interframe)
  let resolved_parent_interframe = joint_locate_interframe(
    name, parent, "parent", parent_frame, parent_interframe,
  )
  let resolved_child_interframe = joint_locate_interframe(
    name, child, "child", child_frame, child_interframe,
  )
  let coordinates = [
    rotation_coordinate.unwrap_or(joint_default_coordinate_index(name, 0)),
    translation_coordinate.unwrap_or(joint_default_coordinate_index(name, 1)),
  ]
  let speeds = [
    rotation_speed.unwrap_or(joint_default_speed_index(name, 0)),
    translation_speed.unwrap_or(joint_default_speed_index(name, 1)),
  ]
  validate_coordinates(coordinates~, speeds~)
  let kdes = joint_kdes(coordinates, speeds)
  let resolved_axis = joint_resolve_axis(joint_axis, resolved_parent_interframe).normalize()
  let parent_joint_point = joint_locate_attachment(
    name, parent, "parent_point", parent_point,
  )
  let child_joint_point = joint_locate_attachment(
    name, child, "child_point", child_point,
  )

  resolved_child_interframe.orient_axis(
    resolved_parent_interframe,
    resolved_axis,
    coordinates[0],
  )
  resolved_child_interframe.set_ang_vel(
    resolved_parent_interframe,
    resolved_axis.scale(speeds[0]),
  )
  child_joint_point.set_pos(
    parent_joint_point,
    resolved_axis.scale(coordinates[1]),
  )
  parent_joint_point.set_vel(parent_frame, @symvector.vector_zero())
  child_joint_point.set_vel(child_frame, @symvector.vector_zero())
  child_joint_point.set_vel(parent_frame, resolved_axis.scale(speeds[1]))
  ignore(
    mech_bodylike_masscenter(child).v2pt_theory(
      child_joint_point, parent_frame, child_frame,
    ),
  )

  CylindricalJoint::{
    name_: name,
    parent_: parent,
    child_: child,
    coordinates_: coordinates,
    speeds_: speeds,
    parent_point_: parent_joint_point,
    child_point_: child_joint_point,
    parent_interframe_: resolved_parent_interframe,
    child_interframe_: resolved_child_interframe,
    parent_frame_: parent_frame,
    child_frame_: child_frame,
    joint_axis_: resolved_axis,
    kdes_: kdes,
  }
}

///|
pub fn CylindricalJoint::name(self : CylindricalJoint) -> String {
  self.name_
}

///|
pub fn CylindricalJoint::parent(self : CylindricalJoint) -> BodyLike {
  self.parent_
}

///|
pub fn CylindricalJoint::child(self : CylindricalJoint) -> BodyLike {
  self.child_
}

///|
pub fn CylindricalJoint::coordinates(self : CylindricalJoint) -> Array[Expr] {
  self.coordinates_.copy()
}

///|
pub fn CylindricalJoint::speeds(self : CylindricalJoint) -> Array[Expr] {
  self.speeds_.copy()
}

///|
pub fn CylindricalJoint::kdes(self : CylindricalJoint) -> Array[Expr] {
  self.kdes_.copy()
}

///|
pub fn CylindricalJoint::parent_point(
  self : CylindricalJoint,
) -> @symvector.Point {
  self.parent_point_
}

///|
pub fn CylindricalJoint::child_point(
  self : CylindricalJoint,
) -> @symvector.Point {
  self.child_point_
}

///|
pub fn CylindricalJoint::parent_interframe(
  self : CylindricalJoint,
) -> @symvector.ReferenceFrame {
  self.parent_interframe_
}

///|
pub fn CylindricalJoint::child_interframe(
  self : CylindricalJoint,
) -> @symvector.ReferenceFrame {
  self.child_interframe_
}

///|
pub fn CylindricalJoint::parent_frame(
  self : CylindricalJoint,
) -> @symvector.ReferenceFrame {
  self.parent_frame_
}

///|
pub fn CylindricalJoint::child_frame(
  self : CylindricalJoint,
) -> @symvector.ReferenceFrame {
  self.child_frame_
}

///|
pub fn CylindricalJoint::joint_axis(
  self : CylindricalJoint,
) -> @symvector.Vector {
  self.joint_axis_
}

///|
pub fn CylindricalJoint::rotation_coordinate(self : CylindricalJoint) -> Expr {
  self.coordinates_[0]
}

///|
pub fn CylindricalJoint::translation_coordinate(
  self : CylindricalJoint,
) -> Expr {
  self.coordinates_[1]
}

///|
pub fn CylindricalJoint::rotation_speed(self : CylindricalJoint) -> Expr {
  self.speeds_[0]
}

///|
pub fn CylindricalJoint::translation_speed(self : CylindricalJoint) -> Expr {
  self.speeds_[1]
}

///|
pub fn CylindricalJoint::repr(self : CylindricalJoint) -> String {
  "CylindricalJoint: " +
  self.name_ +
  "  parent: " +
  mech_bodylike_name(self.parent_) +
  "  child: " +
  mech_bodylike_name(self.child_)
}

///|
pub fn CylindricalJoint::as_joint(self : CylindricalJoint) -> JointLike {
  JointLike::Cylindrical(self)
}

///|
pub fn planar_joint(
  name : String,
  parent : BodyLike,
  child : BodyLike,
  rotation_coordinate? : Expr? = None,
  planar_coordinates? : Array[Expr]? = None,
  rotation_speed? : Expr? = None,
  planar_speeds? : Array[Expr]? = None,
  parent_point? : JointAttachment? = None,
  child_point? : JointAttachment? = None,
  parent_interframe? : JointInterframe? = None,
  child_interframe? : JointInterframe? = None,
) -> PlanarJoint raise {
  let parent_frame = joint_resolve_frame(
    name, parent, "parent", parent_interframe,
  )
  let child_frame = joint_resolve_frame(name, child, "child", child_interframe)
  let resolved_parent_interframe = joint_locate_interframe(
    name, parent, "parent", parent_frame, parent_interframe,
  )
  let resolved_child_interframe = joint_locate_interframe(
    name, child, "child", child_frame, child_interframe,
  )
  let planar_coords = planar_coordinates.unwrap_or([
    joint_default_coordinate_index(name, 1),
    joint_default_coordinate_index(name, 2),
  ])
  let planar_speed_values = planar_speeds.unwrap_or([
    joint_default_speed_index(name, 1),
    joint_default_speed_index(name, 2),
  ])
  let coordinates = [
      rotation_coordinate.unwrap_or(joint_default_coordinate_index(name, 0)),
    ] +
    planar_coords
  let speeds = [rotation_speed.unwrap_or(joint_default_speed_index(name, 0))] +
    planar_speed_values
  validate_coordinates(coordinates~, speeds~)
  let kdes = joint_kdes(coordinates, speeds)
  let rotation_axis = resolved_parent_interframe.x().normalize()
  let planar_vectors = [
    resolved_parent_interframe.y().normalize(),
    resolved_parent_interframe.z().normalize(),
  ]
  let parent_joint_point = joint_locate_attachment(
    name, parent, "parent_point", parent_point,
  )
  let child_joint_point = joint_locate_attachment(
    name, child, "child_point", child_point,
  )

  resolved_child_interframe.orient_axis(
    resolved_parent_interframe,
    rotation_axis,
    coordinates[0],
  )
  resolved_child_interframe.set_ang_vel(
    resolved_parent_interframe,
    rotation_axis.scale(speeds[0]),
  )
  child_joint_point.set_pos(
    parent_joint_point,
    planar_vectors[0].scale(coordinates[1]) +
    planar_vectors[1].scale(coordinates[2]),
  )
  parent_joint_point.set_vel(parent_frame, @symvector.vector_zero())
  child_joint_point.set_vel(child_frame, @symvector.vector_zero())
  child_joint_point.set_vel(
    parent_frame,
    planar_vectors[0].scale(speeds[1]) + planar_vectors[1].scale(speeds[2]),
  )
  ignore(
    mech_bodylike_masscenter(child).v2pt_theory(
      child_joint_point, parent_frame, child_frame,
    ),
  )

  PlanarJoint::{
    name_: name,
    parent_: parent,
    child_: child,
    coordinates_: coordinates,
    speeds_: speeds,
    parent_point_: parent_joint_point,
    child_point_: child_joint_point,
    parent_interframe_: resolved_parent_interframe,
    child_interframe_: resolved_child_interframe,
    parent_frame_: parent_frame,
    child_frame_: child_frame,
    rotation_axis_: rotation_axis,
    planar_vectors_: planar_vectors,
    kdes_: kdes,
  }
}

///|
pub fn PlanarJoint::name(self : PlanarJoint) -> String {
  self.name_
}

///|
pub fn PlanarJoint::parent(self : PlanarJoint) -> BodyLike {
  self.parent_
}

///|
pub fn PlanarJoint::child(self : PlanarJoint) -> BodyLike {
  self.child_
}

///|
pub fn PlanarJoint::coordinates(self : PlanarJoint) -> Array[Expr] {
  self.coordinates_.copy()
}

///|
pub fn PlanarJoint::speeds(self : PlanarJoint) -> Array[Expr] {
  self.speeds_.copy()
}

///|
pub fn PlanarJoint::kdes(self : PlanarJoint) -> Array[Expr] {
  self.kdes_.copy()
}

///|
pub fn PlanarJoint::parent_point(self : PlanarJoint) -> @symvector.Point {
  self.parent_point_
}

///|
pub fn PlanarJoint::child_point(self : PlanarJoint) -> @symvector.Point {
  self.child_point_
}

///|
pub fn PlanarJoint::parent_interframe(
  self : PlanarJoint,
) -> @symvector.ReferenceFrame {
  self.parent_interframe_
}

///|
pub fn PlanarJoint::child_interframe(
  self : PlanarJoint,
) -> @symvector.ReferenceFrame {
  self.child_interframe_
}

///|
pub fn PlanarJoint::parent_frame(
  self : PlanarJoint,
) -> @symvector.ReferenceFrame {
  self.parent_frame_
}

///|
pub fn PlanarJoint::child_frame(
  self : PlanarJoint,
) -> @symvector.ReferenceFrame {
  self.child_frame_
}

///|
pub fn PlanarJoint::rotation_coordinate(self : PlanarJoint) -> Expr {
  self.coordinates_[0]
}

///|
pub fn PlanarJoint::planar_coordinates(self : PlanarJoint) -> Array[Expr] {
  [self.coordinates_[1], self.coordinates_[2]]
}

///|
pub fn PlanarJoint::rotation_speed(self : PlanarJoint) -> Expr {
  self.speeds_[0]
}

///|
pub fn PlanarJoint::planar_speeds(self : PlanarJoint) -> Array[Expr] {
  [self.speeds_[1], self.speeds_[2]]
}

///|
pub fn PlanarJoint::rotation_axis(self : PlanarJoint) -> @symvector.Vector {
  self.rotation_axis_
}

///|
pub fn PlanarJoint::planar_vectors(
  self : PlanarJoint,
) -> Array[@symvector.Vector] {
  self.planar_vectors_.copy()
}

///|
pub fn PlanarJoint::repr(self : PlanarJoint) -> String {
  "PlanarJoint: " +
  self.name_ +
  "  parent: " +
  mech_bodylike_name(self.parent_) +
  "  child: " +
  mech_bodylike_name(self.child_)
}

///|
pub fn PlanarJoint::as_joint(self : PlanarJoint) -> JointLike {
  JointLike::Planar(self)
}

///|
pub fn spherical_joint(
  name : String,
  parent : BodyLike,
  child : BodyLike,
  coordinates? : Array[Expr]? = None,
  speeds? : Array[Expr]? = None,
  parent_point? : JointAttachment? = None,
  child_point? : JointAttachment? = None,
  parent_interframe? : JointInterframe? = None,
  child_interframe? : JointInterframe? = None,
  rot_type? : String = "BODY",
  rot_order? : String = "123",
) -> SphericalJoint raise {
  let parent_frame = joint_resolve_frame(
    name, parent, "parent", parent_interframe,
  )
  let child_frame = joint_resolve_frame(name, child, "child", child_interframe)
  let resolved_parent_interframe = joint_locate_interframe(
    name, parent, "parent", parent_frame, parent_interframe,
  )
  let resolved_child_interframe = joint_locate_interframe(
    name, child, "child", child_frame, child_interframe,
  )
  let coordinate_values = coordinates.unwrap_or([
    joint_default_coordinate_index(name, 0),
    joint_default_coordinate_index(name, 1),
    joint_default_coordinate_index(name, 2),
  ])
  let speed_values = speeds.unwrap_or([
    joint_default_speed_index(name, 0),
    joint_default_speed_index(name, 1),
    joint_default_speed_index(name, 2),
  ])
  validate_coordinates(coordinates=coordinate_values, speeds=speed_values)
  let kdes = joint_kdes(coordinate_values, speed_values)
  let parent_joint_point = joint_locate_attachment(
    name, parent, "parent_point", parent_point,
  )
  let child_joint_point = joint_locate_attachment(
    name, child, "child_point", child_point,
  )
  let rotation_kind = rot_type.to_lower()
  if rotation_kind == "space" {
    resolved_child_interframe.orient_space_fixed(
      resolved_parent_interframe, coordinate_values, rot_order,
    )
  } else {
    resolved_child_interframe.orient_body_fixed(
      resolved_parent_interframe, coordinate_values, rot_order,
    )
  }
  let omega = msubs_vector(
    joint_omega_from_dcm_in_child(
      resolved_child_interframe,
      resolved_child_interframe.dcm(resolved_parent_interframe),
    ),
    joint_qdot_subs(coordinate_values, speed_values),
  )
  resolved_child_interframe.set_ang_vel(resolved_parent_interframe, omega)
  child_joint_point.set_pos(parent_joint_point, @symvector.vector_zero())
  parent_joint_point.set_vel(parent_frame, @symvector.vector_zero())
  child_joint_point.set_vel(child_frame, @symvector.vector_zero())
  ignore(
    mech_bodylike_masscenter(child).v2pt_theory(
      parent_joint_point, parent_frame, child_frame,
    ),
  )

  SphericalJoint::{
    name_: name,
    parent_: parent,
    child_: child,
    coordinates_: coordinate_values,
    speeds_: speed_values,
    parent_point_: parent_joint_point,
    child_point_: child_joint_point,
    parent_interframe_: resolved_parent_interframe,
    child_interframe_: resolved_child_interframe,
    parent_frame_: parent_frame,
    child_frame_: child_frame,
    rot_type_: rot_type,
    rot_order_: rot_order,
    kdes_: kdes,
  }
}

///|
pub fn SphericalJoint::name(self : SphericalJoint) -> String {
  self.name_
}

///|
pub fn SphericalJoint::parent(self : SphericalJoint) -> BodyLike {
  self.parent_
}

///|
pub fn SphericalJoint::child(self : SphericalJoint) -> BodyLike {
  self.child_
}

///|
pub fn SphericalJoint::coordinates(self : SphericalJoint) -> Array[Expr] {
  self.coordinates_.copy()
}

///|
pub fn SphericalJoint::speeds(self : SphericalJoint) -> Array[Expr] {
  self.speeds_.copy()
}

///|
pub fn SphericalJoint::kdes(self : SphericalJoint) -> Array[Expr] {
  self.kdes_.copy()
}

///|
pub fn SphericalJoint::parent_point(self : SphericalJoint) -> @symvector.Point {
  self.parent_point_
}

///|
pub fn SphericalJoint::child_point(self : SphericalJoint) -> @symvector.Point {
  self.child_point_
}

///|
pub fn SphericalJoint::parent_interframe(
  self : SphericalJoint,
) -> @symvector.ReferenceFrame {
  self.parent_interframe_
}

///|
pub fn SphericalJoint::child_interframe(
  self : SphericalJoint,
) -> @symvector.ReferenceFrame {
  self.child_interframe_
}

///|
pub fn SphericalJoint::parent_frame(
  self : SphericalJoint,
) -> @symvector.ReferenceFrame {
  self.parent_frame_
}

///|
pub fn SphericalJoint::child_frame(
  self : SphericalJoint,
) -> @symvector.ReferenceFrame {
  self.child_frame_
}

///|
pub fn SphericalJoint::repr(self : SphericalJoint) -> String {
  "SphericalJoint: " +
  self.name_ +
  "  parent: " +
  mech_bodylike_name(self.parent_) +
  "  child: " +
  mech_bodylike_name(self.child_)
}

///|
pub fn SphericalJoint::as_joint(self : SphericalJoint) -> JointLike {
  JointLike::Spherical(self)
}

///|
pub fn weld_joint(
  name : String,
  parent : BodyLike,
  child : BodyLike,
  parent_point? : JointAttachment? = None,
  child_point? : JointAttachment? = None,
  parent_interframe? : JointInterframe? = None,
  child_interframe? : JointInterframe? = None,
) -> WeldJoint raise @symvector.VectorError {
  let parent_frame = joint_resolve_frame(
    name, parent, "parent", parent_interframe,
  )
  let child_frame = joint_resolve_frame(name, child, "child", child_interframe)
  let resolved_parent_interframe = joint_locate_interframe(
    name, parent, "parent", parent_frame, parent_interframe,
  )
  let resolved_child_interframe = joint_locate_interframe(
    name, child, "child", child_frame, child_interframe,
  )
  let parent_joint_point = joint_locate_attachment(
    name, parent, "parent_point", parent_point,
  )
  let child_joint_point = joint_locate_attachment(
    name, child, "child_point", child_point,
  )
  resolved_child_interframe.orient_axis(
    resolved_parent_interframe,
    resolved_parent_interframe.x(),
    int(0),
  )
  resolved_child_interframe.set_ang_vel(
    resolved_parent_interframe,
    @symvector.vector_zero(),
  )
  child_joint_point.set_pos(parent_joint_point, @symvector.vector_zero())
  parent_joint_point.set_vel(parent_frame, @symvector.vector_zero())
  child_joint_point.set_vel(child_frame, @symvector.vector_zero())
  ignore(
    mech_bodylike_masscenter(child).v2pt_theory(
      parent_joint_point, parent_frame, child_frame,
    ),
  )
  WeldJoint::{
    name_: name,
    parent_: parent,
    child_: child,
    parent_point_: parent_joint_point,
    child_point_: child_joint_point,
    parent_interframe_: resolved_parent_interframe,
    child_interframe_: resolved_child_interframe,
    parent_frame_: parent_frame,
    child_frame_: child_frame,
  }
}

///|
pub fn WeldJoint::name(self : WeldJoint) -> String {
  self.name_
}

///|
pub fn WeldJoint::parent(self : WeldJoint) -> BodyLike {
  self.parent_
}

///|
pub fn WeldJoint::child(self : WeldJoint) -> BodyLike {
  self.child_
}

///|
pub fn WeldJoint::coordinates(_self : WeldJoint) -> Array[Expr] {
  []
}

///|
pub fn WeldJoint::speeds(_self : WeldJoint) -> Array[Expr] {
  []
}

///|
pub fn WeldJoint::kdes(_self : WeldJoint) -> Array[Expr] {
  []
}

///|
pub fn WeldJoint::parent_point(self : WeldJoint) -> @symvector.Point {
  self.parent_point_
}

///|
pub fn WeldJoint::child_point(self : WeldJoint) -> @symvector.Point {
  self.child_point_
}

///|
pub fn WeldJoint::parent_interframe(
  self : WeldJoint,
) -> @symvector.ReferenceFrame {
  self.parent_interframe_
}

///|
pub fn WeldJoint::child_interframe(
  self : WeldJoint,
) -> @symvector.ReferenceFrame {
  self.child_interframe_
}

///|
pub fn WeldJoint::parent_frame(self : WeldJoint) -> @symvector.ReferenceFrame {
  self.parent_frame_
}

///|
pub fn WeldJoint::child_frame(self : WeldJoint) -> @symvector.ReferenceFrame {
  self.child_frame_
}

///|
pub fn WeldJoint::repr(self : WeldJoint) -> String {
  "WeldJoint: " +
  self.name_ +
  "  parent: " +
  mech_bodylike_name(self.parent_) +
  "  child: " +
  mech_bodylike_name(self.child_)
}

///|
pub fn WeldJoint::as_joint(self : WeldJoint) -> JointLike {
  JointLike::Weld(self)
}

///|
pub fn JointLike::name(self : JointLike) -> String {
  match self {
    JointLike::Pin(value) => value.name()
    JointLike::Prismatic(value) => value.name()
    JointLike::Cylindrical(value) => value.name()
    JointLike::Planar(value) => value.name()
    JointLike::Spherical(value) => value.name()
    JointLike::Weld(value) => value.name()
  }
}

///|
pub fn JointLike::parent(self : JointLike) -> BodyLike {
  match self {
    JointLike::Pin(value) => value.parent()
    JointLike::Prismatic(value) => value.parent()
    JointLike::Cylindrical(value) => value.parent()
    JointLike::Planar(value) => value.parent()
    JointLike::Spherical(value) => value.parent()
    JointLike::Weld(value) => value.parent()
  }
}

///|
pub fn JointLike::child(self : JointLike) -> BodyLike {
  match self {
    JointLike::Pin(value) => value.child()
    JointLike::Prismatic(value) => value.child()
    JointLike::Cylindrical(value) => value.child()
    JointLike::Planar(value) => value.child()
    JointLike::Spherical(value) => value.child()
    JointLike::Weld(value) => value.child()
  }
}

///|
pub fn JointLike::coordinates(self : JointLike) -> Array[Expr] {
  match self {
    JointLike::Pin(value) => value.coordinates()
    JointLike::Prismatic(value) => value.coordinates()
    JointLike::Cylindrical(value) => value.coordinates()
    JointLike::Planar(value) => value.coordinates()
    JointLike::Spherical(value) => value.coordinates()
    JointLike::Weld(value) => value.coordinates()
  }
}

///|
pub fn JointLike::speeds(self : JointLike) -> Array[Expr] {
  match self {
    JointLike::Pin(value) => value.speeds()
    JointLike::Prismatic(value) => value.speeds()
    JointLike::Cylindrical(value) => value.speeds()
    JointLike::Planar(value) => value.speeds()
    JointLike::Spherical(value) => value.speeds()
    JointLike::Weld(value) => value.speeds()
  }
}

///|
pub fn JointLike::kdes(self : JointLike) -> Array[Expr] {
  match self {
    JointLike::Pin(value) => value.kdes()
    JointLike::Prismatic(value) => value.kdes()
    JointLike::Cylindrical(value) => value.kdes()
    JointLike::Planar(value) => value.kdes()
    JointLike::Spherical(value) => value.kdes()
    JointLike::Weld(value) => value.kdes()
  }
}

///|
pub fn JointLike::parent_point(self : JointLike) -> @symvector.Point {
  match self {
    JointLike::Pin(value) => value.parent_point()
    JointLike::Prismatic(value) => value.parent_point()
    JointLike::Cylindrical(value) => value.parent_point()
    JointLike::Planar(value) => value.parent_point()
    JointLike::Spherical(value) => value.parent_point()
    JointLike::Weld(value) => value.parent_point()
  }
}

///|
pub fn JointLike::child_point(self : JointLike) -> @symvector.Point {
  match self {
    JointLike::Pin(value) => value.child_point()
    JointLike::Prismatic(value) => value.child_point()
    JointLike::Cylindrical(value) => value.child_point()
    JointLike::Planar(value) => value.child_point()
    JointLike::Spherical(value) => value.child_point()
    JointLike::Weld(value) => value.child_point()
  }
}

///|
pub fn JointLike::parent_interframe(
  self : JointLike,
) -> @symvector.ReferenceFrame {
  match self {
    JointLike::Pin(value) => value.parent_interframe()
    JointLike::Prismatic(value) => value.parent_interframe()
    JointLike::Cylindrical(value) => value.parent_interframe()
    JointLike::Planar(value) => value.parent_interframe()
    JointLike::Spherical(value) => value.parent_interframe()
    JointLike::Weld(value) => value.parent_interframe()
  }
}

///|
pub fn JointLike::child_interframe(
  self : JointLike,
) -> @symvector.ReferenceFrame {
  match self {
    JointLike::Pin(value) => value.child_interframe()
    JointLike::Prismatic(value) => value.child_interframe()
    JointLike::Cylindrical(value) => value.child_interframe()
    JointLike::Planar(value) => value.child_interframe()
    JointLike::Spherical(value) => value.child_interframe()
    JointLike::Weld(value) => value.child_interframe()
  }
}

///|
pub fn JointLike::parent_frame(self : JointLike) -> @symvector.ReferenceFrame {
  match self {
    JointLike::Pin(value) => value.parent_frame()
    JointLike::Prismatic(value) => value.parent_frame()
    JointLike::Cylindrical(value) => value.parent_frame()
    JointLike::Planar(value) => value.parent_frame()
    JointLike::Spherical(value) => value.parent_frame()
    JointLike::Weld(value) => value.parent_frame()
  }
}

///|
pub fn JointLike::child_frame(self : JointLike) -> @symvector.ReferenceFrame {
  match self {
    JointLike::Pin(value) => value.child_frame()
    JointLike::Prismatic(value) => value.child_frame()
    JointLike::Cylindrical(value) => value.child_frame()
    JointLike::Planar(value) => value.child_frame()
    JointLike::Spherical(value) => value.child_frame()
    JointLike::Weld(value) => value.child_frame()
  }
}

///|
pub fn JointLike::repr(self : JointLike) -> String {
  match self {
    JointLike::Pin(value) => value.repr()
    JointLike::Prismatic(value) => value.repr()
    JointLike::Cylindrical(value) => value.repr()
    JointLike::Planar(value) => value.repr()
    JointLike::Spherical(value) => value.repr()
    JointLike::Weld(value) => value.repr()
  }
}
