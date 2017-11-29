/*
| This document describes the error manager used by NHS CFH
| Created by: Duncan Lucas
| Created on: 14/05/2009
|
|

Custom Error Manager (using Quest error manger )
================================================

This document describes the installation and use of the PKG_ERROR_MANAGER.
This package can be used in your application for both tracing and error handling. It uses the QUEST error manager functionality however with a few minor changes to ensure it works correctly for our usage.

The VSS folder includes the qem.zip file containing the quest code but also it contains the minor changes in updated versions of some of the Quest files namely:

	q$error_manager.pks
	q$error_manager.pkb
	qem$install.sql
	qem$define_errors.sql


Note if the latest version of the Quest code is updated into VSS then the above files that are held in VSS that contain customised versions of the Quest code will need to be updated.  
To do this take the new version of qem.zip and once unpacked compare the differences of the files above with their equivalent version from the zip file.  Now take the zip file which is the latest version and merge into this the differences from the above files in the VSS folder.  Once this is done update VSS to replace the above files with their newer versions and also replace the qem.zip file with the latest version.

The qem$define_errors.sql is slightly different in that it just defines the errors that you want to use, so you should be able to just continue with the VSS modified version.  It is unlikely that the latest qem.zip will change this file much.


Installation
============

It is recommended that you create your own version of the error manager files under your application VSS project so that the application has an independent version of the error manager files which are then subject to control for that individual application.  If the master version of error manager is updated then this will need to be distributed, if appropriate, to each individual application in a controlled manner.  ( You would have to release the files individually anyway so this is not much more work to do ).

1.	Under your application project in VSS create a "Quest Error Manager" folder.  In VSS naviagate to the 
		Quest Code --> 	Quest Error manager  VSS folder and set the working folder to be your new application quest error manager folder on your pc.

2.	Now do a GET on the latest version of all the files in the Quest error manager folder.

3.	Unpack the qem.zip file into a sub foler qem.

4.	Now run the batch file : run_qem_install.bat
	This will prompt you for the instance name, the schema name and the sys password of that instance.

5.	It will create 2 log files: one from the quest install and one for the rest of the installation.
	Examine these logfiles for errors...if all is well then the installation was succesful.

6.	Don't forget to reset the VSS working folder back to Quest Error manager directory so that it is not
	defaulted to your application directory.

7.	Finally remove all files from your pc including the qem folder that was created.  This will ensure VSS
	remains the source.

Uninstallation
==============

To uninstall:

1.	Simply run the batch file: run_qem_uninstall.bat
	This will prompt you for the instance name, the schema name and the sys password of that instance.

2.	It will create 1 log files. Examine this logfile for errors...if all is well the uninstallation is complete.







