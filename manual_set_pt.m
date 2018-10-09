

%manualy change set pt
%
%freq=362848466.40;
%freq=362871075.28;
%freq=362865454.07;
%freq=362853600;

%freq=362900000.00
freq=362865454.07; %TO at l/4 246deg
%freq=362760000
freq=362868100-10000;
fprintf('probe beam set freq %f MHz \n',freq)


t = tcpip('0.0.0.0', 33333, 'NetworkRole', 'server');
fopen(t)
fwrite(t,freq,'double')
fclose(t)




%%

