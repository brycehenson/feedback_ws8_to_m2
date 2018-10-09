% solstislab - SolsTiS Laser Communication
% Version 1.0 20-Nov-2014
% 
% Summary
%
%     Matlab driver to communicate with a SolsTiS M Squared CW Ti-saphire
%     laser using TCP/IP.
%
% Description
%   
%     This package can be used to communicate a SolsTiS M Squared CW
%     Ti-saphire laser using TCP/IP. The functions can be used to send a
%     general command, or use the built in functionality for getting and
%     setting the wavelngth.
%
%     The main nontrivial trick was to count '}' characters instead of
%     waiting for a terminator. The Solstis does not send a terminator
%     character over TCP/IP, so if Matlab expects one, then there is a long
%     lag until the timeout is reached.
%
%     The SolsTiS laser should be set up in a standard way using an
%     Angstrom wavemeter. Setup involves setting the TPC/IP addresses
%     correctly in the web interface. In the solstis interface, set the
%     remote interface to the control computer's ip address. Then disable
%     and enable the link. You can find a windows machine's ip address by
%     typing ipconfig into the command prompt.
%   
%
%
% Functions.
%
%     solstis_findInstrument - initialize solstis instrument object
%     solstis_getWavelength - read wavelength
%     solstis_gotoWavelength - go to wavelength
%     solstis_clearBuffer - Clear all incoming messages
%     solstis_getResponse - read solstis instrument
%     sostis_query - query solstis instrument
%     solstis_processResponse - processes solstis text response
%
%
%
%   Copyright (C) 2014 Todd Karin <toddakarin (at) gmail (dot) com>
%
% Tags
%   Solstis, TCP/IP, Matlab, communicate, control