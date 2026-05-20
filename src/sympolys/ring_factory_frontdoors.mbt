///|
/// Typed ring and field factory front doors.
///
/// Current Limits:
/// - SymPy returns dynamic Python ring objects plus unpackable generators.
///   MoonBit returns one structured value instead.
/// - Namespace-injecting helpers (`vring`, `vfield`) cannot mutate a caller's
///   lexical scope, so they are aliases for the typed factories.

///|
pub struct RingFactoryResult {
  domain : Domain
  gens : Array[String]
  symbols : Array[Expr]
  order : TermOrder
}

///|
fn ring_factory_symbols(gens : Array[String]) -> Array[Expr] {
  gens.map(name => Expr::Symbol(name))
}

///|
fn ring_factory_result(
  domain : Domain,
  gens : Array[String],
  order : TermOrder,
) -> RingFactoryResult {
  RingFactoryResult::{
    domain,
    gens,
    symbols: ring_factory_symbols(gens),
    order,
  }
}

///|
fn ring_factory_ground_domain(domain : Domain, gens : Array[String]) -> Domain {
  match domain {
    Domain::PolyRing(base, domain_gens)
    | Domain::RationalFunctionField(base, domain_gens) =>
      if domain_gens == gens {
        base
      } else {
        domain
      }
    _ => domain
  }
}

///|
/// Build a polynomial-ring descriptor.
///
/// - Does: Constructs a typed descriptor for `domain[gens]`.
/// - Input: Generator names, coefficient `Domain`, and optional term order.
/// - Returns: `RingFactoryResult`.
/// - Limits: Does not create Python-style element classes or inject variables.
pub fn ring(
  gens : Array[String],
  domain : Domain,
  order? : TermOrder = TermOrder::Lex,
) -> RingFactoryResult {
  ring_factory_result(Domain::PolyRing(domain, gens), gens, order)
}

///|
/// Build a polynomial-ring descriptor.
///
/// - Does: Mirrors SymPy's `xring` spelling with typed output.
/// - Input: Same as `ring`.
/// - Returns: `RingFactoryResult`.
/// - Limits: Same as `ring`.
pub fn xring(
  gens : Array[String],
  domain : Domain,
  order? : TermOrder = TermOrder::Lex,
) -> RingFactoryResult {
  ring(gens, domain, order~)
}

///|
/// Build a polynomial-ring descriptor without namespace mutation.
///
/// - Does: Mirrors SymPy's `vring` spelling.
/// - Input: Same as `ring`.
/// - Returns: `RingFactoryResult`.
/// - Limits: MoonBit has lexical bindings, so no caller-scope injection occurs.
pub fn vring(
  gens : Array[String],
  domain : Domain,
  order? : TermOrder = TermOrder::Lex,
) -> RingFactoryResult {
  ring(gens, domain, order~)
}

///|
/// Infer a polynomial-ring descriptor from expressions.
///
/// - Does: Infers generators and a conservative coefficient domain.
/// - Input: Expressions plus optional explicit generators/domain/order.
/// - Returns: `RingFactoryResult`.
/// - Limits: Options objects and Python postprocessing flags are not modeled.
pub fn sring(
  exprs : Array[Expr],
  gens? : Array[String] = [],
  domain? : Domain,
  order? : TermOrder = TermOrder::Lex,
) -> RingFactoryResult {
  let resolved_gens = if gens.is_empty() {
    infer_gens_union(exprs)
  } else {
    gens
  }
  let base = match domain {
    Some(value) => value
    None =>
      ring_factory_ground_domain(construct_domain(exprs).domain, resolved_gens)
  }
  ring(resolved_gens, base, order~)
}

///|
/// Build a rational-function-field descriptor.
///
/// - Does: Constructs a typed descriptor for `domain(gens)`.
/// - Input: Generator names, coefficient `Domain`, and optional term order.
/// - Returns: `RingFactoryResult`.
/// - Limits: Does not create Python-style field element classes.
pub fn field(
  gens : Array[String],
  domain : Domain,
  order? : TermOrder = TermOrder::Lex,
) -> RingFactoryResult {
  ring_factory_result(Domain::RationalFunctionField(domain, gens), gens, order)
}

///|
/// Build a rational-function-field descriptor.
///
/// - Does: Mirrors SymPy's `xfield` spelling with typed output.
/// - Input: Same as `field`.
/// - Returns: `RingFactoryResult`.
/// - Limits: Same as `field`.
pub fn xfield(
  gens : Array[String],
  domain : Domain,
  order? : TermOrder = TermOrder::Lex,
) -> RingFactoryResult {
  field(gens, domain, order~)
}

///|
/// Build a rational-function-field descriptor without namespace mutation.
///
/// - Does: Mirrors SymPy's `vfield` spelling.
/// - Input: Same as `field`.
/// - Returns: `RingFactoryResult`.
/// - Limits: MoonBit has lexical bindings, so no caller-scope injection occurs.
pub fn vfield(
  gens : Array[String],
  domain : Domain,
  order? : TermOrder = TermOrder::Lex,
) -> RingFactoryResult {
  field(gens, domain, order~)
}

///|
/// Infer a rational-function-field descriptor from expressions.
///
/// - Does: Infers generators and a conservative coefficient domain.
/// - Input: Expressions plus optional explicit generators/domain/order.
/// - Returns: `RingFactoryResult`.
/// - Limits: Options objects and Python postprocessing flags are not modeled.
pub fn sfield(
  exprs : Array[Expr],
  gens? : Array[String] = [],
  domain? : Domain,
  order? : TermOrder = TermOrder::Lex,
) -> RingFactoryResult {
  let resolved_gens = if gens.is_empty() {
    infer_gens_union(exprs)
  } else {
    gens
  }
  let base = match domain {
    Some(value) => value
    None =>
      ring_factory_ground_domain(construct_domain(exprs).domain, resolved_gens)
  }
  field(resolved_gens, base, order~)
}
