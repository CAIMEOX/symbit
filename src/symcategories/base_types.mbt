///|
pub struct Object {
  name : String
}

///|
pub enum Morphism {
  Identity(Object)
  Named(Object, Object, String)
  Composite(Array[Morphism])
}

///|
pub struct Class {
  objects : Array[Object]
}

///|
pub enum MorphismSpec {
  List(Array[Morphism])
  Props(Map[Morphism, Array[String]])
}

///|
pub struct Diagram {
  premises : Map[Morphism, Array[String]]
  conclusions : Map[Morphism, Array[String]]
  objects : Array[Object]
}

///|
pub struct Category {
  name : String
  objects : Class
  commutative_diagrams : Array[Diagram]
}

///|
pub enum LayoutKind {
  Generic
  Sequential
}

///|
pub struct GridHints {
  layout : LayoutKind
  transpose : Bool
}

///|
pub struct GroupLayout {
  objects : Array[Object]
  hints : GridHints?
}

///|
pub enum GridGroup {
  Single(Object)
  Group(GroupLayout)
}

///|
pub struct GrowableGrid[T] {
  mut width_ : Int
  mut height_ : Int
  array_ : Array[Array[T?]]
}

///|
pub struct DiagramGrid {
  grid_ : GrowableGrid[Object]
  morphisms_ : Map[Morphism, Array[String]]
}

///|
pub struct ArrowStringDescription {
  unit : String
  curving : String
  curving_amount : Int?
  looping_start : String
  looping_end : String
  horizontal_direction : String
  vertical_direction : String
  mut label_position : String
  mut label : String
  mut label_displacement : String
  mut arrow_style : String
  mut forced_label_position : Bool
}

///|
pub type ArrowFormatter = (ArrowStringDescription) -> Unit

///|
pub struct XypicDiagramDrawer {
  mut unit : String
  mut default_curving_amount : Int
  mut default_curving_step : Int
  arrow_formatters : Map[String, ArrowFormatter]
  mut default_arrow_formatter : ArrowFormatter?
}
