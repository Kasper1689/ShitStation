// Based on the supplied Sabre Mining MVP; equipment remains optional.
/obj/item/fighter_component/proc/can_install(obj/structure/overmap/target)
	return TRUE

/obj/item/fighter_component/secondary/utility/mining_module
	name = "moduł górniczy Mk I"
	desc = "Skaner złóż i magnes metalicznych rud dla górniczego Sabre."
	icon = 'aquila/icons/obj/sabre_mining_modules.dmi'
	icon_state = "mining_mk1"
	fighter_fire_mode = null
	power_usage = 0 // Explicit pulse costs, not the utility parent's passive drain.
	var/scan_range = 12
	var/scan_cost = 50
	var/scan_interval = 4 SECONDS
	var/next_scan = 0
	var/pull_radius = 3
	var/impulse_cost = 250
	var/impulse_interval = 1.6 SECONDS
	var/next_impulse = 0
	var/magnet_enabled = TRUE
	var/list/scan_overlays = list()
	// This classification applies only to the Mk I magnet, never to scanning.
	var/static/list/metal_ore_types = typecacheof(list(/obj/item/stack/ore/iron, /obj/item/stack/ore/copper, /obj/item/stack/ore/silver, /obj/item/stack/ore/gold, /obj/item/stack/ore/titanium, /obj/item/stack/ore/uranium, /obj/item/stack/ore/bananium))

/obj/item/fighter_component/secondary/utility/mining_module/tier2
	name = "moduł górniczy Mk II"
	desc = "Skaner dalekiego zasięgu i magnes uniwersalny dla górniczego Sabre. Nie rzuca kryształami bluespace."
	icon_state = "mining_mk2"
	tier = 2
	scan_range = 20
	scan_cost = 75
	scan_interval = 3 SECONDS
	impulse_cost = 350

/obj/item/fighter_component/secondary/utility/mining_module/tier3
	name = "moduł górniczy Mk III"
	desc = "Skaner całego widoku pilota i kolektor bluespace o zasięgu pięciu kratek. Przenosi rudę bez rzucania."
	icon_state = "mining_mk3"
	tier = 3
	scan_cost = 100
	scan_interval = 2 SECONDS
	pull_radius = 5
	impulse_cost = 500

/obj/item/fighter_component/secondary/utility/mining_module/can_install(obj/structure/overmap/target)
	if(istype(target, /obj/structure/overmap/small_craft/transport/sabre/mining))
		return TRUE
	target?.visible_message("<span class='warning'>[src] pasuje wyłącznie do górniczego Sabre.</span>")
	return FALSE

/obj/item/fighter_component/secondary/utility/mining_module/proc/get_craft()
	var/obj/structure/overmap/small_craft/transport/sabre/mining/craft = loc
	if(QDELETED(src) || !active || !istype(craft) || QDELETED(craft))
		return
	if(craft.loadout?.get_slot(HARDPOINT_SLOT_UTILITY_SECONDARY) != src)
		return
	if(QDELETED(craft.pilot) || craft.pilot.stat != CONSCIOUS || craft.pilot.overmap_ship != craft)
		return
	return craft

/obj/item/fighter_component/secondary/utility/mining_module/proc/pay_power(obj/structure/overmap/small_craft/transport/sabre/mining/craft, amount)
	if(!craft || get_craft() != craft)
		return FALSE
	var/obj/item/fighter_component/battery/battery = craft.loadout?.get_slot(HARDPOINT_SLOT_BATTERY)
	if(QDELETED(battery) || !battery.active || battery.charge < amount)
		return FALSE
	// use_power returns FALSE on the successful final pulse as well.
	battery.use_power(amount)
	return TRUE

/obj/item/fighter_component/secondary/utility/mining_module/proc/clear_scan()
	for(var/obj/effect/temp_visual/mining_overlay/overlay as anything in scan_overlays)
		if(!QDELETED(overlay))
			qdel(overlay)
	scan_overlays.Cut()

/obj/item/fighter_component/secondary/utility/mining_module/toggle()
	. = ..()
	if(!active)
		clear_scan()

/obj/item/fighter_component/secondary/utility/mining_module/remove_from(obj/structure/overmap/target, due_to_damage)
	clear_scan()
	magnet_enabled = FALSE
	return ..()

/obj/item/fighter_component/secondary/utility/mining_module/Destroy()
	clear_scan()
	return ..()

/obj/item/fighter_component/secondary/utility/mining_module/proc/scan_minerals()
	var/obj/structure/overmap/small_craft/transport/sabre/mining/craft = get_craft()
	if(!craft || world.time < next_scan)
		return FALSE
	var/turf/center = craft.get_center()
	var/scan_view = scan_range
	if(tier >= 3)
		if(!craft.pilot.client)
			return FALSE
		center = get_turf(craft.pilot.client.eye)
		scan_view = craft.pilot.client.view
	if(!center || center.z != craft.z)
		return FALSE
	var/list/size = getviewsize(scan_view)
	var/turf/lower = locate(max(1, center.x - round((size[1] - 1) / 2)), max(1, center.y - round((size[2] - 1) / 2)), center.z)
	var/turf/upper = locate(min(world.maxx, center.x + round(size[1] / 2)), min(world.maxy, center.y + round(size[2] / 2)), center.z)
	if(!pay_power(craft, scan_cost))
		return FALSE
	next_scan = world.time + scan_interval
	clear_scan()
	// One synchronous pulse: no sleeping rings or callbacks surviving removal.
	for(var/turf/closed/mineral/mineral in block(lower, upper))
		if(mineral.get_virtual_z_level() != center.get_virtual_z_level() || !mineral.scan_state)
			continue
		var/obj/effect/temp_visual/mining_overlay/overlay = new(mineral)
		overlay.icon_state = mineral.scan_state
		scan_overlays += overlay
	return TRUE

/obj/structure/overmap/small_craft/transport/sabre/mining/proc/get_mining_ore_box()
	for(var/area/dropship/interior as anything in linked_areas)
		for(var/obj/structure/ore_box/box in interior)
			if(!QDELETED(box) && isturf(box.loc) && (get_area(box) in linked_areas))
				return box

/obj/item/fighter_component/secondary/utility/mining_module/proc/can_attract(obj/item/stack/ore/ore)
	return tier >= 2 || is_type_in_typecache(ore, metal_ore_types)

/obj/item/fighter_component/secondary/utility/mining_module/process(delta_time)
	var/obj/structure/overmap/small_craft/transport/sabre/mining/craft = get_craft()
	if(!craft)
		clear_scan()
		return
	if(!magnet_enabled || world.time < next_impulse)
		return
	var/obj/structure/ore_box/box = craft.get_mining_ore_box()
	if(!box)
		return
	var/list/footprint = list()
	for(var/dx in 0 to 1)
		for(var/dy in 0 to 1)
			var/turf/hull = locate(craft.x + dx, craft.y + dy, craft.z)
			if(hull)
				footprint += hull
	var/list/candidates = list()
	for(var/obj/item/stack/ore/ore in range(pull_radius + 1, craft))
		if(QDELETED(ore) || ore.throwing || ore.anchored || !isturf(ore.loc) || !can_attract(ore))
			continue
		if(ore.get_virtual_z_level() != craft.get_virtual_z_level())
			continue
		var/turf/closest
		var/distance = INFINITY
		for(var/turf/hull as anything in footprint)
			if(get_dist(ore, hull) < distance)
				closest = hull
				distance = get_dist(ore, hull)
		if(!closest || distance > pull_radius)
			continue
		// Preserve fragile crystals: Mk II can move adjacent ones, never throw them.
		if(tier < 3 && distance > 1 && istype(ore, /obj/item/stack/ore/bluespace_crystal))
			continue
		candidates[ore] = closest
	if(!length(candidates) || !pay_power(craft, impulse_cost))
		return
	next_impulse = world.time + impulse_interval
	for(var/obj/item/stack/ore/ore as anything in candidates)
		if(get_craft() != craft || !magnet_enabled || QDELETED(box) || !(get_area(box) in craft.linked_areas) || !isturf(box.loc))
			break
		if(QDELETED(ore) || ore.throwing || ore.anchored || !isturf(ore.loc) || ore.get_virtual_z_level() != craft.get_virtual_z_level())
			continue
		var/turf/closest = candidates[ore]
		var/distance = get_dist(ore, closest)
		if(distance > pull_radius || (tier < 3 && distance > 1 && istype(ore, /obj/item/stack/ore/bluespace_crystal)))
			continue
		if(tier >= 3 || distance == 0)
			ore.Move(box)
		else if(distance == 1)
			if(ore.Move(closest) && !QDELETED(ore))
				ore.Move(box)
		else
			// Inertia is intentional. Removal prevents later impulses, not flight.
			ore.throw_at(closest, max(distance, 3), 1)
	if(!QDELETED(box))
		box.ui_update()

// Use the existing fighter panel; asteroid-search consoles remain untouched.
/obj/structure/overmap/small_craft/transport/sabre/mining/ui_data(mob/user)
	. = ..()
	var/obj/item/fighter_component/secondary/utility/mining_module/module = loadout?.get_slot(HARDPOINT_SLOT_UTILITY_SECONDARY)
	if(istype(module))
		.["mining_module"] = module.name
		.["mining_active"] = module.active
		.["mining_magnet"] = module.magnet_enabled

/obj/structure/overmap/small_craft/transport/sabre/mining/ui_act(action, params, datum/tgui/ui)
	. = ..()
	if(. || usr != pilot)
		return
	var/obj/item/fighter_component/secondary/utility/mining_module/module = loadout?.get_slot(HARDPOINT_SLOT_UTILITY_SECONDARY)
	switch(action)
		if("mining_scan")
			if(istype(module))
				if(!module.scan_minerals())
					to_chat(usr, "<span class='warning'>Skaner niegotowy lub brak zasilania.</span>")
			return TRUE
		if("mining_toggle")
			if(istype(module))
				module.toggle()
			return TRUE
		if("mining_magnet")
			if(istype(module))
				module.magnet_enabled = !module.magnet_enabled
			return TRUE

/obj/item/fighter_component/primary/plasmacutter
	charge_to_fire = 1000

/obj/structure/overmap/small_craft/transport/sabre/mining/stop_piloting(mob/living/M, eject_mob = FALSE, force = FALSE)
	var/was_pilot = pilot == M
	. = ..()
	if(was_pilot && pilot != M)
		var/obj/item/fighter_component/secondary/utility/mining_module/module = loadout?.get_slot(HARDPOINT_SLOT_UTILITY_SECONDARY)
		if(istype(module))
			module.clear_scan()

// Existing nodes unlock recipes only; no asteroid-console functionality.
/datum/techweb_node/fighter_mining/New()
	. = ..()
	design_ids |= "sabre_mining_module_mk1"

/datum/techweb_node/mineral_nonferrous/New()
	. = ..()
	design_ids |= "sabre_mining_module_mk2"

/datum/techweb_node/bag_of_holding/New()
	. = ..()
	design_ids |= "sabre_mining_module_mk3"

/datum/design/sabre_mining_module_mk1
	name = "Moduł górniczy Mk I"
	desc = "Skaner złóż i magnes metalicznych rud dla górniczego Sabre."
	id = "sabre_mining_module_mk1"
	build_type = PROTOLATHE
	materials = list(/datum/material/iron = 8000, /datum/material/glass = 4000, /datum/material/copper = 4000, /datum/material/titanium = 1000)
	build_path = /obj/item/fighter_component/secondary/utility/mining_module
	category = list("Ship Components")
	departmental_flags = DEPARTMENTAL_FLAG_MUNITIONS|DEPARTMENTAL_FLAG_CARGO|DEPARTMENTAL_FLAG_ENGINEERING

/datum/design/sabre_mining_module_mk2
	name = "Moduł górniczy Mk II"
	desc = "Skaner dalekiego zasięgu i magnes uniwersalny dla górniczego Sabre."
	id = "sabre_mining_module_mk2"
	build_type = PROTOLATHE
	materials = list(/datum/material/iron = 10000, /datum/material/glass = 5000, /datum/material/copper = 6000, /datum/material/silver = 2000, /datum/material/gold = 1000)
	build_path = /obj/item/fighter_component/secondary/utility/mining_module/tier2
	category = list("Ship Components")
	departmental_flags = DEPARTMENTAL_FLAG_MUNITIONS|DEPARTMENTAL_FLAG_CARGO|DEPARTMENTAL_FLAG_ENGINEERING

/datum/design/sabre_mining_module_mk3
	name = "Moduł górniczy Mk III"
	desc = "Skaner całego widoku i kolektor bluespace dla górniczego Sabre."
	id = "sabre_mining_module_mk3"
	build_type = PROTOLATHE
	materials = list(/datum/material/iron = 12000, /datum/material/glass = 6000, /datum/material/titanium = 5000, /datum/material/diamond = 2000, /datum/material/bluespace = 2000)
	build_path = /obj/item/fighter_component/secondary/utility/mining_module/tier3
	category = list("Ship Components")
	departmental_flags = DEPARTMENTAL_FLAG_MUNITIONS|DEPARTMENTAL_FLAG_CARGO|DEPARTMENTAL_FLAG_ENGINEERING
