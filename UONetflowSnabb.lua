module(..., package.seeall)

local link       = require("core.link")
local app        = require("core.app")
local lib        = require("core.lib")
local config     = require("core.config")
local packet     = require("core.packet")
local ethernet   = require("lib.protocol.ethernet")
local ipv4       = require("lib.protocol.ipv4")
local udp        = require("lib.protocol.udp")
local datagram   = require("lib.protocol.datagram")
local raw_sock   = require("apps.socket.raw")
local conf_pack  = require("program.UONetflowSnabb.conf")
local pci        = require("lib.hardware.pci")

local ffi        = require("ffi")
local C = ffi.C

is_done = false

Grand_Packet = {}

function Grand_Packet:new(args)
	-- Claim variables from list "args" invoked from config.app()
	flow_file = io.open(args["flows"], "r")
	s_eth = args["s_eth"]
	d_eth = args["d_eth"]

	local o = conf_pack.packetize(flow_file, s_eth, d_eth) 

	print("OBJECT RETURNED")
	print("My payload size is: " .. o.payload_size)

	return setmetatable(o, {__index = Grand_Packet})
end

global_count = 0

function Grand_Packet:pull()
	assert(self.output.output, "No compatible output port found.")
	link.transmit(self.output.output, self.packet)
	global_count = global_count + 1
	print(global_count)
end

is_done = false

function is_done()
	if is_done then
		return true
	else
		return false
	end
end


function run (args)
	if not (#args == 5) then
		print("Usage: SnabbUONetflow <Flows> <S Eth> <D Eth> <IF> <PCI>")
		print("       Flows : File containing csv network flows based on README.md")
		print("       S Eth : Source Ethernet Address")
		print("       D Eth : Destination Ethernet Address")
		print("       IF    : Interface for packets to be transmitted over")
		print("       PCI   : PCI Address of compatible NIC")
		main.exit(1)
	end

	local flows_file = args[1]
	local s_eth = args[2]
	local d_eth = args[3]
	local IF = args[4]
	local pci_addr = args[5]
	
	-- Check if a file was given as args[1]
	local f = io.open(flows_file, "r")
	if f ~= nil then 
		io.input(f)
	else
		print("Flows file " .. flows_file .. " does not exist.")
		main.exit(1)	
	end

	local c = config.new()
	local RawSocket = raw_sock.RawSocket

	local device_info = pci.device_info(pci_addr)
	local driver = require(device_info.driver).driver

	print("Looking for rx")
	print("RX would have: nic." .. device_info.rx)
	print("Looking for tx")
	print("TX would have: nic." .. device_info.tx)
	
	--config.app(c, "server", RawSocket, IF)
	config.app(c, "nic", driver, {pciaddr = pci_addr})
	
	config.app(c, "packet", Grand_Packet, {flows=flows_file,s_eth=s_eth,d_eth=d_eth})
	config.link(c, "packet.output -> nic.tx")

	--config.link(c, "packet.output -> server.rx")
	engine.configure(c)
	engine.main({report = {showlinks=true}})
end
