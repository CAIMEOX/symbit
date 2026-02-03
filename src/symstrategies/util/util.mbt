///|
/// Strategy-friendly alias for SymPy's Basic.
pub type Basic = @symcore.Expr

///|
/// Operations used by strategy builders for Expr trees.
pub(all) enum ExprOp {
  Number
  Symbol
  Add
  Mul
  Pow
  Function(String)
}

///|
fn expr_op_rank(op : ExprOp) -> Int {
  match op {
    ExprOp::Number => 0
    ExprOp::Symbol => 1
    ExprOp::Add => 2
    ExprOp::Mul => 3
    ExprOp::Pow => 4
    ExprOp::Function(_) => 5
  }
}

///|
pub impl Eq for ExprOp with equal(self, other : ExprOp) -> Bool {
  match (self, other) {
    (ExprOp::Number, ExprOp::Number) => true
    (ExprOp::Symbol, ExprOp::Symbol) => true
    (ExprOp::Add, ExprOp::Add) => true
    (ExprOp::Mul, ExprOp::Mul) => true
    (ExprOp::Pow, ExprOp::Pow) => true
    (ExprOp::Function(a), ExprOp::Function(b)) => a == b
    _ => false
  }
}

///|
pub impl Eq for ExprOp with not_equal(self, other : ExprOp) -> Bool {
  !self.equal(other)
}

///|
pub impl Hash for ExprOp with hash(self) -> Int {
  let hasher = Hasher::new()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for ExprOp with hash_combine(self, hasher : Hasher) -> Unit {
  hasher.combine_int(expr_op_rank(self))
  match self {
    ExprOp::Function(name) => hasher.combine_string(name)
    _ => ()
  }
}

///|
/// Function bundle used by traversal strategies.
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
  match expr {
    @symcore.Expr::Number(_) => ExprOp::Number
    @symcore.Expr::Symbol(_) => ExprOp::Symbol
    @symcore.Expr::Add(_) => ExprOp::Add
    @symcore.Expr::Mul(_) => ExprOp::Mul
    @symcore.Expr::Pow(_, _) => ExprOp::Pow
    @symcore.Expr::Function(name, _) => ExprOp::Function(name)
  }
}

///|
/// Raw (non-canonical) constructor, mirroring Basic.__new__.
pub fn expr_new_raw(op : ExprOp, args : Array[@symcore.Expr]) -> @symcore.Expr {
  match op {
    ExprOp::Number =>
      match args.length() {
        1 => args[0]
        _ => @symcore.int(0)
      }
    ExprOp::Symbol =>
      match args.length() {
        1 => args[0]
        _ => @symcore.symbol("")
      }
    ExprOp::Add => @symcore.raw_add(args)
    ExprOp::Mul => @symcore.raw_mul(args)
    ExprOp::Pow =>
      if args.length() >= 2 {
        @symcore.raw_pow(args[0], args[1])
      } else if args.length() == 1 {
        @symcore.raw_pow(args[0], @symcore.int(1))
      } else {
        @symcore.raw_pow(@symcore.int(0), @symcore.int(1))
      }
    ExprOp::Function(name) => @symcore.raw_function(name, args)
  }
}

///|
/// Canonical constructor for Expr.
pub fn expr_new_eval(op : ExprOp, args : Array[@symcore.Expr]) -> @symcore.Expr {
  match op {
    ExprOp::Number =>
      match args.length() {
        1 => args[0]
        _ => @symcore.int(0)
      }
    ExprOp::Symbol =>
      match args.length() {
        1 => args[0]
        _ => @symcore.symbol("")
      }
    ExprOp::Add => @symcore.add(args)
    ExprOp::Mul => @symcore.mul(args)
    ExprOp::Pow =>
      if args.length() >= 2 {
        @symcore.pow(args[0], args[1])
      } else if args.length() == 1 {
        @symcore.pow(args[0], @symcore.int(1))
      } else {
        @symcore.pow(@symcore.int(0), @symcore.int(1))
      }
    ExprOp::Function(name) => @symcore.function(name, args)
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
  match expr {
    @symcore.Expr::Number(_) => true
    @symcore.Expr::Symbol(_) => true
    @symcore.Expr::Function(_, args) => args.is_empty()
    _ => false
  }
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
/// Alias for raw constructor used by rl.
pub fn new(op : ExprOp, args : Array[@symcore.Expr]) -> @symcore.Expr {
  expr_new_raw(op, args)
}
