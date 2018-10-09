%sostis_query - query solstis instrument
%
% ret = solstis_query(q) sends the query 'q' to the instrument and gets the
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
%change so that can pass soltis insturment in to speed things up
%2018-08-23

function ret = solstis_query(q,solstis)
if isequal(solstis,[])
    solstis = solstis_findInstrument();
end
%fprintf(solstis,['{"message":{"transmission_id":[8], "op":"poll_wave_m"}}']);
timeout=5;
fprintf(solstis,q);
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
   warning('solstis_query did not return anything!')
end

