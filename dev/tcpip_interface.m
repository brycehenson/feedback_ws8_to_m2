%% Host
setpt = 0;
while 1
%     setpt = 3.697789003e8;
    try
        t = tcpip('localhost', 33333, 'NetworkRole', 'client');
        fopen(t)
        setpt = fread(t,1,'double');
        fclose(t)    
    catch
        fprintf('Client not found')
    end
    setpt
end