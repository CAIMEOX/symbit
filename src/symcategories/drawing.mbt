///|
fn latex_name(name : String) -> String {
  @symprint.latex(Symbol(name))
}

///|
fn latex_object(obj : Object) -> String {
  latex_name(obj.name)
}

///|
pub fn arrow_string_description(
  unit : String,
  curving : String,
  curving_amount : Int?,
  looping_start : String,
  looping_end : String,
  horizontal_direction : String,
  vertical_direction : String,
  label_position : String,
  label : String,
) -> ArrowStringDescription {
  {
    unit,
    curving,
    curving_amount,
    looping_start,
    looping_end,
    horizontal_direction,
    vertical_direction,
    label_position,
    label,
    label_displacement: "",
    arrow_style: "",
    forced_label_position: false,
  }
}

///|
pub fn ArrowStringDescription::set_label_position(
  self : ArrowStringDescription,
  value : String,
) -> Unit {
  self.label_position = value
}

///|
pub fn ArrowStringDescription::set_label(
  self : ArrowStringDescription,
  value : String,
) -> Unit {
  self.label = value
}

///|
pub fn ArrowStringDescription::set_label_displacement(
  self : ArrowStringDescription,
  value : String,
) -> Unit {
  self.label_displacement = value
}

///|
pub fn ArrowStringDescription::set_arrow_style(
  self : ArrowStringDescription,
  value : String,
) -> Unit {
  self.arrow_style = value
}

///|
pub fn ArrowStringDescription::set_forced_label_position(
  self : ArrowStringDescription,
  value : Bool,
) -> Unit {
  self.forced_label_position = value
}

///|
pub impl Show for ArrowStringDescription with fn to_string(self) -> String {
  let curving_str = if self.curving != "" {
    match self.curving_amount {
      Some(amount) => "@/\{self.curving}\{amount}\{self.unit}/"
      None => ""
    }
  } else {
    ""
  }

  let looping_str = if self.looping_start != "" && self.looping_end != "" {
    "@(\{self.looping_start},\{self.looping_end})"
  } else {
    ""
  }

  let style_str = if self.arrow_style != "" {
    "@" + self.arrow_style
  } else {
    ""
  }

  "\\ar" +
  curving_str +
  looping_str +
  style_str +
  "[" +
  self.horizontal_direction +
  self.vertical_direction +
  "]" +
  self.label_position +
  self.label_displacement +
  "{" +
  self.label +
  "}"
}

///|
pub impl Show for ArrowStringDescription with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
pub fn xypic_diagram_drawer() -> XypicDiagramDrawer {
  {
    unit: "mm",
    default_curving_amount: 3,
    default_curving_step: 4,
    arrow_formatters: {},
    default_arrow_formatter: None,
  }
}

///|
pub fn XypicDiagramDrawer::set_unit(
  self : XypicDiagramDrawer,
  unit : String,
) -> Unit {
  self.unit = unit
}

///|
pub fn XypicDiagramDrawer::set_default_curving_amount(
  self : XypicDiagramDrawer,
  value : Int,
) -> Unit {
  self.default_curving_amount = value
}

///|
pub fn XypicDiagramDrawer::set_default_curving_step(
  self : XypicDiagramDrawer,
  value : Int,
) -> Unit {
  self.default_curving_step = value
}

///|
pub fn XypicDiagramDrawer::set_arrow_formatter(
  self : XypicDiagramDrawer,
  prop : String,
  formatter : ArrowFormatter,
) -> Unit {
  self.arrow_formatters[prop] = formatter
}

///|
pub fn XypicDiagramDrawer::set_default_arrow_formatter(
  self : XypicDiagramDrawer,
  formatter : ArrowFormatter?,
) -> Unit {
  self.default_arrow_formatter = formatter
}

///|
fn process_loop_morphism(
  row : Int,
  col : Int,
  grid : DiagramGrid,
  morphisms_str_info : Map[Morphism, ArrowStringDescription],
  object_coords : Map[Object, (Int, Int)],
) -> (String, String, String, String) {
  let quadrant = [0, 0, 0, 0]
  let obj = match grid.get(row, col) {
    Some(value) => value
    None => abort("process_loop_morphism")
  }

  for morphism in morphisms_str_info.keys() {
    let info = morphisms_str_info[morphism]
    if morphism.domain() == obj && morphism.codomain() == obj {
      match (info.looping_start, info.looping_end) {
        ("r", "u") => quadrant[0] = quadrant[0] + 1
        ("u", "l") => quadrant[1] = quadrant[1] + 1
        ("l", "d") => quadrant[2] = quadrant[2] + 1
        ("d", "r") => quadrant[3] = quadrant[3] + 1
        _ => ()
      }
      continue
    }

    let mut end_row = 0
    let mut end_col = 0
    let mut goes_out = false
    if morphism.domain() == obj {
      let coords = object_coords[morphism.codomain()]
      end_row = coords.0
      end_col = coords.1
      goes_out = true
    } else if morphism.codomain() == obj {
      let coords = object_coords[morphism.domain()]
      end_row = coords.0
      end_col = coords.1
      goes_out = false
    } else {
      continue
    }

    let delta_row = end_row - row
    let delta_col = end_col - col
    let curving = info.curving

    if delta_row != 0 && delta_col != 0 {
      if delta_row > 0 && delta_col > 0 {
        quadrant[0] = quadrant[0] + 1
      } else if delta_row > 0 && delta_col < 0 {
        quadrant[1] = quadrant[1] + 1
      } else if delta_row < 0 && delta_col < 0 {
        quadrant[2] = quadrant[2] + 1
      } else if delta_row < 0 && delta_col > 0 {
        quadrant[3] = quadrant[3] + 1
      }
    } else if delta_row == 0 {
      let (upper_quadrant, lower_quadrant) = if delta_col > 0 {
        if goes_out {
          (0, 3)
        } else {
          (3, 0)
        }
      } else if goes_out {
        (2, 1)
      } else {
        (1, 2)
      }

      if curving != "" {
        if curving == "^" {
          quadrant[upper_quadrant] = quadrant[upper_quadrant] + 1
        } else if curving == "_" {
          quadrant[lower_quadrant] = quadrant[lower_quadrant] + 1
        }
      } else {
        quadrant[upper_quadrant] = quadrant[upper_quadrant] + 1
        quadrant[lower_quadrant] = quadrant[lower_quadrant] + 1
      }
    } else if delta_col == 0 {
      let (left_quadrant, right_quadrant) = if delta_row < 0 {
        if goes_out {
          (1, 0)
        } else {
          (0, 1)
        }
      } else if goes_out {
        (3, 2)
      } else {
        (2, 3)
      }

      if curving != "" {
        if curving == "^" {
          quadrant[left_quadrant] = quadrant[left_quadrant] + 1
        } else if curving == "_" {
          quadrant[right_quadrant] = quadrant[right_quadrant] + 1
        }
      } else {
        quadrant[left_quadrant] = quadrant[left_quadrant] + 1
        quadrant[right_quadrant] = quadrant[right_quadrant] + 1
      }
    }
  }

  let mut freest = 0
  for idx in 0..<4 {
    if quadrant[idx] < quadrant[freest] {
      freest = idx
    }
  }

  match freest {
    0 => ("", "^", "r", "u")
    1 => ("", "^", "u", "l")
    2 => ("", "^", "l", "d")
    _ => ("", "^", "d", "r")
  }
}

///|
fn process_horizontal_morphism(
  row : Int,
  col : Int,
  target_col : Int,
  grid : DiagramGrid,
  morphisms_str_info : Map[Morphism, ArrowStringDescription],
  object_coords : Map[Object, (Int, Int)],
) -> (String, String) {
  let mut backwards = false
  let mut start = col
  let mut end_ = target_col
  if end_ < start {
    start = target_col
    end_ = col
    backwards = true
  }

  let up : Array[Morphism] = Array::new()
  let down : Array[Morphism] = Array::new()
  let straight_horizontal : Array[Morphism] = Array::new()

  for k in (start + 1)..<end_ {
    let obj = match grid.get(row, k) {
      Some(value) => value
      None => continue
    }

    for morphism in morphisms_str_info.keys() {
      let (end_row, _) = if morphism.domain() == obj {
        object_coords[morphism.codomain()]
      } else if morphism.codomain() == obj {
        object_coords[morphism.domain()]
      } else {
        continue
      }

      if end_row > row {
        down.push(morphism)
      } else if end_row < row {
        up.push(morphism)
      } else if morphisms_str_info[morphism].curving == "" {
        straight_horizontal.push(morphism)
      }
    }
  }

  if up.length() < down.length() {
    for morphism in straight_horizontal {
      let info = morphisms_str_info[morphism]
      let (_, domain_col) = object_coords[morphism.domain()]
      let (_, codomain_col) = object_coords[morphism.codomain()]
      info.label_position = if domain_col < codomain_col { "_" } else { "^" }
      info.forced_label_position = true
    }
    if backwards {
      ("_", "_")
    } else {
      ("^", "^")
    }
  } else {
    for morphism in straight_horizontal {
      let info = morphisms_str_info[morphism]
      let (_, domain_col) = object_coords[morphism.domain()]
      let (_, codomain_col) = object_coords[morphism.codomain()]
      info.label_position = if domain_col < codomain_col { "^" } else { "_" }
      info.forced_label_position = true
    }
    if backwards {
      ("^", "^")
    } else {
      ("_", "_")
    }
  }
}

///|
fn process_vertical_morphism(
  row : Int,
  col : Int,
  target_row : Int,
  grid : DiagramGrid,
  morphisms_str_info : Map[Morphism, ArrowStringDescription],
  object_coords : Map[Object, (Int, Int)],
) -> (String, String) {
  let mut backwards = false
  let mut start = row
  let mut end_ = target_row
  if end_ < start {
    start = target_row
    end_ = row
    backwards = true
  }

  let left : Array[Morphism] = Array::new()
  let right : Array[Morphism] = Array::new()
  let straight_vertical : Array[Morphism] = Array::new()

  for k in (start + 1)..<end_ {
    let obj = match grid.get(k, col) {
      Some(value) => value
      None => continue
    }

    for morphism in morphisms_str_info.keys() {
      let (_, end_col) = if morphism.domain() == obj {
        object_coords[morphism.codomain()]
      } else if morphism.codomain() == obj {
        object_coords[morphism.domain()]
      } else {
        continue
      }

      if end_col > col {
        right.push(morphism)
      } else if end_col < col {
        left.push(morphism)
      } else if morphisms_str_info[morphism].curving == "" {
        straight_vertical.push(morphism)
      }
    }
  }

  if left.length() < right.length() {
    for morphism in straight_vertical {
      let info = morphisms_str_info[morphism]
      let (domain_row, _) = object_coords[morphism.domain()]
      let (codomain_row, _) = object_coords[morphism.codomain()]
      info.label_position = if domain_row < codomain_row { "^" } else { "_" }
      info.forced_label_position = true
    }
    if backwards {
      ("^", "^")
    } else {
      ("_", "_")
    }
  } else {
    for morphism in straight_vertical {
      let info = morphisms_str_info[morphism]
      let (domain_row, _) = object_coords[morphism.domain()]
      let (codomain_row, _) = object_coords[morphism.codomain()]
      info.label_position = if domain_row < codomain_row { "_" } else { "^" }
      info.forced_label_position = true
    }
    if backwards {
      ("_", "_")
    } else {
      ("^", "^")
    }
  }
}

///|
fn process_morphism(
  drawer : XypicDiagramDrawer,
  grid : DiagramGrid,
  morphism : Morphism,
  object_coords : Map[Object, (Int, Int)],
  morphisms_str_info : Map[Morphism, ArrowStringDescription],
) -> ArrowStringDescription {
  fn repeat_string_cond(
    times : Int,
    str_gt : String,
    str_lt : String,
  ) -> String {
    if times > 0 {
      str_gt.repeat(times)
    } else {
      str_lt.repeat(-times)
    }
  }

  fn count_morphisms_undirected(
    a : Object,
    b : Object,
    morphisms_str_info : Map[Morphism, ArrowStringDescription],
  ) -> Int {
    let mut count = 0
    for morphism in morphisms_str_info.keys() {
      let same = normalize_edge(morphism.domain(), morphism.codomain()) ==
        normalize_edge(a, b)
      if same {
        count += 1
      }
    }
    count
  }

  fn count_morphisms_filtered(
    dom : Object,
    cod : Object,
    curving : String,
    morphisms_str_info : Map[Morphism, ArrowStringDescription],
  ) -> Int {
    let mut count = 0
    for morphism in morphisms_str_info.keys() {
      let info = morphisms_str_info[morphism]
      if morphism.domain() == dom &&
        morphism.codomain() == cod &&
        info.curving == curving {
        count += 1
      }
    }
    count
  }

  let (row, col) = object_coords[morphism.domain()]
  let (target_row, target_col) = object_coords[morphism.codomain()]
  let delta_row = target_row - row
  let delta_col = target_col - col
  let vertical_direction = repeat_string_cond(delta_row, "d", "u")
  let horizontal_direction = repeat_string_cond(delta_col, "r", "l")

  let mut curving = ""
  let mut label_pos = "^"
  let mut looping_start = ""
  let mut looping_end = ""

  if delta_row == 0 && delta_col == 0 {
    let loop_info = process_loop_morphism(
      row, col, grid, morphisms_str_info, object_coords,
    )
    curving = loop_info.0
    label_pos = loop_info.1
    looping_start = loop_info.2
    looping_end = loop_info.3
  } else if delta_row == 0 && Int::abs(col - target_col) > 1 {
    let result = process_horizontal_morphism(
      row, col, target_col, grid, morphisms_str_info, object_coords,
    )
    curving = result.0
    label_pos = result.1
  } else if delta_col == 0 && Int::abs(row - target_row) > 1 {
    let result = process_vertical_morphism(
      row, col, target_row, grid, morphisms_str_info, object_coords,
    )
    curving = result.0
    label_pos = result.1
  }

  let count = count_morphisms_undirected(
    morphism.domain(),
    morphism.codomain(),
    morphisms_str_info,
  )
  let mut curving_amount : Int? = None
  if curving != "" {
    curving_amount = Some(
      drawer.default_curving_amount + count * drawer.default_curving_step,
    )
  } else if count > 0 {
    curving = "^"
    let filtered = count_morphisms_filtered(
      morphism.domain(),
      morphism.codomain(),
      curving,
      morphisms_str_info,
    )
    curving_amount = Some(
      drawer.default_curving_amount + filtered * drawer.default_curving_step,
    )
  }

  let morphism_name = match morphism {
    Identity(obj) => "id_{" + latex_object(obj) + "}"
    Composite(items) => {
      let component_names : Array[String] = Array::new()
      for item in items {
        match item.name() {
          Some(name) => component_names.push(latex_name(name))
          None => component_names.push(latex_name("id"))
        }
      }
      let reversed : Array[String] = Array::new()
      for idx in 0..<component_names.length() {
        reversed.push(component_names[component_names.length() - 1 - idx])
      }
      reversed.join("\\circ ")
    }
    Named(_, _, name) => latex_name(name)
  }

  arrow_string_description(
    drawer.unit,
    curving,
    curving_amount,
    looping_start,
    looping_end,
    horizontal_direction,
    vertical_direction,
    label_pos,
    morphism_name,
  )
}

///|
fn check_free_space_horizontal(
  dom_row : Int,
  dom_col : Int,
  cod_col : Int,
  grid : DiagramGrid,
) -> (Bool, Bool, Bool) {
  let (start, end_, backwards) = if dom_col < cod_col {
    (dom_col, cod_col, false)
  } else {
    (cod_col, dom_col, true)
  }

  let free_up = if dom_row == 0 {
    true
  } else {
    let mut all_present = true
    for col in start..<(end_ + 1) {
      if grid.get(dom_row - 1, col) is None {
        all_present = false
        break
      }
    }
    all_present
  }

  let free_down = if dom_row == grid.height() - 1 {
    true
  } else {
    let mut any_present = false
    for col in start..<(end_ + 1) {
      if grid.get(dom_row + 1, col) is Some(_) {
        any_present = true
        break
      }
    }
    !any_present
  }

  (free_up, free_down, backwards)
}

///|
fn check_free_space_vertical(
  dom_row : Int,
  cod_row : Int,
  dom_col : Int,
  grid : DiagramGrid,
) -> (Bool, Bool, Bool) {
  let (start, end_, backwards) = if dom_row < cod_row {
    (dom_row, cod_row, false)
  } else {
    (cod_row, dom_row, true)
  }

  let free_left = if dom_col == 0 {
    true
  } else {
    let mut any_present = false
    for row in start..<(end_ + 1) {
      if grid.get(row, dom_col - 1) is Some(_) {
        any_present = true
        break
      }
    }
    !any_present
  }

  let free_right = if dom_col == grid.width() - 1 {
    true
  } else {
    let mut any_present = false
    for row in start..<(end_ + 1) {
      if grid.get(row, dom_col + 1) is Some(_) {
        any_present = true
        break
      }
    }
    !any_present
  }

  (free_left, free_right, backwards)
}

///|
fn check_free_space_diagonal(
  dom_row : Int,
  cod_row : Int,
  dom_col : Int,
  cod_col : Int,
  grid : DiagramGrid,
) -> (Bool, Bool, Bool) {
  let mut start_row = dom_row
  let mut start_col = dom_col
  let mut end_row = cod_row
  let mut end_col = cod_col
  let mut backwards = false

  if dom_row < cod_row && dom_col < cod_col {
    start_row = dom_row
    start_col = dom_col
    end_row = cod_row
    end_col = cod_col
    backwards = false
  } else if dom_row > cod_row && dom_col > cod_col {
    start_row = cod_row
    start_col = cod_col
    end_row = dom_row
    end_col = dom_col
    backwards = true
  } else if dom_row < cod_row && dom_col > cod_col {
    start_row = dom_row
    start_col = dom_col
    end_row = cod_row
    end_col = cod_col
    backwards = true
  } else if dom_row > cod_row && dom_col < cod_col {
    start_row = cod_row
    start_col = cod_col
    end_row = dom_row
    end_col = dom_col
    backwards = false
  }

  let total_row = Int::abs(end_row - start_row)
  let total_col = Int::abs(end_col - start_col)
  let mut free_up = true
  let mut free_down = true

  let row_min = if start_row < end_row { start_row } else { end_row }
  let row_max = if start_row > end_row { start_row } else { end_row }
  let col_min = if start_col < end_col { start_col } else { end_col }
  let col_max = if start_col > end_col { start_col } else { end_col }

  for row in row_min..<(row_max + 1) {
    if !free_up && !free_down {
      break
    }
    for col in col_min..<(col_max + 1) {
      if !free_up && !free_down {
        break
      }
      if row == start_row && col == start_col {
        continue
      }
      if grid.get(row, col) is None {
        continue
      }

      if col == start_col {
        free_down = false
        continue
      }

      let lhs = Int::abs(row - start_row) * total_col
      let rhs = total_row * Int::abs(col - start_col)
      if lhs > rhs {
        free_down = false
      } else if lhs < rhs {
        free_up = false
      }
    }
  }

  (free_up, free_down, backwards)
}

///|
fn push_labels_out(
  morphisms_str_info : Map[Morphism, ArrowStringDescription],
  grid : DiagramGrid,
  object_coords : Map[Object, (Int, Int)],
) -> Unit {
  fn set_label_position(
    free1 : Bool,
    free2 : Bool,
    pos1 : String,
    pos2 : String,
    backwards : Bool,
    info : ArrowStringDescription,
  ) -> Unit {
    let (first, second) = if backwards { (pos2, pos1) } else { (pos1, pos2) }
    if free1 && !free2 {
      info.label_position = first
    } else if free2 && !free1 {
      info.label_position = second
    }
  }

  for morphism in morphisms_str_info.keys() {
    let info = morphisms_str_info[morphism]
    if info.curving != "" || info.forced_label_position {
      continue
    }
    if morphism.domain() == morphism.codomain() {
      continue
    }

    let (dom_row, dom_col) = object_coords[morphism.domain()]
    let (cod_row, cod_col) = object_coords[morphism.codomain()]

    if dom_row == cod_row {
      let (free_up, free_down, backwards) = check_free_space_horizontal(
        dom_row, dom_col, cod_col, grid,
      )
      set_label_position(free_up, free_down, "^", "_", backwards, info)
    } else if dom_col == cod_col {
      let (free_left, free_right, backwards) = check_free_space_vertical(
        dom_row, cod_row, dom_col, grid,
      )
      set_label_position(free_left, free_right, "_", "^", backwards, info)
    } else {
      let (free_up, free_down, backwards) = check_free_space_diagonal(
        dom_row, cod_row, dom_col, cod_col, grid,
      )
      set_label_position(free_up, free_down, "^", "_", backwards, info)
    }
  }
}

///|
fn morphism_sort_compare(
  a : Morphism,
  b : Morphism,
  object_coords : Map[Object, (Int, Int)],
) -> Int {
  fn morphism_key(
    morphism : Morphism,
    object_coords : Map[Object, (Int, Int)],
  ) -> (Int, Int, Morphism) {
    let (row, col) = object_coords[morphism.domain()]
    let (target_row, target_col) = object_coords[morphism.codomain()]
    if morphism.domain() == morphism.codomain() {
      (3, 0, morphism)
    } else if target_row == row {
      (1, Int::abs(target_col - col), morphism)
    } else if target_col == col {
      (1, Int::abs(target_row - row), morphism)
    } else {
      (2, 0, morphism)
    }
  }

  let key_a = morphism_key(a, object_coords)
  let key_b = morphism_key(b, object_coords)
  let rank_cmp = key_a.0 - key_b.0
  if rank_cmp != 0 {
    return rank_cmp
  }
  let dist_cmp = key_a.1 - key_b.1
  if dist_cmp != 0 {
    return dist_cmp
  }
  compare_morphism(key_a.2, key_b.2)
}

///|
fn build_xypic_string(
  diagram : Diagram,
  grid : DiagramGrid,
  morphisms : Array[Morphism],
  morphisms_str_info : Map[Morphism, ArrowStringDescription],
  diagram_format : String,
) -> String {
  let object_morphisms : Map[Object, Array[Morphism]] = Map([])
  for obj in diagram.objects {
    object_morphisms[obj] = []
  }
  for morphism in morphisms {
    object_morphisms[morphism.domain()].push(morphism)
  }

  let mut result = "\\xymatrix" + diagram_format + "{\n"
  for row in 0..<grid.height() {
    for col in 0..<grid.width() {
      match grid.get(row, col) {
        Some(obj) => {
          result += latex_object(obj) + " "
          for morphism in object_morphisms[obj] {
            result += Show::to_string(morphisms_str_info[morphism]) + " "
          }
        }
        None => ()
      }
      if col < grid.width() - 1 {
        result += "& "
      }
    }
    if row < grid.height() - 1 {
      result += "\\\\"
    }
    result += "\n"
  }
  result += "}\n"
  result
}

///|
pub fn XypicDiagramDrawer::draw(
  self : XypicDiagramDrawer,
  diagram : Diagram,
  grid : DiagramGrid,
  masked? : Array[Morphism] = [],
  diagram_format? : String = "",
) -> String {
  let morphisms_props : Map[Morphism, Array[String]] = Map([])
  for morphism in grid.morphisms().keys() {
    if masked.any(item => item == morphism) {
      continue
    }
    morphisms_props[morphism] = grid.morphisms()[morphism]
  }

  let object_coords : Map[Object, (Int, Int)] = Map([])
  for row in 0..<grid.height() {
    for col in 0..<grid.width() {
      match grid.get(row, col) {
        Some(obj) => object_coords[obj] = (row, col)
        None => ()
      }
    }
  }

  let morphisms = map_keys_sorted(morphisms_props)
  morphisms.sort_by((a, b) => morphism_sort_compare(a, b, object_coords))

  let morphisms_str_info : Map[Morphism, ArrowStringDescription] = Map([])
  for morphism in morphisms {
    let string_description = process_morphism(
      self, grid, morphism, object_coords, morphisms_str_info,
    )

    match self.default_arrow_formatter {
      Some(formatter) => formatter(string_description)
      None => ()
    }

    for prop in morphisms_props[morphism] {
      if self.arrow_formatters.contains(prop) {
        let formatter = self.arrow_formatters[prop]
        formatter(string_description)
      }
    }

    morphisms_str_info[morphism] = string_description
  }

  push_labels_out(morphisms_str_info, grid, object_coords)
  build_xypic_string(
    diagram, grid, morphisms, morphisms_str_info, diagram_format,
  )
}

///|
pub fn xypic_draw_diagram(
  diagram : Diagram,
  masked? : Array[Morphism] = [],
  diagram_format? : String = "",
  groups? : Array[GridGroup] = [],
  hints? : GridHints = generic_hints(),
) -> String raise CategoryError {
  let grid = diagram_grid(diagram, groups~, hints~)
  let drawer = xypic_diagram_drawer()
  drawer.draw(diagram, grid, masked~, diagram_format~)
}

///|
pub fn preview_diagram(
  _diagram : Diagram,
  _masked? : Array[Morphism] = [],
  _diagram_format? : String = "",
  _groups? : Array[GridGroup] = [],
  _output? : String = "png",
  _viewer? : String? = None,
  _euler? : Bool = true,
  _hints? : GridHints = generic_hints(),
) -> Unit raise CategoryError {
  raise Unsupported(
    "preview_diagram requires an external LaTeX preview backend and is not implemented in symbit.",
  )
}
