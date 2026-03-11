///|
/// Core 2D truss modeling and solving aligned with the non-plotting surface of
/// `sympy.physics.continuum_mechanics.truss`.

///|
pub type NodeSpec = (String, @symcore.Expr, @symcore.Expr)

///|
pub type MemberSpec = (String, String, String)

///|
pub type LoadSpec = (String, @symcore.Expr, @symcore.Expr)

///|
pub type SupportSpec = (String, String)

///|
pub type MemberEndpoints = Array[String]

///|
pub type NodeLoads = Array[Array[@symcore.Expr]]

///|
pub suberror TrussError {
  ValueError(String)
} derive(Show, Eq)

///|
pub struct Truss {
  nodes_ : Array[NodeSpec]
  node_labels_ : Array[String]
  node_positions_ : Array[(@symcore.Expr, @symcore.Expr)]
  members_ : Map[String, MemberEndpoints]
  loads_ : Map[String, NodeLoads]
  supports_ : Map[String, String]
  mut reaction_loads_ : Map[String, @symcore.Expr]
  mut internal_forces_ : Map[String, @symcore.Expr]
  node_coordinates_ : Map[String, (@symcore.Expr, @symcore.Expr)]
  mut node_pairs_occupied_ : Map[(String, String), Bool]
  mut member_lengths_ : Map[String, @symcore.Expr]
}

///|
pub fn truss() -> Truss {
  Truss::{
    nodes_: [],
    node_labels_: [],
    node_positions_: [],
    members_: {},
    loads_: {},
    supports_: {},
    reaction_loads_: {},
    internal_forces_: {},
    node_coordinates_: {},
    node_pairs_occupied_: {},
    member_lengths_: {},
  }
}

///|
fn int_expr(value : Int) -> @symcore.Expr {
  @symcore.int(value)
}

///|
fn rational_expr(num : Int, den : Int) -> @symcore.Expr {
  try! @symcore.rational_from_ints(num, den)
}

///|
fn pi_expr() -> @symcore.Expr {
  @symcore.symbol("pi")
}

///|
fn expr_div(lhs : @symcore.Expr, rhs : @symcore.Expr) -> @symcore.Expr {
  lhs * (rhs ^ int_expr(-1))
}

///|
fn sqrt2_over_2() -> @symcore.Expr {
  @symelem.sqrt(int_expr(2)) * rational_expr(1, 2)
}

///|
fn sqrt3_over_2() -> @symcore.Expr {
  @symelem.sqrt(int_expr(3)) * rational_expr(1, 2)
}

///|
fn expr_integer_value(expr : @symcore.Expr) -> Int? {
  match expr {
    @symcore.Expr::Number(n) if n.is_integral() => Some(n.numerator().to_int())
    _ => None
  }
}

///|
fn normalize_expr(expr : @symcore.Expr) -> @symcore.Expr {
  @symsimplify.ratsimp(@symsimplify.simplify(expr, max_passes=4), max_passes=4)
}

///|
fn expr_is_zero(expr : @symcore.Expr) -> Bool {
  normalize_expr(expr) == int_expr(0)
}

///|
fn rename_symbol(expr : @symcore.Expr, old_name : String, new_name : String) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Symbol(name) =>
      if name == old_name {
        @symcore.symbol(new_name)
      } else {
        expr
      }
    @symcore.Expr::Add(args) =>
      @symcore.add(args.map(arg => rename_symbol(arg, old_name, new_name)))
    @symcore.Expr::Mul(args) =>
      @symcore.mul(args.map(arg => rename_symbol(arg, old_name, new_name)))
    @symcore.Expr::Pow(base, exp) =>
      @symcore.pow(rename_symbol(base, old_name, new_name), rename_symbol(exp, old_name, new_name))
    @symcore.Expr::Function(name, args) =>
      @symcore.function(name, args.map(arg => rename_symbol(arg, old_name, new_name)))
    _ => expr
  }
}

///|
fn reaction_x_name(node : String) -> String {
  "R_\{node}_x"
}

///|
fn reaction_y_name(node : String) -> String {
  "R_\{node}_y"
}

///|
fn common_angle_sin(angle : Int) -> @symcore.Expr? {
  match ((angle % 360) + 360) % 360 {
    0 => Some(int_expr(0))
    30 => Some(rational_expr(1, 2))
    45 => Some(sqrt2_over_2())
    60 => Some(sqrt3_over_2())
    90 => Some(int_expr(1))
    120 => Some(sqrt3_over_2())
    135 => Some(sqrt2_over_2())
    150 => Some(rational_expr(1, 2))
    180 => Some(int_expr(0))
    210 => Some(int_expr(-1) * rational_expr(1, 2))
    225 => Some(int_expr(-1) * sqrt2_over_2())
    240 => Some(int_expr(-1) * sqrt3_over_2())
    270 => Some(int_expr(-1))
    300 => Some(int_expr(-1) * sqrt3_over_2())
    315 => Some(int_expr(-1) * sqrt2_over_2())
    330 => Some(int_expr(-1) * rational_expr(1, 2))
    _ => None
  }
}

///|
fn common_angle_cos(angle : Int) -> @symcore.Expr? {
  match ((angle % 360) + 360) % 360 {
    0 => Some(int_expr(1))
    30 => Some(sqrt3_over_2())
    45 => Some(sqrt2_over_2())
    60 => Some(rational_expr(1, 2))
    90 => Some(int_expr(0))
    120 => Some(int_expr(-1) * rational_expr(1, 2))
    135 => Some(int_expr(-1) * sqrt2_over_2())
    150 => Some(int_expr(-1) * sqrt3_over_2())
    180 => Some(int_expr(-1))
    210 => Some(int_expr(-1) * sqrt3_over_2())
    225 => Some(int_expr(-1) * sqrt2_over_2())
    240 => Some(int_expr(-1) * rational_expr(1, 2))
    270 => Some(int_expr(0))
    300 => Some(rational_expr(1, 2))
    315 => Some(sqrt2_over_2())
    330 => Some(sqrt3_over_2())
    _ => None
  }
}

///|
fn sin_deg(angle : @symcore.Expr) -> @symcore.Expr {
  match expr_integer_value(angle) {
    Some(value) =>
      match common_angle_sin(value) {
        Some(out) => out
        None => @symelem.sin(expr_div(pi_expr() * angle, int_expr(180)))
      }
    None => @symelem.sin(expr_div(pi_expr() * angle, int_expr(180)))
  }
}

///|
fn cos_deg(angle : @symcore.Expr) -> @symcore.Expr {
  match expr_integer_value(angle) {
    Some(value) =>
      match common_angle_cos(value) {
        Some(out) => out
        None => @symelem.cos(expr_div(pi_expr() * angle, int_expr(180)))
      }
    None => @symelem.cos(expr_div(pi_expr() * angle, int_expr(180)))
  }
}

///|
fn member_length_from_coords(
  start_coords : (@symcore.Expr, @symcore.Expr),
  end_coords : (@symcore.Expr, @symcore.Expr),
) -> @symcore.Expr {
  let dx = normalize_expr(end_coords.0 - start_coords.0)
  let dy = normalize_expr(end_coords.1 - start_coords.1)
  normalize_expr(@symelem.sqrt((dx ^ int_expr(2)) + (dy ^ int_expr(2))))
}

///|
fn find_string_index(values : Array[String], target : String) -> Int? {
  for i in 0..<values.length() {
    if values[i] == target {
      return Some(i)
    }
  }
  None
}

///|
fn remove_load_entry(loads : NodeLoads, entry : Array[@symcore.Expr]) -> Bool {
  for i in 0..<loads.length() {
    if loads[i] == entry {
      ignore(loads.remove(i))
      return true
    }
  }
  false
}

///|
fn rename_node_load_symbols(
  loads : NodeLoads,
  old_label : String,
  new_label : String,
) -> NodeLoads {
  let out : NodeLoads = []
  let old_rx = reaction_x_name(old_label)
  let old_ry = reaction_y_name(old_label)
  let new_rx = reaction_x_name(new_label)
  let new_ry = reaction_y_name(new_label)
  for load in loads {
    let renamed_magnitude = rename_symbol(
      rename_symbol(load[0], old_rx, new_rx),
      old_ry,
      new_ry,
    )
    out.push([renamed_magnitude, load[1]])
  }
  out
}

///|
fn expect_node_coords(
  coords : Map[String, (@symcore.Expr, @symcore.Expr)],
  label : String,
) -> (@symcore.Expr, @symcore.Expr) raise TrussError {
  match coords.get(label) {
    Some(value) => value
    None => raise TrussError::ValueError("No such node exists in the truss")
  }
}

///|
fn solve_linear_system(
  coeff_rows : Array[Array[@symcore.Expr]],
  rhs_values : Array[@symcore.Expr],
) -> Array[@symcore.Expr] raise TrussError {
  let nrows = coeff_rows.length()
  let ncols = if nrows == 0 { 0 } else { coeff_rows[0].length() }
  guard nrows == rhs_values.length() && nrows == ncols else {
    raise TrussError::ValueError("The given truss cannot be solved")
  }

  let aug : Array[Array[@symcore.Expr]] = []
  for i in 0..<nrows {
    let row = coeff_rows[i].copy()
    row.push(rhs_values[i])
    aug.push(row)
  }

  for pivot in 0..<ncols {
    let mut pivot_row = pivot
    while pivot_row < nrows && expr_is_zero(aug[pivot_row][pivot]) {
      pivot_row += 1
    }
    guard pivot_row < nrows else {
      raise TrussError::ValueError("The given truss cannot be solved")
    }
    if pivot_row != pivot {
      let swapped = aug[pivot]
      aug[pivot] = aug[pivot_row]
      aug[pivot_row] = swapped
    }
    let pivot_value = aug[pivot][pivot]
    for row in (pivot + 1)..<nrows {
      if expr_is_zero(aug[row][pivot]) {
        continue
      }
      let factor = normalize_expr(expr_div(aug[row][pivot], pivot_value))
      for col in pivot..<=(ncols) {
        aug[row][col] = normalize_expr(aug[row][col] - (factor * aug[pivot][col]))
      }
    }
  }

  let solution : Array[@symcore.Expr] = Array::make(ncols, int_expr(0))
  let mut row = nrows - 1
  while row >= 0 {
    let mut rhs = aug[row][ncols]
    let mut col = row + 1
    while col < ncols {
      rhs = normalize_expr(rhs - (aug[row][col] * solution[col]))
      col += 1
    }
    guard !expr_is_zero(aug[row][row]) else {
      raise TrussError::ValueError("The given truss cannot be solved")
    }
    solution[row] = normalize_expr(expr_div(rhs, aug[row][row]))
    row -= 1
  }
  solution
}

///|
fn Truss::refresh_member_cache(self : Truss) -> Unit raise TrussError {
  let next_pairs : Map[(String, String), Bool] = {}
  let next_lengths : Map[String, @symcore.Expr] = {}
  for member_label, endpoints in self.members_ {
    let start = endpoints[0]
    let end_ = endpoints[1]
    let start_coords = expect_node_coords(self.node_coordinates_, start)
    let end_coords = expect_node_coords(self.node_coordinates_, end_)
    next_pairs[(start, end_)] = true
    next_pairs[(end_, start)] = true
    next_lengths[member_label] = member_length_from_coords(start_coords, end_coords)
  }
  self.node_pairs_occupied_ = next_pairs
  self.member_lengths_ = next_lengths
}

///|
fn Truss::move_reaction_solution(self : Truss, old_label : String, new_label : String) -> Unit {
  let old_rx = reaction_x_name(old_label)
  let old_ry = reaction_y_name(old_label)
  let new_rx = reaction_x_name(new_label)
  let new_ry = reaction_y_name(new_label)
  match self.reaction_loads_.get(old_rx) {
    Some(value) => {
      ignore(self.reaction_loads_.remove(old_rx))
      self.reaction_loads_.set(new_rx, value)
    }
    None => ()
  }
  match self.reaction_loads_.get(old_ry) {
    Some(value) => {
      ignore(self.reaction_loads_.remove(old_ry))
      self.reaction_loads_.set(new_ry, value)
    }
    None => ()
  }
}

///|
fn Truss::clear_reaction_solution_for_node(self : Truss, label : String) -> Unit {
  ignore(self.reaction_loads_.remove(reaction_x_name(label)))
  ignore(self.reaction_loads_.remove(reaction_y_name(label)))
}

///|
fn Truss::unknowns(self : Truss) -> Array[String] {
  let out : Array[String] = []
  for node in self.nodes_ {
    match self.supports_.get(node.0) {
      Some("pinned") => {
        out.push(reaction_x_name(node.0))
        out.push(reaction_y_name(node.0))
      }
      Some("roller") => out.push(reaction_y_name(node.0))
      _ => ()
    }
  }
  for member_label, _ in self.members_ {
    out.push(member_label)
  }
  out
}

///|
pub fn Truss::nodes(self : Truss) -> Array[NodeSpec] {
  self.nodes_
}

///|
pub fn Truss::node_labels(self : Truss) -> Array[String] {
  self.node_labels_
}

///|
pub fn Truss::node_positions(self : Truss) -> Array[(@symcore.Expr, @symcore.Expr)] {
  self.node_positions_
}

///|
pub fn Truss::members(self : Truss) -> Map[String, MemberEndpoints] {
  self.members_
}

///|
pub fn Truss::member_lengths(self : Truss) -> Map[String, @symcore.Expr] {
  self.member_lengths_
}

///|
pub fn Truss::supports(self : Truss) -> Map[String, String] {
  self.supports_
}

///|
pub fn Truss::loads(self : Truss) -> Map[String, NodeLoads] {
  self.loads_
}

///|
pub fn Truss::reaction_loads(self : Truss) -> Map[String, @symcore.Expr] {
  self.reaction_loads_
}

///|
pub fn Truss::internal_forces(self : Truss) -> Map[String, @symcore.Expr] {
  self.internal_forces_
}

///|
pub fn Truss::add_node(
  self : Truss,
  specs : Array[NodeSpec],
) -> Unit raise TrussError {
  for spec in specs {
    let label = spec.0
    let x = normalize_expr(spec.1)
    let y = normalize_expr(spec.2)
    guard self.node_coordinates_.get(label) is None else {
      raise TrussError::ValueError("Node needs to have a unique label")
    }
    for _, coords in self.node_coordinates_ {
      if coords == (x, y) {
        raise TrussError::ValueError("A node already exists at the given position")
      }
    }
    self.nodes_.push((label, x, y))
    self.node_labels_.push(label)
    self.node_positions_.push((x, y))
    self.node_coordinates_.set(label, (x, y))
  }
}

///|
pub fn Truss::remove_node(
  self : Truss,
  labels : Array[String],
) -> Unit raise TrussError {
  for label in labels {
    guard self.node_coordinates_.get(label) is Some(_) else {
      raise TrussError::ValueError("No such node exists in the truss")
    }
    for _, endpoints in self.members_ {
      if endpoints[0] == label || endpoints[1] == label {
        raise TrussError::ValueError("The given node already has member attached to it")
      }
    }
    let index = match find_string_index(self.node_labels_, label) {
      Some(value) => value
      None => raise TrussError::ValueError("No such node exists in the truss")
    }
    ignore(self.nodes_.remove(index))
    ignore(self.node_labels_.remove(index))
    ignore(self.node_positions_.remove(index))
    ignore(self.node_coordinates_.remove(label))
    ignore(self.loads_.remove(label))
    ignore(self.supports_.remove(label))
    self.clear_reaction_solution_for_node(label)
  }
}

///|
pub fn Truss::add_member(
  self : Truss,
  specs : Array[MemberSpec],
) -> Unit raise TrussError {
  for spec in specs {
    let label = spec.0
    let start = spec.1
    let end_ = spec.2
    guard start != end_ &&
      self.node_coordinates_.get(start) is Some(_) &&
      self.node_coordinates_.get(end_) is Some(_) else {
      raise TrussError::ValueError("The start and end points of the member must be unique nodes")
    }
    guard self.members_.get(label) is None else {
      raise TrussError::ValueError("A member with the same label already exists for the truss")
    }
    guard self.node_pairs_occupied_.get((start, end_)) is None else {
      raise TrussError::ValueError("A member already exists between the two nodes")
    }
    self.members_.set(label, [start, end_])
    self.internal_forces_.set(label, int_expr(0))
  }
  self.refresh_member_cache()
}

///|
pub fn Truss::remove_member(
  self : Truss,
  labels : Array[String],
) -> Unit raise TrussError {
  for label in labels {
    guard self.members_.get(label) is Some(_) else {
      raise TrussError::ValueError("No such member exists in the Truss")
    }
    ignore(self.members_.remove(label))
    ignore(self.member_lengths_.remove(label))
    ignore(self.internal_forces_.remove(label))
  }
  self.refresh_member_cache()
}

///|
pub fn Truss::change_node_label(
  self : Truss,
  renames : Array[(String, String)],
) -> Unit raise TrussError {
  for rename in renames {
    let old_label = rename.0
    let new_label = rename.1
    guard self.node_coordinates_.get(old_label) is Some(_) else {
      raise TrussError::ValueError("No such node exists for the Truss")
    }
    guard self.node_coordinates_.get(new_label) is None else {
      raise TrussError::ValueError("A node with the given label already exists")
    }
    let index = match find_string_index(self.node_labels_, old_label) {
      Some(value) => value
      None => raise TrussError::ValueError("No such node exists for the Truss")
    }
    let coords = expect_node_coords(self.node_coordinates_, old_label)
    self.nodes_[index] = (new_label, coords.0, coords.1)
    self.node_labels_[index] = new_label
    ignore(self.node_coordinates_.remove(old_label))
    self.node_coordinates_.set(new_label, coords)

    match self.supports_.get(old_label) {
      Some(kind) => {
        ignore(self.supports_.remove(old_label))
        self.supports_.set(new_label, kind)
      }
      None => ()
    }
    match self.loads_.get(old_label) {
      Some(loads) => {
        ignore(self.loads_.remove(old_label))
        self.loads_.set(new_label, rename_node_load_symbols(loads, old_label, new_label))
      }
      None => ()
    }
    self.move_reaction_solution(old_label, new_label)

    for member_label, endpoints in self.members_ {
      if endpoints[0] == old_label {
        endpoints[0] = new_label
      }
      if endpoints[1] == old_label {
        endpoints[1] = new_label
      }
      self.members_.set(member_label, endpoints)
    }
  }
  self.refresh_member_cache()
}

///|
pub fn Truss::change_member_label(
  self : Truss,
  renames : Array[(String, String)],
) -> Unit raise TrussError {
  for rename in renames {
    let old_label = rename.0
    let new_label = rename.1
    let endpoints = match self.members_.get(old_label) {
      Some(value) => value
      None => raise TrussError::ValueError("No such member exists for the Truss")
    }
    guard new_label == old_label || self.members_.get(new_label) is None else {
      raise TrussError::ValueError("A member with the same label already exists for the truss")
    }
    ignore(self.members_.remove(old_label))
    self.members_.set(new_label, endpoints)
    match self.internal_forces_.get(old_label) {
      Some(force) => {
        ignore(self.internal_forces_.remove(old_label))
        self.internal_forces_.set(new_label, force)
      }
      None => self.internal_forces_.set(new_label, int_expr(0))
    }
  }
  self.refresh_member_cache()
}

///|
pub fn Truss::apply_load(
  self : Truss,
  specs : Array[LoadSpec],
) -> Unit raise TrussError {
  for spec in specs {
    let location = spec.0
    guard self.node_coordinates_.get(location) is Some(_) else {
      raise TrussError::ValueError("Load must be applied at a known node")
    }
    let entry = [normalize_expr(spec.1), normalize_expr(spec.2)]
    match self.loads_.get(location) {
      Some(loads) => {
        loads.push(entry)
        self.loads_.set(location, loads)
      }
      None => self.loads_.set(location, [entry])
    }
  }
}

///|
pub fn Truss::remove_load(
  self : Truss,
  specs : Array[LoadSpec],
) -> Unit raise TrussError {
  for spec in specs {
    let location = spec.0
    guard self.node_coordinates_.get(location) is Some(_) else {
      raise TrussError::ValueError("Load must be removed from a known node")
    }
    let loads = match self.loads_.get(location) {
      Some(value) => value
      None => raise TrussError::ValueError("No load of this magnitude and direction has been applied at this node")
    }
    let entry = [normalize_expr(spec.1), normalize_expr(spec.2)]
    guard remove_load_entry(loads, entry) else {
      raise TrussError::ValueError("No load of this magnitude and direction has been applied at this node")
    }
    if loads.is_empty() {
      ignore(self.loads_.remove(location))
    } else {
      self.loads_.set(location, loads)
    }
  }
}

///|
pub fn Truss::apply_support(
  self : Truss,
  specs : Array[SupportSpec],
) -> Unit raise TrussError {
  for spec in specs {
    let location = spec.0
    let kind = spec.1
    guard self.node_coordinates_.get(location) is Some(_) else {
      raise TrussError::ValueError("Support must be added on a known node")
    }
    guard kind == "pinned" || kind == "roller" else {
      raise TrussError::ValueError("Support type must be pinned or roller")
    }
    match self.supports_.get(location) {
      None =>
        if kind == "pinned" {
          self.apply_load([
            (location, @symcore.symbol(reaction_x_name(location)), int_expr(0)),
            (location, @symcore.symbol(reaction_y_name(location)), int_expr(90)),
          ])
        } else {
          self.apply_load([(location, @symcore.symbol(reaction_y_name(location)), int_expr(90))])
        }
      Some(existing) =>
        if existing == "pinned" && kind == "roller" {
          self.remove_load([(location, @symcore.symbol(reaction_x_name(location)), int_expr(0))])
        } else if existing == "roller" && kind == "pinned" {
          self.apply_load([(location, @symcore.symbol(reaction_x_name(location)), int_expr(0))])
        }
    }
    self.supports_.set(location, kind)
  }
}

///|
pub fn Truss::remove_support(
  self : Truss,
  labels : Array[String],
) -> Unit raise TrussError {
  for label in labels {
    guard self.node_coordinates_.get(label) is Some(_) else {
      raise TrussError::ValueError("No such node exists in the Truss")
    }
    let kind = match self.supports_.get(label) {
      Some(value) => value
      None => raise TrussError::ValueError("No support has been added to the given node")
    }
    if kind == "pinned" {
      self.remove_load([
        (label, @symcore.symbol(reaction_x_name(label)), int_expr(0)),
        (label, @symcore.symbol(reaction_y_name(label)), int_expr(90)),
      ])
    } else {
      self.remove_load([(label, @symcore.symbol(reaction_y_name(label)), int_expr(90))])
    }
    ignore(self.supports_.remove(label))
    self.clear_reaction_solution_for_node(label)
  }
}

///|
pub fn Truss::solve(self : Truss) -> Unit raise TrussError {
  let mut reaction_count = 0
  for node in self.nodes_ {
    match self.supports_.get(node.0) {
      Some("pinned") => reaction_count += 2
      Some("roller") => reaction_count += 1
      _ => ()
    }
  }
  guard 2 * self.nodes_.length() == self.members_.length() + reaction_count else {
    raise TrussError::ValueError("The given truss cannot be solved")
  }

  let unknowns = self.unknowns()
  let unknown_index : Map[String, Int] = {}
  for i in 0..<unknowns.length() {
    unknown_index[unknowns[i]] = i
  }

  let coeff_rows : Array[Array[@symcore.Expr]] = []
  let rhs_values : Array[@symcore.Expr] = []
  for node in self.nodes_ {
    let label = node.0
    let row_x = Array::make(unknowns.length(), int_expr(0))
    let row_y = Array::make(unknowns.length(), int_expr(0))
    match self.supports_.get(label) {
      Some("pinned") => {
        row_x[unknown_index[reaction_x_name(label)]] = int_expr(1)
        row_y[unknown_index[reaction_y_name(label)]] = int_expr(1)
      }
      Some("roller") => row_y[unknown_index[reaction_y_name(label)]] = int_expr(1)
      _ => ()
    }

    let mut rhs_x = int_expr(0)
    let mut rhs_y = int_expr(0)
    match self.loads_.get(label) {
      Some(loads) =>
        for load in loads {
          let is_reaction_symbol = match load[0] {
            @symcore.Expr::Symbol(name) =>
              name == reaction_x_name(label) || name == reaction_y_name(label)
            _ => false
          }
          if !is_reaction_symbol {
            rhs_x = normalize_expr(rhs_x - (load[0] * cos_deg(load[1])))
            rhs_y = normalize_expr(rhs_y - (load[0] * sin_deg(load[1])))
          }
        }
      None => ()
    }

    for member_label, endpoints in self.members_ {
      let start = endpoints[0]
      let end_ = endpoints[1]
      let start_coords = expect_node_coords(self.node_coordinates_, start)
      let end_coords = expect_node_coords(self.node_coordinates_, end_)
      let length = match self.member_lengths_.get(member_label) {
        Some(value) => value
        None => raise TrussError::ValueError("missing member length")
      }
      let col = unknown_index[member_label]
      if label == start {
        row_x[col] = normalize_expr(expr_div(end_coords.0 - start_coords.0, length))
        row_y[col] = normalize_expr(expr_div(end_coords.1 - start_coords.1, length))
      } else if label == end_ {
        row_x[col] = normalize_expr(expr_div(start_coords.0 - end_coords.0, length))
        row_y[col] = normalize_expr(expr_div(start_coords.1 - end_coords.1, length))
      }
    }

    coeff_rows.push(row_x)
    coeff_rows.push(row_y)
    rhs_values.push(rhs_x)
    rhs_values.push(rhs_y)
  }

  let solved_values = solve_linear_system(coeff_rows, rhs_values)

  self.reaction_loads_ = {}
  self.internal_forces_ = {}
  let solved : Map[String, @symcore.Expr] = {}
  for i in 0..<unknowns.length() {
    solved[unknowns[i]] = normalize_expr(solved_values[i])
  }
  for node in self.nodes_ {
    match self.supports_.get(node.0) {
      Some("pinned") => {
        let rx = reaction_x_name(node.0)
        let ry = reaction_y_name(node.0)
        self.reaction_loads_.set(rx, normalize_expr(solved[rx]))
        self.reaction_loads_.set(ry, normalize_expr(solved[ry]))
      }
      Some("roller") => {
        let ry = reaction_y_name(node.0)
        self.reaction_loads_.set(ry, normalize_expr(solved[ry]))
      }
      _ => ()
    }
  }
  for member_label, _ in self.members_ {
    self.internal_forces_.set(member_label, normalize_expr(solved[member_label]))
  }
}
