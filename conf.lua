module(..., package.seeall)

local ethernet = require("lib.protocol.ethernet")
local ipv4     = require("lib.protocol.ipv4")
local ipv6     = require("lib.protocol.ipv6")
local icmp     = require("lib.protocol.icmp.header")
local udp      = require("lib.protocol.udp")
local tcp      = require("lib.protocol.tcp")
local datagram = require("lib.protocol.datagram")
local packet   = require("core.packet")

local ETHER_SIZE = 14
local IPV4_SIZE = 20
local IPV6_SIZE = 40
local ICMP_SIZE = 8
local TCP_SIZE = 20
local UDP_SIZE = 8

--[[ FUTURE IMPLEMENTATION:
--   1. Make it so object only has packet
--   2. Get rid of separate layers (e.g. ether)
--]]

function packetize(flow_file, s_eth, d_eth)
	local line = io.read()
	local cc = 0
	local cur_char
	local start_t
	local end_t
	local ip_src
	local ip_dst
	local s_port
	local d_port
	local proto
	local tos
	local tcp_flags
	local num_packets
	local num_bytes
	local i = 0
	local temp = ""
	while cc ~= 16 do
		cur_char = string.sub(line, i, i)
		if cur_char == ',' then
			if     cc == 0 then start_t = temp
			elseif cc == 1 then end_t = temp
			elseif cc == 2 then ip_src = temp 
			elseif cc == 3 then ip_dst = temp
			elseif cc == 4 then s_port = tonumber(temp)
			elseif cc == 5 then d_port = tonumber(temp)
			elseif cc == 6 then proto = tonumber(temp)
			elseif cc == 7 then tos = tonumber(temp)
			elseif cc == 8 then tcp_flags = tonumber(temp)
			elseif cc == 9 then num_packets = tonumber(temp)
			elseif cc == 10 then num_bytes = tonumber(temp)
			end
			cc = cc + 1
			temp = ""
		else
			temp = temp .. cur_char
		end
		i = i + 1
	end

	if 1 then  -- Testing to see if correct attributes gathered
		print("-= Flow Attributes =-")
		print("Start Time:      " .. start_t)
		print("End Time:        " .. end_t)
		print("IP Sorce:        " .. ip_src)
		print("IP Dest:         " .. ip_dst)
		print("Source Port:     " .. s_port)
		print("Dest Port:       " .. d_port)
		print("Protocol:        " .. proto)
		print("Type of Service: " .. tos)
		print("TCP Flags:       " .. tcp_flags)
		print("# of Packets:    " .. num_packets)
		print("# of Bytes:      " .. num_bytes)
	end

	-- Allocate packet to be used with object's datagram
	local p = packet.allocate()

	local o =
	{
		-- Built in Ethernet module @ lib.protocol.ethernet
		ether = ethernet:new(
		{
			-- Network byte order via pton()
			src = ethernet:pton(s_eth),
			dst = ethernet:pton(d_eth),
			type = 0x800
		}),
		dgram = datagram:new(),
		packets_left = num_packets,
	}

	-- Initialize datagram
	o.dgram:new(p)

	if string.find(ip_src, ".") then
		o.ip = ipv4:new(
		{
			-- Built in IPv4 module @ lib.protocol.ipv4
			ihl = 0x4500,
			dscp = tos,
			ttl = 255,
			protocol = proto,
			src = ipv4:pton(ip_src),
			dst = ipv4:pton(ip_dst)
		})
		-- Initialize payload size as ipv4 for final_header()
		o.payload_size = IPV4_SIZE
	else
		o.ip = ipv6:new(
		{
			traffic_class = bit.lshift(tos, 2),
			next_header = proto,
			hop_limit = 255,
			src = ipv6:pton(ip_src),
			dst = ipv6:pton(ip_dst)
		})
		-- Initalize payload size as ipv6 for final_header()
		o.payload_size = IPV6_SIZE
	end

	final_header(o, proto, s_port, d_port, num_packets, num_bytes)

	return o
end

function final_header(obj, proto, s_port, d_port, packets, bytes)
	if proto == 1 then  -- ICMP
		-- Type/code of ICMP given as type.code in src port
		local type_code = split(s_port, ".")
		local icmp_type = type_code[0]
		local icmp_code = type_core[1]
		obj.icmp = icmp:new(
		{
			type = tonumber(icmp_type),
			code = tonumber(icmp_code)
		})
		obj.dgram:push(obj.icmp)
		-- Note: obj.payload_size is already the ip size
		local net_frame_size = obj.payload_size + ICMP_SIZE
		obj.payload_size = (bytes / packets) - net_frame_size
	elseif proto == 6 then  -- TCP
		obj.tcp = tcp:new(
		{
			src_port = s_port,
			dst_port = d_port,
			ack_num = 0,
			seq_num = 0,
			window_size = 8192
		})
		obj.dgram:push(obj.tcp)
		local net_frame_size = obj.payload_size + TCP_SIZE
		obj.payload_size = (bytes / packets) - net_frame_size
	else  -- Default to UDP otherwise
		obj.udp = udp:new(
		{
			src_port = s_port,
			dst_port = d_port
			-- May have to manually implement length
		})
		obj.dgram:push(obj.udp)
		local net_frame_size = obj.payload_size + UDP_SIZE
		obj.payload_size = (bytes / packets) - net_frame_size
	end
	-- Push layer 2 and 3 onto packet stack
	obj.dgram:push(obj.ip)
	obj.dgram:push(obj.ether)
end
