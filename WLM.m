classdef (Sealed) WLM < handle

%{
    Singleton class for a WS6 or WS7 High Finesse wavemeter object. It allows for the readout of
    the WLM in either nm or MHz, regulates the exposure time and if
    necessary, creates parallel workers to allow for toggling of the
    wavemeter channel without blocking matlab execution.
%}
    
    properties
        WL % Last measured wavelength value
        freq % Last measured frequency value
        %% Uncomment to enable channel switching
%         pool % Parallel worker pool 
        toggling = 'off'
        parf % Parallel function handle
        timeout = 0.5; % timeout for wavelength or frequency measurement.
    end
    
    properties (Access = private)
        ar % Struct containing the argument name strings from WLM header
        active_channel = -1 % Number of channel that is read out by wavemeter
        num_channels = 2 % Number of input channels of wavemeter
    end
    
    % Regulate that only 1 instance of WLM can exist with a class-wide,
    % static method
    methods (Static)
        % The "effective" constructor, called as WLM.getInstance
        function wlm = getInstance()
            persistent WLMRef
            if isempty(WLMRef) || ~isvalid(WLMRef)
                WLMRef = WLM();
            end
            wlm = WLMRef;
        end
    end
    
    methods (Access = private)
        
        % Constructor (can only be called by the static getInstance
        % function)
        function obj = WLM()
            % Create a pool of parallel workers, to be able to use the
            % Wavemeter in parallel with other objects (only necessary for
            % some functions).
   %% Uncomment to enable channel switching
%             obj.pool = CreateParPool(obj);
%             spmd
%                 % fill in location of wlmData library.
%                 if ~libisloaded('wlmData')
%                     loadlibrary C:\Windows\System32\wlmData.dll wlmData.hml
%                 end
%             end
            
            
            % fill in location of wlmData library.
            if ~libisloaded('wlmData')
                loadlibrary C:\Windows\System32\wlmData.dll wlmData.hml
            end

            % Generate struct with argument names from wlmData.hml.
            % Read all the lines in the header file wlmData.hml into the cell 
            % "header".
            header = textread('wlmData.hml','%s','delimiter','\n');
            % Loop over all the lines, filling up the argument-struct named "ar".
            for lines=1:length(header)
                % Check if each line defines a constant, beginning with "const".
                % Sum to turn [] into 0. 0 means no argument on line n, 1 the
                % opposite.
                if sum(regexp(header{lines},'([c]onst\s)')); % [c] is c, cap-sensitive
                    str = header{lines};
                    % Find the name start, coming right after the tab delimiter.
                    startname = regexp(str,'\t')+1;
                    % Find the name end, before some number of spaces, after
                    % namestart.
                    endname = regexp(str,'\s+')-1;
                    endname = min(endname(endname>startname));
                    % Define the name of the argument.
                    name = str(startname:endname);
                    val = str2double(str((regexp(str,'= ')+1):(regexp(str,';')-1)));
                    obj.ar.(name) = val;
                end 
            end

            % Instantiate the WaitForWLMEvent function (see WLM manual)
            calllib('wlmData','Instantiate',...
                obj.ar.cInstNotification,obj.ar.cNotifyInstallWaitEvent,-1,0);

            % Set the redoing of the interferometer pattern to "fuzzy", i.e. "fast",
            % so that it spends less time calculating the exact details of the
            % interferometer display. This does not affect the actual data, just the
            % displaying of it.
            calllib('wlmData','SetFastMode',1);         
            obj.num_channels = calllib('wlmData','GetChannelsCount',0);
            for i = 1:1:obj.num_channels
                calllib('wlmData','SetExposureModeNum',i,true);
            end

        end
        
        % Sub-method, identical for either getting WL or freq
        function [WL, freq] = ReadWLM(obj, what, channel)
            timer = tic;
            freq = nan;
            WL = nan;
            
            SwitchToChannel(obj,channel);
            
            while (~strcmp(what, 'WLM')  && isnan(freq)) || ...
                  (~strcmp(what, 'freq') && isnan(WL))

                % Order wavemeter to do a measurement, wait for it to finish
                % writing a new Fizeau diagram, and return the result.
                dummy1 = 0;
                dummy2 = 0;
                calllib('wlmData','TriggerMeasurement', ...
                    obj.ar.cCtrlMeasurementTriggerSuccess);
                calllib('wlmData','WaitForWLMEvent', ...
                    obj.ar.cmiPatternAnalysisWritten, dummy1, dummy2);
                if strcmp(what, 'WLM') || strcmp(what, 'both')
                    WL = calllib('wlmData','GetWavelengthNum',channel,0);
                else
                    WL = nan;
                end
                if strcmp(what, 'freq') || strcmp(what, 'both')
                    freq = calllib('wlmData','GetFrequencyNum',channel,0);
                else
                    freq = nan;
                end
                
                % If returns underexposed (-3) or overexposed (-4), wait for automatic
                % adjustment of exposuretime
                if freq==-3 || WL==-3
                    pauseJava(0.02)
                    freq = nan;
                    WL = nan;
                elseif freq==-4 || WL ==-4
                    pauseJava(0.02)
                    freq = nan;
                    WL = nan;
                end
                
                % Check if timeout has reached.
                if toc(timer) > obj.timeout
                    disp('Wavemeter TimeOut.')
                    break
                end
            end
            calllib('wlmData','TriggerMeasurement',obj.ar.cCtrlMeasurementContinue);
            obj.WL = WL;
            obj.freq = freq;
        end
        
        % Create a pool with workers for parallel processing
        function pool = CreateParPool(~)
            if isempty(gcp('nocreate'))
                pool = parpool('local',1);
            else
                pool = gcp();
            end
        end
        
        function ParToggle(obj,channels,time)
            while 1
                for i = channels
                    SwitchToChannel(obj,i);
                    pauseJava(time);
                end
            end
        end
        
    end
        
    methods (Access = public)
        
        % Switch active wavemeter channel
        function SwitchToChannel(obj,channel)
            if channel ~= obj.active_channel;
                calllib('wlmData','SetActiveChannel',3,1,channel,0);
                obj.active_channel = channel;
                %pauseJava(0.01)
            end
        end
        
        % Toggle channels for simultaneous locking of multiple lasers.
        function ToggleChannels(obj,channels,time,onOffStr)
            if strcmp(onOffStr,'on') && strcmp(obj.toggling,'off')
                obj.pool = CreateParPool(obj);
                obj.parf = parfeval(obj.pool,@obj.ParToggle,0,channels,time);
                obj.toggling = 'on';
                disp('Toggling of wavemeter channels turned ON.')
            elseif strcmp(onOffStr,'off') && strcmp(obj.toggling,'on')
                cancel(obj.parf)
                obj.toggling = 'off';
                disp('Toggling of wavemeter channels turned OFF.')
            end
        end
            
        % Readout of frequency
        function freq = GetFreq(obj, channel)
            [~, freq] = ReadWLM(obj, 'freq', channel);
            freq = freq*1e6; % Output in MHz
        end
        
        % Readout of WL
        function WL = GetWL(obj,channel)
            [WL, ~] = ReadWLM(obj, 'WLM',channel); % Output in nm
        end
        
        % Readout of BOTH at the same time (without waiting for a new
        % readout)
        function [WL, freq] = GetBoth(obj,channel)
            [WL, freq] = ReadWLM(obj, 'both',channel);
            freq = freq*1e6; % output in MHz
        end
        
        % Return active channel
        function channel = GetChannel(obj)
            channel = calllib('wlmData','GetActiveChannel',3,1,0);
        end
        
    end 
end % end of class

% Quick pause method, that does not leak memory like PAUSE()
function pauseJava(tPauseSec)
    th = java.lang.Thread.currentThread();  %Get current Thread
    th.sleep(1000*tPauseSec)                %Pause thread, in ms
end