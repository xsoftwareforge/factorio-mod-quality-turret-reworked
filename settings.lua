local ghost_fixed_quality_values = {"normal", "uncommon", "rare", "epic", "legendary"}
if mods and mods["Quality-Plus-Plus"] then
	local extra_qualities = {"mythical", "masterwork", "wondrous", "artifactual"}
	for _, quality_name in ipairs(extra_qualities) do
		table.insert(ghost_fixed_quality_values, quality_name)
	end
end

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
	},
	{
		type = "string-setting",
		name = "Ghost-Strategy",
		setting_type = "runtime-global",
		default_value = "same",
		allowed_values = {"same", "downgrade", "exact"},
		order = "h"
	},
	{
		type = "string-setting",
		name = "Ghost-Fixed-Quality",
		setting_type = "runtime-global",
		default_value = "normal",
		allowed_values = ghost_fixed_quality_values,
		order = "i"
	},
	{
		type = "bool-setting",
		name = "Ghost-Fallback-Normal",
		setting_type = "runtime-global",
		default_value = true,
		order = "j"
	}
})
