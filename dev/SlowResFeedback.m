%basic feedback implementation
%only to slow resonator pzt 
%feedback speed limited to 25hz to prevent crashing the soltis
%good anti-windup using condition integeration which works greattt
%need to implement slew limiiting (with anit windup)
%found that the resonator voltage relates to the dac setting with
%dac=polyval([0.00000006007743282452 -0.00002630543053390512 0.00404787545023589396 0.27097607207749069280 3.44975464072533588578 ],voltage)
%fine 80MHz
%slow 30GHz

delete(gcp('nocreate'))
%intialize connection
handle=WLM.getInstance();
solstis_clearBuffer()

solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',50))
pause(0.5)
solstis_query('{"message":{"transmission_id":[9],"op":"start_link","parameters":{"ip_address":"150.203.178.175"}}}')
reply=solstis_query('{"message":{"transmission_id":[2],"op":"get_status"}}');
reply=strip(reply,'left','}');
lcurly=sum(reply=='{');
rcurly=sum(reply=='}');
if lcurly~=rcurly
    reply=[reply,repmat('}',[1,lcurly-rcurly])]
end
reply=jsondecode(reply);
status=reply.message.parameters;
res_voltage=status.resonator_voltage;
res_slow_dac=polyval([0.00000006007743282452 -0.00002630543053390512 0.00404787545023589396 0.27097607207749069280 3.44975464072533588578 ],res_voltage);

pause(0.5)
disp('here')
query=sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%3.10f]}}}',res_slow_dac);
solstis_query(query);
disp('past')

%%
%solstis_query('{"message":{"transmission_id":[2],"op":"ping","parameters":{"text_in":"LetsDoThis"}}}')
%solstis_query('{"message":{"transmission_id":[2],"op":"fine_tune_resonator","parameters":{"setting":[0]}}}');
%pause(0.5)
%solstis_query('{"message":{"transmission_id":[2],"op":"fine_tune_resonator","parameters":{"setting":[100]}}}');
%pause(0.5)
%solstis_query('{"message":{"transmission_id":[2],"op":"fine_tune_resonator","parameters":{"setting":[50]}}}')



%%control params
res_lims_dscaled=[20,80]; %limits as dac output range 0-100
res_slow=0.5;
k_int=-3e-4;
k_prop=-2e-5;
k_aw_rate=0.5;
int_lim=5;
slew_lim_dscaled=5; %dac/s max slew rate


%%initalization
slew_lim_uscaled=slew_lim_dscaled/100;
res_lims_uscaled=res_lims_dscaled/100;
integrator=res_slow_dac/100;
pause(0.5)
%freq=handle.GetFreq(1);
%setpt=round(freq/1000)*1000;
% setpt= 3.698027382226406e+08;
% setpt=handle.GetFreq(1)+2e4;
setpt=363.e6;
err=0;
di=0;
ctr_hist=res_slow_dac/100; %given in dac output 0-100
n=1;
aw_slew=0;

%initalize timer
tic;
t1=toc;
pause(1e-3)
t2=toc;
loop_time=t2-t1;
%intialize aw function
logist=@(x) 1./(1+exp(-x));
aw_thresh_range=0.01; %how far away from the edge aw starts (full range 0-1)
aw_fun_range=@(x,y) (logist((x-aw_thresh_range)*10/aw_thresh_range))*(y>0)+(1-logist((x-1+aw_thresh_range)*10/aw_thresh_range))*(y<0);

solstis = solstis_findInstrument();

n=1;
while true
    %get set point from server

    freq=handle.GetFreq(1);
    err=freq-setpt;
    di=k_int*loop_time*err;
    di=di*aw_fun_range((res_slow-res_lims_uscaled(1))/range(res_lims_uscaled),err); %slew anti windup * actuator range anti windup
    integrator=integrator+di;%+aw_slew*k_aw_rate;
    integrator=min(max(-int_lim,integrator),int_lim);
    res_slow=integrator+k_prop*err;%-aw_rate*k_aw_rate);
    
    %slew limit
    
    %slew=mean(diff(ctr_hist))/(loop_time);
    slew=(ctr_hist-res_slow)/(loop_time);
    if abs(slew/slew_lim_uscaled)>1
        integrator=ctr_hist-slew_lim_uscaled*sign(slew)*loop_time-k_prop*err;
        aw_slew=1;
    else
        aw_slew=0;
    end
 
    %recalc output
    %integrator=integrator+aw_slew;
    integrator=min(max(-int_lim,integrator),int_lim);
    res_slow=integrator+k_prop*err;%-aw_rate*k_aw_rate);
    slew=(ctr_hist-res_slow)/(loop_time);
    ctr_hist=res_slow;
    
    %aw_slew=rate_lim(abs(slew/slew_lim_dscaled))*sign(slew);
    res_slow_dscaled=res_slow*100;
    res_slow_dscaled=min(max(res_lims_dscaled(1),res_slow_dscaled),res_lims_dscaled(2));
    fprintf('err %+05.3f MHz Res %02.4f Feedback Freq %03.1f Int %+01.2f Dint %+01.3f slew %+02.2f slewlim %1i\n',[err,res_slow_dscaled,1/loop_time,integrator,di,slew*100,aw_slew])
    query=sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',res_slow_dscaled);
        
 
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

%     if mod(n,100)==0
%         if mod(n,200)==0
%             setpt=setpt-10;
%         else
%             setpt=setpt+10;
%         end
%     end


    n=n+1;

    t2=toc;
    loop_time=t2-t1;
    pause(30e-3-loop_time) %have to slow down or the controller will crash
    
    t2=toc;
    loop_time=t2-t1;
    t1=t2;
end





solstis = instrfind('tag','solstis');
delete(solstis)