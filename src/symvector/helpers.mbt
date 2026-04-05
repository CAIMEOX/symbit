///|
let coord_systems_by_frame : Map[Int, CoordSys3D] = {}

///|
let root_coord_system_cache : Map[String, CoordSys3D] = {}

///|
fn default_vector_names() -> Array[String] {
  ["i", "j", "k"]
}

///|
fn default_variable_names() -> Array[String] {
  ["x", "y", "z"]
}

///|
fn normalize_names(
  label : String,
  items : Array[String]?,
) -> Array[String] raise @rawvec.VectorError {
  match items {
    Some(values) =>
      if values.length() != 3 {
        abort(label + " must have length 3")
      } else {
        values
      }
    None =>
      if label == "vector_names" {
        default_vector_names()
      } else {
        default_variable_names()
      }
  }
}

///|
fn full_variable_names(
  name : String,
  variable_names : Array[String],
) -> Array[String] {
  [
    name + "." + variable_names[0],
    name + "." + variable_names[1],
    name + "." + variable_names[2],
  ]
}

///|
fn root_cache_key(
  name : String,
  vector_names : Array[String],
  variable_names : Array[String],
) -> String {
  "root|" + name + "|" + vector_names.join(",") + "|" + variable_names.join(",")
}

///|
fn child_cache_key(
  parent_key : String,
  rotation_key : String,
  location_key : String,
  vector_names : Array[String],
  variable_names : Array[String],
) -> String {
  "child|" +
  parent_key +
  "|" +
  rotation_key +
  "|" +
  location_key +
  "|" +
  vector_names.join(",") +
  "|" +
  variable_names.join(",")
}

///|
fn matrix_summary(matrix : @symphysics.ExplicitMatrix) -> String {
  let rows = matrix.rows_copy()
  rows.map(row => row.map(@symprint.to_string).join(",")).join("|")
}

///|
fn register_coord_system(system : CoordSys3D) -> Unit {
  if !coord_systems_by_frame.contains(system.frame_.index_) {
    coord_systems_by_frame[system.frame_.index_] = system
  }
}

///|
fn coord_system_from_frame(frame_id : Int) -> CoordSys3D {
  match coord_systems_by_frame.get(frame_id) {
    Some(system) => system
    None => abort("coord_system_from_frame")
  }
}

///|
fn point_wrapper(name : String, raw_point : @rawvec.Point) -> Point {
  { name_: name, raw_: raw_point }
}

///|
fn compare_coord_sys(lhs : CoordSys3D, rhs : CoordSys3D) -> Int {
  lhs.eq_key_.compare(rhs.eq_key_)
}

///|
fn all_coord_systems() -> Array[CoordSys3D] {
  let seen : Map[String, Bool] = {}
  let out : Array[CoordSys3D] = []
  for entry in coord_systems_by_frame {
    let system = entry.1
    if !seen.contains(system.eq_key_) {
      seen[system.eq_key_] = true
      out.push(system)
    }
  }
  out.sort_by(compare_coord_sys)
  out
}

///|
fn coord_systems_in_scalar_expr(expr : @symcore.Expr) -> Array[CoordSys3D] {
  let free = @symcore.free_symbols(expr)
  if free.is_empty() {
    return []
  }
  let symbol_names : Map[String, Bool] = {}
  for item in free {
    symbol_names[@symprint.to_string(item)] = true
  }
  let out : Array[CoordSys3D] = []
  for system in all_coord_systems() {
    if system
      .base_scalars()
      .any(fn(scalar) { symbol_names.contains(scalar.name_) }) {
      out.push(system)
    }
  }
  out
}

///|
fn coord_systems_in_vector(vector : Vector) -> Array[CoordSys3D] {
  let seen : Map[String, Bool] = {}
  let out : Array[CoordSys3D] = []
  for basis in vector.components().keys() {
    let system = basis.system_
    if !seen.contains(system.eq_key_) {
      seen[system.eq_key_] = true
      out.push(system)
    }
  }
  out.sort_by(compare_coord_sys)
  out
}

///|
fn primary_coord_system_in_vector(vector : Vector) -> CoordSys3D? {
  match coord_systems_in_vector(vector) {
    [] => None
    systems => Some(systems[0])
  }
}

///|
fn compare_base_vector(lhs : BaseVector, rhs : BaseVector) -> Int {
  let sys_cmp = compare_coord_sys(lhs.system_, rhs.system_)
  if sys_cmp != 0 {
    return sys_cmp
  }
  lhs.axis_ - rhs.axis_
}

///|
fn raw_basis(frame : @rawvec.ReferenceFrame, axis : Int) -> @rawvec.Vector {
  match axis {
    0 => frame.x()
    1 => frame.y()
    _ => frame.z()
  }
}

///|
fn scalar_with_basis(coeff : @symcore.Expr, basis : String) -> String {
  let txt = @symprint.to_string(coeff)
  if txt == "1" {
    basis
  } else if txt == "-1" {
    "-" + basis
  } else {
    txt + "*" + basis
  }
}

///|
fn join_signed(parts : Array[String]) -> String {
  if parts.is_empty() {
    return "0"
  }
  let mut out = parts[0]
  for part in parts[1:] {
    if part.has_prefix("-") {
      out = out + " - " + part[1:].to_string()
    } else {
      out = out + " + " + part
    }
  }
  out
}
