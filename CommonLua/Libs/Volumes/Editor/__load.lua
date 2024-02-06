if Platform.editor then
	for _, file in ipairs(io.listfiles("CommonLua/Libs/Volumes/Editor")) do
		if not file:ends_with("__load.lua") then
			dofile(file)
		end
	end
end
