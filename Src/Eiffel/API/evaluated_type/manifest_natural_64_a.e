﻿note
	description: "Actual type for integer constant type NATURAL_64."
	legal: "See notice at end of class."
	status: "See notice at end of class."
	date: "$Date$"
	revision: "$Revision$"

class
	MANIFEST_NATURAL_64_A

inherit
	NATURAL_A
		redefine
			convert_to, intrinsic_type, process
		end

	SHARED_TYPES

create
	make_for_constant

feature {NONE} -- Initialization

	make_for_constant (convertible_to_integer_64: BOOLEAN)
			-- Create instance of NATURAL_A represented by 64 bits
			-- and that can be converted to INTEGER_64 iff
			-- `is_convertible_to_integer_64' is `True'.
		do
			is_convertible_to_integer_64 := convertible_to_integer_64
			make (64)
		ensure
			size_set: size = 64
			is_convertible_to_integer_64_set: is_convertible_to_integer_64 = convertible_to_integer_64
		end

feature -- Visitor

	process (v: TYPE_A_VISITOR)
			-- Process current element.
		do
			v.process_manifest_natural_64_a (Current)
		end

feature -- Property

	is_convertible_to_integer_64: BOOLEAN
			-- Is manifest constant value compatible with INTEGER_64?

	intrinsic_type: NATURAL_A
			-- Real type of current manifest integer.
		do
			Result := natural_64_type
		end

feature {COMPILER_EXPORTER} -- Implementation

	convert_to (a_context_class: CLASS_C; a_target_type: TYPE_A): BOOLEAN
			-- Does current convert to `a_target_type' in `a_context_class'?
			-- Update `last_conversion_info' of AST_CONTEXT.
		do
			if attached {INTEGER_A} a_target_type as l_int then
				if is_convertible_to_integer_64 and then l_int.size >= 64 then
					context.set_last_conversion_info (create {NULL_CONVERSION_INFO}.make (l_int))
					Result := True
				end
			elseif attached {NATURAL_A} a_target_type as l_nat then
				if l_nat.size >= 64 then
					context.set_last_conversion_info (create {NULL_CONVERSION_INFO}.make (l_nat))
					Result := True
				end
			else
				Result := Precursor (a_context_class, a_target_type)
			end
		end

invariant
	correct_size: size = 64

note
	copyright:	"Copyright (c) 1984-2015, Eiffel Software"
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
