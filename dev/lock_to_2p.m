%function ret = lock_to_2p()

% Lock the laser to the PMT using a pretty basic software lock in amplifier
% the software starts by scaning the laser over the 2p transtion of choice (using the wavemeter and a cut down version of WM_control) and then fits the result
% it then fits the function and uses this in order to lock the laser to the 2p signal

%WM_control- runs feedback between measurments from ws8 wavemeter and a m2 laser
%Uses software in the loop feedback of the optical frequency of a M Squared SolsTiS Laser (with doubler) to a WS8 wavemeter.
%Checks if the laser has unlocked either the doubler or the Ti:Saf and relocks.
%Can instigate an unlock of the doubler and a scan of the etalon.
%Provides a detailed log file in JSON format.
%
% Syntax:  
%spmd
%    r = WM_control(labindex);
%end

%
% Inputs:
%    labindex - worker instruction to either be the tcip comunicator or feedback worker
% Outputs:
%   logfile output 
%
% Other m-files required: WLM,
% Also See: manual_set_pt,manual_scan_set_pt
% Subfunctions: none
% MAT-files required: none
%
% Known BUGS/ Possible Improvements
%- Documentation
%- move much of the code into functions
%- move pid into separate project
%  - build tests for pid
%- clean up unused functions
%
% Author: Bryce Henson
% email: Bryce.Henson@live.com
% Last revision:2018-10-22

%------------- BEGIN CODE --------------


%warning('on','verbose')
%warning('on','backtrace')
warning off instrument:fscanf:unsuccessfulRead


%start by scanning over the transtion
%6S–8S two photon cesium ~822.4nm 2photon 
%pmt voltage 1160 %filter at 822.5
%Ref https://doi.org/10.1088/1674-1056/21/11/113701  
% older works
% https://doi.org/10.1016/S0030-4018(98)00662-2 (1999)
% https://doi.org/10.1364/OL.32.000701 (2007)
%6^{2}S_{1/2} F=[3,4] -> 8^{2}S_{1/2} F=[3,4]
f_cs_2p_6SF3_8SF3=364507238.363;
f_cs_2p_6SF4_8SF4=364503080.297;
wavemeter_offset=-3;%-151.19;%-145.2;
transition_freq=f_cs_2p_6SF4_8SF4;
scan_center_freq=transition_freq+wavemeter_offset;
scan_freq_range=6;
scan_delt_freq=0.25; %MHz
freq_vec=scan_center_freq+linspace(-scan_freq_range/2,scan_freq_range/2,scan_freq_range/scan_delt_freq)';
scan_step_time=0.2;
volt_aq_time=1e-3;
scan_dat=[];
scan_dat.set_freq_vec=freq_vec;

%% Set up user dir
folder = fileparts(which(mfilename));
folder=strsplit(folder,filesep); %go up a directory
folder=strjoin(folder(1:end-1),filesep);
% Add that folder plus all subfolders to the path.
addpath(genpath(folder));


%% initalize daq
connected_dev=daq.getDevices;
dev_idx=cellfun(@(x) isequal(x,'National Instruments USB-6251'),{connected_dev.Description});
if sum(dev_idx)~=1
    error('somethings broken couldnt find USB-6251')
end
dev_idx=find(dev_idx,1);
connected_dev(dev_idx)
% the sampling rate should be set so that it is much slower than the 200us of the transimpedance
% amplifier % 3.7khz low pass filter, 0.5khz is ok
samp_rate=500;
daq_pmt = daq.createSession('ni');
ch=addAnalogInputChannel(daq_pmt,connected_dev(dev_idx).ID,4,'Voltage');
daq_pmt.Rate = samp_rate;
daq_pmt.DurationInSeconds=volt_aq_time;
ch.TerminalConfig='SingleEnded';
ch=addAnalogInputChannel(daq_pmt,connected_dev(dev_idx).ID,6,'Voltage');
daq_pmt.Rate = samp_rate;
daq_pmt.DurationInSeconds=volt_aq_time;
ch.TerminalConfig='SingleEnded';
daq_pmt.inputSingleScan;



%%
%intialize connection
wmhandle=WLM.getInstance();
solstis=solstis_findInstrument;
solstis_clearBuffer();

%%
solstis_query('{"message":{"transmission_id":[9],"op":"start_link","parameters":{"ip_address":"150.203.178.175"}}}',solstis)
pause(1)
solstis_query('{"message":{"transmission_id":[9],"op":"move_wave_t","parameters":{"wavelength":[822.40000]}}}',solstis)
pause(1)


%START USER OPTIONS
pid_res=[];
pause(1)
%trying to lock blocks the laser from prefroming an alignment
wait_for_align_before_lock=10; %wait for the alignment to be done before trying to lock the laser
align_setpoint_change=5e3; %realign if the setpoint changes by this much
align_err_thresh=50; %how close the laser needs to be before realigning
resonator_range=20000; %thershold in mhz before it considers doing an etalon search
intv_beam_align=60*10; %how often to do an auto realign (s)
intv_blue_meas=1;           %how often to measure the blue light
ecd_relock_pd_thresh=0.5;%0.65 %min power before relock attempt
ecd_relock_err_thresh=200; %MHzhow close to the set point does the laser have to be to bother relocking the ECD

pid_res.setpt=scan_dat.set_freq_vec(1);%setpt; %max val set pt
if isnan(pid_res.setpt)
    error('probe freq setpoint is nan')
end
pid_res.k_int=-3e-2;
pid_res.k_prop=-5e-4;
pid_res.outlims=[5,95];
pid_res.aw_thresh_range=5e-1; %how far away from the edge aw starts (full range 0-1)
pid_res.int_lim=200;
pid_res.slew_lim=5;
pid_res.dout_lim=10;
pid_res.verbose=0;
intv_res_check=3;
log_dir='Y:\TDC_user\ProgramFiles\my_read_tdc_gui_v1.0.1\dld_output\';


%pid system for the etalon
etl_lock_thresh=2000;%MHZ tolerance about half the step size
pid_etalon=[];
pid_etalon.k_int=5e-5;
pid_etalon.k_prop=1e-6;
pid_etalon.int_lim=200;
pid_etalon.outlims=[1,99];
pid_etalon.slew_lim=5;
pid_etalon.dout_lim=20;
pid_etalon.aw_thresh_range=5;
pid_etalon.initalize=true;


etalon_dac_poly=[0.000000039,-0.000018422,0.511559159,-0.078604797];

%END USER OPTIONS

%initalize timers
time_last_res_check=posixtime(datetime('now'));
intialize_res=true;
intialize_etl=true;
time_last_beam_algin=posixtime(datetime('now'));
scan_dat.time_last_scan_step=inf;
scan_dat.meas_num=scan_dat.set_freq_vec*0;
scan_dat.meas_volt=scan_dat.set_freq_vec*[0,0];
scan_dat.meas_freq=scan_dat.set_freq_vec*0;
scan_dat.res_set=scan_dat.set_freq_vec*0;

scan_idx=0;
realign_now=false;
tic;
time_1=posixtime(datetime('now'));
pause(1e-3)
time_2=time_1;
loop_time=time_2-time_1;
pid_res.aw=1;
%open the log file
fclose('all')
clear('flog')
n=1; %initalize loop counter

while scan_idx<numel(scan_dat.set_freq_vec)
%    try
        if n==1 || mod(n,2e5)==1 %make a new log file
                log_file_str=sprintf('%slog_2p_cal_%s.txt',log_dir,datestr(datetime('now'),'yyyymmddTHHMMSS'));
                if exist('flog','var')
                    log=[];
                    nowdt=datetime('now');
                    log.posix_time=posixtime(nowdt);
                    log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
                    log.new_log=log_file_str;
                    log_str=sprintf('%s\n',jsonencode(log));
                    fprintf(flog,log_str);
                    fclose(flog);
                end
                flog=fopen(log_file_str,'A');
                if flog==-1
                    error('could not open log file')
                end
            end

            if intialize_etl
                intialize_etl=false;
                %set the resonator to the middle of the range
                pid_res.ctr_output=50;
                pid_res.initalize=true;
                solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',pid_res.ctr_output),solstis);
                %unlock res.
               
                %unlock the etalon
                solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"etalon_lock","parameters":{"operation":"off","report":"finished"}}}'),solstis);
                pause(0.1)
                solstis_getResponse(solstis);
                % Get etalon dac pos
                reply=solstis_query('{"message":{"transmission_id":[2],"op":"get_status"}}',solstis);
                reply=jsondecode(reply);
                status=reply.message.parameters;
                etalon_dac=polyval(etalon_dac_poly,status.etalon_voltage);

                solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_etalon","parameters":{"setting":[%.10f],"report":"finished"}}}',etalon_dac),solstis);
                pause(0.5)
                solstis_getResponse(solstis);
                pause(0.5)
                query=sprintf('{"message":{"transmission_id":[2],"op":"etalon_lock","parameters":{"operation":"on","report":"finished"}}}'); 
                solstis_query(query,solstis);
                pause(0.5)
                solstis_getResponse(solstis);
                pause(0.5) 
                log=[];
                nowdt=datetime('now');
                log.posix_time=posixtime(nowdt);
                log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
                log.search_etalon.stage='lock';
                log_str=sprintf('%s\n',jsonencode(log));
                fprintf(flog,log_str);
                intialize_res=true;
            end
            
            freq_red=wmhandle.GetFreq(1);
            pid_res.meas=freq_red;
            pid_res=pid_loop(pid_res); %do pid

            nowdt=datetime('now');
            log_str=sprintf('{"posix_time":%.3f,"iso_time":"%s","feedback":{"setpt":%05.3f,"actual":%05.3f,"Res":%.6f,"Int":%.6f,"slew_lim":%1i}}\n',...
                posixtime(nowdt),datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF'),pid_res.setpt,pid_res.meas,pid_res.ctr_output,pid_res.integrator,pid_res.aw_slew);

            fprintf('RES set %05.3f err %+05.3f MHz Res %02.4f Feedback Freq %04.1f Int %+01.2f slew %+02.2f slewlim %1i \n',...
                [pid_res.setpt,pid_res.error,pid_res.ctr_output,1/pid_res.loop_time,pid_res.integrator,pid_res.slew,pid_res.aw_slew])
            fprintf(flog,log_str); 
            %Send the resonator tune comand
            query=sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',pid_res.ctr_output);
            res_tune_out=solstis_query(query,solstis);

            if numel(res_tune_out)==0
                fprintf('the fucking thing didnt fucking return a fucking message, fuck\n\n\n\')
            end
            
            if n>10 && scan_idx==0 && abs(pid_res.error)<0.2 && abs(pid_res.error)>eps*10
                scan_dat.time_last_scan_step=pid_res.time-scan_step_time; %will start scan in 3s
                fprintf('scan started')
                scan_idx=1;
            end               
            if scan_dat.time_last_scan_step+scan_step_time<pid_res.time
                %fprintf('%f\n',scan_dat.time_last_scan_step+scan_step_time-pid_res.time)
                pid_res.setpt=freq_vec(scan_idx);
                scan_dat.time_last_scan_step=pid_res.time;
                scan_idx=scan_idx+1;
            end
            if scan_idx~=0
                scan_dat.meas_volt(scan_idx,:)=scan_dat.meas_volt(scan_idx,:)+daq_pmt.inputSingleScan;
                scan_dat.meas_num(scan_idx)=scan_dat.meas_num(scan_idx)+1;
                scan_dat.meas_freq(scan_idx)=scan_dat.meas_freq(scan_idx)+pid_res.meas;
                scan_dat.res_set(scan_idx)=scan_dat.res_set(scan_idx)+pid_res.ctr_prev;
            end

                
            %  move the etalon if output is at the end of the operating range of resonator or the
            % error is much larger than the scan range of the resonator
            if pid_res.aw<1e-2  || abs(pid_res.error)>resonator_range
                    fprintf('etalon lock lauched because ')
                    if abs(pid_res.error)>resonator_range
                        fprintf('current error val %.1f MHz\n',abs(pid_res.error))
                    elseif pid_res.aw<1e-2
                        fprintf('pid anti windeup at %.3f \n',pid_res.aw)
                    end
                    pid_res.aw=1;
                    log=[];
                    log.posix_time=posixtime(nowdt);
                    log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
                    log.search_etalon.stage='unlock';
                    log_str=sprintf('%s\n',jsonencode(log));
                    fprintf(flog,log_str);
                    %set the resonator to the middle of the range
                    pid_res.ctr_output=50;
                    pid_res.initalize=true;
                    solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',pid_res.ctr_output),solstis);
                    
                    %unlock the etalon
                    solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"etalon_lock","parameters":{"operation":"off","report":"finished"}}}'),solstis);
                    pause(0.1)
                    solstis_getResponse(solstis);
                    % Get etalon dac pos
                    reply=solstis_query('{"message":{"transmission_id":[2],"op":"get_status"}}',solstis);
                    reply=jsondecode(reply);
                    status=reply.message.parameters;
                    etalon_dac=polyval(etalon_dac_poly,status.etalon_voltage);

                    solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_etalon","parameters":{"setting":[%.10f],"report":"finished"}}}',etalon_dac),solstis);
                    pause(0.1)
                    solstis_getResponse(solstis);
                    %set up the PID loop
                    pid_etalon.integrator=etalon_dac; %reset the integerator so there is no discontinuity
                    pid_etalon.ctr_output=etalon_dac;
                    pid_etalon.time=posixtime(datetime('now')); %prevents over slew
                    pid_etalon.setpt=pid_res.setpt;
                    pid_etalon.aw=1;
                    pid_etalon.loop_time=1;
                    %set the threshold to lock the etalon

                    feedback_etalon=true;
                    brute_search_etalon=false;
                    brute_search_step_size=5;
                    %first lets try a pid feedback for a fast etalon relock
                    while feedback_etalon
                        pid_etalon.meas=wmhandle.GetFreq(1); 
                        pid_etalon=pid_loop(pid_etalon); %do pid
                        solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_etalon","parameters":{"setting":[%.10f],"report":"finished"}}}',pid_etalon.ctr_output),solstis);
                        pause(0.1)
                        solstis_getResponse(solstis);
                        %log this
                        log=[];
                        log.posix_time=posixtime(nowdt);
                        log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
                        log.search_etalon.stage='pid_search';
                        log.search_etalon.feedback.setpt=pid_res.setpt;
                        log.search_etalon.feedback.actual=pid_res.meas;
                        log.search_etalon.feedback.int=pid_res.integrator;
                        log.search_etalon.feedback.etl=pid_res.ctr_output;
                        log_str=sprintf('%s\n',jsonencode(log));
                        fprintf(flog,log_str);
                        fprintf('ETALON set %05.3f err %+05.3f MHz Etl %02.4f Feedback Freq %04.1f Int %+01.2f slew %+02.2f slewlim %1i aw %+02.2f \n',...
                        [pid_etalon.setpt,pid_etalon.error,pid_etalon.ctr_output,1/pid_etalon.loop_time,pid_etalon.integrator,pid_etalon.slew,pid_etalon.aw_slew,pid_etalon.aw])

                        if abs(pid_etalon.error)<etl_lock_thresh 
                            feedback_etalon=false;
                            fprintf('sucess')
                        elseif pid_etalon.aw<1e-2
                            fprintf('ETALON PID FALIURE\n RESORTING TO BRUTE SEARCH\n')
                            pause(0.1) %wait a while 
                            if pid_etalon.error*pid_etalon.k_int<0
                                feedback_etalon=false;
                                pid_etalon.ctr_output=95+brute_search_step_size;
                                brute_search_direction=-1;
                                brute_search_etalon=true;
                            elseif pid_etalon.error*pid_etalon.k_int>0
                                feedback_etalon=false;
                                pid_etalon.ctr_output=5-brute_search_step_size;
                                brute_search_direction=1;
                                brute_search_etalon=true;
                            end
                            %return %end the script if hitting the walls of the etalon tune
                        end
                        pause(0.2);
                    end %etalon_search 
                    %if that falis we just do a brute scan across all the etalon values
                    reduce_step_size=false;
                    while brute_search_etalon
                        pid_etalon.ctr_output=pid_etalon.ctr_output+sign(brute_search_direction)*brute_search_step_size;
                        if brute_search_direction<0 && pid_etalon.ctr_output<2
                            pid_etalon.ctr_output=3;
                            brute_search_direction=1;
                            reduce_step_size=true;
                        elseif brute_search_direction>0 && pid_etalon.ctr_output>98
                            pid_etalon.ctr_output=97;
                            brute_search_direction=-1;
                            reduce_step_size=true;
                        end
                        if reduce_step_size && brute_search_step_size>1e-2 %puts a limit to how small the steps are
                            brute_search_step_size=brute_search_step_size/5;
                            reduce_step_size=false;
                        end

                        solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_etalon","parameters":{"setting":[%.10f],"report":"finished"}}}',pid_etalon.ctr_output),solstis);
                        pause(0.1)
                        solstis_getResponse(solstis);
                        pause(0.05)
                        pid_etalon.meas=wmhandle.GetFreq(1);
                        pid_etalon.error=pid_etalon.meas-pid_etalon.setpt;

                        log=[];
                        log.posix_time=posixtime(nowdt);
                        log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
                        log.search_etalon.stage='brute_search';
                        log.search_etalon.setpt=pid_res.setpt;
                        log.search_etalon.actual=pid_res.meas;
                        log.search_etalon.feedback.etl=pid_res.ctr_output;
                        log_str=sprintf('%s\n',jsonencode(log));
                        fprintf(flog,log_str);
                        fprintf('ETALON set %05.3f err %+09.3f MHz Etl %02.4f step size %02.2f\n',...
                        [pid_etalon.setpt,pid_etalon.error,pid_etalon.ctr_output,brute_search_step_size])

                        if abs(pid_etalon.error)<etl_lock_thresh 
                                brute_search_etalon=false;
                                fprintf('Brute search on etalon SUCESS\n')
                        end
                    end
                    query=sprintf('{"message":{"transmission_id":[2],"op":"etalon_lock","parameters":{"operation":"on","report":"finished"}}}');
                    solstis_query(query,solstis);
                    pause(0.5)
                    solstis_getResponse(solstis);
                    
                    log=[];
                    log.posix_time=posixtime(nowdt);
                    log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
                    log.search_etalon.stage='lock';
                    log_str=sprintf('%s\n',jsonencode(log));
                    fprintf(flog,log_str);
                    realign_now=true;
                    intialize_res=true;
            end
            %realign the laser
            if   (time_last_beam_algin+intv_beam_align <pid_res.time && abs(pid_res.error)<align_err_thresh)  || realign_now 
                solstis_query('{"message":{"transmission_id":[2],"op":"beam_alignment","parameters":{"mode":[4]}}}',solstis);
                %LOG this auto alingment operation
                log=[];
                log.posix_time=posixtime(nowdt);
                log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
                log.beam_alignment=4;
                log_str=sprintf('%s\n',jsonencode(log));
                fprintf(flog,log_str);
                time_last_beam_algin=pid_res.time;
                realign_now=false;
            end 


            n=n+1;
            time_2=posixtime(datetime('now'));
            loop_time=time_2-time_1;
            pause(66e-3-loop_time) %have to slow down or the controller will crash
            time_2=posixtime(datetime('now'));
            loop_time=time_2-time_1;
            time_1=time_2;

%     catch me
%         log=[];
%         log.posix_time=posixtime(nowdt);
%         log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
%         log.feedback_error=getReport( me, 'extended');
%         log_str=sprintf('%s\n',jsonencode(log));
%         fprintf(flog,log_str);
%         warning('!!!!!!!!!!!!!FEEDBACK ERROR restarting from the top!!!!!!!!!!!!!!\n')
%         warning(['err msg',log.feedback_error])
%     end    

end%feedback loop

%%
current_gain=2e7; %V/A
current_gain_disp=current_gain/1e9;
loz3fun_offset_grad = @(b,x) b(1).*((b(2)/2)^2)./((x-b(3)).^2+(b(2)/2)^2) + b(4)+b(5).*x; %lorentzian

response=scan_dat.meas_volt(:,1)./scan_dat.meas_num;
deriv=scan_dat.meas_volt(:,2)./scan_dat.meas_num;
meas_freq_freq=scan_dat.meas_freq./scan_dat.meas_num;
%freq_cen=round(mean(meas_freq_freq)/10)*10;
freq_cen=round(mean(meas_freq_freq));
meas_freq_offset=meas_freq_freq-freq_cen;
cen_est=wmean(meas_freq_offset,-response);
std_est=std(meas_freq_offset,-response);
amp_est=-range(response);
offset_est=mean(response)-amp_est/2;
beta0 = [amp_est,std_est,cen_est,offset_est,0]; %intial guesses
opts = statset('MaxIter',1e3);
%opts.RobustWgtFun = 'welsch' ; %a bit of robust fitting
%opts.Tune = 1;
fit_mean = fitnlm(meas_freq_offset,response,loz3fun_offset_grad,beta0,'Options',opts,...
    'CoefficientNames',{'amp','FWHM','center','offset','grad'});
xplot=linspace(min(meas_freq_offset),max(meas_freq_offset),1e3)';
%xplot=linspace(-50,50,1e3)';
yplot=predict(fit_mean,xplot);
sfigure(1)
clf
set(gcf,'color','w')
subplot(3,1,1)

plot(meas_freq_offset,response/current_gain_disp,'k.')
hold on
plot(xplot,yplot/current_gain_disp,'r');
hold off
title('measuring pmt current')
xlabel(sprintf('Set Point - %.2f (MHz)',freq_cen))
ylabel('PMT Current (nA)')

fprintf('Scan found estimated wavemeter shift as %.2f±%.2f MHz \n',...
    freq_cen+fit_mean.Coefficients.Estimate(3)-transition_freq,...
    fit_mean.Coefficients.SE(3))

subplot(3,1,2)
plot(meas_freq_offset,deriv,'k.')

 %%
 freq_to_res=@(x)  interp1(meas_freq_offset,scan_dat.res_set./scan_dat.meas_num,x);
 subplot(3,1,3)
 plot(meas_freq_offset,scan_dat.res_set./scan_dat.meas_num,'k.')
 xlabel('wm freq')
 ylabel('res valuue')
 hold on
 plot(xplot,freq_to_res(xplot))
 hold off
 %%
 
 pid_res.error=inf;
 pid_res.setpt=scan_center_freq+fit_mean.Coefficients.Estimate(3);
 pid_res.initalize=true;
while abs(pid_res.error)>0.2 || pid_res.error==0
%    try
        if n==1 || mod(n,2e5)==1 %make a new log file
                log_file_str=sprintf('%slog_2p_cal_%s.txt',log_dir,datestr(datetime('now'),'yyyymmddTHHMMSS'));
                if exist('flog','var')
                    log=[];
                    nowdt=datetime('now');
                    log.posix_time=posixtime(nowdt);
                    log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
                    log.new_log=log_file_str;
                    log_str=sprintf('%s\n',jsonencode(log));
                    fprintf(flog,log_str);
                    fclose(flog);
                end
                flog=fopen(log_file_str,'A');
                if flog==-1
                    error('could not open log file')
                end
            end

            freq_red=wmhandle.GetFreq(1);
            pid_res.meas=freq_red;
            pid_res=pid_loop(pid_res); %do pid

            nowdt=datetime('now');
            log_str=sprintf('{"posix_time":%.3f,"iso_time":"%s","feedback":{"setpt":%05.3f,"actual":%05.3f,"Res":%.6f,"Int":%.6f,"slew_lim":%1i}}\n',...
                posixtime(nowdt),datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF'),pid_res.setpt,pid_res.meas,pid_res.ctr_output,pid_res.integrator,pid_res.aw_slew);

            fprintf('RES set %05.3f err %+05.3f MHz Res %02.4f Feedback Freq %04.1f Int %+01.2f slew %+02.2f slewlim %1i \n',...
                [pid_res.setpt,pid_res.error,pid_res.ctr_output,1/pid_res.loop_time,pid_res.integrator,pid_res.slew,pid_res.aw_slew])
            fprintf(flog,log_str); 
            %Send the resonator tune comand
            query=sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',pid_res.ctr_output);
            res_tune_out=solstis_query(query,solstis);

            if numel(res_tune_out)==0
                fprintf('the fucking thing didnt fucking return a fucking message, fuck\n\n\n\')
            end

            n=n+1;
            time_2=posixtime(datetime('now'));
            loop_time=time_2-time_1;
            pause(66e-3-loop_time) %have to slow down or the controller will crash
            time_2=posixtime(datetime('now'));
            loop_time=time_2-time_1;
            time_1=time_2;

%     catch me
%         log=[];
%         log.posix_time=posixtime(nowdt);
%         log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
%         log.feedback_error=getReport( me, 'extended');
%         log_str=sprintf('%s\n',jsonencode(log));
%         fprintf(flog,log_str);
%         warning('!!!!!!!!!!!!!FEEDBACK ERROR restarting from the top!!!!!!!!!!!!!!\n')
%         warning(['err msg',log.feedback_error])
%     end    

end%feedback loop



%   Lock to the center of the 2p peak
%  % log file is used from above
% 

set_voltage_pmt=fit_mean.Coefficients.Estimate(4)+fit_mean.Coefficients.Estimate(1)/2;
set_voltage_lock_in=0;
pid_res.setpt=set_voltage_lock_in;
pid_res.k_int=1e-3;
pid_res.k_prop=9e-5;
pid_res.outlims=[5,95];
pid_res.aw_thresh_range=5e-1; %how far away from the edge aw starts (full range 0-1)
pid_res.int_lim=200;
pid_res.slew_lim=1;
pid_res.dout_lim=1;
pid_res.verbose=0;
intv_res_check=3;
pid_res.ctr_output=pid_res.ctr_output; %use output from freq find lock above
pid_res.initalize=true;

query=sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',pid_res.ctr_output);
res_tune_out=solstis_query(query,solstis);
pause(0.1) 

%%
pid_res.initalize=true;

time_1=posixtime(datetime('now'));
pause(1e-3)
time_2=time_1;
loop_time=time_2-time_1;
ii=1;
 while true
    pmt_voltage=daq_pmt.inputSingleScan;
    pid_res.meas=pmt_voltage(2);
    pid_res=pid_loop(pid_res); %do pid
    nowdt=datetime('now');
    log_str=sprintf('{"posix_time":%.3f,"iso_time":"%s","feedback":{"setpt":%05.3f,"actual":%05.3f,"Res":%.6f,"Int":%.6f,"slew_lim":%1i}}\n',...
        posixtime(nowdt),datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF'),pid_res.setpt,pid_res.meas,pid_res.ctr_output,pid_res.integrator,pid_res.aw_slew);
    fprintf('RES set %05.3f err %+05.2fV Curr %+5.2fna Res %02.4f Feedback Freq %04.1f Int %+01.2f slew %+02.2f slewlim %1i \n',...
        [pid_res.setpt,pid_res.error,pmt_voltage(1)/current_gain_disp,pid_res.ctr_output,1/pid_res.loop_time,pid_res.integrator,pid_res.slew,pid_res.aw_slew])
    fprintf(flog,log_str); 

    %Send the resonator tune comand
    query=sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',pid_res.ctr_output);
    res_tune_out=solstis_query(query,solstis);
    %pause(time_between_deriv) 
    if numel(res_tune_out)==0
        fprintf('the fucking thing didnt fucking return a fucking message, fuck\n\n\n\')
    end

    ii=ii+1;
    time_2=posixtime(datetime('now'));
    loop_time=time_2-time_1;
    pause(2e-3-loop_time) %have to slow down or the controller will crash
    time_2=posixtime(datetime('now'));
    loop_time=time_2-time_1;
    time_1=time_2;
 end
 



%%


%  %% Lock to the side of the 2p peak
%  % log file is used from above
% 
%  set_voltage_pmt=fit_mean.Coefficients.Estimate(4)+fit_mean.Coefficients.Estimate(1)/2;
% pid_res.setpt=set_voltage_pmt;
% pid_res.k_int=1e-1;
% pid_res.k_prop=5e-4;
% pid_res.outlims=[5,95];
% pid_res.aw_thresh_range=5e-1; %how far away from the edge aw starts (full range 0-1)
% pid_res.int_lim=200;
% pid_res.slew_lim=1;
% pid_res.dout_lim=1;
% pid_res.verbose=0;
% intv_res_check=3;
% pid_res.ctr_output=freq_to_res(fit_mean.Coefficients.Estimate(3)-fit_mean.Coefficients.Estimate(2)/2);
% pid_res.initalize=true;
% %pid_res=pid_loop(pid_res); %do pid
% 
% %     nowdt=datetime('now');
% %     log_str=sprintf('{"posix_time":%.3f,"iso_time":"%s","feedback":{"setpt":%05.3f,"actual":%05.3f,"Res":%.6f,"Int":%.6f,"slew_lim":%1i}}\n',...
% %         posixtime(nowdt),datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF'),pid_res.setpt,pid_res.meas,pid_res.ctr_output,pid_res.integrator,pid_res.aw_slew);
% % 
% %     fprintf('RES set %05.3f err %+05.3f MHz Res %02.4f Feedback Freq %04.1f Int %+01.2f slew %+02.2f slewlim %1i \n',...
% %         [pid_res.setpt,pid_res.error,pid_res.ctr_output,1/pid_res.loop_time,pid_res.integrator,pid_res.slew,pid_res.aw_slew])
% %     fprintf(flog,log_str); 
% %     %Send the resonator tune comand
% 
% 
% query=sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',pid_res.ctr_output);
% res_tune_out=solstis_query(query,solstis);
% 
% time_1=posixtime(datetime('now'));
% pause(1e-3)
% time_2=time_1;
% loop_time=time_2-time_1;
% ii=1;
%  while true
%     pmt_voltage=daq_pmt.inputSingleScan;
%     pid_res.meas=pmt_voltage;
%     pid_res=pid_loop(pid_res); %do pid
%     nowdt=datetime('now');
%     log_str=sprintf('{"posix_time":%.3f,"iso_time":"%s","feedback":{"setpt":%05.3f,"actual":%05.3f,"Res":%.6f,"Int":%.6f,"slew_lim":%1i}}\n',...
%         posixtime(nowdt),datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF'),pid_res.setpt,pid_res.meas,pid_res.ctr_output,pid_res.integrator,pid_res.aw_slew);
%     fprintf('RES set %05.3f err %+05.3f V Res %02.4f Feedback Freq %04.1f Int %+01.2f slew %+02.2f slewlim %1i \n',...
%         [pid_res.setpt,pid_res.error,pid_res.ctr_output,1/pid_res.loop_time,pid_res.integrator,pid_res.slew,pid_res.aw_slew])
%     fprintf(flog,log_str); 
% 
%     %Send the resonator tune comand
%     query=sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',pid_res.ctr_output);
%     res_tune_out=solstis_query(query,solstis);
%     %pause(time_between_deriv) 
%     if numel(res_tune_out)==0
%         fprintf('the fucking thing didnt fucking return a fucking message, fuck\n\n\n\')
%     end
% 
%     ii=ii+1;
%     time_2=posixtime(datetime('now'));
%     loop_time=time_2-time_1;
%     pause(66e-3-loop_time) %have to slow down or the controller will crash
%     time_2=posixtime(datetime('now'));
%     loop_time=time_2-time_1;
%     time_1=time_2;
%  end
%  
% %%
% sfigure(2)
% clf
% set(gcf,'color','w')
% subplot(2,1,1)
% plot( deriv_scan.freq_set,deriv_scan.meas_deriv./(deriv_scan.meas_num*deriv_dres),'k.')
% ylabel('deriv V/Res')
% subplot(2,1,2)
% plot(deriv_scan.freq_set,deriv_scan.meas_volt./(deriv_scan.meas_num),'k.')
% ylabel('mean')
%  
%  
 

 
 
 
 %%
%  deriv_scan=[];
%  %deriv_scan_cen= freq_to_res(fit_mean.Coefficients.Estimate(3));
%  deriv_scan_hwhm_pos=freq_to_res(fit_mean.Coefficients.Estimate(3)+fit_mean.Coefficients.Estimate(2));
%  deriv_scan_hwhm_neg=freq_to_res(fit_mean.Coefficients.Estimate(3)-fit_mean.Coefficients.Estimate(2));
%  deriv_dres=(deriv_scan_hwhm_pos-deriv_scan_hwhm_neg);
%  deriv_scan.freq_set=freq_cen+linspace(-fit_mean.Coefficients.Estimate(2)*2,fit_mean.Coefficients.Estimate(2)*2,10);
%  deriv_scan.vderiv=deriv_scan.freq_set*0;
%   deriv_scan.vmean=deriv_scan.freq_set*0;
%  
%  %% Scan over the resonance and take the derivative
%  % log file is used from above
% 
%      %pid_res=pid_loop(pid_res); %do pid
% 
% %     nowdt=datetime('now');
% %     log_str=sprintf('{"posix_time":%.3f,"iso_time":"%s","feedback":{"setpt":%05.3f,"actual":%05.3f,"Res":%.6f,"Int":%.6f,"slew_lim":%1i}}\n',...
% %         posixtime(nowdt),datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF'),pid_res.setpt,pid_res.meas,pid_res.ctr_output,pid_res.integrator,pid_res.aw_slew);
% % 
% %     fprintf('RES set %05.3f err %+05.3f MHz Res %02.4f Feedback Freq %04.1f Int %+01.2f slew %+02.2f slewlim %1i \n',...
% %         [pid_res.setpt,pid_res.error,pid_res.ctr_output,1/pid_res.loop_time,pid_res.integrator,pid_res.slew,pid_res.aw_slew])
% %     fprintf(flog,log_str); 
% %     %Send the resonator tune comand
% 
% deriv_averages=5;
% time_between_deriv=5e-3;
% voltage_pos=0;
% voltage_neg=0;
% time_1=posixtime(datetime('now'));
% pause(1e-3)
% time_2=time_1;
% loop_time=time_2-time_1;
% scan_idx=0;
% pid_res.initalize=true;
% pid_res.setpt= deriv_scan.freq_set(1);
% pid_res.meas=wmhandle.GetFreq(1);
% weighting=linspace(1,0,10);
% weighting=weighting/sum(weighting);
% deriv_scan.time_last_scan_step=inf;
% deriv_scan.meas_volt=deriv_scan.freq_set*0;
% deriv_scan.meas_deriv=deriv_scan.freq_set*0;
% deriv_scan.meas_num=deriv_scan.freq_set*0;
% deriv_scan.meas_freq=deriv_scan.freq_set*0;
% deriv_scan.res_set=deriv_scan.freq_set*0;
% scan_step_time=2;
% ii=1;
%  while scan_idx<=numel(deriv_scan.freq_set)
%     inc_sign=(mod(ii,2)-0.5)*2;
%     if mod(ii,2)~=0
%         freq_red=wmhandle.GetFreq(1);
%         pid_res.meas=freq_red;
%         pid_res=pid_loop(pid_res); %do pid
%         nowdt=datetime('now');
%         log_str=sprintf('{"posix_time":%.3f,"iso_time":"%s","feedback":{"setpt":%05.3f,"actual":%05.3f,"Res":%.6f,"Int":%.6f,"slew_lim":%1i}}\n',...
%             posixtime(nowdt),datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF'),pid_res.setpt,pid_res.meas,pid_res.ctr_output,pid_res.integrator,pid_res.aw_slew);
%         fprintf('RES set %05.3f err %+05.3f MHz Res %02.4f Feedback Freq %04.1f Int %+01.2f slew %+02.2f slewlim %1i \n',...
%             [pid_res.setpt,pid_res.error,pid_res.ctr_output,1/pid_res.loop_time,pid_res.integrator,pid_res.slew,pid_res.aw_slew])
%         fprintf(flog,log_str); 
%     end
%     %Send the resonator tune comand
%     query=sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',pid_res.ctr_output+inc_sign*deriv_dres);
%     res_tune_out=solstis_query(query,solstis);
%     %pause(time_between_deriv) 
%     if numel(res_tune_out)==0
%         fprintf('the fucking thing didnt fucking return a fucking message, fuck\n\n\n\')
%     end
% 
%     if scan_idx==0 && abs(pid_res.error)<0.2 && abs(pid_res.error)~=0
%         deriv_scan.time_last_scan_step=pid_res.time; %will start scan in 3s
%         fprintf('scan started')
%         scan_idx=1;
%     end         
%     if scan_idx~=0
%         volt_single=daq_pmt.inputSingleScan;
%         deriv_scan.meas_deriv(scan_idx)=deriv_scan.meas_deriv(scan_idx)+inc_sign*volt_single;
%         deriv_scan.meas_volt(scan_idx)=deriv_scan.meas_volt(scan_idx)+volt_single;
%         deriv_scan.meas_num(scan_idx)=deriv_scan.meas_num(scan_idx)+1;
%         deriv_scan.meas_freq(scan_idx)=deriv_scan.meas_freq(scan_idx)+pid_res.meas;
%         deriv_scan.res_set(scan_idx)=deriv_scan.res_set(scan_idx)+pid_res.ctr_prev;
%     end
%     if deriv_scan.time_last_scan_step+scan_step_time<pid_res.time && mod(ii,2)~=0 %enforce even number of evaluations
%         fprintf('%f\n',deriv_scan.time_last_scan_step+scan_step_time-pid_res.time)
%         pid_res.setpt=deriv_scan.freq_set(scan_idx);
%         deriv_scan.time_last_scan_step=pid_res.time;
%         scan_idx=scan_idx+1;
%     end
% 
%     ii=ii+1;
%     
%     
% %     if mod(jj,deriv_averages*2)==0
% %         jj=0;
% %         ii=ii+1;
% %     end
% %     
% %     query=sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}', deriv_scan.res_set(ii)+deriv_dres*inc_sign);
% %     res_tune_out=solstis_query(query,solstis);
% %     if numel(res_tune_out)==0
% %         fprintf('the fucking thing didnt fucking return a fucking message, fuck\n\n\n\')
% %     end
% %     pause(time_between_deriv)
% %     voltage=daq_pmt.inputSingleScan
% %     deriv_scan.vderiv(ii)=deriv_scan.vderiv(ii)+voltage*inc_sign;
% %     deriv_scan.vmean(ii)=deriv_scan.vmean(ii)+voltage;
% %     
% %     jj=jj+1;
% 
%     time_2=posixtime(datetime('now'));
%     loop_time=time_2-time_1;
%     pause(66e-3-loop_time) %have to slow down or the controller will crash
%     time_2=posixtime(datetime('now'));
%     loop_time=time_2-time_1;
%     time_1=time_2;
%  end
%  
% %%
% sfigure(2)
% clf
% set(gcf,'color','w')
% subplot(2,1,1)
% plot( deriv_scan.freq_set,deriv_scan.meas_deriv./(deriv_scan.meas_num*deriv_dres),'k.')
% ylabel('deriv V/Res')
% subplot(2,1,2)
% plot(deriv_scan.freq_set,deriv_scan.meas_volt./(deriv_scan.meas_num),'k.')
% ylabel('mean')
%  
 %% CLEAN UP
%  solstis = instrfind('tag','solstis');
% delete(solstis)
% delete(daq_pmt)


 
 
        %solstis_query('{"message":{"transmission_id":[2],"op":"ping","parameters":{"text_in":"LetsDoThis"}}}')
        %solstis_query('{"message":{"transmission_id":[2],"op":"fine_tune_resonator","parameters":{"setting":[0]}}}');
        %pause(0.5)
        %solstis_query('{"message":{"transmission_id":[2],"op":"fine_tune_resonator","parameters":{"setting":[100]}}}');
        %pause(0.5)
        %solstis_query('{"message":{"transmission_id":[2],"op":"fine_tune_resonator","parameters":{"setting":[50]}}}')

        
%         status=jsondecode(solstis_query('{"message":{"transmission_id":[2],"op":"get_status"}}',solstis));
%         status=status.message.parameters;
%         res_voltage=status.resonator_voltage;
%         %rescale the reading in volts to the control voltage in %
%         res_slow_dac=polyval([0.00000006007743282452 -0.00002630543053390512 0.00404787545023589396 0.27097607207749069280 3.44975464072533588578 ],res_voltage);
%         query=sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%3.10f]}}}',res_slow_dac);
        %solstis_query(query,[]);
