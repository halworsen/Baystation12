/*
	Sorting order
	Sends a couple of crates and a paper slip to supply

	Supply has to read the paper slip and label the crates appropriately. Supply points are awarded for every correctly labeled crate
*/

/datum/event/sorting_order
	endWhen = 1000 // All correctly labeled crates returned before this time limit gets you a supply point reward

	var/crates_spawned = FALSE
	var/list/crate_names = list()
	var/points_per_crate = 10

/datum/event/sorting_order/announce()
	command_announcement.Announce("The [location_name()] has been assigned a sorting order. Details will arrive on the next available supply shuttle.", "SolGov Office of Interstellar Logistics", zlevels = affecting_z)

/datum/event/sorting_order/tick()
	if(crates_spawned)
		return

	var/datum/shuttle/autodock/ferry/supply/shuttle = SSsupply.shuttle

	// No shuttle on the map
	if(isnull(shuttle))
		kill()
		return

	// Make sure the shuttle is idle at the away site
	if(!shuttle.at_station() && shuttle.moving_status == SHUTTLE_IDLE)
		if(!spawn_crates())
			kill()
			return
		crates_spawned = TRUE

/datum/event/sorting_order/proc/spawn_crates()
	var/obj/item/weapon/paper/order_details = new()
	var/info = "\[center\]\[solcrest\]\n\n\[large\]SolGov Office of Interstellar Logistics\[/large\]\n[location_name()] Sorting Order\[/center\]\[hr\]The Office of Interstellar Logistics has selected the [location_name()] to carry out a sorting order. A list of crate identifiers and destinations is provided below. Label each crate appropriately and ship them on your primary supply transport solution.\n\[hr\]\[large\]\[b\]Crate destinations\[/b\]\[/large\]\[list\]"

	if(!SSsupply.addAtom(order_details))
		log_debug("Failed to add sorting order details!")
		qdel(order_details)
		return FALSE

	var/crates_on_shuttle = FALSE
	var/list/ship_names = list("Pelago", "Vitruvius", "Lance", "Pluto", "Corus", "Zangbeto", "Loki")
	// We want to spawn 2-5 crates
	for(var/i = 0 to rand(1,4))
		var/crate_name = "[uppertext("[pick(GLOB.full_alphabet)][pick(GLOB.full_alphabet)][pick(GLOB.full_alphabet)]")][rand(1000,9999)]"
		crate_names[crate_name] = "[pick("SEV", "SRV", "SSV", "SCV", "STV")] [pick_n_take(ship_names)]"

		var/crate_type = pick(list(
			/obj/structure/closet/crate/secure,
			/obj/structure/closet/crate/secure/large,
			/obj/structure/closet/crate/secure/large/reinforced
		))

		// Make an inaccessible crate
		var/obj/structure/closet/crate/secure/crate = new crate_type()
		crate.req_access += access_inaccessible
		crate.SetName(crate_name)

		// Add crates until the shuttle is full if it's tight on space
		if(!SSsupply.addAtom(crate))
			break
		info += "\[*\]\[ \[field\] \] [crate_name] - [crate_names[crate_name]]"
		crates_on_shuttle = TRUE

	if(!crates_on_shuttle)
		log_debug("Failed to add any crates to the shuttle!")
		qdel(order_details)
		return FALSE

	info += "\[/list\]\[hr\]\[small\]\[i\]Store this form. Inspectors may require your full sorting order history.\[/i\]\[/small\]"
	order_details.set_content(info, "sorting order details")

	return TRUE