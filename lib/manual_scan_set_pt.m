

%manualy scan the set pt


freq_cen=364507238.417;
freq_cen=364507091.65;
freq_cen=364503080.351-147.8;
freq_range=3;
steps=5;
step_time=0.3;
extra_pause=0;
%freq_delta=linspace(-freq_range,freq_range,steps);
freq_delta=[0,freq_range];
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

