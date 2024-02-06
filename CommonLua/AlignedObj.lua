DefineClass.AlignedObj = {
	__parents = { "EditorCallbackObject" },
	flags = { cfAlignObj = true },
}

-- gets pos and angle from the object if not passed; this base method does not implement this and should not be called
function AlignedObj:AlignObj(pos, angle)
	assert(not pos and not angle)
end

function AlignedObj:EditorCallbackPlace()
	self:AlignObj()
end

function AlignedObj:EditorCallbackMove()
	self:AlignObj()
end

function AlignedObj:EditorCallbackRotate()
	self:AlignObj()
end

function AlignedObj:EditorCallbackScale()
	self:AlignObj()
end

if const.HexWidth then
	DefineClass("HexAlignedObj", "AlignedObj")
	
	function HexAlignedObj:AlignObj(pos, angle)
		self:SetPosAngle(HexGetNearestCenter(pos or self:GetPos()), angle or self:GetAngle())
	end
end

if Platform.developer then
	function OnMsg.NewMapLoaded()
		local aligned = 0
		SuspendPassEdits("AlignedObjWarning")
		MapForEach("map", "AlignedObj", function(obj)
			if obj:GetParent() then
				return
			end
			local x1, y1, z1 = obj:GetPosXYZ()
			local a1 = obj:GetAngle()
			obj:AlignObj()
			local x2, y2, z2 = obj:GetPosXYZ()
			local a2 = obj:GetAngle()
			if x1 ~= x2 or y1 ~= y2 or z1 ~= z2 or a1 ~= a2 then
				aligned = aligned + 1
			end
		end)
		ResumePassEdits("AlignedObjWarning")
		if aligned > 0 then
			print(aligned, "object were re-aligned - Save the map!")
		end
	end
end
