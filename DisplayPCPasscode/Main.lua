scriptTitle = "Display PC Passcode"
scriptAuthor = "jrobiche"
scriptVersion = 1
scriptDescription = "Display the parental controls passcode"
scriptPermissions = { "settings" }

Buttons = enum {
	DpadDown = 17,
	DpadLeft = 18,
	DpadRight = 19,
	DpadUp = 16,
	LB = 5,
	LT = 6,
	RB = 4,
	RT = 7,
	X = 2,
	Y = 3,
}

-- Main entry point to script
function main()
	local pcpasscode = Settings.GetSystem("PCPasscode")["PCPasscode"]["value"]
	local passcode_buttons = {}
	passcode_buttons[0] = getButtonName((pcpasscode & 0xFF << 24) >> 24)
	passcode_buttons[1] = getButtonName((pcpasscode & 0xFF << 16) >> 16)
	passcode_buttons[2] = getButtonName((pcpasscode & 0xFF <<  8) >>  8)
	passcode_buttons[3] = getButtonName((pcpasscode & 0xFF <<  0) >>  0)
	local passcode_text = string.format(
		"%s, %s, %s, %s",
		passcode_buttons[0],
		passcode_buttons[1],
		passcode_buttons[2],
		passcode_buttons[3]
	)
	Script.ShowMessageBox(
		"Passcode",
		passcode_text,
		"Close"
	)
end

function getButtonName(buttonValue)
	buttonNames = {}
	buttonNames[Buttons.DpadDown] = "Dpad Down"
	buttonNames[Buttons.DpadLeft] = "Dpad Left"
	buttonNames[Buttons.DpadRight] = "Dpad Right"
	buttonNames[Buttons.DpadUp] = "Dpad Up"
	buttonNames[Buttons.LB] = "LB"
	buttonNames[Buttons.LT] = "LT"
	buttonNames[Buttons.RB] = "RB"
	buttonNames[Buttons.RT] = "RT"
	buttonNames[Buttons.X] = "X"
	buttonNames[Buttons.Y] = "Y"
	setTableDefault(buttonNames, "Unknown")
	return buttonNames[buttonValue]
end

-- https://www.lua.org/pil/13.4.3.html
function setTableDefault(t, d)
	local mt = {__index = function () return d end}
	setmetatable(t, mt)
end
