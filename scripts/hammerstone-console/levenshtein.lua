-- https://gist.github.com/exebetche/18997eb4467956c5263c

levenshtein = {}

function levenshtein:lev(a, b)
	if a:len() == 0 then return b:len() end
	if b:len() == 0 then return a:len() end

	local matrix = {}
	local a_len = a:len()+1
	local b_len = b:len()+1

	-- increment along the first column of each row
	for i = 1, b_len do 
		matrix[i] = {i-1}
	end
	
	-- increment each column in the first row
	for j = 1, a_len do
		matrix[1][j] = j-1
	end

	-- Fill in the rest of the matrix
	for i = 2, b_len do
		for j = 2, a_len do
			if b:byte(i-1) == a:byte(j-1) then
				matrix[i][j] = matrix[i-1][j-1]
			else
				matrix[i][j] = math.min(
					matrix[i-1][j-1] + 1,	-- substitution
					matrix[i  ][j-1] + 1,	-- insertion
					matrix[i-1][j  ] + 1) 	-- deletion
			end
		end
	end

	return matrix[b_len][a_len]
end

return levenshtein