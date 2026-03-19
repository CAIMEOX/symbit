///|
/// Optical medium formulas aligned with `sympy.physics.optics.medium`.

///|
pub enum Medium {
  MediumN(String, Expr)
  MediumPP(String, Expr, Expr)
} derive(Eq)

///|
fn is_vacuum_pair(ep : Expr, mu : Expr) -> Bool {
  ep == e0 && mu == u0
}

///|
fn vacuum_impedance_expr() -> Expr {
  (try! @symcore.rational_from_ints(149896229, 1250000)) *
  pi_expr() *
  (ampere.symbol_expr() ^ int(-2)) *
  kilogram.symbol_expr() *
  (meter.symbol_expr() ^ int(2)) *
  (second.symbol_expr() ^ int(-3))
}

///|
pub fn medium(
  name : String,
  permittivity? : Expr? = None,
  permeability? : Expr? = None,
  n? : Expr? = None,
) -> Medium raise PhysicsError {
  match n {
    Some(index) =>
      match (permittivity, permeability) {
        (Some(ep), None) =>
          Medium::MediumPP(
            name,
            ep,
            (index ^ int(2)) *
            (speed_of_light ^ int(-2)) *
            (ep ^ int(-1)),
          )
        (None, Some(mu)) =>
          Medium::MediumPP(
            name,
            (index ^ int(2)) *
            (speed_of_light ^ int(-2)) *
            (mu ^ int(-1)),
            mu,
          )
        (Some(_), Some(_)) =>
          raise PhysicsError::ValueError(
            "Specifying all of permittivity, permeability, and n is not allowed",
          )
        (None, None) => Medium::MediumN(name, index)
      }
    None =>
      match (permittivity, permeability) {
        (Some(ep), Some(mu)) => Medium::MediumPP(name, ep, mu)
        (None, None) => Medium::MediumPP(name, e0, u0)
        _ =>
          raise PhysicsError::ValueError(
            "Arguments are underspecified. Either specify n or any two of permittivity, permeability, and n",
          )
      }
  }
}

///|
pub fn Medium::name(self : Medium) -> String {
  match self {
    Medium::MediumN(name, _) => name
    Medium::MediumPP(name, _, _) => name
  }
}

///|
pub fn Medium::n(self : Medium) -> Expr {
  match self {
    Medium::MediumN(_, index) => index
    Medium::MediumPP(_, ep, mu) =>
      if is_vacuum_pair(ep, mu) {
        int(1)
      } else {
        speed_of_light * @symelem.sqrt(ep * mu)
      }
  }
}

///|
pub fn Medium::speed(self : Medium) -> Expr {
  match self {
    Medium::MediumN(_, index) => speed_of_light * (index ^ int(-1))
    Medium::MediumPP(_, ep, mu) =>
      if is_vacuum_pair(ep, mu) {
        speed_of_light
      } else {
        @symelem.sqrt(ep * mu) ^ int(-1)
      }
  }
}

///|
pub fn Medium::refractive_index(self : Medium) -> Expr {
  match self {
    Medium::MediumN(_, index) => index
    Medium::MediumPP(_, ep, mu) =>
      if is_vacuum_pair(ep, mu) {
        int(1)
      } else {
        speed_of_light * @symelem.sqrt(ep * mu)
      }
  }
}

///|
pub fn Medium::permittivity(self : Medium) -> Expr raise PhysicsError {
  match self {
    Medium::MediumPP(_, ep, _) => ep
    _ => raise PhysicsError::ValueError("permittivity is undefined for MediumN")
  }
}

///|
pub fn Medium::permeability(self : Medium) -> Expr raise PhysicsError {
  match self {
    Medium::MediumPP(_, _, mu) => mu
    _ => raise PhysicsError::ValueError("permeability is undefined for MediumN")
  }
}

///|
pub fn Medium::intrinsic_impedance(
  self : Medium,
) -> Expr raise PhysicsError {
  match self {
    Medium::MediumPP(_, ep, mu) =>
      if is_vacuum_pair(ep, mu) {
        vacuum_impedance_expr()
      } else {
        @symelem.sqrt(mu * (ep ^ int(-1)))
      }
    _ =>
      raise PhysicsError::ValueError(
        "intrinsic_impedance is undefined for MediumN",
      )
  }
}
