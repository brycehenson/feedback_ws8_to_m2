handle=WLM.getInstance();
solstis_query('{"message":{"transmission_id":[9],"op":"start_link","parameters":{"ip_address":"150.203.178.175"}}}')
solstis_query('{"message":{"transmission_id":[2],"op":"ping","parameters":{"text_in":"LetsDoThis"}}}')
solstis_query('{"message":{"transmission_id":[2],"op":"etalon_lock_status"}}')
solstis_query('{"message":{"transmission_id":[2],"op":"read_all_adc"}}')
solstis_query('{"message":{"transmission_id":[2],"op":"fine_tune_resonator","parameters":{"setting":[50]}}}')

%set up to use analog out for the fast path
connected_dev=daq.getDevices;
dev_idx=cellfun(@(x) isequal(x,'National Instruments PCI-6711'),{connected_dev.Description});
if sum(dev_idx)~=1
    error('somethings fucked couldnt find 6711')
end
dev_idx=find(dev_idx,1);
connected_dev(dev_idx)
s = daq.createSession('ni');
addAnalogOutputChannel(s,connected_dev(dev_idx).ID,1,'Voltage');



res_fine=0.5;
k_int=-5e-0;
k_prop=-3e-10;
k_aw=1e2;
integrator=0.5/k_int;
int_lim=2000/k_int;
pause(1)
freq=handle.GetFreq(1);
%setpt=round(freq/10)*10;
anti_wind=0;
err=0;
res_fine_scaled=50;
di=0;

%setpt=373897815;%handle.GetFreq(1)
tic;
t1=toc;
logist=@(x) 1./(1+exp(-x));


solstis = solstis_findInstrument();
for n=1:1000
    freq=handle.GetFreq(1);
%     err=freq-setpt;
     t2=toc;
     loop_time=t2-t1;
%     anti_wind=anti_wind+logist((res_fine-0.9)*100)+logist((res_fine-0.1)*100)-1;
%     di=(err-k_aw*anti_wind)*loop_time;
%     di=di*logist(-(di-0.1)*100);
%     pen=logist(-(abs(integrator)/int_lim-0.5)*10);
%     pen=logist(-(abs(integrator)/int_lim-0.5)*10)
%     pen=logist(-(abs(di-50)-40)*0.75);
%     di=di*(pen+1*(1-pen)*(sign(di)~=sign(integrator)));
% 
%     integrator=integrator+di;
%     integrator=min(max(-int_lim,integrator),int_lim);
%     res_fine=k_int*integrator+k_prop*err;
%     res_fine_scaled=res_fine*100;
%     res_fine_scaled=min(max(1,res_fine),100);
    outputSingleScan(s,normrnd(0,1))
     fprintf('err %+05.3f MHz Res %02.4f Feedback Freq %03.1f Int %02.4f Dint %02.4f Aw %02.2f\n',[err,res_fine_scaled,1/loop_time,integrator,di,k_aw*anti_wind])
    res_fine_scaled=50+normrnd(0,0.1);


    query=sprintf('{"message":{"transmission_id":[2],"op":"fine_tune_resonator","parameters":{"setting":[%2.4f]}}}',res_fine_scaled);
    fprintf(solstis,['{"message":{"transmission_id":[8], "op":"poll_wave_m"}}']);
    fprintf(solstis,query)

    
    ret = [];
    while 1
        ret = [ret fscanf(solstis)];
        numOpenBracket = sum(ret=='{');
        numClosedBracket = sum(ret=='}');

        if numOpenBracket>0 && numOpenBracket==numClosedBracket
            break
        end
    end

    t1=t2;




end





%solstis = instrfind('tag','solstis');
%delete(solstis)