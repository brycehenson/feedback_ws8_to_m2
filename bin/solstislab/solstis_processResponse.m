%solstis_processResponse - processes solstis text response
%
% response = solstis_processResponse(ret) processes the text response ret
% into a matlab struture response with fields equal to those in the text
% response. This is not a general process, but works for the wavelength
% setting in these scripts.
%
%
% Codes for status
%
% 0 - tuning software not active
% 1 - no link to wavelength meter or no meter configured
% 2 - tuning in progress
% 3 - wavelength lock is on
% -1 - communication error!
%
% Todd Karin
% 12/05/2014

function response = solstis_processResponse(ret)

%ret = '{"message":{"transmission_id":[3],"op":"set_wave_m_reply","parameters":{"status":[0],"wavelength":[759.502197]}}}';

%ret = '{"message":{"transmission_id":[3],"op":"set_wave_m_reply","parameters":{"status":[0],"wavelength":[750.344482]}}}{"message":{"transmission_id":[8],"op":"poll_wave_m_reply","parameters":{"status":[2],"current_wavelength":[759.501953],"lock_status":[0]}}}';


response.messageRecieved = 1;
response.current_wavelength = 0;
response.status = 4;
if isempty(ret)
    response.messageRecieved = 0;
    return
end

% extract the last message (throw away any others)
lastMessageStart = strfind(ret,'}{"message"');
if ~isempty(lastMessageStart)
    ret = ret(lastMessageStart(end)+1:end);
end
response.current_wavelength = findQuoteStrNumeric('current_wavelength');
response.status = findQuoteStrNumeric('status');
response.transmission_id = findQuoteStrNumeric('transmission_id');
response.lock_status = findQuoteStrNumeric('lock_status');

response.wavelength = findQuoteStrNumeric('wavelength');

function val = findQuoteStrNumeric(str)
startPos = strfind(ret,['"' str '"']);
if isempty(startPos)
   val = -1;
   return
end

startPos = startPos+length(str)+4;

endPos=startPos;
while ret(endPos)~=']'
    endPos=endPos+1;
end
endPos=endPos-1;
val = str2num(ret(startPos:endPos));


end


end