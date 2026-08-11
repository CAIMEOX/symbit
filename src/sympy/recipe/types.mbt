///|
/// A value produced by one recipe node.
///
/// References are tied to the builder that created them. The constructor is
/// intentionally private so callers cannot forge node identifiers.
pub struct ValueRef {
  id : Int
  owner : Ref[Unit]
}

///|
/// Values accepted as recipe call arguments.
///
/// Integer and floating-point constants use text so their exact spelling is
/// preserved across JSON and no host integer or floating-point range is
/// imposed. `Ref` reuses a value already produced by this builder.
pub(all) enum RecipeArg {
  Ref(ValueRef)
  Null
  Bool(Bool)
  Str(String)
  DecimalInt(String)
  DecimalFloat(String)
}

///|
/// How the worker converts the selected Python value into JSON.
pub(all) enum ResultCodec {
  Discard
  NoneValue
  Str
  Repr
  Srepr
  Bool
  Int
  Float
  Json
  Optional(ResultCodec)
  List(ResultCodec)
  Tuple(Array[ResultCodec])
  DictPairs(ResultCodec, ResultCodec)
}

///|
/// Local recipe construction failures.
pub(all) suberror RecipeError {
  ForeignReference
  BuilderClosed
  RecursiveCodec
  CodecTooDeep
  UnexpectedResult(String)
}

///|
/// A single-use builder for one `oracle.recipe.v1` request.
///
/// Node construction is local. The first terminal request seals the builder,
/// including when the worker reports an error.
pub struct Builder {
  owner : Ref[Unit]
  nodes : Array[Json]
  mut closed : Bool
}
