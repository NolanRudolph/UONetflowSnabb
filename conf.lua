module(..., package.seeall)

function packetize(flow_file, s_eth, d_eth)
	local line = io.read()
	local cc = 0
	local cur_char
	local start_t
	local end_t
	local i = 0
	local temp = ""
	while cc ~= 16 do
		cur_char = string.sub(line, i, i)
		if cur_char == ',' then
			if     cc == 0 then start_t = temp
			elseif cc == 1 then end_t = temp
			else   print("This shouldn't happen")
			end
			cc = cc + 1
			temp = ""
		else
			temp = temp .. cur_char
		end
		i = i + 1
	end
	
	return {}
end
