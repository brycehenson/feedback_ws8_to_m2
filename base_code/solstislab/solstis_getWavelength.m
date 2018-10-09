%solstis_getWavelength - read wavelength
%
% wavelength = solstis_getWavelength() gets the current wavelength of the
% laser by reading the wavemeter.
%
% Todd Karin
% 11/17/2014

function wavelength = solstis_getWavelength()


solstis = solstis_findInstrument();
ret = solstis_query('{"message":{"transmission_id":[8], "op":"poll_wave_m"}}');

response = solstis_processResponse(ret);
wavelength = response.current_wavelength;
