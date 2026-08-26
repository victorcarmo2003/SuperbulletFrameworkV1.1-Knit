-- AI NOTE: In-memory log buffer with overflow trimming. Pure data structure —
-- no HTTP here, see BackendTransport.lua for sending.

local LogBuffer = {}
LogBuffer.__index = LogBuffer

LogBuffer.MAX_BATCH_SIZE = 100
local MAX_BUFFER_SIZE = LogBuffer.MAX_BATCH_SIZE * 2

local function getTimestampMs()
	return DateTime.now().UnixTimestampMillis
end

local function getFormattedTime()
	local t = os.date("*t")
	return string.format("%02d:%02d:%02d", t.hour, t.min, t.sec)
end

-- Parses Roblox error/log strings like "Script:42: message" into parts.
local function parseLogMessage(message)
	local scriptPath, line, msg = message:match("^(.+):(%d+):%s*(.+)$")

	if scriptPath and line then
		local scriptName = scriptPath:match("[^%.]+$") or scriptPath
		return {
			script = scriptName,
			line = tonumber(line),
			message = msg,
		}
	end

	return { message = message }
end

function LogBuffer.new()
	return setmetatable({ _entries = {} }, LogBuffer)
end

function LogBuffer:Add(source, level, message, traceback)
	local parsed = parseLogMessage(message)

	table.insert(self._entries, {
		timestamp = getTimestampMs(),
		timeFormatted = getFormattedTime(),
		source = source,
		level = level,
		message = parsed.message or message,
		script = parsed.script,
		line = parsed.line,
		traceback = traceback,
	})

	-- Prevent unbounded growth — trim to the most recent MAX_BATCH_SIZE entries.
	if #self._entries > MAX_BUFFER_SIZE then
		local trimmed = {}
		local startIndex = #self._entries - LogBuffer.MAX_BATCH_SIZE + 1
		for i = startIndex, #self._entries do
			table.insert(trimmed, self._entries[i])
		end
		self._entries = trimmed
	end
end

function LogBuffer:IsEmpty()
	return #self._entries == 0
end

-- Removes and returns up to `maxSize` of the oldest entries.
function LogBuffer:DrainUpTo(maxSize)
	local count = math.min(#self._entries, maxSize)
	local drained = {}
	for i = 1, count do
		table.insert(drained, self._entries[i])
	end

	local remaining = {}
	for i = count + 1, #self._entries do
		table.insert(remaining, self._entries[i])
	end
	self._entries = remaining

	return drained
end

return LogBuffer
