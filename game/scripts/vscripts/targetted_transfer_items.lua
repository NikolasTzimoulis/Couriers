targetted_transfer_items = class({})

function targetted_transfer_items:OnSpellStart()
	if IsServer() then
		local hero = self:GetCursorTarget()
		local courier = self:GetCaster()
		for itemSlot = 0, 11, 1 do
			local item = courier:GetItemInSlot( itemSlot ) 
			if IsValidEntity(item) and hero:HasRoomForItem(item:GetName(), true, true) then
				Timers:CreateTimer(0.1*(itemSlot+2), function()
					courier:MoveToNPCToGiveItem(hero, item)
				end)
			end
		end
	end
end