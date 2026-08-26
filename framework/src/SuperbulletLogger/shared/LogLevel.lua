-- Shared LogService.MessageType -> Superbullet log level string mapping.
-- Used by both SuperbulletServerLogger and SuperbulletClientLogger — keep the
-- two in sync by editing this file instead of each copy.

local LogLevel = {}

function LogLevel.FromMessageType(messageType)
	if messageType == Enum.MessageType.MessageError then
		return "error"
	elseif messageType == Enum.MessageType.MessageWarning then
		return "warning"
	elseif messageType == Enum.MessageType.MessageInfo then
		return "info"
	elseif messageType == Enum.MessageType.MessageOutput then
		return "debug" -- print() statements
	end
	return "info"
end

return LogLevel
