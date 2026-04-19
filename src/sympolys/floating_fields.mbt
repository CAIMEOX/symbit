///|
fn field_default_precision(precision : Int) -> Int {
  if precision > 0 {
    precision
  } else {
    53
  }
}

///|
fn field_float_expr_from_exact(
  value : @symnum.BigRational,
  precision : Int,
) -> Expr {
  @symcore.Expr::Float(
    @symcore.Float::from_exact(value, prec=precision) catch {
      _ => @symcore.Float::from_mpf(@symnum.fnan, prec=precision)
    },
  )
}

///|
fn complex_float_expr_from_gaussian(
  value : GaussianRatCompat,
  precision : Int,
) -> Expr {
  if value.im.is_zero() {
    field_float_expr_from_exact(value.re, precision)
  } else {
    @symcore.Expr::ComplexFloat(
      @symcore.ComplexFloat::from_exact_parts(
        value.re,
        value.im,
        prec=precision,
      ),
    )
  }
}

///|
/// Floating-field compatibility front doors.
///
/// Current Limits:
/// - these wrappers model approximate real and complex coefficient domains only.
/// - arithmetic stays within the current `Expr::Float` and `Expr::ComplexFloat`
///   compatibility surface.

///|
/// Approximate real coefficient field descriptor.
///
/// - Does: Stores the target working precision for approximate real arithmetic.
/// - Input: Constructed from a positive precision or the default precision.
/// - Returns: A `RealField`.
/// - Limits: This is a field descriptor, not a container of coefficients.
pub struct RealField {
  precision : Int
} derive(Eq, Debug)

///|
/// Approximate complex coefficient field descriptor.
///
/// - Does: Stores the target working precision for approximate complex
///   arithmetic.
/// - Input: Constructed from a positive precision or the default precision.
/// - Returns: A `ComplexField`.
/// - Limits: This is a field descriptor, not a container of coefficients.
pub struct ComplexField {
  precision : Int
} derive(Eq, Debug)

///|
/// Build an approximate real field descriptor.
///
/// - Does: Creates a `RealField` with normalized precision.
/// - Input: Optional precision `Int`.
/// - Returns: A `RealField`.
/// - Limits: Non-positive precision falls back to the default precision.
pub fn RealField::new(precision? : Int = 53) -> RealField {
  { precision: field_default_precision(precision) }
}

///|
/// Build an approximate complex field descriptor.
///
/// - Does: Creates a `ComplexField` with normalized precision.
/// - Input: Optional precision `Int`.
/// - Returns: A `ComplexField`.
/// - Limits: Non-positive precision falls back to the default precision.
pub fn ComplexField::new(precision? : Int = 53) -> ComplexField {
  { precision: field_default_precision(precision) }
}

///|
/// Return the working precision.
///
/// - Does: Exposes the precision stored in the field descriptor.
/// - Input: A `RealField`.
/// - Returns: An `Int`.
/// - Limits: This is metadata only.
pub fn RealField::precision(self : RealField) -> Int {
  self.precision
}

///|
/// Return the working precision.
///
/// - Does: Exposes the precision stored in the field descriptor.
/// - Input: A `ComplexField`.
/// - Returns: An `Int`.
/// - Limits: This is metadata only.
pub fn ComplexField::precision(self : ComplexField) -> Int {
  self.precision
}

///|
/// Return the corresponding domain descriptor.
///
/// - Does: Maps the field wrapper to `Domain::RR`.
/// - Input: A `RealField`.
/// - Returns: A `Domain`.
/// - Limits: This is a structural descriptor only.
pub fn RealField::domain(self : RealField) -> Domain {
  ignore(self)
  Domain::RR
}

///|
/// Return the corresponding domain descriptor.
///
/// - Does: Maps the field wrapper to `Domain::CC`.
/// - Input: A `ComplexField`.
/// - Returns: A `Domain`.
/// - Limits: This is a structural descriptor only.
pub fn ComplexField::domain(self : ComplexField) -> Domain {
  ignore(self)
  Domain::CC
}

///|

///|
/// Public API `RealField.contains_expr`.
///
/// - Does: Provides the `RealField.contains_expr` operation for approximate real and complex fields.
/// - Input: parameters `self : RealField`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn RealField::contains_expr(self : RealField, expr : Expr) -> Bool {
  ignore(self)
  Domain::RR.contains_expr(expr)
}

///|

///|
/// Public API `ComplexField.contains_expr`.
///
/// - Does: Provides the `ComplexField.contains_expr` operation for approximate real and complex fields.
/// - Input: parameters `self : ComplexField`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn ComplexField::contains_expr(self : ComplexField, expr : Expr) -> Bool {
  ignore(self)
  Domain::CC.contains_expr(expr)
}

///|
/// Evaluate an expression into the approximate real field.
///
/// - Does: Runs the package evalf path at the field precision.
/// - Input: A `RealField` and `Expr`.
/// - Returns: An approximate `Expr`.
/// - Limits: Raises `PolyError` when the expression cannot be evaluated in the
///   real field.
pub fn RealField::evalf_expr(
  self : RealField,
  expr : Expr,
) -> Expr raise PolyError {
  domain_evalf_expr(Domain::RR, expr, prec=Some(self.precision))
}

///|
/// Evaluate an expression into the approximate complex field.
///
/// - Does: Runs the package evalf path at the field precision.
/// - Input: A `ComplexField` and `Expr`.
/// - Returns: An approximate `Expr`.
/// - Limits: Raises `PolyError` when the expression cannot be evaluated in the
///   complex field.
pub fn ComplexField::evalf_expr(
  self : ComplexField,
  expr : Expr,
) -> Expr raise PolyError {
  domain_evalf_expr(Domain::CC, expr, prec=Some(self.precision))
}

///|
/// Lift an exact rational into the real field.
///
/// - Does: Converts one exact rational into an `Expr::Float`.
/// - Input: A `RealField` and exact rational value.
/// - Returns: An `Expr`.
/// - Limits: The result is rounded to the field precision.
pub fn RealField::from_exact(
  self : RealField,
  value : @symnum.BigRational,
) -> Expr {
  field_float_expr_from_exact(value, self.precision)
}

///|
/// Lift exact real and imaginary parts into the complex field.
///
/// - Does: Converts exact real/imaginary parts into an `Expr::ComplexFloat`.
/// - Input: A `ComplexField` and two exact rationals.
/// - Returns: An `Expr`.
/// - Limits: The result is rounded to the field precision.
pub fn ComplexField::from_exact_parts(
  self : ComplexField,
  real : @symnum.BigRational,
  imag : @symnum.BigRational,
) -> Expr {
  complex_float_expr_from_gaussian(
    GaussianRatCompat::{ re: real, im: imag },
    self.precision,
  )
}

///|

///|
/// Public API `RealField.from_float`.
///
/// - Does: Provides the `RealField.from_float` operation for approximate real and complex fields.
/// - Input: parameters `self : RealField`, `value : @symcore.Float`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn RealField::from_float(self : RealField, value : @symcore.Float) -> Expr {
  @symcore.Expr::Float(
    @symcore.Float::from_mpf(
      @symnum.mpf_pos(value.to_mpf(), self.precision, @symnum.round_nearest),
      prec=self.precision,
    ),
  )
}

///|

///|
/// Public API `ComplexField.from_complex_float`.
///
/// - Does: Provides the `ComplexField.from_complex_float` operation for approximate real and complex fields.
/// - Input: parameters `self : ComplexField`, `value : @symcore.ComplexFloat`, using
/// the package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn ComplexField::from_complex_float(
  self : ComplexField,
  value : @symcore.ComplexFloat,
) -> Expr {
  @symcore.Expr::ComplexFloat(
    @symcore.ComplexFloat::from_parts(
      @symnum.mpf_pos(
        value.to_mpc().real,
        self.precision,
        @symnum.round_nearest,
      ),
      @symnum.mpf_pos(
        value.to_mpc().imag,
        self.precision,
        @symnum.round_nearest,
      ),
      prec=self.precision,
    ),
  )
}

///|
/// Coerce an expression to a real floating value.
///
/// - Does: Evaluates the expression and extracts a real float at the field
///   precision.
/// - Input: A `RealField` and `Expr`.
/// - Returns: A `Float`.
/// - Limits: Raises `PolyError::DomainMismatch` when the expression is not real
///   at this layer.
pub fn RealField::coerce_float(
  self : RealField,
  expr : Expr,
) -> @symcore.Float raise PolyError {
  match self.evalf_expr(expr) {
    Expr::Float(f) => f
    Expr::ComplexFloat(z) =>
      if @symnum.is_zero(z.to_mpc().imag) {
        z.real_part()
      } else {
        raise PolyError::DomainMismatch
      }
    _ => raise PolyError::DomainMismatch
  }
}

///|
/// Coerce an expression to a complex floating value.
///
/// - Does: Evaluates the expression and extracts a complex float at the field
///   precision.
/// - Input: A `ComplexField` and `Expr`.
/// - Returns: A `ComplexFloat`.
/// - Limits: Raises `PolyError::DomainMismatch` when the expression cannot be
///   represented in the complex field.
pub fn ComplexField::coerce_complex(
  self : ComplexField,
  expr : Expr,
) -> @symcore.ComplexFloat raise PolyError {
  match self.evalf_expr(expr) {
    Expr::ComplexFloat(z) => z
    Expr::Float(f) =>
      @symcore.ComplexFloat::from_real(
        @symcore.Float::from_mpf(
          @symnum.mpf_pos(f.to_mpf(), self.precision, @symnum.round_nearest),
          prec=self.precision,
        ),
      )
    Expr::Number(n) =>
      @symcore.ComplexFloat::from_exact_parts(
        n,
        @symnum.BigRational::zero(),
        prec=self.precision,
      )
    _ => raise PolyError::DomainMismatch
  }
}

///|

///|
/// Public API `RealField.from_expr`.
///
/// - Does: Provides the `RealField.from_expr` operation for approximate real and complex fields.
/// - Input: parameters `self : RealField`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn RealField::from_expr(
  self : RealField,
  expr : Expr,
) -> Expr raise PolyError {
  self.evalf_expr(expr)
}

///|

///|
/// Public API `ComplexField.from_expr`.
///
/// - Does: Provides the `ComplexField.from_expr` operation for approximate real and complex fields.
/// - Input: parameters `self : ComplexField`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ComplexField::from_expr(
  self : ComplexField,
  expr : Expr,
) -> Expr raise PolyError {
  self.evalf_expr(expr)
}

///|
/// Add two approximate real expressions.
///
/// - Does: Coerces both arguments to the real field and adds them.
/// - Input: A `RealField` and two `Expr` values.
/// - Returns: An approximate `Expr`.
/// - Limits: Raises `PolyError` when coercion to the real field fails.
pub fn RealField::add(
  self : RealField,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  self.from_float(self.coerce_float(left) + self.coerce_float(right))
}

///|
/// Multiply two approximate real expressions.
///
/// - Does: Coerces both arguments to the real field and multiplies them.
/// - Input: A `RealField` and two `Expr` values.
/// - Returns: An approximate `Expr`.
/// - Limits: Raises `PolyError` when coercion to the real field fails.
pub fn RealField::mul(
  self : RealField,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  self.from_float(self.coerce_float(left) * self.coerce_float(right))
}

///|

///|
/// Public API `RealField.neg`.
///
/// - Does: Provides the `RealField.neg` operation for approximate real and complex fields.
/// - Input: parameters `self : RealField`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn RealField::neg(self : RealField, expr : Expr) -> Expr raise PolyError {
  self.from_expr(@symcore.mul([@symcore.int(-1), expr]))
}

///|

///|
/// Public API `RealField.inv`.
///
/// - Does: Provides the `RealField.inv` operation for approximate real and complex fields.
/// - Input: parameters `self : RealField`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn RealField::inv(self : RealField, expr : Expr) -> Expr raise PolyError {
  self.from_float(
    self.coerce_float(expr).reciprocal() catch {
      _ => raise PolyError::DivisionByZero
    },
  )
}

///|
/// Add two approximate complex expressions.
///
/// - Does: Coerces both arguments to the complex field and adds them.
/// - Input: A `ComplexField` and two `Expr` values.
/// - Returns: An approximate `Expr`.
/// - Limits: Raises `PolyError` when coercion to the complex field fails.
pub fn ComplexField::add(
  self : ComplexField,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  self.from_complex_float(
    self.coerce_complex(left) + self.coerce_complex(right),
  )
}

///|
/// Multiply two approximate complex expressions.
///
/// - Does: Coerces both arguments to the complex field and multiplies them.
/// - Input: A `ComplexField` and two `Expr` values.
/// - Returns: An approximate `Expr`.
/// - Limits: Raises `PolyError` when coercion to the complex field fails.
pub fn ComplexField::mul(
  self : ComplexField,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  self.from_complex_float(
    self.coerce_complex(left) * self.coerce_complex(right),
  )
}

///|

///|
/// Public API `ComplexField.neg`.
///
/// - Does: Provides the `ComplexField.neg` operation for approximate real and complex fields.
/// - Input: parameters `self : ComplexField`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ComplexField::neg(
  self : ComplexField,
  expr : Expr,
) -> Expr raise PolyError {
  self.from_expr(@symcore.mul([@symcore.int(-1), expr]))
}

///|

///|
/// Public API `ComplexField.inv`.
///
/// - Does: Provides the `ComplexField.inv` operation for approximate real and complex fields.
/// - Input: parameters `self : ComplexField`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ComplexField::inv(
  self : ComplexField,
  expr : Expr,
) -> Expr raise PolyError {
  self.from_complex_float(
    self.coerce_complex(expr).reciprocal() catch {
      _ => raise PolyError::DivisionByZero
    },
  )
}

///|

///|
/// Public API `ComplexField.conjugate`.
///
/// - Does: Provides the `ComplexField.conjugate` operation for approximate real and complex fields.
/// - Input: parameters `self : ComplexField`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ComplexField::conjugate(
  self : ComplexField,
  expr : Expr,
) -> Expr raise PolyError {
  let z = self.coerce_complex(expr)
  self.from_complex_float(
    @symcore.ComplexFloat::from_parts(
      @symnum.mpf_pos(z.to_mpc().real, self.precision, @symnum.round_nearest),
      @symnum.mpf_neg(z.to_mpc().imag, self.precision, @symnum.round_nearest),
      prec=self.precision,
    ),
  )
}

///|

///|
/// Public API `RealField.zero`.
///
/// - Does: Provides the `RealField.zero` operation for approximate real and complex fields.
/// - Input: parameters `self : RealField`, using the package representation expected by
/// the signature.
/// - Returns: a `Expr` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn RealField::zero(self : RealField) -> Expr {
  field_float_expr_from_exact(@symnum.BigRational::zero(), self.precision)
}

///|

///|
/// Public API `RealField.one`.
///
/// - Does: Provides the `RealField.one` operation for approximate real and complex fields.
/// - Input: parameters `self : RealField`, using the package representation expected by
/// the signature.
/// - Returns: a `Expr` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn RealField::one(self : RealField) -> Expr {
  field_float_expr_from_exact(@symnum.BigRational::one(), self.precision)
}

///|

///|
/// Public API `ComplexField.zero`.
///
/// - Does: Provides the `ComplexField.zero` operation for approximate real and complex fields.
/// - Input: parameters `self : ComplexField`, using the package representation expected
/// by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn ComplexField::zero(self : ComplexField) -> Expr {
  self.from_exact_parts(
    @symnum.BigRational::zero(),
    @symnum.BigRational::zero(),
  )
}

///|

///|
/// Public API `ComplexField.one`.
///
/// - Does: Provides the `ComplexField.one` operation for approximate real and complex fields.
/// - Input: parameters `self : ComplexField`, using the package representation expected
/// by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn ComplexField::one(self : ComplexField) -> Expr {
  self.from_exact_parts(@symnum.BigRational::one(), @symnum.BigRational::zero())
}
