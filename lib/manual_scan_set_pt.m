

%manualy scan the set pt


%freq_cen=364507238.417;
%freq_cen=364507091.65;

wavemeter_offset=0;%-150.4;%-145.2;
% 2photon cs cell b  
% filter at 822.5
%freq_cen=364507238.363+wavemeter_offset %2photon CS 6s->8s F=3
freq_cen=351730625+1000;
freq_range=20;
steps=10;
step_time=0.10;
extra_pause=0;
freq_delta=[linspace(-freq_range,freq_range,steps),linspace(freq_range,-freq_range,steps)];
%freq_delta=linspace(0,freq_range,steps);

ii=1;
while true
    freq=freq_cen+freq_delta(ii);
    %fprintf('probe beam set freq %f MHz \n',freq)
    fprintf('probe beam set freq %f MHz \n',freq_delta(ii))
    t = tcpip('0.0.0.0', 33333, 'NetworkRole', 'server');
    fopen(t)
    fwrite(t,freq,'double')
    fclose(t)
    pause(step_time)
    if ii==1
        pause(extra_pause)
    end
    ii=ii+1;
    if ii>numel(freq_delta)
        ii=1;
    end
end


%%

