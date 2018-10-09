%solstis_findInstrument - initialize solstis instrument object
%
% solstis = solstis_findInstrument() sets up communication with the solstis
% laser through tcp/ip. The output 'solstis' is the matlab tcp/ip
% instrument. If the instrument is already initialized,
% solstis_findInstrument just returns the instrument without initializing.
%
% In order for this to work, the TCP/IP communication must be set up in the
% web browser interface. In the solstis interface, set the remote interface
% to the control computer's ip address. Then disable and enable the link.
% You can find a windows machine's ip address by typing ipconfig into the
% command prompt.
%
% Change the IP addresses and port numbers in this script to get this
% working on your computer. 
%
% Note that the terminator for the instrument is set to '}'! This makes for
% a faster readout, but can cut things off mid-sentence. For this reason,
% use solstis_query to send a query or solstis_getResponse() to read out
% the instrument buffer.
%
% Todd Karin
% 11/25/2014





function solstis = solstis_findInstrument()

% If instrument already exists, then just grab it.
solstis = instrfind('tag','solstis');

if isempty(solstis)
    disp('Initializing SolsTiS communication')
    
    % Open communication
    solstis = tcpip('192.168.1.220', 39933,... % Enter the ICE BLOC ip address and port number here.
        'tag','solstis',...
        'timeout',1,...
        'terminator',125); % Note that the terminator is set to '}'!
    fopen(solstis)
    
    % Turn off warning about terminator.
    id = 'instrument:query:unsuccessfulRead';
    warning('off',id)
%     tic
    ret = query(solstis,['{"message":{"transmission_id":[1],"op":"start_link",' ...
        '"parameters":{"ip_address":"192.168.1.133"}}}']); % Enter the control computer's IP address here.
%     toc
    warning('on',id)    

    % If no response, show error.
    if ~strncmp('{"message"',ret,10)
        ret
        error('Error initializing communication! try restarting box')
    end
   
    disp('Done!')
    
end

