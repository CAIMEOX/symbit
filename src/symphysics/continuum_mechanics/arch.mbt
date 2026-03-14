///|
/// Parabolic three-hinged arch helper aligned with the core symbolic surface of
/// `sympy.physics.continuum_mechanics.arch`.

///|
pub suberror ArchError {
  ValueError(String)
  TypeError(String)
  SolveError(String)
} derive(Show, Eq)

///|
pub struct Arch {
  mut left_support_ : Array[@symcore.Expr]
  mut right_support_ : Array[@symcore.Expr]
  mut crown_x_ : @symcore.Expr
  mut crown_y_ : @symcore.Expr
  mut shape_a_ : @symcore.Expr
  supports_ : Map[String, String]
  point_loads_ : Map[String, Array[@symcore.Expr]]
  distributed_loads_ : Map[String, Array[@symcore.Expr]]
  mut member_ : Array[@symcore.Expr]?
  reaction_force_ : Map[String, @symcore.Expr]
}

///|
fn arch_var() -> @symcore.Expr {
  @symcore.symbol("x")
}

///|
fn arch_pi() -> @symcore.Expr {
  @symcore.symbol("pi")
}

///|
fn arch_normalized_degree(angle : @symcore.Expr) -> Int? {
  match angle {
    @symcore.Expr::Number(n) if n.is_integral() => {
      let mut deg = n.numerator().to_int() % 360
      if deg < 0 {
        deg += 360
      }
      Some(deg)
    }
    _ => None
  }
}

///|
fn arch_sin_deg(angle : @symcore.Expr) -> @symcore.Expr {
  match arch_normalized_degree(angle) {
    Some(0) | Some(180) => @symcore.int(0)
    Some(30) | Some(150) => cm_rat_expr(1, 2)
    Some(210) | Some(330) => cm_rat_expr(-1, 2)
    Some(90) => @symcore.int(1)
    Some(270) => @symcore.int(-1)
    Some(45) | Some(135) => cm_rat_expr(1, 2) * @symelem.sqrt(@symcore.int(2))
    Some(225) | Some(315) => cm_rat_expr(-1, 2) * @symelem.sqrt(@symcore.int(2))
    Some(60) | Some(120) => cm_rat_expr(1, 2) * @symelem.sqrt(@symcore.int(3))
    Some(240) | Some(300) => cm_rat_expr(-1, 2) * @symelem.sqrt(@symcore.int(3))
    _ => @symelem.sin(arch_pi() * angle * cm_rat_expr(1, 180))
  }
}

///|
fn arch_cos_deg(angle : @symcore.Expr) -> @symcore.Expr {
  match arch_normalized_degree(angle) {
    Some(90) | Some(270) => @symcore.int(0)
    Some(0) => @symcore.int(1)
    Some(180) => @symcore.int(-1)
    Some(60) | Some(300) => cm_rat_expr(1, 2)
    Some(120) | Some(240) => cm_rat_expr(-1, 2)
    Some(45) | Some(315) => cm_rat_expr(1, 2) * @symelem.sqrt(@symcore.int(2))
    Some(135) | Some(225) => cm_rat_expr(-1, 2) * @symelem.sqrt(@symcore.int(2))
    Some(30) | Some(330) => cm_rat_expr(1, 2) * @symelem.sqrt(@symcore.int(3))
    Some(150) | Some(210) => cm_rat_expr(-1, 2) * @symelem.sqrt(@symcore.int(3))
    _ => @symelem.cos(arch_pi() * angle * cm_rat_expr(1, 180))
  }
}

///|
fn arch_recompute_shape(
  left_support : Array[@symcore.Expr],
  right_support : Array[@symcore.Expr],
  crown_x : @symcore.Expr,
  crown_y? : @symcore.Expr? = None,
) -> (@symcore.Expr, @symcore.Expr) raise ArchError {
  let x1 = left_support[0]
  let y1 = left_support[1]
  let x2 = right_support[0]
  let y2 = right_support[1]
  match crown_y {
    Some(cy) => {
      let denom = cm_simplify((x1 - crown_x) ^ @symcore.int(2))
      guard !cm_expr_is_zero(denom) else {
        raise ArchError::ValueError(
          "provided coordinates do not define a parabolic arch",
        )
      }
      let a = cm_simplify((y1 - cy) * (denom ^ @symcore.int(-1)))
      let rhs = cm_simplify(a * ((x2 - crown_x) ^ @symcore.int(2)) + cy)
      guard cm_numeric_expr_eq(rhs, y2) else {
        raise ArchError::ValueError(
          "provided coordinates of crown and supports are not consistent with parabolic arch",
        )
      }
      (a, cy)
    }
    None => {
      let denom = cm_simplify(
        ((x1 - crown_x) ^ @symcore.int(2)) - ((x2 - crown_x) ^ @symcore.int(2)),
      )
      guard !cm_expr_is_zero(denom) else {
        raise ArchError::ValueError(
          "parabolic arch cannot be constructed with the provided coordinates, try providing crown_y",
        )
      }
      let a = cm_simplify((y1 - y2) * (denom ^ @symcore.int(-1)))
      guard !cm_expr_is_zero(a) else {
        raise ArchError::ValueError(
          "parabolic arch cannot be constructed with the provided coordinates, try providing crown_y",
        )
      }
      let cy = cm_simplify(y1 - a * ((x1 - crown_x) ^ @symcore.int(2)))
      (a, cy)
    }
  }
}

///|
pub fn arch(
  left_support : (@symcore.Expr, @symcore.Expr),
  right_support : (@symcore.Expr, @symcore.Expr),
  crown_x : @symcore.Expr,
  crown_y? : @symcore.Expr? = None,
) -> Arch raise ArchError {
  let left = [left_support.0, left_support.1]
  let right = [right_support.0, right_support.1]
  let (a, cy) = try! arch_recompute_shape(left, right, crown_x, crown_y~)
  let reactions : Map[String, @symcore.Expr] = {
    "R_A_x": @symcore.int(0),
    "R_A_y": @symcore.int(0),
    "R_B_x": @symcore.int(0),
    "R_B_y": @symcore.int(0),
  }
  Arch::{
    left_support_: left,
    right_support_: right,
    crown_x_: crown_x,
    crown_y_: cy,
    shape_a_: a,
    supports_: { "left": "hinge", "right": "hinge" },
    point_loads_: {},
    distributed_loads_: {},
    member_: None,
    reaction_force_: reactions,
  }
}

///|
fn arch_shape_value(a : Arch, x : @symcore.Expr) -> @symcore.Expr {
  cm_simplify(a.shape_a_ * ((x - a.crown_x_) ^ @symcore.int(2)) + a.crown_y_)
}

///|
fn arch_shape_slope(a : Arch, x : @symcore.Expr) -> @symcore.Expr {
  cm_simplify(@symcore.int(2) * a.shape_a_ * (x - a.crown_x_))
}

///|
fn arch_interval_contains(
  lower : @symcore.Expr,
  upper : @symcore.Expr,
  point : @symcore.Expr,
) -> Bool {
  let lhs_ok = cm_sign_of_difference(lower, point)
    .map(v => v <= 0)
    .unwrap_or(false)
  let rhs_ok = cm_sign_of_difference(point, upper)
    .map(v => v <= 0)
    .unwrap_or(false)
  lhs_ok && rhs_ok
}

///|
fn arch_load_moment(
  point_x : @symcore.Expr,
  point_y : @symcore.Expr,
  force_x : @symcore.Expr,
  force_y : @symcore.Expr,
  ref_x : @symcore.Expr,
  ref_y : @symcore.Expr,
) -> @symcore.Expr {
  cm_simplify((point_x - ref_x) * force_y - (point_y - ref_y) * force_x)
}

///|
fn arch_partial_distributed_segment(
  start : @symcore.Expr,
  end : @symcore.Expr,
  upto : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr)? {
  if !arch_interval_contains(start, end, upto) &&
    cm_sign_of_difference(upto, end).map(v => v > 0).unwrap_or(false) {
    Some((start, end))
  } else if arch_interval_contains(start, end, upto) {
    Some((start, upto))
  } else {
    None
  }
}

///|
fn arch_total_force_and_moment(
  arch : Arch,
  ref_x : @symcore.Expr,
  ref_y : @symcore.Expr,
  lower? : @symcore.Expr? = None,
  upper? : @symcore.Expr? = None,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr) {
  let mut fx = @symcore.int(0)
  let mut fy = @symcore.int(0)
  let mut moment = @symcore.int(0)
  for _, item in arch.point_loads_ {
    let x = item[0]
    let y = item[1]
    let load_fx = item[2]
    let load_fy = item[3]
    let keep = match (lower, upper) {
      (Some(lo), Some(hi)) => arch_interval_contains(lo, hi, x)
      _ => true
    }
    if keep {
      fx = cm_simplify(fx + load_fx)
      fy = cm_simplify(fy + load_fy)
      moment = cm_simplify(
        moment + arch_load_moment(x, y, load_fx, load_fy, ref_x, ref_y),
      )
    }
  }
  for _, item in arch.distributed_loads_ {
    let start = item[0]
    let end = item[1]
    let magnitude = item[2]
    let segment = match (lower, upper) {
      (Some(lo), Some(hi)) =>
        if arch_interval_contains(lo, hi, start) &&
          arch_interval_contains(lo, hi, end) {
          Some((start, end))
        } else {
          None
        }
      _ => Some((start, end))
    }
    match segment {
      Some((seg_start, seg_end)) => {
        let width = cm_simplify(seg_end - seg_start)
        let force_y = cm_simplify(magnitude * width)
        let centroid_x = cm_simplify((seg_start + seg_end) * cm_rat_expr(1, 2))
        fx = cm_simplify(fx)
        fy = cm_simplify(fy + force_y)
        moment = cm_simplify(moment + (centroid_x - ref_x) * force_y)
      }
      None => ()
    }
  }
  (fx, fy, moment)
}

///|
fn arch_left_force_and_moment_at(
  arch : Arch,
  pos : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr) {
  let y_cut = arch_shape_value(arch, pos)
  let rax = arch.reaction_force_["R_A_x"]
  let ray = arch.reaction_force_["R_A_y"]
  let mut fx = rax
  let mut fy = ray
  let mut moment = arch_load_moment(
    arch.left_support_[0],
    arch.left_support_[1],
    rax,
    ray,
    pos,
    y_cut,
  )
  for _, item in arch.point_loads_ {
    let x = item[0]
    if cm_sign_of_difference(x, pos).map(v => v <= 0).unwrap_or(false) {
      let load_fx = item[2]
      let load_fy = item[3]
      fx = cm_simplify(fx + load_fx)
      fy = cm_simplify(fy + load_fy)
      moment = cm_simplify(
        moment + arch_load_moment(x, item[1], load_fx, load_fy, pos, y_cut),
      )
    }
  }
  for _, item in arch.distributed_loads_ {
    match arch_partial_distributed_segment(item[0], item[1], pos) {
      Some((seg_start, seg_end)) => {
        let width = cm_simplify(seg_end - seg_start)
        let force_y = cm_simplify(item[2] * width)
        let centroid_x = cm_simplify((seg_start + seg_end) * cm_rat_expr(1, 2))
        fy = cm_simplify(fy + force_y)
        moment = cm_simplify(moment + (centroid_x - pos) * force_y)
      }
      None => ()
    }
  }
  (fx, fy, moment)
}

///|
pub fn Arch::get_shape_eqn(self : Arch) -> @symcore.Expr {
  arch_shape_value(self, arch_var())
}

///|
pub fn Arch::get_loads(
  self : Arch,
) -> Map[String, Map[String, Array[@symcore.Expr]]] {
  { "distributed": self.distributed_loads_, "concentrated": self.point_loads_ }
}

///|
pub fn Arch::supports(self : Arch) -> Map[String, String] {
  self.supports_
}

///|
pub fn Arch::left_support(self : Arch) -> Array[@symcore.Expr] {
  self.left_support_
}

///|
pub fn Arch::right_support(self : Arch) -> Array[@symcore.Expr] {
  self.right_support_
}

///|
pub fn Arch::reaction_force(self : Arch) -> Map[String, @symcore.Expr] {
  self.reaction_force_
}

///|
pub fn Arch::apply_load(
  self : Arch,
  order : Int,
  label : String,
  start : @symcore.Expr,
  mag : @symcore.Expr,
  end? : @symcore.Expr? = None,
  angle? : @symcore.Expr? = None,
) -> Unit raise ArchError {
  guard self.point_loads_.get(label) is None &&
    self.distributed_loads_.get(label) is None else {
    raise ArchError::ValueError("load with the given label already exists")
  }
  guard label != "A" && label != "B" else {
    raise ArchError::ValueError(
      "cannot use the given label, reserved for supports",
    )
  }
  if order == 0 {
    let stop = end.unwrap_or_else(() => {
      raise ArchError::ValueError("provide end greater than start")
    })
    guard cm_sign_of_difference(stop, start).map(v => v > 0).unwrap_or(false) else {
      raise ArchError::ValueError("provide end greater than start")
    }
    self.distributed_loads_[label] = [start, stop, mag]
    return
  }
  guard order == -1 else {
    raise ArchError::ValueError("supported arch load orders are -1 and 0")
  }
  let theta = angle.unwrap_or_else(() => {
    raise ArchError::TypeError("please provide direction of force")
  })
  let y = arch_shape_value(self, start)
  self.point_loads_[label] = [
    start,
    y,
    cm_simplify(mag * arch_cos_deg(theta)),
    cm_simplify(mag * arch_sin_deg(theta)),
    mag,
    theta,
  ]
}

///|
pub fn Arch::remove_load(self : Arch, label : String) -> Unit raise ArchError {
  if self.distributed_loads_.get(label) is Some(_) {
    self.distributed_loads_.remove(label)
    return
  }
  if self.point_loads_.get(label) is Some(_) {
    self.point_loads_.remove(label)
    return
  }
  raise ArchError::ValueError("label not found")
}

///|
pub fn Arch::change_support_position(
  self : Arch,
  left_support? : (@symcore.Expr, @symcore.Expr)? = None,
  right_support? : (@symcore.Expr, @symcore.Expr)? = None,
) -> Unit raise ArchError {
  match left_support {
    Some(v) => self.left_support_ = [v.0, v.1]
    None => ()
  }
  match right_support {
    Some(v) => self.right_support_ = [v.0, v.1]
    None => ()
  }
  let (a, cy) = try! arch_recompute_shape(
    self.left_support_,
    self.right_support_,
    self.crown_x_,
    crown_y=Some(self.crown_y_),
  )
  self.shape_a_ = a
  self.crown_y_ = cy
}

///|
pub fn Arch::change_crown_position(
  self : Arch,
  crown_x? : @symcore.Expr? = None,
  crown_y? : @symcore.Expr? = None,
) -> Unit raise ArchError {
  match crown_x {
    Some(v) => self.crown_x_ = v
    None => ()
  }
  let target_y = match crown_y {
    Some(v) => Some(v)
    None => Some(self.crown_y_)
  }
  let (a, cy) = try! arch_recompute_shape(
    self.left_support_,
    self.right_support_,
    self.crown_x_,
    crown_y=target_y,
  )
  self.shape_a_ = a
  self.crown_y_ = cy
}

///|
pub fn Arch::change_support_type(
  self : Arch,
  left_support? : String? = None,
  right_support? : String? = None,
) -> Unit raise ArchError {
  for kind in [left_support, right_support] {
    match kind {
      Some(value) =>
        if value != "roller" && value != "hinge" {
          raise ArchError::ValueError("supports must only be roller or hinge")
        }
      None => ()
    }
  }
  match left_support {
    Some(v) => self.supports_["left"] = v
    None => ()
  }
  match right_support {
    Some(v) => self.supports_["right"] = v
    None => ()
  }
}

///|
pub fn Arch::add_member(self : Arch, y : @symcore.Expr) -> Unit raise ArchError {
  let min_y = self.left_support_[1]
  let right_y = self.right_support_[1]
  let lower = if cm_sign_of_difference(min_y, right_y)
    .map(v => v <= 0)
    .unwrap_or(true) {
    min_y
  } else {
    right_y
  }
  guard cm_sign_of_difference(y, lower).map(v => v >= 0).unwrap_or(false) &&
    cm_sign_of_difference(y, self.crown_y_).map(v => v <= 0).unwrap_or(false) else {
    raise ArchError::ValueError(
      "member must lie between support level and crown",
    )
  }
  let x_diff = @symelem.sqrt(
    cm_simplify((y - self.crown_y_) * (self.shape_a_ ^ @symcore.int(-1))),
  )
  self.member_ = Some([
    cm_simplify(self.crown_x_ - x_diff),
    cm_simplify(self.crown_x_ + x_diff),
    y,
  ])
}

///|
pub fn Arch::solve(self : Arch) -> Unit raise ArchError {
  let (net_x, net_y, moment_a_loads) = arch_total_force_and_moment(
    self,
    self.left_support_[0],
    self.left_support_[1],
  )
  let (_, _, moment_hinge_left_loads) = arch_total_force_and_moment(
    self,
    self.crown_x_,
    self.crown_y_,
    lower=Some(self.left_support_[0]),
    upper=Some(self.crown_x_),
  )
  let (_, _, moment_hinge_right_loads) = arch_total_force_and_moment(
    self,
    self.crown_x_,
    self.crown_y_,
    lower=Some(self.crown_x_),
    upper=Some(self.right_support_[0]),
  )
  let rax = cm_symbol("R_A_x")
  let ray = cm_symbol("R_A_y")
  let rbx = cm_symbol("R_B_x")
  let rby = cm_symbol("R_B_y")
  let t = cm_symbol("T")
  let eqs : Array[@symcore.Expr] = []
  let unknowns : Array[@symcore.Expr] = []
  if self.supports_["left"] == "hinge" && self.supports_["right"] == "hinge" {
    eqs.push(cm_simplify(rax + rbx + net_x))
    eqs.push(cm_simplify(ray + rby + net_y))
    eqs.push(
      cm_simplify(
        (self.right_support_[0] - self.left_support_[0]) * rby -
        (self.right_support_[1] - self.left_support_[1]) * rbx +
        moment_a_loads,
      ),
    )
    eqs.push(
      cm_simplify(
        (self.right_support_[0] - self.crown_x_) * rby -
        (self.right_support_[1] - self.crown_y_) * rbx +
        moment_hinge_right_loads,
      ),
    )
    unknowns.push(rax)
    unknowns.push(ray)
    unknowns.push(rbx)
    unknowns.push(rby)
  } else if self.supports_["left"] == "hinge" &&
    self.supports_["right"] == "roller" {
    let rod = self.member_.unwrap_or_else(() => {
      raise ArchError::SolveError(
        "member must be added if any support is roller",
      )
    })
    guard cm_sign_of_difference(rod[2], self.left_support_[1])
      .map(v => v >= 0)
      .unwrap_or(false) &&
      cm_sign_of_difference(rod[2], self.right_support_[1])
      .map(v => v >= 0)
      .unwrap_or(false) else {
      raise ArchError::SolveError("member must lie above the support level")
    }
    eqs.push(rbx)
    eqs.push(cm_simplify(rax + net_x))
    eqs.push(cm_simplify(ray + rby + net_y))
    eqs.push(
      cm_simplify(
        moment_hinge_right_loads +
        rby * (self.right_support_[0] - self.crown_x_) +
        t * (rod[2] - self.crown_y_),
      ),
    )
    eqs.push(
      cm_simplify(
        moment_a_loads + rby * (self.right_support_[0] - self.left_support_[0]),
      ),
    )
    unknowns.push(rax)
    unknowns.push(ray)
    unknowns.push(rbx)
    unknowns.push(rby)
    unknowns.push(t)
  } else if self.supports_["left"] == "roller" &&
    self.supports_["right"] == "hinge" {
    let rod = self.member_.unwrap_or_else(() => {
      raise ArchError::SolveError(
        "member must be added if any support is roller",
      )
    })
    guard cm_sign_of_difference(rod[2], self.left_support_[1])
      .map(v => v >= 0)
      .unwrap_or(false) &&
      cm_sign_of_difference(rod[2], self.right_support_[1])
      .map(v => v >= 0)
      .unwrap_or(false) else {
      raise ArchError::SolveError("member must lie above the support level")
    }
    eqs.push(rax)
    eqs.push(cm_simplify(rbx + net_x))
    eqs.push(cm_simplify(ray + rby + net_y))
    eqs.push(
      cm_simplify(
        moment_hinge_left_loads +
        ray * (self.left_support_[0] - self.crown_x_) -
        t * (rod[2] - self.crown_y_),
      ),
    )
    eqs.push(
      cm_simplify(
        moment_a_loads -
        rbx * (self.right_support_[1] - self.left_support_[1]) +
        rby * (self.right_support_[0] - self.left_support_[0]),
      ),
    )
    unknowns.push(rax)
    unknowns.push(ray)
    unknowns.push(rbx)
    unknowns.push(rby)
    unknowns.push(t)
  } else {
    raise ArchError::SolveError(
      "arch solve currently requires hinge/hinge or one roller support with a member",
    )
  }
  let solution = try cm_linear_solve(eqs, unknowns) catch {
    _ => raise ArchError::SolveError("unable to solve arch reactions")
  } noraise {
    result => result
  }
  match solution {
    Some(values) => {
      self.reaction_force_["R_A_x"] = cm_simplify(
        values.get("R_A_x").unwrap_or(@symcore.int(0)),
      )
      self.reaction_force_["R_A_y"] = cm_simplify(
        values.get("R_A_y").unwrap_or(@symcore.int(0)),
      )
      self.reaction_force_["R_B_x"] = cm_simplify(
        values.get("R_B_x").unwrap_or(@symcore.int(0)),
      )
      self.reaction_force_["R_B_y"] = cm_simplify(
        values.get("R_B_y").unwrap_or(@symcore.int(0)),
      )
    }
    None => raise ArchError::SolveError("unable to solve arch reactions")
  }
}

///|
pub fn Arch::bending_moment_at(
  self : Arch,
  pos? : @symcore.Expr? = None,
) -> @symcore.Expr raise ArchError {
  let x = pos.unwrap_or_else(() => {
    raise ArchError::ValueError("position is required")
  })
  let (_, _, moment) = arch_left_force_and_moment_at(self, x)
  cm_simplify(@symcore.int(-1) * moment)
}

///|
pub fn Arch::axial_force_at(
  self : Arch,
  pos? : @symcore.Expr? = None,
) -> @symcore.Expr raise ArchError {
  let x = pos.unwrap_or_else(() => {
    raise ArchError::ValueError("position is required")
  })
  let (fx, fy, _) = arch_left_force_and_moment_at(self, x)
  let slope = arch_shape_slope(self, x)
  let denom = @symelem.sqrt(@symcore.int(1) + (slope ^ @symcore.int(2)))
  cm_simplify((fx + fy * slope) * (denom ^ @symcore.int(-1)))
}

///|
pub fn Arch::shear_force_at(
  self : Arch,
  pos? : @symcore.Expr? = None,
) -> @symcore.Expr raise ArchError {
  let x = pos.unwrap_or_else(() => {
    raise ArchError::ValueError("position is required")
  })
  let (fx, fy, _) = arch_left_force_and_moment_at(self, x)
  let slope = arch_shape_slope(self, x)
  let denom = @symelem.sqrt(@symcore.int(1) + (slope ^ @symcore.int(2)))
  cm_simplify((@symcore.int(-1) * fx * slope + fy) * (denom ^ @symcore.int(-1)))
}
