This project contains some of the scripts and functions we use within the 
VMware Hands-on Labs (http://labs.hol.vmware.com) to manage our mini-datacenters:

LabStartup is the sleketon we provide to our teams for testing the readiness of
their environments for use by the users. The script can query and restart services,
startup virtual machines and vApps, reports detailed status into a logfile, and 
summary progress to the user with DesktopInfo http://www.glenn.delahoy.com/software/

The SSL module is still pretty rough but is used by the lab teams to request and 
issue certificates for the solutions deployed within our lab environments. We have
a Microsoft CA deployed on Controlcenter (CONTROLCENTER-CA). To save resources in 
the lab, we do not have the Microsoft CA web interface enabled, so we use Powershell
to handle the processing. 

The management scripts are some of the tools we use to configure the ESXi hosts and
vCenter servers within the vPods.

The ModuleSwitcher is a simple panel we use to call Start and Stop scripts to
allow users to "fast forward" their lab environments to defined checkpoints within
the environment -- we call these module boundaries because they map to the states
expected by the various sections of our manuals.
