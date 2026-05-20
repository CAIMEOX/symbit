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
/// Alias for the complex-root placeholder type.
pub type CRootOf = RootOf

///|
/// Alias for the complex-root placeholder type.
pub type ComplexRootOf = RootOf

///|
/// Symbolic root-sum placeholder.
///
/// - Does: Stores a polynomial and optional lambda-like expression payload.
/// - Input: A polynomial plus an optional expression.
/// - Returns: A `RootSum`.
/// - Limits: This is symbolic only and does not expand into explicit roots.
pub struct RootSum {
  poly : Poly
  func : Expr?
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
/// Construct a symbolic root sum object.
///
/// - Does: Builds a `RootSum(poly, func)` placeholder.
/// - Input: One `Poly` and optional expression payload.
/// - Returns: A `RootSum`.
/// - Limits: No algebraic expansion is attempted.
pub fn root_sum(poly : Poly, func? : Expr) -> RootSum {
  RootSum::{ poly, func }
}

///|
/// Render this symbolic root in `CRootOf(poly, index)` form.

///|
/// Display implementation for `RootOf.to_string`.
///
/// - Does: Formats `RootOf` values for display.
/// - Input: the receiver value and MoonBit logger/display protocol arguments.
/// - Returns: the formatted display output required by the `Show` implementation.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub impl Show for RootOf with to_string(self) -> String {
  let expr_str = @symprint.pretty_string(self.poly.to_expr())
  "CRootOf(\{expr_str}, \{self.index})"
}

///|

///|
/// Display implementation for `RootOf.output`.
///
/// - Does: Formats `RootOf` values for display.
/// - Input: the receiver value and MoonBit logger/display protocol arguments.
/// - Returns: the formatted display output required by the `Show` implementation.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub impl Show for RootOf with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Show for RootSum with to_string(self) -> String {
  let expr_str = @symprint.pretty_string(self.poly.to_expr())
  match self.func {
    Some(func) => "RootSum(\{expr_str}, \{@symprint.pretty_string(func)})"
    None => "RootSum(\{expr_str})"
  }
}

///|
pub impl Show for RootSum with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
