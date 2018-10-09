%fucking m2 does not give the dac value [0-100] for the reonator voltage
%only the actual voltage
%to prevent moving the resonator every time at startup i need to know what this conversion is

solstis_query('{"message":{"transmission_id":[9],"op":"start_link","parameters":{"ip_address":"150.203.178.175"}}}')


dac_vals=linspace(20,80,1000);
voltage=NaN*dac_vals;

for n=1:numel(dac_vals)
fprintf('%02i\n',n)
query=sprintf('{"message":{"transmission_id":[2],"op":"tune_resonator","parameters":{"setting":[%2.4f]}}}',dac_vals(n));
solstis_query(query);
pause(1)
reply=solstis_query('{"message":{"transmission_id":[2],"op":"get_status"}}');
reply=strip(reply,'left','}');
lcurly=sum(reply=='{');
rcurly=sum(reply=='}');
if lcurly~=rcurly
    reply=[reply,repmat('}',[1,lcurly-rcurly])];
end
reply=jsondecode(reply);
status=reply.message.parameters;

voltage(n)=status.resonator_voltage;
plot(dac_vals,voltage,'k+')
end
%%


p=polyfit(voltage,dac_vals,4)
plot(voltage,dac_vals,'k+')
hold on
xplot = linspace(min(voltage),max(voltage),1e3);
fit = polyval(p,xplot);
plot(xplot,fit,'-')
hold off

%found fit as
%v=(1.8963)*dac+4.7376;