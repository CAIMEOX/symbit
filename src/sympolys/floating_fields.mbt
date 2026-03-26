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
pub struct RealField {
  precision : Int
} derive(Eq, Show)

///|
pub struct ComplexField {
  precision : Int
} derive(Eq, Show)

///|
pub fn RealField::new(precision? : Int = 53) -> RealField {
  { precision: field_default_precision(precision) }
}

///|
pub fn ComplexField::new(precision? : Int = 53) -> ComplexField {
  { precision: field_default_precision(precision) }
}

///|
pub fn RealField::precision(self : RealField) -> Int {
  self.precision
}

///|
pub fn ComplexField::precision(self : ComplexField) -> Int {
  self.precision
}

///|
pub fn RealField::domain(self : RealField) -> Domain {
  ignore(self)
  Domain::RR
}

///|
pub fn ComplexField::domain(self : ComplexField) -> Domain {
  ignore(self)
  Domain::CC
}

///|
pub fn RealField::contains_expr(self : RealField, expr : Expr) -> Bool {
  ignore(self)
  Domain::RR.contains_expr(expr)
}

///|
pub fn ComplexField::contains_expr(self : ComplexField, expr : Expr) -> Bool {
  ignore(self)
  Domain::CC.contains_expr(expr)
}

///|
pub fn RealField::evalf_expr(
  self : RealField,
  expr : Expr,
) -> Expr raise PolyError {
  domain_evalf_expr(Domain::RR, expr, prec=Some(self.precision))
}

///|
pub fn ComplexField::evalf_expr(
  self : ComplexField,
  expr : Expr,
) -> Expr raise PolyError {
  domain_evalf_expr(Domain::CC, expr, prec=Some(self.precision))
}

///|
pub fn RealField::from_exact(
  self : RealField,
  value : @symnum.BigRational,
) -> Expr {
  field_float_expr_from_exact(value, self.precision)
}

///|
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
pub fn RealField::from_float(self : RealField, value : @symcore.Float) -> Expr {
  @symcore.Expr::Float(
    @symcore.Float::from_mpf(
      @symnum.mpf_pos(value.to_mpf(), self.precision, @symnum.round_nearest),
      prec=self.precision,
    ),
  )
}

///|
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
pub fn RealField::from_expr(
  self : RealField,
  expr : Expr,
) -> Expr raise PolyError {
  self.evalf_expr(expr)
}

///|
pub fn ComplexField::from_expr(
  self : ComplexField,
  expr : Expr,
) -> Expr raise PolyError {
  self.evalf_expr(expr)
}

///|
pub fn RealField::add(
  self : RealField,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  self.from_float(self.coerce_float(left) + self.coerce_float(right))
}

///|
pub fn RealField::mul(
  self : RealField,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  self.from_float(self.coerce_float(left) * self.coerce_float(right))
}

///|
pub fn RealField::neg(self : RealField, expr : Expr) -> Expr raise PolyError {
  self.from_expr(@symcore.mul([@symcore.int(-1), expr]))
}

///|
pub fn RealField::inv(self : RealField, expr : Expr) -> Expr raise PolyError {
  self.from_float(
    self.coerce_float(expr).reciprocal() catch {
      _ => raise PolyError::DivisionByZero
    },
  )
}

///|
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
pub fn ComplexField::neg(
  self : ComplexField,
  expr : Expr,
) -> Expr raise PolyError {
  self.from_expr(@symcore.mul([@symcore.int(-1), expr]))
}

///|
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
pub fn RealField::zero(self : RealField) -> Expr {
  field_float_expr_from_exact(@symnum.BigRational::zero(), self.precision)
}

///|
pub fn RealField::one(self : RealField) -> Expr {
  field_float_expr_from_exact(@symnum.BigRational::one(), self.precision)
}

///|
pub fn ComplexField::zero(self : ComplexField) -> Expr {
  self.from_exact_parts(
    @symnum.BigRational::zero(),
    @symnum.BigRational::zero(),
  )
}

///|
pub fn ComplexField::one(self : ComplexField) -> Expr {
  self.from_exact_parts(@symnum.BigRational::one(), @symnum.BigRational::zero())
}
