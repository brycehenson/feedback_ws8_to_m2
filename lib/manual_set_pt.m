%manualy change the set pt of the ws8 to msquared laser feedback



% freq_list = [744396182.90,744396206.40,744396224.36,744396476.75];
% width_list = [7.41,12.35,5.56,9.34];
% scan_range = [];
% for ii=1:length(freq_list)
%     interval = -width_list(ii):1:width_list(ii);
%     scan_range = [scan_range,3*interval+freq_list(ii)];
% end
% scan_range = sort(unique(round(scan_range)));
% sfigure(572042);
% plot(scan_range,'x')
% title(sprintf('Targeted scan, %u pts',length(scan_range)))

% 2photon cs cell b  
% filter at 822.5
%freq=364507091.65 %2photon CS 6s->8s F=3
%freq=364503080.351-147.8+0; %2photon CS 6s->8s F=4
%freq=364507238.417-146.8; %2photon CS 6s->8s F=4
%f_cs_6sF4_6PF5=351725718.50-4021.776399375+263.81; %MHZ
%freq=f_cs_6sF4_6PF5;

% 427nm forbidden transition
%freq=700939247.242651/2;

%% TRANSITION FREQS
target = 744396193; 
target = 700939257.480888-1.7154;
% target = 701001649.5449-1.7154;%1.7154;
% target = 744515114-23;
% target = 744515336.76-47;
% target = 744515206.2;
% target = 2*372215290;
offset = 189.0/2; %Frequency shift from AOM
freq = target/2-offset 
% freq = 363651705
% freq = 363651706.794468; % Observed 412
% freq=372198246.94175;
fprintf('probe beam set freq %f MHz \n',freq)
t = tcpip('0.0.0.0', 33333, 'NetworkRole', 'server');
fopen(t)
fwrite(t,freq,'double')
fclose(t)




%%
%datetime(posixtime(datetime('now'))+140*26,'ConvertFrom','posix')
