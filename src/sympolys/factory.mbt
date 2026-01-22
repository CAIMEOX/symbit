///|
pub struct PolyBuilder {
  gens : Array[String]
  domain : Domain
  order : TermOrder
}

///|
pub fn PolyBuilder::new(gens : Array[String], domain : Domain) -> PolyBuilder {
  PolyBuilder::{ gens, domain, order: TermOrder::Lex }
}

///|
pub fn PolyBuilder::order(self : PolyBuilder, order : TermOrder) -> PolyBuilder {
  PolyBuilder::{ gens: self.gens, domain: self.domain, order }
}

///|
pub fn PolyBuilder::from_expr(
  self : PolyBuilder,
  expr : @symcore.Expr,
) -> Poly raise PolyError {
  Poly::from_expr(expr, self.gens, self.domain).with_order(self.order)
}
