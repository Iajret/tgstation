/datum/computer_file/program/faxbond
	filename = "faxbond"
	filedesc = "FaxBond"
	can_run_on_flags = PROGRAM_PDA
	downloader_category = PROGRAM_CATEGORY_DEVICE
	program_open_overlay = "generic"
	extended_desc = "A lightweight piece of software designed to decrease fax response time. Will send a notification as soon as one of connected faxes recieves a message. Recommended by 9 out of 10 CentCom officers."
	size = 1
	tgui_id = "NtosFaxBond"
	program_icon = "fa-fax"
	/// weak refs to our faxes, so we can clean up after ourselves
	var/list/faxes_weakrefs = list()
	var/list/muted_faxes = list()

/**
 * Proc for subscribing to faxes. Registers needed signal and updates fax related vars for program. Includes type checking.
 * Arguments:
 * * target - [/datum/computer_file/program/proc/tap] proc target, can be anything
 */
/datum/computer_file/program/faxbond/proc/connect_fax(obj/machinery/fax/target)
	if(!istype(target))
		return FALSE

	var/our_id = target.fax_id
	var/datum/weakref/fax_ref = faxes_weakrefs[our_id]
	var/obj/machinery/fax/old_fax = fax_ref?.resolve()
	if(old_fax)
		return FALSE

	faxes_weakrefs[our_id] = WEAKREF(target)
	RegisterSignal(target, COMSIG_FAX_MESSAGE_RECEIVED, PROC_REF(on_receive))

	return TRUE

/datum/computer_file/program/faxbond/proc/disconnect_fax(fax_id)
	if(!faxes_weakrefs[fax_id])
		return

	var/datum/weakref/fax_ref = faxes_weakrefs[fax_id]
	var/obj/machinery/fax/our_fax = fax_ref.resolve()

	faxes_weakrefs -= fax_id
	UnregisterSignal(our_fax, COMSIG_FAX_MESSAGE_RECEIVED)

/datum/computer_file/program/faxbond/proc/on_receive(obj/machinery/fax/target, message_source)
	SIGNAL_HANDLER

	var/datum/computer_file/program/messenger/messenger = locate() in computer.stored_files
	var/datum/signal/subspace/messaging/tablet_message/signal = new(target, list(
		"fakename" = "Fax Notificator",
		"fakejob" = "PDA Program",
		"message" = "Your fax [target.fax_name] has received a new message from [message_source]",
		"targets" = list(messenger),
		"automated" = TRUE
	))
	INVOKE_ASYNC(signal, TYPE_PROC_REF(send_to_receivers))

/datum/computer_file/program/faxbond/Destroy()
	. = ..()
	for(var/fax in faxes_weakrefs)
		disconnect_fax(fax)

/datum/computer_file/program/faxbond/tap(atom/tapped_atom, mob/living/user, list/modifiers)
	return connect_fax(tapped_atom)

/datum/computer_file/program/faxbond/ui_data(mob/user)
	var/list/data = list()

	data["faxes_info"] = list()
	for(var/fax_id in faxes_weakrefs)
		var/datum/weakref/fax_ref = faxes_weakrefs[fax_id]
		var/obj/machinery/fax/fax = fax_ref.resolve()
		var/area/our_area = get_area(fax)
		var/list/fax_info = list(
			"id" = fax_id,
			"name" = fax.fax_name,
			"location" = our_area.name,
			"muted" = (fax.fax_id in muted_faxes),
			)
		data["faxes_info"] += list(fax_info)
	return data

/datum/computer_file/program/faxbond/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	switch(action)
		if("unsubscribe")
			disconnect_fax(params["id"])
			return TRUE
		if("mute")
			if (params["id"] in muted_faxes)
				muted_faxes.Remove(params["id"])
				return TRUE
			muted_faxes.Add(params["id"])
			return TRUE
