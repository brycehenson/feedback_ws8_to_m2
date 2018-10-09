
setpoints = linspace(362848466.40,362871075.28,10);
    
calibrate_interval=5;

setpints_out=nan(30,1);

for i=1:size(setpints_out,1)

    if mod(i,calibrate_interval)==0
            
    else
       
        pointer=floor(i/calibrate_interval)*(calibrate_interval-1)+ rem(i,calibrate_interval);
        pointer = mod(pointer-1,length(setpoints))+1; 
        fprintf('%u\n',pointer)
        setpt = setpoints(pointer);
        setpints_out(i)=setpt;
        
    end


end

plot(setpints_out,'x')