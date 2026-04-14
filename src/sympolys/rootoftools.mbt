///|
/// Symbolic root placeholders for irreducible factors.

///|
/// Symbolic complex root reference.
///
/// - Does: Stores a polynomial together with one root index.
/// - Input: Structured fields managed through `rootof`.
/// - Returns: A `RootOf`.
/// - Limits: This type is symbolic only; it does not isolate or approximate the
///   root on its own.
pub struct RootOf {
  poly : Poly
  index : Int
}

///|
/// Construct a symbolic complex root object.
///
/// - Does: Builds a `CRootOf(poly, index)` placeholder.
/// - Input: One `Poly` and one zero-based root index.
/// - Returns: A `RootOf`.
/// - Limits: Index validity is not checked at construction time.
pub fn rootof(poly : Poly, index : Int) -> RootOf {
  RootOf::{ poly, index }
}

///|
/// Render this symbolic root in `CRootOf(poly, index)` form.
pub impl Show for RootOf with to_string(self) -> String {
  let expr_str = @symprint.to_string(self.poly.to_expr())
  "CRootOf(\{expr_str}, \{self.index})"
}

///|
pub impl Show for RootOf with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
