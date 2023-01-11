scriptTitle = "Device ID Updater"
scriptAuthor = "jrobiche"
scriptVersion = 1
scriptDescription = "Update Device IDs"
scriptPermissions = { "filesystem", "sql" }

-- Main entry point to script
function main()
	local changesMade = false
	local oldToNewDeviceIds = {}
	-- determine mappings of old device ids to new device ids
	for _, v in pairs(Sql.ExecuteFetchRows("SELECT Id, Path, DeviceId FROM ScanPaths")) do
		if isOldDeviceId(v["DeviceId"]) and not isMappedToNewDevice(v["DeviceId"], oldToNewDeviceIds) then
			local oldDeviceId = v["DeviceId"]
			local newDeviceId = promptForNewDeviceId(v["Path"])
			if not (newDeviceId == nil) then
				oldToNewDeviceIds[oldDeviceId] = newDeviceId
			end
		end
	end
	-- update deviceid in scanpaths table
	for oldDeviceId, newDeviceId in pairs(oldToNewDeviceIds) do
		Sql.Execute("UPDATE ScanPaths SET DeviceId = '" .. newDeviceId .. "' WHERE DeviceId = '" .. oldDeviceId .. "';")
		changesMade = true
	end
	-- prompt a restart if changes were made
	if changesMade then
		promptForAuroraRestart()
	else
		local ret = Script.ShowMessageBox(
			"Complete",
			"No changes were made.",
			"Close"
		)
	end
end

function isMappedToNewDevice(deviceId, oldToNewDeviceIds)
	for k, _ in pairs(oldToNewDeviceIds) do
		if k == deviceId then
			return true
		end
	end
	return false
end

function isOldDeviceId(deviceId)
	for _, v in pairs(FileSystem.GetDrives(false)) do
		if deviceId == v["Serial"] then
			return false
		end
	end
	return true
end

function promptForAuroraRestart()
	local ret = Script.ShowMessageBox(
		"Restart Aurora",
		"A restart is required. Would you like to restart now?",
		"No", "Yes"
	)
	if ret.Button == 2 then
		Aurora.Restart()
	end
end

function promptForNewDeviceId(scanPath)
	local allDrives = FileSystem.GetDrives(false)
	local options = {}
	for i, v in ipairs(allDrives) do
		options[i] = v["MountPoint"]
	end
	local ret = Script.ShowPopupList(
		"Select drive containing " .. scanPath,
		"No Drives Found",
		options
	)
	if not ret["Canceled"] then
		for _, v in pairs(allDrives) do
			if v["MountPoint"] == ret["Selected"]["Value"] then
				return v["Serial"]
			end
		end
	end
	return nil
end
