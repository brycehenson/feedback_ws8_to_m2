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
%Bryce Henson
%change so that can pass soltis insturment in and out to speed things up
%2018-08-23

function ret = solstis_getResponse(solstis)
if isequal(solstis,[])
    solstis = solstis_findInstrument();
end
%fprintf(solstis,['{"message":{"transmission_id":[8], "op":"poll_wave_m"}}']);
%fprintf(solstis,q)
timeout=5;

ret = [];
tic
while toc<timeout
ret = [ret fscanf(solstis)];
numOpenBracket = sum(ret=='{');
numClosedBracket = sum(ret=='}');

if numOpenBracket>0 && numOpenBracket==numClosedBracket
    break
end

end

if isequal(ret,[])
   warning('solstis_getResponse did not return anything!')
end

