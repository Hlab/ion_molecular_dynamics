from __future__ import division
import numpy as np

class simulation_parameters(object):
    
    def __init__(self):
    
        self.number_ions = 15
        #trap frequencies
        self.f_drve = 30.0 * 10**6#Hz
        self.f_x = 2.8 * 10**6#MHz
        self.f_y = 3.0 * 10**6#Hz
        self.f_z = 0.150 * 10**6#Hz
        self.use_harmonic_approximation = True
        #simulation parameters
        self.damping = 0 #optional velocity damping, useful for finding equlibrium positions
        self.simulation_duration = 0.001#seconds
        self.timestep = (1 / self.f_drve) /100#seconds
        #ion parameters
        self.mass = 40 * 1.6605402e-27 #40 amu in kg
        self.coulomb_coeff = 2.30707955552e-28 # k =  U.e**2 / (4.0 * U.pi * U.eps0) 
        self.hbar = 1.05457266913e-34
        self.transition_gamma = (1 / (7.1 * 10**-9)) #Gamma = 1 / Tau
        #laser
        self.saturation = 0
        self.laser_detuning = -.5 * self.transition_gamma
        self.laser_direction = np.array([1.0,1.0,1.0]); self.laser_direction = self.laser_direction / np.sqrt(np.sum(self.laser_direction))#normalized
        self.transition_k_mag =  2 * np.pi / (396.847 * 10**-9) 
        self.laser_waist =  1.
        self.pulsed_laser = False
        self.laser_center = np.array([0.0,0.0,1.0])
    
    @property
    def total_steps(self):
        return int(self.simulation_duration / self.timestep)