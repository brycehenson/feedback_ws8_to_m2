%set up to use analog out for the fast path
% connected_dev=daq.getDevices;
% dev_idx=cellfun(@(x) isequal(x,'National Instruments PCI-6711'),{connected_dev.Description});
% if sum(dev_idx)~=1
%     error('somethings broken couldnt find 6711')
% end
% dev_idx=find(dev_idx,1);
% connected_dev(dev_idx)
% s = daq.createSession('ni');
% addAnalogOutputChannel(s,connected_dev(dev_idx).ID,1:3,'Voltage');
% 
% outputSingleScan(s,[0 0 0])


%%
connected_dev=daq.getDevices;
dev_idx=cellfun(@(x) isequal(x,'National Instruments USB-6251'),{connected_dev.Description});
if sum(dev_idx)~=1
    error('somethings broken couldnt find USB-6251')
end
dev_idx=find(dev_idx,1);
connected_dev(dev_idx)
s = daq.createSession('ni');
ch=addAnalogInputChannel(s,connected_dev(dev_idx).ID,4,'Voltage');
s.Rate = 10000;
voltage = s.inputSingleScan
ch.TerminalConfig='SingleEnded'

%%
figure(1)
clf
[voltage,time] = s.startForeground;
plot(time,voltage)


current_gain=2e7; %V/A
current_gain=current_gain/1e9;
voltage=[];
time=[];
start_time=posixtime(datetime('now'));
time=[time,posixtime(datetime('now'))-start_time];
voltage=[voltage,s.inputSingleScan/current_gain];
figure(1)
h=plot(time, voltage,'k.-','LineWidth',1.5,'MarkerSize',20);
set(gcf,'color','w')
xlabel('time (s)')
ylabel('pmt currentA')


plot_duration=120;
% now get into the loop
while true
    voltage_now=s.inputSingleScan/current_gain;
    time_now=posixtime(datetime('now'))-start_time;
if time(1)>plot_duration
    time=circshift(time,1);
    voltage=circshift(voltage,1);
    time(1)=time_now;
    voltage(1)=voltage_now;
else
    time=[time_now,time];
    voltage=[voltage_now,voltage]; 
end
set(h,'xdata', time, 'ydata', voltage);
set(gca,'xlim', time([end,1]));

drawnow

end