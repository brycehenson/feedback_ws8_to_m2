%solstis_getResponse - read solstis instrument
%
% ret = solstis_getResponse() reads the response from the solstis.
% response ret. Since the instrument terminator is the '}' characterm, we
% need to iteratively read the solstis buffer until we get the correct
% number of '}' characters.
%
% Example
%
%  ret = solstis_query('{"message":{"transmission_id":[8], "op":"poll_wave_m"}}')
%
% Todd Karin
% 11/25/2014


function ret = solstis_getResponse()


solstis = solstis_findInstrument();
%fprintf(solstis,['{"message":{"transmission_id":[8], "op":"poll_wave_m"}}']);
%fprintf(solstis,q)

ret = [];

while 1
ret = [ret fscanf(solstis)];
numOpenBracket = sum(ret=='{');
numClosedBracket = sum(ret=='}');

if numOpenBracket>0 && numOpenBracket==numClosedBracket
    break
end

end

