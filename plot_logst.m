 x=linspace(0,1,1e6);
 logist=@(x) 1./(1+exp(-x));
 aw_thresh=0.1; %how far away from the edge aw starts (full range 0-1)
aw_fun=@(x,y) (logist((x-aw_thresh)*10/aw_thresh))*(y>0)+(1-logist((x-1+aw_thresh)*10/aw_thresh))*(y<0)
figure(1)
plot(x,aw_fun(x,1),'r')
hold on
plot(x,aw_fun(x,-1),'b')
hold off
xlabel('control actuator')
ylabel('difac')

figure(2)
clf
 x=linspace(-1,1,1e6);
 logist=@(x) 1./(1+exp(-x));
aw_thresh_rate=0.3;
aw_fun_rate=@(x) -logist((x-aw_thresh_rate+1)*5/aw_thresh_rate)+1-logist((x-1+aw_thresh_rate)*5/aw_thresh_rate);
plot(x,aw_fun_rate(x),'r')
xlabel('control actuator')
ylabel('difac')



figure(3)
clf
x=linspace(0,1,1e5);
logist=@(x) 1./(1+exp(-x));
aw_rate_thersh=0.5;
rate_lim=@(x) (logist((x-aw_rate_thersh)*10/aw_rate_thersh))
plot(x,rate_lim(x),'b')

ylabel('difac')