%two chan test
%testing how fast the wm can switch between different channels without using the treaded option in
%the WLM class
wmhandle=WLM.getInstance();
time_chan1=nan(1,20);
time_chan2=nan(1,20);
wmhandle.GetFreq(1);
for ii=1:numel(time_chan1)
    tic; wmhandle.GetFreq(1); 
    time_chan1(ii)=toc;
end

wmhandle.GetFreq(2);
for ii=1:numel(time_chan1)
    tic; wmhandle.GetFreq(2); 
    time_chan2(ii)=toc;
end

fprintf('measurment time chan 1: %.2fms, chan 2: %.2fms\n',mean(time_chan1)*1e3,mean(time_chan2)*1e3)


%switching test
wmhandle.GetFreq(2);
time_switch=nan(1,20);
freqs=nan(2,numel(time_switch));
for ii=1:numel(time_switch)
    tic;
    freqs(1,ii)=wmhandle.GetFreq(1); 
    freqs(2,ii)=wmhandle.GetFreq(2);
    time_switch(ii)=toc;
end
fprintf('measurment time both chan: %.2fms, ratio %.2f\n',mean(time_switch)*1e3,mean(time_switch)/(mean(time_chan1)+mean(time_chan2)))





octave_err=freqs(1,:)*2-freqs(2,:);
fprintf('red*2-blue mean %.2f std %.2f peak %.2f \n',mean(octave_err),std(octave_err),max(octave_err))