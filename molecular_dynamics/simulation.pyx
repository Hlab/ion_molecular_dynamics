import numpy as np
from libc.math cimport sin, acos, cos, sqrt, M_PI, exp

cdef class simulator(object):

    cdef int TOTAL_STEPS
    cdef int NUMBER_IONS
    cdef double TIMESTEP
    cdef double W_DRIVE
    cdef double W_X
    cdef double W_Y
    cdef double W_Z
    cdef double MASS
    cdef double COULOMB_COEFF
    cdef double VEL_DAMPING
    cdef double HBAR 
    #laser parameters
    cdef double GAMMA
    cdef double SATURATION
    cdef double LASER_DETUNING
    cdef double [:] LASER_DIRECTION
    cdef double [:] LASER_CENTER
    cdef double TRANSITION_K_MAG
    cdef double LASER_WAIST
    cdef int PULSED_LASER
    cdef int USE_HARMONIC_APPROXIMATION
    
    def __init__(self, parameters):
        p = parameters
        self.TRANSITION_K_MAG = p.transition_k_mag
        self.LASER_DIRECTION = p.laser_direction
        self.LASER_DETUNING = p.laser_detuning
        self.SATURATION = p.saturation
        self.GAMMA = p.transition_gamma
        self.HBAR = p.hbar
        self.VEL_DAMPING = p.damping
        self.COULOMB_COEFF = p.coulomb_coeff
        self.MASS = p.mass
        self.W_Z = p.f_z * 2 * M_PI
        self.W_Y = p.f_y * 2 * M_PI
        self.W_X = p.f_x * 2 * M_PI
        self.W_DRIVE = p.f_drve * 2 * M_PI
        self.TIMESTEP = p.timestep
        self.NUMBER_IONS = p.number_ions
        self.TOTAL_STEPS = p.total_steps
        self.LASER_WAIST = p.laser_waist
        self.LASER_CENTER = p.laser_center
        self.PULSED_LASER = int(p.pulsed_laser)
        self.USE_HARMONIC_APPROXIMATION = int(p.use_harmonic_approximation)
 
    cdef void calculate_acceleration(self, double [:, :] position, double [:, :] velocity, double [:, :] current_acceleration, double time, double [:, :] random_floats, char[:] excitation):
        '''
        given the current position, computes the current acceleration and fills in the current_acceleration array
        '''
        cdef int i = 0
        cdef int j = 0
        cdef double dx, dy, dz, distance_sq
        cdef double Fx, Fy, Fz
        cdef double inst_detuning
        cdef double gamma_laser
        cdef double p_excited
        cdef double theta = 0 
        cdef double phi = 0
        cdef double r_x
        cdef double r_y
        cdef double r_z
        cdef double distance_along_laser_sq
        cdef double distance_perp_laser_sq
        #acceleration due to the trap
        for i in range(self.NUMBER_IONS):
            if not self.USE_HARMONIC_APPROXIMATION:
                current_acceleration[i, 0] = ( (1/2.)*(-self.W_X**2 + self.W_Y**2 + self.W_Z**2) - self.W_DRIVE * sqrt(self.W_X**2 + self.W_Y**2 + self.W_Z**2) * cos (self.W_DRIVE * time)) * position[i, 0]
                current_acceleration[i, 1] = ( (1/2.)*( self.W_X**2 - self.W_Y**2 + self.W_Z**2) + self.W_DRIVE * sqrt(self.W_X**2 + self.W_Y**2 + self.W_Z**2) * cos (self.W_DRIVE * time)) * position[i, 1]
            else:
                current_acceleration[i, 0] = - self.W_X**2 *  position[i, 0]
                current_acceleration[i, 1] = - self.W_Y**2 *  position[i, 1]
            current_acceleration[i, 2] = - self.W_Z**2 *  position[i, 2]
        #acceleration due to the coulombic repulsion
        for i in range(self.NUMBER_IONS):
            for j in range(i + 1, self.NUMBER_IONS):
                #the double for loop iterations over unique pairs
                dx = position[i, 0] - position[j, 0]
                dy = position[i, 1] - position[j, 1]
                dz = position[i, 2] - position[j, 2]
                distance_sq = dx**2 + dy**2 + dz**2
                if distance_sq == 0:
                    raise Exception("Distance between ions is 0")
                Fx = self.COULOMB_COEFF * dx / (distance_sq)**(3./2.)
                Fy = self.COULOMB_COEFF * dy / (distance_sq)**(3./2.)
                Fz = self.COULOMB_COEFF * dz / (distance_sq)**(3./2.)
                #acceleartion is equal and opposite
                current_acceleration[i, 0] += Fx / self.MASS
                current_acceleration[i, 1] += Fy / self.MASS
                current_acceleration[i, 2] += Fz / self.MASS
                current_acceleration[j, 0] -= Fx / self.MASS
                current_acceleration[j, 1] -= Fy / self.MASS
                current_acceleration[j, 2] -= Fz / self.MASS
            #optional velocity damping
            current_acceleration[i, 0] += - self.VEL_DAMPING * velocity[i, 0]
            current_acceleration[i, 1] += - self.VEL_DAMPING * velocity[i, 1]
            current_acceleration[i, 2] += - self.VEL_DAMPING * velocity[i, 2]
        #acceleration due to laser interaction
        for i in range(self.NUMBER_IONS):
            inst_detuning = self.LASER_DETUNING - self.TRANSITION_K_MAG * ( self.LASER_DIRECTION[0] * velocity[i, 0] + self.LASER_DIRECTION[1] * velocity[i, 1]+ self.LASER_DIRECTION[2] * velocity[i, 2]) #Delta + k . v
            gamma_laser = self.SATURATION /  (1. + (2 * inst_detuning /  self.GAMMA)**2) * self.GAMMA / 2.
            if self.PULSED_LASER:
                if (time * self.W_X * 1.000/ (2 * M_PI)) % 1.0 < 0.5:
                    gamma_laser = 0.0
            #reducing gamma_laser due to finie waist of the beam  
            r_x = (self.LASER_CENTER[0] - position[i, 0])
            r_y = (self.LASER_CENTER[1] - position[i, 1])
            r_z = (self.LASER_CENTER[2] - position[i, 2])
            #calculating |k_hat dot r|
#             distance_along_laser_sq = + (self.LASER_DIRECTION[0] * r_x)**2 \
#                                       + (self.LASER_DIRECTION[1] * r_y)**2 \
#                                       + (self.LASER_DIRECTION[2] * r_z)**2  
            #calculating |r - k_hat dot r|          
            distance_perp_laser_sq = + (r_x - self.LASER_DIRECTION[0] * r_x)**2 \
                                     + (r_y - self.LASER_DIRECTION[1] * r_y)**2 \
                                     + (r_z - self.LASER_DIRECTION[2] * r_z)**2
            gamma_laser = gamma_laser * exp(- distance_perp_laser_sq / self.LASER_WAIST**2)
            #could also reduce gamma_laser due to the rayleigh range here by taking into account distance_along_laser_sq
            if not excitation[i]:
                #if atom is not currently excited, calculate probability to get excited
                p_exc = gamma_laser * self.TIMESTEP
                if random_floats[i, 0] <= p_exc:
                    #atom gets excited
                    excitation[i] = 1
                    #acceleration = (momentum change) / ( time * mass)
                    current_acceleration[i, 0] += self.HBAR * self.TRANSITION_K_MAG * self.LASER_DIRECTION[0] / (self.TIMESTEP * self.MASS) 
                    current_acceleration[i, 1] += self.HBAR * self.TRANSITION_K_MAG * self.LASER_DIRECTION[1] / (self.TIMESTEP * self.MASS) 
                    current_acceleration[i, 2] += self.HBAR * self.TRANSITION_K_MAG * self.LASER_DIRECTION[2] / (self.TIMESTEP * self.MASS) 
                else:
                    #atom stays in the ground state
                    pass
            else:
                #if atom is currently excited, it can decay sponteneously or stimulated
                p_spon = self.GAMMA * self.TIMESTEP
                p_stim = gamma_laser * self.TIMESTEP
                if p_spon > 0.1 or p_stim > 0.1:
                    raise Exception ("time step too small to deal with emission")
                if random_floats[i, 0] <= p_stim:
                    #atom gets de-excited, stimualted
                    excitation[i] = 0
                    current_acceleration[i, 0] -= self.HBAR *self. TRANSITION_K_MAG * self.LASER_DIRECTION[0] / (self.TIMESTEP * self.MASS) 
                    current_acceleration[i, 1] -= self.HBAR * self.TRANSITION_K_MAG * self.LASER_DIRECTION[1] / (self.TIMESTEP * self.MASS) 
                    current_acceleration[i, 2] -= self.HBAR * self.TRANSITION_K_MAG * self.LASER_DIRECTION[2] / (self.TIMESTEP * self.MASS) 
                elif p_stim < random_floats[i, 0] <= (p_stim + p_spon):
                    #atom gets de-excited, spontaneous, in a random direction
                    excitation[i] = 0
                    theta = 2 * M_PI * random_floats[i, 1]
                    phi = acos(2 * random_floats[i, 2] - 1)
                    current_acceleration[i, 0] += self.HBAR * self.TRANSITION_K_MAG * sin(theta) * cos(phi)   / (self.TIMESTEP * self.MASS) 
                    current_acceleration[i, 1] += self.HBAR * self.TRANSITION_K_MAG * sin(theta) * sin(phi)   / (self.TIMESTEP * self.MASS) 
                    current_acceleration[i, 2] += self.HBAR * self.TRANSITION_K_MAG * cos(theta)              / (self.TIMESTEP * self.MASS) 
                else:
                    #atom stays excited
                    pass
     
    cdef void do_verlet_integration(self, double [:, :, :] positions, double [:, :, :] random_floats, char [:, :] excitations):
        cdef double[:, :] current_position = positions[:,1,:]
        initial_excitation = np.zeros(self.NUMBER_IONS, dtype = np.uint8)
        cdef char[:] current_excitation = initial_excitation
        initial_acceleration =  np.zeros((self.NUMBER_IONS, 3))
        cdef double[:, :] current_acceleration = initial_acceleration
        current_velocity_np =  np.array(positions[:,1,:]) - np.array(positions[:,0,:])
        cdef double[:, :] current_velocity = current_velocity_np
        cdef int i
        cdef int j
        cdef int k
        cdef double current_time
        cdef double next_print_progress = 0
        for i in range(2, self.TOTAL_STEPS):
            #print progress update
            if next_print_progress / 100.0 < float(i) / self.TOTAL_STEPS:
                print 'PROGRESS: {} %'.format(next_print_progress)
                next_print_progress = next_print_progress + 10
            current_time = i * self.TIMESTEP
            self.calculate_acceleration(current_position, current_velocity, current_acceleration, current_time, random_floats[i], current_excitation)
            #cycle over ions
            for j in range(self.NUMBER_IONS):
                #cycle over coordinates
                for k in range(3):
                    positions[j, i, k] = 2 * positions[j , i - 1, k] -  positions[j, i - 2, k] + current_acceleration[j, k] * self.TIMESTEP**2
                    current_velocity[j, k] = (positions[j, i, k] - positions[j, i -2, k]) / (2 * self.TIMESTEP)
                excitations[i,j] = current_excitation[j]
            current_position = positions[:,i,:]
         
    def simulation(self, starting_position, starting_velocities, random_seeding = None):
        assert starting_position.shape == (self.NUMBER_IONS, 3), "Incorrect starting position format"
        if random_seeding is not None:
            np.random.seed(random_seeding)
        #precalcualte random floats we will be using
        random_floats = np.random.random((self.TOTAL_STEPS, self.NUMBER_IONS, 3))
        positions = np.zeros((self.NUMBER_IONS, self.TOTAL_STEPS, 3))
        excitations = np.zeros((self.TOTAL_STEPS, self.NUMBER_IONS), dtype = np.uint8)
        positions[:, 0, :] = starting_position
        positions[:, 1, :] = starting_position + starting_velocities
        cdef double [:, :, :] positions_view = positions
        cdef double [:, :, :] random_float_view = random_floats
        cdef char [:,:] excitations_view = excitations
        self.do_verlet_integration(positions_view, random_float_view, excitations_view)
        return positions, excitations