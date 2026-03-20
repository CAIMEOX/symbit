///|
/// Symbolic Euler-Bernoulli beam helper aligned with the core symbolic surface
/// of `sympy.physics.continuum_mechanics.beam`.

///|
pub type BeamBoundaryValue = (@symcore.Expr, @symcore.Expr)

///|
pub type BeamLoadSpec = (@symcore.Expr, @symcore.Expr, Int, @symcore.Expr?)

///|
pub suberror BeamError {
  ValueError(String)
  TypeError(String)
  SolveError(String)
} derive(Show, Eq)

///|
pub struct Beam {
  mut length_ : @symcore.Expr
  mut elastic_modulus_ : @symcore.Expr
  mut second_moment_ : @symcore.Expr
  mut area_ : @symcore.Expr
  mut variable_ : @symcore.Expr
  base_char_ : String
  mut bc_shear_force_ : Array[BeamBoundaryValue]
  mut bc_bending_moment_ : Array[BeamBoundaryValue]
  mut bc_slope_ : Array[BeamBoundaryValue]
  mut bc_deflection_ : Array[BeamBoundaryValue]
  mut applied_loads_ : Array[BeamLoadSpec]
  applied_support_symbols_ : Array[@symcore.Expr]
  mut load_ : @symcore.Expr
  mut reaction_loads_ : Map[String, @symcore.Expr]
}

///|
pub fn beam(
  length : @symcore.Expr,
  elastic_modulus : @symcore.Expr,
  second_moment : @symcore.Expr,
  area? : @symcore.Expr = @symcore.symbol("A"),
  variable? : @symcore.Expr = @symcore.symbol("x"),
  base_char? : String = "C",
) -> Beam raise BeamError {
  guard variable is @symcore.Expr::Symbol(_) else {
    raise BeamError::TypeError("beam variable should be a symbol")
  }
  Beam::{
    length_: length,
    elastic_modulus_: elastic_modulus,
    second_moment_: second_moment,
    area_: area,
    variable_: variable,
    base_char_: base_char,
    bc_shear_force_: [],
    bc_bending_moment_: [],
    bc_slope_: [],
    bc_deflection_: [],
    applied_loads_: [],
    applied_support_symbols_: [],
    load_: @symcore.int(0),
    reaction_loads_: {},
  }
}

///|
fn beam_var_name(beam : Beam) -> String {
  match beam.variable_ {
    @symcore.Expr::Symbol(name) => name
    _ => "x"
  }
}

///|
fn beam_support_symbol(loc : @symcore.Expr, prefix : String) -> @symcore.Expr {
  @symcore.symbol(prefix + @symprint.to_string(loc))
}

///|
fn beam_unique_exprs(values : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  let seen : Map[String, Bool] = {}
  let out : Array[@symcore.Expr] = []
  for value in values {
    let key = @symprint.to_string(value)
    if seen.get(key) is None {
      seen[key] = true
      out.push(value)
    }
  }
  out
}

///|
fn beam_factorial(n : Int) -> Int {
  let mut acc = 1
  for i in 2..<=n {
    acc = acc * i
  }
  acc
}

///|
fn beam_falling_factorial(n : Int, k : Int) -> Int {
  let mut acc = 1
  for i in 0..<k {
    acc = acc * (n - i)
  }
  acc
}

///|
fn beam_end_terms(
  value : @symcore.Expr,
  start : @symcore.Expr,
  order : Int,
  end_value : @symcore.Expr,
  var_expr : @symcore.Expr,
) -> Array[@symcore.Expr] raise BeamError {
  if order < 0 {
    raise BeamError::ValueError(
      "end is only valid for distributed loads with nonnegative order",
    )
  }
  let start_to_end = end_value - start
  let out : Array[@symcore.Expr] = []
  for i in 0..<=order {
    let coeff = if i == order {
      value
    } else {
      value *
      @symcore.int(beam_falling_factorial(order, i)) *
      (start_to_end ^ @symcore.int(order - i)) *
      cm_rat_expr(1, beam_factorial(i))
    }
    out.push(coeff * cm_singularity(var_expr, end_value, i))
  }
  out
}

///|
fn beam_substitute_map(
  expr : @symcore.Expr,
  solution : Map[String, @symcore.Expr],
) -> @symcore.Expr {
  @symcore.subst(expr, solution)
}

///|
fn beam_ei(beam : Beam) -> @symcore.Expr {
  beam.elastic_modulus_ * beam.second_moment_
}

///|
fn beam_slope_curve(beam : Beam, constant_name : String) -> @symcore.Expr {
  let integral = cm_integrate(beam.bending_moment(), beam_var_name(beam))
  cm_symbol(constant_name) +
  @symcore.int(-1) * integral * (beam_ei(beam) ^ @symcore.int(-1))
}

///|
fn beam_deflection_curve(
  beam : Beam,
  slope_curve : @symcore.Expr,
  constant_name : String,
) -> @symcore.Expr {
  cm_integrate(slope_curve, beam_var_name(beam)) + cm_symbol(constant_name)
}

///|
fn beam_solve_constant_system(
  beam : Beam,
  slope_curve : @symcore.Expr,
  deflection_curve : @symcore.Expr,
  include_slope : Bool,
  include_deflection : Bool,
) -> Map[String, @symcore.Expr]? raise BeamError {
  let c3 = cm_symbol(beam.base_char_ + "3")
  let c4 = cm_symbol(beam.base_char_ + "4")
  let eqs : Array[@symcore.Expr] = []
  let unknowns : Array[@symcore.Expr] = []
  if include_slope {
    unknowns.push(c3)
    for item in beam.bc_slope_ {
      eqs.push(cm_eval_at(slope_curve, beam_var_name(beam), item.0) - item.1)
    }
  }
  if include_deflection {
    if !unknowns.any(item => item == c3) {
      unknowns.push(c3)
    }
    unknowns.push(c4)
    for item in beam.bc_deflection_ {
      eqs.push(
        cm_eval_at(deflection_curve, beam_var_name(beam), item.0) - item.1,
      )
    }
  }
  if eqs.is_empty() {
    return Some({})
  }
  let maybe_solution = try? cm_linear_solve(eqs, beam_unique_exprs(unknowns))
  match maybe_solution {
    Ok(solution) => solution
    Err(_) => raise BeamError::SolveError("unable to determine beam constants")
  }
}

///|
pub fn Beam::length(self : Beam) -> @symcore.Expr {
  self.length_
}

///|
pub fn Beam::elastic_modulus(self : Beam) -> @symcore.Expr {
  self.elastic_modulus_
}

///|
pub fn Beam::second_moment(self : Beam) -> @symcore.Expr {
  self.second_moment_
}

///|
pub fn Beam::area(self : Beam) -> @symcore.Expr {
  self.area_
}

///|
pub fn Beam::variable(self : Beam) -> @symcore.Expr {
  self.variable_
}

///|
pub fn Beam::set_length(self : Beam, value : @symcore.Expr) -> Unit {
  self.length_ = value
}

///|
pub fn Beam::set_elastic_modulus(self : Beam, value : @symcore.Expr) -> Unit {
  self.elastic_modulus_ = value
}

///|
pub fn Beam::set_second_moment(self : Beam, value : @symcore.Expr) -> Unit {
  self.second_moment_ = value
}

///|
pub fn Beam::set_area(self : Beam, value : @symcore.Expr) -> Unit {
  self.area_ = value
}

///|
pub fn Beam::set_variable(
  self : Beam,
  value : @symcore.Expr,
) -> Unit raise BeamError {
  guard value is @symcore.Expr::Symbol(_) else {
    raise BeamError::TypeError("beam variable should be a symbol")
  }
  self.variable_ = value
}

///|
pub fn Beam::bc_shear_force(self : Beam) -> Array[BeamBoundaryValue] {
  self.bc_shear_force_
}

///|
pub fn Beam::bc_bending_moment(self : Beam) -> Array[BeamBoundaryValue] {
  self.bc_bending_moment_
}

///|
pub fn Beam::bc_slope(self : Beam) -> Array[BeamBoundaryValue] {
  self.bc_slope_
}

///|
pub fn Beam::bc_deflection(self : Beam) -> Array[BeamBoundaryValue] {
  self.bc_deflection_
}

///|
pub fn Beam::set_bc_shear_force(
  self : Beam,
  values : Array[BeamBoundaryValue],
) -> Unit {
  self.bc_shear_force_ = values.copy()
}

///|
pub fn Beam::set_bc_bending_moment(
  self : Beam,
  values : Array[BeamBoundaryValue],
) -> Unit {
  self.bc_bending_moment_ = values.copy()
}

///|
pub fn Beam::set_bc_slope(
  self : Beam,
  values : Array[BeamBoundaryValue],
) -> Unit {
  self.bc_slope_ = values.copy()
}

///|
pub fn Beam::set_bc_deflection(
  self : Beam,
  values : Array[BeamBoundaryValue],
) -> Unit {
  self.bc_deflection_ = values.copy()
}

///|
pub fn Beam::boundary_conditions(
  self : Beam,
) -> Map[String, Array[BeamBoundaryValue]] {
  let out : Map[String, Array[BeamBoundaryValue]] = {}
  out["shear_force"] = self.bc_shear_force_
  out["bending_moment"] = self.bc_bending_moment_
  out["slope"] = self.bc_slope_
  out["deflection"] = self.bc_deflection_
  out
}

///|
pub fn Beam::applied_loads(self : Beam) -> Array[BeamLoadSpec] {
  self.applied_loads_
}

///|
pub fn Beam::load(self : Beam) -> @symcore.Expr {
  self.load_
}

///|
pub fn Beam::reaction_loads(self : Beam) -> Map[String, @symcore.Expr] {
  self.reaction_loads_
}

///|
pub fn Beam::apply_load(
  self : Beam,
  value : @symcore.Expr,
  start : @symcore.Expr,
  order : Int,
  end? : @symcore.Expr? = None,
) -> Unit raise BeamError {
  self.applied_loads_.push((value, start, order, end))
  self.load_ = self.load_ + value * cm_singularity(self.variable_, start, order)
  match end {
    Some(stop) => {
      let terms = beam_end_terms(value, start, order, stop, self.variable_)
      for term in terms {
        self.load_ = self.load_ - term
      }
    }
    None => ()
  }
}

///|
pub fn Beam::remove_load(
  self : Beam,
  value : @symcore.Expr,
  start : @symcore.Expr,
  order : Int,
  end? : @symcore.Expr? = None,
) -> Unit raise BeamError {
  let kept : Array[BeamLoadSpec] = []
  let mut removed = false
  for item in self.applied_loads_ {
    if !removed && item == (value, start, order, end) {
      removed = true
    } else {
      kept.push(item)
    }
  }
  guard removed else {
    raise BeamError::ValueError("no such load distribution exists on the beam")
  }
  self.applied_loads_ = []
  self.load_ = @symcore.int(0)
  for item in kept {
    self.apply_load(item.0, item.1, item.2, end=item.3)
  }
}

///|
pub fn Beam::apply_support(
  self : Beam,
  loc : @symcore.Expr,
  kind? : String = "fixed",
) -> Array[@symcore.Expr] raise BeamError {
  guard kind == "fixed" || kind == "pin" || kind == "roller" else {
    raise BeamError::ValueError("support type must be fixed, pin, or roller")
  }
  let force = beam_support_symbol(loc, "R_")
  self.applied_support_symbols_.push(force)
  self.apply_load(force, loc, -1)
  self.bc_deflection_.push((loc, @symcore.int(0)))
  if kind == "fixed" {
    let moment = beam_support_symbol(loc, "M_")
    self.applied_support_symbols_.push(moment)
    self.apply_load(moment, loc, -2)
    self.bc_slope_.push((loc, @symcore.int(0)))
    [force, moment]
  } else {
    [force]
  }
}

///|
pub fn Beam::shear_force(self : Beam) -> @symcore.Expr {
  @symcore.int(-1) * cm_integrate(self.load_, beam_var_name(self))
}

///|
pub fn Beam::bending_moment(self : Beam) -> @symcore.Expr {
  cm_integrate(self.shear_force(), beam_var_name(self))
}

///|
pub fn Beam::slope(self : Beam) -> @symcore.Expr raise BeamError {
  let slope_curve = beam_slope_curve(self, self.base_char_ + "3")
  let deflection_curve = beam_deflection_curve(
    self,
    slope_curve,
    self.base_char_ + "4",
  )
  let maybe_solution = beam_solve_constant_system(
    self,
    slope_curve,
    deflection_curve,
    !self.bc_slope_.is_empty(),
    self.bc_slope_.is_empty() && !self.bc_deflection_.is_empty(),
  )
  match maybe_solution {
    Some(solution) => cm_simplify(beam_substitute_map(slope_curve, solution))
    None => cm_simplify(slope_curve)
  }
}

///|
pub fn Beam::deflection(self : Beam) -> @symcore.Expr raise BeamError {
  let slope_curve = beam_slope_curve(self, self.base_char_ + "3")
  let deflection_curve = beam_deflection_curve(
    self,
    slope_curve,
    self.base_char_ + "4",
  )
  let maybe_solution = beam_solve_constant_system(
    self,
    slope_curve,
    deflection_curve,
    !self.bc_slope_.is_empty(),
    !self.bc_deflection_.is_empty(),
  )
  match maybe_solution {
    Some(solution) =>
      cm_simplify(beam_substitute_map(deflection_curve, solution))
    None => cm_simplify(deflection_curve)
  }
}

///|
pub fn Beam::shear_stress(self : Beam) -> @symcore.Expr {
  self.shear_force() * (self.area_ ^ @symcore.int(-1))
}

///|
pub fn Beam::solve_for_reaction_loads(
  self : Beam,
  reactions? : Array[@symcore.Expr] = [],
) -> Unit raise BeamError {
  let all_reactions = beam_unique_exprs(
    reactions + self.applied_support_symbols_,
  )
  let c3 = @symcore.symbol("C3")
  let c4 = @symcore.symbol("C4")
  let var_name = beam_var_name(self)
  let shear_curve = cm_right_limit_at(
    self.shear_force(),
    var_name,
    self.length_,
  )
  let moment_curve = cm_right_limit_at(
    self.bending_moment(),
    var_name,
    self.length_,
  )
  let slope_curve = cm_integrate(self.bending_moment(), var_name) + c3
  let deflection_curve = cm_integrate(slope_curve, var_name) + c4
  let equations : Array[@symcore.Expr] = [shear_curve, moment_curve]
  for item in self.bc_shear_force_ {
    equations.push(cm_eval_at(self.shear_force(), var_name, item.0) - item.1)
  }
  for item in self.bc_bending_moment_ {
    equations.push(cm_eval_at(self.bending_moment(), var_name, item.0) - item.1)
  }
  for item in self.bc_slope_ {
    equations.push(cm_eval_at(slope_curve, var_name, item.0) - item.1)
  }
  for item in self.bc_deflection_ {
    equations.push(cm_eval_at(deflection_curve, var_name, item.0) - item.1)
  }
  let unknowns = [c3, c4] + all_reactions
  let maybe_solution = try? cm_linear_solve(equations, unknowns)
  match maybe_solution {
    Ok(Some(solution)) => {
      self.reaction_loads_ = {}
      for reaction in all_reactions {
        match reaction {
          @symcore.Expr::Symbol(name) =>
            self.reaction_loads_[name] = cm_simplify(
              solution.get(name).unwrap_or(@symcore.int(0)),
            )
          _ => ()
        }
      }
      self.load_ = beam_substitute_map(self.load_, solution)
    }
    _ => raise BeamError::SolveError("unable to solve beam reactions")
  }
}
