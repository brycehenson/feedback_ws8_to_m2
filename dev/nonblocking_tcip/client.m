% this is the matlab interface for the BEC control, it will only run evy 30s
% it should send info to the wavemeter program

while true
     setpt=rand(1);
     t = tcpip('0.0.0.0', 33333, 'NetworkRole', 'server');
     fopen(t)
     fwrite(t, setpt,'double')
     fclose(t)
     pause(1)
end

%%
fclose('all')
