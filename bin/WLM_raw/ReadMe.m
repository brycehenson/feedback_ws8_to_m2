% WLM - a driver class to control a High Finesse WS6 or WS7 wavelength meter
% -------------------------------------------------------------------------
% Jakko de Jong - 21 november 2016
% Copyright (C) 2016 Jakko de Jong <jakkodejong (at) gmail (dot) com>
%https://au.mathworks.com/matlabcentral/fileexchange/60330-ws6-or-ws7-wavemeter-driver
%
% Description
% -----------
% Matlab driver class to setup and read-out a High Finesse WS6 or WS7
% wavelength meter. The class supports the addition of a multichannel
% switchbox connected to the wavelength meter. As an extra feature,
% routines are added to toggle between wavemeter channels without blocking
% execution of other matlab scripts. This is achieved by creating a
% parallel worker pool, so be aware that this will take up additional RAM!
% 
% The class provides a level of usability by checking user input for
% compatibility with the wavelength meter and returning informative warnings and
% error messages. The class is a singleton, preventing the user from
% accidentally instantiating multiple objects that control the same
% wavelength meter.
%
%
% Functions
% ---------
% getInstance - instantiate the WLM object
% SwitchToChannel - issue switchbox to switch to a different channel.
% ToggleChannels - constantly toggle between wavemeter channels.
% GetFreq - Return the photon frequency measured at a certain channel.
% GetWL - Return the wavelength measured at a certain channel.
% GetBoth - Return both the photon frequency and the wavelength measured at a certain channel.
% GetChannel - Return the active channel.
%
% A detailed description of all the class' functionality is provided by
% WLM_matlab_class.pdf