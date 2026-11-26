--!nonstrict
-- Filters controls across all tabs by tab, section, name and description.
local Search = {}

-- Case-insensitive; every word of the query must appear somewhere in the text.
function Search.matches(text: string, query: string): boolean
	local haystack = string.lower(text)
	for word in string.gmatch(string.lower(query), "%S+") do
		if not string.find(haystack, word, 1, true) then
			return false
		end
	end
	return true
end

function Search.apply(window: any, query: string)
	local searching = string.find(query, "%S") ~= nil
	local counts = {}
	for _, tab in window.tabs do
		counts[tab] = 0
		for _, section in tab.sections do
			local found = 0
			for _, element in section.elements do
				local text = `{section.Name} {element.Name} {element.Description or ""}`
				-- dividers are noise in results
				element.matches = not searching or (element.Type ~= "Divider" and Search.matches(text, query))
				element:_applyVisibility()
				if element.matches and element.visible then
					found += 1
				end
			end
			section.searching = searching
			section.matches = not searching or (found > 0 and section.visible)
			section:_render()
			if section.matches and searching then
				counts[tab] += found
			end
		end
	end
	local selected = window.selected
	if searching and selected and counts[selected] == 0 then
		for _, tab in window.tabs do
			if counts[tab] > 0 and tab.button.Visible then
				window:SelectTab(tab)
				break
			end
		end
	end
	window.empty.Visible = searching and window.selected ~= nil and counts[window.selected] == 0
end

return Search
