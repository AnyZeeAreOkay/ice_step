local icesheetradius = 4

-- chance for node restoral per second (No worries, all nodes will be restored, but not immediately)
local c_randomize_restore = 5

-- transform listed nodes only
local c_restricted_mode = true

local compatible_nodes = {
	"default:water_source",
	"default:water_flowing",
	"default:river_water_source",
	"default:river_water_flowing"
}

-- Check if the subspace still enabled for user (or can be disabled)
local function isu_get_wielded(playername)
	local user = minetest.get_player_by_name(playername)
	-- if user leave the game, disable them
	if not user then
		return false
	end
	-- user does not hold the staff in the hand
	local item = user:get_wielded_item()
	if not item or item:get_name() ~= "ice_step:ice_staff" then
		return false
	end
	-- all ok, still active
	return item
end


local ice_staff_users = {
	staff_users = {},
}

-- tool definition
minetest.register_tool("ice_step:ice_staff", {
	description = "Staff of Ice",
	inventory_image = "ice_staff.png",
	wield_image = "ice_staff.png",
	liquids_pointable = true,
	tool_capabilities = {},
	range = 30,
	on_use = function(itemstack, user, pointed_thing)
		ice_staff_users.staff_users[user:get_player_name()] = {timer = 1}
	end,
	on_place = function(itemstack, user, pointed_thing)
		local pos = minetest.get_pointed_thing_position(pointed_thing)
		if pointed_thing.type == "node" then
			local node = minetest.get_node(pos)


	local pos1 = {x=pos.x-icesheetradius, y=pos.y-icesheetradius, z=pos.z-icesheetradius}
	local pos2 = {x=pos.x+icesheetradius, y=pos.y+icesheetradius, z=pos.z+icesheetradius}

	local manip = minetest.get_voxel_manip()
	local min_c, max_c = manip:read_from_map(pos1, pos2)
	local area = VoxelArea:new({MinEdge=min_c, MaxEdge=max_c})

	local data = manip:get_data()
	local changed = false

	local isu_id = minetest.get_content_id("ice_step:ice")
	local air_id = minetest.get_content_id("air")

	local transform_count = 0

	-- check each node in the area
	for i in area:iterp(pos1, pos2) do
		local nodepos = area:position(i)
		--if math.random(0, vector.distance(userpos, nodepos)) < 2 then
			local cur_id = data[i]
			if cur_id and cur_id ~= isu_id and cur_id ~= air_id then
				local cur_name = minetest.get_name_from_content_id(cur_id)
				if c_restricted_mode then
					for _, compat in ipairs(compatible_nodes) do
						if compat == cur_name then
							data[i] = isu_id
							minetest.get_meta(area:position(i)):set_string("ice_staff_users", cur_name)
							changed = true
							transform_count = transform_count + 1
						end
					end
				else
					data[i] = isu_id
					minetest.get_meta(area:position(i)):set_string("ice_staff_users", cur_name)
					changed = true
					transform_count = transform_count + 1
				end
			end
--					end
	end
	-- save changes if needed
	if changed then
		manip:set_data(data)
		manip:write_to_map()

	end
end
end
}
)


-- Globalstep check for nodes to replace
minetest.register_globalstep(function(dtime)
	-- check each player with staff
	for playername, isu in pairs(ice_staff_users.staff_users) do
		isu.timer = isu.timer + dtime
		local isu_stack = isu_get_wielded(playername)
		if not isu_stack then
			ice_staff_users.staff_users[playername] = nil
		else
			local user = minetest.get_player_by_name(playername)
			local userpos = user:getpos()



				-- set offset for jump or sneak
				userpos = vector.round(userpos)

				--voxel_manip magic
				local pos1 = {x=userpos.x-icesheetradius, y=userpos.y-1, z=userpos.z-icesheetradius}
				local pos2 = {x=userpos.x+icesheetradius, y=userpos.y+icesheetradius, z=userpos.z+icesheetradius}

				local manip = minetest.get_voxel_manip()
				local min_c, max_c = manip:read_from_map(pos1, pos2)
				local area = VoxelArea:new({MinEdge=min_c, MaxEdge=max_c})

				local data = manip:get_data()
				local changed = false

				local isu_id = minetest.get_content_id("ice_step:ice")
				local air_id = minetest.get_content_id("air")

				local transform_count = 0

				-- check each node in the area
				for i in area:iterp(pos1, pos2) do
					local nodepos = area:position(i)
					--if math.random(0, vector.distance(userpos, nodepos)) < 2 then
						local cur_id = data[i]
						if cur_id and cur_id ~= isu_id and cur_id ~= air_id then
							local cur_name = minetest.get_name_from_content_id(cur_id)
							if c_restricted_mode then
								for _, compat in ipairs(compatible_nodes) do
									if compat == cur_name then
										data[i] = isu_id
										minetest.get_meta(area:position(i)):set_string("ice_staff_users", cur_name)
										changed = true
										transform_count = transform_count + 1
									end
								end
							else
								data[i] = isu_id
								minetest.get_meta(area:position(i)):set_string("ice_staff_users", cur_name)
								changed = true
								transform_count = transform_count + 1
							end
						end
--					end
				end
				-- save changes if needed
				if changed then
					manip:set_data(data)
					manip:write_to_map()
					local wear = isu_stack:get_wear()
					isu_stack:add_wear(transform_count)
					user:set_wielded_item(isu_stack)
				end
			end
			-- jump special handling. Restore node under the player
			end
		end
)

-- node to hide the original one
minetest.register_node("ice_step:ice", {
	description = "Ice",
	tiles = {"default_ice.png"},
	is_ground_content = false,
	paramtype = "light",
	groups = {cracky = 3, cools_lava = 1},

})

-- ABM to restore blocks
minetest.register_abm({
	nodenames = { "ice_step:ice" },
	interval = 0.5,
	chance = c_randomize_restore,
	action = function(pos, node)
		if node.name == 'ignore' then
			return
		end

		local can_be_restored = true
		-- check if the node can be restored
		for playername, _ in pairs(ice_staff_users.staff_users) do
			local isu_stack = isu_get_wielded(playername)
			if not isu_stack then
				ice_staff_users.staff_users[playername] = nil
			else
				local user = minetest.get_player_by_name(playername)
				local userpos = user:getpos()
				userpos.y = math.floor(userpos.y-1)
				if ( pos.x >= userpos.x-icesheetradius-1 and pos.x <= userpos.x+icesheetradius+1) and  -- "+1" is to avoid flickering of nodes. restoring range is higher then the effect range
						( pos.y >= userpos.y and pos.y <= userpos.y+icesheetradius+1 ) and
						( pos.z >= userpos.z-icesheetradius-1 and pos.z <= userpos.z+icesheetradius+1) then
					can_be_restored = false --active user in range
				end
			end
		end

		--restore them
		if can_be_restored then
			local node = minetest.get_node(pos)
			local meta = minetest.get_meta(pos)
			local data = meta:to_table()
			node.name = data.fields.ice_staff_users
			data.fields.ice_staff_users = nil
			meta:from_table(data)
			minetest.swap_node(pos, node)
		end
	end
})

minetest.register_craft({
	output = "ice_step:ice_staff",
	width = 1,
	recipe = {
			{"default:ice"},
			{"default:ice"},
			{"group:stick"}
	}
})
