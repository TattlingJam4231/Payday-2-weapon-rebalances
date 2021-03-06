function RaycastWeaponBase:_collect_hits(from, to)
	local can_shoot_through = self._can_shoot_through_wall or self._can_shoot_through_shield or self._can_shoot_through_enemy
	local ray_hits = nil
	local hit_enemy = false
	local enemy_mask = managers.slot:get_mask("enemies")
	local wall_mask = managers.slot:get_mask("world_geometry", "vehicles")
	local shield_mask = managers.slot:get_mask("enemy_shield_check")
	local ai_vision_ids = Idstring("ai_vision")
	local bulletproof_ids = Idstring("bulletproof")
	
	local units_hit = {}
	local unique_hits = {}
	
	
	if self._ammo_data.can_shoot_through_armor_plating then

		if self._can_shoot_through_wall then
			ray_hits = World:raycast_wall("ray", from, to, "slot_mask", self._bullet_slotmask, "ignore_unit", self._setup.ignore_units, "thickness", 40, "thickness_mask", wall_mask)
		else
			ray_hits = World:raycast_all("ray", from, to, "slot_mask", self._bullet_slotmask, "ignore_unit", self._setup.ignore_units)
		end
		
		
		for i, hit in ipairs(ray_hits) do
			if not units_hit[hit.unit:key()] then
				if hit.body:name() == Idstring("body_shields") then
					hit.unit:damage():run_sequence_simple("int_seq_shield_detach")
					hit.unit:character_damage():set_shield_health(0)
				elseif hit.body:name() == Idstring("head") then
					units_hit[hit.unit:key()] = true
					unique_hits[#unique_hits + 1] = hit
					hit.hit_position = hit.position
				end
			end
		end
	end


	if self._can_shoot_through_wall then
		ray_hits = World:raycast_wall("ray", from, to, "slot_mask", self._bullet_slotmask, "ignore_unit", self._setup.ignore_units, "thickness", 40, "thickness_mask", wall_mask)
	else
		ray_hits = World:raycast_all("ray", from, to, "slot_mask", self._bullet_slotmask, "ignore_unit", self._setup.ignore_units)
	end
	
	for i, hit in ipairs(ray_hits) do
		if not units_hit[hit.unit:key()] then
			units_hit[hit.unit:key()] = true
			unique_hits[#unique_hits + 1] = hit
			hit.hit_position = hit.position
			hit_enemy = hit_enemy or hit.unit:in_slot(enemy_mask)
			local weak_body = hit.body:has_ray_type(ai_vision_ids)
			weak_body = weak_body or hit.body:has_ray_type(bulletproof_ids)
			
			if self._ammo_data.can_shoot_through_armor_plating then
				--nothing
			elseif not self._can_shoot_through_enemy and hit_enemy then
				break
			elseif not self._can_shoot_through_wall and hit.unit:in_slot(wall_mask) and weak_body then
				break
			elseif not self._can_shoot_through_shield and hit.unit:in_slot(shield_mask) then
				break
			end
		end
	end

	return unique_hits, hit_enemy
end

function RaycastWeaponBase:add_ammo(ratio, add_amount_override)

	local function _add_ammo(ammo_base, ratio, add_amount_override)
		if ammo_base:get_ammo_max() == ammo_base:get_ammo_total() then
			return false, 0
		end

		local multiplier_min = 1
		local multiplier_max = 1
		
		--pick up modifiers from attachments don't negate pick up modifiers from skills and perks
			if ammo_base._ammo_data and ammo_base._ammo_data.ammo_pickup_min_mul then
				multiplier_min = managers.player:upgrade_value("player", "pick_up_ammo_multiplier", 1)
				multiplier_min = multiplier_min + managers.player:upgrade_value("player", "pick_up_ammo_multiplier_2", 1) - 1
				multiplier_min = multiplier_min + managers.player:crew_ability_upgrade_value("crew_scavenge", 0)
				multiplier_min = multiplier_min * ammo_base._ammo_data.ammo_pickup_min_mul
			else
				multiplier_min = managers.player:upgrade_value("player", "pick_up_ammo_multiplier", 1)
				multiplier_min = multiplier_min + managers.player:upgrade_value("player", "pick_up_ammo_multiplier_2", 1) - 1
				multiplier_min = multiplier_min + managers.player:crew_ability_upgrade_value("crew_scavenge", 0)
			end

			if ammo_base._ammo_data and ammo_base._ammo_data.ammo_pickup_max_mul then
				multiplier_max = managers.player:upgrade_value("player", "pick_up_ammo_multiplier", 1)
				multiplier_max = multiplier_max + managers.player:upgrade_value("player", "pick_up_ammo_multiplier_2", 1) - 1
				multiplier_max = multiplier_max + managers.player:crew_ability_upgrade_value("crew_scavenge", 0)
				multiplier_max = multiplier_max * ammo_base._ammo_data.ammo_pickup_max_mul
			else
				multiplier_max = managers.player:upgrade_value("player", "pick_up_ammo_multiplier", 1)
				multiplier_max = multiplier_max + managers.player:upgrade_value("player", "pick_up_ammo_multiplier_2", 1) - 1
				multiplier_max = multiplier_max + managers.player:crew_ability_upgrade_value("crew_scavenge", 0)
			end
		--
		local add_amount = add_amount_override
		local picked_up = true

		if not add_amount then
			local rng_ammo = math.lerp(ammo_base._ammo_pickup[1] * multiplier_min, ammo_base._ammo_pickup[2] * multiplier_max, math.random())
			picked_up = rng_ammo > 0
			add_amount = math.max(0, math.round(rng_ammo))
		end

		add_amount = math.floor(add_amount * (ratio or 1))

		ammo_base:set_ammo_total(math.clamp(ammo_base:get_ammo_total() + add_amount, 0, ammo_base:get_ammo_max()))

		return picked_up, add_amount
	end

	local picked_up, add_amount = nil
	picked_up, add_amount = _add_ammo(self, ratio, add_amount_override)

	if self.AKIMBO then
		local akimbo_rounding = self:get_ammo_total() % 2 + #self._fire_callbacks

		if akimbo_rounding > 0 then
			_add_ammo(self, nil, akimbo_rounding)
		end
	end

	for _, gadget in ipairs(self:get_all_override_weapon_gadgets()) do
		if gadget and gadget.ammo_base then
			local p, a = _add_ammo(gadget:ammo_base(), ratio, add_amount_override)
			picked_up = p or picked_up
			add_amount = add_amount + a
		end
	end

	return picked_up, add_amount
end