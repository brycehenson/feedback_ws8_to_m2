%solstis_clearBuffer - Clear all incoming messages
%
% solstis_clearBuffer() repeatedly reads the TCP/IP buffer until no new
% messages are recieived.
%
% Todd Karin
% 11/25/2014

function solstis_clearBuffer()


solstis = solstis_findInstrument();
%fprintf(solstis,['{"message":{"transmission_id":[8], "op":"poll_wave_m"}}']);

ret = ['a'];

while length(ret)>0

    ret =  fscanf(solstis);

end

disp('Buffer cleared!')

