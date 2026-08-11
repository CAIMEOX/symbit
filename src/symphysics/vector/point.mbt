///|
/// Point kinematics aligned with `sympy.physics.vector.point`.

///|
pub impl Eq for Point with fn equal(self, other : Point) -> Bool {
  self.index_ == other.index_
}

///|
pub impl Eq for Point with fn not_equal(self, other : Point) -> Bool {
  self.index_ != other.index_
}

///|
pub fn point(name : String) -> Point raise VectorError {
  if name == "" {
    raise ValueError("point name must be non-empty")
  }
  let next_index = vector_point_registry.length() + 1
  let p = Point::{ name_: name, index_: next_index }
  vector_point_registry.push(p)
  vector_point_states.push({ pos_dict: {}, vel_dict: {}, acc_dict: {} })
  p
}

///|
pub fn Point::name(self : Point) -> String {
  self.name_
}

///|
pub fn Point::set_pos(self : Point, other : Point, value : Vector) -> Unit {
  vector_point_states[self.index_ - 1].pos_dict.set(other.index_, value)
  vector_point_states[other.index_ - 1].pos_dict.set(self.index_, value.neg())
}

///|
pub fn Point::locatenew(
  self : Point,
  name : String,
  value : Vector,
) -> Point raise VectorError {
  let child = point(name)
  child.set_pos(self, value)
  child
}

///|
fn point_neighbors(point_ : Point) -> Array[Point] {
  let out : Array[Point] = []
  for entry in vector_point_states[point_.index_ - 1].pos_dict {
    out.push(point_registry_get(entry.0))
  }
  out
}

///|
fn point_path_between(
  start_ : Point,
  other : Point,
) -> Array[Point] raise VectorError {
  if start_ == other {
    return [start_]
  }
  let queue : Array[Array[Point]] = [[start_]]
  let seen : Map[Int, Bool] = Map([])
  seen.set(start_.index_, true)
  let mut head = 0
  while head < queue.length() {
    let path = queue[head]
    head += 1
    let last = path[path.length() - 1]
    for neighbor in point_neighbors(last) {
      if (match seen.get(neighbor.index_) {
          Some(true) => true
          _ => false
        }) {
        continue
      }
      let next : Array[Point] = []
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
  raise ValueError("no connecting path between points")
}

///|
pub fn Point::pos_from(self : Point, other : Point) -> Vector raise VectorError {
  if self == other {
    return vector_zero()
  }
  let path = point_path_between(other, self)
  let mut out = vector_zero()
  for i in 0..<(path.length() - 1) {
    let cur = path[i]
    let nxt = path[i + 1]
    match vector_point_states[nxt.index_ - 1].pos_dict.get(cur.index_) {
      Some(value) => out = out + value
      None => raise ValueError("missing point position relation")
    }
  }
  out
}

///|
pub fn Point::set_vel(
  self : Point,
  frame : ReferenceFrame,
  value : Vector,
) -> Unit {
  vector_point_states[self.index_ - 1].vel_dict.set(frame.index_, value)
}

///|
pub fn Point::set_acc(
  self : Point,
  frame : ReferenceFrame,
  value : Vector,
) -> Unit {
  vector_point_states[self.index_ - 1].acc_dict.set(frame.index_, value)
}

///|
pub fn Point::vel(
  self : Point,
  frame : ReferenceFrame,
) -> Vector raise VectorError {
  match vector_point_states[self.index_ - 1].vel_dict.get(frame.index_) {
    Some(value) => value
    None => {
      let queue : Array[Point] = [self]
      let parent : Map[Int, Int] = Map([])
      parent.set(self.index_, 0)
      let mut head = 0
      let mut base : Point? = None
      while head < queue.length() {
        let current = queue[head]
        head += 1
        if current != self &&
          vector_point_states[current.index_ - 1].vel_dict.contains(
            frame.index_,
          ) {
          base = Some(current)
          break
        }
        for neighbor in point_neighbors(current) {
          if !parent.contains(neighbor.index_) {
            parent.set(neighbor.index_, current.index_)
            queue.push(neighbor)
          }
        }
      }
      match base {
        Some(anchor) => {
          let base_vel = vector_point_states[anchor.index_ - 1].vel_dict[frame.index_]
          let rel = self.pos_from(anchor)
          let value = base_vel + rel.dt(frame)
          vector_point_states[self.index_ - 1].vel_dict.set(frame.index_, value)
          value
        }
        None =>
          raise ValueError("velocity is not defined in the requested frame")
      }
    }
  }
}

///|
pub fn Point::acc(
  self : Point,
  frame : ReferenceFrame,
) -> Vector raise VectorError {
  match vector_point_states[self.index_ - 1].acc_dict.get(frame.index_) {
    Some(value) => value
    None => {
      let value = self.vel(frame).dt(frame)
      vector_point_states[self.index_ - 1].acc_dict.set(frame.index_, value)
      value
    }
  }
}

///|
pub fn Point::v1pt_theory(
  self : Point,
  other : Point,
  outframe : ReferenceFrame,
  interframe : ReferenceFrame,
) -> Vector raise VectorError {
  let dist = self.pos_from(other).express(interframe)
  let vel_rel = self.vel(interframe)
  let omega = interframe.ang_vel_in(outframe).express(interframe)
  let value = vel_rel + other.vel(outframe) + omega.cross(dist)
  self.set_vel(outframe, value)
  value
}

///|
pub fn Point::a1pt_theory(
  self : Point,
  other : Point,
  outframe : ReferenceFrame,
  interframe : ReferenceFrame,
) -> Vector raise VectorError {
  let dist = self.pos_from(other).express(interframe)
  let vel_rel = self.vel(interframe)
  let omega = interframe.ang_vel_in(outframe).express(interframe)
  let alpha = interframe.ang_acc_in(outframe).express(interframe)
  let value = self.acc(interframe) +
    omega.cross(vel_rel).scale(int_expr(2)) +
    other.acc(outframe) +
    alpha.cross(dist) +
    omega.cross(omega.cross(dist))
  self.set_acc(outframe, value)
  value
}

///|
pub fn Point::v2pt_theory(
  self : Point,
  other : Point,
  outframe : ReferenceFrame,
  fixedframe : ReferenceFrame,
) -> Vector raise VectorError {
  let dist = self.pos_from(other).express(fixedframe)
  let omega = fixedframe.ang_vel_in(outframe).express(fixedframe)
  let value = other.vel(outframe) + omega.cross(dist)
  self.set_vel(outframe, value)
  value
}

///|
pub fn Point::a2pt_theory(
  self : Point,
  other : Point,
  outframe : ReferenceFrame,
  fixedframe : ReferenceFrame,
) -> Vector raise VectorError {
  let dist = self.pos_from(other).express(fixedframe)
  let omega = fixedframe.ang_vel_in(outframe).express(fixedframe)
  let alpha = fixedframe.ang_acc_in(outframe).express(fixedframe)
  let value = other.acc(outframe) +
    alpha.cross(dist) +
    omega.cross(omega.cross(dist))
  self.set_acc(outframe, value)
  value
}

///|
pub fn Point::partial_velocity(
  self : Point,
  frame : ReferenceFrame,
  speed : Expr,
) -> Vector raise VectorError {
  self.vel(frame).diff(speed, frame, var_in_dcm=false)
}

///|
pub fn Point::partial_velocities(
  self : Point,
  frame : ReferenceFrame,
  speeds : Array[Expr],
) -> Array[Vector] raise VectorError {
  let out : Array[Vector] = []
  for speed in speeds {
    out.push(self.partial_velocity(frame, speed))
  }
  out
}
