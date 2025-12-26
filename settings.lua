data:extend(
{
	{
		type = "int-setting",
		name = "XP-Start-Value",
		setting_type = "startup",
		default_value = 10,
		minimum_value = 1,
		order = "a"
	},
	{
		type = "string-setting",
		name = "XP-Scaling-Algo",
		setting_type = "startup",
		default_value = "constant",
		allowed_values = {"constant", "linear", "exponential"},
		order = "aa"
	},
	{
		type = "double-setting",
		name = "XP-Scaling-Factor",
		setting_type = "startup",
		default_value = 2.0,
		minimum_value = 0.1,
		order = "ab"
	},
	{
		type = "bool-setting",
		name = "Limit-quality-to-unlocked",
		setting_type = "startup",
		default_value = true,
		order = "b"
	},
	{
		type = "bool-setting",
		name = "Show-level-up-text",
		setting_type = "runtime-global",
		default_value = true,
		order = "c"
	},
	{
		type = "bool-setting",
		name = "Play-level-up-sound",
		setting_type = "runtime-global",
		default_value = true,
		order = "d"
	},
	{
		type = "bool-setting",
		name = "UI-Separate-Kill-Counter",
		setting_type = "runtime-per-user",
		default_value = true,
		order = "e"
	},
	{
		type = "int-setting",
		name = "UI-Spacer-Height",
		setting_type = "runtime-per-user",
		default_value = 8,
		minimum_value = 0,
		maximum_value = 50,
		order = "f"
	},
	{
		type = "bool-setting",
		name = "Preserve-kill-counter",
		setting_type = "runtime-global",
		default_value = false,
		order = "g"
	}
	})