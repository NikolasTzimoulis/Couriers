targetted_transfer_items = class({})

function targetted_transfer_items:OnSpellStart()
	if IsServer() then
		local hero = self:GetCursorTarget()
		local courier = self:GetCaster()
		for itemSlot = 0, 11, 1 do
			local item = courier:GetItemInSlot( itemSlot ) 
			hero:AddNewModifier(spawnedUnit, nil, "modifier_rooted", {duration = 0})
			if IsValidEntity(item) and hero:HasRoomForItem(item:GetName(), false, false) then
				--courier:MoveToNPCToGiveItem(hero, item)
				--print(item:GetName().." "..hero:GetName())
				hero:AddItem(courier:TakeItem(item))
			end
		end
	end
end