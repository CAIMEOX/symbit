///|
/// Reference frames and orientation relations aligned with
/// `sympy.physics.vector.frame`.

///|
pub impl Eq for ReferenceFrame with fn equal(self, other : ReferenceFrame) -> Bool {
  self.index_ == other.index_
}

///|
pub impl Eq for ReferenceFrame with fn not_equal(self, other : ReferenceFrame) -> Bool {
  self.index_ != other.index_
}

///|
pub fn reference_frame(
  name : String,
  indices? : Array[String]? = None,
  latexs? : Array[String]? = None,
  variables? : Array[String]? = None,
) -> ReferenceFrame raise VectorError {
  if name == "" {
    raise ValueError("frame name must be non-empty")
  }
  let next_index = vector_frame_registry.length() + 1
  let idxs = match indices {
    Some(vals) if vals.length() == 3 => vals
    Some(_) => raise ValueError("indices must have length 3")
    None => ["x", "y", "z"]
  }
  let ltx = match latexs {
    Some(vals) if vals.length() == 3 => vals
    Some(_) => raise ValueError("latexs must have length 3")
    None => [name + "_x", name + "_y", name + "_z"]
  }
  let vars = match variables {
    Some(vals) if vals.length() == 3 => vals
    Some(_) => raise ValueError("variables must have length 3")
    None => [name + "_x", name + "_y", name + "_z"]
  }
  let frame = ReferenceFrame::{
    name_: name,
    index_: next_index,
    indices_: idxs,
    latexs_: ltx,
    variables_: vars,
  }
  vector_frame_registry.push(frame)
  let init_dcm : Map[Int, @symphysics.ExplicitMatrix] = Map([])
  init_dcm.set(next_index, @symphysics.explicit_matrix_eye(3))
  let init_cache : Map[Int, @symphysics.ExplicitMatrix] = Map([])
  init_cache.set(next_index, @symphysics.explicit_matrix_eye(3))
  vector_frame_states.push({
    dcm_dict: init_dcm,
    dcm_cache: init_cache,
    ang_vel_dict: {},
    ang_acc_dict: {},
  })
  for i in 0..<3 {
    vector_coordinate_registry.set(vars[i], (next_index, i))
  }
  frame
}

///|
pub fn ReferenceFrame::name(self : ReferenceFrame) -> String {
  self.name_
}

///|
pub fn ReferenceFrame::basis(
  self : ReferenceFrame,
  axis : Int,
) -> Vector raise VectorError {
  if axis < 0 || axis > 2 {
    raise ValueError("basis axis must be 0, 1, or 2")
  }
  vector_from_components(self, basis_components(axis))
}

///|
pub fn ReferenceFrame::x(self : ReferenceFrame) -> Vector {
  vector_from_components(self, basis_components(0))
}

///|
pub fn ReferenceFrame::y(self : ReferenceFrame) -> Vector {
  vector_from_components(self, basis_components(1))
}

///|
pub fn ReferenceFrame::z(self : ReferenceFrame) -> Vector {
  vector_from_components(self, basis_components(2))
}

///|
pub fn ReferenceFrame::xx(self : ReferenceFrame) -> Dyadic {
  dyadic_basis(self, 0, self, 0)
}

///|
pub fn ReferenceFrame::xy(self : ReferenceFrame) -> Dyadic {
  dyadic_basis(self, 0, self, 1)
}

///|
pub fn ReferenceFrame::xz(self : ReferenceFrame) -> Dyadic {
  dyadic_basis(self, 0, self, 2)
}

///|
pub fn ReferenceFrame::yx(self : ReferenceFrame) -> Dyadic {
  dyadic_basis(self, 1, self, 0)
}

///|
pub fn ReferenceFrame::yy(self : ReferenceFrame) -> Dyadic {
  dyadic_basis(self, 1, self, 1)
}

///|
pub fn ReferenceFrame::yz(self : ReferenceFrame) -> Dyadic {
  dyadic_basis(self, 1, self, 2)
}

///|
pub fn ReferenceFrame::zx(self : ReferenceFrame) -> Dyadic {
  dyadic_basis(self, 2, self, 0)
}

///|
pub fn ReferenceFrame::zy(self : ReferenceFrame) -> Dyadic {
  dyadic_basis(self, 2, self, 1)
}

///|
pub fn ReferenceFrame::zz(self : ReferenceFrame) -> Dyadic {
  dyadic_basis(self, 2, self, 2)
}

///|
pub fn ReferenceFrame::u(self : ReferenceFrame) -> Dyadic {
  self.xx() + self.yy() + self.zz()
}

///|
pub fn ReferenceFrame::coord(
  self : ReferenceFrame,
  axis : Int,
) -> CoordinateSym raise VectorError {
  if axis < 0 || axis > 2 {
    raise ValueError("coordinate axis must be 0, 1, or 2")
  }
  coordinate_symbol(self, axis)
}

///|
pub fn ReferenceFrame::coords(self : ReferenceFrame) -> Array[CoordinateSym] {
  [
    coordinate_symbol(self, 0),
    coordinate_symbol(self, 1),
    coordinate_symbol(self, 2),
  ]
}

///|
fn frame_neighbors(frame : ReferenceFrame) -> Array[ReferenceFrame] {
  let out : Array[ReferenceFrame] = []
  for entry in vector_frame_states[frame.index_ - 1].dcm_dict {
    let other_id = entry.0
    if other_id != frame.index_ {
      out.push(frame_registry_get(other_id))
    }
  }
  out
}

///|
fn frame_path_between(
  start_frame : ReferenceFrame,
  other : ReferenceFrame,
) -> Array[ReferenceFrame] raise VectorError {
  if start_frame == other {
    return [start_frame]
  }
  let queue : Array[Array[ReferenceFrame]] = [[start_frame]]
  let seen : Map[Int, Bool] = Map([])
  seen.set(start_frame.index_, true)
  let mut head = 0
  while head < queue.length() {
    let path = queue[head]
    head += 1
    let last = path[path.length() - 1]
    for neighbor in frame_neighbors(last) {
      if (match seen.get(neighbor.index_) {
          Some(true) => true
          _ => false
        }) {
        continue
      }
      let next : Array[ReferenceFrame] = []
      for item in path {
        next.push(item)
      }
      next.push(neighbor)
      if neighbor == other {
        return next
      }
      seen.set(neighbor.index_, true)
      queue.push(next)
    }
  }
  raise ValueError("no connecting orientation path between frames")
}

///|
fn set_direct_dcm(
  target : ReferenceFrame,
  source : ReferenceFrame,
  matrix : @symphysics.ExplicitMatrix,
) -> Unit {
  vector_frame_states[target.index_ - 1].dcm_dict.set(source.index_, matrix)
  vector_frame_states[target.index_ - 1].dcm_cache.set(source.index_, matrix)
}

///|
fn set_direct_ang_vel(
  target : ReferenceFrame,
  source : ReferenceFrame,
  value : Vector,
) -> Unit {
  vector_frame_states[target.index_ - 1].ang_vel_dict.set(source.index_, value)
}

///|
fn parse_rotation_order(order : String) -> Array[Int] raise VectorError {
  let trimmed = order.trim().to_owned()
  if trimmed.length() != 3 {
    raise ValueError("rotation order must have length 3")
  }
  let out : Array[Int] = []
  for i in 0..<3 {
    let ch = trimmed[i]
    let axis = match ch {
      '1' | 'x' | 'X' => 0
      '2' | 'y' | 'Y' => 1
      '3' | 'z' | 'Z' => 2
      _ => raise ValueError("invalid rotation order")
    }
    out.push(axis)
  }
  out
}

///|
fn orientation_from_spec(
  parent : ReferenceFrame,
  child : ReferenceFrame,
  spec : OrientationSpec,
) -> @symphysics.ExplicitMatrix raise VectorError {
  match spec {
    AxisSpec(angle, axis_vector) => {
      let axis_in_parent = axis_vector.express(parent)
      let comps = axis_in_parent.components_in(parent)
      let norm_sq = components_norm_sq(comps)
      if expr_is_zero(norm_sq) {
        raise ValueError("axis vector must be nonzero")
      }
      let unit = if expr_eq(norm_sq, int(1)) {
        comps
      } else {
        let norm = @symelem.sqrt(norm_sq)
        components_scale(norm ^ int(-1), comps)
      }
      let parent_dcm_child = rotation_matrix_about_axis(unit, angle)
      let ang_vel = axis_in_parent
        .normalize()
        .scale(@symcalculus.diff(angle, dynamicsymbols_t))
      set_direct_ang_vel(child, parent, ang_vel)
      set_direct_ang_vel(parent, child, ang_vel.neg())
      parent_dcm_child
    }
    DcmSpec(matrix) => matrix
    BodySpec(angles, order) | SpaceSpec(angles, order) => {
      if angles.length() != 3 {
        raise ValueError("body/space orientation needs 3 angles")
      }
      let axes = parse_rotation_order(order)
      let mut parent_dcm_child = @symphysics.explicit_matrix_eye(3)
      for i in 0..<3 {
        let single = rotation_matrix(axes[i], angles[i])
        parent_dcm_child = parent_dcm_child.mul(single) catch {
          _ => raise ValueError("rotation composition failed")
        }
      }
      parent_dcm_child
    }
    QuaternionSpec(q0, q1, q2, q3) => {
      let two = int_expr(2)
      let q0sq = q0 ^ two
      let q1sq = q1 ^ two
      let q2sq = q2 ^ two
      let q3sq = q3 ^ two
      let parent_dcm_child = matrix_from_rows([
        [
          q0sq + q1sq - q2sq - q3sq,
          two * (q1 * q2 - q0 * q3),
          two * (q1 * q3 + q0 * q2),
        ],
        [
          two * (q1 * q2 + q0 * q3),
          q0sq - q1sq + q2sq - q3sq,
          two * (q2 * q3 - q0 * q1),
        ],
        [
          two * (q1 * q3 - q0 * q2),
          two * (q2 * q3 + q0 * q1),
          q0sq - q1sq - q2sq + q3sq,
        ],
      ])
      let q0d = @symcalculus.diff(q0, dynamicsymbols_t)
      let q1d = @symcalculus.diff(q1, dynamicsymbols_t)
      let q2d = @symcalculus.diff(q2, dynamicsymbols_t)
      let q3d = @symcalculus.diff(q3, dynamicsymbols_t)
      let ang_x = two * (q1d * q0 + q2d * q3 - q3d * q2 - q0d * q1)
      let ang_y = two * (q2d * q0 + q3d * q1 - q1d * q3 - q0d * q2)
      let ang_z = two * (q3d * q0 + q1d * q2 - q2d * q1 - q0d * q3)
      let ang_vel = child.x().scale(ang_x) +
        child.y().scale(ang_y) +
        child.z().scale(ang_z)
      set_direct_ang_vel(child, parent, ang_vel)
      set_direct_ang_vel(parent, child, ang_vel.neg())
      parent_dcm_child
    }
  }
}

///|
pub fn ReferenceFrame::orient(
  self : ReferenceFrame,
  parent : ReferenceFrame,
  spec : OrientationSpec,
) -> Unit raise VectorError {
  if self == parent {
    raise ValueError("frame cannot orient relative to itself")
  }
  let parent_dcm_child = orientation_from_spec(parent, self, spec)
  set_direct_dcm(parent, self, parent_dcm_child)
  set_direct_dcm(self, parent, parent_dcm_child.transpose())
  clear_frame_caches()
}

///|
pub fn ReferenceFrame::orientnew(
  self : ReferenceFrame,
  name : String,
  spec : OrientationSpec,
  indices? : Array[String]? = None,
  latexs? : Array[String]? = None,
  variables? : Array[String]? = None,
) -> ReferenceFrame raise VectorError {
  let child = reference_frame(name, indices~, latexs~, variables~)
  child.orient(self, spec)
  child
}

///|
pub fn ReferenceFrame::orient_axis(
  self : ReferenceFrame,
  parent : ReferenceFrame,
  axis : Vector,
  angle : Expr,
) -> Unit raise VectorError {
  self.orient(parent, AxisSpec(angle, axis))
}

///|
pub fn ReferenceFrame::dcm(
  self : ReferenceFrame,
  other : ReferenceFrame,
) -> @symphysics.ExplicitMatrix raise VectorError {
  if self == other {
    return @symphysics.explicit_matrix_eye(3)
  }
  match vector_frame_states[self.index_ - 1].dcm_cache.get(other.index_) {
    Some(value) => value
    None => {
      let path = frame_path_between(self, other)
      let mut acc = @symphysics.explicit_matrix_eye(3)
      for i in 0..<(path.length() - 1) {
        let lhs = path[i]
        let rhs = path[i + 1]
        match vector_frame_states[lhs.index_ - 1].dcm_dict.get(rhs.index_) {
          Some(step) =>
            acc = acc.mul(step) catch {
              _ => raise ValueError("dcm multiplication failed")
            }
          None => raise ValueError("missing direct dcm relation")
        }
      }
      vector_frame_states[self.index_ - 1].dcm_cache.set(other.index_, acc)
      acc
    }
  }
}

///|
pub fn ReferenceFrame::variable_map(
  self : ReferenceFrame,
  other : ReferenceFrame,
) -> Map[String, Expr] raise VectorError {
  let dcm = other.dcm(self)
  let out : Map[String, Expr] = Map([])
  for i in 0..<3 {
    let col = matrix_column(dcm, i)
    let mapped = col[0] * coordinate_symbol(other, 0) +
      col[1] * coordinate_symbol(other, 1) +
      col[2] * coordinate_symbol(other, 2)
    out.set(coordinate_symbol_name(self, i), simplify_expr(mapped))
  }
  out
}

///|
pub fn ReferenceFrame::set_ang_vel(
  self : ReferenceFrame,
  other : ReferenceFrame,
  value : Vector,
) -> Unit {
  set_direct_ang_vel(self, other, value)
  set_direct_ang_vel(other, self, value.neg())
}

///|
pub fn ReferenceFrame::ang_vel_in(
  self : ReferenceFrame,
  other : ReferenceFrame,
) -> Vector raise VectorError {
  if self == other {
    return vector_zero()
  }
  match vector_frame_states[self.index_ - 1].ang_vel_dict.get(other.index_) {
    Some(value) => value
    None => {
      let path = frame_path_between(self, other)
      let mut acc = vector_zero()
      for i in 0..<(path.length() - 1) {
        let lhs = path[i]
        let rhs = path[i + 1]
        match vector_frame_states[lhs.index_ - 1].ang_vel_dict.get(rhs.index_) {
          Some(value) => acc = acc + value
          None => raise ValueError("missing angular velocity relation")
        }
      }
      vector_frame_states[self.index_ - 1].ang_vel_dict.set(other.index_, acc)
      acc
    }
  }
}

///|
pub fn ReferenceFrame::set_ang_acc(
  self : ReferenceFrame,
  other : ReferenceFrame,
  value : Vector,
) -> Unit {
  vector_frame_states[self.index_ - 1].ang_acc_dict.set(other.index_, value)
  vector_frame_states[other.index_ - 1].ang_acc_dict.set(
    self.index_,
    value.neg(),
  )
}

///|
pub fn ReferenceFrame::ang_acc_in(
  self : ReferenceFrame,
  other : ReferenceFrame,
) -> Vector raise VectorError {
  if self == other {
    return vector_zero()
  }
  match vector_frame_states[self.index_ - 1].ang_acc_dict.get(other.index_) {
    Some(value) => value
    None => self.ang_vel_in(other).dt(other)
  }
}

///|
pub fn _check_frame(frame : ReferenceFrame) -> ReferenceFrame {
  frame
}
