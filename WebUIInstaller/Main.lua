scriptTitle = "WebUI Installer"
scriptAuthor = "jrobiche"
scriptVersion = 1
scriptDescription = "Install custom WebUIs"
scriptPermissions = { "content", "filesystem", "sql" }

-- libraries
json = require("JSON")

ContentGroup = enum {
	Start = 0,
	Hidden = 0,
	Xbox360 = 1,
	XBLA = 2,
	Indie = 3,
	XboxClassic = 4,
	Unsigned = 5,
	LibXenon = 6,
	Count = 7
}

ExecutableType = enum {
	None = -1,
	Xex = 0,
	Xbe = 1,
	XexCon = 2,
	XbeCon = 3,
	XnaCon = 4
}

-- Main entry point to script
function main()
	local listContent = {}
	listContent[1] = "Install New WebUI"
	listContent[2] = "Backup Current WebUI"
	listContent[3] = "Update titles.json"
	listContent[4] = "Credits"
	local ret = Script.ShowPopupList(
		"WebUI Installer",
		"No options available",
		listContent
	)
	if ret.Canceled then return end
	if ret.Selected.Key == 1 then
		local selectedWebUi = SelectWebUI()
		if selectedWebUi == "" then return end
		if not InstallWebUI(selectedWebUi) then
			Script.ShowNotification("Custom WebUI was not installed", 2)
			return
		end
		Script.ShowNotification("Install successful", 0)
		Script.ShowMessageBox(
			"Complete",
			"Access the WebUI at http://" .. Aurora.GetIPAddress() .. ":9999",
			"OK"
		)
	elseif ret.Selected.Key == 2 then
		if not BackupWebUI() then 
			Script.ShowNotification("Current WebUI was not backed up", 2)
			return
		end
		Script.ShowNotification("Backup successful", 0)
	elseif ret.Selected.Key == 3 then
		if not UpdateTitlesJSON() then
			Script.ShowNotification("Failed to update titles.json", 2)
			return
		end
		Script.ShowNotification("Successfully updated titles.json", 0)
	elseif ret.Selected.Key == 4 then
		Script.ShowMessageBox(
			"Credits",
			"Icon made by Those Icons from www.flaticon.com"
				.. "\nJSON Lua library by Jeffrey Friedl from http://regex.info/blog/"
				.. "\nScript by " ..  scriptAuthor,
			"OK"
		)
	end
end

-- remove trailing and leading whitespace from string.
-- http://en.wikipedia.org/wiki/Trim_(programming)
function trim(s)
	-- from PiL2 20.4
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function BackupWebUI()
	function GetDestPath()
		local destPath = nil
		repeat
			local keyboardData = Script.ShowKeyboard(
				"Backup Name",
				"Please enter a name for the current WebUI",
				"",
				0
			);
			if keyboardData.Canceled then
				destPath = ""
			else
				local tempPath = Script.GetBasePath() .. "webuis\\" .. trim(keyboardData.Buffer)
				if FileSystem.FileExists(tempPath) then
					Script.ShowMessageBox(
						"Error",
						"A WebUI already exists with that name.\nPlease use a different name.",
						"Ok"
					)
				else
					destPath = tempPath
				end
			end
		until(destPath ~= nil)
		return destPath
	end
	local srcPath = "Game:\\Plugins\\WebRoot"
	local destPath = GetDestPath()
	if destPath == "" then return false end
	if not FileSystem.CopyDirectory(srcPath, destPath, true) then
		Script.ShowMessageBox(
			"Error",
			"Failed to backup current web root.\nExiting.",
			"Ok"
		)
		return false
	end
	return true
end

function SelectWebUI()
	local webUisPath = Script.GetBasePath() .. "webuis"
	local webUis = {}
	for _, d in pairs(FileSystem.GetDirectories(webUisPath .. "\\*")) do
		table.insert(webUis, d.Name)
	end
	table.sort(webUis)
	local ret = Script.ShowPopupList(
		"Select WebUI to Install",
		"No WebUIs available",
		webUis
	)
	if ret.Canceled then return "" end
	return webUisPath .. "\\" .. ret.Selected.Value
end

function InstallWebUI(srcPath)
	local destPath = "Game:\\Plugins\\WebRoot"
	-- could not delete entire WebRoot directory, so delete
	-- contents of WebRoot directory instead
	if not DeleteDirectoryContents(destPath) then
		Script.ShowMessageBox(
			"Error",
			"Failed to remove current web root.\nExiting.",
			"Ok"
		)
		return false
	end
	-- copy contents of `srcPath` into `destPath`
	if not FileSystem.CopyDirectory(srcPath, destPath, true) then
		Script.ShowMessageBox(
			"Error",
			"Failed to copy custom WebUI into the web root.\nExiting.",
			"Ok"
		)
		return false
	end

	-- ask to update titles.json if it exists
	if FileSystem.FileExists("Game:\\Plugins\\WebRoot\\api\\titles.json") then
		local ret = Script.ShowMessageBox(
			"Warning",
			"Would you like to update titles.json?",
			"No", "Yes"
		)
		if ret.Button == 2 then
			if not UpdateTitlesJSON() then
				Script.ShowNotification("Failed to update titles.json", 2)
				return
			end
			Script.ShowNotification("Successfully updated titles.json", 0)
		end
	end
	return true
end

function DeleteDirectoryContents(path)
	local success = true
	local glob = path .. "\\*"
	local files = FileSystem.GetFiles(glob)
	local dirs = FileSystem.GetDirectories(glob)
	for _, x in pairs(files) do
		success = success and FileSystem.DeleteFile(path .. "\\" .. x.Name)
	end
	for _, x in pairs(dirs) do
		success = success and FileSystem.DeleteDirectory(path .. "\\" .. x.Name)
	end
	return success
end

function UpdateTitlesJSON()
	local contentCount = 0
	local contentCountSql = "SELECT seq FROM sqlite_sequence WHERE name = 'ContentItems'"
	local contentIdSql = "SELECT Id FROM ContentItems"
	local titles = {}
	Script.SetStatus("Updating titles.json")
	Script.SetProgress(0)
	for _, row in pairs(Sql.ExecuteFetchRows(contentCountSql)) do
		contentCount = row.seq
	end
	for i, row in pairs(Sql.ExecuteFetchRows(contentIdSql)) do
		local contentInfo = Content.GetInfo(row.Id)
		local entry = {}
		entry["directory"] = GetExecutableRoot(contentInfo.Root) .. contentInfo.Directory
		entry["executable"] = contentInfo.Executable
		entry["type"] = GetExecutableType(contentInfo.Executable, contentInfo.DefaultGroup)
		entry["titleName"] = contentInfo.Name
		entry["contentGroup"] = contentInfo.Group
		entry["hidden"] = contentInfo.Hidden
		entry["art"] = {}
		entry["art"]["tile"] = ""
		entry["art"]["boxartLarge"] = ""
		entry["art"]["boxartSmall"] = ""
		entry["art"]["background"] = ""
		entry["art"]["banner"] = ""
		entry["art"]["screenshots"] = {}
		local fileUrls = GetFileUrls(row.Id, contentInfo.TitleId)
		for _, fileUrl in pairs(fileUrls) do
			if IsTileFileUrl(fileUrl) then entry["art"]["tile"] = fileUrl end
			if IsBoxartLargeFileUrl(fileUrl) then entry["art"]["boxartLarge"] = fileUrl end
			if IsBoxartSmallFileUrl(fileUrl) then entry["art"]["boxartSmall"] = fileUrl end
			if IsBackgroundFileUrl(fileUrl) then entry["art"]["background"] = fileUrl end
			if IsBannerFileUrl(fileUrl) then entry["art"]["banner"] = fileUrl end
			if IsScreenshotFileUrl(fileUrl) then
				table.insert(entry["art"]["screenshots"], fileUrl)
			end
		end
		table.insert(titles, entry)
		Script.SetProgress(math.floor(i / contentCount * 100))
	end
	Script.SetProgress(100)
	return FileSystem.WriteFile(
		"Game:\\Plugins\\WebRoot\\api\\titles.json",
		json:encode(titles)
	)
end

function IsTileFileUrl(fileUrl)
	local end1 = "tile.png"
	local end2 = "icon/0/8000"
	return fileUrl:sub(-1 * #end1) == end1
		or fileUrl:sub(-1 * #end2) == end2
end

function IsBoxartLargeFileUrl(fileUrl)
	local end1 = "boxartlg.jpg"
	local end2 = "xboxboxart.jpg"
	return fileUrl:sub(-1 * #end1) == end1
		or fileUrl:sub(-1 * #end2) == end2
end

function IsBoxartSmallFileUrl(fileUrl)
	local end1 = "boxartsm.jpg"
	local end2 = "webboxart.jpg"
	return fileUrl:sub(-1 * #end1) == end1
		or fileUrl:sub(-1 * #end2) == end2
end

function IsBackgroundFileUrl(fileUrl)
	local end1 = "background.jpg"
	return fileUrl:sub(-1 * #end1) == end1
end

function IsBannerFileUrl(fileUrl)
	local end1 = "banner.png"
	local end2 = "marketplace/0/1"
	return fileUrl:sub(-1 * #end1) == end1
		or fileUrl:sub(-1 * #end2) == end2
end

function IsScreenshotFileUrl(fileUrl)
	return string.match(fileUrl, "screen%d+.jpg$") ~= nil
		or string.match(fileUrl, "screenlg%d+.jpg$") ~= nil
end

function GetFileUrls(contentId, titleId)
	local i = 1
	local fileUrls = {}
	local assetInfoPath = "Game:\\Data\\GameData\\"
		.. string.format("%08X", titleId):sub(-8)
		.. "_"
		.. string.format("%08X", contentId):sub(-8)
		.. "\\GameAssetInfo.bin"
	if FileSystem.FileExists(assetInfoPath) then
		local assetXml = FileSystem.ReadFile(assetInfoPath)
		for x in string.gmatch(assetXml, "<live:fileUrl>([^<]+)</live:fileUrl>") do
			fileUrls[i] = x
			i = i + 1
		end
	end
	return fileUrls
end

function GetExecutableType(executable, contentGroup)
	-- assume that the executable is a container if the
	-- filename does not contain a '.' character
	local isContainer = executable:reverse():find("%.") == nil
	if conentGroup == ContentGroup.Start
		or contentGroup == ContentGroup.Xbox360
		or contentGroup == ContentGroup.XBLA
		or contentGroup == ContentGroup.Unsigned
		or contentGroup == ContentGroup.LibXenon
		or contentGroup == ContentGroup.Count
	then
		if isContainer then return ExecutableType.XexCon
		else return ExecutableType.Xex end
	elseif contentGroup == ContentGroup.Indie then
		if isContainer then return ExecutableType.XnaCon end
	elseif contentGroup == ContentGroup.XboxClassic then
		if isContainer then return ExecutableType.XbeCon
		else return ExecutableType.Xbe end
	end
	return ExecutableType.None
end

-- function GetExecutableRoot(contentId)
function GetExecutableRoot(contentRoot)
	-- cannot support the following because they share the same key
	-- devices["onboardmu:"] = "\\Device\\BuiltInMuUsb\\Storage"
	-- devices["onboardmu:"] = "\\Device\\BuiltInMuMmc\\Storage"
	-- devices["onboardmu:"] = "\\Device\\BuiltInMuSfc"
	local devices = {}
	devices["flash:"] = "\\SystemRoot"
	devices["dvd:"] = "\\Device\\Cdrom0"
	devices["hdd1:"] = "\\Device\\Harddisk0\\Partition1"
	devices["hdd0:"] = "\\Device\\Harddisk0\\Partition0"
	devices["hddx:"] = "\\Device\\Harddisk0\\SystemPartition"
	devices["sysext:"] = "\\sep"
	devices["memunit0:"] = "\\Device\\Mu0"
	devices["memunit1:"] = "\\Device\\Mu1"
	devices["usb0:"] = "\\Device\\Mass0"
	devices["usb1:"] = "\\Device\\Mass1"
	devices["usb2:"] = "\\Device\\Mass2"
	devices["hddvdplayer:"] = "\\Device\\HdDvdPlayer"
	devices["hddvdstorage:"] = "\\Device\\HdDvdStorage"
	devices["transfercable:"] = "\\Device\\Transfercable"
	devices["transfercablexbox1:"] = "\\Device\\Transfercable\\Compatibility\\Xbox1"
	devices["usbmu0:"] = "\\Device\\Mass0PartitionFile\\Storage"
	devices["usbmu1:"] = "\\Device\\Mass1PartitionFile\\Storage"
	devices["usbmu2:"] = "\\Device\\Mass2PartitionFile\\Storage"
	devices["usbmucache0:"] = "\\Device\\Mass0PartitionFile\\StorageSystem"
	devices["usbmucache1:"] = "\\Device\\Mass1PartitionFile\\StorageSystem"
	devices["usbmucache2:"] = "\\Device\\Mass2PartitionFile\\StorageSystem"
	return devices[contentRoot:lower()] or ""
end
