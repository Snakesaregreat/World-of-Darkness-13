/obj/item/gun/medbeam
	name = "Healing Hand"
	desc = "It has some blood coming from it..."
	icon = 'icons/obj/chronos.dmi'
	icon_state = "medgun"
	inhand_icon_state = "medgun"
	w_class = WEIGHT_CLASS_NORMAL

	var/mob/living/current_target
	var/last_check = 0
	var/check_delay = 10 //Check los as often as possible, max resolution is SSobj tick though
	var/max_range = 8
	var/active = FALSE
	var/datum/beam/current_beam = null
	var/mounted = 0 //Denotes if this is a handheld or mounted version

	weapon_weight = WEAPON_MEDIUM

/obj/item/gun/medbeam/Initialize()
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/item/gun/medbeam/Destroy(mob/user)
	STOP_PROCESSING(SSobj, src)
	LoseTarget()
	return ..()

/obj/item/gun/medbeam/dropped(mob/user)
	..()
	LoseTarget()

/obj/item/gun/medbeam/equipped(mob/user)
	..()
	LoseTarget()

/**
 * Proc that always is called when we want to end the beam and makes sure things are cleaned up, see beam_died()
 */
/obj/item/gun/medbeam/proc/LoseTarget()
	if(active)
		qdel(current_beam)
		current_beam = null
		active = FALSE
		on_beam_release(current_target)
	current_target = null

/**
 * Proc that is only called when the beam fails due to something, so not when manually ended.
 * manual disconnection = LoseTarget, so it can silently end
 * automatic disconnection = beam_died, so we can give a warning message first
 */
/obj/item/gun/medbeam/proc/beam_died()
	active = FALSE //skip qdelling the beam again if we're doing this proc, because
	if(isliving(loc))
		to_chat(loc, "<span class='warning'>You lose control of the beam!</span>")
	LoseTarget()

/obj/item/gun/medbeam/process_fire(atom/target, mob/living/user, message = TRUE, params = null, zone_override = "", bonus_spread = 0)
	if(isliving(user))
		add_fingerprint(user)

	if(current_target)
		LoseTarget()
	if(!isliving(target))
		return

	current_target = target
	active = TRUE
	current_beam = user.Beam(current_target, icon_state="blood", time = 10 MINUTES, maxdistance = max_range, beam_type = /obj/effect/ebeam/medical)
	RegisterSignal(current_beam, COMSIG_PARENT_QDELETING, .proc/beam_died)//this is a WAY better rangecheck than what was done before (process check)

	SSblackbox.record_feedback("tally", "gun_fired", 1, type)

/obj/item/gun/medbeam/process()
	if(!mounted && !isliving(loc))
		LoseTarget()
		return

	if(!current_target)
		LoseTarget()
		return

	if(world.time <= last_check+check_delay)
		return

	last_check = world.time

	if(!los_check(loc, current_target))
		qdel(current_beam)//this will give the target lost message
		return

	if(current_target)
		on_beam_tick(current_target)

/obj/item/gun/medbeam/proc/los_check(atom/movable/user, mob/target)
	var/turf/user_turf = user.loc
	if(mounted)
		user_turf = get_turf(user)
	else if(!istype(user_turf))
		return FALSE
	var/obj/dummy = new(user_turf)
	dummy.pass_flags |= PASSTABLE|PASSGLASS|PASSGRILLE //Grille/Glass so it can be used through common windows
	for(var/turf/turf in getline(user_turf,target))
		if(mounted && turf == user_turf)
			continue //Mechs are dense and thus fail the check
		if(turf.density)
			qdel(dummy)
			return FALSE
		for(var/atom/movable/AM in turf)
			if(!AM.CanPass(dummy,turf,1))
				qdel(dummy)
				return FALSE
//		for(var/obj/effect/ebeam/medical/B in turf)// Don't cross the str-beams!
//			if(B.owner.origin != current_beam.origin)
//				explosion(B.loc,0,3,5,8)
//				qdel(dummy)
//				return FALSE
	qdel(dummy)
	return TRUE

/obj/item/gun/medbeam/proc/on_beam_hit(mob/living/target)
	return

/obj/item/gun/medbeam/proc/on_beam_tick(mob/living/target)
	if(target.health != target.maxHealth)
		new /obj/effect/temp_visual/heal(get_turf(target), "#FF0000")
	target.adjustBruteLoss(-20)
	target.adjustFireLoss(-20)
	target.adjustToxLoss(-10)
	target.adjustOxyLoss(-10)
	return

/obj/item/gun/medbeam/proc/on_beam_release(mob/living/target)
	return

/obj/effect/ebeam/medical
	name = "medical beam"

//////////////////////////////Mech Version///////////////////////////////
/obj/item/gun/medbeam/mech
	mounted = TRUE

/obj/item/gun/medbeam/mech/Initialize()
	. = ..()
	STOP_PROCESSING(SSobj, src) //Mech mediguns do not process until installed, and are controlled by the holder obj