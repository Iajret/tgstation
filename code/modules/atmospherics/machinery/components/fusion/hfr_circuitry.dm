/obj/item/circuit_component/hfr_control
	display_name = "HFR Interfacing Circuit"
	desc = "Does nothing on its own. At all."
	circuit_flags = CIRCUIT_FLAG_INPUT_SIGNAL|CIRCUIT_FLAG_OUTPUT_SIGNAL

	/// Core of the reactor
	var/obj/machinery/atmospherics/components/unary/hypertorus/core/reactor_core
	var/obj/machinery/hypertorus/interface/interface

/obj/item/circuit_component/hfr_control/register_usb_parent(atom/movable/shell)
	. = ..()
	if(istype(shell, /obj/machinery/hypertorus/interface))
		interface = shell
		reactor_core = interface.connected_core

/obj/item/circuit_component/hfr_control/unregister_usb_parent(atom/movable/shell)
	interface = null
	reactor_core = null
	return ..()

/obj/item/circuit_component/hfr_control/power
	display_name = "HFR Power Interfacing Circuit"
	desc = "Basic power and settings control circuit"
	circuit_flags = NONE

	var/datum/port/input/option/reaction_selector
	var/datum/port/input/power_on
	var/datum/port/input/power_off
	var/datum/port/input/cooling_on
	var/datum/port/input/cooling_off

	var/static/list/hfr_reactions

/obj/item/circuit_component/hfr_control/power/populate_ports()
	reaction_selector = add_option_port("Reaction Selector", hfr_reactions)
	power_on = add_input_port("Power On", PORT_TYPE_SIGNAL)
	power_off = add_input_port("Power Off", PORT_TYPE_SIGNAL)
	cooling_on = add_input_port("Cooling On", PORT_TYPE_SIGNAL)
	cooling_off = add_input_port("Cooling Off", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/hfr_control/power/input_received(datum/port/input/port)
	if(port == power_on)
		reactor_core.start_power = TRUE
		reactor_core.update_use_power(reactor_core.start_power ? ACTIVE_POWER_USE : IDLE_POWER_USE)
	if(port == power_off)
		reactor_core.start_power = FALSE
		reactor_core.update_use_power(reactor_core.start_power ? ACTIVE_POWER_USE : IDLE_POWER_USE)
	if(port == cooling_on)
		reactor_core.start_cooling = TRUE
	if(port == cooling_off)
		reactor_core.start_cooling = FALSE
	if(port == reaction_selector || reactor_core.power_level == 0)
		reactor_core.selected_fuel = null
		var/fuel_mix = "nothing"
		var/datum/hfr_fuel/fuel = null
		if(reaction_selector.value != "")
			fuel = hfr_reactions[reaction_selector.value]
		if(fuel)
			reactor_core.selected_fuel = fuel
			fuel_mix = fuel.name
		if(reactor_core.internal_fusion.total_moles())
			reactor_core.dump_gases()
		reactor_core.update_parents()
		reactor_core.linked_input.update_parents()
		reactor_core.linked_output.update_parents()
		reactor_core.linked_moderator.update_parents()
		investigate_log("was set to recipe [fuel_mix ? fuel_mix : "null"] by [src]", INVESTIGATE_ATMOS)

/obj/item/circuit_component/hfr_control/power/populate_options()
	if(!hfr_reactions)
		hfr_reactions = list()
		for(var/fuel_id in GLOB.hfr_fuels_list)
			var/datum/hfr_fuel/reaction = GLOB.hfr_fuels_list[fuel_id]
			hfr_reactions[reaction.name] = reaction

/obj/item/circuit_component/hfr_control/core
	display_name = "HFR Core Control Circuit"
	desc = "Interfacing circuit for HFR controls and general reaction readouts"

	var/datum/port/input/heating_conductor
	var/datum/port/input/cooling_volume
	var/datum/port/input/magnetic_constrictor
	var/datum/port/input/current_dampener

	var/datum/port/output/temperature_readout
	var/datum/port/output/containment_integrity
	var/datum/port/output/iron_amount
	var/datum/port/output/fusion_level
	var/datum/port/output/fusion_energy
	var/datum/port/output/fusion_reactivity
	var/datum/port/output/fusion_instability

/obj/item/circuit_component/hfr_control/core/populate_ports()
	heating_conductor = add_input_port("Heating Conductor", PORT_TYPE_NUMBER)
	cooling_volume = add_input_port("Cooling Volume", PORT_TYPE_NUMBER)
	magnetic_constrictor = add_input_port("Magnetic Constrictor", PORT_TYPE_NUMBER)
	current_dampener = add_input_port("Current Dampener", PORT_TYPE_NUMBER)

	temperature_readout = add_output_port("Temperature Readout", PORT_TYPE_NUMBER)
	containment_integrity = add_output_port("Containment Field Integrity", PORT_TYPE_NUMBER)
	iron_amount = add_output_port("Core Iron Amount", PORT_TYPE_NUMBER)
	fusion_level = add_output_port("Fusion Level", PORT_TYPE_NUMBER)
	fusion_energy = add_output_port("Fusion Energy", PORT_TYPE_NUMBER)
	fusion_reactivity = add_output_port("Reaction Reactivity", PORT_TYPE_NUMBER)
	fusion_instability = add_output_port("Reation Instability", PORT_TYPE_NUMBER)

/obj/item/circuit_component/hfr_control/core/input_received(datum/port/input/port)
	if(heating_conductor != null)
		reactor_core.heating_conductor = clamp(heating_conductor.value, 50, 500)
	if(magnetic_constrictor != null)
		reactor_core.magnetic_constrictor = clamp(magnetic_constrictor.value, 50, 1000)
	if(current_dampener != null)
		reactor_core.current_damper = clamp(current_dampener.value, 0, 1000)
	if(cooling_volume != null)
		reactor_core.airs[1].volume = clamp(cooling_volume.value, 50, 2000)

	containment_integrity.set_output(reactor_core.critical_threshold_proximity / 9)
	iron_amount.set_output(reactor_core.iron_content)
	fusion_level.set_output(reactor_core.power_level)
	fusion_energy.set_output(reactor_core.energy)
	fusion_reactivity.set_output(reactor_core.heat_output / (reactor_core.heat_output < 0 ? reactor_core.heat_output_min : reactor_core.heat_output_max))
	fusion_instability.set_output(reactor_core.instability)

/obj/item/circuit_component/hfr_control/fuel
	display_name = "HFR Fuel Injection Control Circuit"
	desc = "Interfacing circuit for fuel injector along with core mixture readout"

	var/datum/port/input/injector_on
	var/datum/port/input/injector_off
	var/datum/port/input/fuel_input_rate

	var/datum/port/output/core_gasmix
	var/datum/port/output/core_moles
	var/datum/port/output/core_temp

/obj/item/circuit_component/hfr_control/fuel/populate_ports()
	injector_on = add_input_port("Fuel Injector On", PORT_TYPE_SIGNAL, trigger = PROC_REF(fuel_injector_toggle))
	injector_off = add_input_port("Fuel Injector Off", PORT_TYPE_SIGNAL, trigger = PROC_REF(fuel_injector_toggle))
	fuel_input_rate = add_input_port("Fuel Injection Rate", PORT_TYPE_NUMBER)

	core_gasmix = add_output_port("Reactor Core Gas Mix", PORT_TYPE_TABLE)
	core_moles = add_output_port("Reactor Core Mole Count", PORT_TYPE_NUMBER)
	core_temp = add_output_port("Reactor Core Temp", PORT_TYPE_NUMBER)

/obj/item/circuit_component/hfr_control/fuel/proc/fuel_injector_toggle(datum/port/input/port)
	CIRCUIT_TRIGGER

	if(port == injector_on)
		reactor_core.start_fuel = TRUE
	else
		reactor_core.start_fuel = FALSE

/obj/item/circuit_component/hfr_control/fuel/input_received(datum/port/input/port)
	reactor_core.fuel_injection_rate = clamp(fuel_input_rate.value, 0.5, 150)

	core_gasmix.set_output(get_core_gases())
	core_moles.set_output(reactor_core.internal_fusion.total_moles())
	core_temp.set_output(reactor_core.fusion_temperature)

/obj/item/circuit_component/hfr_control/fuel/proc/get_core_gases()
	. = list()
	for(var/gas_type in reactor_core.internal_fusion.gases)
		var/datum/gas/gas = gas_type
		. += list(
			"id" = gas::id,
			"name" = gas::name,
			"amount" = reactor_core.internal_fusion.gases[gas][MOLES] || 0,
		)

/obj/item/circuit_component/hfr_control/moderator
	display_name = "HFR Moderator Injection Control Circuit"
	desc = "Interfacing circuit for moderator injector along with moderating mixture readout"

	var/datum/port/input/moderator_on
	var/datum/port/input/moderator_off
	var/datum/port/input/moderator_input_rate
	var/datum/port/input/filter_on
	var/datum/port/input/filter_off
	var/datum/port/input/filter_rate
	var/datum/port/input/filter_gasses

	var/datum/port/output/moderator_gasmix
	var/datum/port/output/moderator_moles
	var/datum/port/output/moderator_temp

/obj/item/circuit_component/hfr_control/moderator/populate_ports()
	moderator_on = add_input_port("Moderator Injector On", PORT_TYPE_SIGNAL, trigger = PROC_REF(moderator_injector_toggle))
	moderator_off = add_input_port("Moderator Injector Off", PORT_TYPE_SIGNAL, trigger = PROC_REF(moderator_injector_toggle))
	moderator_input_rate = add_input_port("Moderator Injection Rate", PORT_TYPE_NUMBER)
	filter_on = add_input_port("Moderator Filtration On", PORT_TYPE_SIGNAL, trigger = PROC_REF(filtering_toggle))
	filter_off = add_input_port("Moderator Filtration Off", PORT_TYPE_SIGNAL, trigger = PROC_REF(filtering_toggle))
	filter_rate = add_input_port("Moderator Filtration Rate", PORT_TYPE_NUMBER)
	filter_gasses = add_input_port("Moderator Filtration List", PORT_TYPE_LIST(PORT_TYPE_STRING))

	moderator_gasmix = add_output_port("Moderator Gas Mix", PORT_TYPE_TABLE)
	moderator_moles = add_output_port("Moderator Mole Count", PORT_TYPE_NUMBER)
	moderator_temp = add_output_port("Moderator Gas Temp", PORT_TYPE_NUMBER)

/obj/item/circuit_component/hfr_control/moderator/proc/moderator_injector_toggle(datum/port/input/port)
	CIRCUIT_TRIGGER

	if(port == moderator_on)
		reactor_core.start_moderator = TRUE
	else
		reactor_core.start_moderator = FALSE

/obj/item/circuit_component/hfr_control/moderator/proc/filtering_toggle(datum/port/input/port)
	CIRCUIT_TRIGGER

	if(port == filter_on)
		reactor_core.waste_remove = TRUE
	else
		reactor_core.waste_remove = FALSE

/obj/item/circuit_component/hfr_control/moderator/input_received(datum/port/input/port)
	reactor_core.moderator_injection_rate = clamp(moderator_input_rate.value, 0.5, 150)
	reactor_core.moderator_filtering_rate = clamp(filter_rate.value, 5, 200)

	moderator_gasmix.set_output(get_moderator_gases())
	moderator_moles.set_output(reactor_core.moderator_internal.total_moles())
	moderator_temp.set_output(reactor_core.moderator_temperature)

/obj/item/circuit_component/hfr_control/moderator/proc/get_moderator_gases()
	. = list()
	for(var/gas_type in reactor_core.moderator_internal.gases)
		var/datum/gas/gas = gas_type
		. += list(
			"id" = gas::id,
			"name" = gas::name,
			"amount" = reactor_core.moderator_internal.gases[gas][MOLES] || 0,
		)
