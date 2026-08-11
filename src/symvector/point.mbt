///|
pub fn Point::name(self : Point) -> String {
  self.name_
}

///|
pub fn Point::locate_new(
  self : Point,
  name : String,
  position : Vector,
) -> Point raise @rawvec.VectorError {
  point_wrapper(name, self.raw_.locatenew(name, position.raw_))
}

///|
pub fn Point::position_wrt(
  self : Point,
  other : PointReference,
) -> Vector raise @rawvec.VectorError {
  let raw_other = match other {
    PointObject(point) => point.raw_
    CoordSystem(system) => system.origin_.raw_
  }
  { raw_: self.raw_.pos_from(raw_other) }
}

///|
pub fn Point::express_coordinates(
  self : Point,
  system : CoordSys3D,
) -> Array[@symcore.Expr] raise @rawvec.VectorError {
  let position = self.position_wrt(CoordSystem(system)) catch {
    err => raise err
  }
  let matrix = position.to_matrix(system) catch { err => raise err }
  let rows = matrix.rows_copy()
  [rows[0][0], rows[1][0], rows[2][0]]
}
