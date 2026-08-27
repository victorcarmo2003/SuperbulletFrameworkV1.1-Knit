local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

local MAX_PROFILE_BYTES = 8192
local MAX_USER_ID = 2 ^ 40 - 1 -- generous: real Roblox UserIds never get close to this

return Lync.define("Profile", {
	-- One record per player (id = player.UserId), keyBy("owner") + audience
	-- restricts each record to just its owner. Automatic push (add) + Set's
	-- native catchup cover "send the profile as soon as it loads and the
	-- player is ready", with no manual race-condition queue needed.
	Fields = Lync.replicate(Lync.struct({
		owner = Lync.int(1, MAX_USER_ID),
		profile = Lync.unknown(MAX_PROFILE_BYTES),
	})):keyBy("owner"),

	-- Granular push on every ChangeData, for anyone who wants to react to a
	-- single key without diffing the whole profile blob.
	KeyChanged = Lync.packet(Lync.struct({
		path = Lync.array(Lync.str(1, 64), 1, 8),
		value = Lync.unknown(MAX_PROFILE_BYTES),
	})),

	-- Explicit on-demand pull: path == nil returns the whole profile, a
	-- filled-in path returns only the value at that path.
	RequestProfile = Lync.query(
		Lync.optional(Lync.array(Lync.str(1, 64), 1, 8)),
		Lync.unknown(MAX_PROFILE_BYTES)
	),
})
