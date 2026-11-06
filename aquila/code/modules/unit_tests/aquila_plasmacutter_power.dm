// Upstream undefines these macros before the modular unit tests.
#define TEST_ASSERT(assertion, reason) if (!(assertion)) { return Fail("Assertion failed: [reason || "No reason"]") }

/// The power fix must also work on an ordinary craft, without any Mining module.
/obj/structure/overmap/small_craft/plasmacutter_unit_test
	loadout_type = LOADOUT_UTILITY_ONLY
	dradis_type = null

/datum/unit_test/aquila_plasmacutter_power

/datum/unit_test/aquila_plasmacutter_power/Run()
	var/obj/structure/overmap/small_craft/craft = allocate(/obj/structure/overmap/small_craft/plasmacutter_unit_test)
	var/obj/item/fighter_component/primary/plasmacutter/cutter = allocate(/obj/item/fighter_component/primary/plasmacutter)
	var/obj/item/fighter_component/battery/battery = allocate(/obj/item/fighter_component/battery)
	craft.loadout.install_hardpoint(cutter)
	TEST_ASSERT(!cutter.get_ammo(), "Missing battery reports ammunition")
	TEST_ASSERT(!cutter.fire(null, null), "Missing battery allows firing")
	craft.loadout.install_hardpoint(battery)
	battery.charge = cutter.charge_to_fire
	TEST_ASSERT(!cutter.get_ammo(), "Switched-off battery reports ammunition")
	TEST_ASSERT(!cutter.fire(null, null), "Switched-off battery allows firing")
	TEST_ASSERT(battery.charge == cutter.charge_to_fire, "Rejected shot consumed power")
	battery.active = TRUE
	battery.charge = cutter.charge_to_fire - 1
	TEST_ASSERT(!cutter.fire(null, null), "Insufficient charge allows firing")
	TEST_ASSERT(battery.charge == cutter.charge_to_fire - 1, "Insufficient-charge shot consumed power")
	battery.charge = cutter.charge_to_fire
	cutter.active = FALSE
	TEST_ASSERT(!cutter.get_ammo() && !cutter.fire(null, null), "Disabled cutter allows firing")
	cutter.active = TRUE
	TEST_ASSERT(cutter.get_ammo() == 1, "Exact charge does not report one shot")
	TEST_ASSERT(cutter.fire(null, null) == cutter.projectile, "Exact charge does not fire the last shot")
	TEST_ASSERT(battery.charge == 0 && !battery.active, "Last shot did not deplete and disable battery")
	TEST_ASSERT(craft.master_caution, "Last shot did not trigger battery caution")
	TEST_ASSERT(!cutter.fire(null, null), "Depleted battery allows another shot")
	craft.loadout.remove_hardpoint(cutter, FALSE)
	TEST_ASSERT(!cutter.get_ammo() && !cutter.fire(null, null), "Unmounted cutter allows firing")

#undef TEST_ASSERT
