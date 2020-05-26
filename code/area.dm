/*

### This file contains a list of all the areas in your station. Format is as follows:

/area/CATEGORY/OR/DESCRIPTOR/NAME 	(you can make as many subdivisions as you want)
	name = "NICE NAME" 				(not required but makes things really nice)
	icon = "ICON FILENAME" 			(defaults to areas.dmi)
	icon_state = "NAME OF ICON" 	(defaults to "unknown" (blank))
	requires_power = 0 				(defaults to 1)

*/

/////ZeWaka note: PLEASE stuff your areas in the right place, its organized

#define SIMS_DETAILED_SCOREKEEPING

//
/area
	var/active = 0 //True if a dude is here (DOES NOT APPLY TO THE "SPACE" AREA)
	var/list/population = list() //Who is here (ditto)
	var/fire = null
	var/atmos = 1
	var/poweralm = 1
	var/skip_sims = 0
	var/sims_score = 100
	var/virtual = 0
	var/gencolor
	level = null
	#ifdef UNDERWATER_MAP
	name = "Ocean"
	#else
	name = "Space"
	#endif
	icon = 'icons/turf/areas.dmi'
	icon_state = "unknown"
	layer = EFFECTS_LAYER_BASE
	mouse_opacity = 0
	mat_changename = 0
	mat_changedesc = 0
	var/lightswitch = 1
	var/may_eat_here_in_restricted_z = 0

	var/eject = null

	var/obj/machinery/power/apc/area_apc = null // okay in certain cases you may have more than one apc, but for my purposes the latest apc works just fine

	var/requires_power = 1
	var/power_equip = 1
	var/power_light = 1
	var/power_environ = 1
	var/used_equip = 0
	var/used_light = 0
	var/used_environ = 0
	var/expandable = 1

	var/irradiated = 0 // space blowouts use this, should always be 0
	var/permarads = 0 // Blowouts don't set irradiated on this area back to zero.
	var/do_not_irradiate = 1 // don't irradiate this place!!
	// Definitely DO NOT var-edit areas in the map editor because it apparently causes individual tiles
	// to become detached from the parent area. Example: APCs belonging to medbay or whatever that are in
	// adjacent maintenance tunnels, not in the same room they're powering. If you set the d_n_i flag,
	// it will render them useless.

	var/datum/gang/gang_owners = null // gang that owns this area in gang mode
	var/gang_base = 0 // is this a gang's base (uncaptureable)?
	var/being_captured = null // for gang mode

	var/filler_turf = null		// if set, replacewithspace in this area instead replaces with this turf type

	var/teleport_blocked = 0 //Cannot teleport into this area without some explicit set_loc thing. 1 for most things, 2 for definitely everything.

	var/workplace = 0 //Do people work here?

	var/list/obj/critter/registered_critters = list()
	var/waking_critters = 0

	var/sound_loop = null
	var/sound_loop_vol = 50
	var/sound_fx_1 = null
	var/sound_fx_2 = null
	var/played_fx_1 = 0
	var/played_fx_2 = 0
	var/sound_group = null
	var/sound_environment = 1 //default environment for sounds - see sound datum vars documentation for the presets.

	var/sanctuary = 0//set to 1 to inhibit attacks in this area.
	var/blocked   = 0//set to 1 to inhibit entrance into this area, may not work completely yet.
	var/blocked_waypoint //if set and a blocked person makes their way into here via Bad Ways, they'll be teleported here instead of nullspace. use a path!
	var/list/blockedTimers
	var/storming = 0 // for BR

	var/obj/machinery/light_area_manager/light_manager = 0
	var/list/machines = list()

	proc/CanEnter(var/atom/movable/A)
		if( blocked )
			if( ismob(A) )
				var/mob/M = A
				if( !M.client )
					return 0
				if( !blockedTimers ) blockedTimers = list()
				if( !blockedTimers[ M.client.key ] || blockedTimers[ M.client.key ] < world.time )
					return 0
			else
				return 0
		else
			return 1

	Entered(var/atom/movable/A, atom/oldloc)
		if (ismob(A))
			var/mob/M = A
			if (M.client)
				#define AMBIENCE_ENTER_PROB 6

				//Handle ambient sound
				var/area/lastarea = get_area(oldloc)
				if (lastarea) //People can come from places with no area. :byondood:
					M.client.last_soundgroup = lastarea.sound_group

				if (sound_loop)
					M.client.playAmbience(src, AMBIENCE_LOOPING, sound_loop_vol)

				if (!played_fx_1 && prob(AMBIENCE_ENTER_PROB))
					src.pickAmbience()
					M.client.playAmbience(src, AMBIENCE_FX_1, 18)
				#undef AMBIENCE_ENTER_PROB

		if ((isliving(A) || iswraith(A)) || locate(/mob) in A)
			if (!Z4_ACTIVE && A.z == 4) Z4_ACTIVE = 1//bloop
			//world.log << "[src] entered by [A]"
			//Just...deal with this
			var/list/enteringMobs = get_all_mobs_in(A)

			//If any mobs are entering, within a thing or otherwise
			if (enteringMobs.len > 0)
				for (var/mob/enteringM in enteringMobs) //each dumb mob
					if( !(isliving(enteringM) || iswraith(enteringM)) ) continue
					//Wake up a bunch of lazy darn critters
					if (isliving(enteringM))
						wake_critters()

					//If it's a real fuckin player
					if (enteringM.ckey && enteringM.client)
						if( !CanEnter( enteringM ) )

							var/target = get_turf(oldloc)
							if( !target && blocked_waypoint )
								target = get_turf(locate(blocked_waypoint) in world)
							enteringM.loc = target
						var/area/oldarea = get_area(oldloc)
						if( sanctuary && !blocked && !(oldarea.sanctuary))
							boutput( enteringM, "<b style='color:#31BAE8'>You are entering a sanctuary zone. You cannot be harmed by other players here.</b>" )
						if (src.name != "Space" || src.name != "Ocean") //Who cares about making space active gosh
							if (!(enteringM.mind in src.population))
								src.population += enteringM.mind
							if (!src.active)
								src.active = 1

						//Dumb fucking medal fuck
						if (src.name == "Space" && istype(A, /obj/vehicle/segway))
							enteringM.unlock_medal("Jimi Heselden", 1)

		else if(oldloc && !ismob(A) && !CanEnter( A ))
			A.loc = oldloc
		..()

	Exited(var/atom/movable/A)
		if (ismob(A))
			var/mob/M = A
			if (M.client)
				if (sound_loop)
					SPAWN_DBG(1 DECI SECOND)
						var/area/mobarea = get_area(M)
						if (M && (mobarea.sound_group != src.sound_group))
							M.client.playAmbience(src, AMBIENCE_LOOPING, 0) //pass 0 to cancel

		if ((isliving(A) || iswraith(A)) || locate(/mob) in A)
			//world.log << "[src] exited by [A]"
			//Deal with this too
			var/list/exitingMobs = get_all_mobs_in(A)

			if (exitingMobs.len > 0)
				for (var/mob/exitingM in exitingMobs)
					if (exitingM.ckey && exitingM.client && exitingM.mind)
						var/area/the_area = get_area(exitingM)
						if( sanctuary && !blocked && !(the_area.sanctuary) )
							boutput( exitingM, "<b style='color:#31BAE8'>You are leaving the sanctuary zone.</b>" )
						if( blocked && !exitingM.client.holder )
							blockedTimers[ exitingM.client.key ] = world.time + 300
							boutput( exitingM, "<b class='alert'>If you stay out of [name] for 30 seconds, you will be prevented from re-entering.</b>" )

						if (src.name != "Space" || src.name != "Ocean")
							if (exitingM.mind in src.population)
								src.population -= exitingM.mind
							if (src.active && src.population.len == 0) //Only if this area is now empty
								src.active = 0

						//Put whatever you want here. See Entering above.

		..()

	proc/find_middle(var/mustbeinside = 1)
		var/minx = 300
		var/miny = 300
		var/maxx = 0
		var/maxy = 0
		var/minz = 100
		var/hasturfs = 0
		for (var/turf/T in src)
			if (minx > T.x)
				minx = T.x
			if (miny > T.y)
				miny = T.y
			if (maxx < T.x)
				maxx = T.x
			if (maxy < T.y)
				maxy = T.y
			if (minz > T.z)
				minz = T.z
			hasturfs = 1
		if (!hasturfs)
			return 0
		var/midx = round((minx + maxx) / 2)
		var/midy = round((miny + maxy) / 2)
		var/midz = minz
		var/turf/R = locate(midx, midy, midz)
		if (mustbeinside)
			if (!(R in src))
				return null
		return R

	proc/build_sims_score()
		if (name == "Space" || src.name == "Ocean" || type == /area || skip_sims)
			return
		sims_score = 100
		for (var/turf/T in src)
			var/penalty = 0
			var/list/loose_items = list()
			for (var/obj/O in T)
				if (isitem(O))
					penalty += 4
					loose_items += O
				if (istype(O, /obj/decal/cleanable))
					sims_score -= 6
			if ((locate(/obj/table) in T) || (locate(/obj/rack) in T))
				continue
			else
				sims_score -= penalty
		sims_score = max(sims_score, 0)

	proc/wake_critters()
		if(waking_critters || !registered_critters.len) return
		waking_critters = 1
		for(var/obj/critter/C in src.registered_critters)
			C.wake_from_hibernation()
		waking_critters = 0

	proc/calculate_area_value()
		var/value = 0
		for (var/turf/simulated/floor/F in src.contents)
			if (F.broken || F.burnt || F.icon_state == "plating")
				continue
			value++

		for (var/obj/machinery/M in src.contents)
			if (M.status & BROKEN || M.status & NOPOWER)
				continue
			value++

		return value

	proc/calculate_structure_value()
		var/value = 0
		for (var/turf/simulated/wall/W in src.contents)
			value++
		for (var/turf/simulated/floor/F in src.contents)
			if (F.broken || F.burnt)
				continue
			value++
		for (var/obj/machinery/light/L in src.contents)
			if (L.light_status != 0) //See LIGHT_OK
				continue
			value++
		for (var/obj/window/W in src.contents)
			value++

		return value

	proc/calculate_area_cleanliness()
		var/total_count = 0
		var/clean_count = 0
		var/dirty = 0
		var/list/dirtyStuff = list(/obj/decal/cleanable,/obj/fluid)

		for (var/turf/simulated/T in src.contents)
			dirty = 0
			total_count++
			for (var/thing in T.contents)
				for(var/dirtyType in dirtyStuff)
					if(istype(thing, dirtyType))
						dirty = 1
						break
				if(dirty)
					break
			if (!dirty)
				clean_count++
		if (total_count == 0) return -1
		else return get_percentage_of_fraction_and_whole(clean_count,total_count)

	proc/pickAmbience()
		switch(src.name)
			if ("Chapel") sound_fx_1 = pick('sound/ambience/station/Chapel_FemaleChoir.ogg','sound/ambience/station/Chapel_ChoirTwoNote1.ogg','sound/ambience/station/Chapel_ChoirTwoNote2.ogg','sound/ambience/station/Chapel_HighFemaleSolo.ogg')
			if ("Morgue") sound_fx_1 = pick('sound/ambience/station/Station_SpookyAtmosphere1.ogg','sound/ambience/station/Station_SpookyAtmosphere2.ogg')
			if ("Jazz Lounge") sound_fx_1 = 'sound/ambience/station/JazzLounge1.ogg'
			if ("Zen Garden") sound_fx_1 = pick('sound/ambience/station/ZenGarden1.ogg','sound/ambience/station/ZenGarden2.ogg')
			//if ("Engine Control") sound_fx_1 = pick(ambience_engine)
			//if ("Atmospherics") sound_fx_1 = pick(ambience_atmospherics)
			if ("Radio Server") sound_fx_1 = pick(ambience_computer) //"Computer Core"
			//if ("Engineering Power Room") sound_fx_1 = pick(ambience_power)
			if ("Ice Moon") sound_fx_1 = pick('sound/ambience/nature/Wind_Cold1.ogg', 'sound/ambience/nature/Wind_Cold2.ogg', 'sound/ambience/nature/Wind_Cold3.ogg')
			if ("Biodome North") sound_fx_1 = pick('sound/ambience/nature/Biodome_Bugs.ogg', 'sound/ambience/nature/Biodome_Birds1.ogg', 'sound/ambience/nature/Biodome_Birds2.ogg', 'sound/ambience/nature/Biodome_Monkeys.ogg')
			if ("Biodome South") sound_fx_1 = pick('sound/ambience/nature/Biodome_Bugs.ogg', 'sound/ambience/nature/Biodome_Birds1.ogg', 'sound/ambience/nature/Biodome_Birds2.ogg', 'sound/ambience/nature/Biodome_Monkeys.ogg')
			if ("Caves") sound_fx_1 = pick('sound/ambience/nature/Cave_Bugs.ogg', 'sound/ambience/nature/Cave_Rumbling.ogg', 'sound/ambience/nature/Cave_Wind1.ogg', 'sound/ambience/nature/Cave_Wind2.ogg', 'sound/ambience/nature/Cave_Drips.ogg')
			if ("Glacial Abyss") sound_fx_1 = pick('sound/ambience/nature/Glacier_DeepRumbling1.ogg','sound/ambience/nature/Glacier_DeepRumbling1.ogg', 'sound/ambience/nature/Glacier_DeepRumbling1.ogg', 'sound/ambience/nature/Glacier_IceCracking.ogg', 'sound/ambience/nature/Glacier_DeepRumbling1.ogg', 'sound/ambience/nature/Glacier_Scuttling.ogg')
			if ("AI Satellite Core") sound_fx_1 = pick('sound/ambience/station/Station_SpookyAtmosphere1.ogg','sound/ambience/station/Station_SpookyAtmosphere2.ogg')
			if ("The Blind Pig") sound_fx_1 = pick('sound/ambience/spooky/TheBlindPig.ogg','sound/ambience/spooky/TheBlindPig2.ogg')
			if ("M. Fortuna's House of Fortune") sound_fx_1 = 'sound/ambience/spooky/MFortuna.ogg'
			#ifdef SUBMARINE_MAP
			else sound_fx_1 = pick(ambience_submarine)
			#endif
			else sound_fx_1 = pick(ambience_general)

	proc/add_light(var/obj/machinery/light/L)
		if (!light_manager)
			light_manager = new
			light_manager.my_area = src
			for(var/turf/T in src)
				light_manager.loc = T
				break
		light_manager.lights += L

	proc/remove_light(var/obj/machinery/light/L)
		if (light_manager)
			light_manager.lights -= L
	New()
		if( type == /area )
			power_equip = power_light = power_environ = 0
//////////////////////////// zewaka - adventure/technical/admin areas below

/area/cordon
	name = "CORDON"
	icon = 'icons/effects/mapeditor.dmi'
	icon_state = "cordonarea"
	invisibility = 101
	teleport_blocked = 2
	force_fullbright = 1
	expandable = 0//oh god i know some fucker would try this

	Entered(atom/movable/O) // TODO: make this better and not copy n pasted from area_that_kills_you_if_you_enter_it
		..()
		if (isobserver(O))
			return
		if (ismob(O))
			var/mob/jerk = O
			if ((jerk.client && jerk.client.flying))
				return
			setdead(jerk)
			jerk.remove()
		else if (isobj(O) && !istype(O, /obj/overlay/tile_effect))
			qdel(O)
		return

	dark
		force_fullbright = 0
		luminosity = 0

/area/titlescreen
	name = "The Title Screen"
	teleport_blocked = 2
	force_fullbright = 1
	expandable = 0
	// filler_turf = "/turf/unsimulated/floor/setpieces/gauntlet"

/area/cavetiny
	name = "Caves"
	icon_state = "purple"
	skip_sims = 1
	sims_score = 50
	force_fullbright = 0
	sound_environment = 8
	teleport_blocked = 1
	sound_group = "tinycave"

/area/fermented_potato
	name = "????"
	icon_state = "purple"
	skip_sims = 1
	sims_score = 50
	force_fullbright = 0
	teleport_blocked = 1

/area/area_that_kills_you_if_you_enter_it //People entering VR or exiting VR with stupid exploits are jerks.
	name = "Invisible energy field that will kill you if you step into it"
	skip_sims = 1
	sims_score = 0
	icon_state = "death"
	requires_power = 0
	teleport_blocked = 1

	Entered(atom/movable/O)
		if (isobserver(O))
			return
		if (ismob(O))
			var/mob/jerk = O
			if ((jerk.client && jerk.client.flying))
				return
			setdead(jerk)
			jerk.remove()
		else if (isobj(O) && !istype(O, /obj/overlay/tile_effect))
			qdel(O)
		return

/area/battle_royale_spawn //People entering VR or exiting VR with stupid exploits are jerks.
	name = "Battle Royale warp zone"
	skip_sims = 1
	sims_score = 0
	icon_state = "battle_spawn"
	requires_power = 0
	teleport_blocked = 1

	Entered(atom/movable/O)
		var/dest = null
		..()
		if (isobserver(O))
			return
		if (ismob(O))
			var/mob/jerk = O
			dest = pick(get_area_turfs(current_battle_spawn,1))
			if(!dest)
				dest= pick(get_area_turfs(/area/station/maintenance/,1))
				boutput(jerk, "You somehow land in maintenance! Weird!")
			jerk.set_loc(dest)
			jerk.nodamage = 0
			jerk.removeOverlayComposition(/datum/overlayComposition/shuttle_warp)
			jerk.removeOverlayComposition(/datum/overlayComposition/shuttle_warp/ew)
		else if (isobj(O) && !istype(O, /obj/overlay/tile_effect))
			qdel(O)
		return

/area/build_zone // currently for z4 just so people don't teleport in there randomly
	name = "Build Space"
	icon_state = "death"
	skip_sims = 1
	sims_score = 25
	requires_power = 0
	teleport_blocked = 1
	force_fullbright = 1
	filler_turf = "/turf/unsimulated/nicegrass/random"

//////////////////////////// zewaka - shuttle areas, read below note

//These are shuttle areas, they must contain two areas in a subgroup if you want to move a shuttle from one
//place to another. Look at escape shuttle for example.

/area/shuttle //DO NOT TURN THE RL_Lighting STUFF ON FOR SHUTTLES. IT BREAKS THINGS.
#ifdef HALLOWEEN
	alpha = 128
	icon = 'icons/effects/dark.dmi'
#elif defined(UNDERWATER_MAP)
	requires_power = 0
	force_fullbright = 0
	luminosity = 0
#else
	requires_power = 0
	luminosity = 1
	force_fullbright = 1
#endif
	sound_environment = 2
	expandable = 0

/area/shuttle/arrival
	name = "Arrival Shuttle"
	//sanctuary = 1//waka waka bang bang
	teleport_blocked = 2
	//blocked = 1
	//blocked_waypoint = /obj/landmark/block_waypoint/shuttle

/area/shuttle/arrival/pre_game
	icon_state = "shuttle2"

/area/shuttle/arrival/station
	icon_state = "shuttle"
	flags = ALWAYS_SOLID_FLUID

/area/shuttle/escape
	name = "Emergency Shuttle"

/area/shuttle/escape/station
	icon_state = "shuttle2"

/area/shuttle/escape/centcom
	icon_state = "shuttle"
	sound_group = "centcom"

/area/shuttle/prison/
	name = "Prison Shuttle"

/area/shuttle/prison/station
	icon_state = "shuttle"

/area/shuttle/prison/prison
	icon_state = "shuttle2"

/area/shuttle/brig/station
	icon_state = "shuttle"

/area/shuttle/brig/prison
	icon_state = "shuttle2"

/area/shuttle/brig/outpost
	icon_state = "shuttle3"

/area/shuttle/research/station
	icon_state = "shuttle"

/area/shuttle/research/outpost
	icon_state = "shuttle2"

/area/shuttle/attack2/prison
	icon_state = "shuttle2"

/area/shuttle/mining/station
	icon_state = "shuttle"

/area/shuttle/mining/space
	icon_state = "shuttle2"

/area/shuttle/icebase_elevator/upper
	icon_state = "shuttle"
	filler_turf = "/turf/simulated/floor/arctic/abyss"
	force_fullbright = 0
	sound_group = "ice_moon"

/area/shuttle/icebase_elevator/lower
	icon_state = "shuttle2"
	filler_turf = "/turf/simulated/floor/arctic/snow/ice"
	force_fullbright = 0
	sound_group = "ice_moon"

/area/shuttle/biodome_elevator/upper
	icon_state = "shuttle"
	force_fullbright = 0
	name = "Elevator"

/area/shuttle/biodome_elevator/lower
	icon_state = "shuttle2"
	force_fullbright = 0
	name = "Elevator"

/area/recovery_shuttle
	icon_state = "shuttle2"
	name = "Recovery Shuttle"

/area/shuttle/merchant_shuttle
	icon_state = "shuttle2"
	name = "Merchant Shuttle"
	teleport_blocked = 1

/area/shuttle/merchant_shuttle/left_centcom

/area/shuttle/merchant_shuttle/right_centcom

/area/shuttle/merchant_shuttle/diner_centcom

/area/shuttle/merchant_shuttle/diner_station

/area/shuttle/merchant_shuttle/left_station
	icon_state = "shuttle2"

/area/shuttle/merchant_shuttle/right_station
	icon_state = "shuttle2"

/area/shuttle/spacebus
	name = "Space Bus"

/area/shuttle/escape/transit
	icon_state = "eshuttle_transit"
	sound_group = "eshuttle_transit"
	var/warp_dir = NORTH // fuck you

	Entered(atom/movable/Obj,atom/OldLoc)
		..()
		if (ismob(Obj))
			var/mob/M = Obj
			if (src.warp_dir & NORTH || src.warp_dir & SOUTH)
				M.addOverlayComposition(/datum/overlayComposition/shuttle_warp)
			else
				M.addOverlayComposition(/datum/overlayComposition/shuttle_warp/ew)

	Exited(atom/movable/Obj)
		..()
		if (ismob(Obj))
			var/mob/M = Obj
			M.removeOverlayComposition(/datum/overlayComposition/shuttle_warp)

/area/shuttle/escape/transit/ew
	warp_dir = EAST

/area/shuttle_transit_space
	name = "Wormhole"
	icon_state = "shuttle_transit_space_n"
	teleport_blocked = 1
	var/throw_dir = NORTH // goddamnit x2
	expandable = 0

	Entered(atom/movable/Obj,atom/OldLoc)
		..()
		if (ismob(Obj))
			var/mob/M = Obj
			if (src.throw_dir == NORTH || src.throw_dir == SOUTH)
				M.addOverlayComposition(/datum/overlayComposition/shuttle_warp)
			else
				M.addOverlayComposition(/datum/overlayComposition/shuttle_warp/ew)
		if (!isobserver(Obj) && !isintangible(Obj) && !iswraith(Obj) && !istype(Obj,/obj/machinery/vehicle/escape_pod))
			var/atom/target = get_edge_target_turf(src, src.throw_dir)
			if (OldLoc && isturf(OldLoc))
				SPAWN_DBG(0)
					if (target && Obj)
						Obj.throw_at(target, 1, 1)

	Exited(atom/movable/Obj)
		..()
		if (ismob(Obj))
			var/mob/M = Obj
			M.removeOverlayComposition(/datum/overlayComposition/shuttle_warp)

/area/shuttle_transit_space/south
	icon_state = "shuttle_transit_space_s"
	throw_dir = SOUTH
/area/shuttle_transit_space/east
	icon_state = "shuttle_transit_space_e"
	throw_dir = EAST
/area/shuttle_transit_space/west
	icon_state = "shuttle_transit_space_w"
	throw_dir = WEST

/area/shuttle_particle_spawn
	icon_state = "shuttle_transit_stars_n"
	teleport_blocked = 1
	var/star_dir = null // particle system defaults to northbound stars

	proc/start_particles()
		for (var/turf/T in src)
			particleMaster.SpawnSystem(new /datum/particleSystem/warp_star(T, src.star_dir))

/area/shuttle_particle_spawn/south
	icon_state = "shuttle_transit_stars_s"
	star_dir = "_s"

/area/shuttle_particle_spawn/east
	icon_state = "shuttle_transit_stars_e"
	star_dir = "_e"

/area/shuttle_particle_spawn/west
	icon_state = "shuttle_transit_stars_w"
	star_dir = "_w"

/area/shuttle_sound_spawn
	icon_state = "shuttle_transit_sound"
	teleport_blocked = 1

/////////////////////////////////////zewaka - actual areas below

/////////////////////zewaka - adventure zone areas

/area/station/wreckage
	name = "Twisted Wreckage"
	icon_state = "donutbridge"
	sound_environment = 14
	do_not_irradiate = 1

/area/otherdimesion //moved from actuallyKeelinsStuff.dm
	requires_power = 0
	luminosity = 1
	force_fullbright = 1
	name = "Somewhere"
	icon_state = "shuttle2"

/area/someplace
	name = "some place"
	icon_state = "purple"
	filler_turf = "/turf/simulated/floor/void"
	requires_power = 0
	luminosity = 1
	force_fullbright = 1
	skip_sims = 1
	sims_score = 15
	expandable = 0
	sound_group = "some place"
	sound_loop = 'sound/ambience/spooky/Somewhere_Tone.ogg'

/area/someplacehot
	name = "some place"
	icon_state = "atmos"
	filler_turf = "/turf/simulated/floor/void"
	requires_power = 0
	luminosity = 1
	force_fullbright = 1
	skip_sims = 1
	sims_score = 15
	sound_group = "some place hot"
	sound_loop = 'sound/ambience/loop/Fire_Medium.ogg'
	sound_loop_vol = 75

	Entered(atom/movable/Obj,atom/OldLoc)
		..()
		if(ismob(Obj))
			Obj:addOverlayComposition(/datum/overlayComposition/heat)
		return

	Exited(atom/movable/Obj)
		..()
		if(ismob(Obj))
			Obj:removeOverlayComposition(/datum/overlayComposition/heat)
		return

/area/crunch/wtc
	name = "Mysterious Facility"
	icon_state = "purple"
	requires_power = 0
	sound_environment = 4
	teleport_blocked = 1
	expandable = 0

/*/area/factory
	name = "Derelict Robot Factory"
	icon_state = "start"

/area/factory/core
	name = "Aged Computer Core"
	icon_state = "ai"

/area/old_outpost
	name = "Derelict Outpost"
	icon_state = "yellow"
	sound_environment = 12

/area/old_outpost/engine
	name = "Outpost Engine"
	icon_state = "dk_yellow"
	sound_environment = 10

/area/old_outpost/control
	name = "Outpost Control"
	icon_state = "purple"

/area/old_outpost/medical
	name = "VR Research"
	icon_state = "medresearch"
	sound_environment = 3

/area/old_outpost/study
	name = "Outpost Study"
	icon_state = "green"
	sound_environment = 4

/area/old_outpost/teleporter
	name = "Outpost Teleporter"
	icon_state = "teleporter"
	sound_environment = 2*/


/area/adventure
	name = "Adventure Zone"
	icon_state = "purple"
	force_fullbright = 0
	sound_environment = 31
	skip_sims = 1
	sims_score = 30
	virtual = 1
	expandable = 0


/////////////////////// zewaka - debris field areas/Spacejunk

/area/buddyfactory
	name = "Factory V"
	icon_state = "yellow"
	expandable = 0

/area/buddyfactory/mainframe
	name = "Old Computer Core"
	icon_state = "purple"

/area/space_hive
	name = "Space Bee Hive"
	icon_state = "yellow"
	force_fullbright = 0
	sound_environment = 20
	teleport_blocked = 1
	skip_sims = 1
	sims_score = 100

/area/helldrone
	name = "Drone Corpse"
	icon_state = "red"
	sound_environment = 3
	teleport_blocked = 1
	skip_sims = 1
	sims_score = 50

	var/list/soundSubscribers = list()

	New()
		..()

		SPAWN_DBG (60)
			if (!helldrone_awake_sound)
				helldrone_awake_sound = new/sound()
				helldrone_awake_sound.file = 'sound/machines/giantdrone_loop.ogg'
				helldrone_awake_sound.repeat = 0
				helldrone_awake_sound.wait = 0
				helldrone_awake_sound.channel = 122
				helldrone_awake_sound.volume = 60
				helldrone_awake_sound.priority = 255
				helldrone_awake_sound.status = SOUND_UPDATE

			if (!helldrone_wakeup_sound)
				helldrone_wakeup_sound = new/sound()
				helldrone_wakeup_sound.file = 'sound/machines/giantdrone_startup.ogg'
				helldrone_wakeup_sound.repeat = 0
				helldrone_wakeup_sound.wait = 0
				helldrone_wakeup_sound.channel = 122
				helldrone_wakeup_sound.volume = 60
				helldrone_wakeup_sound.priority = 255
				helldrone_wakeup_sound.status = SOUND_UPDATE

	Entered(atom/movable/Obj,atom/OldLoc)
		..()
		if(ismob(Obj))
			if (!soundSubscribers:Find(Obj))
				soundSubscribers += Obj

		return

	core
		Entered(atom/movable/O)
			..()
			if (isliving(O) && !helldrone_awake)
				helldrone_awake = 1
				SPAWN_DBG (20)
					helldrone_wakeup()
					src.process()

	proc/process()
		if (!soundSubscribers || !helldrone_awake)
			return

		var/sound/S = null
		var/sound_delay = 0


		while(current_state < GAME_STATE_FINISHED)
			sleep(6 SECONDS)
/*
			if(prob(10) && fxlist)
				S = sound(file=pick(fxlist), volume=50)
				sound_delay = rand(0, 50)
			else
				S = null
				continue
*/
			for(var/mob/living/H in soundSubscribers)
				var/area/mobArea = get_area(H)
				if (!istype(mobArea) || mobArea.type != src.type)
					soundSubscribers -= H
					if (H.client)
						helldrone_awake_sound.status = SOUND_PAUSED | SOUND_UPDATE
						helldrone_awake_sound.volume = 0
						H << helldrone_awake_sound
					continue

				if(H.client)
					helldrone_awake_sound.status = SOUND_UPDATE
					helldrone_awake_sound.volume = 60
					H << helldrone_awake_sound
					if(S)
						SPAWN_DBG(sound_delay)
							H << S

/area/helldrone/core
	name = "Drone Computer Core"
	icon_state = "ai"
	skip_sims = 1
	sims_score = 30

//zewaka note: moved these from near adventure zone areas

/area/martian_trader
	name ="Martian Trade Outpost"
	sound_environment = 8

/area/abandonedmedicalship
	name = "Abandoned Medical ship"
	icon_state = "yellow"

/area/abandonedoutpostthing
	name = "Abandoned Outpost"
	icon_state = "yellow"

/area/abandonedmedicalship/robot_trader
	name ="Robot Trade Outpost"
	icon_state ="green"
	sound_environment = 3
/area/bee_trader
	name ="Bombini's Ship"
	icon_state ="green"
	sound_environment = 2

/area/flock_trader
	name = "Flocktrader Ship"
	icon_state = "green"
	sound_environment = 2

/area/skeleton_trader
	name = "Skeleton Trade Outpost"
	icon_state = "green"
	sound_environment = 2

/area/fermid_hive
	name = "Fermid Hive"
	icon_state = "purple"


/area/iss
	name = "Derelict Space Station"
	icon_state = "derelict"
#ifdef SUBMARINE_MAP
	force_fullbright = 1
#endif


/area/abandonedship
	name = "Abandoned ship"
	icon_state = "yellow"

/area/spacehabitat
	name = "Habitat Dome"
	icon_state = "green"

/area/spacehabitat/beach
	name = "Habitat Dome Beach"
	icon_state = "yellow"
	force_fullbright = 1

/area/salyut
	name = "Soviet derelict"
	icon_state = "yellow"

/area/hollowasteroid/ //evilderelict.dm
	name = "Forgotten Subterranean Wreckage"
	icon_state = "derelict"
	sound_loop = 'sound/ambience/spooky/Evilreaver_Ambience.ogg'

/area/diner
	sound_environment = 12

/area/diner/hangar
	name = "Diner Parking"
	icon_state = "storage"

/area/diner/kitchen
	name = "Diner Kitchen"
	icon_state = "purple"

/area/diner/dining
	name = "Diner Seating Area"
	icon_state = "green"

/area/diner/bathroom
	name = "Diner Bathroom"
	icon_state = "showers"

/area/diner/hallway
	name = "Diner Hallway"
	icon_state = "blue"

/area/diner/backroom
	name = "Diner Backroom"
	icon_state = "green"

/area/diner/solar
	name = "Diner Solar Control"
	icon_state = "yellow"

/area/diner/motel
	name = "Space Motel"
	icon_state = "orange"

/area/diner/motel/observatory
	name = "Motel Observatory"
	icon_state = "blue"

/area/diner/motel/pool
	name = "Motel Pool"
	icon_state = "yellow"

/area/diner/motel/chemstorage
	name = "Chemical Storage"
	icon_state = "orange"

/area/tech_outpost
	name = "Tech Outpost"
	icon_state = "storage"

/////////////////////// Sealab trench areas

/area/shuttle/sea_elevator_room
	name = "Sea Elevator Room"
	icon_state = "purple"

/area/shuttle/sea_elevator
	name = "Sea Elevator Shaft"
	icon_state = "blue"

/area/shuttle/sea_elevator/lower
	name = "Sea Elevator Shaft"
	icon_state = "shuttle2"
	filler_turf = "/turf/simulated/floor/plating"

/area/shuttle/sea_elevator/upper
	name = "Sea Elevator Shaft"
	icon_state = "shuttle"
	filler_turf = "/turf/simulated/floor/specialroom/sea_elevator_shaft"


/area/trench_landing
	name = "Trench Landing"
	icon_state = "yellow"

/area/blind_pig
	name = "The Blind Pig"
	icon_state = "red"
	sound_environment = 4

/area/brindle
	name = "Brindle Laboratory for Genomic Research"
	icon_state = "blue"
	sound_environment = 2

/area/helianthus
	name = "Helianthus Institute Greenhouse"
	icon_state = "green"
	sound_environment = 15

/area/sandy_ruins
	name = "Sandy Ruins"
	icon_state = "yellow"
	ambient_light = rgb(37, 53, 79)
	sound_environment = 8

/area/deserted_outpost
	name = "Deserted Outpost"
	icon_state = "red"
	sound_environment = 2

/area/mobius
	name = "Mobius Strip Mall"
	icon_state = "purple"
	sound_environment = 2
	sound_loop = 'sound/ambience/music/shoptheme.ogg'

/area/mobius/mfortuna
	name = "M. Fortuna's House of Fortune"

/area/raceway
	name = "Abandoned Raceway"
	icon_state = "purple"
	sound_environment = 9

/area/zoo
	name = "Forgotten Zoo"
	icon_state = "orange"
	sound_environment = 23

/area/sea_monkey_hideout
	name = "Sea Monkey Hideout"
	icon_state = "purple"
	sound_environment = 4

/area/sea_prison
	name = "Sunken Temporary Holding Facility"
	icon_state = "red"
	sound_environment = 12

/area/replicant_lab
	name = "Workshop"
	icon_state = "orange"
	sound_environment = 21

/area/ghost_house
	name = "Ghost House"
	icon_state = "purple"
	sound_environment = 23

/area/slimy_honk
	name = "Slimy's House of Fun and Burgers"
	icon_state = "purple"

/area/sea_sketch
	name = "Sketchy Den"
	icon_state = "purple"

/area/sea_mining
	name = "Mining Outpost"
	icon_state = "purple"

/area/station/turret_protected/sea_crashed //dumb area pathing aRRGHHH
	name = "Crashed Transport"
	icon_state = "purple"

/area/water_treatment
	name = "Water Treatment Facility"
	icon_state = "purple"

/area/station/bee_sanctuary
	name = "Bee Sanctuary"
	icon_state = "purple"

//////////////////////////// zewaka - vspace areas

/area/sim
	name = "Sim"
	icon_state = "purple"
	luminosity = 1
	force_fullbright = 1
	requires_power = 0
	teleport_blocked = 1
	virtual = 1
	skip_sims = 1
	sims_score = 100
	sound_group = "vr"

/area/sim/area1
	name = "Vspace area 1"
	icon_state = "simA1"

/area/sim/a1entry
	name = "Vspace area 1 Entry"
	icon_state = "simA1E"

/area/sim/area2
	name = "Vspace area 2"
	icon_state = "simA2"

/area/sim/a2entry
	name = "Vspace area 2 Entry"
	icon_state = "simA2E"

/area/sim/bball
	name = "B-Ball Court"
	icon_state="vr"

/area/sim/gunsim
	name = "Gun Sim"
	icon_state = "gunsim"

/area/sim/tdome
	name = "Thunderdome"
	icon_state = "medbay"
	sound_environment = 9

/area/sim/tdome/tdome1
	name = "Thunderdome (Team 1)"
	icon_state = "green"
	sound_environment = 9

/area/sim/tdome/tdome2
	name = "Thunderdome (Team 2)"
	icon_state = "yellow"
	sound_environment = 9

/area/sim/tdome/tdomea
	name = "Thunderdome (Admin.)"
	icon_state = "purple"
	sound_environment = 9

/area/sim/tdome/tdomes
	name = "Thunderdome (Spectator)"
	icon_state = "purple"
	sound_environment = 9

///////////////////// zewaka-station areas

/area/station
	do_not_irradiate = 0
	sound_fx_1 = 'sound/ambience/station/Station_VocalNoise1.ogg'
	var/initial_structure_value = 0
#ifdef MOVING_SUB_MAP
	filler_turf = "/turf/space/fluid/manta"

	New()
		..()
		initial_structure_value = calculate_structure_value()
#else
	filler_turf = null

	New()
		..()
		initial_structure_value = calculate_structure_value()
#endif

/area/station/atmos
	name = "Atmospherics"
	icon_state = "atmos"
	sound_environment = 10
	workplace = 1
	do_not_irradiate = 1

/area/station/atmos/hookups
	sound_environment = 3

/area/station/atmos/hookups/east
	name = "East Air Hookups"

/area/station/atmos/hookups/west
	name = "West Air Hookups"

/area/station/atmos/hookups/north
	name = "North Air Hookups"

/area/station/atmos/hookups/south
	name = "South Air Hookups"

area/station/communications
	name = "Communications Office"
	icon_state = "communicationsoffice"
	sound_environment = 4

	communicationsbedroom
		name = "Communications Office Bedroom"
		icon_state = "communicationsoffice-bedroom"

/area/station/maintenance/
	name = "Maintenance"
	icon_state = "maintcentral"
	sound_environment = 12
	workplace = 1
	do_not_irradiate = 1

/area/station/maintenance/NWmaint
	name = "North West Maintenance"
	icon_state = "NWmaint"

/area/station/maintenance/NEmaint
	name = "North East Maintenance"
	icon_state = "NEmaint"

/area/station/maintenance/SEmaint
	name = "South East Maintenance"
	icon_state = "SEmaint"

/area/station/maintenance/SWmaint
	name = "South West Maintenance"
	icon_state = "SWmaint"

/area/station/maintenance/maintcentral
	name = "Central Maintenance"
	icon_state = "maintcentral"

/area/station/maintenance/north
	name = "North Maintenance"
	icon_state = "Nmaint"

/area/station/maintenance/east
	name = "East Maintenance"
	icon_state = "Emaint"

/area/station/maintenance/west
	name = "West Maintenance"
	icon_state = "Wmaint"

/area/station/maintenance/south
	name = "South Maintenance"
	icon_state = "Smaint"

/area/station/maintenance/eastsolar
	name = "East Solar Maintenance"
	icon_state = "SolarcontrolE"

/area/station/maintenance/westsolar
	name = "West Solar Maintenance"
	icon_state = "SolarcontrolW"

/area/station/maintenance/southsolar
	name = "South Solar Maintenance"
	icon_state = "SolarcontrolS"

/area/station/maintenance/northsolar
	name = "North Solar Maintenance"
	icon_state = "SolarcontrolN"

/area/station/maintenance/inner
	name = "Inner Maintenance"
	icon_state = "imaint"

/area/station/maintenance/storage
	name = "Atmospherics"
	icon_state = "green"

/area/station/maintenance/disposal
	name = "Waste Disposal"
	icon_state = "disposal"

/area/station/maintenance/lowerstarboard
	name = "Lower Starboard Maintenance"
	icon_state = "lower_starboard_maintenance"

/area/station/maintenance/lowerport
	name = "Lower Port Maintenance"
	icon_state = "lower_port_maintenance"

/area/station/maintenance/upperport
	name = "Upper Port Maintenance"
	icon_state = "upper_port_maintenance"

/area/station/maintenance/upperstarboard
	name = "Upper Starboard Maintenance"
	icon_state = "upper_starboard_maintenance"

/area/station/maintenance/seaturtle
	name = "Sea Turtle Maintenance"
	icon_state = "orange"

	boiler
		name = "Boiler room"
		icon_state = "orange"

/area/station/hallway/
	name = "Hallway"
	icon_state = "hallC"
	sound_environment = 10

/area/station/hallway/primary/north
	name = "North Primary Hallway"
	icon_state = "hallN"

/area/station/hallway/primary/east
	name = "East Primary Hallway"
	icon_state = "hallE"

/area/station/hallway/primary/south
	name = "South Primary Hallway"
	icon_state = "hallS"

/area/station/hallway/primary/west
	name = "West Primary Hallway"
	icon_state = "hallW"

/area/station/hallway/primary/central
	name = "Central Primary Hallway"
	icon_state = "hallC"

/area/station/hallway/secondary/exit
	name = "Escape Shuttle Hallway"
	icon_state = "escape"

/area/station/hallway/secondary/north
	name = "North Secondary Hallway"
	icon_state = "hallN2"

/area/station/hallway/secondary/east
	name = "East Secondary Hallway"
	icon_state = "hallE2"

/area/station/hallway/secondary/south
	name = "South Secondary Hallway"
	icon_state = "hallS2"

/area/station/hallway/secondary/west
	name = "West Secondary Hallway"
	icon_state = "hallW2"

/area/station/hallway/secondary/central
	name = "Central Secondary Hallway"
	icon_state = "hallC2"

area/station/hallway/starboardlowerhallway
	name = "Starboard Lower Hallway"
	icon_state ="starboard_lower_hallway"

area/station/hallway/seaturtlehallway
	name = "Sea Turtle Hallway"
	icon_state ="green"

area/station/hallway/portlowerhallway
	name = "Port Lower Hallway"
	icon_state ="port_lower_hallway"

area/station/hallway/centralhallway
	name = "Central Hallway"
	icon_state ="central_hallway"

area/station/hallway/portupperhallway
	name = "Port Upper Hallway"
	icon_state ="port_upper_hallway"
	requires_power = 1

area/station/hallway/starboardupperhallway
	name = "Starboard Upper Hallway"
	icon_state ="starboard_upper_hallway"
	requires_power = 1

/area/station/hallway/secondary/construction
	name = "Construction Area"
	icon_state = "construction"
	workplace = 1
	do_not_irradiate = 1

/area/station/hallway/secondary/construction2
	name = "Secondary Construction Area"
	icon_state = "construction"
	workplace = 1
	do_not_irradiate = 1

/area/station/hallway/secondary/entry
	name = "Main Hallway"
	icon_state = "entry"

/area/station/hallway/secondary/shuttle
	name = "Shuttle Bay"
	icon_state = "shuttle3"

/area/station/mailroom
	name = "Mailroom"
	icon_state = "mail"
	sound_environment = 2
	workplace = 1

/area/station/construction
	name = "Construction"
	icon_state = "red"
	sound_environment = 10

	under_construction
		name = "Under Construction"


/area/station/mining
	name = "Mining"
	icon_state = "mining"
	sound_environment = 10

/area/station/mining/refinery
	name = "Mining Refinery"
	icon_state = "miningg"

/area/station/mining/magnet
	name = "Mining Magnet Control Room"
	icon_state = "miningp"

/area/station/bridge
	name = "Bridge"
	icon_state = "bridge"
	sound_environment = 4
#ifdef SUBMARINE_MAP
	sound_group = "bridge"
	sound_loop = 'sound/ambience/station/underwater/sub_bridge_ambi1.ogg'
#endif

area/station/seaturtlebridge
	name = "Sea Turtle Bridge"
	icon_state = "bridge"

/area/station/captain //Three below this one are because Manta uses specific ambience on the bridge
	name = "Captain's Office"
	icon_state = "CAPN"

/area/station/hos
	name = "Head of Personnel's Office"
	icon_state = "HOP"

/area/station/hos/quarter
	name = "Head of Personnel's Personal Quarter"
	icon_state = "HOP"

/area/station/bridge/captain
	name = "Captain's Office"
	icon_state = "CAPN"

/area/station/bridge/hos
	name = "Head of Personnel's Office"
	icon_state = "HOP"

/area/station/bridge/customs
	name = "Customs"
	icon_state = "yellow"

/area/station/crew_quarters/quarters_north
	name = "North Crew Quarters"
	icon_state = "crewquarters"
	sound_environment = 3

/area/station/crew_quarters/quarters_west
	name = "West Crew Quarters"
	icon_state = "crewquarters"
	sound_environment = 3

/area/station/crew_quarters/quarters_east
	name = "East Crew Quarters"
	icon_state = "crewquarters"
	sound_environment = 3

/area/station/crew_quarters/quarters_south
	name = "South Crew Quarters"
	icon_state = "crewquarters"
	sound_environment = 3

/area/station/crew_quarters/hos
	name = "Head of Security's Quarters"
	icon_state = "HOS"
	sound_environment = 4

/area/station/crew_quarters/md
	name = "Medical Director's Quarters"
	icon_state = "MD"
	sound_environment = 4

/area/station/crew_quarters/ce
	name = "Chief Engineer's Quarters"
	icon_state = "CE"
	sound_environment = 4

/area/station/crew_quarters/sauna
	name = "Sauna"
	icon_state = "crewquarters"
	sound_environment = 2
	requires_power = 1

/area/station/crew_quarters/utility
	name = "Utility Room"
	icon_state = "orange"
	sound_environment = 2

/area/station/crew_quarters/lounge
	name = "Crew Lounge"
	icon_state = "crew_lounge"
	sound_environment = 2

/area/station/crew_quarters/lounge_port
	name = "West Crew Lounge"
	icon_state = "crew_lounge"
	sound_environment = 2

/area/station/crew_quarters/lounge_starboard
	name = "East Crew Lounge"
	icon_state = "crew_lounge"
	sound_environment = 2

/area/station/crew_quarters/locker
	name = "Locker Room"
	icon_state = "locker"
	sound_environment = 3

/area/station/crew_quarters/stockex
	name = "Stock Exchange"
	icon_state = "yellow"
	sound_environment = 0

/area/station/crew_quarters/radio
	name = "Radio Lab"
	icon_state = "green"
	sound_environment = 2

/area/station/crew_quarters/radio/bathroom
	name = "Radio Lab Bathroom"

/area/station/crew_quarters/arcade
	name = "Arcade"
	icon_state = "yellow"
	sound_environment = 4

/area/station/crew_quarters/arcade/dungeon
	name = "Nerd Dungeon"
	icon_state = "purple"
	sound_environment = 5

/area/station/crew_quarters/data
	name = "Data Center"
	icon_state = "purple"
	sound_environment = 5

/area/station/crew_quarters/fitness
	name = "Fitness Room"
	icon_state = "fitness"
	sound_environment = 2

/area/station/crew_quarters/captain
	name = "Captain's Quarters"
	icon_state = "captain"
	sound_environment = 4

/area/station/crew_quarters/hop
	name = "Head of Personnel's Quarters"
	icon_state = "green"
	sound_environment = 4

/area/station/crew_quarters/cafeteria
	name = "Cafeteria"
	icon_state = "cafeteria"
	sound_environment = 0

	the_rising_tide_bar
		name = "The Rising Tide"


/area/station/crew_quarters/kitchen
	name = "Kitchen"
	icon_state = "kitchen"
	sound_environment = 3

	freezer
		name = "Freezer"
		icon_state = "blue"

	therustykrab
		name = "The Rusty Krab"
		icon_state = "kitchen"

/area/station/crew_quarters/clown
	name = "Clown Hole"
	icon_state = "storage"
	do_not_irradiate = 1

/area/station/crew_quarters/catering
	name = "Catering Storage"
	icon_state = "storage"
	do_not_irradiate = 1

/area/station/crew_quarters/bathroom
	name = "Bathroom"
	icon_state = "showers"

/area/station/security/beepsky
	name = "Beepsky's House"
	icon_state = "storage"
	do_not_irradiate = 1

/area/station/crew_quarters/jazz
	name = "Jazz Lounge"
	icon_state = "purple"

/area/station/crew_quarters/info
	name = "Information Office"
	icon_state = "purple"

/area/station/crew_quarters/bar
	name= "Bar"
	icon_state = "bar"
	sound_environment = 4

/area/station/crew_quarters/baroffice
	name= "Bar Office"
	icon_state = "bar_office"
	sound_environment = 2

/area/station/crew_quarters/heads
	name = "Head of Personnel's Office"
	icon_state = "HOP"
	sound_environment = 4

/area/station/crew_quarters/hor
	name = "Research Director's Office"
	icon_state = "RD"
	sound_environment = 4
	requires_power = 1

	horprivate
	name = "Research Director's Private Quarters"
	icon_state = "RD"
	sound_environment = 4

/area/station/crew_quarters/quarters
	name = "Crew Lounge"
	icon_state = "purple"
	sound_environment = 2

/area/station/crew_quarters/quartersA
	name = "Crew Quarters A"
	icon_state = "crewquarters"
	sound_environment = 3

/area/station/crew_quarters/quartersB
	name = "Crew Quarters B"
	icon_state = "crewquarters"
	sound_environment = 3

/area/station/crew_quarters/quartersC
	name = "Crew Quarters C"
	icon_state = "crewquarters"
	sound_environment = 3

/area/station/crew_quarters/toilets
	name = "Toilets"
	icon_state = "toilets"
	sound_environment = 3

/area/station/crew_quarters/showers
	name = "Shower Room"
	icon_state = "showers"
	sound_environment = 3

/area/station/crew_quarters/pool
	name = "Pool Room"
	icon_state = "showers"
	sound_environment = 3

/area/station/crew_quarters/observatory
	name = "Observatory"
	icon_state = "observatory"
	sound_environment = 2

/area/station/crew_quarters/courtroom
	name = "Courtroom"
	icon_state = "courtroom"
	sound_environment = 0

/area/station/crew_quarters/juryroom
	name = "Jury Room"
	icon_state = "juryroom"
	sound_environment = 0

/area/station/crew_quarters/barber_shop
	name = "Barber Shop"
	icon_state= "yellow"
	sound_environment = 2

/area/station/crew_quarters/market
	name = "Public Market"
	icon_state = "yellow"
	sound_environment = 0

/area/station/crew_quarters/garden
	name = "Public Garden"
	icon_state = "park"

area/station/crewquarters/garbagegarbs //It's the clothing store on Manta
	name = "Garbage Garbs clothing store"
	icon_state = "green"

area/station/crewquarters/cryotron
	name ="Cryogenic Crew Storage"
	icon_state = "blue"

/area/station/com_dish/comdish
	name = "Communications Dish"
	icon_state = "yellow"
	force_fullbright = 1 // ????

/area/station/com_dish/auxdish
	name = "Auxilary Communications Dish"
	icon_state = "yellow"
	force_fullbright = 1

/area/station/com_dish/research_outpost
	name = "Research Outpost Communications Dish"
	icon_state = "yellow"
	force_fullbright = 1

/area/station/engine
	sound_environment = 5
	workplace = 1

/area/station/engine/engineering
	name = "Engineering"
	icon_state = "engineering"

/area/station/engine/ptl
	name = "Power Transmission Laser"
	icon_state = "ptl"

/area/station/engine/engineering/ce
	name = "Chief Engineer's Office"
	icon_state = "CE"

/area/station/engine/engineering/ce/private
	name = "Chief Engineer's Private Quarters"
	icon_state = "CE"

/area/station/engine/engineering/restroom
	name = "Engineering Restroom"
	icon_state = "toilets"

/area/station/engine/engineering/breakroom
	name = "Engineering Break Room"
	icon_state ="showers"

/area/station/engine/engineering/private
	name = "Engineering Quarters"
	icon_state = "yellow"

/area/mining/miningoutpost
	name = "Mining Outpost"
	icon_state = "engine"

/area/station/engine/storage
	name = "Engineering Storage"
	icon_state = "engine_hallway"

/area/station/engine/shield_gen
	name = "Engineering Shield Generator"
	icon_state = "engine_monitoring"

/area/station/engine/shields
	name = "Engineering Shields"
	icon_state = "engine_monitoring"

/area/station/engine/elect
	name = "Mechanic's Lab"
	icon_state = "mechanics"

/area/station/engine/power
	name = "Engineering Power Room"
	icon_state = "showers"
	sound_environment = 5

/area/station/engine/monitoring
	name = "Engineering Control Room"
	icon_state = "green"


/area/station/engine/singcore
	name = "Singularity Core"
	icon_state = "red"

/area/station/engine/eva
	name = "Engineering EVA"
	icon_state = "showers"

/area/station/engine/core
	name = "Thermo-Electric Generator"
	icon_state = "teg" // sometimes you just gotta make an icon the way it is because that's what your heart tells you to do, even if it looks like something a cartoon for toddlers would reject for looking too stupid
	sound_environment = 10

/area/station/engine/hotloop
	name = "Hot Loop"
	icon_state = "red"

/area/station/engine/combustion_chamber
	name = "Combustion Chamber"
	icon_state = "combustion_chamber"

/area/station/engine/coldloop
	name = "Cold Loop"
	icon_state = "purple"

/area/station/engine/gas
	name = "Engineering Gas Storage"
	icon_state = "storage"
	sound_environment = 3

/area/station/engine/inner
	name = "Inner Engineering"
	icon_state = "yellow"

/area/station/engine/substation
	icon_state = "purple"
	sound_environment = 3

/area/station/engine/substation/pylon
	name = "Electrical Substation"
	do_not_irradiate = 1

/area/station/engine/substation/west
	name = "West Electrical Substation"
	do_not_irradiate = 1

/area/station/engine/substation/east
	name = "East Electrical Substation"
	do_not_irradiate = 1

/area/station/engine/substation/north
	name = "North Electrical Substation"
	do_not_irradiate = 1

/area/station/engine/proto
	name = "Prototype Engine"
	icon_state = "prototype_engine"

/area/station/engine/thermo
	name = "Thermoelectric generator"
	icon_state = "prototype_engine"

/area/station/engine/proto_gangway
	name = "Prototype Gangway"
	icon_state = "green"
	luminosity = 1
	force_fullbright = 1
	requires_power = 0

/area/station/hangar
	name = "Hangar"
	icon_state = "purple"
	sound_environment = 10

/area/station/teleporter
	name = "Teleporter"
	icon_state = "teleporter"
	sound_environment = 3
	workplace = 1

/area/syndicate_teleporter
	name = "Syndicate Teleporter"
	icon_state = "teleporter"
	requires_power = 0
	teleport_blocked = 1
	do_not_irradiate = 1

/area/station/medical
	name = "Medical area"
	icon_state = "medbay"
	workplace = 1

/area/station/medical/medbay
	name = "Medbay"
	icon_state = "medbay"
	sound_environment = 3

/area/station/medical/medbay/lobby
	name = "Medbay Lobby"
	icon_state = "medbay_lobby"

/area/station/medical/medbay/cloner
	name = "Cloning"
	icon_state = "cloner"

/area/station/medical/medbay/pharmacy
	name = "Pharmacy"
	icon_state = "chem"

/area/station/medical/medbay/treatment1
	name = "Treatment Room 1"
	icon_state = "treat1"

/area/station/medical/medbay/treatment2
	name = "Treatment Room 2"
	icon_state = "treat2"

/area/station/medical/medbay/restroom
	name = "Medbay Restroom"
	icon_state = "blue"

/area/station/medical/medbay/surgery
	name = "Medbay Operating Theater"
	icon_state = "medbay_surgery"

/area/station/medical/medbay/surgery/storage
	name = "Medical Storage"
	icon_state = "blue"

/area/station/medical/robotics
	name = "Robotics"
	icon_state = "medresearch"

/area/station/medical/research
	name = "Medical Research"
	icon_state = "medresearch"
	sound_environment = 3

/area/station/medical/head
	name = "Medical Director's Office"
	icon_state = "MD"
	sound_environment = 1

	private
		name = "Medical Director's  Private Quarters"

/area/station/medical/cdc
	name = "Pathology Research"
	icon_state = "medcdc"
	sound_environment = 5

/area/station/medical/dome
	name = "Monkey Dome"
	icon_state = "green"
	sound_environment = 3

/area/station/medical/morgue
	name = "Morgue"
	icon_state = "morgue"
	sound_environment = 3

/area/station/medical/crematorium
	name = "Crematorium"
	icon_state = "morgue"
	sound_environment = 3

/area/station/medical/medbooth
	name = "Medical Booth"
	icon_state = "medbooth"
	sound_environment = 3

/area/station/medical/breakroom
	name = "Medbay Break Room"
	icon_state = "medbay_break"
	sound_environment = 3

/area/station/medical/maintenance
	name = "Medical Maintenance"
	icon_state = "medical_maintenance"
	sound_environment = 3
	do_not_irradiate = 1

/area/station/medical/staff
	name = "Medbay Staff Area"
	icon_state = "medbay_staff"
	sound_environment = 3

/area/station/security
	teleport_blocked = 1
	workplace = 1

/area/station/security/main
	name = "Security"
	icon_state = "security"
	sound_environment = 2

/area/station/security/interrogation
	name = "Interrogation Room"
	icon_state = "red"
	sound_environment = 2

/area/station/security/processing
	name = "Processing Room"
	icon_state = "red"
	sound_environment = 2

/area/station/security/brig
	name = "Brig"
	icon_state = "brigcell"
	sound_environment = 3
	teleport_blocked = 0

	cell_block_control
		name = "Cell Block Control"
		icon_state = "orange"

	cell_block
		name = "Cell Block"
		icon_state = "brigcell"
	cell1
		name = "Cell #1"
		icon_state = "red"
	genpop
		name = "Genpop Cell"
		icon_state = "brig"
	solitary
		name = "Solitary Confinement"
		icon_state = "brig"



/area/station/security/checkpoint
	name = "Bridge Security Checkpoint"
	icon_state = "checkpoint1"
	sound_environment = 2

	arrivals
		name = "Arrivals Security Checkpoint"
	escape
		name = "Escape Hallway Security Checkpoint"
	customs
		name = "Customs Security Checkpoint"
	sec_foyer
		name = "Security Foyer Checkpoint"
	podbay
		name = "Pod Bay Security Checkpoint"
	chapel
		name = "Chapel Security Checkpoint"
	cargo
		name = "Cargo Security Checkpoint"
	west
		name = "West Hallway Security Checkpoint"
	east
		name = "East Hallway Security Checkpoint"
	medical
		name = "Medical Security Checkpoint"

/area/station/security/armory //what the fuck this is not the real armory???
	name = "Armory" //ai_monitored/armory is, shitty ass code
	icon_state = "armory"
	sound_environment = 2

/area/station/security/prison
	name = "Prison Station"
	icon_state = "brig"
	sound_environment = 2

/area/station/security/secwing
	name = "Security Wing"
	icon_state = "brig"
	sound_environment = 2

/area/station/security/secoffquarters
	name = "Sec. Officers Quarters"
	icon_state = "brig"
	sound_environment = 2
	requires_power = 1

/area/station/security/starboardtorpedoes
	name = "Starboard Torpedo Bay"
	icon_state = "torpedoes_starboard"
	sound_environment = 2
	requires_power = 1

/area/station/security/porttorpedoes
	name = "Port Torpedo Bay"
	icon_state = "torpedoes_port"
	sound_environment = 2
	requires_power = 1

/area/station/security/detectives_office
	name = "Detective's Office"
	icon_state = "detective"
	sound_environment = 4
	workplace = 1

/area/station/security/detectives_office_manta
	name = "Detective's Office"
	icon_state = "detective"
	sound_environment = 15
	workplace = 1
	sound_loop = 'sound/ambience/station/detectivesoffice.ogg'
	sound_loop_vol = 30
	sound_group = "detective"

	detectives_bedroom
		name = "Detective's Bedroom"
		icon_state = "red"
		workplace = 0

/area/station/security/hos
	name = "Head of Security's Office"
	icon_state = "HOS"
	sound_environment = 4
	workplace = 0 //As does the hos

area/station/security/visitation
	name ="Visitation"
	icon_state = "red"
	sound_environment = 4

/area/station/solar
	requires_power = 0
	luminosity = 1
	force_fullbright = 1
	workplace = 1
	do_not_irradiate = 1

/area/station/solar/north
	name = "North Solar Array"
	icon_state = "yellow"
	icon_state = "panelsN"

/area/station/solar/south
	name = "South Solar Array"
	icon_state = "panelsS"

/area/station/solar/east
	name = "East Solar Array"
	icon_state = "panelsE"

/area/station/solar/west
	name = "West Solar Array"
	icon_state = "panelsW"

/area/station/solar/small_backup1
	name = "Emergency Solar Array 1"
	icon_state = "yellow"

/area/station/solar/small_backup2
	name = "Emergency Solar Array 2"
	icon_state = "yellow"

/area/station/solar/small_backup3
	name = "Emergency Solar Array 3"
	icon_state = "yellow"

/area/station/quartermaster
	name = "Quartermaster's"
	icon_state = "quart"
	workplace = 1

/area/station/quartermaster/office
	name = "Quartermaster's Office"
	icon_state = "quartoffice"
	sound_environment = 10

/area/station/quartermaster/storage
	name = "Quartermaster's Storage"
	icon_state = "quartstorage"
	sound_environment = 2
	do_not_irradiate = 1

/area/station/quartermaster/magnet
	name = "Magnet Control Room"
	icon_state = "green"
	sound_environment = 10

/area/station/quartermaster/refinery
	name = "Refinery"
	icon_state = "green"
	sound_environment = 10

/area/station/quartermaster/cargobay
	name = "Cargo Bay"
	icon_state = "quartstorage"
	sound_environment = 10

/area/station/quartermaster/cargooffice
	name = "Cargo Bay Office"
	icon_state = "quartoffice"
	sound_environment = 10

/area/station/janitor
	name = "Janitor's Office"
	icon_state = "janitor"
	sound_environment = 3
	workplace = 1

/area/station/janitor/supply
	name = "Janitor's Supply Closet"
	icon_state = "janitor"
	sound_environment = 3
	workplace = 1

/area/station/chemistry
	name = "Chemistry"
	icon_state = "chem"
	sound_environment = 3
	workplace = 1

/area/station/testchamber
	name = "Test Chamber"
	icon_state = "yellow"
	sound_environment = 5
	workplace = 1
	do_not_irradiate = 1

/area/station/science
	//name = "Research Outpost Zeta"
	name = "Research Sector"
	icon_state = "purple"
	sound_environment = 3
	workplace = 1

/area/station/science/gen_storage
	name = "Research Storage"
	icon_state = "genstorage"
	do_not_irradiate = 1

/area/station/science/restroom
	name = "Research Restroom"
	icon_state = "purple"

/area/station/science/bot_storage
	name = "Robot Depot"
	icon_state = "toxstorage"

/area/station/science/teleporter
	name = "Science Teleporter"
	icon_state = "telelab"

/area/station/science/research_director
	name = "Research Director's Office"
	icon_state = "toxlab"
	workplace = 0

/area/station/science/lab
	name = "Toxin Lab"
	icon_state = "toxlab"

/area/station/science/artifact
	name = "Artifact Lab"
	icon_state = "artifact"

/area/station/science/storage
	name = "Toxin Storage"
	icon_state = "toxstorage"
	do_not_irradiate = 1

/area/station/science/laser
	name = "Optics Lab"
	icon_state = "yellow"

/area/station/science/spectral
	name = "Spectral Studies Lab"
	icon_state = "purple"

/area/station/science/construction
	name = "Research Sector Construction Area"
	icon_state = "yellow"
	do_not_irradiate = 1

/area/station/test_area
	name = "Toxin Test Area"
	icon_state = "toxtest"
	virtual = 1
	sound_group = "toxtest"
	force_fullbright = 1

/area/station/chapel/main
	name = "Chapel"
	icon_state = "chapel"
	sound_environment = 7

/area/station/chapel/main/main //wtf why is this a thing

/area/station/chapel/office
	name = "Chapel Office"
	icon_state = "chapeloffice"
	sound_environment = 11

/area/station/storage
	name = "Storage Area"
	icon_state = "storage"
	workplace = 1

/area/station/storage/tools
	name = "Tool Storage"
	icon_state = "storage"
	sound_environment = 3

/area/station/storage/primary
	name = "Primary Tool Storage"
	icon_state = "primarystorage"
	sound_environment = 3

/area/station/storage/autolathe
	name = "Autolathe Storage"
	icon_state = "storage"

/area/station/storage/auxillary
	name = "Auxillary Storage"
	icon_state = "auxstorage"

/area/station/storage/eva
	name = "EVA Storage"
	icon_state = "eva"
	sound_environment = 3

/area/station/storage/eeva
	name = "Engineering EVA Storage"
	icon_state = "eva"

/area/station/storage/secure
	name = "Secure Storage"
	icon_state = "storage"

/area/station/storage/emergencyinternals
	name = "Emergency Internals"
	icon_state = "yellow"

/area/station/storage/emergency
	name = "Emergency Storage A"
	icon_state = "emergencystorage"

/area/station/storage/emergency2
	name = "Emergency Storage B"
	icon_state = "emergencystorage"

/area/station/storage/tech
	name = "Technical Storage"
	icon_state = "auxstorage"
	do_not_irradiate = 1

/area/station/storage/warehouse
	name = "Central Warehouse"
	icon_state = "red"
	sound_environment = 18

/area/station/storage/testroom
	requires_power = 0
	name = "Test Room"
	icon_state = "storage"
	teleport_blocked = 1

// cogmap new areas ///////////

/area/station/hangar
	name = "Hangar"
	icon_state = "hangar"
	workplace = 1
	do_not_irradiate = 1

	main
		name = "Pod Bay"
		sound_environment = 10
	catering
		name = "Catering Dock"
	arrivals
		name = "Arrivals Dock"
	sec
		name = "Secure Dock"
		teleport_blocked = 1
	engine
		name = "Engineering Dock"
	qm
		name = "Cargo Dock"
	escape
		name = "Escape Dock"
	science
		name = "Research Dock"
		teleport_blocked = 1
	port
		name = "Submarine Bay (Port)"
		requires_power = 1
	starboard
		name = "Submarine Bay (Starboard)"
	mining
		name = "Submarine Bay (Mining)"
	security
		name = "Submarine Bay (Security)"

/area/station/hydroponics
	name = "Hydroponics"
	icon_state = "hydro"
	workplace = 1

/area/station/hydroponics/lobby
	name = "Hydroponics Lobby"
	icon_state = "green"

/area/station/owlery
	name = "Owlery"
	icon_state = "yellow"
	sound_environment = 15
	do_not_irradiate = 1

/area/station/aviary
	name = "Aviary"
	icon_state = "aviary"
	sound_environment = 15
	do_not_irradiate = 1

/area/station/habitat
	name = "Habitat Dome"
	icon_state = "aviary"
	sound_environment = 15
	do_not_irradiate = 1
	force_fullbright = 1

/area/station/zen
	name = "Zen Garden"
	icon_state = "aviary"
	sound_environment = 15
	do_not_irradiate = 1

/area/station/catwalk
	icon_state = "yellow"
	force_fullbright = 1

/area/station/catwalk/north
	name = "North Maintenance Catwalk"

/area/station/catwalk/south
	name = "South Maintenance Catwalk"

/area/station/catwalk/west
	name = "West Maintenance Catwalk"

/area/station/catwalk/east
	name = "East Maintenance Catwalk"

/area/station/routingdepot
	name = "Routing Depot"
	icon_state = "depot"
	sound_environment = 13
	do_not_irradiate = 1

	catering
		name = "Cafeteria Router"

	eva
		name = "EVA Router"

	engine
		name = "Engine Router"

	medsci
		name = "Med-Sci Router"

	security
		name = "Security Router"

	airbridge
		name = "Airbridge Router"

/area/research_outpost
	name = "Research Outpost"
	icon_state = "blue"
	do_not_irradiate = 1

	hangar
		name = "Research Outpost Hangar"
		icon_state = "hangar"

	chamber
		name = "Research Outpost Test Chamber"
		icon_state = "yellow"

	maint
		name = "Research Outpost Maintenance"
		icon_state = "purple"
		do_not_irradiate = 1

	toxins
		name = "Research Outpost Toxins"
		icon_state = "green"

///////////////////////////////

/area/listeningpost
	name = "Listening Post"
	icon_state = "brig"
	teleport_blocked = 1
	do_not_irradiate = 1

	syndicateassaultvessel
		name ="Syndicate Assault Vessel"


/area/listeningpost/power
	name = "Listening Post Control Room"
	icon_state = "engineering"

/area/listeningpost/solars
	name = "Listening Post Solar Array"
	icon_state = "yellow"
	requires_power = 0
	luminosity = 1
	force_fullbright = 1

///////////////////////////////

/area/syndicate_station
	name = "Syndicate Station"
	icon_state = "yellow"
	requires_power = 0
	sound_environment = 2
	teleport_blocked = 1
	sound_group = "syndicate_station"

	battlecruiser
		name = "Syndicate Battlecruiser Cairngorm"
		icon_state = "red"
		sanctuary = 1

	firing_range
		name = "firing range"
		icon_state = "blue"

///////////////////////////////

/area/wizard_station
	name = "Wizard's Den"
	icon_state = "yellow"
	requires_power = 0
	sound_environment = 4
	teleport_blocked = 1

	CanEnter( var/atom/movable/A )
		var/mob/living/M = A
		if( istype(M) && M.mind && M.mind.special_role != "wizard" && isliving(M) )
			if(M.client && M.client.holder)
				return 1
			boutput( M, "<span class='alert'>A magical barrier prevents you from entering!</span>" )//or something
			return 0
		return 1

	//sanctuary = 1

///////////////////////////////

/area/station/ai_monitored
	name = "AI Monitored Area"
	var/obj/machinery/camera/motion/motioncamera = null
	workplace = 1

/area/station/ai_monitored/New()
	..()
	// locate and store the motioncamera
	SPAWN_DBG (20) // spawn on a delay to let turfs/objs load
		for (var/obj/machinery/camera/motion/M in src)
			motioncamera = M
			return
	return

/area/station/ai_monitored/Entered(atom/movable/O)
	..()
	if (ismob(O) && motioncamera)
		motioncamera.newTarget(O)
//
/area/station/ai_monitored/Exited(atom/movable/O)
	..()
	if (ismob(O) && motioncamera)
		motioncamera.lostTarget(O)

/area/station/ai_monitored/storage/eva
	name = "EVA Storage"
	icon_state = "eva"
	sound_environment = 12

/area/station/ai_monitored/storage/secure
	name = "Secure Storage"
	icon_state = "storage"
	sound_environment = 12

/area/station/ai_monitored/storage/emergency
	name = "Emergency Storage"
	icon_state = "storage"
	sound_environment = 12

/area/station/ai_monitored/armory
	name = "Armory"
	icon_state = "armory"
	sound_environment = 2
	teleport_blocked = 1

///////////////////////////////

/area/station/turret_protected
	name = "Turret Protected Area"
	var/list/obj/machinery/turret/turret_list = list()
	var/obj/machinery/camera/motion/motioncamera = null
	var/list/obj/blob/blob_list = list() //faster to cache blobs as they enter instead of searching the area for them (For turrets)

/area/station/turret_protected/New()
	..()
	// locate and store the motioncamera
	SPAWN_DBG (20) // spawn on a delay to let turfs/objs load
		for (var/obj/machinery/camera/motion/M in src)
			motioncamera = M
			return
	return

/area/station/turret_protected/Entered(O)
	..()
	if (isliving(O))
		if(!issilicon(O))
			if (motioncamera)
				motioncamera.newTarget(O)
			popUpTurrets()
	if (istype(O,/obj/blob))
		blob_list += O
	return 1

/area/station/turret_protected/Exited(O)
	..()
	if (isliving(O))
		if (!issilicon(O))
			if(motioncamera)
				motioncamera.lostTarget(O)
			//popDownTurrets()
	if (istype(O,/obj/blob))
		blob_list -= O
	return 1

/area/station/turret_protected/proc/popDownTurrets()
	for (var/obj/machinery/turret/aTurret in src.turret_list)
		aTurret.popDown()

/area/station/turret_protected/proc/popUpTurrets()
	for (var/obj/machinery/turret/aTurret in src.turret_list)
		aTurret.popUp()


/area/station/turret_protected/ai_upload
	name = "AI Upload Chamber"
	icon_state = "ai_upload"
	sound_environment = 12
	do_not_irradiate = 1

/area/station/turret_protected/ai_upload_foyer
	name = "AI Upload Foyer"
	icon_state = "ai_foyer"
	sound_environment = 12

/area/station/turret_protected/ai
	name = "AI Chamber"
	icon_state = "ai_chamber"
	sound_environment = 12
	do_not_irradiate = 1

/area/station/turret_protected/AIbasecore1
	name = "AI Core 1"
	icon_state = "AIt"
	sound_environment = 12

/area/station/turret_protected/AIbaseoutside
	name = "AI Perimeter Defenses"
	icon_state = "AIt"
	requires_power = 0
	sound_environment = 12

/area/station/turret_protected/AIbasecore2
	name = "AI Core 2"
	icon_state = "AIt"
	sound_environment = 12

/area/station/turret_protected/Zeta
	name = "Computer Core"
	icon_state = "AIt"
	sound_environment = 12

/area/station/turret_protected/port
	name = "AI Upload Foyer Port"
	sound_environment = 12
	icon_state = "ai_foyer"

/area/station/turret_protected/starboard
	name = "AI Upload Foyer Starboard"
	sound_environment = 12
	icon_state = "ai_foyer"




/////////////////////////////// OLD AREAS THAT ARE NOT USED BUT ARE IN HERE

///////////////////// zewaka-old mining outpost

/area/mining
	name = "Mining Outpost"
	icon_state = "engine"
	workplace = 1

/area/mining/power
	name = "Outpost Power Room"
	icon_state = "showers"
	sound_environment = 3

/area/mining/manufacturing
	name = "Outpost Manufacturing Room"
	icon_state = "storage"
	sound_environment = 12

/area/mining/quarters
	name = "Outpost Miner's Quarters"
	icon_state = "locker"
	sound_environment = 2

/area/mining/comms
	name = "Outpost Comms Room"
	icon_state = "yellow"
	sound_environment = 2

/area/mining/dock
	name = "Outpost Shuttle Dock"
	icon_state = "storage"
	sound_environment = 10

/area/mining/exit_west
	name = "Outpost West Airlock"
	icon_state = "maintcentral"
	sound_environment = 12

/area/mining/exit_east
	name = "Outpost East Airlock"
	icon_state = "maintcentral"
	sound_environment = 12

/area/mining/exit_south
	name = "Outpost South Airlock"
	icon_state = "maintcentral"
	sound_environment = 12

/area/mining/magnet_control
	name = "Mining Outpost Magnet Control"
	icon_state = "miningp"

/area/mining/refinery
	name = "Mining Outpost Refinery"
	icon_state = "yellow"

/area/mining/hangar/
	name = "Mining Dock"
	icon_state = "storage"
	sound_environment = 10
	workplace = 1

/area/mining/mainasteroid
	name = "Main Asteroid"
	icon_state = "green"
	force_fullbright = 1

/area/station/tunnelsnake
	name = "Tunnel Snake Mining Rig"
	icon_state = "red"
	sound_environment = 3
	workplace = 1

/area/station/tunnelsnake/toilet
	name = "Toilet"
	icon_state = "blue"
	sound_environment = 3

/area/station/tunnelsnake/bridge
	name = "Tunnel Snake Bridge"
	icon_state = "yellow"
	sound_environment = 3

/area/station/tunnelsnake/room1
	name = "Private Quarters"
	icon_state = "green"
	sound_environment = 3

/area/station/tunnelsnake/room2
	name = "Private Quarters"
	icon_state = "green"
	sound_environment = 3

/area/station/tunnelsnake/room3
	name = "Private Quarters"
	icon_state = "green"
	sound_environment = 3

/area/station/tunnelsnake/room4
	name = "Private Quarters"
	icon_state = "green"
	sound_environment = 3

////////////////////////////////////

/area/russian
	name = "Kosmicheskoi Stantsii 13"
	icon_state = "green"
	sound_environment = 13

/area/russian/radiation
	name = "Kosmicheskoi Stantsii 13"
	icon_state = "yellow"
	permarads = 1

///////////////////////////////

/*
/area/derelict
	name = "Derelict Station"
	icon_state = "derelict"
	sound_environment = 21

/area/derelict/hallway/primary
	name = "Derelict Primary Hallway"
	icon_state = "hallP"

/area/derelict/hallway/secondary
	name = "Derelict Secondary Hallway"
	icon_state = "hallS"

/area/derelict/arrival
	name = "Arrival Centre"
	icon_state = "yellow"

/area/derelict/storage/equipment
	name = "Derelict Equipment Storage"

/area/derelict/storage/storage_access
	name = "Derelict Storage Access"

/area/derelict/storage/engine_storage
	name = "Derelict Engine Storage"
	icon_state = "green"

/area/derelict/bridge
	name = "Control Room"
	icon_state = "bridge"

/area/derelict/bridge/access
	name = "Control Room Access"
	icon_state = "auxstorage"

/area/derelict/bridge/ai_upload
	name = "Ruined Computer Core"
	icon_state = "ai"

/area/derelict/solar_control
	name = "Solar Control"
	icon_state = "engine"

/area/derelict/crew_quarters
	name = "Derelict Crew Quarters"
	icon_state = "fitness"

/area/derelict/medical
	name = "Derelict Medbay"
	icon_state = "medbay"

/area/derelict/medical/morgue
	name = "Derelict Morgue"
	icon_state = "morgue"

/area/derelict/medical/chapel
	name = "Derelict Chapel"
	icon_state = "chapel"

/area/derelict/teleporter
	name = "Derelict Teleporter"
	icon_state = "teleporter"

/area/derelict/eva
	name = "Derelict EVA Storage"
	icon_state = "eva"

/area/derelict/smuggler

/area/derelict/smuggler/power
	name = "Power center"
	icon_state = "engine"

/area/derelict/smuggler/cargo
	name = "Cargo sorting"
	icon_state = "storage"

/area/derelict/smuggler/control
	name = "Control room"
	icon_state = "bridge"*/

/////////////////////////zewaka - old prison area

/*
/area/prison/arrival_airlock
	name = "Asylum Station Airlock"
	icon_state = "green"
	requires_power = 0

/area/prison/control
	name = "Warden's Office"
	icon_state = "security"

/area/prison/crew_quarters
	name = "Asylum Staff Quarters"
	icon_state = "security"

/area/prison/closet
	name = "Prison Supply Closet"
	icon_state = "dk_yellow"

/area/prison/hallway/north
	name = "Asylum North Hallway"
	icon_state = "yellow"

/area/prison/hallway/south
	name = "Prison South Hallway"
	icon_state = "yellow"

/area/prison/hallway/west
	name = "Prison West Hallway"
	icon_state = "yellow"

/area/prison/hallway/east
	name = "Prison East Hallway"
	icon_state = "yellow"

/area/prison/morgue
	name = "Asylum Morgue"
	icon_state = "morgue"

/area/prison/medical_research
	name = "Prison Genetic Research"
	icon_state = "medresearch"

/area/prison/office
	name = "Asylum Offices"
	icon_state = "purple"

/area/prison/office/checkpoint
	name = "Nurse's Station"

/area/prison/medical
	name = "Asylum Operating Theatre"
	icon_state = "medbay"

/area/prison/solar
	name = "Prison Solar Array"
	icon_state = "storage"
	requires_power = 0

/area/prison/podbay
	name = "Prison Podbay"
	icon_state = "dk_yellow"

/area/prison/solar_control
	name = "Prison Solar Array Control"
	icon_state = "dk_yellow"

/area/prison/solitary
	name = "Solitary Confinement"
	icon_state = "brig"*/

/area/prison/cell_block/wards
	name = "Asylum Wards"
	icon_state = "brig"
	requires_power = 0/*

/area/prison/cell_block/A
	name = "Prison Cell Block A"
	icon_state = "brig"

/area/prison/cell_block/B
	name = "Prison Cell Block B"
	icon_state = "brig"

/area/prison/cell_block/C
	name = "Prison Cell Block C"
	icon_state = "brig"
*/

///////////////////////////////

/*/area/factory
	name = "Derelict Robot Factory"
	icon_state = "start"

/area/factory/core
	name = "Aged Computer Core"
	icon_state = "ai"

/area/old_outpost
	name = "Derelict Outpost"
	icon_state = "yellow"
	sound_environment = 12

/area/old_outpost/engine
	name = "Outpost Engine"
	icon_state = "dk_yellow"
	sound_environment = 10

/area/old_outpost/control
	name = "Outpost Control"
	icon_state = "purple"

/area/old_outpost/medical
	name = "VR Research"
	icon_state = "medresearch"
	sound_environment = 3

/area/old_outpost/study
	name = "Outpost Study"
	icon_state = "green"
	sound_environment = 4

/area/old_outpost/teleporter
	name = "Outpost Teleporter"
	icon_state = "teleporter"
	sound_environment = 2*/

/area/shamecube
	name = "Shame Cube"
	blocked = 1
	sanctuary = 1
	teleport_blocked = 1
	mouse_opacity = 1
	luminosity = 1
	force_fullbright = 1
	CanEnter(var/atom/movable/A)
		if(ismob(A) && A:client && A:client:player && A:client:player:shamecubed)
			return 1
		else
			return 0

/area/shamecube/unshamefulcube
	name = "Unshameful Cube"
	blocked = 0
	sanctuary = 0
	mouse_opacity = 0
	luminosity = 0
	force_fullbright = 0
	CanEnter()
		return 1

/area/built_zone
	name = "Built Zone"
	requires_power = 1
	power_equip = 0
	power_light = 0
	power_environ = 0
	proc/SetName(var/name)
		src.name = name
		for(var/obj/machinery/power/apc/apc in src)
			apc.name = "[name] APC"
			apc.area = src
	New()
		.=..()
		SetName(name)//because the jerk built an APC first, because WHY NOT JERKO?!


// end areas




/* ================================================== */

/area/New()
	src.icon = 'icons/effects/alert.dmi'
	src.layer = EFFECTS_LAYER_BASE
//Halloween is all about darkspace
	if(name == "Space" || src.name == "Ocean")			// override defaults for space
		requires_power = 0
		#ifdef UNDERWATER_MAP
		src.ambient_light = OCEAN_LIGHT
		#endif
#ifdef HALLOWEEN
		alpha = 128
		icon = 'icons/effects/dark.dmi'
#endif

	if(!requires_power)
		power_light = 1
		power_equip = 1
		power_environ = 1
	else
		luminosity = 0

	SPAWN_DBG(1.5 SECONDS)
		src.power_change()		// all machines set to current power level, also updates lighting icon


/area/proc/poweralert(var/state, var/source)
	if (state != poweralm)
		poweralm = state
		var/list/cameras = list()
		for (var/obj/machinery/camera/C in orange(source, 7))
			cameras += C
			LAGCHECK(LAG_HIGH)
		for (var/mob/living/silicon/aiPlayer in mobs)
			if (state == 1)
				aiPlayer.cancelAlarm("Power", src, source)
			else
				aiPlayer.triggerAlarm("Power", src, cameras, source)
	return


/area/proc/firealert()
	if(src.name == "Space" || src.name == "Ocean") //no fire alarms in space
		return
	if (!( src.fire ))
		src.fire = 1
		src.updateicon()
		src.mouse_opacity = 0
		var/list/cameras = list()
		for (var/obj/machinery/firealarm/F in src)
			F.icon_state = "fire1"
			LAGCHECK(LAG_HIGH)
		for (var/obj/machinery/camera/C in src)
			cameras += C
			LAGCHECK(LAG_HIGH)
		for (var/mob/living/silicon/ai/aiPlayer in AIs)
			aiPlayer.triggerAlarm("Fire", src, cameras, src)
			LAGCHECK(LAG_HIGH)
		for (var/obj/machinery/computer/atmosphere/alerts/a in machine_registry[MACHINES_ATMOSALERTS])
			a.triggerAlarm("Fire", src, cameras, src)
			LAGCHECK(LAG_HIGH)
	return

/area/proc/firereset()
	if (src.fire)
		src.fire = 0
		src.mouse_opacity = 0
		src.updateicon()

		for (var/obj/machinery/firealarm/F in src)
			F.icon_state = "fire0"
			LAGCHECK(LAG_HIGH)
		for (var/mob/living/silicon/ai/aiPlayer in AIs)
			aiPlayer.cancelAlarm("Fire", src, src)
			LAGCHECK(LAG_HIGH)
		for (var/obj/machinery/computer/atmosphere/alerts/a in machine_registry[MACHINES_ATMOSALERTS])
			a.cancelAlarm("Fire", src, src)
			LAGCHECK(LAG_HIGH)
	return

/area/proc/updateicon()
	if ((fire || eject) && power_environ)
		if(fire && !eject)
//			icon_state = "blue"
			icon_state = null
		else if(!fire && eject)
			icon_state = "red"
		else
			icon_state = "blue-red"
	else
	//	new lighting behaviour with obj lights
		icon_state = null

/area/proc/powered(var/chan)		// return true if the area has power to given channel

	if(!requires_power)
		return 1
	switch(chan)
		if(EQUIP)
			return power_equip
		if(LIGHT)
			return power_light
		if(ENVIRON)
			return power_environ
	return 0

// called when power status changes

/area/proc/power_change()
	for(var/X in src.machines)	// for each machine in the area
		var/obj/machinery/M = X
		M?.power_change()

	updateicon()

/area/proc/usage(var/chan)

	switch(chan)
		if(LIGHT)
			. = used_light
		if(EQUIP)
			. = used_equip
		if(ENVIRON)
			. = used_environ
		if(TOTAL)
			. = used_light + used_equip + used_environ

/area/proc/clear_usage()

	used_equip = 0
	used_light = 0
	used_environ = 0

/area/proc/use_power(var/amount, var/chan)

	switch(chan)
		if(EQUIP)
			used_equip += amount
		if(LIGHT)
			used_light += amount
		if(ENVIRON)
			used_environ += amount


/area/janitor_setpiece // adhara setpiece
	name = "Rental Office"
	icon_state = "purple"


/*
Occasionally you need to have doubles of every station area on a map.
This is useful for copy-pasting huge chunks of an existing DMM into another existing DMM where you don't wanna have APC conflicts.
Anyway if you ever choose to uncomment this, make sure it's temporary, and just do a search-and-replace for all "/station/" with "/station2/" in your DMM, in raw.
Don't try and do this in the editor nerd. ~Warc



/area/station2
	do_not_irradiate = 0
	sound_fx_1 = 'sound/ambience/station/Station_VocalNoise1.ogg'
	var/initial_structure_value = 0
#ifdef MOVING_SUB_MAP
	filler_turf = "/turf/space/fluid/manta"

	New()
		..()
		initial_structure_value = calculate_structure_value()
#else
	filler_turf = null

	New()
		..()
		initial_structure_value = calculate_structure_value()
#endif

/area/station2/atmos
	name = "Atmospherics"
	icon_state = "atmos"
	sound_environment = 10
	workplace = 1
	do_not_irradiate = 1

/area/station2/atmos/hookups
	sound_environment = 3

/area/station2/atmos/hookups/east
	name = "East Air Hookups"

/area/station2/atmos/hookups/west
	name = "West Air Hookups"

/area/station2/atmos/hookups/north
	name = "North Air Hookups"

/area/station2/atmos/hookups/south
	name = "South Air Hookups"

area/station/communications
	name = "Communications Office"
	icon_state = "communicationsoffice"
	sound_environment = 4

	communicationsbedroom
		name = "Communications Office Bedroom"
		icon_state = "communicationsoffice-bedroom"

/area/station2/maintenance/
	name = "Maintenance"
	icon_state = "maintcentral"
	sound_environment = 12
	workplace = 1
	do_not_irradiate = 1

/area/station2/maintenance/NWmaint
	name = "North West Maintenance"
	icon_state = "NWmaint"

/area/station2/maintenance/NEmaint
	name = "North East Maintenance"
	icon_state = "NEmaint"

/area/station2/maintenance/SEmaint
	name = "South East Maintenance"
	icon_state = "SEmaint"

/area/station2/maintenance/SWmaint
	name = "South West Maintenance"
	icon_state = "SWmaint"

/area/station2/maintenance/maintcentral
	name = "Central Maintenance"
	icon_state = "maintcentral"

/area/station2/maintenance/north
	name = "North Maintenance"
	icon_state = "Nmaint"

/area/station2/maintenance/east
	name = "East Maintenance"
	icon_state = "Emaint"

/area/station2/maintenance/west
	name = "West Maintenance"
	icon_state = "Wmaint"

/area/station2/maintenance/south
	name = "South Maintenance"
	icon_state = "Smaint"

/area/station2/maintenance/eastsolar
	name = "East Solar Maintenance"
	icon_state = "SolarcontrolE"

/area/station2/maintenance/westsolar
	name = "West Solar Maintenance"
	icon_state = "SolarcontrolW"

/area/station2/maintenance/southsolar
	name = "South Solar Maintenance"
	icon_state = "SolarcontrolS"

/area/station2/maintenance/northsolar
	name = "North Solar Maintenance"
	icon_state = "SolarcontrolN"

/area/station2/maintenance/inner
	name = "Inner Maintenance"
	icon_state = "imaint"

/area/station2/maintenance/storage
	name = "Atmospherics"
	icon_state = "green"

/area/station2/maintenance/disposal
	name = "Waste Disposal"
	icon_state = "disposal"

/area/station2/maintenance/lowerstarboard
	name = "Lower Starboard Maintenance"
	icon_state = "lower_starboard_maintenance"

/area/station2/maintenance/lowerport
	name = "Lower Port Maintenance"
	icon_state = "lower_port_maintenance"

/area/station2/maintenance/upperport
	name = "Upper Port Maintenance"
	icon_state = "upper_port_maintenance"

/area/station2/maintenance/upperstarboard
	name = "Upper Starboard Maintenance"
	icon_state = "upper_starboard_maintenance"

/area/station2/hallway/
	name = "Hallway"
	icon_state = "hallC"
	sound_environment = 10

/area/station2/hallway/primary/north
	name = "North Primary Hallway"
	icon_state = "hallN"

/area/station2/hallway/primary/east
	name = "East Primary Hallway"
	icon_state = "hallE"

/area/station2/hallway/primary/south
	name = "South Primary Hallway"
	icon_state = "hallS"

/area/station2/hallway/primary/west
	name = "West Primary Hallway"
	icon_state = "hallW"

/area/station2/hallway/primary/central
	name = "Central Primary Hallway"
	icon_state = "hallC"

/area/station2/hallway/secondary/exit
	name = "Escape Shuttle Hallway"
	icon_state = "escape"

/area/station2/hallway/secondary/north
	name = "North Secondary Hallway"
	icon_state = "hallN2"

/area/station2/hallway/secondary/east
	name = "East Secondary Hallway"
	icon_state = "hallE2"

/area/station2/hallway/secondary/south
	name = "South Secondary Hallway"
	icon_state = "hallS2"

/area/station2/hallway/secondary/west
	name = "West Secondary Hallway"
	icon_state = "hallW2"

/area/station2/hallway/secondary/central
	name = "Central Secondary Hallway"
	icon_state = "hallC2"

area/station/hallway/starboardlowerhallway
	name = "Starboard Lower Hallway"
	icon_state ="starboard_lower_hallway"

area/station/hallway/portlowerhallway
	name = "Port Lower Hallway"
	icon_state ="port_lower_hallway"

area/station/hallway/centralhallway
	name = "Central Hallway"
	icon_state ="central_hallway"

area/station/hallway/portupperhallway
	name = "Port Upper Hallway"
	icon_state ="port_upper_hallway"
	requires_power = 1

area/station/hallway/starboardupperhallway
	name = "Starboard Upper Hallway"
	icon_state ="starboard_upper_hallway"
	requires_power = 1

/area/station2/hallway/secondary/construction
	name = "Construction Area"
	icon_state = "construction"
	workplace = 1
	do_not_irradiate = 1

/area/station2/hallway/secondary/construction2
	name = "Secondary Construction Area"
	icon_state = "construction"
	workplace = 1
	do_not_irradiate = 1

/area/station2/hallway/secondary/entry
	name = "Main Hallway"
	icon_state = "entry"

/area/station2/hallway/secondary/shuttle
	name = "Shuttle Bay"
	icon_state = "shuttle3"

/area/station2/mailroom
	name = "Mailroom"
	icon_state = "mail"
	sound_environment = 2
	workplace = 1

/area/station2/mining
	name = "Mining"
	icon_state = "mining"
	sound_environment = 10

/area/station2/mining/refinery
	name = "Mining Refinery"
	icon_state = "miningg"

/area/station2/mining/magnet
	name = "Mining Magnet Control Room"
	icon_state = "miningp"

/area/station2/bridge
	name = "Bridge"
	icon_state = "bridge"
	sound_environment = 4
#ifdef SUBMARINE_MAP
	sound_group = "bridge"
	sound_loop = 'sound/ambience/station/underwater/sub_bridge_ambi1.ogg'
#endif

/area/station2/captain //Three below this one are because Manta uses specific ambience on the bridge
	name = "Captain's Office"
	icon_state = "CAPN"

/area/station2/hos
	name = "Head of Personnel's Office"
	icon_state = "HOP"

/area/station2/hos/quarter
	name = "Head of Personnel's Personal Quarter"
	icon_state = "HOP"

/area/station2/bridge/captain
	name = "Captain's Office"
	icon_state = "CAPN"

/area/station2/bridge/hos
	name = "Head of Personnel's Office"
	icon_state = "HOP"

/area/station2/bridge/customs
	name = "Customs"
	icon_state = "yellow"

/area/station2/crew_quarters/quarters_north
	name = "North Crew Quarters"
	icon_state = "crewquarters"
	sound_environment = 3

/area/station2/crew_quarters/quarters_west
	name = "West Crew Quarters"
	icon_state = "crewquarters"
	sound_environment = 3

/area/station2/crew_quarters/quarters_east
	name = "East Crew Quarters"
	icon_state = "crewquarters"
	sound_environment = 3

/area/station2/crew_quarters/quarters_south
	name = "South Crew Quarters"
	icon_state = "crewquarters"
	sound_environment = 3

/area/station2/crew_quarters/hos
	name = "Head of Security's Quarters"
	icon_state = "HOS"
	sound_environment = 4

/area/station2/crew_quarters/md
	name = "Medical Director's Quarters"
	icon_state = "MD"
	sound_environment = 4

/area/station2/crew_quarters/ce
	name = "Chief Engineer's Quarters"
	icon_state = "CE"
	sound_environment = 4

/area/station2/crew_quarters/sauna
	name = "Sauna"
	icon_state = "crewquarters"
	sound_environment = 2
	requires_power = 1

/area/station2/crew_quarters/utility
	name = "Utility Room"
	icon_state = "orange"
	sound_environment = 2

/area/station2/crew_quarters/lounge
	name = "Crew Lounge"
	icon_state = "crew_lounge"
	sound_environment = 2

/area/station2/crew_quarters/lounge_port
	name = "West Crew Lounge"
	icon_state = "crew_lounge"
	sound_environment = 2

/area/station2/crew_quarters/lounge_starboard
	name = "East Crew Lounge"
	icon_state = "crew_lounge"
	sound_environment = 2

/area/station2/crew_quarters/locker
	name = "Locker Room"
	icon_state = "locker"
	sound_environment = 3

/area/station2/crew_quarters/stockex
	name = "Stock Exchange"
	icon_state = "yellow"
	sound_environment = 0

/area/station2/crew_quarters/radio
	name = "Radio Lab"
	icon_state = "green"
	sound_environment = 2

/area/station2/crew_quarters/radio/bathroom
	name = "Radio Lab Bathroom"

/area/station2/crew_quarters/arcade
	name = "Arcade"
	icon_state = "yellow"
	sound_environment = 4

/area/station2/crew_quarters/arcade/dungeon
	name = "Nerd Dungeon"
	icon_state = "purple"
	sound_environment = 5

/area/station2/crew_quarters/data
	name = "Data Center"
	icon_state = "purple"
	sound_environment = 5

/area/station2/crew_quarters/fitness
	name = "Fitness Room"
	icon_state = "fitness"
	sound_environment = 2

/area/station2/crew_quarters/captain
	name = "Captain's Quarters"
	icon_state = "captain"
	sound_environment = 4

/area/station2/crew_quarters/hop
	name = "Head of Personnel's Quarters"
	icon_state = "green"
	sound_environment = 4

/area/station2/crew_quarters/cafeteria
	name = "Cafeteria"
	icon_state = "cafeteria"
	sound_environment = 0

	the_rising_tide_bar
		name = "The Rising Tide"


/area/station2/crew_quarters/kitchen
	name = "Kitchen"
	icon_state = "kitchen"
	sound_environment = 3

	freezer
		name = "Freezer"
		icon_state = "blue"

	therustykrab
		name = "The Rusty Krab"
		icon_state = "kitchen"

/area/station2/crew_quarters/clown
	name = "Clown Hole"
	icon_state = "storage"
	do_not_irradiate = 1

/area/station2/crew_quarters/catering
	name = "Catering Storage"
	icon_state = "storage"
	do_not_irradiate = 1

/area/station2/crew_quarters/bathroom
	name = "Bathroom"
	icon_state = "showers"

/area/station2/security/beepsky
	name = "Beepsky's House"
	icon_state = "storage"
	do_not_irradiate = 1

/area/station2/crew_quarters/jazz
	name = "Jazz Lounge"
	icon_state = "purple"

/area/station2/crew_quarters/info
	name = "Information Office"
	icon_state = "purple"

/area/station2/crew_quarters/bar
	name= "Bar"
	icon_state = "bar"
	sound_environment = 4

/area/station2/crew_quarters/baroffice
	name= "Bar Office"
	icon_state = "bar_office"
	sound_environment = 2

/area/station2/crew_quarters/heads
	name = "Head of Personnel's Office"
	icon_state = "HOP"
	sound_environment = 4

/area/station2/crew_quarters/hor
	name = "Research Director's Office"
	icon_state = "RD"
	sound_environment = 4
	requires_power = 1

	horprivate
	name = "Research Director's Private Quarters"
	icon_state = "RD"
	sound_environment = 4

/area/station2/crew_quarters/quarters
	name = "Crew Lounge"
	icon_state = "purple"
	sound_environment = 2

/area/station2/crew_quarters/quartersA
	name = "Crew Quarters A"
	icon_state = "crewquarters"
	sound_environment = 3

/area/station2/crew_quarters/quartersB
	name = "Crew Quarters B"
	icon_state = "crewquarters"
	sound_environment = 3

/area/station2/crew_quarters/quartersC
	name = "Crew Quarters C"
	icon_state = "crewquarters"
	sound_environment = 3

/area/station2/crew_quarters/toilets
	name = "Toilets"
	icon_state = "toilets"
	sound_environment = 3

/area/station2/crew_quarters/showers
	name = "Shower Room"
	icon_state = "showers"
	sound_environment = 3

/area/station2/crew_quarters/pool
	name = "Pool Room"
	icon_state = "showers"
	sound_environment = 3

/area/station2/crew_quarters/observatory
	name = "Observatory"
	icon_state = "observatory"
	sound_environment = 2

/area/station2/crew_quarters/courtroom
	name = "Courtroom"
	icon_state = "courtroom"
	sound_environment = 0

/area/station2/crew_quarters/juryroom
	name = "Jury Room"
	icon_state = "juryroom"
	sound_environment = 0

/area/station2/crew_quarters/barber_shop
	name = "Barber Shop"
	icon_state= "yellow"
	sound_environment = 2

/area/station2/crew_quarters/market
	name = "Public Market"
	icon_state = "yellow"
	sound_environment = 0

/area/station2/crew_quarters/garden
	name = "Public Garden"
	icon_state = "park"

area/station/crewquarters/garbagegarbs //It's the clothing store on Manta
	name = "Garbage Garbs clothing store"
	icon_state = "green"

area/station/crewquarters/cryotron
	name ="Cryogenic Crew Storage"
	icon_state = "blue"

/area/station2/com_dish/comdish
	name = "Communications Dish"
	icon_state = "yellow"
	force_fullbright = 1 // ????

/area/station2/com_dish/auxdish
	name = "Auxilary Communications Dish"
	icon_state = "yellow"
	force_fullbright = 1

/area/station2/com_dish/research_outpost
	name = "Research Outpost Communications Dish"
	icon_state = "yellow"
	force_fullbright = 1

/area/station2/engine
	sound_environment = 5
	workplace = 1

/area/station2/engine/engineering
	name = "Engineering"
	icon_state = "engineering"

/area/station2/engine/ptl
	name = "Power Transmission Laser"
	icon_state = "ptl"

/area/station2/engine/engineering/ce
	name = "Chief Engineer's Office"
	icon_state = "CE"

/area/station2/engine/engineering/ce/private
	name = "Chief Engineer's Private Quarters"
	icon_state = "CE"

/area/station2/engine/engineering/restroom
	name = "Engineering Restroom"
	icon_state = "toilets"

/area/station2/engine/engineering/breakroom
	name = "Engineering Break Room"
	icon_state ="showers"

/area/station2/engine/engineering/private
	name = "Engineering Quarters"
	icon_state = "yellow"

/area/mining/miningoutpost
	name = "Mining Outpost"
	icon_state = "engine"

/area/station2/engine/storage
	name = "Engineering Storage"
	icon_state = "engine_hallway"

/area/station2/engine/shield_gen
	name = "Engineering Shield Generator"
	icon_state = "engine_monitoring"

/area/station2/engine/shields
	name = "Engineering Shields"
	icon_state = "engine_monitoring"

/area/station2/engine/elect
	name = "Mechanic's Lab"
	icon_state = "mechanics"

/area/station2/engine/power
	name = "Engineering Power Room"
	icon_state = "showers"
	sound_environment = 5

/area/station2/engine/monitoring
	name = "Engineering Control Room"
	icon_state = "green"


/area/station2/engine/singcore
	name = "Singularity Core"
	icon_state = "red"

/area/station2/engine/eva
	name = "Engineering EVA"
	icon_state = "showers"

/area/station2/engine/core
	name = "Thermo-Electric Generator"
	icon_state = "teg" // sometimes you just gotta make an icon the way it is because that's what your heart tells you to do, even if it looks like something a cartoon for toddlers would reject for looking too stupid
	sound_environment = 10

/area/station2/engine/hotloop
	name = "Hot Loop"
	icon_state = "red"

/area/station2/engine/combustion_chamber
	name = "Combustion Chamber"
	icon_state = "combustion_chamber"

/area/station2/engine/coldloop
	name = "Cold Loop"
	icon_state = "purple"

/area/station2/engine/gas
	name = "Engineering Gas Storage"
	icon_state = "storage"
	sound_environment = 3

/area/station2/engine/inner
	name = "Inner Engineering"
	icon_state = "yellow"

/area/station2/engine/substation
	icon_state = "purple"
	sound_environment = 3

/area/station2/engine/substation/pylon
	name = "Electrical Substation"
	do_not_irradiate = 1

/area/station2/engine/substation/west
	name = "West Electrical Substation"
	do_not_irradiate = 1

/area/station2/engine/substation/east
	name = "East Electrical Substation"
	do_not_irradiate = 1

/area/station2/engine/substation/north
	name = "North Electrical Substation"
	do_not_irradiate = 1

/area/station2/engine/proto
	name = "Prototype Engine"
	icon_state = "prototype_engine"

/area/station2/engine/thermo
	name = "Thermoelectric generator"
	icon_state = "prototype_engine"

/area/station2/engine/proto_gangway
	name = "Prototype Gangway"
	icon_state = "green"
	luminosity = 1
	force_fullbright = 1
	requires_power = 0

/area/station2/hangar
	name = "Hangar"
	icon_state = "purple"
	sound_environment = 10

/area/station2/teleporter
	name = "Teleporter"
	icon_state = "teleporter"
	sound_environment = 3
	workplace = 1

/area/syndicate_teleporter
	name = "Syndicate Teleporter"
	icon_state = "teleporter"
	requires_power = 0
	teleport_blocked = 1
	do_not_irradiate = 1

/area/station2/medical
	name = "Medical area"
	icon_state = "medbay"
	workplace = 1

/area/station2/medical/medbay
	name = "Medbay"
	icon_state = "medbay"
	sound_environment = 3

/area/station2/medical/medbay/lobby
	name = "Medbay Lobby"
	icon_state = "medbay_lobby"

/area/station2/medical/medbay/cloner
	name = "Cloning"
	icon_state = "cloner"

/area/station2/medical/medbay/pharmacy
	name = "Pharmacy"
	icon_state = "chem"

/area/station2/medical/medbay/treatment1
	name = "Treatment Room 1"
	icon_state = "treat1"

/area/station2/medical/medbay/treatment2
	name = "Treatment Room 2"
	icon_state = "treat2"

/area/station2/medical/medbay/restroom
	name = "Medbay Restroom"
	icon_state = "blue"

/area/station2/medical/medbay/surgery
	name = "Medbay Operating Theater"
	icon_state = "medbay_surgery"

/area/station2/medical/medbay/surgery/storage
	name = "Medical Storage"
	icon_state = "blue"

/area/station2/medical/robotics
	name = "Robotics"
	icon_state = "medresearch"

/area/station2/medical/research
	name = "Medical Research"
	icon_state = "medresearch"
	sound_environment = 3

/area/station2/medical/head
	name = "Medical Director's Office"
	icon_state = "MD"
	sound_environment = 1

	private
		name = "Medical Director's  Private Quarters"

/area/station2/medical/cdc
	name = "Pathology Research"
	icon_state = "medcdc"
	sound_environment = 5

/area/station2/medical/dome
	name = "Monkey Dome"
	icon_state = "green"
	sound_environment = 3

/area/station2/medical/morgue
	name = "Morgue"
	icon_state = "morgue"
	sound_environment = 3

/area/station2/medical/crematorium
	name = "Crematorium"
	icon_state = "morgue"
	sound_environment = 3

/area/station2/medical/medbooth
	name = "Medical Booth"
	icon_state = "medbooth"
	sound_environment = 3

/area/station2/medical/breakroom
	name = "Medbay Break Room"
	icon_state = "medbay_break"
	sound_environment = 3

/area/station2/medical/maintenance
	name = "Medical Maintenance"
	icon_state = "medical_maintenance"
	sound_environment = 3
	do_not_irradiate = 1

/area/station2/medical/staff
	name = "Medbay Staff Area"
	icon_state = "medbay_staff"
	sound_environment = 3

/area/station2/security
	teleport_blocked = 1
	workplace = 1

/area/station2/security/main
	name = "Security"
	icon_state = "security"
	sound_environment = 2

/area/station2/security/interrogation
	name = "Interrogation Room"
	icon_state = "red"
	sound_environment = 2

/area/station2/security/processing
	name = "Processing Room"
	icon_state = "red"
	sound_environment = 2

/area/station2/security/brig
	name = "Brig"
	icon_state = "brigcell"
	sound_environment = 3
	teleport_blocked = 0

	cell_block_control
		name = "Cell Block Control"
		icon_state = "orange"

	cell_block
		name = "Cell Block"
		icon_state = "brigcell"
	cell1
		name = "Cell #1"
		icon_state = "red"
	genpop
		name = "Genpop Cell"
		icon_state = "brig"
	solitary
		name = "Solitary Confinement"
		icon_state = "brig"



/area/station2/security/checkpoint
	name = "Bridge Security Checkpoint"
	icon_state = "checkpoint1"
	sound_environment = 2

	arrivals
		name = "Arrivals Security Checkpoint"
	escape
		name = "Escape Hallway Security Checkpoint"
	customs
		name = "Customs Security Checkpoint"
	sec_foyer
		name = "Security Foyer Checkpoint"
	podbay
		name = "Pod Bay Security Checkpoint"
	chapel
		name = "Chapel Security Checkpoint"
	cargo
		name = "Cargo Security Checkpoint"
	west
		name = "West Hallway Security Checkpoint"
	east
		name = "East Hallway Security Checkpoint"
	medical
		name = "Medical Security Checkpoint"

/area/station2/security/armory //what the fuck this is not the real armory???
	name = "Armory" //ai_monitored/armory is, shitty ass code
	icon_state = "armory"
	sound_environment = 2

/area/station2/security/prison
	name = "Prison Station"
	icon_state = "brig"
	sound_environment = 2

/area/station2/security/secwing
	name = "Security Wing"
	icon_state = "brig"
	sound_environment = 2

/area/station2/security/secoffquarters
	name = "Sec. Officers Quarters"
	icon_state = "brig"
	sound_environment = 2
	requires_power = 1

/area/station2/security/starboardtorpedoes
	name = "Starboard Torpedo Bay"
	icon_state = "torpedoes_starboard"
	sound_environment = 2
	requires_power = 1

/area/station2/security/porttorpedoes
	name = "Port Torpedo Bay"
	icon_state = "torpedoes_port"
	sound_environment = 2
	requires_power = 1

/area/station2/security/detectives_office
	name = "Detective's Office"
	icon_state = "detective"
	sound_environment = 4
	workplace = 1

/area/station2/security/detectives_office_manta
	name = "Detective's Office"
	icon_state = "detective"
	sound_environment = 15
	workplace = 1
	sound_loop = 'sound/ambience/station/detectivesoffice.ogg'
	sound_loop_vol = 30
	sound_group = "detective"

	detectives_bedroom
		name = "Detective's Bedroom"
		icon_state = "red"
		workplace = 0

/area/station2/security/hos
	name = "Head of Security's Office"
	icon_state = "HOS"
	sound_environment = 4
	workplace = 0 //As does the hos

area/station/security/visitation
	name ="Visitation"
	icon_state = "red"
	sound_environment = 4

/area/station2/solar
	requires_power = 0
	luminosity = 1
	force_fullbright = 1
	workplace = 1
	do_not_irradiate = 1

/area/station2/solar/north
	name = "North Solar Array"
	icon_state = "yellow"
	icon_state = "panelsN"

/area/station2/solar/south
	name = "South Solar Array"
	icon_state = "panelsS"

/area/station2/solar/east
	name = "East Solar Array"
	icon_state = "panelsE"

/area/station2/solar/west
	name = "West Solar Array"
	icon_state = "panelsW"

/area/station2/solar/small_backup1
	name = "Emergency Solar Array 1"
	icon_state = "yellow"

/area/station2/solar/small_backup2
	name = "Emergency Solar Array 2"
	icon_state = "yellow"

/area/station2/solar/small_backup3
	name = "Emergency Solar Array 3"
	icon_state = "yellow"

/area/station2/quartermaster
	name = "Quartermaster's"
	icon_state = "quart"
	workplace = 1

/area/station2/quartermaster/office
	name = "Quartermaster's Office"
	icon_state = "quartoffice"
	sound_environment = 10

/area/station2/quartermaster/storage
	name = "Quartermaster's Storage"
	icon_state = "quartstorage"
	sound_environment = 2
	do_not_irradiate = 1

/area/station2/quartermaster/magnet
	name = "Magnet Control Room"
	icon_state = "green"
	sound_environment = 10

/area/station2/quartermaster/refinery
	name = "Refinery"
	icon_state = "green"
	sound_environment = 10

/area/station2/quartermaster/cargobay
	name = "Cargo Bay"
	icon_state = "quartstorage"
	sound_environment = 10

/area/station2/quartermaster/cargooffice
	name = "Cargo Bay Office"
	icon_state = "quartoffice"
	sound_environment = 10

/area/station2/janitor
	name = "Janitor's Office"
	icon_state = "janitor"
	sound_environment = 3
	workplace = 1

/area/station2/janitor/supply
	name = "Janitor's Supply Closet"
	icon_state = "janitor"
	sound_environment = 3
	workplace = 1

/area/station2/chemistry
	name = "Chemistry"
	icon_state = "chem"
	sound_environment = 3
	workplace = 1

/area/station2/testchamber
	name = "Test Chamber"
	icon_state = "yellow"
	sound_environment = 5
	workplace = 1
	do_not_irradiate = 1

/area/station2/science
	//name = "Research Outpost Zeta"
	name = "Research Sector"
	icon_state = "purple"
	sound_environment = 3
	workplace = 1

/area/station2/science/gen_storage
	name = "Research Storage"
	icon_state = "genstorage"
	do_not_irradiate = 1

/area/station2/science/restroom
	name = "Research Restroom"
	icon_state = "purple"

/area/station2/science/bot_storage
	name = "Robot Depot"
	icon_state = "toxstorage"

/area/station2/science/teleporter
	name = "Science Teleporter"
	icon_state = "telelab"

/area/station2/science/research_director
	name = "Research Director's Office"
	icon_state = "toxlab"
	workplace = 0

/area/station2/science/lab
	name = "Toxin Lab"
	icon_state = "toxlab"

/area/station2/science/artifact
	name = "Artifact Lab"
	icon_state = "artifact"

/area/station2/science/storage
	name = "Toxin Storage"
	icon_state = "toxstorage"
	do_not_irradiate = 1

/area/station2/science/laser
	name = "Optics Lab"
	icon_state = "yellow"

/area/station2/science/spectral
	name = "Spectral Studies Lab"
	icon_state = "purple"

/area/station2/science/construction
	name = "Research Sector Construction Area"
	icon_state = "yellow"
	do_not_irradiate = 1

/area/station2/test_area
	name = "Toxin Test Area"
	icon_state = "toxtest"
	virtual = 1
	sound_group = "toxtest"
	force_fullbright = 1

/area/station2/chapel/main
	name = "Chapel"
	icon_state = "chapel"
	sound_environment = 7

/area/station2/chapel/main/main //wtf why is this a thing

/area/station2/chapel/office
	name = "Chapel Office"
	icon_state = "chapeloffice"
	sound_environment = 11

/area/station2/storage
	name = "Storage Area"
	icon_state = "storage"
	workplace = 1

/area/station2/storage/tools
	name = "Tool Storage"
	icon_state = "storage"
	sound_environment = 3

/area/station2/storage/primary
	name = "Primary Tool Storage"
	icon_state = "primarystorage"
	sound_environment = 3

/area/station2/storage/autolathe
	name = "Autolathe Storage"
	icon_state = "storage"

/area/station2/storage/auxillary
	name = "Auxillary Storage"
	icon_state = "auxstorage"

/area/station2/storage/eva
	name = "EVA Storage"
	icon_state = "eva"
	sound_environment = 3

/area/station2/storage/eeva
	name = "Engineering EVA Storage"
	icon_state = "eva"

/area/station2/storage/secure
	name = "Secure Storage"
	icon_state = "storage"

/area/station2/storage/emergencyinternals
	name = "Emergency Internals"
	icon_state = "yellow"

/area/station2/storage/emergency
	name = "Emergency Storage A"
	icon_state = "emergencystorage"

/area/station2/storage/emergency2
	name = "Emergency Storage B"
	icon_state = "emergencystorage"

/area/station2/storage/tech
	name = "Technical Storage"
	icon_state = "auxstorage"
	do_not_irradiate = 1

/area/station2/storage/warehouse
	name = "Central Warehouse"
	icon_state = "red"
	sound_environment = 18

/area/station2/storage/testroom
	requires_power = 0
	name = "Test Room"
	icon_state = "storage"
	teleport_blocked = 1

// cogmap new areas ///////////

/area/station2/hangar
	name = "Hangar"
	icon_state = "hangar"
	workplace = 1
	do_not_irradiate = 1

	main
		name = "Pod Bay"
		sound_environment = 10
	catering
		name = "Catering Dock"
	arrivals
		name = "Arrivals Dock"
	sec
		name = "Secure Dock"
		teleport_blocked = 1
	engine
		name = "Engineering Dock"
	qm
		name = "Cargo Dock"
	escape
		name = "Escape Dock"
	science
		name = "Research Dock"
		teleport_blocked = 1
	port
		name = "Submarine Bay (Port)"
		requires_power = 1
	starboard
		name = "Submarine Bay (Starboard)"
	mining
		name = "Submarine Bay (Mining)"
	security
		name = "Submarine Bay (Security)"

/area/station2/hydroponics
	name = "Hydroponics"
	icon_state = "hydro"
	workplace = 1

/area/station2/hydroponics/lobby
	name = "Hydroponics Lobby"
	icon_state = "green"

/area/station2/owlery
	name = "Owlery"
	icon_state = "yellow"
	sound_environment = 15
	do_not_irradiate = 1

/area/station2/aviary
	name = "Aviary"
	icon_state = "aviary"
	sound_environment = 15
	do_not_irradiate = 1

/area/station2/habitat
	name = "Habitat Dome"
	icon_state = "aviary"
	sound_environment = 15
	do_not_irradiate = 1
	force_fullbright = 1

/area/station2/zen
	name = "Zen Garden"
	icon_state = "aviary"
	sound_environment = 15
	do_not_irradiate = 1

/area/station2/catwalk
	icon_state = "yellow"
	force_fullbright = 1

/area/station2/catwalk/north
	name = "North Maintenance Catwalk"

/area/station2/catwalk/south
	name = "South Maintenance Catwalk"

/area/station2/catwalk/west
	name = "West Maintenance Catwalk"

/area/station2/catwalk/east
	name = "East Maintenance Catwalk"

/area/station2/routingdepot
	name = "Routing Depot"
	icon_state = "depot"
	sound_environment = 13
	do_not_irradiate = 1

	catering
		name = "Cafeteria Router"

	eva
		name = "EVA Router"

	engine
		name = "Engine Router"

	medsci
		name = "Med-Sci Router"

	security
		name = "Security Router"

	airbridge
		name = "Airbridge Router"

/area/research_outpost
	name = "Research Outpost"
	icon_state = "blue"
	do_not_irradiate = 1

	hangar
		name = "Research Outpost Hangar"
		icon_state = "hangar"

	chamber
		name = "Research Outpost Test Chamber"
		icon_state = "yellow"

	maint
		name = "Research Outpost Maintenance"
		icon_state = "purple"
		do_not_irradiate = 1

	toxins
		name = "Research Outpost Toxins"
		icon_state = "green"

///////////////////////////////

/area/listeningpost
	name = "Listening Post"
	icon_state = "brig"
	teleport_blocked = 1
	do_not_irradiate = 1

	syndicateassaultvessel
		name ="Syndicate Assault Vessel"


/area/listeningpost/power
	name = "Listening Post Control Room"
	icon_state = "engineering"

/area/listeningpost/solars
	name = "Listening Post Solar Array"
	icon_state = "yellow"
	requires_power = 0
	luminosity = 1
	force_fullbright = 1

///////////////////////////////

/area/syndicate_station
	name = "Syndicate Station"
	icon_state = "yellow"
	requires_power = 0
	sound_environment = 2
	teleport_blocked = 1
	sound_group = "syndicate_station"

	battlecruiser
		name = "Syndicate Battlecruiser Cairngorm"
		icon_state = "red"
		sanctuary = 1

	firing_range
		name = "firing range"
		icon_state = "blue"

///////////////////////////////

/area/wizard_station
	name = "Wizard's Den"
	icon_state = "yellow"
	requires_power = 0
	sound_environment = 4
	teleport_blocked = 1

	CanEnter( var/atom/movable/A )
		var/mob/living/M = A
		if( istype(M) && M.mind && M.mind.special_role != "wizard" && isliving(M) )
			if(M.client && M.client.holder)
				return 1
			boutput( M, "<span class='alert'>A magical barrier prevents you from entering!</span>" )//or something
			return 0
		return 1

	//sanctuary = 1

///////////////////////////////

/area/station2/ai_monitored
	name = "AI Monitored Area"
	var/obj/machinery/camera/motion/motioncamera = null
	workplace = 1

/area/station2/ai_monitored/New()
	..()
	// locate and store the motioncamera
	SPAWN_DBG (20) // spawn on a delay to let turfs/objs load
		for (var/obj/machinery/camera/motion/M in src)
			motioncamera = M
			return
	return

/area/station2/ai_monitored/Entered(atom/movable/O)
	..()
	if (ismob(O) && motioncamera)
		motioncamera.newTarget(O)
//
/area/station2/ai_monitored/Exited(atom/movable/O)
	..()
	if (ismob(O) && motioncamera)
		motioncamera.lostTarget(O)

/area/station2/ai_monitored/storage/eva
	name = "EVA Storage"
	icon_state = "eva"
	sound_environment = 12

/area/station2/ai_monitored/storage/secure
	name = "Secure Storage"
	icon_state = "storage"
	sound_environment = 12

/area/station2/ai_monitored/storage/emergency
	name = "Emergency Storage"
	icon_state = "storage"
	sound_environment = 12

/area/station2/ai_monitored/armory
	name = "Armory"
	icon_state = "armory"
	sound_environment = 2
	teleport_blocked = 1

///////////////////////////////

/area/station2/turret_protected
	name = "Turret Protected Area"
	var/list/obj/machinery/turret/turret_list = list()
	var/obj/machinery/camera/motion/motioncamera = null
	var/list/obj/blob/blob_list = list() //faster to cache blobs as they enter instead of searching the area for them (For turrets)

/area/station2/turret_protected/New()
	..()
	// locate and store the motioncamera
	SPAWN_DBG (20) // spawn on a delay to let turfs/objs load
		for (var/obj/machinery/camera/motion/M in src)
			motioncamera = M
			return
	return

/area/station2/turret_protected/Entered(O)
	..()
	if (isliving(O))
		if(!issilicon(O))
			if (motioncamera)
				motioncamera.newTarget(O)
			popUpTurrets()
	if (istype(O,/obj/blob))
		blob_list += O
	return 1

/area/station2/turret_protected/Exited(O)
	..()
	if (isliving(O))
		if (!issilicon(O))
			if(motioncamera)
				motioncamera.lostTarget(O)
			//popDownTurrets()
	if (istype(O,/obj/blob))
		blob_list -= O
	return 1

/area/station2/turret_protected/proc/popDownTurrets()
	for (var/obj/machinery/turret/aTurret in src.turret_list)
		aTurret.popDown()

/area/station2/turret_protected/proc/popUpTurrets()
	for (var/obj/machinery/turret/aTurret in src.turret_list)
		aTurret.popUp()


/area/station2/turret_protected/ai_upload
	name = "AI Upload Chamber"
	icon_state = "ai_upload"
	sound_environment = 12
	do_not_irradiate = 1

/area/station2/turret_protected/ai_upload_foyer
	name = "AI Upload Foyer"
	icon_state = "ai_foyer"
	sound_environment = 12

/area/station2/turret_protected/ai
	name = "AI Chamber"
	icon_state = "ai_chamber"
	sound_environment = 12
	do_not_irradiate = 1

/area/station2/turret_protected/AIbasecore1
	name = "AI Core 1"
	icon_state = "AIt"
	sound_environment = 12

/area/station2/turret_protected/AIbaseoutside
	name = "AI Perimeter Defenses"
	icon_state = "AIt"
	requires_power = 0
	sound_environment = 12

/area/station2/turret_protected/AIbasecore2
	name = "AI Core 2"
	icon_state = "AIt"
	sound_environment = 12

/area/station2/turret_protected/Zeta
	name = "Computer Core"
	icon_state = "AIt"
	sound_environment = 12

/area/station2/turret_protected/port
	name = "AI Upload Foyer Port"
	sound_environment = 12
	icon_state = "ai_foyer"

/area/station2/turret_protected/starboard
	name = "AI Upload Foyer Starboard"
	sound_environment = 12
	icon_state = "ai_foyer"


*/
