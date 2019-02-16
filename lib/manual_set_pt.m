%manualy change the set pt of the ws8 to msquared laser feedback
%
%freq=362848466.40;
%freq=362871075.28;
%freq=362865454.07;
%freq=362853600;

%TUNE OUT filter at 826.1
%freq=362900000.00
freq=362865454.07; %TO at l/4 246deg
freq=362865454.07; %TO at l/4 246deg
%freq=362760000
% freq=362867621%-  6000; %TO as at 2018/11/28
%freq=362867621-50000; % -0.1nm for spectral tests

%freq=362867621+20e3; % max signal

freq=362867621; % Centre of scan range
freq=362867621+10000; % Alignment
%freq=362867621-2000; % Run starting val

freq=362867621-50000; % Alignment


% 2photon cs cell b  
% filter at 822.5
%freq=364507091.65 %2photon CS 6s->8s F=3
%freq=364503080.351-147.8+0; %2photon CS 6s->8s F=4
%freq=364507238.417-146.8; %2photon CS 6s->8s F=4
%f_cs_6sF4_6PF5=351725718.50-4021.776399375+263.81; %MHZ
%freq=f_cs_6sF4_6PF5;

% 427nm forbidden transition
%freq=700939247.242651/2;

fprintf('probe beam set freq %f MHz \n',freq)


t = tcpip('0.0.0.0', 33333, 'NetworkRole', 'server');
fopen(t)
fwrite(t,freq,'double')
fclose(t)




%%
%datetime(posixtime(datetime('now'))+140*26,'ConvertFrom','posix')
