
--| Copyright (c) 1993-2006 University of Southern California and contributors.
--| All rights reserved.
--| Your use of this work is governed under the terms of the GNU General
--| Public License version 2.

class TEST
create
	make
feature
	
	make is
		local
			t2: TEST2
		do
			create x.make_filled (t2, 1, 10)
			print (x.count); io.new_line
 		end

	x: ARRAY [TEST2]
	
end
