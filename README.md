# biostat@UCPH HPC facilities

biostat@UCPH has access to a small linux computing cluster consisting of two servers:

* **cox** (official name: `biostatcomp01fl`) 
* **rao** (official name: `biostatcomp02fl`) 

Each server has 128 cores and 512 GB of memory. The cluster is suitable for simulations 
and other parallel computing tasks. 

If you submit a job to the cluster you are thus capable of running 256 calculations
simulataneously (see the section later about jobs with a long execution time).

In order to avoid that multiple users disturb each others computations and to
ensure a fair allocation of our ressources, all computing tasks **have** to be 
started using the [Slurm Workload Manager](https://slurm.schedmd.com/documentation.html).

Since the documentation is quite rich, we provide below the minimum level of examples.

Questions and help requests should be posed to those who have tried
before. You can also get write access to this github repository and
share your experience and examples.

## Important ground rules

1) It is **not** allowed to run R interactively on the servers *expect*
when you need to install R packages for subsequent use by jobs
submitted to the scheduler. You can do that by starting up R
interactively in a terminal on either cox and rao and installing the
packages as usual.

2) Do **not** run jobs that are using `mclapply` or similar features
from the `parallel` packages, as you are then going behind the scenes
of the schedular and messing up the ressource allocation. You should
write your script as a single job and then let the scheduler handle
the parallelization - se example later.

3) You should be **aware** that some R packages will automatically 
spawn a lot of threads even though you're only executing a single job.
This is e.g., the case for the keras packages and other stuff depending
on TensorFlow and numpy in Python. **[TODO: We are still trying to understand how this works]**


# Usage

## Connect to a server

Connect to the UCPH domain through a VPN connection unless you are at work 
(CSS) and use a connection with a cable in the wall. On linux, macOS and 
Windows you can connect from terminal using ssh, e.g.,

```
ssh abc123@cox
```

where abc123 should be your KU id and you'll then be prompted for your KU password. 
If you have a KU-computer (Windows or macOS) you only need to execute `ssh cox`, as it automatically recognizes you.

Previously Windows users connected through Putty, but that is no longer recommended, as

1) Windows nowadays has an ssh client build-in
2) Putty requires certain changes to its standard configuration in order to authenticate correctly with the SMB network drives. 

If you **really** want to use Putty, contact AKJ and he knows a solution.

## Getting comfortable

### Network drives

When you log on to the servers you be at your home directory `~`. From there you have access to

* `~/ucph/hdir`: your personal (SMB) drive (previously P-drive). This is accessible across all platforms (Windows, macOS, linux).
* `~/ucph/groupdir`: common (SMB) drives shared across the section (SUN-IFSV-BioStat) and the department (SUN-IFSV-ALLE) - previously O/Q-drives.
* `/projects/biostat01`: an NFS drive only available on the servers.

If you're *not* a Windows user, it is *highly recommended* that you put all your files under `/projects/biostat01/people/abc1234` where `abc1234` is your username. If you're a macOS user there also exists a solution where you can locally mount `/projects` using `sshfs`.

**Note**: It is not recommended to run your parallelized jobs with Slurm under `~/ucph/hdir` as you might experience issues with Slurm incorrectly forwarding Kerberos tickets for the SMB protocol. Instead, run your jobs under `/projects/biostat01/people/abc1234` where `abc1234` is your KU user id.

**Note**: `~` has a quota of 10 GB, so it's not suitable for storing large amounts of data or simulation results. Use `~/ucph/hdir` or `/projects/biostat01/people/abc123` instead.

All network drives have a standard 90 days UCPH backup policy.

### Software

When you log on there will not be any software available, but you need to enable it yourself.
To see a list of the software available on the servers you can execute

```
module avail
```

Most users would probably like to use the latest version of R and the version of gcc
which it depends on. Therefore, in order to use R you need to load the following 2 modules:

```
module load gcc/11.2.0
module load R/4.1.2
```

**Protip:** If you want this to be performed automatically every time you log on to any of servers,
you can add the following line to your `~/.bash_profile` file

```
module load gcc/11.2.0 R/4.1.2
```

This is very convenient and highly recommended as you then don't need to specifically loading this software
when submitting job to the scheduler further on.

**Protip**: KU-IT will automatically make new R versions available when they're released. If you have something
automatically loaded in `~/.bash_profile` you need to change it yourself when a new version becomes available.


### R packages

Ensure that all R packages that your program needs are installed on
the server. There are no packages automatically available for you.
To install a package, you can start R interactively and use `install.packages()` as usual. 

## Setting up your job

The way the scheduler works is that you only need to think about writing your code as it would work on a *single* data set. 
When you then submit your code as a job to the scheduler, it will automatically distribute it independently across the cluster in as many instances as you specify.

You should have your computation task prepared:

1. A file with code that should be run repeatedly (in parallel) and every time it is run does the following:
   * controls the random seed if necessary
   * reads in data, or simulates data
   * runs the analysis (important: each analysis should only use a single computation core and not parallelize!) 
   * saves the results in a result file which should have a task specific filename
2. A terminal command-line command started with `sbatch` or by bash script file which is then run from the terminal using `sbatch`.
3. A program that collects the results from the parallel analyses.

## Executing a job

The following commands are used to communicate with the Slurm scheduler and are probably the only ones that you will need.

* ```squeue``` - view information about jobs located in the Slurm scheduler
* ```scancel``` - cancel a job running on Slurm
* ```sbatch``` - submit a job to Slurm
* ```sinfo``` - see the state of the cluster (idle and mix are good. drng or anything else is bad: Contact AKJ)

## Examples

### An example of R
Consider a simple R program like the following where we generate some random
data and estimate a parameter

```
x <- rnorm(1000)
mean(x)
```

To run this program 100 times in parallel with different random seeds we use
an R code file which we call `mySim.R` and which has the following
contents consisting of a header that controls the randomness following by the code of what 
you actually wish to calculate.

```
#This is the total number of jobs that you told Slurm to execute
number_of_tasks <- as.numeric(Sys.getenv("SLURM_ARRAY_TASK_COUNT"))
#This is an index specific for each job running in parallel
task_id <- as.numeric(Sys.getenv("SLURM_ARRAY_TASK_ID"))

# Set a reproducible random seed for your simulations
set.seed(123457890)
# Generate a large number of random seeds to be assigned to each task
seeds <- sample(1:10^6, size = number_of_tasks, replace = FALSE)
# Assign the randomly generated seed to the current task
set.seed(seeds[task_id])

# ---------- Your personal R code goes between these lines ----------
x <- rnorm(1000)
result <- mean(x)
# -------------------------------------------------------------------

# Save the results for this task as an individual file in the output folder
save(result, file = paste0('mySim-res-', sprintf("%05d", task_id), '.RData')
```

Then, execute the following command

```
sbatch -J "mySim" -o mySim-stdout-%a.txt --array=1-100 --wrap="Rscript mySim.R"
```

Then the standard output for each job will be saved as `mySim-stdout-1.txt`, ..., `mySim-stdout-100.txt`, and the results of the computations will be saved as the files `mySim-res-00001.RData`, ..., `mySim-res-00100.RData`.

**TODO**: Will there still be issues with `--no-save --no-restore` when using `Rscript` like the above compared to `R CMD BATCH`?

To get more flexibility and requirement of the execution, you can also specify your job in a Slurm script. See e.g., [slurm examples](https://computing.sas.upenn.edu/gpc/job/slurm) for examples and more options.

After you have submitted your job, you'll see something like this in the terminal
```
Submitted batch job 312191
```
where the number is the ID of your job.

To check if your job is actually running, you can execute `squeue` and you'll see a list of all running and scheduled jobs.

If you wish to cancel a job that is either currently running or is in the queue, you can run `scancel xxxxxx` where `xxxxxx` is the job's ID number. You can of course only cancel jobs submitted by yourself.

Note, that it can take a little while for running job to be fully canceled. Check by executing `squeue`.


## Jobs with a long runtime

The scheduler is configured with two queues (called partitions in Slurm lingo): a `standard` partition running on both cox and rao, and a `long` partition running only on rao. The difference between the two is that jobs taking longer than four hours (not in total but for each individual job you're running) will automatically be killed in the `standard` partition, whereas jobs can run infinitely long in the `long` partition. If you don't specify anything, you are automatically using the `standard` partition. 

To submit a job to the `long` paratition, you need to add the following to your sbatch command `--partition=long`.

# Using `screen` with the software modules

If you for some reason wish to use `screen` as a virtual terminal/multiplexer on the servers, you should be aware that software loaded with `module load` will not immediately be available in your `screen` sessions. There is an easy solution for this. After you start your `screen` session, you can run `module reload` and all your loaded software will be available in that screen session.


# Linux terminal servers

biostat@UCPH also have two additional servers

* **doob** (official name: `biostatcomp03fl`) 
* **rasch** (official name: `biostatcomp04fl`)
 
These are virtual servers with only six cores and a limited amount of memory (12 GB). These servers are **not** meant to be used for high performance computing but rather as traditional terminal servers, which you can use for e.g. accessing the network drives, synchronizing files, compiling LaTeX or other stuff.

## LaTeX on doob and rasch

LaTeX can be loaded as a software module on by running `module load texlive/2021` and .tex files can then be compiled by running `pdflatex`.

## SAS on doob and rasch

To load SAS 9.4 on the servers you must run
```
module load openjdk/13.0.1 sas/9.4
```

The SAS executable is called `sas_en`.

There is no graphical user interface available, so you can either run SAS in batch mode or in interactive line mode by running `sas_en -nodms`.
