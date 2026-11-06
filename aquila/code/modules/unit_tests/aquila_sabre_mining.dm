#define TEST_ASSERT(assertion, reason) if (!(assertion)) { return Fail("Assertion failed: [reason || "No reason"]") }

// Keep these tests independent of asynchronous interior map loading.
/obj/structure/overmap/small_craft/transport/sabre/mining/unit_test
	interior_mode = NO_INTERIOR
	possible_interior_maps = null
	components = list(/obj/item/fighter_component/battery)
	var/obj/structure/ore_box/test_box

/obj/structure/overmap/small_craft/transport/sabre/mining/unit_test/get_mining_ore_box()
	return test_box

/obj/structure/overmap/small_craft/transport/sabre/mining/unit_test/Destroy()
	linked_areas.Cut()
	test_box = null
	return ..()

/datum/unit_test/aquila_sabre_mining_equipment

/datum/unit_test/aquila_sabre_mining_equipment/Run()
	var/obj/structure/overmap/small_craft/ordinary = allocate(/obj/structure/overmap/small_craft/plasmacutter_unit_test)
	var/obj/item/fighter_component/secondary/utility/hold/hold = allocate(/obj/item/fighter_component/secondary/utility/hold)
	var/obj/item/fighter_component/secondary/utility/mining_module/module = allocate(/obj/item/fighter_component/secondary/utility/mining_module)
	ordinary.loadout.install_hardpoint(hold)
	TEST_ASSERT(!ordinary.loadout.install_hardpoint(module), "Ordinary craft accepted a Mining module")
	TEST_ASSERT(ordinary.loadout.get_slot(HARDPOINT_SLOT_UTILITY_SECONDARY) == hold, "Rejected install removed existing equipment")
	var/obj/structure/overmap/small_craft/transport/sabre/mining/unit_test/craft = allocate(/obj/structure/overmap/small_craft/transport/sabre/mining/unit_test)
	var/mob/living/carbon/human/pilot = allocate(/mob/living/carbon/human)
	craft.pilot = pilot
	pilot.overmap_ship = craft
	craft.loadout.install_hardpoint(module)
	TEST_ASSERT(module.get_craft() == craft, "Mining module cannot find its pilot and slot")
	var/obj/item/fighter_component/battery/battery = craft.loadout.get_slot(HARDPOINT_SLOT_BATTERY)
	battery.charge = module.scan_cost
	TEST_ASSERT(!module.pay_power(craft, module.scan_cost), "Disabled battery powered scanner")
	battery.active = TRUE
	TEST_ASSERT(module.pay_power(craft, module.scan_cost), "Exact charge cannot power a scan")
	TEST_ASSERT(battery.charge == 0 && !battery.active, "Final scan did not deplete battery")
	TEST_ASSERT(!module.pay_power(null, module.scan_cost), "Null craft accepted power request")
	module.toggle()
	TEST_ASSERT(!module.get_craft(), "Disabled module is still operational")
	module.toggle()
	craft.loadout.remove_hardpoint(module, FALSE)
	TEST_ASSERT(!module.get_craft() && !module.scan_minerals(), "Removed module still scans")
	TEST_ASSERT(!module.magnet_enabled, "Removed module retained enabled magnet")
	var/mob/camera/ai_eye/remote/overmap_observer/eye = allocate(/mob/camera/ai_eye/remote/overmap_observer)
	eye.origin = craft
	pilot.sight = SEE_MOBS
	TEST_ASSERT(eye.update_remote_sight(pilot), "Mining camera no longer uses the default remote sight")
	TEST_ASSERT(pilot.sight == (SEE_TURFS | SEE_BLACKNESS), "Mining camera no longer has the default meson-like sight")
	craft.pilot = null
	pilot.overmap_ship = null

/datum/unit_test/aquila_sabre_mining_scan
	var/list/changed_turfs = list()

/datum/unit_test/aquila_sabre_mining_scan/Destroy()
	for(var/turf/changed as anything in changed_turfs)
		changed.ChangeTurf(changed_turfs[changed])
	changed_turfs = null
	return ..()

/datum/unit_test/aquila_sabre_mining_scan/proc/scanned(obj/item/fighter_component/secondary/utility/mining_module/module, turf/target)
	for(var/obj/effect/temp_visual/mining_overlay/overlay as anything in module.scan_overlays)
		if(!QDELETED(overlay) && get_turf(overlay) == target)
			return TRUE
	return FALSE

/datum/unit_test/aquila_sabre_mining_scan/Run()
	var/obj/structure/overmap/small_craft/transport/sabre/mining/unit_test/craft = allocate(/obj/structure/overmap/small_craft/transport/sabre/mining/unit_test)
	var/mob/living/carbon/human/pilot = allocate(/mob/living/carbon/human)
	craft.pilot = pilot
	pilot.overmap_ship = craft
	var/obj/item/fighter_component/battery/battery = craft.loadout.get_slot(HARDPOINT_SLOT_BATTERY)
	battery.active = TRUE
	var/obj/item/fighter_component/secondary/utility/mining_module/module = allocate(/obj/item/fighter_component/secondary/utility/mining_module)
	craft.loadout.install_hardpoint(module)
	var/turf/center = craft.get_center()
	var/list/rocks = list()
	for(var/distance in list(12, 13, 20, 21))
		var/turf/target = locate(center.x + distance, center.y, center.z)
		TEST_ASSERT(target, "Not enough space for scanner range regression")
		var/old_type = target.type
		target = target.ChangeTurf(/turf/closed/mineral/bananium)
		changed_turfs[target] = old_type
		rocks += target
	TEST_ASSERT(module.scan_minerals(), "Mk I scan did not execute")
	TEST_ASSERT(scanned(module, rocks[1]) && !scanned(module, rocks[2]), "Mk I range is not exactly 12, or bananium is invisible")
	var/obj/effect/temp_visual/mining_overlay/external = allocate(/obj/effect/temp_visual/mining_overlay, rocks[1])
	craft.loadout.remove_hardpoint(module, FALSE)
	TEST_ASSERT(!length(module.scan_overlays) && !QDELETED(external), "Removal did not clean only module-owned overlays")
	var/obj/item/fighter_component/secondary/utility/mining_module/tier2/advanced = allocate(/obj/item/fighter_component/secondary/utility/mining_module/tier2)
	craft.loadout.install_hardpoint(advanced)
	TEST_ASSERT(advanced.scan_minerals(), "Mk II scan did not execute")
	TEST_ASSERT(scanned(advanced, rocks[3]) && !scanned(advanced, rocks[4]), "Mk II range is not exactly 20")
	var/obj/item/fighter_component/secondary/utility/mining_module/tier3/bluespace = allocate(/obj/item/fighter_component/secondary/utility/mining_module/tier3)
	craft.loadout.install_hardpoint(bluespace)
	TEST_ASSERT(!length(advanced.scan_overlays), "Replacing Mk left its scan overlays behind")
	var/charge_before = battery.charge
	TEST_ASSERT(!bluespace.scan_minerals() && battery.charge == charge_before, "Mk III charged without a pilot client/view")
	craft.pilot = null
	pilot.overmap_ship = null

/datum/unit_test/aquila_sabre_mining_collection

/datum/unit_test/aquila_sabre_mining_collection/Run()
	var/obj/structure/overmap/small_craft/transport/sabre/mining/unit_test/craft = allocate(/obj/structure/overmap/small_craft/transport/sabre/mining/unit_test)
	var/mob/living/carbon/human/pilot = allocate(/mob/living/carbon/human)
	craft.pilot = pilot
	pilot.overmap_ship = craft
	var/obj/structure/ore_box/box = allocate(/obj/structure/ore_box, run_loc_floor_top_right)
	craft.test_box = box
	craft.linked_areas = list(get_area(box))
	var/obj/item/fighter_component/secondary/utility/mining_module/tier3/module = allocate(/obj/item/fighter_component/secondary/utility/mining_module/tier3)
	craft.loadout.install_hardpoint(module)
	var/obj/item/fighter_component/battery/battery = craft.loadout.get_slot(HARDPOINT_SLOT_BATTERY)
	battery.active = TRUE
	battery.charge = module.impulse_cost
	var/turf/source = locate(craft.x + 3, craft.y, craft.z)
	var/obj/item/stack/ore/bluespace_crystal/crystal = allocate(/obj/item/stack/ore/bluespace_crystal, source)
	module.process(2)
	TEST_ASSERT(!QDELETED(crystal) && crystal.loc == box && !crystal.throwing, "Mk III did not safely Move bluespace ore to box")
	TEST_ASSERT(battery.charge == 0 && !battery.active, "Collection did not consume exactly one impulse")
	var/obj/item/stack/ore/iron/ore = allocate(/obj/item/stack/ore/iron, source)
	battery.active = TRUE
	battery.charge = 1000
	craft.loadout.remove_hardpoint(module, FALSE)
	module.next_impulse = 0
	module.process(2)
	TEST_ASSERT(ore.loc == source && !ore.throwing && battery.charge == 1000, "Removed module issued another impulse")
	craft.pilot = null
	pilot.overmap_ship = null

/obj/item/stack/ore/iron/sabre_mining_unit_test
	var/impulses = 0

/obj/item/stack/ore/iron/sabre_mining_unit_test/throw_at(atom/target, range, speed, mob/thrower, spin = TRUE, diagonals_first = FALSE, datum/callback/callback, force = MOVE_FORCE_STRONG, quickstart = TRUE)
	impulses++
	return ..()

/datum/unit_test/aquila_sabre_mining_inertia

/datum/unit_test/aquila_sabre_mining_inertia/Run()
	var/obj/structure/overmap/small_craft/transport/sabre/mining/unit_test/craft = allocate(/obj/structure/overmap/small_craft/transport/sabre/mining/unit_test)
	var/mob/living/carbon/human/pilot = allocate(/mob/living/carbon/human)
	craft.pilot = pilot
	pilot.overmap_ship = craft
	craft.test_box = allocate(/obj/structure/ore_box, run_loc_floor_top_right)
	craft.linked_areas = list(get_area(craft.test_box))
	var/obj/item/fighter_component/battery/battery = craft.loadout.get_slot(HARDPOINT_SLOT_BATTERY)
	for(var/module_type in list(/obj/item/fighter_component/secondary/utility/mining_module, /obj/item/fighter_component/secondary/utility/mining_module/tier2))
		var/obj/item/fighter_component/secondary/utility/mining_module/module = allocate(module_type)
		craft.loadout.install_hardpoint(module)
		battery.active = TRUE
		battery.charge = 5000
		var/turf/source = locate(craft.x + 4, craft.y, craft.z)
		var/obj/item/stack/ore/iron/sabre_mining_unit_test/ore = allocate(/obj/item/stack/ore/iron/sabre_mining_unit_test, source)
		module.process(2)
		TEST_ASSERT(ore.impulses == 1, "Mk I/II did not issue one physical impulse")
		var/datum/thrownthing/flight = ore.throwing
		var/charge_after = battery.charge
		craft.loadout.remove_hardpoint(module, FALSE)
		module.next_impulse = 0
		module.process(2)
		TEST_ASSERT(ore.impulses == 1 && battery.charge == charge_after, "Removed module issued another impulse")
		TEST_ASSERT(ore.throwing == flight, "Removal cancelled a physical flight already in progress")
		qdel(ore)
	craft.pilot = null
	pilot.overmap_ship = null

/datum/unit_test/aquila_sabre_mining_research

/datum/unit_test/aquila_sabre_mining_research/Run()
	var/datum/techweb/web = allocate(/datum/techweb)
	var/list/nodes = list("fightermining", "mineral_nonferrous", "bagofholding")
	var/list/designs = list("sabre_mining_module_mk1", "sabre_mining_module_mk2", "sabre_mining_module_mk3")
	for(var/index in 1 to 3)
		var/datum/techweb_node/node = SSresearch.techweb_node_by_id(nodes[index])
		TEST_ASSERT(designs[index] in node.design_ids, "Module is absent from its specified existing research node")
		web.research_node(node, TRUE, FALSE, FALSE)
		TEST_ASSERT(designs[index] in web.researched_designs, "Research did not unlock production recipe")
		var/datum/design/design = SSresearch.techweb_design_by_id(designs[index])
		TEST_ASSERT(design.departmental_flags & DEPARTMENTAL_FLAG_MUNITIONS, "Recipe is unavailable in fighter techfab")
		TEST_ASSERT(design.build_type & PROTOLATHE, "Recipe has incompatible build type")

#undef TEST_ASSERT
