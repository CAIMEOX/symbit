///|
pub struct RootOf {
  poly : Poly
  index : Int
}

///|
pub fn rootof(poly : Poly, index : Int) -> RootOf {
  RootOf::{ poly, index }
}

///|
pub fn RootOf::to_string(self : RootOf) -> String {
  let expr_str = @symprint.to_string(self.poly.to_expr())
  "CRootOf(\{expr_str}, \{self.index})"
}

///|
impl Show for RootOf with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
