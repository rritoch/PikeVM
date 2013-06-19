Title: Pike Virtual Machine
Version: Pre-release
Author: Ralph Ritoch <rritoch@gmail.com>
Company: VNetPublishing - http://www.vnetpublishing.com 
Content-type: text/plain
Source: https://github.com/rritoch/PikeVM/
Copyright:  Ralph Ritoch 2009 - 2013 ALL RIGHTS RESERVED
Licence: http://www.vnetpublishing.com/Legal/Licenses/2010/10/vnetlpl.txt

The pike VirtualMachine is a pike language Sandbox environment. Much of the
core functionality of the master object has been moved into a kernel object. 
This makes it possible to modify core functionality without needing to restart 
the machine. The system has also been designed to make it possible to protect 
all core functionality from applications running in the virtual machine. With 
modifications to the kernel and security system system operators should be able 
to restrict access and override all core functions and objects.  
 
To get started you will first need to install and configure the machine. 

Pre-requisites:

  Requires Pike version 7.8 or above which can be downloaded 
  from http://pike.lysator.liu.se/download/

Installation:

1. Download and extract pike virtual machine to your preferred location
2. Copy example configuration file in root\boot\system-1.0\kernel.conf.example
 to root\boot\system-1.0\kernel.conf
3. Edit the kernel configuration file to match your preferences
4. The machine was configured by default for Windows 7, 64 bit. Defines in
the master object () may need to be changed to match your machine type.

Starting the Machine:

If you are on windows you can start the virtual machine using the
batch file located at "root\boot\start.bat". Otherwise it can be started
using the following command.

pike -m <path_to_master> <path_to_system>

Example: If Sources are installed in /opt/PikeVM

pike -m /opt/PikeVM/root/boot/master-1.0.pike /opt/PikeVM/root/boot/system-1.0


Contributions:

This project is maintained at https://github.com/rritoch/PikeVM/ .  If you are
interested in contributing to this project please email rritoch@gmail.com.     