% This class is used to instantiate one or two Solstis objects to control the M Squared Lasers SolsTis laser via TCPIP commands.

% 
classdef (Sealed) Solstis < handle

%{
    Singleton class for one or two Solstis laser object. 
%}

    properties (Access = public)
        last_WL = 0
        sol_ip_address
        pc_ip_address
        port
        write_reports = false
        report = {}
        tcp
        terascan = struct
        channel
        lambda_lock = ''
    end
   
    % Regulate that only 2 instances of Solstis can exist with a class-wide,
    % static method
    methods (Static)
        
        % The "effective" constructor, called as Solstis.getInstance()
        function solstis = getInstance(ip_address,port)
            persistent Solstis1
            persistent Solstis2
            if isempty(Solstis1) || ~isvalid(Solstis1)
                Solstis1 = Solstis(ip_address,port);
                solstis = Solstis1;
                disp(['Instantiated Solstis with ip-address: ' ip_address '.'])
            elseif (isempty(Solstis2)|| ~isvalid(Solstis2)) && ~strcmp(Solstis1.sol_ip_address,ip_address)
                Solstis2 = Solstis(ip_address,port);
                solstis = Solstis2;
                disp(['Instantiated Solstis with ip-address: ' ip_address '.'])
            else
                error('Solstis.m: Initialization stopped. Either two Solstices are initialized or ip_address is already initialized.')
            end
        end
        
    end
    
    methods (Access = private)
        
        % Constructor (can only be called by the static getInstance
        % function)
        function obj = Solstis(ip_address,port)
            obj.sol_ip_address = ip_address;
            obj.port = port;
            obj.pc_ip_address = '192.168.1.220';% Enter the lab computer's IP address here.
        end
        
    end
        
    methods (Access = public)
        
        % Open a TCPIP connection with the solstis ICE-box 
        function response = OpenTCPIP(obj)
            disp(['Initializing communication with ' obj.sol_ip_address '.'])

            % Open communication
            obj.tcp = tcpip(obj.sol_ip_address, obj.port,...
                'timeout',1,...
                'terminator',125); % Note that the terminator is set to '}'!
            try
                fopen(obj.tcp);
            catch
                warning('Solstis.m: TCP/IP connection failed.')
            end
            q = ['{"message":{"transmission_id":[1],"op":"start_link",' ...
                '"parameters":{"ip_address":"' obj.pc_ip_address '"}}}']; 
            response = Query(obj,q);
        end
        
        % Send query to Solstis and wait for return string.
        function response = Query(obj,q)
            if isempty(obj.tcp) || ~strcmp(obj.tcp.Status,'open')
                response = 'No open TCP/IP for Solstis exists.';
                warning(response)
                return
            end
            fprintf(obj.tcp,q);
            ret = [];
            ret_part = [];
            first = true;
            while ~isempty(ret_part) || first
                first = false;
                ret_part = fscanf(obj.tcp);
                ret = [ret ret_part];
                numOpenBracket = sum(ret=='{');
                numClosedBracket = sum(ret=='}');
                if numOpenBracket>0 && numOpenBracket==numClosedBracket
                    break
                end
            end
            response = Parse(obj,ret);
        end
        
        % Take return string from Solstis and turn it into a struct with
        % all return parameters separated.
        function response = Parse(obj,ret)
            response.datetime = datestr(now);
            if isempty(ret)
                response.messageRecieved = 0;
                return
            end

            % extract the last message (throw away any others)
            lastMessageStart = strfind(ret,'}{"message"');
            if ~isempty(lastMessageStart)
                ret = ret(lastMessageStart(end)+1:end);
                warning('Solstis.m: Skipping solstis reports! Reduce rate of Solstis output reports.')
            end
            
            % DQI=doubleQuoteIndex, an array with all the indices of double quote characters in the string.
            DQI = strfind(ret,'"');             
            if ~isempty(DQI)
                for i = 2:2:length(DQI)
                    if ret(DQI(i)+1) == ':' && ret(DQI(i)+2) ~= '{'
                        fieldName = ret(DQI(i-1)+1:DQI(i)-1);
                        if ret(DQI(i)+2) == '"'
                            fieldValue = ret(DQI(i+1)+1:DQI(i+2)-1);
                        elseif ret(DQI(i)+2) == '['
                            index = strfind(ret(DQI(i)+3:end),']');
                            fieldValue = str2double(ret(DQI(i)+3:DQI(i)+1+index));
                        end
                        response.(fieldName) = fieldValue;
                    end
                end
            end
            if ~strcmp(response.op,'automatic_output') && obj.write_reports
                obj.report{end+1} = response;
            end
        end
        
        function response = WaitForResponse(obj)
            ret = '';
            warning off instrument:fscanf:unsuccessfulRead
            while (isempty(ret) || obj.tcp.BytesAvailable > 0)
                ret = [ret fscanf(obj.tcp)];
                pause(0.005)
            end
            warning on instrument:fscanf:unsuccessfulRead
            response = Parse(obj,ret);
        end
        
        % Query for wavelength and store in obj.wavelength
        function [response,wavelength] = GetWL(obj)
            q = '{"message":{"transmission_id":[8], "op":"poll_wave_m"}}';
            response = Query(obj,q);
            wavelength = response.current_wavelength;
            obj.last_WL = wavelength;
        end
        
        % Command solstis to go to wavelength. This function returns control
        % after a final report is received from the Solstis.
        function response = GoToWL(obj,wavelength)
            wavelengthStr =  num2str(wavelength,'%03.6f');
            fprintf(['Going to ' wavelengthStr ' nm\n'])
            q = ['{"message":{"transmission_id":[3],"op":"set_wave_m","parameters":{"wavelength":[' wavelengthStr '],"report":"finished"}}}'];
            response = Query(obj,q);
            if response.status == 1 || response.status == 2
                warning('Solstis.m: Problem with gotoWL().')
            else
                % Wait for the final report and interpret it.
                response = WaitForResponse(obj);
                if response.report == 1
                    warning('gotoWavelength failed!')
                else
                    obj.last_WL = response.wavelength;
                    fprintf(strcat('Laser settled at: ', num2str(obj.last_WL) ,'.\n'))
                end
            end

        end
        
        % Turn on/off wavelength locking 'lambda lock'.
        function response = Lock(obj,onOffStr)
            if strcmp(onOffStr,'on')
                q = '{"message":{"transmission_id":[700], "op":"lock_wave_m", "parameters":{"operation":"on"}}}';
                response = Query(obj,q);
                fprintf('Lambda_lock on.\n')
                obj.lambda_lock = 'on';
            elseif strcmp(onOffStr,'off')
                q = '{"message":{"transmission_id":[700], "op":"lock_wave_m", "parameters":{"operation":"off"}}}';
                response = Query(obj,q);
                fprintf('Lambda_lock off.\n')
                obj.lambda_lock = 'off';
            end
            response.message = 0;
        end
        
        % Clear the output message buffer of the solstis. 
        function bufferRemains = ClearBuffer(obj)
            bufferRemains = [];
            while obj.tcp.BytesAvailable ~= 0
                bufferRemains = [bufferRemains fscanf(obj.tcp)];
            end
        end
        
        % Start TeraScan
        function response = TeraScan(obj,finalreport)
            check = GetWL(obj);
            if check.status == 1
                error('Solstis.m: No link with wavemeter found.')
            elseif check.status == 2
                error('Solstis.m: Tuning in progress.')
            elseif check.status == 3
                error('Solstis.m: Lambda lock is on. Turn it off and try again.') 
            end
            
            if isempty(obj.terascan)
                response = 'Solstis.m: TeraScan is aborted because it was not yet initialized with TeraScanInit().';
                warning(response)
                return
            end
            
            if strcmp(finalreport,'on')
                q = ['{"message":{"transmission_id":[102], "op":"scan_stitch_op",' ...
                '"parameters":{"scan":"' obj.terascan.scan_type '", "operation":"start", "report":"finished"}}}'];
            elseif strcmp(finalreport,'off')
                q = ['{"message":{"transmission_id":[102], "op":"scan_stitch_op",' ...
                '"parameters":{"scan":"' obj.terascan.scan_type '", "operation":"start"}}}'];
            else
                warning('Solstis.m: finalreport was set to `off`.')
                q = ['{"message":{"transmission_id":[102], "op":"scan_stitch_op",' ...
                '"parameters":{"scan":"' obj.terascan.scan_type '", "operation":"start"}}}'];
            end
            response = Query(obj,q);
        end
        
        % Initialize TeraScan settings and save them in obj.terascan
        function response = TeraScanInit(obj,scan_type,start,stop,scan_rate,units)
            % Check if start and stop wavelength are in the solstis range
            if start > 1003 || start < 697 || stop > 1003 || stop < 697
                error('Solstis.m: Terascan start and/or stop wavelengths are out of range (697 to 1003 nm).')
            end

            % Check unit of scan rate
            if strcmp(scan_type,'medium') && strcmp(units,'GHz/s')
                allowed_rates = [1 2 5 10 15 20 50 100];
            elseif strcmp(scan_type,'fine') && strcmp(units,'GHz/s')
                allowed_rates = [1 2 5 10 15 20];
            elseif strcmp(scan_type,'fine') && strcmp(units,'MHz/s')
                allowed_rates = [1 2 5 10 15 20 50 100 200 500];
            elseif strcmp(scan_type,'medium') && strcmp(units,'MHz/s')
                error('Solstis.m: TeraScan rate unit is not correct. Use "GHz/s" for "medium"-type scans.')
            else
                error('Solstis.m: TeraScan rate unit or scan_type is incorrect. Use "GHz/s" or "MHz/s" for "fine" and "GHz/s" for "medium".')
            end

            % Make rate compatible with scanrates of solstis
            if ~any(scan_rate==allowed_rates)
                [~,i] = min(abs(allowed_rates - scan_rate));
                new_rate = allowed_rates(i(1));
                disp(['Solstis.m: TeraScan rate is changed from ' num2str(scan_rate) units ' to ' num2str(new_rate) units '.'])
                scan_rate = new_rate;
            end
            
            obj.terascan.start = start;
            obj.terascan.stop = stop;
            obj.terascan.scan_type = scan_type;
            obj.terascan.scan_rate = scan_rate;
            obj.terascan.units = units;
            
            % Initialise TeraScan parameters
            q = ['{"message":{"transmission_id":[101], "op":"scan_stitch_initialise",' ...
                '"parameters":{"scan":"' scan_type '", "start":[' num2str(start) '], "stop":[' num2str(stop) '], "rate":[' num2str(scan_rate) '], "units":"' units '"}}}'];
            response = Query(obj,q);
        end
        
        % Control TeraScan settings for automatic reports and pausing during scan and save them in obj.terascan
        function response = TeraScanOutput(obj,operation,pause)
            % Configure 'TeraScan Automatic Output' parameters
            q = ['{"message":{"transmission_id":[100], "op":"terascan_output",' ...
                '"parameters":{"operation":"' operation '", "delay":[0], "update":[0], "pause":"' pause '"}}}'];
            response = Query(obj,q);
            obj.terascan.update_rate = 0;
            obj.terascan.operation = operation;
            obj.terascan.pause = pause;
        end
        
        % Check TeraScan status
        function response = TeraScanStatus(obj)
            q = ['{"message":{"transmission_id":[555], "op":"scan_stitch_status", "parameters":{"scan":"' obj.terascan.scan_type '"}}}'];
            response = Query(obj,q);            
        end
        
        % Continue a paused terascan routine
        function response = TeraScanContinue(obj)
            q = '{"message":{"transmission_id":[555], "op":"terascan_continue"}}';
            response = Query(obj,q);
        end
        
        % Start a single resonator scan
        function response = FastScan(obj,width,duration)
            % Check if time and width are in the correct range
            if duration < 0.01 || duration > 10000
                error('Solstis.m: Scan time should be in the range [0.01 10000].')
            end
            if (width < 0.01 || width > 30)
                error(['Solstis.m: The width of a resonator scan should be in the range [0.01 30]. Now range was:' num2str(width) '.'])
            end
            
            % Start resonator scan
            q = ['{"message":{"transmission_id":[777], "op":"fast_scan_start",' ...
                '"parameters":{"scan":"resonator_single", "width":[' num2str(width) '], "time":[' num2str(duration) ']}}}'];
            response = Query(obj,q);
        end
        
        % Check the status of a fast scan
        function response = PollFastScan(obj)
             % Start resonator scan
            q = ['{"message":{"transmission_id":[777], "op":"fast_scan_poll",' ...
            '"parameters":{"scan":"resonator_single"}}}'];
            response = Query(obj,q);
        end
        
    end 
end
% end of class