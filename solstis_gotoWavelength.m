%solstis_gotoWavelength - go to wavelength
%
% setWavelength = solstis_gotoWavelength(wavelength) brings the solsTiS
% laser to the wavelength specified in nm. The function does not return
% until the laser has settled. setWavelength is the final wavelength the
% laser is left at.
%
% Example
%
%   setWavelength = solstis_gotoWavelength(754.524)
%
% Todd Karin
% 11/17/2014

function setWavelength = solstis_gotoWavelength(wavelength)
%wavelength= 750+1*rand(1);

solstis = solstis_findInstrument();
wavelengthStr =  num2str(wavelength,'%03.6f');
fprintf(['Going to ' wavelengthStr ' nm'])

id = 'instrument:query:unsuccessfulRead';
warning('off',id)
fprintf(solstis,['{"message":{"transmission_id":[3],"op":"set_wave_m","parameters":{"wavelength":[' wavelengthStr ']}}}'])

laserSettled = 0;

while ~laserSettled
    fprintf('.')
    
    ret = solstis_query('{"message":{"transmission_id":[8], "op":"poll_wave_m"}}');
    response = solstis_processResponse(ret);
    pause(.2)
    
%     
%     ret = query(solstis,['{"message":{"transmission_id":[8], "op":"poll_wave_m"}}']);
%     response = solstis_processResponse(ret);
%     pause(.2)
%     

    laserSettled = response.messageRecieved & response.status==0 & abs(response.current_wavelength-wavelength)<.01 ;
    
end

setWavelength = response.current_wavelength;
fprintf(' laser settled!\n')

warning('on',id)