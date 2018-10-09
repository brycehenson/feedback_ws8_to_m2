% Solstis - a class to control the MSquared Lasers 'SolsTis' laser
% ----------------------------------------------------------------
% Jakko de Jong - 18 november 2016
% Copyright (C) 2016 Jakko de Jong <jakkodejong (at) gmail (dot) com>
%
%
% Description
% -----------
% Matlab class to control the M Squared cw TiSapph laser over TCP/IP.
% 
% This script can be used to send commands to the Solstis and read back its
% reports. The class limits the number of solstis objects that can
% be instantiated (current limit is two, but this is easily changed in the
% class constructor). The class provides basic functionality of setting and
% reading the wavelength, applying wavelength feedback (requires a
% wavemeter link) to lock the wavelength to a certain value. It also
% supports the more sophisticated built-in scan routines TeraScan and 
% FastScan provided by M Squared Lasers.
% 
% The class provides a level of usability by checking user input for
% compatibility with the solstis and returning informative warnings and
% error messages. It also parses the solstis reports (single strings) into
% matlab structs with a separate field for each piece of information.
%
% Please note that some functions require a direct connection between the
% solstis and a wavemeter. Ask M Squared Lasers for further information.
%
% N.B.: Currently, the class requires the user to insert the ip-address of 
% the PC on which the script is run. By default, it is set to '192.168.1.220' 
% in the constructor. Either change this value in the script, or change it
% after instantiation by doing the following:
% solstis = Solstis.getInstance( ... , ... ) (fill in solstis ip and port)
% solstis.pc_ip_address = 'xxx.xxx.xxx.xxx' (fill in pc ip-address as a string)
%
%
% Functions
% ---------
% getInstance - instantiate the solstis object
% OpenTCPIP - open the TCPIP connection with the solstis
% Query - send a command string to the solstis
% Parse - change solstis report strings into a more informative stuct
% WaitForResponse - wait for solstis final reports (used with terascan a.o.)
% GetWL - ask solstis for its current wavelength
% GoToWL - go to a wavelength and report when done.
% Lock - lock the wavelength to an external wavelength meter.
% ClearBuffer - empty the solstis output message buffer.
% TeraScan - perform the terascan routine
% TeraScanInit - initialize the terascan routine
% TeraScanOutput - initialize optional terascan settings for reports during
% the scan.
% TeraScanStatus - obtain information about the current status of terascan.
% TeraScanContinue - continue a paused terascan
% FastScan - perform a fast scan routine
% PollFastScan - obtain information about the current status of fastscan.
%
% A detailed description of all the class' functionality is provided by
% Solstis_matlab_class.pdf
%
%
% Acknowledgements
% ----------------
% M Squared Lasers technical support has been thorough and helped a lot in
% understanding in detail the workings of their apparatus and its TCPIP
% interface.
% Further, the matlab scripts written by Todd Karin on remote solstis
% control provided a solid basis to start experimenting with controlling
% the solstis via script.