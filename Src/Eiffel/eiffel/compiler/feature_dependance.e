﻿note
	description: "Dependance between features."
	legal: "See notice at end of class."
	status: "See notice at end of class."
	date: "$Date$"
	revision: "$Revision$"

class
	FEATURE_DEPENDANCE

inherit
	TWO_WAY_SORTED_SET [DEPEND_UNIT]
		export
			{FEATURE_DEPENDANCE} all
			{ANY} cursor, go_to, start, before, after, forth, item, active,
				count, first_element, last_element, new_cursor, object_comparison, sublist,
				extend, prunable, off, readable, valid_cursor, extendible
		redefine
			make, wipe_out, copy, is_equal
		end

	SHARED_WORKBENCH
		export
			{NONE} all
		undefine
			copy, is_equal
		end

	COMPILER_EXPORTER
		undefine
			copy, is_equal
		end

	SHARED_NAMES_HEAP
		undefine
			copy, is_equal
		end

	SHARED_ENCODING_CONVERTER
		undefine
			copy, is_equal
		end

	INTERNAL_COMPILER_STRING_EXPORTER
		undefine
			copy, is_equal
		end

create
	make

create {FEATURE_DEPENDANCE}
	make_sublist

feature {NONE} -- Initialization

	make
		do
			Precursor {TWO_WAY_SORTED_SET}
			compare_objects
			create suppliers.make
		end

feature -- Access

	suppliers: TWO_WAY_SORTED_SET [INTEGER]
			-- Set of all the syntactical suppliers of the feature

	instance_suppliers: detachable LINKED_SET [INSTANCE_DEPENDENCE]
			-- Set of types used to create objects.

	feature_name_32: STRING_32
			-- Final name of the feature
		require
			feature_name_id_set: feature_name_id >= 1
		do
			Result := encoding_converter.utf8_to_utf32 (feature_name)
		ensure
			Result_not_void: Result /= Void
			Result_not_empty: not Result.is_empty
		end

	feature_name_id: INTEGER
			-- name ID of the feature for which we have the dependances

feature -- Modification

	add_supplier (a_class: CLASS_C)
			-- Add the class to the list of suppliers
		require
			good_argument: a_class /= Void
		do
			suppliers.extend (a_class.class_id)
		end

	extend_depend_unit_with_level (a_class_id: INTEGER; a_feature: FEATURE_I; a_context: NATURAL_16)
			-- Optimized extend to avoid creating unnecessary depend units when they already exist.
		require
			a_feature_attached: a_feature /= Void
		local
			l_depend_unit: DEPEND_UNIT
		do
			l_depend_unit := reusable_depend_unit
			l_depend_unit.set_with_level (a_class_id, a_feature, a_context)
			extend (l_depend_unit)
			if item = l_depend_unit then
					-- We have been successfully insert so we add a new version.
				replace (create {DEPEND_UNIT}.make_with_level (a_class_id, a_feature, a_context))
			end
		end

	set_suppliers (new_suppliers: like suppliers)
		do
			suppliers := new_suppliers
		end

	add_instance_supplier (d: INSTANCE_DEPENDENCE)
			-- Add instance dependence `d` to the set of creation suppliers.
		local
			s: like instance_suppliers
		do
			s := instance_suppliers
			if not attached s then
				create s.make
				s.compare_objects
				instance_suppliers := s
			end
			s.extend (d)
		end

	set_feature_name_id (id: INTEGER)
			-- Assign `id' to `feature_name_id'.
		require
			valid_id: Names_heap.valid_index (id)
		do
			feature_name_id := id
		ensure
			feature_name_id_set: feature_name_id = id
		end

feature {NONE} -- Modification

	reusable_depend_unit: DEPEND_UNIT
			-- Reusable depend unit for optimized addition by `extend_depend_unit_with_level'.
		once
			create Result.make_creation_unit (system.any_id)
		end

feature -- Removal

	wipe_out
		do
			Precursor {TWO_WAY_SORTED_SET}
			suppliers.wipe_out
			instance_suppliers := Void
		end

feature -- Duplication

	copy (other: like Current)
		do
			if other /= Current then
				Precursor {TWO_WAY_SORTED_SET} (other)
				set_suppliers (suppliers.twin)
				if attached instance_suppliers as s then
					instance_suppliers := s.twin
				end
			end
		end

feature {INTERNAL_COMPILER_STRING_EXPORTER} -- Access

	feature_name: STRING
			-- Final name of the feature
		require
			feature_name_id_set: feature_name_id >= 1
		do
			Result := Names_heap.item (feature_name_id)
		ensure
			Result_not_void: Result /= Void
			Result_not_empty: not Result.is_empty
		end

feature -- Comparison

	is_equal (other: like Current): BOOLEAN
			-- Is `other' attached to an object considered
			-- equal to current object?
		do
			Result :=
				Precursor {TWO_WAY_SORTED_SET} (other) and then
				equal (suppliers, other.suppliers) and then
				instance_suppliers ~ other.instance_suppliers
		end

feature -- Incrementality

	has_removed_id: BOOLEAN
			-- One of the suppliers has been removed from the system?
		local
			l_system: like system
		do
			l_system := system
			Result :=
				across suppliers as s some not attached l_system.class_of_id (s.item) end or else
				attached instance_suppliers as cs and then across cs as s some s.item.has_removed_class (l_system) end or else
				across Current as d some not attached l_system.class_of_id (d.item.class_id) end
		end

feature -- Debug

	trace
		do
			io.error.put_string("Suppliers%N")
			across
				suppliers as s
			loop
				io.error.put_string ("Supplier id: ")
				io.error.put_integer (s.item)
				io.error.put_new_line
			end
			do_all (agent {DEPEND_UNIT}.trace)
		end

note
	copyright:	"Copyright (c) 1984-2019, Eiffel Software"
	license:	"GPL version 2 (see http://www.eiffel.com/licensing/gpl.txt)"
	licensing_options:	"http://www.eiffel.com/licensing"
	copying: "[
			This file is part of Eiffel Software's Eiffel Development Environment.
			
			Eiffel Software's Eiffel Development Environment is free
			software; you can redistribute it and/or modify it under
			the terms of the GNU General Public License as published
			by the Free Software Foundation, version 2 of the License
			(available at the URL listed under "license" above).
			
			Eiffel Software's Eiffel Development Environment is
			distributed in the hope that it will be useful, but
			WITHOUT ANY WARRANTY; without even the implied warranty
			of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
			See the GNU General Public License for more details.
			
			You should have received a copy of the GNU General Public
			License along with Eiffel Software's Eiffel Development
			Environment; if not, write to the Free Software Foundation,
			Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
		]"
	source: "[
			Eiffel Software
			5949 Hollister Ave., Goleta, CA 93117 USA
			Telephone 805-685-1006, Fax 805-685-6869
			Website http://www.eiffel.com
			Customer support http://support.eiffel.com
		]"

end
