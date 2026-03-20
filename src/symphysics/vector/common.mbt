///|
/// Shared helpers for `sympy.physics.vector` style frame/vector algebra.

///|
pub type CoordinateSym = Expr

///|
pub enum AxisName {
  X
  Y
  Z
} derive(Eq, Show)

///|
pub enum OrientationSpec {
  AxisSpec(Expr, Vector)
  DcmSpec(@symphysics.ExplicitMatrix)
  BodySpec(Array[Expr], String)
  SpaceSpec(Array[Expr], String)
  QuaternionSpec(Expr, Expr, Expr, Expr)
}

///|
pub suberror VectorError {
  ValueError(String)
  TypeError(String)
} derive(Show, Eq)

///|
priv struct FrameState {
  dcm_dict : Map[Int, @symphysics.ExplicitMatrix]
  mut dcm_cache : Map[Int, @symphysics.ExplicitMatrix]
  ang_vel_dict : Map[Int, Vector]
  ang_acc_dict : Map[Int, Vector]
}

///|
priv struct PointState {
  pos_dict : Map[Int, Vector]
  vel_dict : Map[Int, Vector]
  acc_dict : Map[Int, Vector]
}

///|
pub struct Point {
  name_ : String
  index_ : Int
}

///|
pub struct ReferenceFrame {
  name_ : String
  index_ : Int
  indices_ : Array[String]
  latexs_ : Array[String]
  variables_ : Array[String]
}

///|
pub struct Vector {
  args : Array[(Int, Array[Expr])]
}

///|
pub struct Dyadic {
  args : Array[(Expr, Int, Int, Int, Int)]
}

///|
pub let dynamicsymbols_t : Expr = symbol("t")

///|
let vector_frame_registry : Array[ReferenceFrame] = []

///|
let vector_frame_states : Array[FrameState] = []

///|
let vector_coordinate_registry : Map[String, (Int, Int)] = {}

///|
let vector_point_registry : Array[Point] = []

///|
let vector_point_states : Array[PointState] = []

///|
fn zero_expr() -> Expr {
  int(0)
}

///|
fn one_expr() -> Expr {
  int(1)
}

///|
fn neg_one_expr() -> Expr {
  int(-1)
}

///|
fn int_expr(value : Int) -> Expr {
  int(value)
}

///|
fn simplify_expr(expr : Expr) -> Expr {
  @symsimplify.ratsimp(@symsimplify.simplify(expr, max_passes=6), max_passes=4)
}

///|
fn expr_is_zero(expr : Expr) -> Bool {
  match simplify_expr(expr) {
    Expr::Number(n) => n.is_zero()
    _ => false
  }
}

///|
fn expr_neg(expr : Expr) -> Expr {
  neg_one_expr() * expr
}

///|
fn expr_eq(lhs : Expr, rhs : Expr) -> Bool {
  expr_is_zero(lhs - rhs)
}

///|
fn clone_expr_array(items : Array[Expr]) -> Array[Expr] {
  let out : Array[Expr] = []
  for item in items {
    out.push(item)
  }
  out
}

///|
fn zero_components() -> Array[Expr] {
  [zero_expr(), zero_expr(), zero_expr()]
}

///|
fn basis_components(axis : Int) -> Array[Expr] {
  match axis {
    0 => [one_expr(), zero_expr(), zero_expr()]
    1 => [zero_expr(), one_expr(), zero_expr()]
    _ => [zero_expr(), zero_expr(), one_expr()]
  }
}

///|
fn components_add(
  lhs : Array[Expr],
  rhs : Array[Expr],
) -> Array[Expr] {
  [lhs[0] + rhs[0], lhs[1] + rhs[1], lhs[2] + rhs[2]]
}

///|
fn components_scale(
  scalar : Expr,
  comps : Array[Expr],
) -> Array[Expr] {
  [scalar * comps[0], scalar * comps[1], scalar * comps[2]]
}

///|
fn components_dot(
  lhs : Array[Expr],
  rhs : Array[Expr],
) -> Expr {
  lhs[0] * rhs[0] + lhs[1] * rhs[1] + lhs[2] * rhs[2]
}

///|
fn components_cross(
  lhs : Array[Expr],
  rhs : Array[Expr],
) -> Array[Expr] {
  [
    lhs[1] * rhs[2] - lhs[2] * rhs[1],
    lhs[2] * rhs[0] - lhs[0] * rhs[2],
    lhs[0] * rhs[1] - lhs[1] * rhs[0],
  ]
}

///|
fn components_norm_sq(comps : Array[Expr]) -> Expr {
  components_dot(comps, comps)
}

///|
fn matrix_from_rows(
  rows : Array[Array[Expr]],
) -> @symphysics.ExplicitMatrix {
  let normalized : Array[Array[Expr]] = []
  for row in rows {
    let next : Array[Expr] = []
    for value in row {
      next.push(simplify_expr(value))
    }
    normalized.push(next)
  }
  @symphysics.explicit_matrix_from_rows(normalized) catch {
    _ => @symphysics.explicit_matrix_from_ints([])
  }
}

///|
fn matrix_column(
  matrix : @symphysics.ExplicitMatrix,
  col : Int,
) -> Array[Expr] {
  let rows = matrix.rows_copy()
  let a = rows[0][col]
  let b = rows[1][col]
  let c = rows[2][col]
  [a, b, c]
}

///|
fn matrix_mul_vec(
  matrix : @symphysics.ExplicitMatrix,
  vec : Array[Expr],
) -> Array[Expr] {
  let rows = matrix.rows_copy()
  let a00 = rows[0][0]
  let a01 = rows[0][1]
  let a02 = rows[0][2]
  let a10 = rows[1][0]
  let a11 = rows[1][1]
  let a12 = rows[1][2]
  let a20 = rows[2][0]
  let a21 = rows[2][1]
  let a22 = rows[2][2]
  [
    a00 * vec[0] + a01 * vec[1] + a02 * vec[2],
    a10 * vec[0] + a11 * vec[1] + a12 * vec[2],
    a20 * vec[0] + a21 * vec[1] + a22 * vec[2],
  ]
}

///|
fn rotation_matrix(
  axis : Int,
  angle : Expr,
) -> @symphysics.ExplicitMatrix {
  let c = @symelem.cos(angle)
  let s = @symelem.sin(angle)
  match axis {
    0 =>
      matrix_from_rows([
        [one_expr(), zero_expr(), zero_expr()],
        [zero_expr(), c, expr_neg(s)],
        [zero_expr(), s, c],
      ])
    1 =>
      matrix_from_rows([
        [c, zero_expr(), s],
        [zero_expr(), one_expr(), zero_expr()],
        [expr_neg(s), zero_expr(), c],
      ])
    _ =>
      matrix_from_rows([
        [c, expr_neg(s), zero_expr()],
        [s, c, zero_expr()],
        [zero_expr(), zero_expr(), one_expr()],
      ])
  }
}

///|
fn rotation_matrix_about_axis(
  axis : Array[Expr],
  angle : Expr,
) -> @symphysics.ExplicitMatrix {
  let u0 = axis[0]
  let u1 = axis[1]
  let u2 = axis[2]
  let c = @symelem.cos(angle)
  let s = @symelem.sin(angle)
  let omc = one_expr() - c
  matrix_from_rows([
    [c + u0 * u0 * omc, u0 * u1 * omc - u2 * s, u0 * u2 * omc + u1 * s],
    [u1 * u0 * omc + u2 * s, c + u1 * u1 * omc, u1 * u2 * omc - u0 * s],
    [u2 * u0 * omc - u1 * s, u2 * u1 * omc + u0 * s, c + u2 * u2 * omc],
  ])
}

///|
fn frame_registry_get(index : Int) -> ReferenceFrame {
  vector_frame_registry[index - 1]
}

///|
fn clear_frame_caches() -> Unit {
  for i in 0..<vector_frame_states.length() {
    vector_frame_states[i].dcm_cache = {}
  }
}

///|
fn coordinate_symbol_name(frame : ReferenceFrame, axis : Int) -> String {
  frame.variables_[axis]
}

///|
fn coordinate_symbol(frame : ReferenceFrame, axis : Int) -> CoordinateSym {
  symbol(coordinate_symbol_name(frame, axis))
}

///|
fn dynamicsymbol_single(name : String, level : Int) -> Expr {
  let base = @symcore.function(name, [dynamicsymbols_t])
  if level <= 0 {
    base
  } else {
    let args : Array[Expr] = [base]
    for _ in 0..<level {
      args.push(dynamicsymbols_t)
    }
    @symcore.raw_function("Derivative", args)
  }
}

///|
fn tokenize_dynamicsymbols(names : String) -> Array[String] {
  let normalized = names.replace(old=",", new=" ")
  let out : Array[String] = []
  for piece in normalized.split(" ") {
    let token = piece.trim().to_string()
    if token != "" {
      out.push(token)
    }
  }
  out
}

///|
fn expand_dynamicsymbol_token(token : String) -> Array[String] {
  let parts = token.split(":").to_array()
  if parts.length() != 2 {
    return [token]
  }
  let start_s = parts[0].to_string()
  let end_s = parts[1].to_string()
  let mut digit_start = start_s.length()
  for i in 0..<start_s.length() {
    let ch = start_s[i]
    if ch >= '0' && ch <= '9' {
      digit_start = i
      break
    }
  }
  if digit_start == start_s.length() {
    return [token]
  }
  let prefix = start_s[:digit_start].to_string()
  let start_num = @strconv.parse_int(start_s[digit_start:].to_string(), base=10) catch {
    _ => return [token]
  }
  let end_num = @strconv.parse_int(end_s, base=10) catch { _ => return [token] }
  let out : Array[String] = []
  for value in start_num..<end_num {
    out.push(prefix + value.to_string())
  }
  out
}

///|
fn collect_symbol_names(expr : Expr, seen : Map[String, Bool]) -> Unit {
  match expr {
    Expr::Symbol(name) => seen.set(name, true)
    Expr::Add(args)
    | Expr::Mul(args)
    | Expr::Function(_, args) =>
      for arg in args {
        collect_symbol_names(arg, seen)
      }
    Expr::Pow(base, exp) => {
      collect_symbol_names(base, seen)
      collect_symbol_names(exp, seen)
    }
    _ => ()
  }
}

///|
fn point_registry_get(index : Int) -> Point {
  vector_point_registry[index - 1]
}

///|
pub fn orient_axis(angle : Expr, axis : Vector) -> OrientationSpec {
  AxisSpec(angle, axis)
}

///|
pub fn orient_dcm(matrix : @symphysics.ExplicitMatrix) -> OrientationSpec {
  DcmSpec(matrix)
}

///|
pub fn orient_body(
  angles : Array[Expr],
  order : String,
) -> OrientationSpec {
  BodySpec(angles, order)
}

///|
pub fn orient_space(
  angles : Array[Expr],
  order : String,
) -> OrientationSpec {
  SpaceSpec(angles, order)
}

///|
pub fn orient_quaternion(
  q0 : Expr,
  q1 : Expr,
  q2 : Expr,
  q3 : Expr,
) -> OrientationSpec {
  QuaternionSpec(q0, q1, q2, q3)
}
