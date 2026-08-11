///|
/// Strategy-friendly alias for SymPy's Basic.
pub type Basic = @symcore.Expr

///|
/// Operator tags for `Expr` nodes in generic strategy combinators.
pub(all) enum ExprOp {
  Number
  Symbol
  Add
  Mul
  Pow
  Function(String)
} derive(Eq, Hash)

///|
/// Generic traversal adapter: inspect node op, rebuild, and enumerate children.
pub struct Fns[T, Op] {
  op : (T) -> Op
  new : (Op, Array[T]) -> T
  children : (T) -> ArrayView[T]
  leaf : (T) -> Bool
}

///|
/// Return a new map with one key updated.
pub fn[K : Eq + Hash, V] assoc(m : Map[K, V], k : K, v : V) -> Map[K, V] {
  let out = m.copy()
  out[k] = v
  out
}

///|
/// Extract the operator for an Expr.
pub fn expr_op(expr : @symcore.Expr) -> ExprOp {
  match @symcore.expr_form(expr) {
    Number(_) | Float(_) | ComplexFloat(_) | Boolean(_) => Number
    Symbol(_) => Symbol
    Add(_) => Add
    Mul(_) => Mul
    Pow(_, _) => Pow
    _ => Function(@symcore.head_name(expr))
  }
}

///|
/// Raw (non-canonical) constructor, mirroring Basic.__new__.
pub fn expr_new_raw(op : ExprOp, args : Array[@symcore.Expr]) -> @symcore.Expr {
  match op {
    Number =>
      match args.length() {
        1 => args[0]
        _ => @symcore.int(0)
      }
    Symbol =>
      match args.length() {
        1 => args[0]
        _ => Symbol("")
      }
    Add => @symcore.raw_add(args)
    Mul => @symcore.raw_mul(args)
    Pow =>
      if args.length() >= 2 {
        @symcore.raw_pow(args[0], args[1])
      } else if args.length() == 1 {
        @symcore.raw_pow(args[0], @symcore.int(1))
      } else {
        @symcore.raw_pow(@symcore.int(0), @symcore.int(1))
      }
    Function(name) => @symcore.raw_function(name, args)
  }
}

///|
/// Canonical constructor for Expr.
pub fn expr_new_eval(op : ExprOp, args : Array[@symcore.Expr]) -> @symcore.Expr {
  match op {
    Number =>
      match args.length() {
        1 => args[0]
        _ => @symcore.int(0)
      }
    Symbol =>
      match args.length() {
        1 => args[0]
        _ => Symbol("")
      }
    Add => @symcore.add(args)
    Mul => @symcore.mul(args)
    Pow =>
      if args.length() >= 2 {
        @symcore.pow(args[0], args[1])
      } else if args.length() == 1 {
        @symcore.pow(args[0], @symcore.int(1))
      } else {
        @symcore.pow(@symcore.int(0), @symcore.int(1))
      }
    Function(name) => @symcore.function(name, args)
  }
}

///|
/// Expr children accessor.
pub fn expr_children(expr : @symcore.Expr) -> ArrayView[@symcore.Expr] {
  @symcore.children(expr)
}

///|
/// Leaf predicate for Expr traversal.
pub fn expr_leaf(expr : @symcore.Expr) -> Bool {
  @symcore.is_atomic(expr)
}

///|
/// Basic (raw) traversal functions.
pub let basic_fns : Fns[@symcore.Expr, ExprOp] = {
  op: expr_op,
  new: expr_new_raw,
  children: expr_children,
  leaf: expr_leaf,
}

///|
/// Expression (evaluating) traversal functions.
pub let expr_fns : Fns[@symcore.Expr, ExprOp] = {
  op: expr_op,
  new: expr_new_eval,
  children: expr_children,
  leaf: expr_leaf,
}

///|
/// Alias for the raw constructor expected by rewrite-library helpers.
pub fn new(op : ExprOp, args : Array[@symcore.Expr]) -> @symcore.Expr {
  expr_new_raw(op, args)
}
