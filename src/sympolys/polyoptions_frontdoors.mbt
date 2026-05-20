///|
/// Typed option descriptor for polynomial front doors.
///
/// - Does: Stores the common generator/domain/order options accepted by
///   `sympolys` front doors.
/// - Input: Generator names plus optional domain, modulus, extension, and
///   monomial order choices.
/// - Returns: An `Options` value.
/// - Limits: Python-only preprocessing flags and dynamic postprocessors are not
///   modeled; pass explicit fields to the MoonBit front doors instead.
pub struct Options {
  gens : Array[String]
  domain : Domain?
  order : TermOrder
  modulus : Int?
  extension : Array[String]
}

///|
/// Build a typed polynomial options descriptor.
///
/// - Does: Normalizes absent options to the defaults used by public front
///   doors.
/// - Input: Optional generator names, domain, order, modulus, and extension
///   symbols.
/// - Returns: `Options`.
/// - Limits: Does not parse Python-style keyword dictionaries or flags.
pub fn Options::new(
  gens? : Array[String] = [],
  domain? : Domain,
  order? : TermOrder = TermOrder::Lex,
  modulus? : Int,
  extension? : Array[String] = [],
) -> Options {
  Options::{ gens, domain, order, modulus, extension }
}
