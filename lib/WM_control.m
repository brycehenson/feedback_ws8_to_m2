function ret = WM_control(method_key)
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

if method_key ==1 %Simulates the run counter
   while 1
       try
           t = tcpip('localhost',33333,'NetworkRole','client');
           fopen(t)
           setpt = fread(t,1,'double');
           fclose(t)   
           labSend(setpt,2);
           %disp('TCP sucess')
       catch
%                disp('TCP failure')
       end
   end
   ret = 0;
elseif method_key==2 %feedback loop!
    try
    %intialize connection
    wmhandle=WLM.getInstance();
    solstis_clearBuffer();
    solstis=solstis_findInstrument;
    solstis_query('{"message":{"transmission_id":[9],"op":"start_link","parameters":{"ip_address":"150.203.178.175"}}}',solstis)
    pause(1)
    solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"etalon_lock","parameters":{"operation":"on","report":"finished"}}}'),solstis);
    pause(0.1)
    solstis_getResponse(solstis);        
    %solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',50),solstis)

    %START USER OPTIONS
    pid_res=[];
    pause(1)
    resonator_range=20000; %thershold in mhz before it considers doing an etalon search
    intv_beam_align=60*10; %how often to do an auto realign (s)
    intv_blue_meas=1;           %how often to measure the blue light
    ecd_relock_pd_thresh=0.7;
    ecd_relock_err_thresh=100; %MHzhow close to the set point does the laser have to be to bother relocking the ECD
    pid_res.setpt=wmhandle.GetFreq(1);%setpt; %max val set pt
    pid_res.k_int=-1e-2;
    pid_res.k_prop=5e-4;
    pid_res.outlims=[5,95];
    pid_res.aw_thresh_range=5e-3; %how far away from the edge aw starts (full range 0-1)
    pid_res.int_lim=200;
    pid_res.slew_lim=20;
    intv_res_check=3;
    log_dir='Y:\TDC_user\ProgramFiles\my_read_tdc_gui_v1.0.1\dld_output\';

    %pid system for the etalon
    pid_etalon=[];
    pid_etalon.k_int=1e-4;
    pid_etalon.k_prop=1e-5;
    pid_etalon.int_lim=200;
    pid_etalon.outlims=[1,99];
    pid_etalon.slew_lim=10;
    pid_etalon.aw_thresh_range=5e-2;

    %END USER OPTIONS

    %initalize timers
    time_last_res_check=posixtime(datetime('now'));
    intialize_res=true;
    intialize_etl=true;
    time_last_beam_algin=posixtime(datetime('now'));
    time_last_blue_meas=posixtime(datetime('now'));
    realign_now=false;
    tic;
    time_1=posixtime(datetime('now'));
    pause(1e-3)
    time_2=time_1;
    loop_time=time_2-time_1;
    pid_res.aw=1;
    %open the log file
    fclose('all')
    n=1; %initalize loop counter
    while true
        if n==1 || mod(n,2e5)==1 %make a new log file
            log_file_str=sprintf('%slog_wm_%s.txt',log_dir,datestr(datetime('now'),'yyyymmddTHHMMSS'));
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
        end

        if intialize_etl
            intialize_etl=false;
            %set the resonator to the middle of the range
            solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',50),solstis);
            %unlock res.
            solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"ecd_lock","parameters":{"operation":"off","report":"finished"}}}'),solstis);
            pause(0.1)
            solstis_getResponse(solstis); %wait unitll it says its done with the res. unlock
            %unlock the etalon
            solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"etalon_lock","parameters":{"operation":"off","report":"finished"}}}'),solstis);
            pause(0.1)
            solstis_getResponse(solstis);
            % Get etalon dac pos
            reply=solstis_query('{"message":{"transmission_id":[2],"op":"get_status"}}',solstis);
            reply=jsondecode(reply);
            status=reply.message.parameters;
            etalon_dac=polyval([0.0000000380,-0.0000179883,0.5115165165,-0.0782913954],status.etalon_voltage);

            solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_etalon","parameters":{"setting":[%.10f],"report":"finished"}}}',etalon_dac),solstis);
            pause(0.5)
            solstis_getResponse(solstis);
            pause(0.5)
            query=sprintf('{"message":{"transmission_id":[2],"op":"etalon_lock","parameters":{"operation":"on","report":"finished"}}}'); 
            solstis_query(query,solstis);
            pause(0.5)
            solstis_getResponse(solstis);
            pause(0.5)
            query=sprintf('{"message":{"transmission_id":[2],"op":"ecd_lock","parameters":{"operation":"on","report":"finished"}}}');
            solstis_query(query,solstis);
            pause(1)
            solstis_getResponse(solstis);
            log=[];
            nowdt=datetime('now');
            log.posix_time=posixtime(nowdt);
            log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
            log.search_etalon.stage='lock';
            log_str=sprintf('%s\n',jsonencode(log));
            fprintf(flog,log_str);
            intialize_res=true;
        end

        if intialize_res
            intialize_res=false;
            realign_now=true;
            stat_read_raw=solstis_query('{"message":{"transmission_id":[2],"op":"get_status"}}',solstis);
            stat_struct=jsondecode(stat_read_raw);
            stat_struct=stat_struct.message.parameters;
            nowdt=datetime('now');
            %LOG this status read
            log=[];
            log.posix_time=posixtime(nowdt);
            log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
            log.get_status=stat_struct;
            log_str=sprintf('%s\n',jsonencode(log));
            fprintf(flog,log_str);

            if isfield(stat_struct,'resonator_voltage') 
            res_voltage=stat_struct.resonator_voltage;
            %rescale the reading in volts to the control voltage in teh DAC % values
            res_slow_dac=polyval([0.00000006007743282452 -0.00002630543053390512 0.00404787545023589396 0.27097607207749069280 3.44975464072533588578 ],res_voltage);
            pid_res.integrator=res_slow_dac; %reset the integerator so there is no discontinuity
            pid_res.ctr_output=res_slow_dac;
            pid_res.time=posixtime(datetime('now')); %prevents over slew
            pid_res.loop_time=1;
            %set the DAC
            solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',res_slow_dac),solstis)
            %LOG this resonator set
            log=[];
            log.posix_time=posixtime(nowdt);
            log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
            log.tune_resonator=res_slow_dac;
            log_str=sprintf('%s\n',jsonencode(log));
            fprintf(flog,log_str);
            else
                intialize_res=true;
                stat_read_raw
                solstis_clearBuffer();
            end

        end
        try %Check for new set point
            if labProbe
                data = labReceive(1);
                if data ~=pid_res.setpt
                    %disp(['Data received, ',num2str(data)])
                    pid_res.setpt = data; %get set point from server
                else
                    %disp('Data received, no change')
                end
            else
                %disp('No signal')
            end
        catch
            %disp('Transmission error')
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

        %  move the etalon if output is at the end of the operating range of resonator or the
        % error is much larger than the scan range of the resonator
        if pid_res.aw<1e-2  || abs(pid_res.error)>resonator_range
                pid_res.aw=1;
                log=[];
                log.posix_time=posixtime(nowdt);
                log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
                log.search_etalon.stage='unlock';
                log_str=sprintf('%s\n',jsonencode(log));
                fprintf(flog,log_str);
                %set the resonator to the middle of the range
                solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',50),solstis);
                %unlock res.
                solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"ecd_lock","parameters":{"operation":"off","report":"finished"}}}'),solstis);
                pause(0.1)
                solstis_getResponse(solstis); %wait unitll it says its done with the res. unlock
                %unlock the etalon
                solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"etalon_lock","parameters":{"operation":"off","report":"finished"}}}'),solstis);
                pause(0.1)
                solstis_getResponse(solstis);
                % Get etalon dac pos
                reply=solstis_query('{"message":{"transmission_id":[2],"op":"get_status"}}',solstis);
                reply=jsondecode(reply);
                status=reply.message.parameters;
                etalon_dac=polyval([0.0000000380,-0.0000179883,0.5115165165,-0.0782913954],status.etalon_voltage);

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
                etl_lock_thresh=1000;%MHZ tolerance about half the step size
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
                    pause(0.08);
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
                pause(0.5)
                query=sprintf('{"message":{"transmission_id":[2],"op":"ecd_lock","parameters":{"operation":"on","report":"finished"}}}');
                solstis_query(query,solstis);
                pause(1)
                solstis_getResponse(solstis);
                log=[];
                log.posix_time=posixtime(nowdt);
                log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
                log.search_etalon.stage='lock';
                log_str=sprintf('%s\n',jsonencode(log));
                fprintf(flog,log_str);
                intialize_res=true;
        end
        %measures the blue light
        if  time_last_blue_meas+intv_blue_meas <pid_res.time
            freq_blue=wmhandle.GetFreq(2); 
            log=[];
            log.posix_time=posixtime(nowdt);
            log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
            log.blue_freq=freq_blue;
            log_str=sprintf('%s\n',jsonencode(log));
            fprintf(flog,log_str);
            time_last_blue_meas=pid_res.time;
            fprintf('BLUE M  %05.3f, 2r-b %05.3f\n',freq_blue,freq_red*2-freq_blue)
        end
        %realign the laser
        if  time_last_beam_algin+intv_beam_align <pid_res.time || realign_now
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

        %check the status of the laser ECD output and if bad relock
        if time_last_res_check+intv_res_check<pid_res.time && abs(pid_res.error)<ecd_relock_err_thresh
            time_last_res_check=pid_res.time; %change the last check time
            unlock=true; %go through check at least once
            res_lock_attempts=0;
            while unlock  
                %'{"message":{"transmission_id":[9714],"op":"ecd_lock_f_r","parameters":{"report":[0]}}}'
                pause(0.1);
                stat_read_raw=solstis_query('{"message":{"transmission_id":[2],"op":"get_status"}}',solstis); %TO DO NEED TO GRACEFULLY HANDLE NO OUTPUT!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                stat_struct=jsondecode(stat_read_raw);
                stat_struct=stat_struct.message.parameters;
                if isfield(stat_struct,'etalon_lock')
                  etl_status=stat_struct.etalon_lock;
                    %LOG this status read
                    nowdt=datetime('now');
                    log=[];
                    log.posix_time=posixtime(nowdt);
                    log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
                    log.get_status=stat_struct;
                    log_str=sprintf('%s\n',jsonencode(log));
                    fprintf(flog,log_str);
                else
                    stat_read_raw
                    solstis_clearBuffer();
                end

                %read and log all the adc
                response=jsondecode(solstis_query('{"message":{"transmission_id":[2],"op":"read_all_adc"}}',solstis));
                log=[];
                log.posix_time=posixtime(nowdt);
                log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
                log.read_all_adc=response.message.parameters;
                log_str=sprintf('%s\n',jsonencode(log));
                fprintf(flog,log_str);
                if isfield(response.message.parameters,'value10')
                    ecd_voltage=response.message.parameters.value10;
                else
                    ecd_voltage=nan;
                     solstis_clearBuffer();
                end
                if ~isequal(etl_status,'on')
                    query=sprintf('{"message":{"transmission_id":[2],"op":"etalon_lock","parameters":{"operation":"on","report":"finished"}}}');
                    solstis_query(query,solstis);
                    pause(0.1)
                    solstis_getResponse(solstis);
                    pause(0.5)

                     log=[];
                    log.posix_time=posixtime(nowdt);
                    log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
                    log.etl_lock='on';
                    log_str=sprintf('%s\n',jsonencode(log));
                    fprintf(flog,log_str);

                end
                if ecd_voltage<ecd_relock_pd_thresh
                    res_lock_attempts=res_lock_attempts+1;
                    if res_lock_attempts>4 %try a random postion to relock the resonator
                        solstis_query(sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%.10f]}}}',round(rand(1)*100)),solstis);
                        pause(1)
                        fprintf('trying relock of ECD at random location !!!!!!!!!!!!!!\n')
                    end
                    fprintf('\n need relock... unlocking...\n')
                    query=sprintf('{"message":{"transmission_id":[2],"op":"ecd_lock","parameters":{"operation":"off","report":"finished"}}}');
                    solstis_query(query,solstis);


                    log=[];
                    log.posix_time=posixtime(nowdt);
                    log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
                    log.ecd_lock='off';
                    log_str=sprintf('%s\n',jsonencode(log));
                    fprintf(flog,log_str);
                    pause(0.1)
                    solstis_getResponse(solstis);
                    pause(0.5)
                    query=sprintf('{"message":{"transmission_id":[2],"op":"ecd_lock","parameters":{"operation":"on","report":"finished"}}}');
                    solstis_query(query,solstis);

                    log=[];
                    log.posix_time=posixtime(nowdt);
                    log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
                    log.ecd_lock='on';
                    log_str=sprintf('%s\n',jsonencode(log));
                    fprintf(flog,log_str);
                    pause(2)

                    solstis_getResponse(solstis);
                    fprintf('\nlocked...\n')  
                    pause(1)
                    intialize_res=true;
                    pid_res.time=posixtime(datetime('now')); %prevents over slew
                else
                    unlock=false;
                end
            end
        end%check the status of the laser ECD output

        n=n+1;
        time_2=posixtime(datetime('now'));
        loop_time=time_2-time_1;
        pause(66e-3-loop_time) %have to slow down or the controller will crash
        time_2=posixtime(datetime('now'));
        loop_time=time_2-time_1;
        time_1=time_2;
    end%feedback loop

    solstis = instrfind('tag','solstis');
    delete(solstis)
    ret=0;
    catch me
        log=[];
        log.posix_time=posixtime(nowdt);
        log.iso_time=datestr(nowdt,'yyyy-mm-ddTHH:MM:SS.FFF');
        log.feedback_error=getReport( me, 'extended');
        log_str=sprintf('%s\n',jsonencode(log));
        fprintf(flog,log_str);
        warning('!!!!!!!!!!!!!FEEDBACK ERROR restarting from the top!!!!!!!!!!!!!!\n')
        warning(['err msg',log.feedback_error])
    end
else
    ret = 0;
end
end


 %%
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
