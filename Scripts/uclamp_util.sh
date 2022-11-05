#!/bin/bash

# EAS uclamp_util cgroups setup
#
# The idea here is to partition tasks into cgroups, where we can then boost, clamp
# and mark tasks as being latency.senstive (latency biasing). ie: performing some
# cpu scheduling hygiene on RT and FAIR tasks. 
#
# This should help improve performance for some tasks, while pushing less
# important tasks out of the way.
#
# The other motivation is to improve energy efficiency. 
#
# The cgroups are as follows:
#
# LOW_LATENCY_TASKS
# GUI_TASKS
# FG_TASKS
# BG_TASKS
# IDLE_TASKS

# cut cpu migration of (other) tasks, favour rt task performance / low latency.
echo -e ""
echo -e "\e[1;32mecho 8 > /proc/sys/kernel/sched_nr_migrate"
echo 8 > /proc/sys/kernel/sched_nr_migrate
# this may screw with energy aware task placement. no idea how to test it.
# but I suspect it's worth the possible tradeoffs

echo -e "\e[1;34m"
echo -e "\e[1;34m---------------------------------------------------------"
echo -e "\e[1;92mcreate cpu,cpuset cgroups for uclmap_util buckets"
echo -e "\e[1;34m---------------------------------------------------------"
echo -e "\e[1;37m"

# Create all cgroups (no more than 5, that how many buckets there are)
cgcreate -a ninez -t ninez -g cpu:low_latency_tasks
echo -e "\e[1;31m/sys/fs/cgroup/low_latency_tasks created"
cgcreate -a ninez -t ninez -g cpu:gui_tasks
echo -e "\e[1;31m/sys/fs/cgroup/gui_tasks created"
cgcreate -a ninez -t ninez -g cpu:fg_tasks
echo -e "\e[1;31m/sys/fs/cgroup/fg_tasks created"
cgcreate -a ninez -t ninez -g cpu:bg_tasks
echo -e "\e[1;31m/sys/fs/cgroup/bg_tasks created"
cgcreate -a ninez -t ninez -g cpu:idle_tasks
echo -e "\e[1;31m/sys/fs/cgroup/idle_tasks created"
cgcreate -a ninez -t ninez -g cpuset:low_latency_tasks
echo -e "\e[1;31m/sys/fs/cgroup/low_latency_tasks created"
cgcreate -a ninez -t ninez -g cpuset:gui_tasks
echo -e "\e[1;31m/sys/fs/cgroup/gui_tasks created"
cgcreate -a ninez -t ninez -g cpuset:fg_tasks
echo -e "\e[1;31m/sys/fs/cgroup/fg_tasks created"
cgcreate -a ninez -t ninez -g cpuset:bg_tasks
echo -e "\e[1;31m/sys/fs/cgroup/bg_tasks created"
cgcreate -a ninez -t ninez -g cpuset:idle_tasks
echo -e "\e[1;31m/sys/fs/cgroup/idle_tasks created"

#################################
# Make CPUSET sysfs writeable ###
#################################

# no heavy partitioning, as we don't want to restrict the groups to cpu
# cores/threads tightly. it will result in more overhead poorer perfrormance
# and energy-saving.
#
# That said, restrict bg_tasks and idle_tasks to 0-1 cores/threads

# set cpuset.cpus
echo 0-7 > '/sys/fs/cgroup/low_latency_tasks.cpus'
echo 0-7 > '/sys/fs/cgroup/gui_tasks.cpus'
echo 0-7 > '/sys/fs/cgroup/fg_tasks.cpus'
echo 0-3 > '/sys/fs/cgroup/bg_tasks.cpus'
echo 6-7 > '/sys/fs/cgroup/idle_tasks.cpus'
#set cpuset.mems
echo 0 >'/sys/fs/cgroup/low_latency_tasks.mems'
echo 0 >'/sys/fs/cgroup/gui_tasks.mems'
echo 0 >'/sys/fs/cgroup/fg_tasks.mems'
echo 0 >'/sys/fs/cgroup/bg_tasks.mems'
echo 0 >'/sys/fs/cgroup/idle_tasks.mems'
# now they are writeable ( ie: we can move PIDs into ../<groupname>/tasks).

echo -e ""
echo -e "\e[1;92mcpusets made writeable"

#################################
### LOW_LATENCY_TASKS cgroups ###
#################################

# Settings for low_latency_tasks CPU cgroup
echo max > '/sys/fs/cgroup/low_latency_tasks.uclamp.max'
# set cpu.uclamp.min, so that uclamp_boosted() returns 'true'
echo 1.00 > '/sys/fs/cgroup/low_latency_tasks.uclamp.min'
echo 950000 > '/sys/fs/cgroup/low_latency_tasks.rt_period_us'
echo 1 > '/sys/fs/cgroup/low_latency_tasks.uclamp.latency_sensitive'
# Setting for low_latency_tasks CPUSET cgroup
# use cgroup.clone.children - so we can grab up the children and keep them as
# low_latency_tasks, with their parents.
echo 1 > '/sys/fs/cgroup/low_latency_tasks/cgroup.clone_children'   

# Since we are clamping / boosting, be careful to only add tasks - it's probably best
# to add them manually - like I do with Jackd, Reaper, etc. Otherwise we risk wasting
# a lot of energy, due to high cpu-frequencies (cpu.uclamp.min = 70%)
#
# for low_latency_tasks, we want to avoid cpu-frequencies dropping - as it will
# hurt performance and in the case of jackd - could introduce buffer underruns.
#
# example below:

echo -e "\e[1;34m---------------------------------------------------------"
echo -e "\e[1;92mmove tasks to LOW_LATENCY_TASKS cgroups"
echo -e "\e[1;34m---------------------------------------------------------"

# Find PIDs, move tasks to CPU cgroup
for pid in $(pgrep pulse); do echo $pid > /sys/fs/cgroup/low_latency_tasks/tasks; done
# Find PIDs, move tasks to CPUSET cgroup
for pid in $(pgrep pulse); do echo $pid > /sys/fs/cgroup/low_latency_tasks/tasks; done

echo -e "\e[1;31mPulseaudio moved to LOW_LATENCY_TASKS"
echo -e "\e[1;31mall children will be cloned, as well"

#########################
### GUI_TASKS cgroups ###
#########################

# Settings for gui_tasks CPU cgroup
echo 95.00 > '/sys/fs/cgroup/gui_tasks.uclamp.max'
# set cpu.uclamp.min, so that uclamp_boosted() returns 'true'
echo 1.00 > '/sys/fs/cgroup/gui_tasks.uclamp.min'
echo 900000 > '/sys/fs/cgroup/gui_tasks.rt_period_us'
echo 1 > '/sys/fs/cgroup/gui_tasks.uclamp.latency_sensitive'
# Setting for gui_tasks CPUSET cgroup
# don't use cgroup.clone.children -- it drags in processes we don't want in gui_tasks
# instead, just whitelist PIDs we actually want. 
echo 0 > '/sys/fs/cgroup/gui_tasks/cgroup.clone_children'

# Be careful and very selective in what PIDs get to be in this group, being as
# we are using clamping/boosting + latency.sensitive. 

echo -e "\e[1;34m---------------------------------------------------------"
echo -e "\e[1;92mmove tasks to GUI_TASKS cgroups"
echo -e "\e[1;34m---------------------------------------------------------"

# Find PIDs, move tasks to CPU cgroup
for pid in $(pgrep Xorg); do echo $pid > /sys/fs/cgroup/gui_tasks/tasks; done
for pid in $(pgrep gnome-shell); do echo $pid > /sys/fs/cgroup/gui_tasks/tasks; done
for pid in $(pgrep easystroke); do echo $pid > /sys/fs/cgroup/gui_tasks/tasks; done
for pid in $(pgrep onboard); do echo $pid > /sys/fs/cgroup/gui_tasks/tasks; done
# Find PIDs, move tasks to CPUSET cgroup
for pid in $(pgrep Xorg); do echo $pid > /sys/fs/cgroup/gui_tasks/tasks; done
for pid in $(pgrep gnome-shell); do echo $pid > /sys/fs/cgroup/gui_tasks/tasks; done
for pid in $(pgrep easystroke); do echo $pid > /sys/fs/cgroup/gui_tasks/tasks; done
for pid in $(pgrep onboard); do echo $pid > /sys/fs/cgroup/gui_tasks/tasks; done

echo -e "\e[1;31mmoved Xorg, Gnome-Shell, EasyStroke and Onboard to GUI_TASKS"
echo -e "\e[1;31mall children will NOT be cloned!"

########################
### FG_TASKS cgroups ###
########################

# Settings for fg_tasks CPU cgroup
echo 75.00 > '/sys/fs/cgroup/fg_tasks.uclamp.max'
echo 800000 > '/sys/fs/cgroup/fg_tasks.rt_period_us'
echo 0 > '/sys/fs/cgroup/fg_tasks.uclamp.latency_sensitive'
# Setting for fg_tasks CPUSET cgroup
# cgroup.clone.children - this should be save here, we aren't boosting, nor using 
# latency.sensitive tasks.
echo 1 > '/sys/fs/cgroup/fg_tasks/cgroup.clone_children'   

echo -e "\e[1;34m---------------------------------------------------------"
echo -e "\e[1;92mmove tasks to FG_TASKS cgroups"
echo -e "\e[1;34m---------------------------------------------------------"

# Find PIDs, move tasks to CPU cgroup
for pid in $(pgrep nautilus); do echo $pid > /sys/fs/cgroup/fg_tasks/tasks; done
for pid in $(pgrep bash); do echo $pid > /sys/fs/cgroup/fg_tasks/tasks; done
for pid in $(pgrep gnome-terminal); do echo $pid > /sys/fs/cgroup/fg_tasks/tasks; done
# Find PIDs, move tasks to CPUSET cgroup
for pid in $(pgrep nautilus); do echo $pid > /sys/fs/cgroup/fg_tasks/tasks; done
for pid in $(pgrep bash); do echo $pid > /sys/fs/cgroup/fg_tasks/tasks; done
for pid in $(pgrep gnome-terminal); do echo $pid > /sys/fs/cgroup/fg_tasks/tasks; done

echo -e "\e[1;31mmoved Nautilus, Bash and gnome-terminal to FG_TASKS"
echo -e "\e[1;31mall children will be cloned, as well"

########################
### BG_TASKS cgroups ###
########################

# Settings for bg_tasks CPU cgroup
echo 30.00 > '/sys/fs/cgroup/bg_tasks.uclamp.max'
echo 400000 > '/sys/fs/cgroup/bg_tasks.rt_period_us'
echo 0 > '/sys/fs/cgroup/bg_tasks.uclamp.latency_sensitive'
# Setting for bg_tasks CPUSET cgroup
# use cgroup.clone.children - so we can grab up the children and keep them in
# the background, as well.
echo 1 > '/sys/fs/cgroup/bg_tasks/cgroup.clone_children'   

echo -e "\e[1;34m---------------------------------------------------------"
echo -e "\e[1;92mmove tasks to BG_TASKS cgroups"
echo -e "\e[1;34m---------------------------------------------------------"

# Find PIDs, move tasks to CPU cgroup
for pid in $(pgrep gsd-); do echo $pid > /sys/fs/cgroup/bg_tasks/tasks; done
for pid in $(pgrep gvfs-); do echo $pid > /sys/fs/cgroup/bg_tasks/tasks; done
# Find PIDs, move tasks to CPUSET cgroup
for pid in $(pgrep gsd-); do echo $pid > /sys/fs/cgroup/bg_tasks/tasks; done
for pid in $(pgrep gvfs-); do echo $pid > /sys/fs/cgroup/bg_tasks/tasks; done

echo -e "\e[1;31mmoved gsd-* + gvfs-* tasks to BG_TASKS"
echo -e "\e[1;31mall children will be cloned, as well"

##########################
### IDLE_TASKS cgroups ###
##########################

# Settings for idle_tasks CPU cgroup
echo 15.00 > '/sys/fs/cgroup/idle_tasks.uclamp.max'
echo 200000 > '/sys/fs/cgroup/idle_tasks.rt_period_us'
echo 0 > '/sys/fs/cgroup/idle_tasks.uclamp.latency_sensitive'
# Setting for idle_tasks CPUSET cgroup
# use cgroup.clone.children - so we can grab up the children and keep them in
# as idle_tasks, as well.
echo 1 > '/sys/fs/cgroup/idle_tasks/cgroup.clone_children'   

echo -e "\e[1;34m---------------------------------------------------------"
echo -e "\e[1;92mmove tasks to IDLE_TASKS cgroups"
echo -e "\e[1;34m---------------------------------------------------------"

# Find PIDs, move tasks to CPU cgroup
for pid in $(pgrep zeitgeist-); do echo $pid > /sys/fs/cgroup/idle_tasks/tasks; done
for pid in $(pgrep evolution-); do echo $pid > /sys/fs/cgroup/idle_tasks/tasks; done
for pid in $(pgrep goa-); do echo $pid > /sys/fs/cgroup/idle_tasks/tasks; done
# Find PIDs, move tasks to CPUSET cgroup
for pid in $(pgrep zeitgeist-); do echo $pid > /sys/fs/cgroup/idle_tasks/tasks; done
for pid in $(pgrep evolution-); do echo $pid > /sys/fs/cgroup/idle_tasks/tasks; done
for pid in $(pgrep goa-); do echo $pid > /sys/fs/cgroup/idle_tasks/tasks; done

echo -e "\e[1;31mmoved zeitgeist-*, evolution-* and goa-* tasks to IDLE_TASKS"
echo -e "\e[1;31mall children will be cloned, as well"

echo -e "\e[1;31muclamp_util.sh completed"
echo -e "\e[1;37m"
