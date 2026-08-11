///|
type Point = (Int, Int)

///|
type Edge = (Object, Object)

///|
type Triangle = (Edge, Edge, Edge)

///|
fn normalize_edge(a : Object, b : Object) -> Edge {
  if compare_object(a, b) <= 0 {
    (a, b)
  } else {
    (b, a)
  }
}

///|
fn compare_edge(a : Edge, b : Edge) -> Int {
  let first_cmp = compare_object(a.0, b.0)
  if first_cmp != 0 {
    return first_cmp
  }
  compare_object(a.1, b.1)
}

///|
fn edge_contains(edge : Edge, obj : Object) -> Bool {
  edge.0 == obj || edge.1 == obj
}

///|
fn edge_is_same(a : Edge, b : Edge) -> Bool {
  a.0 == b.0 && a.1 == b.1
}

///|
fn edge_other_object(edge : Edge, obj : Object) -> Object {
  if edge.0 == obj {
    edge.1
  } else {
    edge.0
  }
}

///|
fn edge_common_count(a : Edge, b : Edge) -> Int {
  let mut count = 0
  if edge_contains(b, a.0) {
    count += 1
  }
  if a.1 != a.0 && edge_contains(b, a.1) {
    count += 1
  }
  count
}

///|
fn edge_juxtapose(edge1 : Edge, edge2 : Edge) -> Edge? {
  if edge_is_same(edge1, edge2) {
    return None
  }
  if edge_common_count(edge1, edge2) != 1 {
    return None
  }
  let shared = if edge_contains(edge2, edge1.0) { edge1.0 } else { edge1.1 }
  let left = edge_other_object(edge1, shared)
  let right = edge_other_object(edge2, shared)
  Some(normalize_edge(left, right))
}

///|
fn triangle_edges(triangle : Triangle) -> Array[Edge] {
  [triangle.0, triangle.1, triangle.2]
}

///|
fn normalize_triangle(edge1 : Edge, edge2 : Edge, edge3 : Edge) -> Triangle {
  let edges = [edge1, edge2, edge3]
  edges.sort_by(compare_edge)
  (edges[0], edges[1], edges[2])
}

///|
fn triangle_contains_edge(triangle : Triangle, edge : Edge) -> Bool {
  edge_is_same(triangle.0, edge) ||
  edge_is_same(triangle.1, edge) ||
  edge_is_same(triangle.2, edge)
}

///|
fn triangle_objects(triangle : Triangle) -> Array[Object] {
  normalize_objects([
    triangle.0.0,
    triangle.0.1,
    triangle.1.0,
    triangle.1.1,
    triangle.2.0,
    triangle.2.1,
  ])
}

///|
pub fn compare_triangle(a : Triangle, b : Triangle) -> Int {
  let cmp0 = compare_edge(a.0, b.0)
  if cmp0 != 0 {
    return cmp0
  }
  let cmp1 = compare_edge(a.1, b.1)
  if cmp1 != 0 {
    return cmp1
  }
  compare_edge(a.2, b.2)
}

///|
fn triangle_other_vertex(triangle : Triangle, edge : Edge) -> Object {
  let objs = triangle_objects(triangle)
  for obj in objs {
    if !edge_contains(edge, obj) {
      return obj
    }
  }
  abort("triangle_other_vertex")
}

///|
pub fn[T] growable_grid(width : Int, height : Int) -> GrowableGrid[T] {
  let array_ : Array[Array[T?]] = Array::new()
  for _ in 0..<height {
    let row : Array[T?] = Array::new()
    for _ in 0..<width {
      row.push(None)
    }
    array_.push(row)
  }
  { width_: width, height_: height, array_ }
}

///|
pub fn[T] GrowableGrid::width(self : GrowableGrid[T]) -> Int {
  self.width_
}

///|
pub fn[T] GrowableGrid::height(self : GrowableGrid[T]) -> Int {
  self.height_
}

///|
pub fn[T] GrowableGrid::get(self : GrowableGrid[T], row : Int, col : Int) -> T? {
  self.array_[row][col]
}

///|
pub fn[T] GrowableGrid::set(
  self : GrowableGrid[T],
  row : Int,
  col : Int,
  value : T?,
) -> Unit {
  self.array_[row][col] = value
}

///|
pub fn[T] GrowableGrid::append_row(self : GrowableGrid[T]) -> Unit {
  self.height_ = self.height_ + 1
  let row : Array[T?] = Array::new()
  for _ in 0..<self.width_ {
    row.push(None)
  }
  self.array_.push(row)
}

///|
pub fn[T] GrowableGrid::append_column(self : GrowableGrid[T]) -> Unit {
  self.width_ = self.width_ + 1
  for i in 0..<self.height_ {
    self.array_[i].push(None)
  }
}

///|
pub fn[T] GrowableGrid::prepend_row(self : GrowableGrid[T]) -> Unit {
  self.height_ = self.height_ + 1
  let row : Array[T?] = Array::new()
  for _ in 0..<self.width_ {
    row.push(None)
  }
  self.array_.insert(0, row)
}

///|
pub fn[T] GrowableGrid::prepend_column(self : GrowableGrid[T]) -> Unit {
  self.width_ = self.width_ + 1
  for i in 0..<self.height_ {
    self.array_[i].insert(0, None)
  }
}

///|
pub fn[T] GrowableGrid::rows(self : GrowableGrid[T]) -> Array[Array[T?]] {
  self.array_
}

///|
fn simplify_morphisms(
  morphisms : Map[Morphism, Array[String]],
) -> Map[Morphism, Array[String]] {
  let newmorphisms : Map[Morphism, Array[String]] = Map([])
  for morphism in morphisms.keys() {
    let props = morphisms[morphism]
    match morphism {
      Composite(_) =>
        if props.is_empty() {
          ()
        } else {
          newmorphisms[morphism] = props
        }
      Identity(_) => ()
      _ => newmorphisms[morphism] = props
    }
  }
  newmorphisms
}

///|
fn merge_premises_conclusions(
  premises : Map[Morphism, Array[String]],
  conclusions : Map[Morphism, Array[String]],
) -> Map[Morphism, Array[String]] {
  let merged : Map[Morphism, Array[String]] = Map([])
  for morphism in premises.keys() {
    merged[morphism] = premises[morphism]
  }
  for morphism in conclusions.keys() {
    merged[morphism] = conclusions[morphism]
  }
  merged
}

///|
fn add_edge_append(
  dictionary : Map[Edge, Array[Morphism]],
  edge : Edge,
  elem : Morphism,
) -> Unit {
  if dictionary.contains(edge) {
    dictionary[edge].push(elem)
  } else {
    dictionary[edge] = [elem]
  }
}

///|
fn build_skeleton(
  morphisms : Map[Morphism, Array[String]],
) -> Map[Edge, Array[Morphism]] {
  let edges : Map[Edge, Array[Morphism]] = Map([])
  for morphism in morphisms.keys() {
    add_edge_append(
      edges,
      normalize_edge(morphism.domain(), morphism.codomain()),
      morphism,
    )
  }

  let edges1 : Array[Edge] = map_keys_sorted(edges)
  for w in edges1 {
    for v in edges1 {
      match edge_juxtapose(w, v) {
        Some(wv) => if !edges.contains(wv) { edges[wv] = [] }
        None => ()
      }
    }
  }
  edges
}

///|
fn list_triangles(edges : Map[Edge, Array[Morphism]]) -> Array[Triangle] {
  let triangles : Array[Triangle] = []
  let edge_keys = map_keys_sorted(edges)
  for w in edge_keys {
    for v in edge_keys {
      match edge_juxtapose(w, v) {
        Some(wv) =>
          if edges.contains(wv) {
            let tri = normalize_triangle(w, v, wv)
            if !triangles.any(existing => existing == tri) {
              triangles.push(tri)
            }
          }
        None => ()
      }
    }
  }
  triangles
}

///|
fn drop_redundant_triangles(
  triangles : Array[Triangle],
  skeleton : Map[Edge, Array[Morphism]],
) -> Array[Triangle] {
  let out : Array[Triangle] = []
  for triangle in triangles {
    let mut count = 0
    for edge in triangle_edges(triangle) {
      if !skeleton[edge].is_empty() {
        count += 1
      }
    }
    if count >= 2 {
      out.push(triangle)
    }
  }
  out
}

///|
fn morphism_length(morphism : Morphism) -> Int {
  match morphism {
    Composite(items) => items.length()
    _ => 1
  }
}

///|
fn compute_triangle_min_sizes(
  triangles : Array[Triangle],
  edges : Map[Edge, Array[Morphism]],
) -> Map[Triangle, Int] {
  let triangle_sizes : Map[Triangle, Int] = Map([])
  for triangle in triangles {
    let mut size = 0
    for edge in triangle_edges(triangle) {
      let morphisms = edges[edge]
      if !morphisms.is_empty() {
        let mut max_len = 0
        for morphism in morphisms {
          let length = morphism_length(morphism)
          if length > max_len {
            max_len = length
          }
        }
        size += max_len
      }
    }
    triangle_sizes[triangle] = size
  }
  triangle_sizes
}

///|
fn empty_point(pt : Point, grid : GrowableGrid[Object]) -> Bool {
  if pt.0 < 0 || pt.1 < 0 || pt.0 >= grid.height() || pt.1 >= grid.width() {
    return true
  }
  grid.get(pt.0, pt.1) is None
}

///|
fn put_object(
  coords : Point,
  obj : Object,
  grid : GrowableGrid[Object],
  fringe : Array[(Point, Point)],
) -> Point {
  let mut row = coords.0
  let mut col = coords.1
  let mut offset : Point = (0, 0)

  if row == -1 {
    grid.prepend_row()
    row = 0
    offset = (1, 0)
    for k in 0..<fringe.length() {
      let ((i1, j1), (i2, j2)) = fringe[k]
      fringe[k] = ((i1 + 1, j1), (i2 + 1, j2))
    }
  } else if row == grid.height() {
    grid.append_row()
  }

  if col == -1 {
    col = 0
    offset = (offset.0, 1)
    grid.prepend_column()
    for k in 0..<fringe.length() {
      let ((i1, j1), (i2, j2)) = fringe[k]
      fringe[k] = ((i1, j1 + 1), (i2, j2 + 1))
    }
  } else if col == grid.width() {
    grid.append_column()
  }

  grid.set(row, col, Some(obj))
  offset
}

///|
fn choose_target_cell(
  pt1 : Point,
  pt2 : Point,
  edge : (Point, Point),
  obj : Object,
  skeleton : Map[Edge, Array[Morphism]],
  grid : GrowableGrid[Object],
) -> Point? {
  let pt1_empty = empty_point(pt1, grid)
  let pt2_empty = empty_point(pt2, grid)

  if pt1_empty && pt2_empty {
    let anchor = match grid.get(edge.0.0, edge.0.1) {
      Some(value) => value
      None => abort("choose_target_cell")
    }
    let visible_edge = normalize_edge(anchor, obj)
    if skeleton.contains(visible_edge) && !skeleton[visible_edge].is_empty() {
      return Some(pt1)
    } else {
      return Some(pt2)
    }
  }
  if pt1_empty {
    Some(pt1)
  } else if pt2_empty {
    Some(pt2)
  } else {
    None
  }
}

///|
fn find_triangle_to_weld(
  triangles : Array[Triangle],
  fringe : Array[(Point, Point)],
  grid : GrowableGrid[Object],
) -> (Triangle, (Point, Point))? {
  for triangle in triangles {
    for edge_pts in fringe {
      let obj_a = match grid.get(edge_pts.0.0, edge_pts.0.1) {
        Some(value) => value
        None => continue
      }
      let obj_b = match grid.get(edge_pts.1.0, edge_pts.1.1) {
        Some(value) => value
        None => continue
      }
      if triangle_contains_edge(triangle, normalize_edge(obj_a, obj_b)) {
        return Some((triangle, edge_pts))
      }
    }
  }
  None
}

///|
fn fringe_remove(fringe : Array[(Point, Point)], item : (Point, Point)) -> Unit {
  for i in 0..<fringe.length() {
    if fringe[i] == item {
      ignore(fringe.remove(i))
      return
    }
  }
}

///|
fn weld_triangle(
  triangle : Triangle,
  welding_edge : (Point, Point),
  fringe : Array[(Point, Point)],
  grid : GrowableGrid[Object],
  skeleton : Map[Edge, Array[Morphism]],
) -> Bool {
  let mut a = welding_edge.0
  let mut b = welding_edge.1
  let obj_a = match grid.get(a.0, a.1) {
    Some(value) => value
    None => abort("weld_triangle:a")
  }
  let obj_b = match grid.get(b.0, b.1) {
    Some(value) => value
    None => abort("weld_triangle:b")
  }
  let edge = normalize_edge(obj_a, obj_b)
  let obj = triangle_other_vertex(triangle, edge)
  let mut target_cell : Point? = None

  if Int::abs(a.0 - b.0) == 1 && Int::abs(a.1 - b.1) == 1 {
    let first = (a.0, b.1)
    match grid.get(first.0, first.1) {
      Some(_) => {
        let second = (b.0, a.1)
        match grid.get(second.0, second.1) {
          Some(_) => {
            fringe_remove(fringe, (a, b))
            return true
          }
          None => target_cell = Some(second)
        }
      }
      None => target_cell = Some(first)
    }
  } else if a.0 == b.0 {
    let down_left = (a.0 + 1, a.1)
    let down_right = (a.0 + 1, b.1)
    target_cell = choose_target_cell(
      down_left,
      down_right,
      (a, b),
      obj,
      skeleton,
      grid,
    )
    if target_cell is None {
      let up_left = (a.0 - 1, a.1)
      let up_right = (a.0 - 1, b.1)
      target_cell = choose_target_cell(
        up_left,
        up_right,
        (a, b),
        obj,
        skeleton,
        grid,
      )
      if target_cell is None {
        fringe_remove(fringe, (a, b))
        return true
      }
    }
  } else if a.1 == b.1 {
    let right_up = (a.0, a.1 + 1)
    let right_down = (b.0, a.1 + 1)
    target_cell = choose_target_cell(
      right_up,
      right_down,
      (a, b),
      obj,
      skeleton,
      grid,
    )
    if target_cell is None {
      let left_up = (a.0, a.1 - 1)
      let left_down = (b.0, a.1 - 1)
      target_cell = choose_target_cell(
        left_up,
        left_down,
        (a, b),
        obj,
        skeleton,
        grid,
      )
      if target_cell is None {
        fringe_remove(fringe, (a, b))
        return true
      }
    }
  }

  let target = match target_cell {
    Some(value) => value
    None => abort("weld_triangle:target")
  }
  let offset = put_object(target, obj, grid, fringe)
  let shifted_target = (target.0 + offset.0, target.1 + offset.1)
  a = (a.0 + offset.0, a.1 + offset.1)
  b = (b.0 + offset.0, b.1 + offset.1)
  fringe.push((a, shifted_target))
  fringe.push((b, shifted_target))
  false
}

///|
fn triangle_key(
  triangle : Triangle,
  triangle_sizes : Map[Triangle, Int],
) -> (Int, Array[Object]) {
  (triangle_sizes[triangle], triangle_objects(triangle))
}

///|
fn pick_root_edge(
  triangle : Triangle,
  skeleton : Map[Edge, Array[Morphism]],
) -> Edge {
  let candidates : Array[Edge] = Array::new()
  for edge in triangle_edges(triangle) {
    if !skeleton[edge].is_empty() {
      candidates.push(edge)
    }
  }
  candidates.sort_by(compare_edge)
  candidates[0]
}

///|
fn drop_irrelevant_triangles(
  triangles : Array[Triangle],
  placed_objects : Map[Object, Bool],
) -> Array[Triangle] {
  let out : Array[Triangle] = Array::new()
  for triangle in triangles {
    let objs = triangle_objects(triangle)
    let mut all_placed = true
    for obj in objs {
      if !placed_objects.contains(obj) {
        all_placed = false
        break
      }
    }
    if !all_placed {
      out.push(triangle)
    }
  }
  out
}

///|
fn grow_pseudopod(
  triangles : Array[Triangle],
  fringe : Array[(Point, Point)],
  grid : GrowableGrid[Object],
  skeleton : Map[Edge, Array[Morphism]],
  placed_objects : Map[Object, Bool],
) -> Object? {
  for i in 0..<grid.height() {
    for j in 0..<grid.width() {
      let obj = match grid.get(i, j) {
        Some(value) => value
        None => continue
      }

      let tris : Array[Triangle] = Array::new()
      for triangle in triangles {
        let objs = triangle_objects(triangle)
        if !contains_object(objs, obj) {
          continue
        }
        let mut compatible = true
        for triangle_obj in objs {
          if triangle_obj != obj && placed_objects.contains(triangle_obj) {
            compatible = false
            break
          }
        }
        if compatible {
          tris.push(triangle)
        }
      }
      if tris.is_empty() {
        continue
      }

      let triangle = tris[0]
      let candidates : Array[Edge] = Array::new()
      for edge in triangle_edges(triangle) {
        if !skeleton[edge].is_empty() {
          candidates.push(edge)
        }
      }
      candidates.sort_by(compare_edge)

      let edges : Array[Edge] = Array::new()
      for edge in candidates {
        if edge_contains(edge, obj) {
          edges.push(edge)
        }
      }
      if edges.is_empty() {
        continue
      }

      let other_obj = edge_other_object(edges[0], obj)
      let neighbours : Array[Point] = [
        (i - 1, j),
        (i, j + 1),
        (i + 1, j),
        (i, j - 1),
        (i - 1, j - 1),
        (i - 1, j + 1),
        (i + 1, j - 1),
        (i + 1, j + 1),
      ]

      for pt in neighbours {
        if empty_point(pt, grid) {
          let offset = put_object(pt, other_obj, grid, fringe)
          let updated_origin = (i + offset.0, j + offset.1)
          let updated_pt = (pt.0 + offset.0, pt.1 + offset.1)
          fringe.push((updated_origin, updated_pt))
          return Some(other_obj)
        }
      }
    }
  }
  None
}

///|
fn group_placeholder(layout : GroupLayout) -> Object {
  let name = "__group__[" + layout.objects.map(obj => obj.name).join("|") + "]"
  object(name)
}

///|
fn handle_groups(
  source_diagram : Diagram,
  groups : Array[GridGroup],
  merged_morphisms : Map[Morphism, Array[String]],
  hints : GridHints,
) -> DiagramGrid raise CategoryError {
  let obj_groups : Map[Object, Object] = Map([])
  let groups_grids : Map[Object, DiagramGrid] = Map([])
  let top_groups : Array[Object] = Array::new()

  for group in groups {
    match group {
      Single(obj) => {
        obj_groups[obj] = obj
        if !top_groups.any(existing => existing == obj) {
          top_groups.push(obj)
        }
      }
      Group(layout) => {
        let placeholder = group_placeholder(layout)
        for obj in layout.objects {
          obj_groups[obj] = placeholder
        }
        if !top_groups.any(existing => existing == placeholder) {
          top_groups.push(placeholder)
        }
        let local_hints = match layout.hints {
          Some(value) => value
          None => hints
        }
        groups_grids[placeholder] = diagram_grid(
          source_diagram.subdiagram_from_objects(layout.objects),
          hints=local_hints,
        )
      }
    }
  }

  for obj in source_diagram.objects {
    if !obj_groups.contains(obj) {
      obj_groups[obj] = obj
      if !top_groups.any(existing => existing == obj) {
        top_groups.push(obj)
      }
    }
  }

  let new_morphisms : Array[Morphism] = Array::new()
  for morphism in merged_morphisms.keys() {
    let dom = obj_groups[morphism.domain()]
    let cod = obj_groups[morphism.codomain()]
    if dom != cod {
      new_morphisms.push(named_morphism(dom, cod, "dummy"))
    }
  }

  let top_diag = diagram(premises=List(new_morphisms))
  let top_grid = diagram_grid(top_diag)

  fn group_size(
    obj : Object?,
    groups_grids : Map[Object, DiagramGrid],
  ) -> (Int, Int) {
    match obj {
      Some(value) =>
        if groups_grids.contains(value) {
          let grid = groups_grids[value]
          (grid.height(), grid.width())
        } else {
          (1, 1)
        }
      None => (1, 1)
    }
  }

  let row_heights : Array[Int] = Array::new()
  for i in 0..<top_grid.height() {
    let mut row_height = 1
    for j in 0..<top_grid.width() {
      let size = group_size(top_grid.get(i, j), groups_grids)
      if size.0 > row_height {
        row_height = size.0
      }
    }
    row_heights.push(row_height)
  }

  let column_widths : Array[Int] = Array::new()
  for j in 0..<top_grid.width() {
    let mut column_width = 1
    for i in 0..<top_grid.height() {
      let size = group_size(top_grid.get(i, j), groups_grids)
      if size.1 > column_width {
        column_width = size.1
      }
    }
    column_widths.push(column_width)
  }

  let total_width = column_widths.fold(init=0, (acc, value) => acc + value)
  let total_height = row_heights.fold(init=0, (acc, value) => acc + value)
  let grid : GrowableGrid[Object] = growable_grid(total_width, total_height)

  let mut real_row = 0
  for logical_row in 0..<top_grid.height() {
    let mut real_column = 0
    for logical_column in 0..<top_grid.width() {
      match top_grid.get(logical_row, logical_column) {
        Some(obj) =>
          if groups_grids.contains(obj) {
            let local_grid = groups_grids[obj]
            for i in 0..<local_grid.height() {
              for j in 0..<local_grid.width() {
                grid.set(real_row + i, real_column + j, local_grid.get(i, j))
              }
            }
          } else {
            grid.set(real_row, real_column, Some(obj))
          }
        None => ()
      }
      real_column += column_widths[logical_column]
    }
    real_row += row_heights[logical_row]
  }

  {
    grid_: grid,
    morphisms_: merge_premises_conclusions(
      simplify_morphisms(source_diagram.premises),
      simplify_morphisms(source_diagram.conclusions),
    ),
  }
}

///|
fn generic_layout(
  diagram : Diagram,
  merged_morphisms : Map[Morphism, Array[String]],
) -> GrowableGrid[Object] raise CategoryError {
  let all_objects = normalize_objects(diagram.objects)
  if all_objects.length() == 1 {
    let grid : GrowableGrid[Object] = growable_grid(1, 1)
    grid.set(0, 0, Some(all_objects[0]))
    return grid
  }

  let skeleton = build_skeleton(merged_morphisms)
  let grid : GrowableGrid[Object] = growable_grid(2, 1)

  if skeleton.length() == 1 {
    grid.set(0, 0, Some(all_objects[0]))
    grid.set(0, 1, Some(all_objects[1]))
    return grid
  }

  let triangle_sizes = compute_triangle_min_sizes(
    drop_redundant_triangles(list_triangles(skeleton), skeleton),
    skeleton,
  )
  let triangles = drop_redundant_triangles(list_triangles(skeleton), skeleton)
  triangles.sort_by((a, b) => {
    let key_a = triangle_key(a, triangle_sizes)
    let key_b = triangle_key(b, triangle_sizes)
    let size_cmp = key_a.0 - key_b.0
    if size_cmp != 0 {
      size_cmp
    } else {
      compare_object_arrays(key_a.1, key_b.1)
    }
  })

  let root_edge = pick_root_edge(triangles[0], skeleton)
  grid.set(0, 0, Some(root_edge.0))
  grid.set(0, 1, Some(root_edge.1))
  let fringe : Array[(Point, Point)] = [((0, 0), (0, 1))]
  let placed_objects : Map[Object, Bool] = Map([])
  placed_objects[root_edge.0] = true
  placed_objects[root_edge.1] = true
  let mut active_triangles = triangles

  while placed_objects.length() != all_objects.length() {
    match find_triangle_to_weld(active_triangles, fringe, grid) {
      Some((triangle, welding_edge)) => {
        let restart_required = weld_triangle(
          triangle, welding_edge, fringe, grid, skeleton,
        )
        if restart_required {
          continue
        }
        for obj in triangle_objects(triangle) {
          placed_objects[obj] = true
        }
      }
      None =>
        match
          grow_pseudopod(
            active_triangles, fringe, grid, skeleton, placed_objects,
          ) {
          Some(new_obj) => placed_objects[new_obj] = true
          None => {
            let remaining_objects : Array[Object] = Array::new()
            for obj in all_objects {
              if !placed_objects.contains(obj) {
                remaining_objects.push(obj)
              }
            }
            let remaining_diagram = diagram.subdiagram_from_objects(
              remaining_objects,
            )
            let remaining_grid = diagram_grid(remaining_diagram).grid_
            let final_width = grid.width() + remaining_grid.width()
            let final_height = if grid.height() > remaining_grid.height() {
              grid.height()
            } else {
              remaining_grid.height()
            }
            let final_grid : GrowableGrid[Object] = growable_grid(
              final_width, final_height,
            )
            for i in 0..<grid.height() {
              for j in 0..<grid.width() {
                final_grid.set(i, j, grid.get(i, j))
              }
            }
            let start_j = grid.width()
            for i in 0..<remaining_grid.height() {
              for j in 0..<remaining_grid.width() {
                final_grid.set(i, start_j + j, remaining_grid.get(i, j))
              }
            }
            return final_grid
          }
        }
    }

    active_triangles = drop_irrelevant_triangles(
      active_triangles, placed_objects,
    )
  }

  grid
}

///|
fn get_undirected_graph(
  objects : Array[Object],
  merged_morphisms : Map[Morphism, Array[String]],
) -> Map[Object, Array[Object]] {
  let adjlists : Map[Object, Array[Object]] = Map([])
  for obj in objects {
    adjlists[obj] = []
  }

  for morphism in merged_morphisms.keys() {
    adjlists[morphism.domain()].push(morphism.codomain())
    adjlists[morphism.codomain()].push(morphism.domain())
  }

  for obj in objects {
    let neighbors = normalize_objects(adjlists[obj])
    adjlists[obj] = neighbors
  }
  adjlists
}

///|
fn sequential_layout(
  diagram : Diagram,
  merged_morphisms : Map[Morphism, Array[String]],
) -> GrowableGrid[Object] {
  let objects = normalize_objects(diagram.objects)
  let adjlists = get_undirected_graph(objects, merged_morphisms)

  let mut root = objects[0]
  for obj in objects {
    if adjlists[obj].length() < adjlists[root].length() {
      root = obj
    }
  }

  let grid : GrowableGrid[Object] = growable_grid(1, 1)
  grid.set(0, 0, Some(root))
  let placed_objects : Map[Object, Bool] = Map([])
  placed_objects[root] = true

  fn place_objects(
    pt : Point,
    placed_objects : Map[Object, Bool],
    adjlists : Map[Object, Array[Object]],
    grid : GrowableGrid[Object],
  ) -> Unit {
    let current = match grid.get(pt.0, pt.1) {
      Some(value) => value
      None => return
    }
    let mut new_pt = (pt.0, pt.1 + 1)
    for adjacent_obj in adjlists[current] {
      if placed_objects.contains(adjacent_obj) {
        continue
      }
      ignore(put_object(new_pt, adjacent_obj, grid, []))
      placed_objects[adjacent_obj] = true
      place_objects(new_pt, placed_objects, adjlists, grid)
      new_pt = (new_pt.0 + 1, new_pt.1)
    }
  }

  place_objects((0, 0), placed_objects, adjlists, grid)
  grid
}

///|
fn drop_inessential_morphisms(
  merged_morphisms : Map[Morphism, Array[String]],
) -> Map[Morphism, Array[String]] {
  let morphisms : Map[Morphism, Array[String]] = Map([])
  for morphism in merged_morphisms.keys() {
    if morphism.domain() != morphism.codomain() {
      morphisms[morphism] = merged_morphisms[morphism]
    }
  }
  morphisms
}

///|
fn get_connected_components(
  objects : Array[Object],
  merged_morphisms : Map[Morphism, Array[String]],
) -> Array[Diagram] raise CategoryError {
  let component_index : Map[Object, Int] = Map([])
  for obj in objects {
    component_index[obj] = -1
  }

  let adjlist = get_undirected_graph(objects, merged_morphisms)

  fn traverse_component(
    obj : Object,
    current_index : Int,
    component_index : Map[Object, Int],
    adjlist : Map[Object, Array[Object]],
  ) -> Unit {
    component_index[obj] = current_index
    for other in adjlist[obj] {
      if component_index[other] == -1 {
        traverse_component(other, current_index, component_index, adjlist)
      }
    }
  }

  let mut current_index = 0
  for obj in objects {
    if component_index[obj] == -1 {
      traverse_component(obj, current_index, component_index, adjlist)
      current_index += 1
    }
  }

  let component_objects : Array[Array[Object]] = Array::new()
  for _ in 0..<current_index {
    component_objects.push([])
  }
  for obj in objects {
    component_objects[component_index[obj]].push(obj)
  }

  let component_morphisms : Array[Diagram] = Array::new()
  for component in component_objects {
    let current_morphisms : Map[Morphism, Array[String]] = Map([])
    for morphism in merged_morphisms.keys() {
      if contains_object(component, morphism.domain()) &&
        contains_object(component, morphism.codomain()) {
        current_morphisms[morphism] = merged_morphisms[morphism]
      }
    }
    if component.length() == 1 {
      current_morphisms[identity_morphism(component[0])] = []
    }
    component_morphisms.push(diagram(premises=Props(current_morphisms)))
  }
  component_morphisms
}

///|
fn transpose_grid(grid : GrowableGrid[Object]) -> GrowableGrid[Object] {
  let out : GrowableGrid[Object] = growable_grid(grid.height(), grid.width())
  for i in 0..<grid.height() {
    for j in 0..<grid.width() {
      out.set(j, i, grid.get(i, j))
    }
  }
  out
}

///|
pub fn diagram_grid(
  diagram : Diagram,
  groups? : Array[GridGroup] = [],
  hints? : GridHints = generic_hints(),
) -> DiagramGrid raise CategoryError {
  let premises = simplify_morphisms(diagram.premises)
  let conclusions = simplify_morphisms(diagram.conclusions)
  let all_merged_morphisms = merge_premises_conclusions(premises, conclusions)
  let merged_morphisms = drop_inessential_morphisms(all_merged_morphisms)
  let components = get_connected_components(
    diagram.objects,
    all_merged_morphisms,
  )

  let mut laid_out : GrowableGrid[Object] = growable_grid(1, 1)
  if !groups.is_empty() {
    let grouped = handle_groups(diagram, groups, merged_morphisms, hints)
    laid_out = grouped.grid_
  } else if components.length() > 1 {
    components.sort_by(compare_diagram)
    let grids : Array[DiagramGrid] = Array::new()
    for component in components {
      grids.push(diagram_grid(component, hints~))
    }
    let total_width = grids.fold(init=0, (acc, value) => acc + value.width())
    let mut total_height = 0
    for grid in grids {
      if grid.height() > total_height {
        total_height = grid.height()
      }
    }
    laid_out = growable_grid(total_width, total_height)
    let mut start_j = 0
    for g in grids {
      for i in 0..<g.height() {
        for j in 0..<g.width() {
          laid_out.set(i, start_j + j, g.get(i, j))
        }
      }
      start_j += g.width()
    }
  } else {
    laid_out = match hints.layout {
      Sequential => sequential_layout(diagram, merged_morphisms)
      Generic => generic_layout(diagram, merged_morphisms)
    }
  }

  if hints.transpose {
    laid_out = transpose_grid(laid_out)
  }

  { grid_: laid_out, morphisms_: all_merged_morphisms }
}

///|
pub fn DiagramGrid::width(self : DiagramGrid) -> Int {
  self.grid_.width()
}

///|
pub fn DiagramGrid::height(self : DiagramGrid) -> Int {
  self.grid_.height()
}

///|
pub fn DiagramGrid::get(self : DiagramGrid, row : Int, col : Int) -> Object? {
  self.grid_.get(row, col)
}

///|
pub fn DiagramGrid::morphisms(
  self : DiagramGrid,
) -> Map[Morphism, Array[String]] {
  self.morphisms_
}

///|
fn show_grid_row(row : Array[Object?]) -> String {
  let items : Array[String] = Array::new()
  for cell in row {
    match cell {
      Some(obj) => items.push(Show::to_string(obj))
      None => items.push("None")
    }
  }
  "[" + items.join(", ") + "]"
}

///|
pub impl Show for DiagramGrid with fn to_string(self) -> String {
  "[" + self.grid_.rows().map(show_grid_row).join(", ") + "]"
}

///|
pub impl Show for DiagramGrid with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}
