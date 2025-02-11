# -*- coding: utf-8 -*-
"""
Created on Mon Jan  7 13:49:24 2019

@author: butenko
"""
import h5py
import os
import neuron as n
import numpy as np
from pandas import read_csv
import matplotlib.pyplot as plt
import time as tm
import multiprocessing as mp

import logging

from Axon_files.axon import Axon
from Axon_files.Parameter_insertion_python3 import paste_to_hoc_python3, paste_paraview_vis_python3

# this script is solely for McIntyre2002 model

#This function only saves the dictionary of the activation rate, the visualizator is called externally outside of docker container!
#IMPORTANT: if same connections of different branches will be united (otherwise, the circuit image is unreadable).
#In this case, the activation rate will be assessed as



def conduct_parallel_NEURON(population_name,last_point,N_index_glob,N_index,Ampl_scale,t_steps,n_segments,dt,tstop,n_pulse,v_init,output):

#    nodes=[]
#    for point_inx in range(n_segments):
#        nodes_point_in_time=np.load(os.environ['PATIENTDIR']+'/Points_in_time/Signal_t_conv'+str(point_inx+N_index*n_segments+last_point)+'.npy') #get solution for each compartment in time for one neuron
#        nodes.append(nodes_point_in_time*(1000)*Ampl_scale)    #convert to mV
#    nodes=np.asarray(nodes)
#    nodes = nodes.ravel()
#
#    V_art=np.zeros((n_segments,t_steps),float)
#
#    for i in range(n_segments):
#        V_art[i,:]=nodes[(i*t_steps):((i*t_steps)+t_steps)]


    #to distinguish axons in different populations, we indexed them with the global index of the last compartment
    axon_in_time=np.load(os.environ['PATIENTDIR']+'/Axons_in_time/Signal_t_conv'+str(n_segments-1+N_index*n_segments+last_point)+'.npy')
    V_art=np.zeros((n_segments,t_steps),float)
    for i in range(n_segments):
        V_art[i,:]=axon_in_time[i,:t_steps]*(1000)*Ampl_scale   #convert to mV

    #only if we want to save potential in time on axons
    #np.save('Field_on_axons_in_time/'+str(population_name)+'axon_'+str(N_index_glob), V_art)


    n.h('{load_file("axon4pyfull.hoc")}')

    n.h.deletenodes()
    n.h.createnodes()

    n.h.dependent_var()
    n.h.initialize()
    n.h.setupAPWatcher_0() # 'left' end of axon
    n.h.setupAPWatcher_1() # 'right' end of axon

    n.h.dt = dt
    n.h.tstop = tstop
    n.h.n_pulse = n_pulse
    n.h.v_init=v_init


    for i in range(0,V_art.shape[0]):
        n.h.wf[i]=n.h.Vector(V_art[i,:])        # feed the potential in time for compartment i to NEURON

    n.h.stimul()
    n.h.run()
    spike=n.h.stoprun-0.5

    if spike==0.5:
        return output.put([N_index_glob,N_index])
    else:
        return output.put([N_index_glob,-1])


def run_simulation_with_NEURON(d, last_point,population_index,fib_diam,n_Ranvier,N_models,Ampl_scale,n_processors,neuron_encap,neuron_csf,neuron_array_name=None):
    # this script is solely for McIntyre2002 model
    '''Here we assume that all axons have the same number of nodes of Ranvier (and hence the length) and the morphology'''

    # phi and t_step in s here
    t_steps_trunc = int(d['phi']/d['t_step']) + int(d['T']/d['t_step'])*17  # empirically defined number (i.e., we need 16*T after pulse period)
    tstop = (d['t_step']*1000.0)*t_steps_trunc  # convert to ms

    dt = d['t_step']*1000.0

    if d['Stim_side']==0:
        stim_folder='Results_rh/'
    else:
        stim_folder='Results_lh/'

    n_pulse=1   # we always simulate only one pulse from DBS. If need more, we should just copy the array and make sure the time vectors are in order

    param_ax={
    'centered':True,
    'diameter':fib_diam
    }
    ax=Axon(param_ax)
    axon_dict=Axon.get_axonparams(ax)

    paranodes1=axon_dict["para1_nodes"]*(n_Ranvier-1)/(21-1)
    paranodes2=axon_dict["para2_nodes"]*(n_Ranvier-1)/(21-1)
    if axon_dict["fiberD"]>3.0:
        axoninter=(n_Ranvier-1)*6
    else:
        axoninter=(n_Ranvier-1)*3
    n_segments=int(n_Ranvier+paranodes1+paranodes2+axoninter)

    #passing through n.h. does not work sometimes, so we do insert the parameters straight to the file
    paste_to_hoc_python3(n_Ranvier,paranodes1,paranodes2,axoninter,n_segments,d['v_init'],axon_dict["fiberD"],axon_dict["para1_length"],axon_dict["para2_length"],axon_dict["ranvier_length"],axon_dict["node_diameter"],axon_dict["axon_diameter"],axon_dict["para1_diameter"],axon_dict["para2_diameter"],axon_dict["deltax"],axon_dict["lamellas"],int(1.0/dt))

    if population_index==-1:            # only one population is simulated
        population_name=''
        Vert_full_get=read_csv(os.environ['PATIENTDIR']+'/Neuron_model_arrays/All_neuron_models.csv', delimiter=' ', header=None)     # get all neuron models
        Vert_full=Vert_full_get.values
        Vert_full=np.round(Vert_full,8)

        Vert_get=read_csv(os.environ['PATIENTDIR']+'/Neuron_model_arrays/Vert_of_Neural_model_NEURON.csv', delimiter=' ', header=None)    # get only physiologically correct neuron models
        Vert=Vert_get.values
        Vert=np.round(Vert,8)
    else:
        hf = h5py.File(os.environ['PATIENTDIR']+'/Neuron_model_arrays/All_neuron_models_by_populations.h5', 'r')
        lst=list(hf.keys())

        if N_models==0:
            logging.critical("{} population was not placed".format(str(lst[population_index])))
            return 0

        population_name=str(lst[population_index])+'/'
        Vert_full=hf.get(lst[population_index])
        Vert_full=np.array(Vert_full)
        hf.close()
        Vert_full=np.round(Vert_full,8)

        hf2 = h5py.File(os.environ['PATIENTDIR']+'/Neuron_model_arrays/Vert_of_Neural_model_NEURON_by_populations.h5', 'r')
        lst=list(hf2.keys())
        Vert=hf2.get(lst[population_index])
        Vert=np.array(Vert)
        hf2.close()
        Vert=np.round(Vert,8)

#        #only if we want to save potential in time on axons
#        if not os.path.isdir('Field_on_axons_in_time/'+str(lst[population_index])+'/'):
#            os.makedirs('Field_on_axons_in_time/'+str(lst[population_index]))

    Nodes_status=np.zeros((N_models*n_segments,4),float)    #Nodes_status will contain info whether the placed(!) axon was activated
    Nodes_status[:,:3]=Vert[:,:]

    List_of_activated=[]
    List_of_not_activated=[]
    Activated_models=0
    int_counter=0
    Neuron_index=0
    neuron_global_index_array=np.zeros((N_models),int)

    axons_quart=[int(N_models/4.0),int(2*N_models/4.0),int(3*N_models/4.0)]

    # run NEURON simulation in parallel
    while Neuron_index<N_models:
        proc=[]
        j_proc=0 #counter for processes
        output=mp.Queue()
        while j_proc<n_processors and Neuron_index<N_models:
            first_axon_point=np.array([Vert[Neuron_index*n_segments,0],Vert[Neuron_index*n_segments,1],Vert[Neuron_index*n_segments,2]])
            second_axon_point=np.array([Vert[Neuron_index*n_segments+1,0],Vert[Neuron_index*n_segments+1,1],Vert[Neuron_index*n_segments+1,2]])
            last_axon_point=np.array([Vert[Neuron_index*n_segments+n_segments-1,0],Vert[Neuron_index*n_segments+n_segments-1,1],Vert[Neuron_index*n_segments+n_segments-1,2]])

            inx_first=np.flatnonzero((Vert_full == first_axon_point).all(1)) # Finally get indices
            inx_second=np.flatnonzero((Vert_full == second_axon_point).all(1)) # Finally get indices
            inx_last=np.flatnonzero((Vert_full == last_axon_point).all(1)) # Finally get indices

            #assuming we do not have axons that start (first two points) and end in the same points
            for j in inx_first:
                for j_second in inx_second:
                    if j_second-j==1:
                        for j_last in inx_last:
                            if j_last-j==n_segments-1:
                                inx_first_true=j
                                break

            neuron_global_index_array[Neuron_index]=int(inx_first_true/n_segments) #index in Prepared_models_full

            processes=mp.Process(target=conduct_parallel_NEURON,args=(population_name,last_point,neuron_global_index_array[Neuron_index],Neuron_index,Ampl_scale,t_steps_trunc,n_segments,dt,tstop,n_pulse,d['v_init'],output))
            proc.append(processes)

            j_proc=j_proc+1
            Neuron_index=Neuron_index+1
            
            if N_models>500 and Neuron_index in axons_quart:
                logging.critical("{}% of neuron models were processed".format(int(Neuron_index*100/N_models)+1))
            
        for p in proc:
            p.start()
        for p in proc:
            p.join()

        #returns list, where activated models have corresponding numbers, others have -1
        Activated_numbers = [output.get() for p in proc]

        for n_mdls in Activated_numbers:            #n_mdls is list[N_glob,N_loc]!
            if n_mdls[1]!=-1:
                Nodes_status[n_segments*n_mdls[1]:(n_segments*n_mdls[1]+n_segments),3]=1.0
                Activated_models=Activated_models+1
                List_of_activated.append(n_mdls[0])
            else:
                List_of_not_activated.append(int(n_mdls[0]))

            int_counter=int_counter+1

    Number_of_axons_initially=int(Vert_full.shape[0]/n_segments)
    Vert_full_status=np.zeros(Number_of_axons_initially,int)            # has status of all neurons (-1 - was not placed, 0 - was not activated, 1 - was activated)

    # num_removed=0
    # for axon_i in range(Number_of_axons_initially):
    #     if axon_i in List_of_activated:
    #         Vert_full_status[axon_i]=1
    #     elif axon_i in List_of_not_activated:
    #         Vert_full_status[axon_i]=0
    #     else:
    #         Vert_full_status[axon_i]=-1     #was removed
    #         num_removed=num_removed+1

    Axon_status=np.zeros((N_models,7),float)      #x1,y1,z1,x2,y2,z2,status. Holds info only about placed neurons. Important: coordinates are in the initial MRI space!

    [Mx_mri,My_mri,Mz_mri,x_min,y_min,z_min,x_max,y_max,z_max,MRI_voxel_size_x,MRI_voxel_size_y,MRI_voxel_size_z]=np.genfromtxt(os.environ['PATIENTDIR']+'/MRI_DTI_derived_data/MRI_misc.csv', delimiter=' ')
    shift_to_MRI_space=np.array([x_min,y_min,z_min])

    Axon_Lead_DBS=np.zeros((Number_of_axons_initially*n_segments,5),float)
    num_removed=0

    for axon_i in range(Number_of_axons_initially):
        Axon_Lead_DBS[axon_i*n_segments:n_segments*(axon_i+1),:3]=Vert_full[axon_i*n_segments:n_segments*(axon_i+1),:3]+shift_to_MRI_space
        Axon_Lead_DBS[axon_i*n_segments:n_segments*(axon_i+1),3]=axon_i+1   # because Lead-DBS number them from 1
        if axon_i in List_of_activated:
            Vert_full_status[axon_i]=1
            Axon_Lead_DBS[axon_i*n_segments:n_segments*(axon_i+1),4]=1
        elif axon_i in List_of_not_activated:
            Vert_full_status[axon_i]=0
            Axon_Lead_DBS[axon_i*n_segments:n_segments*(axon_i+1),4]=0
        else:
            
            # check if axon_i is in the list
            if axon_i in neuron_encap:
                Vert_full_status[axon_i] = -1     # intersected with the electrode / encap
                Axon_Lead_DBS[axon_i*n_segments:n_segments*(axon_i+1),4] = -1
            elif axon_i in neuron_csf:
                Vert_full_status[axon_i] = -2     # traversed CSF
                Axon_Lead_DBS[axon_i*n_segments:n_segments*(axon_i+1),4] = -2
            else:
                Vert_full_status[axon_i] = -3     # outside of the domain/ lost?
                Axon_Lead_DBS[axon_i*n_segments:n_segments*(axon_i+1),4] = -3
            
            num_removed=num_removed+1


    from scipy.io import savemat
    mdic = {"fibers": Axon_Lead_DBS, "ea_fibformat": "1.0"}
    if population_index==-1:            # only one population is simulated
        if d['Stim_side']==0:
            savemat(os.environ['PATIENTDIR']+"/Results_rh/Axon_state.mat", mdic)
        else:
            savemat(os.environ['PATIENTDIR']+"/Results_lh/Axon_state.mat", mdic)
    else:
        if d['Stim_side']==0:
            savemat(os.environ['PATIENTDIR']+"/Results_rh/Axon_state_"+str(lst[population_index])+".mat", mdic)
        else:
            savemat(os.environ['PATIENTDIR']+"/Results_lh/Axon_state_"+str(lst[population_index])+".mat", mdic)

    loc_ind_start=0
    for i in range(N_models):
        Axon_status[i,:3]=Nodes_status[loc_ind_start,:3]+shift_to_MRI_space
        Axon_status[i,3:6]=Nodes_status[loc_ind_start+n_segments-1,:3]+shift_to_MRI_space
        Axon_status[i,6]=Nodes_status[loc_ind_start,3]
        loc_ind_start=loc_ind_start+n_segments

    #for Lead-DBS for visualization purposes
    Nodes_status_MRI_space=np.zeros((N_models*n_segments,4),float)
    Nodes_status_MRI_space[:,:3]=Nodes_status[:,:3]+shift_to_MRI_space
    Nodes_status_MRI_space[:,3]=Nodes_status[:,3]

    logging.critical("{} models were activated".format(Activated_models))

    List_of_activated=np.asarray(List_of_activated)

    Nodes_status_MRI_space_only_activated=np.delete(Nodes_status_MRI_space, np.where(Nodes_status_MRI_space[:,3] == 0.0)[0], axis=0)

#    if neuron_array_name==None:
#        hf = h5py.File('Field_solutions/Activation/VAT_Neuron_array.h5', 'a')
#        hf.create_dataset('VAT_Neuron_array_'+str(Activated_models), data=Nodes_status_MRI_space_only_activated)
#        hf.close()
#    else:
#        hf = h5py.File('Field_solutions/Activation/Activation_in_'+neuron_array_name[:-3]+'.h5', 'a')
#        hf.create_dataset(str(lst[population_index])+'_'+str(Activated_models), data=Nodes_status_MRI_space_only_activated)
#        hf.close()

    # Simple way to check activations (only those that were not exluded by Kuncel-VTA)
    Summary_status = np.zeros(5,float)    # Activated, non-activated , 'damaged'
    Summary_status[0] = len(List_of_activated)
    Summary_status[1] = len(List_of_not_activated)
    Summary_status[2] = len(neuron_encap)
    Summary_status[3] = len(neuron_csf)
    Summary_status[4] = Number_of_axons_initially-np.sum(Summary_status[:4])

    if population_index != -1:
        hf = h5py.File(os.environ['PATIENTDIR'] + '/' + stim_folder + 'Summary_status.h5', 'a')
        hf.create_dataset(str(lst[population_index]), data=Summary_status)
        hf.close()
    else:
        np.savetxt(os.environ['PATIENTDIR'] + '/' + stim_folder + 'Summary_status.csv', Summary_status, delimiter=" ")

    if population_index==-1:
        logging.critical("{}% activation (including damaged neurons)\n".format(np.round(Activated_models/float(Number_of_axons_initially)*100,2)))
        #np.savetxt(os.environ['PATIENTDIR']+'/Field_solutions/Activation/Last_run.csv', List_of_activated, delimiter=" ")
        np.savetxt(os.environ['PATIENTDIR']+'/'+stim_folder+'Last_run.csv', List_of_activated, delimiter=" ")
        np.save(os.environ['PATIENTDIR']+'/'+stim_folder+'Connection_status',Axon_status)
        #np.save(os.environ['PATIENTDIR']+'/'+stim_folder+'Network_status',Vert_full_status)
        np.savetxt(os.environ['PATIENTDIR']+'/'+stim_folder+'Neurons_status.csv', Vert_full_status, delimiter=" ")  #Ningfei prefers .csv
        np.savetxt(os.environ['PATIENTDIR']+'/'+stim_folder+'Activation_VAT_Neuron_Array_'+str(Activated_models)+'.csv', Nodes_status_MRI_space_only_activated, delimiter=" ")


    else:
        logging.critical("{}% activation in {} (including damaged neurons)\n".format(np.round(Activated_models/float(Number_of_axons_initially)*100,2),lst[population_index]))
        np.savetxt(os.environ['PATIENTDIR']+'/'+stim_folder+'Last_run_in_'+str(lst[population_index])+'.csv', List_of_activated, delimiter=" ")
        np.save(os.environ['PATIENTDIR']+'/'+stim_folder+'Connection_status_'+str(lst[population_index]),Axon_status)
        np.savetxt(os.environ['PATIENTDIR']+'/'+stim_folder+'Activation_'+neuron_array_name[:-3]+'___'+str(lst[population_index])+'_'+str(Activated_models)+'.csv', Nodes_status_MRI_space_only_activated, delimiter=" ")

        hf = h5py.File(os.environ['PATIENTDIR']+'/'+stim_folder+'Neurons_status.h5', 'a')
        hf.create_dataset(str(lst[population_index]), data=Vert_full_status)
        hf.close()

    return Activated_models

