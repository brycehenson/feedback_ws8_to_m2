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

function ret = solstis_query(q)


solstis = solstis_findInstrument();
%fprintf(solstis,['{"message":{"transmission_id":[8], "op":"poll_wave_m"}}']);
fprintf(solstis,q)

ret = [];

while 1
ret = [ret fscanf(solstis)];
numOpenBracket = sum(ret=='{');
numClosedBracket = sum(ret=='}');

if numOpenBracket>0 && numOpenBracket==numClosedBracket
    break
end

end

