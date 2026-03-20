///|
/// Minimal physics units foundation aligned with the core SymPy units
/// semantics used by `physics.units.prefixes`, `quantities`, and `dimensions`.

///|
pub struct Dimension {
  name : Expr
  symbol : String?
} derive(Eq)

///|
pub fn dimension(name : String, symbol? : String? = None) -> Dimension {
  Dimension::{ name: @symcore.symbol(name), symbol }
}

///|
pub fn Dimension::mul(self : Dimension, other : Dimension) -> Dimension {
  Dimension::{ name: self.name * other.name, symbol: None }
}

///|
pub fn Dimension::div(self : Dimension, other : Dimension) -> Dimension {
  Dimension::{ name: self.name * (other.name ^ int(-1)), symbol: None }
}

///|
pub fn Dimension::pow(self : Dimension, exp : Int) -> Dimension {
  Dimension::{ name: self.name ^ int(exp), symbol: None }
}

///|
pub fn Dimension::add(
  self : Dimension,
  other : Dimension,
) -> Dimension raise PhysicsError {
  guard self == other else {
    raise PhysicsError::ValueError("incompatible dimensions")
  }
  self
}

///|
pub struct Quantity {
  name : String
  abbrev : String
  dimension : Dimension
  scale_factor : Expr
  is_prefixed : Bool
} derive(Eq)

///|
pub fn quantity(
  name : String,
  abbrev? : String = "",
  dimension? : Dimension = dimension("dimensionless"),
  scale_factor? : Expr = int(1),
  is_prefixed? : Bool = false,
) -> Quantity {
  Quantity::{ name, abbrev, dimension, scale_factor, is_prefixed }
}

///|
pub fn Quantity::symbol_expr(self : Quantity) -> Expr {
  symbol(self.name)
}

///|
pub fn Quantity::with_scale(
  self : Quantity,
  scale_factor : Expr,
) -> Quantity {
  Quantity::{ ..self, scale_factor, }
}

///|
pub struct Prefix {
  name : String
  abbrev : String
  exponent : Int
  base : Int
  latex_repr : String?
} derive(Eq)

///|
pub enum PrefixValue {
  Prefix(Prefix)
  Expr(Expr)
} derive(Eq)

///|
fn int_pow(base : Int, exp : Int) -> BigInt {
  let mut out = BigInt::from_int(1)
  let b = BigInt::from_int(base)
  for _ in 0..<exp {
    out = out * b
  }
  out
}

///|
fn prefix_scale_factor_expr(base : Int, exponent : Int) -> Expr {
  if exponent >= 0 {
    @symcore.number(@symnum.BigRational::from_bigint(int_pow(base, exponent)))
  } else {
    @symcore.number(
      @symnum.BigRational::from_bigint(BigInt::from_int(1)).div_r(
        @symnum.BigRational::from_bigint(int_pow(base, -exponent)),
      ),
    )
  }
}

///|
fn expr_inverse(expr : Expr) -> Expr {
  match expr {
    Expr::Number(n) =>
      @symcore.number(
        @symnum.BigRational::from_bigint(n.denominator()).div_r(
          @symnum.BigRational::from_bigint(n.numerator()),
        ),
      )
    _ => expr ^ int(-1)
  }
}

///|
pub fn prefix(
  name : String,
  abbrev : String,
  exponent : Int,
  base? : Int = 10,
  latex_repr? : String? = None,
) -> Prefix {
  Prefix::{ name, abbrev, exponent, base, latex_repr }
}

///|
pub fn Prefix::scale_factor(self : Prefix) -> Expr {
  prefix_scale_factor_expr(self.base, self.exponent)
}

///|
pub fn Prefix::mul_prefix(self : Prefix, other : Prefix) -> PrefixValue {
  let factor = self.scale_factor() * other.scale_factor()
  if factor == int(1) {
    return PrefixValue::Expr(int(1))
  }
  for item in known_prefixes() {
    if item.scale_factor() == factor {
      return PrefixValue::Prefix(item)
    }
  }
  PrefixValue::Expr(factor)
}

///|
pub fn Prefix::div_prefix(self : Prefix, other : Prefix) -> PrefixValue {
  let factor = self.scale_factor() * expr_inverse(other.scale_factor())
  if factor == int(1) {
    return PrefixValue::Expr(int(1))
  }
  for item in known_prefixes() {
    if item.scale_factor() == factor {
      return PrefixValue::Prefix(item)
    }
  }
  PrefixValue::Expr(factor)
}

///|
pub fn Prefix::rdiv_one(self : Prefix) -> PrefixValue {
  let factor = expr_inverse(self.scale_factor())
  if factor == int(1) {
    return PrefixValue::Expr(int(1))
  }
  for item in known_prefixes() {
    if item.scale_factor() == factor {
      return PrefixValue::Prefix(item)
    }
  }
  PrefixValue::Expr(factor)
}

///|
pub fn Prefix::mul_quantity(self : Prefix, other : Quantity) -> Expr {
  self.scale_factor() * other.symbol_expr()
}

///|
pub fn Prefix::div_quantity(self : Prefix, other : Quantity) -> Expr {
  self.scale_factor() * expr_inverse(other.symbol_expr())
}

///|
pub fn prefix_value_to_string(value : PrefixValue) -> String {
  match value {
    PrefixValue::Prefix(p) => p.abbrev
    PrefixValue::Expr(expr) => @symprint.to_string(expr)
  }
}

///|
pub fn prefix_unit(
  unit : Quantity,
  prefixes : Map[String, Prefix],
) -> Array[Quantity] {
  let out : Array[Quantity] = Array::new()
  for _, item in prefixes {
    out.push(
      quantity(
        item.name + unit.name,
        abbrev=item.abbrev + unit.abbrev,
        dimension=unit.dimension,
        scale_factor=item.scale_factor() * unit.scale_factor,
        is_prefixed=true,
      ),
    )
  }
  out
}

///|
pub let length : Dimension = dimension("length", symbol=Some("L"))

///|
pub let time_dimension : Dimension = dimension("time", symbol=Some("T"))

///|
pub let mass : Dimension = dimension("mass", symbol=Some("M"))

///|
pub let current : Dimension = dimension("current", symbol=Some("I"))

///|
pub let dimensionless : Dimension = dimension("dimensionless")

///|
pub let meter : Quantity = quantity("meter", abbrev="m", dimension=length)

///|
pub let second : Quantity = quantity(
  "second",
  abbrev="s",
  dimension=time_dimension,
)

///|
pub let kilogram : Quantity = quantity("kilogram", abbrev="kg", dimension=mass)

///|
pub let ampere : Quantity = quantity("ampere", abbrev="A", dimension=current)

///|
pub let watt : Quantity = quantity(
  "watt",
  abbrev="W",
  dimension=mass.mul(length.pow(2)).div(time_dimension.pow(3)),
)

///|
pub let yotta : Prefix = prefix("yotta", "Y", 24)

///|
pub let zetta : Prefix = prefix("zetta", "Z", 21)

///|
pub let exa : Prefix = prefix("exa", "E", 18)

///|
pub let peta : Prefix = prefix("peta", "P", 15)

///|
pub let tera : Prefix = prefix("tera", "T", 12)

///|
pub let giga : Prefix = prefix("giga", "G", 9)

///|
pub let mega : Prefix = prefix("mega", "M", 6)

///|
pub let kilo : Prefix = prefix("kilo", "k", 3)

///|
pub let hecto : Prefix = prefix("hecto", "h", 2)

///|
pub let deca : Prefix = prefix("deca", "da", 1)

///|
pub let deci : Prefix = prefix("deci", "d", -1)

///|
pub let centi : Prefix = prefix("centi", "c", -2)

///|
pub let milli : Prefix = prefix("milli", "m", -3)

///|
pub let micro : Prefix = prefix("micro", "mu", -6, latex_repr=Some("\\mu"))

///|
pub let nano : Prefix = prefix("nano", "n", -9)

///|
pub let pico : Prefix = prefix("pico", "p", -12)

///|
pub let femto : Prefix = prefix("femto", "f", -15)

///|
pub let atto : Prefix = prefix("atto", "a", -18)

///|
pub let zepto : Prefix = prefix("zepto", "z", -21)

///|
pub let yocto : Prefix = prefix("yocto", "y", -24)

///|
pub let prefixes : Map[String, Prefix] = {
  "Y": yotta,
  "Z": zetta,
  "E": exa,
  "P": peta,
  "T": tera,
  "G": giga,
  "M": mega,
  "k": kilo,
  "h": hecto,
  "da": deca,
  "d": deci,
  "c": centi,
  "m": milli,
  "mu": micro,
  "n": nano,
  "p": pico,
  "f": femto,
  "a": atto,
  "z": zepto,
  "y": yocto,
}

///|
pub let kibi : Prefix = prefix("kibi", "Ki", 10, base=2)

///|
pub let mebi : Prefix = prefix("mebi", "Mi", 20, base=2)

///|
pub let gibi : Prefix = prefix("gibi", "Gi", 30, base=2)

///|
pub let tebi : Prefix = prefix("tebi", "Ti", 40, base=2)

///|
pub let pebi : Prefix = prefix("pebi", "Pi", 50, base=2)

///|
pub let exbi : Prefix = prefix("exbi", "Ei", 60, base=2)

///|
pub let bin_prefixes : Map[String, Prefix] = {
  "Ki": kibi,
  "Mi": mebi,
  "Gi": gibi,
  "Ti": tebi,
  "Pi": pebi,
  "Ei": exbi,
}

///|
pub let speed_of_light : Expr = int(299792458) *
  meter.symbol_expr() *
  (second.symbol_expr() ^ int(-1))

///|
pub let e0 : Expr = @symcore.number(
    @symnum.BigRational::from_bigint(BigInt::from_int(625000)).div_r(
      @symnum.BigRational::from_bigint(
        BigInt::from_string("22468879468420441"),
      ),
    ),
  ) *
  (ampere.symbol_expr() ^ int(2)) *
  (second.symbol_expr() ^ int(4)) *
  (pi_expr() ^ int(-1)) *
  (kilogram.symbol_expr() ^ int(-1)) *
  (meter.symbol_expr() ^ int(-3))

///|
pub let u0 : Expr = pi_expr() *
  @symcore.number(
    @symnum.BigRational::from_int(1).div_r(@symnum.BigRational::from_int(2500000)),
  ) *
  kilogram.symbol_expr() *
  meter.symbol_expr() *
  (ampere.symbol_expr() ^ int(-2)) *
  (second.symbol_expr() ^ int(-2))

///|
fn known_prefixes() -> Array[Prefix] {
  [
    yotta, zetta, exa, peta, tera, giga, mega, kilo, hecto, deca, deci, centi, milli,
    micro, nano, pico, femto, atto, zepto, yocto, kibi, mebi, gibi, tebi, pebi, exbi,
  ]
}
