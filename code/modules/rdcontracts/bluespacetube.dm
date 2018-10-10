/obj/machinery/contracttube
	name = "tube mail station"
	desc = "A mail tube system using bluespace rifts to quickly transport small packages over large distances"
	icon = 'icons/obj/machines/tubemail.dmi'
	icon_state = "empty"

	req_access = list(access_rd)

	var/busy = 0
	var/ui_state = "operation"

	// rd contracts
	var/list/contracts = list()
	// held item
	var/obj/item/tube_item = null
	// isolated bank account for the system's $$$
	var/datum/money_account/account = null

	// keep 10 contracts at all times
	var/num_contracts = 10
	// some contracts are "high end", i.e. they require high research levels, mats or lots of work
	// we always want some contracts you can pull off, so cap the amount of high end contracts
	var/highend_contracts = 0
	var/max_highend_contracts = 2

	// we're waiting to purchase this item
	var/decl/hierarchy/rd_shopping_article/queued_purchase = null

	// used for contract generation
	var/list/possible_contracts
	var/list/normal_contracts
	var/list/highend_contract_list

/obj/machinery/contracttube/Initialize()
	. = ..()

	account = create_account("Research Supply Fund")
	// makes it practically impossible to mess with since nobody has the PIN
	account.security_level = 2

	possible_contracts = subtypesof(/datum/rdcontract)
	for(var/C in possible_contracts)
		var/datum/rdcontract/contract = C
		if(!initial(contract.highend))
			LAZYADD(normal_contracts, C)
	highend_contract_list = possible_contracts - normal_contracts

	gen_contracts(num_contracts)

/obj/machinery/contracttube/Destroy()
	QDEL_NULL_LIST(contracts)
	QDEL_NULL(account)

	if(tube_item)
		tube_item.dropInto(loc)
		tube_item = null

	queued_purchase = null

	. = ..()

/obj/machinery/contracttube/update_icon()
	icon_state = "empty"

	if(tube_item)
		icon_state = "filled"

/obj/machinery/contracttube/attackby(var/obj/item/O, var/mob/user)
	if(!istype(O))
		return

	if(busy)
		return

	if(tube_item)
		return

	if(!user.unEquip(O, src))
		return
	tube_item = O

	update_icon()
	SSnano.update_uis(src)

	. = ..()

/obj/machinery/contracttube/attack_hand(var/mob/user)
	ui_interact(user)

// generate n new contracts
/obj/machinery/contracttube/proc/gen_contracts(var/n)
	for(var/i in 0 to (n-1))
		// pick normal contracts if we have enough high end ones
		var/chosen_contract = pick(possible_contracts)
		if((highend_contracts == max_highend_contracts))
			chosen_contract = pick(normal_contracts)

		if(chosen_contract in highend_contract_list)
			highend_contracts++

		contracts.Add(new chosen_contract(account.account_number))

/obj/machinery/contracttube/proc/begin_deliver()
	if(busy)
		return 0

	if(!tube_item)
		return 0

	if(!contracts.len)
		return 0

	busy = 1
	SSnano.update_uis(src)

	flick("downfilled", src)
	addtimer(CALLBACK(src, .proc/finish_deliver), 41)

/obj/machinery/contracttube/proc/finish_deliver()
	var/anim = "upfilled"
	for(var/datum/rdcontract/C in contracts)
		if(C.check_completion(tube_item))
			contracts.Remove(C)
			C.complete()

			QDEL_NULL(tube_item)

			gen_contracts(1)
			anim = "upempty"

			break

	flick(anim, src)
	
	update_icon()

	sleep(4	SECONDS)
	busy = 0

	SSnano.update_uis(src)

/obj/machinery/contracttube/proc/begin_get_purchase()
	if(busy)
		return 0

	if(!allowed(usr))
		return 0

	if(!queued_purchase)
		return 0

	if(tube_item)
		return 0

	// sanity
	if(account.money < queued_purchase.cost)
		return 0

	busy = 1
	SSnano.update_uis(src)

	var/datum/transaction/T = new("Torch, Ltd. Research Dept.", "Article purchase ([queued_purchase.name])", -queued_purchase.cost, "BlueSupply Services")
	account.do_transaction(T)

	flick("downempty", src)
	addtimer(CALLBACK(src, .proc/finish_get_purchase), 41)

/obj/machinery/contracttube/proc/finish_get_purchase()
	tube_item = new queued_purchase.item_path()
	if(istype(tube_item, /obj/item/stack))
		var/obj/item/stack/S = tube_item
		S.amount = queued_purchase.amount
	queued_purchase = null

	flick("upfilled", src)

	update_icon()

	sleep(4	SECONDS)
	busy = 0

	SSnano.update_uis(src)

/obj/machinery/contracttube/ui_interact(var/mob/user, var/ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1, var/master_ui = null)
	var/list/data = list()

	data["state"] = ui_state
	data["busy"] = busy

	// operations
	data["item"] = (tube_item ? 1 : 0)
	data["item_name"] = (tube_item ? tube_item.name : "none")

	// contracts
	data["contracts"] = list()
	for(var/datum/rdcontract/C in contracts)
		data["contracts"] += list(list("name" = C.name, "desc" = C.desc, "reward" = C.reward))

	// purchase/store
	data["available_funds"] = account.money

	data["queued_purchase"] = (queued_purchase ? queued_purchase.name : "none")

	// access is only used for the store
	data["has_access"] = allowed(user)

	data["articles"] = list()
	// putting this inline made the compiler whine
	var/decl/hierarchy/D = decls_repository.get_decl(/decl/hierarchy/rd_shopping_article)
	for(var/decl/hierarchy/rd_shopping_article/A in D.children)
		data["articles"] += list(list("name" = A.name, "cost" = A.cost, "type" = "[A.item_path]"))

	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "rd_contracts.tmpl", src.name, 400, 500, master_ui = master_ui)
		ui.set_initial_data(data)
		ui.open()

/obj/machinery/contracttube/OnTopic(href, href_list)
	if(..())
		return 1

	if(href_list["state"])
		ui_state = href_list["state"]
		return TOPIC_REFRESH

	if(busy)
		return TOPIC_HANDLED

	switch(href_list["cmd"])
		if("eject")
			if(!tube_item)
				return TOPIC_HANDLED

			tube_item.dropInto(loc)
			tube_item = null

			update_icon()
		if("deliver")
			begin_deliver()

		if("purchase")
			if(!allowed(usr))
				return TOPIC_HANDLED

			if(!href_list["article"])
				return TOPIC_HANDLED

			var/decl/hierarchy/D = decls_repository.get_decl(/decl/hierarchy/rd_shopping_article)
			for(var/decl/hierarchy/rd_shopping_article/A in D.children)
				if("[A.item_path]" == href_list["article"])
					queued_purchase = A
					break

		if("cancel_purchase")
			queued_purchase = null

		if("get_purchase")
			begin_get_purchase()

	return TOPIC_REFRESH
