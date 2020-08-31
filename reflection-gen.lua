local mg		= require "moongen"
local memory	= require "memory"
local device	= require "device"
local stats		= require "stats"
local log 		= require "log"

-- IP address of the test resolver
local CONTROL = "8.8.8.8"

function configure(parser)
	parser:description("Generates UDP-based responses for protocols such as DNS, NTP etc.")
	parser:argument("dev", "Devices to transmit from."):args("*"):convert(tonumber)
	parser:option("-r --rate", "Transmit rate in Mbit/s."):default(10000):convert(tonumber)
	parser:option("-t --threads", "Number of threads."):default(1):convert(tonumber)
	parser:option("-f --sources", "Number of different source IPs to use."):default(7000):convert(tonumber)
	parser:option("-p --port", "Source/ service port to use, e.g., port 53 for DNS."):default(53):convert(tonumber)
end

function master(args)
	-- print("Generating random source IPs. " .. args.source .. " of them!")
	local ip_list = generateAttackSources(args.sources)

	for i, dev in ipairs(args.dev) do
		local dev = device.config{port = dev, txQueues = args.threads}
		dev:wait()

		for thread=1, args.threads do
			local queue = dev:getTxQueue(thread-1)
			queue:setRate(args.rate / args.threads)
			mg.startTask("loadTrafficGenerator", queue, i, thread, args.sources, args.port, ip_list)
		end
	end
	mg.waitForTasks()
end

function loadTrafficGenerator(queue, dev, thread, sources, service_port, ip_list)
	local packetLen = 60
	local mem = memory.createMemPool(function(buf)
		buf:getUdpPacket(ipv4):fill{ 
			ethSrc = queue,
			ethDst = "aa:bb:cc:dd:ee:ff",
			ip4Src = "10.0.0.1",
			-- ip4Dst = "10.0.0.2",
			udpSrc = service_port,
			-- udpDst = 1024
			pktLength = packetLen
		}
	end)

	local bufs = mem:bufArray()

	print("Device #" .. dev ..  " Thread #" .. thread .. ": Generating traffic now")
	local txStats = stats:newDevTxCounter(queue, "plain")
	while mg.running() do		
		bufs:alloc(packetLen)

		for j, buf in ipairs(bufs) do 			
			local pkt = buf:getUdpPacket(ipv4)

			local ip_index = math.random(1, sources)
			pkt.ip4.src:set(ip_list[ip_index])

			-- Linux ephemeral port range, 32768 to 60999
			local dest_port = math.random(32768,60999)
			pkt.udp.dst = dest_port
		end 

		--offload checksums to NIC
		bufs:offloadTcpChecksums(ipv4)
		queue:send(bufs)
		txStats:update()	
	end
	txStats:finalize()
end

function generateAttackSources(sources)
	local ip_list = {}
	local ip_set = {}
	for source=0, sources, 1 do
		local ip = tostring(math.random(0,255)) .. "." .. tostring(math.random(0,255)) .. "." .. tostring(math.random(0,255)) .. "." .. tostring(math.random(0,255))
		local ip, valid = parseIPAddress(ip)

		-- make sure the IP generated:
		-- 1. is a valid IP address
		-- 2. does not clash with our test resolver
		-- 3. is not a duplicated
		while not valid or ip == CONTROL or ip_set[ip] do
			ip = tostring(math.random(0,255)) .. "." .. tostring(math.random(0,255)) .. "." .. tostring(math.random(0,255)) .. "." .. tostring(math.random(0,255))
			ip, valid = parseIPAddress(ip)
		end
		table.insert(ip_list, ip)
		ip_set[ip] = true
	end
	return ip_list
end