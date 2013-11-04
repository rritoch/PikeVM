* Title: Pike Virtual Machine
* Version: 1.1 (Alpha)
* Author: Ralph Ritoch <rritoch@gmail.com>
* Company: VNetPublishing - http://www.vnetpublishing.com 
* Content-type: text/plain
* Source: https://github.com/rritoch/PikeVM/
* Copyright:  Ralph Ritoch 2009 - 2013 ALL RIGHTS RESERVED
* Licence: http://www.vnetpublishing.com/Legal/Licenses/2010/10/vnetlpl.txt

The pike VirtualMachine is a pike language Sandbox environment. Much of the
core functionality of the master object has been moved into a kernel object 
which makes it possible to modify core functionality without needing to restart 
the machine. The system has also been designed to make it possible to protect 
all core functionality from applications running in the virtual machine. With 
modifications to the kernel and security system system operators should be able 
to restrict access and override all core functions and objects.  
 
To get started you will first need to install and configure the machine. 

Pre-requisites:

  Requires Pike version 7.8 or above which can be downloaded 
  from http://pike.lysator.liu.se/download/

###Installation:

1. Download and extract pike virtual machine to your preferred location
2. Copy example configuration file in root\boot\system-1.1\kernel.conf.example
 to root\boot\system-1.1\kernel.conf
3. Edit the kernel configuration file to match your preferences
4. The machine was configured by default for Windows 7, 64 bit. Command line 
arguments can be used to match your platform.

### Installation Notes:

The following environment settings are evaluated by PikeVM to locate Pike

* PIKE_INCLUDE_PATH - Path to pike distribution includes, can also be set in command line argument -I
* PIKE_MODULE_PATH - Path to pike distribution includes modules, can also be set in command line argument -M
* PIKE_PROGRAM_PATH - Default search path for pike files, can also be set in command line argument -P



Starting the Machine:

If you are on windows you can start the virtual machine using the
batch file located at "root\boot\start.bat" or on linux a shell script is located at "root\boot\start.sh". 
These scripts may need to be edited to match your platform, otherwise it can be started
using the following command.

pike -m &#60;path_to_master&#62; &#60;path_to_system&#62; [-I &#60;pike_includes&#62;] [-M &#60;pike_modules&#62;]

Example: If Sources are installed in /opt/PikeVM

```
pike -m /opt/PikeVM/root/boot/master-1.1.pike /opt/PikeVM/root/boot/system-1.1 -I "C:\Program Files\Pike\lib\include" -M C:\Program Files\Pike\lib\modules
```

Note: At the login prompt enter any username and follow the prompts for a user account to be created. Raw pike 
commands can be entered at the command line using the at "@" prefix. 

Ex.
  @ write("Hello World!")

### Features:

System V style init scripts
POSIX virtualization
Console shell
Web Server
FTP Server
Telnet Server

Contributions:

This project is maintained at https://github.com/rritoch/PikeVM/ .  If you are
interested in contributing to this project please email rritoch@gmail.com.     
