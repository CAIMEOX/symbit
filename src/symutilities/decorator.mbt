///|\
/// MoonBit-native equivalents of selected `sympy.utilities.decorator` helpers.

///|
pub enum Threadable[T] {
  Scalar(T)
  Array(Array[Threadable[T]])
} derive(Eq)

///|
pub fn[T] threadable_scalar(value : T) -> Threadable[T] {
  Threadable::Scalar(value)
}

///|
pub fn[T] threadable_array(values : Array[Threadable[T]]) -> Threadable[T] {
  Threadable::Array(values)
}

///|
fn[T] thread_container(value : Threadable[T], rule : (T) -> T) -> Threadable[T] {
  match value {
    Threadable::Scalar(v) => Threadable::Scalar(rule(v))
    Threadable::Array(items) =>
      Threadable::Array(items.map(item => thread_container(item, rule)))
  }
}

///|
fn thread_expr(expr : Expr, use_add : Bool, rule : (Expr) -> Expr) -> Expr {
  match expr {
    Expr::Add(args) if use_add => @symcore.add(args.map(arg => rule(arg)))
    _ => rule(expr)
  }
}

///|
/// Apply `rule` over arrays of expressions and, by default, over additive
/// expression arguments as well.
pub fn threaded(
  rule : (Expr) -> Expr,
) -> (Threadable[Expr]) -> Threadable[Expr] {
  letrec apply = (value : Threadable[Expr]) => {
    match value {
      Threadable::Scalar(expr) =>
        Threadable::Scalar(thread_expr(expr, true, rule))
      Threadable::Array(items) => Threadable::Array(items.map(apply))
    }
  }
  apply
}

///|
/// Same as `threaded`, but treats additive expressions as atomic values.
pub fn xthreaded(
  rule : (Expr) -> Expr,
) -> (Threadable[Expr]) -> Threadable[Expr] {
  (value : Threadable[Expr]) => thread_container(value, expr => rule(expr))
}

///|
/// Register `name` in a caller-owned export list and return `obj` unchanged.
pub fn[T] public(obj : T, exports : Ref[Array[String]], name : String) -> T {
  if !exports.val.contains(name) {
    exports.val.push(name)
  }
  obj
}

///|
/// Wrap a unary function so that each invocation first reports a deprecation.
pub fn[T, U] deprecated(
  message : String,
  deprecated_since_version : String,
  active_deprecations_target : String,
  f : (T) -> U,
  reporter? : (SymPyDeprecationWarning) -> Unit = _ => (),
) -> (T) -> U {
  let warning : SymPyDeprecationWarning = {
    message,
    deprecated_since_version,
    active_deprecations_target,
  }
  (arg : T) => {
    reporter(warning)
    f(arg)
  }
}
