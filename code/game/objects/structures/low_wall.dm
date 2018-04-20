// Basically see-through walls. Used for windows
// If nothing has been built on the low wall, you can climb on it

/obj/structure/low_wall
	name = "low wall"
	desc = "A low wall section which serves as the base of windows, amongst other things."
	icon = 'icons/obj/frame.dmi'
	icon_state = "frame"

	atom_flags = ATOM_FLAG_CLIMBABLE
	anchored = 1
	density = 1
	opacity = 0

	// icon related
	var/list/connections = list("0", "0", "0", "0")

	// window related
	var/obj/structure/grille/grille
	var/obj/item/stack/material/glass/pane_small
	var/obj/item/stack/material/glass/pane_large
	var/panes_secured = 0
	var/window_health = 2 // windows need to have both panes broken to fully shatter. basically 2 health bars

/obj/structure/low_wall/New(var/new_loc)
	..(new_loc)

	update_connections(1)
	update_icon()

/obj/structure/low_wall/attackby(var/obj/item/weapon/W, var/mob/user)
	// grille
	if(istype(W, /obj/item/stack/rods))
		var/obj/item/stack/rods/R = W

		if(pane_large && pane_small)
			to_chat(user, "<span class='warning'>The glass pane is in the way.</span>")
			return

		if(R.get_amount() < 2)
			to_chat(user, "<span class='warning'>You need at least two rods to do this.</span>")
			return

		R.in_use = 1
		if (!do_after(user, 10))
			R.in_use = 0
			return

		var/obj/structure/grille/G = new /obj/structure/grille(src)
		grille = G
		atom_flags = 0
		R.in_use = 0
		R.use(2)

		src.add_fingerprint(user)
		update_icon()

	// normal glass. starts making a window
	if(istype(W, /obj/item/stack/material/glass))
		if(pane_large && pane_small)
			return

		var/obj/item/stack/material/glass/G = W

		if(G.get_amount() < 2)
			to_chat(user, "<span class='warning'>You need at least two sheets to do this.</span>")
			return

		//var/list/window_dirs = ?????
		//var/pane_side = input(src,"Choose a side to build the pane on.","Select side",null) as anything in window_dirs

		G.in_use = 1
		if (!do_after(user, 10))
			G.in_use = 0
			return

		var/obj/item/stack/material/glass/P = G.split(2)
		if(pane_large)
			pane_small = P
		else
			pane_large = P

		G.in_use = 0

		panes_secured = 1
		atom_flags = 0
		src.add_fingerprint(user)
		update_icon()

	if(isScrewdriver(W))
		if(!pane_small || !pane_large)
			return ..()

		if(panes_secured)
			to_chat(user, "You unsecure the window pane[pane_small && pane_large ? "s" : ""].")
		else
			to_chat(user, "You secure the window pane[pane_small && pane_large ? "s" : ""].")

		playsound(loc, 'sound/items/Screwdriver.ogg', 50, 1)
		panes_secured = !panes_secured

	if(isWirecutter(W))
		if(!grille)
			return ..()
		if(pane_small || pane_large)
			to_chat(user, "<span class='warning'>The glass pane is in the way.</span>")
			return ..()

		grille.attackby(W, user)

	..()

// icon related

/obj/structure/low_wall/update_icon()
	overlays.Cut()

	for(var/i = 1 to 4)
		var/image/I = image('icons/obj/frame.dmi', "frame[connections[i]]", dir = 1<<(i-1))
		world << "i=[i]: frame icon: frame[connections[i]]"
		world << "DIR: [1<<(i-1)]"
		overlays += I

	/*
	if(grille)
		for(var/i = 1 to 4)
			I = image('icons/obj/structures.dmi', "grille")
			overlays += I
	if(pane_small)
		for(var/i = 1 to 4)
			I = image('icons/obj/structures.dmi', "rwindow", dir = 1<<(i-1))
			overlays += I
	if(pane_large)
		for(var/i = 1 to 4)
			I = image('icons/obj/structures.dmi', "rwindow", dir = 1<<(i-1))
			overlays += I
	*/

	return

/obj/structure/low_wall/proc/update_connections(var/propagate = 0)
	var/list/dirs = list()
	for(var/turf/simulated/wall/W in orange(src, 1))
		if(!W.material)
			continue
		if(propagate)
			W.update_connections()
			W.update_icon()
		dirs += get_dir(src, W)
	for(var/obj/machinery/door/D in orange(src, 1))
		dirs += get_dir(src,D)
	for(var/obj/structure/low_wall/W in orange(src, 1))
		dirs += get_dir(src,W)

	connections = dirs_to_corner_states(dirs)