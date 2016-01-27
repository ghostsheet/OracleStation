#define TESLA_DEFAULT_POWER 1738260
#define TESLA_MINI_POWER 869130

var/list/blacklisted_tesla_types = list(/obj/machinery/atmospherics,
										/obj/machinery/power/emitter,
										/obj/machinery/field/generator,
										/mob/living/simple_animal,
										/obj/machinery/particle_accelerator/control_box,
										/obj/structure/particle_accelerator/fuel_chamber,
										/obj/structure/particle_accelerator/particle_emitter/center,
										/obj/structure/particle_accelerator/particle_emitter/left,
										/obj/structure/particle_accelerator/particle_emitter/right,
										/obj/structure/particle_accelerator/power_box,
										/obj/structure/particle_accelerator/end_cap,
										/obj/machinery/field/containment,
										/obj/structure/disposalpipe,
										/obj/machinery/gateway)

/obj/singularity/energy_ball
	name = "energy ball"
	desc = "An energy ball."
	icon = 'icons/obj/tesla_engine/energy_ball.dmi'
	icon_state = "energy_ball"
	pixel_x = -32
	pixel_y = -32
	current_size = STAGE_TWO
	move_self = 1
	grav_pull = 0
	contained = 0
	density = 1
	
	var/list/orbiting_balls = list()
	var/produced_power
	var/energy_to_raise = 100
	var/energy_to_lower = -10

/obj/singularity/energy_ball/Destroy()
	if (orbiting && istype(orbiting, /obj/singularity/energy_ball))
		var/obj/singularity/energy_ball/EB = orbiting
		EB.orbiting_balls -= src
		orbiting = null
	
	for(var/ball in orbiting_balls)
		var/obj/singularity/energy_ball/EB = ball
		qdel(EB)
	
	return ..()

/obj/singularity/energy_ball/process()
	if(orbiting)
		handle_energy()
		
		move_the_basket_ball(2 + orbiting_balls.len * 2)
		
		playsound(src.loc, 'sound/magic/lightningbolt.ogg', 100, 1, extrarange = 15)
		
		pixel_x = 0
		pixel_y = 0
		
		dir = tesla_zap(src, 7, TESLA_DEFAULT_POWER)
		
		pixel_x = -32
		pixel_y = -32
		for (var/ball in orbiting_balls)
			tesla_zap(ball, rand(1, Clamp(orbiting_balls.len, 3, 7)), TESLA_MINI_POWER)
	else
		energy = 0 // ensure we dont have miniballs of miniballs
	
	return

/obj/singularity/energy_ball/examine(mob/user)
	..()
	if(orbiting_balls.len)
		user << "The amount of orbiting mini-balls is [orbiting_balls.len]."


/obj/singularity/energy_ball/proc/move_the_basket_ball(var/move_amount)
	//we face the last thing we zapped, so this lets us favor that direction a bit
	var/first_move = dir
	for(var/i in 0 to move_amount)
		var/move_dir = pick(alldirs + first_move) //give the first move direction a bit of favoring.
		var/turf/T = get_step(src, move_dir)
		if(can_move(T))
			loc = T

/obj/singularity/energy_ball/proc/handle_energy()
	if(energy >= energy_to_raise)
		energy_to_lower = energy_to_raise - 10
		energy_to_raise += energy_to_raise

		playsound(src.loc, 'sound/magic/lightning_chargeup.ogg', 100, 1, extrarange = 15)
		spawn(100)
			var/obj/singularity/energy_ball/EB = new(loc)
			
			EB.transform *= pick(0.3, 0.4, 0.5, 0.6, 0.7)
			var/icon/I = icon(icon,icon_state,dir)
			
			var/orbitsize = (I.Width() + I.Height()) * pick(0.5, 0.6, 0.7)
			orbitsize -= (orbitsize / world.icon_size) * (world.icon_size * 0.25)
			
			EB.orbit(src, orbitsize, pick(FALSE, TRUE), rand(10, 25), pick(3, 4, 5, 6, 36))
			
	else if(energy < energy_to_lower && orbiting_balls.len)
		energy_to_raise = energy_to_raise * 0.5
		energy_to_lower = (energy_to_raise * 0.5) - 10
		
		var/Orchiectomy_target = pick(orbiting_balls)
		qdel(Orchiectomy_target)
		
	else if(orbiting_balls.len)
		energy -= orbiting_balls.len

/obj/singularity/energy_ball/Bump(atom/A)
	dust_mobs(A)

/obj/singularity/energy_ball/Bumped(atom/A)
	dust_mobs(A)

/obj/singularity/energy_ball/orbit(obj/singularity/energy_ball/target)
	if (istype(target))
		target.orbiting_balls += src
		poi_list -= src
	
	. = ..()
	
	if (istype(target))
		target.orbiting_balls -= src

/obj/singularity/energy_ball/proc/dust_mobs(atom/A)
	if(istype(A, /mob/living/carbon))
		var/mob/living/carbon/C = A
		C.dust()
	return

/proc/get_closest_atom(list, source, typetocheck)
	var/closest_atom
	var/closest_distance
	for(var/A in list)
		if (typetocheck && !istype(A, typetocheck))
			continue
		var/distance = get_dist(source, A)
		if(!closest_atom || closest_distance > distance)
			closest_distance = distance
			closest_atom = A
	return closest_atom

/proc/tesla_zap(var/atom/source, zap_range = 3, power)
	. = source.dir
	if(power < 1000)
		return
	var/list/tesla_coils = list()
	var/list/grounding_rods = list()
	var/list/potential_machine_zaps = list()
	var/list/potential_mob_zaps = list()
	var/list/potential_structure_zaps = list()
	var/closest_atom
	for(var/atom/A in oview(source, zap_range))
		if(istype(A, /obj/machinery/power/tesla_coil))
			var/obj/machinery/power/tesla_coil/C = A
			if(!C.being_shocked)
				tesla_coils += C

		else if(istype(A, /obj/machinery/power/grounding_rod))
			var/obj/machinery/power/grounding_rod/R = A
			grounding_rods += R
			
		else if(istype(A, /obj/machinery))
			var/obj/machinery/M = A
			if(!is_type_in_list(M, blacklisted_tesla_types) && !M.being_shocked)
				potential_machine_zaps += M
		
		else if(istype(A, /obj/structure))
			var/obj/structure/M = A
			if(!is_type_in_list(M, blacklisted_tesla_types) && !M.being_shocked)
				potential_structure_zaps += M
			
		else if(istype(A, /mob/living))
			var/mob/living/L = A
			if(!is_type_in_list(L, blacklisted_tesla_types) && L.stat != DEAD)
				potential_mob_zaps += L

	closest_atom = get_closest_atom(tesla_coils, source)
	if(closest_atom)
		var/obj/machinery/power/tesla_coil/C = closest_atom
		source.Beam(C, icon_state="lightning[rand(1,12)]", icon='icons/effects/effects.dmi', time=5)
		C.tesla_act(power)

	if(!closest_atom)
		closest_atom = get_closest_atom(grounding_rods, source)
		if(closest_atom)
			var/obj/machinery/power/grounding_rod/R = closest_atom
			source.Beam(R, icon_state="lightning[rand(1,12)]", icon='icons/effects/effects.dmi', time=5)
			R.tesla_act(power)
			
	if(!closest_atom)
		closest_atom = get_closest_atom(potential_mob_zaps, source)
		if(closest_atom)
			var/mob/living/L = closest_atom
			var/shock_damage = Clamp(round(power/400), 10, 90) + rand(-5, 5)
			source.Beam(L, icon_state="lightning[rand(1,12)]", icon='icons/effects/effects.dmi', time=5)
			L.electrocute_act(shock_damage, source, 1, tesla_shock = 1)
			if(istype(L, /mob/living/silicon))
				var/mob/living/silicon/S = L
				S.emp_act(2)
				tesla_zap(S, 7, power / 1.5) // metallic folks bounce it further
			else
				tesla_zap(L, 5, power / 1.5)
			
	if(!closest_atom)
		closest_atom = get_closest_atom(potential_machine_zaps, source)
		if(closest_atom)
			var/obj/machinery/M = closest_atom
			source.Beam(M, icon_state="lightning[rand(1,12)]", icon='icons/effects/effects.dmi',time=5)
			M.tesla_act(power)
			if(prob(85))
				M.emp_act(2)
			else
				if(prob(50))
					M.ex_act(3)
				else
					if(prob(90))
						M.ex_act(2)
					else
						M.ex_act(1)
			
	if(!closest_atom)
		closest_atom = get_closest_atom(/obj/structure, potential_structure_zaps, source)
		if(closest_atom)
			var/obj/structure/S = closest_atom
			source.Beam(S, icon_state="lightning[rand(1,12)]", icon='icons/effects/effects.dmi', time=5)
			S.tesla_act(power)
			
	if(closest_atom)
		var/zapdir = get_dir(source, closest_atom)
		if (zapdir)
			. = zapdir

