///|
pub struct RootOf {
  poly : Poly
  index : Int
}

///|
/// Construct a symbolic complex root object `CRootOf(poly, index)`.
pub fn rootof(poly : Poly, index : Int) -> RootOf {
  RootOf::{ poly, index }
}

///|
/// Render this symbolic root in `CRootOf(poly, index)` form.
pub fn RootOf::to_string(self : RootOf) -> String {
  let expr_str = @symprint.to_string(self.poly.to_expr())
  "CRootOf(\{expr_str}, \{self.index})"
}

///|
pub impl Show for RootOf with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
