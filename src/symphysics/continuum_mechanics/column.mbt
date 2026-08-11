///|
/// Axially loaded column helper aligned with the core symbolic surface of
/// `sympy.physics.continuum_mechanics.column`.

///|
pub type ColumnLoadSpec = (@symcore.Expr, @symcore.Expr, Int, @symcore.Expr?)

///|
pub suberror ColumnError {
  ValueError(String)
  TypeError(String)
  SolveError(String)
} derive(Debug, Eq)

///|
pub struct Column {
  mut length_ : @symcore.Expr
  mut elastic_modulus_ : @symcore.Expr
  mut area_ : @symcore.Expr
  mut variable_ : @symcore.Expr
  base_char_ : String
  mut bc_extension_ : Array[@symcore.Expr]
  mut bc_hinge_ : Array[@symcore.Expr]
  mut applied_supports_ : Array[@symcore.Expr]
  mut applied_hinges_ : Array[@symcore.Expr]
  mut applied_loads_ : Array[ColumnLoadSpec]
  mut load_ : @symcore.Expr
  mut reaction_loads_ : Map[String, @symcore.Expr]
  mut hinge_extensions_ : Map[String, @symcore.Expr]
  mut integration_constants_ : Map[String, @symcore.Expr]
  mut is_solved_ : Bool
}

///|
pub fn column(
  length : @symcore.Expr,
  elastic_modulus : @symcore.Expr,
  area : @symcore.Expr,
  variable? : @symcore.Expr = Symbol("x"),
  base_char? : String = "C",
) -> Column raise ColumnError {
  guard variable is Symbol(_) else {
    raise TypeError("column variable should be a symbol")
  }
  {
    length_: length,
    elastic_modulus_: elastic_modulus,
    area_: area,
    variable_: variable,
    base_char_: base_char,
    bc_extension_: [],
    bc_hinge_: [],
    applied_supports_: [],
    applied_hinges_: [],
    applied_loads_: [],
    load_: @symcore.int(0),
    reaction_loads_: {},
    hinge_extensions_: {},
    integration_constants_: {},
    is_solved_: false,
  }
}

///|
fn column_var_name(column : Column) -> String {
  match column.variable_ {
    Symbol(name) => name
    _ => "x"
  }
}

///|
fn column_support_symbol(loc : @symcore.Expr) -> @symcore.Expr {
  Symbol("R_" + @symprint.pretty_string(loc))
}

///|
fn column_hinge_symbol(loc : @symcore.Expr) -> @symcore.Expr {
  Symbol("u_" + @symprint.pretty_string(loc))
}

///|
pub fn Column::length(self : Column) -> @symcore.Expr {
  self.length_
}

///|
pub fn Column::elastic_modulus(self : Column) -> @symcore.Expr {
  self.elastic_modulus_
}

///|
pub fn Column::area(self : Column) -> @symcore.Expr {
  self.area_
}

///|
pub fn Column::variable(self : Column) -> @symcore.Expr {
  self.variable_
}

///|
pub fn Column::set_length(self : Column, value : @symcore.Expr) -> Unit {
  self.length_ = value
}

///|
pub fn Column::set_elastic_modulus(
  self : Column,
  value : @symcore.Expr,
) -> Unit {
  self.elastic_modulus_ = value
}

///|
pub fn Column::set_area(self : Column, value : @symcore.Expr) -> Unit {
  self.area_ = value
}

///|
pub fn Column::set_variable(
  self : Column,
  value : @symcore.Expr,
) -> Unit raise ColumnError {
  guard value is Symbol(_) else {
    raise TypeError("column variable should be a symbol")
  }
  self.variable_ = value
}

///|
pub fn Column::bc_extension(self : Column) -> Array[@symcore.Expr] {
  self.bc_extension_
}

///|
pub fn Column::bc_hinge(self : Column) -> Array[@symcore.Expr] {
  self.bc_hinge_
}

///|
pub fn Column::applied_loads(self : Column) -> Array[ColumnLoadSpec] {
  self.applied_loads_
}

///|
pub fn Column::load(self : Column) -> @symcore.Expr {
  self.load_
}

///|
pub fn Column::reaction_loads(self : Column) -> Map[String, @symcore.Expr] {
  self.reaction_loads_
}

///|
pub fn Column::hinge_extensions(self : Column) -> Map[String, @symcore.Expr] {
  self.hinge_extensions_
}

///|
pub fn Column::apply_support(
  self : Column,
  loc : @symcore.Expr,
) -> @symcore.Expr raise ColumnError {
  guard !self.bc_extension_.any(item => cm_expr_eq(item, loc)) else {
    raise ValueError("there is already a support at this location")
  }
  let reaction = column_support_symbol(loc)
  self.applied_supports_.push(reaction)
  self.bc_extension_.push(loc)
  self.load_ = self.load_ + reaction * cm_singularity(self.variable_, loc, -1)
  reaction
}

///|
pub fn Column::apply_load(
  self : Column,
  value : @symcore.Expr,
  start : @symcore.Expr,
  order : Int,
  end? : @symcore.Expr? = None,
) -> Unit raise ColumnError {
  self.applied_loads_.push((value, start, order, end))
  self.load_ = self.load_ + value * cm_singularity(self.variable_, start, order)
  match end {
    Some(stop) => {
      let terms = beam_end_terms(value, start, order, stop, self.variable_) catch {
        ValueError(message) => raise ValueError(message)
        TypeError(message) => raise TypeError(message)
        SolveError(message) => raise SolveError(message)
      }
      let start_before_end = cm_sign_of_difference(start, stop)
        .map(s => s <= 0)
        .unwrap_or(true)
      for term in terms {
        self.load_ = if start_before_end {
          self.load_ - term
        } else {
          self.load_ + term
        }
      }
    }
    None => ()
  }
}

///|
pub fn Column::remove_load(
  self : Column,
  value : @symcore.Expr,
  start : @symcore.Expr,
  order : Int,
  end? : @symcore.Expr? = None,
) -> Unit raise ColumnError {
  let mut found = false
  let kept : Array[ColumnLoadSpec] = []
  for item in self.applied_loads_ {
    if !found && item == (value, start, order, end) {
      found = true
    } else {
      kept.push(item)
    }
  }
  guard found else {
    raise ValueError("no such load distribution exists on the column")
  }
  self.applied_loads_ = kept
  self.load_ = @symcore.int(0)
  for reaction, value in self.reaction_loads_ {
    let _ = reaction
    let _ = value
  }
  self.reaction_loads_ = {}
  self.hinge_extensions_ = {}
  self.integration_constants_ = {}
  self.is_solved_ = false
  let supports = self.applied_supports_.copy()
  let hinges = self.applied_hinges_.copy()
  self.applied_supports_ = []
  self.applied_hinges_ = []
  let bcs_ext = self.bc_extension_.copy()
  let bcs_hinge = self.bc_hinge_.copy()
  self.bc_extension_ = []
  self.bc_hinge_ = []
  for item in kept {
    self.apply_load(item.0, item.1, item.2, end=item.3)
  }
  self.applied_supports_ = supports
  self.applied_hinges_ = hinges
  self.bc_extension_ = bcs_ext
  self.bc_hinge_ = bcs_hinge
}

///|
pub fn Column::apply_telescope_hinge(
  self : Column,
  loc : @symcore.Expr,
) -> @symcore.Expr {
  let extension = column_hinge_symbol(loc)
  self.bc_hinge_.push(loc)
  self.applied_hinges_.push(extension)
  self.load_ = self.load_ +
    self.elastic_modulus_ *
    self.area_ *
    extension *
    cm_singularity(self.variable_, loc, -2)
  extension
}

///|
fn column_solved_load(column : Column) -> @symcore.Expr {
  let mut expr = column.load_
  expr = @symcore.subst(expr, column.reaction_loads_)
  @symcore.subst(expr, column.hinge_extensions_)
}

///|
pub fn Column::solve_for_reaction_loads(
  self : Column,
  reactions? : Array[@symcore.Expr] = [],
) -> Unit raise ColumnError {
  let qx = self.load_
  let x_name = column_var_name(self)
  let c_n = @symcore.Expr::Symbol("C_N")
  let c_u = @symcore.Expr::Symbol("C_u")
  let applied_supports = beam_unique_exprs(reactions + self.applied_supports_)
  let axial_force = @symcore.int(-1) * cm_integrate(qx, x_name) + c_n
  let extension = @symcore.int(-1) *
    cm_integrate(cm_integrate(qx, x_name), x_name) *
    ((self.elastic_modulus_ * self.area_) ^ @symcore.int(-1)) +
    c_n * self.variable_ +
    c_u
  let eqs : Array[@symcore.Expr] = [
    cm_left_limit_at(axial_force, x_name, @symcore.int(0)),
    cm_right_limit_at(axial_force, x_name, self.length_),
  ]
  let ea = self.elastic_modulus_ * self.area_
  for loc in self.bc_extension_ {
    eqs.push(cm_simplify(cm_eval_at(extension, x_name, loc) * ea))
  }
  for loc in self.bc_hinge_ {
    eqs.push(cm_right_limit_at(axial_force, x_name, loc))
  }
  let unknowns = applied_supports + self.applied_hinges_ + [c_n, c_u]
  try cm_linear_solve(eqs, unknowns) catch {
    _ => raise SolveError("unable to solve column reactions")
  } noraise {
    result =>
      match result {
        Some(solution) => {
          self.reaction_loads_ = {}
          for reaction in applied_supports {
            match reaction {
              Symbol(name) =>
                self.reaction_loads_[name] = cm_simplify(
                  solution.get(name).unwrap_or(@symcore.int(0)),
                )
              _ => ()
            }
          }
          self.hinge_extensions_ = {}
          for hinge in self.applied_hinges_ {
            match hinge {
              Symbol(name) =>
                self.hinge_extensions_[name] = cm_simplify(
                  solution.get(name).unwrap_or(@symcore.int(0)),
                )
              _ => ()
            }
          }
          self.integration_constants_ = {}
          self.integration_constants_["C_N"] = cm_simplify(
            solution.get("C_N").unwrap_or(@symcore.int(0)),
          )
          self.integration_constants_["C_u"] = cm_simplify(
            solution.get("C_u").unwrap_or(@symcore.int(0)),
          )
          self.is_solved_ = true
        }
        None => raise SolveError("unable to solve column reactions")
      }
  }
}

///|
pub fn Column::axial_force(self : Column) -> @symcore.Expr {
  let load_expr = if self.is_solved_ {
    column_solved_load(self)
  } else {
    self.load_
  }
  let c_n = self.integration_constants_.get("C_N").unwrap_or(Symbol("C_N"))
  @symcore.int(-1) * cm_integrate(load_expr, column_var_name(self)) + c_n
}

///|
pub fn Column::extension(self : Column) -> @symcore.Expr {
  let load_expr = if self.is_solved_ {
    column_solved_load(self)
  } else {
    self.load_
  }
  let c_n = self.integration_constants_.get("C_N").unwrap_or(Symbol("C_N"))
  let c_u = self.integration_constants_.get("C_u").unwrap_or(Symbol("C_u"))
  @symcore.int(-1) *
  cm_integrate(
    cm_integrate(load_expr, column_var_name(self)),
    column_var_name(self),
  ) *
  ((self.elastic_modulus_ * self.area_) ^ @symcore.int(-1)) +
  c_n * self.variable_ +
  c_u
}
