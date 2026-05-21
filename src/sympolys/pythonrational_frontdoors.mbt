///|
/// Compatibility front doors for small scalar/domain helpers.

///|
/// Convert a PythonRational-like pair to a symbolic rational.
///
/// - Does: Mirrors `sympify_pythonrational` by building an exact rational
///   expression from numerator and denominator fields.
/// - Input: Integer numerator and denominator.
/// - Returns: An `Expr::Number` rational.
/// - Limits: Raises `PolyError::DivisionByZero` for a zero denominator; the
///   Python object protocol is represented by explicit scalar fields.
pub fn sympify_pythonrational(num : Int, den : Int) -> Expr raise PolyError {
  expr_from_rational(poly_rational_from_ints(num, den))
}

///|
/// Line-wrap a polynomial expression string.
///
/// - Does: Replaces a space by a newline when the current column is already
///   wider than `width`.
/// - Input: Text and an optional column width.
/// - Returns: Wrapped text.
/// - Limits: Matches the source helper's simple space-only wrapping; it does
///   not perform word reflow or account for display width.
pub fn wrap(text : String, width? : Int = 80) -> String {
  let mut out = ""
  let mut col = 0
  for c in text {
    let piece = if c == ' ' && col > width {
      col = 0
      "\n"
    } else {
      col = col + 1
      c.to_string()
    }
    out = out + piece
  }
  out
}
