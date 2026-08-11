///|
/// Request-scoped oracle helpers for SymPy combinatorics.

///|
priv enum CombinatoricsArg {
  CNull
  CBoolean(Bool)
  CInteger(Int)
  CText(String)
  CList(Array[CombinatoricsArg])
}

///|
fn CombinatoricsArg::materialize(
  self : CombinatoricsArg,
  builder : @recipe.Builder,
) -> @recipe.RecipeArg raise {
  match self {
    CNull => Null
    CBoolean(value) => Bool(value)
    CInteger(value) => DecimalInt(Show::to_string(value))
    CText(value) => Str(value)
    CList(values) => {
      let items : Array[@recipe.RecipeArg] = []
      for value in values {
        items.push(value.materialize(builder))
      }
      Ref(builder.list(items))
    }
  }
}

///|
fn int_list_arg(values : Array[Int]) -> CombinatoricsArg {
  CList(values.map(value => CInteger(value)))
}

///|
fn text_list_arg(values : Array[String]) -> CombinatoricsArg {
  CList(values.map(value => CText(value)))
}

///|
fn int_matrix_arg(values : Array[Array[Int]]) -> CombinatoricsArg {
  CList(values.map(value => int_list_arg(value)))
}

///|
fn int_cube_arg(values : Array[Array[Array[Int]]]) -> CombinatoricsArg {
  CList(values.map(value => int_matrix_arg(value)))
}

///|
fn pair_list_arg(values : Array[(Int, Int)]) -> CombinatoricsArg {
  CList(values.map(value => CList([CInteger(value.0), CInteger(value.1)])))
}

///|
fn pair_matrix_arg(values : Array[Array[(Int, Int)]]) -> CombinatoricsArg {
  CList(values.map(value => pair_list_arg(value)))
}

///|
fn optional_int_arg(value : Int?) -> CombinatoricsArg {
  match value {
    Some(value) => CInteger(value)
    None => CNull
  }
}

///|
fn optional_text_arg(value : String?) -> CombinatoricsArg {
  match value {
    Some(value) => CText(value)
    None => CNull
  }
}

///|
fn optional_int_list_arg(value : Array[Int]?) -> CombinatoricsArg {
  match value {
    Some(value) => int_list_arg(value)
    None => CNull
  }
}

///|
fn nullable_int_list_arg(values : Array[Int?]) -> CombinatoricsArg {
  CList(values.map(value => optional_int_arg(value)))
}

///|
fn combinatorics_source() -> String {
  let source =
    #|def _int_value(value):
    #|    return int(str(value))
    #|
    #|def _int_list_equal(ours, values):
    #|    values = list(values)
    #|    if len(ours) != len(values):
    #|        return False
    #|    return all(ours[i] == _int_value(values[i]) for i in range(len(ours)))
    #|
    #|def _int_matrix_equal(ours, values):
    #|    values = list(values)
    #|    if len(ours) != len(values):
    #|        return False
    #|    return all(_int_list_equal(ours[i], list(values[i])) for i in range(len(ours)))
    #|
    #|def _unordered_int_matrix_equal(ours, values):
    #|    values = list(values)
    #|    if len(ours) != len(values):
    #|        return False
    #|    ours_keys = sorted(','.join(str(item) for item in row) for row in ours)
    #|    value_keys = sorted(','.join(str(item) for item in list(row)) for row in values)
    #|    return ours_keys == value_keys
    #|
    #|def _int_cube_equal(ours, values):
    #|    values = list(values)
    #|    if len(ours) != len(values):
    #|        return False
    #|    return all(_int_matrix_equal(ours[i], values[i]) for i in range(len(ours)))
    #|
    #|def _string_list_equal(ours, values):
    #|    values = list(values)
    #|    if len(ours) != len(values):
    #|        return False
    #|    return all(ours[i] == str(values[i]) for i in range(len(ours)))
    #|
    #|def _pair_list_equal(ours, values):
    #|    values = list(values)
    #|    if len(ours) != len(values):
    #|        return False
    #|    for i, item in enumerate(values):
    #|        parts = list(item)
    #|        if len(parts) != 2:
    #|            return False
    #|        if ours[i][0] != _int_value(parts[0]) or ours[i][1] != _int_value(parts[1]):
    #|            return False
    #|    return True
    #|
    #|def _unordered_pair_list_equal(ours, values):
    #|    ours_keys = sorted(str(pair[0]) + ',' + str(pair[1]) for pair in ours)
    #|    value_keys = []
    #|    for item in list(values):
    #|        parts = list(item)
    #|        if len(parts) == 2:
    #|            left = _int_value(parts[0])
    #|            right = _int_value(parts[1])
    #|            low, high = (left, right) if left < right else (right, left)
    #|            value_keys.append(str(low) + ',' + str(high))
    #|    return ours_keys == sorted(value_keys)
    #|
    #|def _dict_pairs_equal(ours, value):
    #|    pairs = [(_int_value(key), _int_value(item)) for key, item in value.items()]
    #|    pairs.sort(key=lambda pair: pair[0])
    #|    if len(ours) != len(pairs):
    #|        return False
    #|    return all(ours[i][0] == pairs[i][0] and ours[i][1] == pairs[i][1] for i in range(len(ours)))
    #|
    #|def _permutation(array, size):
    #|    from sympy.combinatorics.permutations import Permutation
    #|    if size is None:
    #|        return Permutation(array)
    #|    return Permutation(array, size=size)
    #|
    #|def _permutation_cycles(cycles, size):
    #|    from sympy.combinatorics.permutations import Permutation
    #|    if size is None:
    #|        return Permutation(cycles)
    #|    return Permutation(cycles, size=size)
    #|
    #|def _permutation_list(arrays):
    #|    return [_permutation(array, None) for array in arrays]
    #|
    #|def _permutation_arrays(values):
    #|    return [list(value.array_form) for value in list(values)]
    #|
    #|def _permutation_group(generators):
    #|    from sympy.combinatorics.perm_groups import PermutationGroup
    #|    return PermutationGroup(_permutation_list(generators))
    #|
    #|def _permutation_group_elements(group):
    #|    return list(group.generate_dimino(af=True))
    #|
    #|def _polyhedron(name):
    #|    import sympy.combinatorics.polyhedron as module
    #|    return getattr(module, name)
    #|
    #|def _free_group_tuple(symbols):
    #|    from sympy.combinatorics.free_groups import free_group
    #|    return free_group(', '.join(symbols))
    #|
    #|def _free_group_word(symbols, form):
    #|    items = _free_group_tuple(symbols)
    #|    group = items[0]
    #|    symbol_items = list(group.symbols)
    #|    if len(form) == 0:
    #|        return group.dtype()
    #|    for pair in form:
    #|        if not 0 <= pair[0] < len(symbol_items):
    #|            raise IndexError('free-group symbol index out of range')
    #|    pairs = [(symbol_items[pair[0]], pair[1]) for pair in form]
    #|    return group.dtype(pairs)
    #|
    #|def _free_group_named_form(symbols, word):
    #|    result = []
    #|    for item in list(word.array_form):
    #|        parts = list(item)
    #|        if len(parts) != 2:
    #|            continue
    #|        name_text = str(parts[0])
    #|        try:
    #|            index = int(name_text)
    #|        except Exception:
    #|            name = name_text
    #|        else:
    #|            name = symbols[index] if 0 <= index < len(symbols) else name_text
    #|        result.append((name, _int_value(parts[1])))
    #|    return result
    #|
    #|def _free_group_expected_form(symbols, form):
    #|    return [(symbols[pair[0]], pair[1]) for pair in form if 0 <= pair[0] < len(symbols)]
    #|
    #|def _free_group_form_equal(symbols, form, word):
    #|    return _free_group_expected_form(symbols, form) == _free_group_named_form(symbols, word)
    #|
    #|def _tensor_component(base, generators, count, symmetry):
    #|    return (base, _permutation_list(generators), count, symmetry)
    #|
    #|def graycode_generate(n, ours, start, rank):
    #|    from sympy.combinatorics.graycode import GrayCode
    #|    kwargs = {}
    #|    if start is not None:
    #|        kwargs['start'] = start
    #|    if rank is not None:
    #|        kwargs['rank'] = rank
    #|    return _string_list_equal(ours, list(GrayCode(n).generate_gray(**kwargs)))
    #|
    #|def graycode_rank(n, start, ours):
    #|    from sympy.combinatorics.graycode import GrayCode
    #|    return str(GrayCode(n, start=start).rank) == str(ours)
    #|
    #|def gray_to_bin_value(bits, ours):
    #|    from sympy.combinatorics.graycode import gray_to_bin
    #|    return str(gray_to_bin(bits)) == ours
    #|
    #|def bin_to_gray_value(bits, ours):
    #|    from sympy.combinatorics.graycode import bin_to_gray
    #|    return str(bin_to_gray(bits)) == ours
    #|
    #|def graycode_subsets_value(items, ours):
    #|    from sympy.combinatorics.graycode import graycode_subsets
    #|    return _int_matrix_equal(ours, list(graycode_subsets(items)))
    #|
    #|def ksubsets_value(superset, size, ours):
    #|    from sympy.combinatorics.subsets import ksubsets
    #|    return _int_matrix_equal(ours, list(ksubsets(superset, size)))
    #|
    #|def subset_rank(subset, superset, ours_binary, ours_lexicographic, ours_gray):
    #|    from sympy.combinatorics.subsets import Subset
    #|    value = Subset(subset, superset)
    #|    return (str(value.rank_binary) == str(ours_binary)
    #|            and str(value.rank_lexicographic) == str(ours_lexicographic)
    #|            and str(value.rank_gray) == str(ours_gray))
    #|
    #|def subset_next_prev(subset, superset, ours_next, ours_previous):
    #|    from sympy.combinatorics.subsets import Subset
    #|    value = Subset(subset, superset)
    #|    return (_int_list_equal(ours_next, value.next_binary().subset)
    #|            and _int_list_equal(ours_previous, value.prev_binary().subset))
    #|
    #|def prufer_tree(sequence, ours):
    #|    from sympy.combinatorics.prufer import Prufer
    #|    return _int_matrix_equal(ours, Prufer(sequence).tree_repr)
    #|
    #|def prufer_sequence(edges, ours):
    #|    from sympy.combinatorics.prufer import Prufer
    #|    return _int_list_equal(ours, Prufer(edges).prufer_repr)
    #|
    #|def prufer_rank(sequence, ours):
    #|    from sympy.combinatorics.prufer import Prufer
    #|    return str(Prufer(sequence).rank) == str(ours)
    #|
    #|def integer_partition_conjugate(partition, ours):
    #|    from sympy.combinatorics.partitions import IntegerPartition
    #|    return _int_list_equal(ours, IntegerPartition(partition).conjugate)
    #|
    #|def integer_partition_next_prev(partition, ours_next, ours_previous):
    #|    from sympy.combinatorics.partitions import IntegerPartition
    #|    value = IntegerPartition(partition)
    #|    return (_int_list_equal(ours_next, value.next_lex().partition)
    #|            and _int_list_equal(ours_previous, value.prev_lex().partition))
    #|
    #|def rgs_rank_value(rgs, ours):
    #|    from sympy.combinatorics.partitions import RGS_rank
    #|    return str(RGS_rank(rgs)) == str(ours)
    #|
    #|def rgs_unrank_value(rank, size, ours):
    #|    from sympy.combinatorics.partitions import RGS_unrank
    #|    return _int_list_equal(ours, RGS_unrank(rank, size))
    #|
    #|def partition_rgs(blocks, ours_rgs, ours_rank):
    #|    from sympy.combinatorics.partitions import Partition
    #|    value = Partition(*blocks)
    #|    return (_int_list_equal(ours_rgs, value.RGS)
    #|            and str(value.rank) == str(ours_rank))
    #|
    #|def permutation_array_form(array, ours, size):
    #|    return _int_list_equal(ours, _permutation(array, size).array_form)
    #|
    #|def permutation_cycles_array_form(cycles, ours, size):
    #|    return _int_list_equal(ours, _permutation_cycles(cycles, size).array_form)
    #|
    #|def permutation_cyclic_form(array, ours, size):
    #|    return _int_matrix_equal(ours, _permutation(array, size).cyclic_form)
    #|
    #|def permutation_full_cyclic_form(array, ours, size):
    #|    return _int_matrix_equal(ours, _permutation(array, size).full_cyclic_form)
    #|
    #|def permutation_cycle_structure(array, ours, size):
    #|    return _dict_pairs_equal(ours, _permutation(array, size).cycle_structure)
    #|
    #|def permutation_parity(array, ours, size):
    #|    return str(_permutation(array, size).parity()) == str(ours)
    #|
    #|def permutation_order(array, ours, size):
    #|    return str(_permutation(array, size).order()) == str(ours)
    #|
    #|def permutation_rank(array, ours, size):
    #|    return str(_permutation(array, size).rank()) == str(ours)
    #|
    #|def permutation_inversion_vector(array, ours, size):
    #|    return _int_list_equal(ours, _permutation(array, size).inversion_vector())
    #|
    #|def permutation_transpositions(array, ours, size):
    #|    return _pair_list_equal(ours, _permutation(array, size).transpositions())
    #|
    #|def permutation_unrank_lex(size, rank, ours):
    #|    from sympy.combinatorics.permutations import Permutation
    #|    return _int_list_equal(ours, Permutation.unrank_lex(size, rank).array_form)
    #|
    #|def permutation_next_lex(array, has_value, ours):
    #|    value = _permutation(array, None).next_lex()
    #|    if value is None:
    #|        raise ValueError('py-call-none')
    #|    if not has_value:
    #|        return False
    #|    return _int_list_equal(ours, value.array_form)
    #|
    #|def permutation_apply_array(array, values, ours, size):
    #|    return _string_list_equal(ours, _permutation(array, size)(values))
    #|
    #|def permutation_from_sequence(sequence, ours):
    #|    from sympy.combinatorics.permutations import Permutation
    #|    return _int_list_equal(ours, Permutation.from_sequence(sequence).array_form)
    #|
    #|def generators_symmetric(size, ours):
    #|    from sympy.combinatorics.generators import symmetric
    #|    return _unordered_int_matrix_equal(ours, list(symmetric(size)))
    #|
    #|def generators_cyclic(size, ours):
    #|    from sympy.combinatorics.generators import cyclic
    #|    return _unordered_int_matrix_equal(ours, list(cyclic(size)))
    #|
    #|def generators_alternating(size, ours):
    #|    from sympy.combinatorics.generators import alternating
    #|    return _unordered_int_matrix_equal(ours, list(alternating(size)))
    #|
    #|def generators_dihedral(size, ours):
    #|    from sympy.combinatorics.generators import dihedral
    #|    return _unordered_int_matrix_equal(ours, list(dihedral(size)))
    #|
    #|def permutation_group_elements(generators, ours):
    #|    return _unordered_int_matrix_equal(ours, _permutation_group_elements(_permutation_group(generators)))
    #|
    #|def permutation_group_order(generators, ours):
    #|    return str(_permutation_group(generators).order()) == str(ours)
    #|
    #|def named_group_elements(kind, size, ours):
    #|    import sympy.combinatorics.named_groups as module
    #|    group = getattr(module, kind)(size)
    #|    return _unordered_int_matrix_equal(ours, _permutation_group_elements(group))
    #|
    #|def named_group_order(kind, size, ours):
    #|    import sympy.combinatorics.named_groups as module
    #|    return str(getattr(module, kind)(size).order()) == str(ours)
    #|
    #|def abelian_group_elements(orders, ours):
    #|    from sympy.combinatorics.named_groups import AbelianGroup
    #|    return _unordered_int_matrix_equal(ours, _permutation_group_elements(AbelianGroup(*orders)))
    #|
    #|def group_number_nilpotent(value, ours):
    #|    from sympy.combinatorics.group_numbers import is_nilpotent_number
    #|    try:
    #|        result = is_nilpotent_number(value)
    #|    except Exception:
    #|        return False
    #|    return str(result) == ('True' if ours else 'False')
    #|
    #|def group_number_abelian(value, ours):
    #|    from sympy.combinatorics.group_numbers import is_abelian_number
    #|    try:
    #|        result = is_abelian_number(value)
    #|    except Exception:
    #|        return False
    #|    return str(result) == ('True' if ours else 'False')
    #|
    #|def group_number_cyclic(value, ours):
    #|    from sympy.combinatorics.group_numbers import is_cyclic_number
    #|    try:
    #|        result = is_cyclic_number(value)
    #|    except Exception:
    #|        return False
    #|    return str(result) == ('True' if ours else 'False')
    #|
    #|def group_number_count(value, ours_ok, ours_value):
    #|    from sympy.combinatorics.group_numbers import groups_count
    #|    try:
    #|        result = groups_count(value)
    #|    except Exception:
    #|        return not ours_ok
    #|    return ours_ok and str(result) == ours_value
    #|
    #|def schur_number_value(size, has_value, value):
    #|    from sympy.combinatorics.schur_number import SchurNumber
    #|    expected = str(value) if has_value else 'SchurNumber(' + str(size) + ')'
    #|    return str(SchurNumber(size)) == expected
    #|
    #|def schur_number_lower_bound(size, value):
    #|    from sympy.combinatorics.schur_number import SchurNumber
    #|    return str(SchurNumber(size).lower_bound()) == str(value)
    #|
    #|def schur_partition_value(size, ours):
    #|    from sympy.combinatorics.schur_number import schur_partition
    #|    return _int_matrix_equal(ours, schur_partition(size))
    #|
    #|def galois_group_elements(name, ours):
    #|    import sympy.combinatorics.galois as module
    #|    group = getattr(module, name)()
    #|    return _unordered_int_matrix_equal(ours, _permutation_group_elements(group))
    #|
    #|def galois_enum_group_elements(enum_name, member_name, ours):
    #|    import sympy.combinatorics.galois as module
    #|    group = getattr(getattr(module, enum_name), member_name).get_perm_group()
    #|    return _unordered_int_matrix_equal(ours, _permutation_group_elements(group))
    #|
    #|def polyhedron_corners(name, ours):
    #|    return _string_list_equal(ours, _polyhedron(name).corners)
    #|
    #|def polyhedron_faces(name, ours):
    #|    return _unordered_int_matrix_equal(ours, list(_polyhedron(name).faces))
    #|
    #|def polyhedron_edges(name, ours):
    #|    return _unordered_pair_list_equal(ours, list(_polyhedron(name).edges))
    #|
    #|def polyhedron_group_elements(name, ours):
    #|    return _unordered_int_matrix_equal(ours, _permutation_group_elements(_polyhedron(name).pgroup))
    #|
    #|def polyhedron_array_form_index(name, index, ours):
    #|    value = _polyhedron(name).copy()
    #|    try:
    #|        value.rotate(index)
    #|    except Exception:
    #|        pass
    #|    return _int_list_equal(ours, value.array_form)
    #|
    #|def polyhedron_array_form_permutation(name, array, ours):
    #|    value = _polyhedron(name).copy()
    #|    try:
    #|        value.rotate(_permutation(array, None))
    #|    except Exception:
    #|        pass
    #|    return _int_list_equal(ours, value.array_form)
    #|
    #|def polyhedron_cyclic_form_index(name, index, ours):
    #|    value = _polyhedron(name).copy()
    #|    try:
    #|        value.rotate(index)
    #|    except Exception:
    #|        pass
    #|    return _int_matrix_equal(ours, value.cyclic_form)
    #|
    #|def util_base_ordering(base, degree, ours):
    #|    from sympy.combinatorics.util import _base_ordering
    #|    return _int_list_equal(ours, _base_ordering(base, degree))
    #|
    #|def free_group_multiply(symbols, form_a, form_b, ours):
    #|    left = _free_group_word(symbols, form_a)
    #|    right = _free_group_word(symbols, form_b)
    #|    return _free_group_form_equal(symbols, ours, left.__mul__(right))
    #|
    #|def free_group_power(symbols, form, exponent, ours):
    #|    return _free_group_form_equal(symbols, ours, pow(_free_group_word(symbols, form), exponent))
    #|
    #|def free_group_inverse(symbols, form, ours):
    #|    return _free_group_form_equal(symbols, ours, _free_group_word(symbols, form).inverse())
    #|
    #|def free_group_subword(symbols, form, start, end, ours):
    #|    return _free_group_form_equal(symbols, ours, _free_group_word(symbols, form).subword(start, end))
    #|
    #|def fp_group_reduce(symbols, relators, word_form, ours):
    #|    from sympy.combinatorics.fp_groups import FpGroup
    #|    group = _free_group_tuple(symbols)[0]
    #|    fp_group = FpGroup(group, [_free_group_word(symbols, relator) for relator in relators])
    #|    reduced = fp_group.reduce(_free_group_word(symbols, word_form))
    #|    return _free_group_form_equal(symbols, ours, reduced)
    #|
    #|def fp_group_coset_table(symbols, relators, subgroup, strategy, ours):
    #|    from sympy.combinatorics.fp_groups import FpGroup, coset_enumeration_c, coset_enumeration_r
    #|    group = _free_group_tuple(symbols)[0]
    #|    fp_group = FpGroup(group, [_free_group_word(symbols, relator) for relator in relators])
    #|    subgroup_words = [_free_group_word(symbols, word) for word in subgroup]
    #|    enumerate_cosets = coset_enumeration_c if strategy == 'coset_table_based' else coset_enumeration_r
    #|    table = enumerate_cosets(fp_group, subgroup_words)
    #|    try:
    #|        table.compress()
    #|    except Exception:
    #|        pass
    #|    try:
    #|        table.standardize()
    #|    except Exception:
    #|        pass
    #|    return _int_matrix_equal(ours, table.table)
    #|
    #|def util_check_cycles(array, ours):
    #|    from sympy.combinatorics.util import _check_cycles_alt_sym
    #|    return str(_check_cycles_alt_sym(_permutation(array, None))) == ('True' if ours else 'False')
    #|
    #|def util_distribute_gens(base, generators, ours):
    #|    from sympy.combinatorics.util import _distribute_gens_by_base
    #|    values = _distribute_gens_by_base(base, _permutation_list(generators))
    #|    arrays = [_permutation_arrays(part) for part in list(values)]
    #|    return _int_cube_equal(ours, arrays)
    #|
    #|def util_strong_gens(distributed, ours):
    #|    from sympy.combinatorics.util import _strong_gens_from_distr
    #|    values = [_permutation_list(part) for part in distributed]
    #|    return _int_matrix_equal(ours, _permutation_arrays(_strong_gens_from_distr(values)))
    #|
    #|def tensor_dummy_sgs(dummies, symmetry, size, ours):
    #|    from sympy.combinatorics.tensor_can import dummy_sgs
    #|    return _int_matrix_equal(ours, dummy_sgs(dummies, symmetry, size))
    #|
    #|def tensor_min_dummies(dummies, symmetries, indices, ours):
    #|    from sympy.combinatorics.tensor_can import _min_dummies
    #|    return _int_list_equal(ours, _min_dummies(dummies, symmetries, indices))
    #|
    #|def tensor_symmetric_group(size, antisymmetric, ours_base, ours_generators):
    #|    from sympy.combinatorics.tensor_can import get_symmetric_group_sgs
    #|    parts = list(get_symmetric_group_sgs(size, antisymmetric))
    #|    if len(parts) != 2 or not _int_list_equal(ours_base, parts[0]):
    #|        return False
    #|    return _int_matrix_equal(ours_generators, _permutation_arrays(parts[1]))
    #|
    #|def tensor_perm_af_direct_product(gens1, gens2, signed, ours):
    #|    from sympy.combinatorics.tensor_can import perm_af_direct_product
    #|    return _int_matrix_equal(ours, perm_af_direct_product(gens1, gens2, signed))
    #|
    #|def tensor_bsgs_direct_product(base1, gens1, base2, gens2, signed, ours_base, ours_gens):
    #|    from sympy.combinatorics.tensor_can import bsgs_direct_product
    #|    parts = list(bsgs_direct_product(base1, _permutation_list(gens1), base2, _permutation_list(gens2), signed))
    #|    if len(parts) != 2 or not _int_list_equal(ours_base, parts[0]):
    #|        return False
    #|    return _int_matrix_equal(ours_gens, _permutation_arrays(parts[1]))
    #|
    #|def tensor_gens_value(base, generators, list_free, symmetry, ours_size, ours_base, ours_generators):
    #|    from sympy.combinatorics.tensor_can import tensor_gens
    #|    parts = list(tensor_gens(base, _permutation_list(generators), list_free, symmetry))
    #|    if len(parts) != 3 or type(parts[0]) is not int or parts[0] != ours_size:
    #|        return False
    #|    if not _int_list_equal(ours_base, parts[1]):
    #|        return False
    #|    return _int_matrix_equal(ours_generators, _permutation_arrays(parts[2]))
    #|
    #|def tensor_canonical_free(base, generators, permutation, num_free, ours):
    #|    from sympy.combinatorics.tensor_can import canonical_free
    #|    value = canonical_free(base, _permutation_list(generators), _permutation(permutation, None), num_free)
    #|    return _int_list_equal(ours, value)
    #|
    #|def tensor_double_coset(dummies, symmetries, base, generators, permutation, ours):
    #|    from sympy.combinatorics.tensor_can import double_coset_can_rep, get_transversals
    #|    generator_objects = _permutation_list(generators)
    #|    transversals = get_transversals(base, generator_objects)
    #|    value = double_coset_can_rep(dummies, symmetries, base, generator_objects, transversals, _permutation(permutation, None))
    #|    if type(value) is int:
    #|        return value == 0 and ours is None
    #|    return ours is not None and _int_list_equal(ours, value)
    #|
    #|def tensor_canonicalize(dummies, msym, permutation, bases, generators, counts, symmetries, ours):
    #|    from sympy.combinatorics.tensor_can import canonicalize
    #|    components = [_tensor_component(bases[i], generators[i], counts[i], symmetries[i]) for i in range(len(counts))]
    #|    value = canonicalize(_permutation(permutation, None), dummies, msym, *components)
    #|    if type(value) is int:
    #|        return value == 0 and ours is None
    #|    return ours is not None and _int_list_equal(ours, value)
  source
}

///|
fn combinatorics_call(
  helper_name : String,
  args : Array[CombinatoricsArg],
) -> Bool raise {
  let builder = @recipe.Builder::new()
  let builtins = builder.import_module("builtins")
  let scope = builder.dict([(Str("__builtins__"), Ref(builtins))])
  let scope = builder.exec(scope, combinatorics_source())
  let callable = builder.getitem(scope, Str(helper_name))
  let call_args : Array[@recipe.RecipeArg] = []
  for argument in args {
    call_args.push(argument.materialize(builder))
  }
  let result = builder.call(callable, call_args)
  builder.request_bool(result)
}

///|
pub fn graycode_generate_equiv(
  n : Int,
  ours : Array[String],
  start? : String,
  rank? : Int,
) -> Bool raise {
  combinatorics_call("graycode_generate", [
    CInteger(n),
    text_list_arg(ours),
    optional_text_arg(start),
    optional_int_arg(rank),
  ])
}

///|
pub fn graycode_rank_equiv(n : Int, start : String, ours : Int) -> Bool raise {
  combinatorics_call("graycode_rank", [
    CInteger(n),
    CText(start),
    CInteger(ours),
  ])
}

///|
pub fn gray_to_bin_equiv(bits : String, ours : String) -> Bool raise {
  combinatorics_call("gray_to_bin_value", [CText(bits), CText(ours)])
}

///|
pub fn bin_to_gray_equiv(bits : String, ours : String) -> Bool raise {
  combinatorics_call("bin_to_gray_value", [CText(bits), CText(ours)])
}

///|
pub fn graycode_subsets_equiv(
  items : Array[Int],
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("graycode_subsets_value", [
    int_list_arg(items),
    int_matrix_arg(ours),
  ])
}

///|
pub fn ksubsets_equiv(
  superset : Array[Int],
  k : Int,
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("ksubsets_value", [
    int_list_arg(superset),
    CInteger(k),
    int_matrix_arg(ours),
  ])
}

///|
pub fn subset_rank_equiv(
  subset : Array[Int],
  superset : Array[Int],
  ours_bin : Int,
  ours_lex : Int,
  ours_gray : Int,
) -> Bool raise {
  combinatorics_call("subset_rank", [
    int_list_arg(subset),
    int_list_arg(superset),
    CInteger(ours_bin),
    CInteger(ours_lex),
    CInteger(ours_gray),
  ])
}

///|
pub fn subset_next_prev_equiv(
  subset : Array[Int],
  superset : Array[Int],
  ours_next : Array[Int],
  ours_prev : Array[Int],
) -> Bool raise {
  combinatorics_call("subset_next_prev", [
    int_list_arg(subset),
    int_list_arg(superset),
    int_list_arg(ours_next),
    int_list_arg(ours_prev),
  ])
}

///|
pub fn prufer_equiv_tree(
  seq : Array[Int],
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("prufer_tree", [int_list_arg(seq), int_matrix_arg(ours)])
}

///|
pub fn prufer_equiv_sequence(
  edges : Array[Array[Int]],
  ours : Array[Int],
) -> Bool raise {
  combinatorics_call("prufer_sequence", [
    int_matrix_arg(edges),
    int_list_arg(ours),
  ])
}

///|
pub fn prufer_rank_equiv(seq : Array[Int], ours : Int) -> Bool raise {
  combinatorics_call("prufer_rank", [int_list_arg(seq), CInteger(ours)])
}

///|
pub fn integer_partition_conjugate_equiv(
  part : Array[Int],
  ours : Array[Int],
) -> Bool raise {
  combinatorics_call("integer_partition_conjugate", [
    int_list_arg(part),
    int_list_arg(ours),
  ])
}

///|
pub fn integer_partition_next_prev_equiv(
  part : Array[Int],
  ours_next : Array[Int],
  ours_prev : Array[Int],
) -> Bool raise {
  combinatorics_call("integer_partition_next_prev", [
    int_list_arg(part),
    int_list_arg(ours_next),
    int_list_arg(ours_prev),
  ])
}

///|
pub fn rgs_rank_equiv(rgs : Array[Int], ours : Int) -> Bool raise {
  combinatorics_call("rgs_rank_value", [int_list_arg(rgs), CInteger(ours)])
}

///|
pub fn rgs_unrank_equiv(rank : Int, m : Int, ours : Array[Int]) -> Bool raise {
  combinatorics_call("rgs_unrank_value", [
    CInteger(rank),
    CInteger(m),
    int_list_arg(ours),
  ])
}

///|
pub fn partition_rgs_equiv(
  blocks : Array[Array[Int]],
  ours_rgs : Array[Int],
  ours_rank : Int,
) -> Bool raise {
  combinatorics_call("partition_rgs", [
    int_matrix_arg(blocks),
    int_list_arg(ours_rgs),
    CInteger(ours_rank),
  ])
}

///|
pub fn perm_array_form_equiv_from_array(
  array : Array[Int],
  ours : Array[Int],
  size? : Int,
) -> Bool raise {
  combinatorics_call("permutation_array_form", [
    int_list_arg(array),
    int_list_arg(ours),
    optional_int_arg(size),
  ])
}

///|
pub fn perm_array_form_equiv_from_cycles(
  cycles : Array[Array[Int]],
  ours : Array[Int],
  size? : Int,
) -> Bool raise {
  combinatorics_call("permutation_cycles_array_form", [
    int_matrix_arg(cycles),
    int_list_arg(ours),
    optional_int_arg(size),
  ])
}

///|
pub fn perm_cyclic_form_equiv_from_array(
  array : Array[Int],
  ours : Array[Array[Int]],
  size? : Int,
) -> Bool raise {
  combinatorics_call("permutation_cyclic_form", [
    int_list_arg(array),
    int_matrix_arg(ours),
    optional_int_arg(size),
  ])
}

///|
pub fn perm_full_cyclic_form_equiv_from_array(
  array : Array[Int],
  ours : Array[Array[Int]],
  size? : Int,
) -> Bool raise {
  combinatorics_call("permutation_full_cyclic_form", [
    int_list_arg(array),
    int_matrix_arg(ours),
    optional_int_arg(size),
  ])
}

///|
pub fn perm_cycle_structure_equiv_from_array(
  array : Array[Int],
  ours : Array[(Int, Int)],
  size? : Int,
) -> Bool raise {
  combinatorics_call("permutation_cycle_structure", [
    int_list_arg(array),
    pair_list_arg(ours),
    optional_int_arg(size),
  ])
}

///|
pub fn perm_parity_equiv_from_array(
  array : Array[Int],
  ours : Int,
  size? : Int,
) -> Bool raise {
  combinatorics_call("permutation_parity", [
    int_list_arg(array),
    CInteger(ours),
    optional_int_arg(size),
  ])
}

///|
pub fn perm_order_equiv_from_array(
  array : Array[Int],
  ours : Int,
  size? : Int,
) -> Bool raise {
  combinatorics_call("permutation_order", [
    int_list_arg(array),
    CInteger(ours),
    optional_int_arg(size),
  ])
}

///|
pub fn perm_rank_equiv_from_array(
  array : Array[Int],
  ours : Int,
  size? : Int,
) -> Bool raise {
  combinatorics_call("permutation_rank", [
    int_list_arg(array),
    CInteger(ours),
    optional_int_arg(size),
  ])
}

///|
pub fn perm_inversion_vector_equiv_from_array(
  array : Array[Int],
  ours : Array[Int],
  size? : Int,
) -> Bool raise {
  combinatorics_call("permutation_inversion_vector", [
    int_list_arg(array),
    int_list_arg(ours),
    optional_int_arg(size),
  ])
}

///|
pub fn perm_transpositions_equiv_from_array(
  array : Array[Int],
  ours : Array[(Int, Int)],
  size? : Int,
) -> Bool raise {
  combinatorics_call("permutation_transpositions", [
    int_list_arg(array),
    pair_list_arg(ours),
    optional_int_arg(size),
  ])
}

///|
pub fn perm_unrank_lex_equiv(
  size : Int,
  rank : Int,
  ours : Array[Int],
) -> Bool raise {
  combinatorics_call("permutation_unrank_lex", [
    CInteger(size),
    CInteger(rank),
    int_list_arg(ours),
  ])
}

///|
pub fn perm_next_lex_equiv(
  array : Array[Int],
  has_value : Bool,
  ours : Array[Int],
) -> Bool raise {
  combinatorics_call("permutation_next_lex", [
    int_list_arg(array),
    CBoolean(has_value),
    int_list_arg(ours),
  ])
}

///|
pub fn perm_apply_array_equiv(
  array : Array[Int],
  values : Array[String],
  ours : Array[String],
  size? : Int,
) -> Bool raise {
  combinatorics_call("permutation_apply_array", [
    int_list_arg(array),
    text_list_arg(values),
    text_list_arg(ours),
    optional_int_arg(size),
  ])
}

///|
pub fn perm_from_sequence_string_equiv(
  seq : String,
  ours : Array[Int],
) -> Bool raise {
  combinatorics_call("permutation_from_sequence", [
    CText(seq),
    int_list_arg(ours),
  ])
}

///|
pub fn generators_symmetric_equiv(
  n : Int,
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("generators_symmetric", [CInteger(n), int_matrix_arg(ours)])
}

///|
pub fn generators_cyclic_equiv(n : Int, ours : Array[Array[Int]]) -> Bool raise {
  combinatorics_call("generators_cyclic", [CInteger(n), int_matrix_arg(ours)])
}

///|
pub fn generators_alternating_equiv(
  n : Int,
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("generators_alternating", [
    CInteger(n),
    int_matrix_arg(ours),
  ])
}

///|
pub fn generators_dihedral_equiv(
  n : Int,
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("generators_dihedral", [CInteger(n), int_matrix_arg(ours)])
}

///|
pub fn perm_group_elements_equiv_from_gens(
  gens : Array[Array[Int]],
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("permutation_group_elements", [
    int_matrix_arg(gens),
    int_matrix_arg(ours),
  ])
}

///|
pub fn perm_group_order_equiv_from_gens(
  gens : Array[Array[Int]],
  ours : Int,
) -> Bool raise {
  combinatorics_call("permutation_group_order", [
    int_matrix_arg(gens),
    CInteger(ours),
  ])
}

///|
pub fn named_group_elements_equiv(
  kind : String,
  n : Int,
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("named_group_elements", [
    CText(kind),
    CInteger(n),
    int_matrix_arg(ours),
  ])
}

///|
pub fn named_group_order_equiv(
  kind : String,
  n : Int,
  ours : Int,
) -> Bool raise {
  combinatorics_call("named_group_order", [
    CText(kind),
    CInteger(n),
    CInteger(ours),
  ])
}

///|
pub fn abelian_group_elements_equiv(
  orders : Array[Int],
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("abelian_group_elements", [
    int_list_arg(orders),
    int_matrix_arg(ours),
  ])
}

///|
pub fn group_numbers_is_nilpotent_equiv(n : Int, ours : Bool) -> Bool raise {
  combinatorics_call("group_number_nilpotent", [CInteger(n), CBoolean(ours)])
}

///|
pub fn group_numbers_is_abelian_equiv(n : Int, ours : Bool) -> Bool raise {
  combinatorics_call("group_number_abelian", [CInteger(n), CBoolean(ours)])
}

///|
pub fn group_numbers_is_cyclic_equiv(n : Int, ours : Bool) -> Bool raise {
  combinatorics_call("group_number_cyclic", [CInteger(n), CBoolean(ours)])
}

///|
pub fn group_numbers_groups_count_equiv(
  n : Int,
  ours_ok : Bool,
  ours_value : String,
) -> Bool raise {
  combinatorics_call("group_number_count", [
    CInteger(n),
    CBoolean(ours_ok),
    CText(ours_value),
  ])
}

///|
pub fn schur_number_equiv(k : Int, has_value : Bool, value : Int) -> Bool raise {
  combinatorics_call("schur_number_value", [
    CInteger(k),
    CBoolean(has_value),
    CInteger(value),
  ])
}

///|
pub fn schur_number_lower_bound_equiv(k : Int, value : Int) -> Bool raise {
  combinatorics_call("schur_number_lower_bound", [CInteger(k), CInteger(value)])
}

///|
pub fn schur_partition_equiv(n : Int, ours : Array[Array[Int]]) -> Bool raise {
  combinatorics_call("schur_partition_value", [
    CInteger(n),
    int_matrix_arg(ours),
  ])
}

///|
pub fn galois_group_elements_equiv(
  name : String,
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("galois_group_elements", [
    CText(name),
    int_matrix_arg(ours),
  ])
}

///|
pub fn galois_enum_group_elements_equiv(
  enum_name : String,
  member_name : String,
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("galois_enum_group_elements", [
    CText(enum_name),
    CText(member_name),
    int_matrix_arg(ours),
  ])
}

///|
pub fn polyhedron_corners_equiv(
  name : String,
  ours : Array[String],
) -> Bool raise {
  combinatorics_call("polyhedron_corners", [CText(name), text_list_arg(ours)])
}

///|
pub fn polyhedron_faces_equiv(
  name : String,
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("polyhedron_faces", [CText(name), int_matrix_arg(ours)])
}

///|
pub fn polyhedron_edges_equiv(
  name : String,
  ours : Array[(Int, Int)],
) -> Bool raise {
  combinatorics_call("polyhedron_edges", [CText(name), pair_list_arg(ours)])
}

///|
pub fn polyhedron_pgroup_elements_equiv(
  name : String,
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("polyhedron_group_elements", [
    CText(name),
    int_matrix_arg(ours),
  ])
}

///|
pub fn polyhedron_array_form_equiv_index(
  name : String,
  idx : Int,
  ours : Array[Int],
) -> Bool raise {
  combinatorics_call("polyhedron_array_form_index", [
    CText(name),
    CInteger(idx),
    int_list_arg(ours),
  ])
}

///|
pub fn polyhedron_array_form_equiv_perm(
  name : String,
  perm_array : Array[Int],
  ours : Array[Int],
) -> Bool raise {
  combinatorics_call("polyhedron_array_form_permutation", [
    CText(name),
    int_list_arg(perm_array),
    int_list_arg(ours),
  ])
}

///|
pub fn polyhedron_cyclic_form_equiv_index(
  name : String,
  idx : Int,
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("polyhedron_cyclic_form_index", [
    CText(name),
    CInteger(idx),
    int_matrix_arg(ours),
  ])
}

///|
pub fn util_base_ordering_equiv(
  base : Array[Int],
  degree : Int,
  ours : Array[Int],
) -> Bool raise {
  combinatorics_call("util_base_ordering", [
    int_list_arg(base),
    CInteger(degree),
    int_list_arg(ours),
  ])
}

///|
pub fn free_group_mul_equiv(
  symbols : Array[String],
  form_a : Array[(Int, Int)],
  form_b : Array[(Int, Int)],
  ours_form : Array[(Int, Int)],
) -> Bool raise {
  combinatorics_call("free_group_multiply", [
    text_list_arg(symbols),
    pair_list_arg(form_a),
    pair_list_arg(form_b),
    pair_list_arg(ours_form),
  ])
}

///|
pub fn free_group_pow_equiv(
  symbols : Array[String],
  form_a : Array[(Int, Int)],
  n : Int,
  ours_form : Array[(Int, Int)],
) -> Bool raise {
  combinatorics_call("free_group_power", [
    text_list_arg(symbols),
    pair_list_arg(form_a),
    CInteger(n),
    pair_list_arg(ours_form),
  ])
}

///|
pub fn free_group_inverse_equiv(
  symbols : Array[String],
  form_a : Array[(Int, Int)],
  ours_form : Array[(Int, Int)],
) -> Bool raise {
  combinatorics_call("free_group_inverse", [
    text_list_arg(symbols),
    pair_list_arg(form_a),
    pair_list_arg(ours_form),
  ])
}

///|
pub fn free_group_subword_equiv(
  symbols : Array[String],
  form_a : Array[(Int, Int)],
  from_i : Int,
  to_j : Int,
  ours_form : Array[(Int, Int)],
) -> Bool raise {
  combinatorics_call("free_group_subword", [
    text_list_arg(symbols),
    pair_list_arg(form_a),
    CInteger(from_i),
    CInteger(to_j),
    pair_list_arg(ours_form),
  ])
}

///|
pub fn fp_group_reduce_equiv(
  symbols : Array[String],
  relator_forms : Array[Array[(Int, Int)]],
  word_form : Array[(Int, Int)],
  ours_form : Array[(Int, Int)],
) -> Bool raise {
  combinatorics_call("fp_group_reduce", [
    text_list_arg(symbols),
    pair_matrix_arg(relator_forms),
    pair_list_arg(word_form),
    pair_list_arg(ours_form),
  ])
}

///|
pub fn fp_group_coset_table_equiv(
  symbols : Array[String],
  relator_forms : Array[Array[(Int, Int)]],
  subgroup_forms : Array[Array[(Int, Int)]],
  strategy : String,
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("fp_group_coset_table", [
    text_list_arg(symbols),
    pair_matrix_arg(relator_forms),
    pair_matrix_arg(subgroup_forms),
    CText(strategy),
    int_matrix_arg(ours),
  ])
}

///|
pub fn util_check_cycles_alt_sym_equiv(
  perm_array : Array[Int],
  ours : Bool,
) -> Bool raise {
  combinatorics_call("util_check_cycles", [
    int_list_arg(perm_array),
    CBoolean(ours),
  ])
}

///|
pub fn util_distribute_gens_by_base_equiv(
  base : Array[Int],
  gens : Array[Array[Int]],
  ours : Array[Array[Array[Int]]],
) -> Bool raise {
  combinatorics_call("util_distribute_gens", [
    int_list_arg(base),
    int_matrix_arg(gens),
    int_cube_arg(ours),
  ])
}

///|
pub fn util_strong_gens_from_distr_equiv(
  strong_gens_distr : Array[Array[Array[Int]]],
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("util_strong_gens", [
    int_cube_arg(strong_gens_distr),
    int_matrix_arg(ours),
  ])
}

///|
pub fn tensor_can_dummy_sgs_equiv(
  dummies : Array[Int],
  sym : Int?,
  n : Int,
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("tensor_dummy_sgs", [
    int_list_arg(dummies),
    optional_int_arg(sym),
    CInteger(n),
    int_matrix_arg(ours),
  ])
}

///|
pub fn tensor_can_min_dummies_equiv(
  dummies : Array[Array[Int]],
  sym : Array[Int?],
  indices : Array[Int],
  ours : Array[Int],
) -> Bool raise {
  combinatorics_call("tensor_min_dummies", [
    int_matrix_arg(dummies),
    nullable_int_list_arg(sym),
    int_list_arg(indices),
    int_list_arg(ours),
  ])
}

///|
pub fn tensor_can_symmetric_group_equiv(
  n : Int,
  antisym : Bool,
  base : Array[Int],
  gens : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("tensor_symmetric_group", [
    CInteger(n),
    CBoolean(antisym),
    int_list_arg(base),
    int_matrix_arg(gens),
  ])
}

///|
pub fn tensor_can_perm_af_direct_product_equiv(
  gens1 : Array[Array[Int]],
  gens2 : Array[Array[Int]],
  signed : Bool,
  ours : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("tensor_perm_af_direct_product", [
    int_matrix_arg(gens1),
    int_matrix_arg(gens2),
    CBoolean(signed),
    int_matrix_arg(ours),
  ])
}

///|
pub fn tensor_can_bsgs_direct_product_equiv(
  base1 : Array[Int],
  gens1 : Array[Array[Int]],
  base2 : Array[Int],
  gens2 : Array[Array[Int]],
  signed : Bool,
  ours_base : Array[Int],
  ours_gens : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("tensor_bsgs_direct_product", [
    int_list_arg(base1),
    int_matrix_arg(gens1),
    int_list_arg(base2),
    int_matrix_arg(gens2),
    CBoolean(signed),
    int_list_arg(ours_base),
    int_matrix_arg(ours_gens),
  ])
}

///|
pub fn tensor_can_tensor_gens_equiv(
  base : Array[Int],
  gens : Array[Array[Int]],
  list_free : Array[Array[Int]],
  sym : Int?,
  ours_size : Int,
  ours_base : Array[Int],
  ours_gens : Array[Array[Int]],
) -> Bool raise {
  combinatorics_call("tensor_gens_value", [
    int_list_arg(base),
    int_matrix_arg(gens),
    int_matrix_arg(list_free),
    optional_int_arg(sym),
    CInteger(ours_size),
    int_list_arg(ours_base),
    int_matrix_arg(ours_gens),
  ])
}

///|
pub fn tensor_can_canonical_free_equiv(
  base : Array[Int],
  gens : Array[Array[Int]],
  g : Array[Int],
  num_free : Int,
  ours : Array[Int],
) -> Bool raise {
  combinatorics_call("tensor_canonical_free", [
    int_list_arg(base),
    int_matrix_arg(gens),
    int_list_arg(g),
    CInteger(num_free),
    int_list_arg(ours),
  ])
}

///|
pub fn tensor_can_double_coset_can_rep_equiv(
  dummies : Array[Array[Int]],
  sym : Array[Int?],
  base : Array[Int],
  sgens : Array[Array[Int]],
  g : Array[Int],
  ours : Array[Int]?,
) -> Bool raise {
  combinatorics_call("tensor_double_coset", [
    int_matrix_arg(dummies),
    nullable_int_list_arg(sym),
    int_list_arg(base),
    int_matrix_arg(sgens),
    int_list_arg(g),
    optional_int_list_arg(ours),
  ])
}

///|
pub fn tensor_can_canonicalize_equiv(
  dummies : Array[Array[Int]],
  msym : Array[Int?],
  g : Array[Int],
  bases : Array[Array[Int]],
  gens_list : Array[Array[Array[Int]]],
  counts : Array[Int],
  syms : Array[Int?],
  ours : Array[Int]?,
) -> Bool raise {
  combinatorics_call("tensor_canonicalize", [
    int_matrix_arg(dummies),
    nullable_int_list_arg(msym),
    int_list_arg(g),
    int_matrix_arg(bases),
    int_cube_arg(gens_list),
    int_list_arg(counts),
    nullable_int_list_arg(syms),
    optional_int_list_arg(ours),
  ])
}
