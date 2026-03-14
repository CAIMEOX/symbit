///|
/// Cable equilibrium helper covering the point-load and uniformly distributed
/// load workflows of `sympy.physics.continuum_mechanics.cable`.

///|
pub type CableSupportSpec = (String, @symcore.Expr, @symcore.Expr)

///|
pub type CablePointLoadSpec = (
  String,
  @symcore.Expr,
  @symcore.Expr,
  @symcore.Expr,
  @symcore.Expr,
)

///|
pub suberror CableError {
  ValueError(String)
  SolveError(String)
} derive(Show, Eq)

///|
pub struct Cable {
  mut supports_ : Map[String, Array[@symcore.Expr]]
  mut support_labels_ : Array[String]
  mut left_support_ : Array[@symcore.Expr]
  mut right_support_ : Array[@symcore.Expr]
  point_loads_ : Map[String, Array[@symcore.Expr]]
  distributed_loads_ : Map[String, @symcore.Expr]
  loads_position_ : Map[String, Array[@symcore.Expr]]
  mut length_ : @symcore.Expr
  mut reaction_loads_ : Map[String, @symcore.Expr]
  mut tension_ : Map[String, @symcore.Expr]
  mut lowest_x_ : @symcore.Expr
  mut lowest_y_ : @symcore.Expr
}

///|
pub fn cable(
  left : CableSupportSpec,
  right : CableSupportSpec,
) -> Cable raise CableError {
  guard left.0 != right.0 else {
    raise CableError::ValueError("supports cannot have the same label")
  }
  guard !cm_expr_eq(left.1, right.1) || !cm_expr_eq(left.2, right.2) else {
    raise CableError::ValueError("supports cannot be at the same location")
  }
  let ordered = if cm_sign_of_difference(left.1, right.1).unwrap_or(-1) <= 0 {
    (left, right)
  } else {
    (right, left)
  }
  let supports : Map[String, Array[@symcore.Expr]] = {}
  supports[ordered.0.0] = [ordered.0.1, ordered.0.2]
  supports[ordered.1.0] = [ordered.1.1, ordered.1.2]
  let reaction_loads : Map[String, @symcore.Expr] = {}
  for label in [ordered.0.0, ordered.1.0] {
    reaction_loads["R_" + label + "_x"] = @symcore.int(0)
    reaction_loads["R_" + label + "_y"] = @symcore.int(0)
  }
  Cable::{
    supports_: supports,
    support_labels_: [ordered.0.0, ordered.1.0],
    left_support_: [ordered.0.1, ordered.0.2],
    right_support_: [ordered.1.1, ordered.1.2],
    point_loads_: {},
    distributed_loads_: {},
    loads_position_: {},
    length_: @symcore.int(0),
    reaction_loads_: reaction_loads,
    tension_: {},
    lowest_x_: @symcore.int(0),
    lowest_y_: @symcore.int(0),
  }
}

///|
fn cable_segment_length(
  x1 : @symcore.Expr,
  y1 : @symcore.Expr,
  x2 : @symcore.Expr,
  y2 : @symcore.Expr,
) -> @symcore.Expr {
  @symelem.sqrt(((x2 - x1) ^ @symcore.int(2)) + ((y2 - y1) ^ @symcore.int(2)))
}

///|
fn cable_pi() -> @symcore.Expr {
  @symcore.symbol("pi")
}

///|
fn cable_normalized_degree(angle : @symcore.Expr) -> Int? {
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
fn cable_sin_deg(angle : @symcore.Expr) -> @symcore.Expr {
  match cable_normalized_degree(angle) {
    Some(0) | Some(180) => @symcore.int(0)
    Some(30) | Some(150) => cm_rat_expr(1, 2)
    Some(210) | Some(330) => cm_rat_expr(-1, 2)
    Some(90) => @symcore.int(1)
    Some(270) => @symcore.int(-1)
    Some(45) | Some(135) => cm_rat_expr(1, 2) * @symelem.sqrt(@symcore.int(2))
    Some(225) | Some(315) => cm_rat_expr(-1, 2) * @symelem.sqrt(@symcore.int(2))
    Some(60) | Some(120) => cm_rat_expr(1, 2) * @symelem.sqrt(@symcore.int(3))
    Some(240) | Some(300) => cm_rat_expr(-1, 2) * @symelem.sqrt(@symcore.int(3))
    _ => @symelem.sin(cable_pi() * angle * cm_rat_expr(1, 180))
  }
}

///|
fn cable_cos_deg(angle : @symcore.Expr) -> @symcore.Expr {
  match cable_normalized_degree(angle) {
    Some(90) | Some(270) => @symcore.int(0)
    Some(0) => @symcore.int(1)
    Some(180) => @symcore.int(-1)
    Some(60) | Some(300) => cm_rat_expr(1, 2)
    Some(120) | Some(240) => cm_rat_expr(-1, 2)
    Some(45) | Some(315) => cm_rat_expr(1, 2) * @symelem.sqrt(@symcore.int(2))
    Some(135) | Some(225) => cm_rat_expr(-1, 2) * @symelem.sqrt(@symcore.int(2))
    Some(30) | Some(330) => cm_rat_expr(1, 2) * @symelem.sqrt(@symcore.int(3))
    Some(150) | Some(210) => cm_rat_expr(-1, 2) * @symelem.sqrt(@symcore.int(3))
    _ => @symelem.cos(cable_pi() * angle * cm_rat_expr(1, 180))
  }
}

///|
pub fn Cable::supports(self : Cable) -> Map[String, Array[@symcore.Expr]] {
  self.supports_
}

///|
pub fn Cable::left_support(self : Cable) -> Array[@symcore.Expr] {
  self.left_support_
}

///|
pub fn Cable::right_support(self : Cable) -> Array[@symcore.Expr] {
  self.right_support_
}

///|
pub fn Cable::loads(
  self : Cable,
) -> Map[String, Map[String, Array[@symcore.Expr]]] {
  let distributed : Map[String, Array[@symcore.Expr]] = {}
  for label, mag in self.distributed_loads_ {
    distributed[label] = [mag]
  }
  { "distributed": distributed, "point_load": self.point_loads_ }
}

///|
pub fn Cable::loads_position(self : Cable) -> Map[String, Array[@symcore.Expr]] {
  self.loads_position_
}

///|
pub fn Cable::length(self : Cable) -> @symcore.Expr {
  self.length_
}

///|
pub fn Cable::reaction_loads(self : Cable) -> Map[String, @symcore.Expr] {
  self.reaction_loads_
}

///|
pub fn Cable::tension(self : Cable) -> Map[String, @symcore.Expr] {
  self.tension_
}

///|
pub fn Cable::change_support(
  self : Cable,
  label : String,
  new_support : CableSupportSpec,
) -> Unit raise CableError {
  guard self.supports_.get(label) is Some(_) else {
    raise CableError::ValueError("no support exists with the given label")
  }
  self.supports_.remove(label)
  self.supports_[new_support.0] = [new_support.1, new_support.2]
  let entries = self.supports_
    .iter()
    .to_array()
    .map(item => (item.0, item.1[0], item.1[1]))
  let rebuilt = try! cable(entries[0], entries[1])
  self.supports_ = rebuilt.supports_
  self.support_labels_ = rebuilt.support_labels_
  self.left_support_ = rebuilt.left_support_
  self.right_support_ = rebuilt.right_support_
  self.reaction_loads_ = rebuilt.reaction_loads_
}

///|
pub fn Cable::apply_point_load(
  self : Cable,
  load : CablePointLoadSpec,
) -> Unit raise CableError {
  guard self.distributed_loads_.is_empty() else {
    raise CableError::ValueError("distributed load already exists")
  }
  guard self.point_loads_.get(load.0) is None else {
    raise CableError::ValueError("label already exists")
  }
  self.point_loads_[load.0] = [load.3, load.4]
  self.loads_position_[load.0] = [load.1, load.2]
}

///|
pub fn Cable::apply_distributed_load(
  self : Cable,
  label : String,
  magnitude : @symcore.Expr,
) -> Unit raise CableError {
  guard self.loads_position_.is_empty() else {
    raise CableError::ValueError("point loads already exist")
  }
  guard self.distributed_loads_.get(label) is None else {
    raise CableError::ValueError("label already exists")
  }
  self.distributed_loads_[label] = magnitude
}

///|
pub fn Cable::remove_loads(
  self : Cable,
  labels : Array[String],
) -> Unit raise CableError {
  for label in labels {
    if self.point_loads_.get(label) is Some(_) {
      self.point_loads_.remove(label)
      self.loads_position_.remove(label)
    } else if self.distributed_loads_.get(label) is Some(_) {
      self.distributed_loads_.remove(label)
    } else {
      raise CableError::ValueError(
        "error removing load " + label + ": no such load exists",
      )
    }
  }
}

///|
pub fn Cable::apply_length(self : Cable, value : @symcore.Expr) -> Unit {
  self.length_ = value
}

///|
fn cable_ordered_nodes(
  cable : Cable,
) -> Array[(String, @symcore.Expr, @symcore.Expr, Bool)] {
  let nodes : Array[(String, @symcore.Expr, @symcore.Expr, Bool)] = [
    (
      cable.support_labels_[0],
      cable.left_support_[0],
      cable.left_support_[1],
      false,
    ),
  ]
  let items = cable.loads_position_
    .iter()
    .to_array()
    .map(item => (item.0, item.1[0], item.1[1], true))
  items.sort_by((a, b) => cm_sign_of_difference(a.1, b.1).unwrap_or(0))
  for item in items {
    nodes.push(item)
  }
  nodes.push(
    (
      cable.support_labels_[1],
      cable.right_support_[0],
      cable.right_support_[1],
      false,
    ),
  )
  nodes
}

///|
pub fn Cable::solve(
  self : Cable,
  lowest_x? : @symcore.Expr? = None,
  lowest_y? : @symcore.Expr? = None,
) -> Unit raise CableError {
  self.tension_ = {}
  if !self.loads_position_.is_empty() {
    let nodes = cable_ordered_nodes(self)
    let mut total_length = @symcore.int(0)
    for i in 0..<(nodes.length() - 1) {
      total_length = total_length +
        cable_segment_length(
          nodes[i].1,
          nodes[i].2,
          nodes[i + 1].1,
          nodes[i + 1].2,
        )
    }
    self.length_ = cm_simplify(total_length)
    self.reaction_loads_ = {}
    let mut moment_left = @symcore.int(0)
    let mut moment_right = @symcore.int(0)
    let mut force_x = @symcore.int(0)
    let mut force_y = @symcore.int(0)
    let left_x = self.left_support_[0]
    let left_y = self.left_support_[1]
    let right_x = self.right_support_[0]
    let right_y = self.right_support_[1]

    for i in 1..<(nodes.length() - 1) {
      let current = nodes[i]
      let load = self.point_loads_[current.0]
      let load_x = cm_simplify(load[0] * cable_cos_deg(load[1]))
      let load_y = cm_simplify(load[0] * cable_sin_deg(load[1]))
      moment_left = cm_simplify(
        moment_left +
        load_x * @symelem.abs(left_y - current.2) +
        load_y * @symelem.abs(left_x - current.1),
      )
      force_x = cm_simplify(force_x + load_x)
      force_y = cm_simplify(force_y + load_y)
      if i < nodes.length() - 1 {
        let next = nodes[i + 1]
        let dx = next.1 - current.1
        let dy = next.2 - current.2
        let seg_len = cable_segment_length(current.1, current.2, next.1, next.2)
        let denom = cm_simplify(
          @symelem.abs(left_y - current.2) * dx * (seg_len ^ @symcore.int(-1)) +
          @symelem.abs(left_x - current.1) * dy * (seg_len ^ @symcore.int(-1)),
        )
        self.tension_[current.0 + "_" + next.0] = cm_simplify(
          @symcore.int(-1) * moment_left * (denom ^ @symcore.int(-1)),
        )
      }
      moment_right = cm_simplify(
        moment_right +
        load_x * @symelem.abs(right_y - current.2) +
        load_y * @symelem.abs(right_x - current.1),
      )
    }

    let first = nodes[1]
    let first_dx = first.1 - left_x
    let first_dy = first.2 - left_y
    let first_len = cable_segment_length(left_x, left_y, first.1, first.2)
    let first_denom = cm_simplify(
      @symelem.abs(right_y - first.2) *
      first_dx *
      (first_len ^ @symcore.int(-1)) -
      @symelem.abs(right_x - first.1) *
      first_dy *
      (first_len ^ @symcore.int(-1)),
    )
    let first_tension = cm_simplify(
      @symcore.int(-1) * moment_right * (first_denom ^ @symcore.int(-1)),
    )
    self.tension_[self.support_labels_[0] + "_" + first.0] = first_tension

    let left_rx = cm_simplify(
      @symcore.int(-1) *
      first_tension *
      first_dx *
      (first_len ^ @symcore.int(-1)),
    )
    let left_ry = cm_simplify(
      @symcore.int(-1) *
      first_tension *
      first_dy *
      (first_len ^ @symcore.int(-1)),
    )
    self.reaction_loads_["R_" + self.support_labels_[0] + "_x"] = left_rx
    self.reaction_loads_["R_" + self.support_labels_[0] + "_y"] = left_ry
    force_x = cm_simplify(force_x + left_rx)
    force_y = cm_simplify(force_y + left_ry)
    self.reaction_loads_["R_" + self.support_labels_[1] + "_x"] = cm_simplify(
      @symcore.int(-1) * force_x,
    )
    self.reaction_loads_["R_" + self.support_labels_[1] + "_y"] = cm_simplify(
      @symcore.int(-1) * force_y,
    )
  } else if !self.distributed_loads_.is_empty() {
    let x0 = match lowest_x {
      Some(value) => value
      None =>
        raise CableError::ValueError("provide the lowest point of the cable")
    }
    let _ = lowest_y
    self.lowest_x_ = x0
    let left_dx = self.left_support_[0] - x0
    let right_dx = self.right_support_[0] - x0
    let coeffs = try! cm_linear_solve(
      [
        @symcore.symbol("A") * (left_dx ^ @symcore.int(2)) +
        @symcore.symbol("c") -
        self.left_support_[1],
        @symcore.symbol("A") * (right_dx ^ @symcore.int(2)) +
        @symcore.symbol("c") -
        self.right_support_[1],
      ],
      [@symcore.symbol("A"), @symcore.symbol("c")],
    ).unwrap_or({})
    let a_coeff = coeffs.get("A").unwrap_or(@symcore.int(0))
    let c_coeff = coeffs.get("c").unwrap_or(@symcore.int(0))
    self.lowest_y_ = c_coeff
    let right_dy = self.right_support_[1] - c_coeff
    let weight = self.distributed_loads_.iter().to_array()[0].1
    let h = cm_simplify(
      weight *
      (right_dx ^ @symcore.int(2)) *
      cm_rat_expr(1, 2) *
      (right_dy ^ @symcore.int(-1)),
    )
    let x = @symcore.symbol("X")
    let slope = cm_simplify(@symcore.int(2) * a_coeff * x)
    let tension_expr = cm_simplify(
      h * @symelem.sqrt(@symcore.int(1) + (slope ^ @symcore.int(2))),
    )
    self.tension_ = { "distributed": tension_expr }
    self.reaction_loads_ = {}
    let left_slope = cm_simplify(
      @symcore.int(2) * a_coeff * (self.left_support_[0] - x0),
    )
    let right_slope = cm_simplify(
      @symcore.int(2) * a_coeff * (self.right_support_[0] - x0),
    )
    let left_tension = try! self.tension_at(self.left_support_[0])
    self.reaction_loads_["R_" + self.support_labels_[0] + "_x"] = cm_simplify(h)
    self.reaction_loads_["R_" + self.support_labels_[0] + "_y"] = cm_simplify(
      h * left_slope,
    )
    self.reaction_loads_["R_" + self.support_labels_[1] + "_x"] = cm_simplify(
      left_tension *
      (
        @symelem.sqrt(@symcore.int(1) + (right_slope ^ @symcore.int(2))) ^
        @symcore.int(-1)
      ),
    )
    self.reaction_loads_["R_" + self.support_labels_[1] + "_y"] = cm_simplify(
      self.reaction_loads_["R_" + self.support_labels_[1] + "_x"] * right_slope,
    )
  } else {
    raise CableError::ValueError("no loads applied to the cable")
  }
}

///|
pub fn Cable::tension_at(
  self : Cable,
  x : @symcore.Expr,
) -> @symcore.Expr raise CableError {
  match self.tension_.get("distributed") {
    Some(expr) => @symcore.subst(expr, { "X": x - self.lowest_x_ })
    None =>
      raise CableError::ValueError(
        "no distributed load added or solve not called",
      )
  }
}
