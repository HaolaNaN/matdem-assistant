%set the material of the model
clear
load('TempModel/Mixer1.mat');
B.setUIoutput();%set output of message
d=B.d;
d.calculateData();
d.mo.setGPU('off');
d.getModel();%get xyz from d.mo
d.resetStatus();%initialize model status, which records running information
d.setStandarddT();

%----------make a Box, and import the objects to the box---------
totalTime=d.SET.totalTime;
d.mo.aMUp(:)=0.5;%set the friction coefficient of element
d.mo.setShear('on');

%add monitoring points
monitorId=randperm(length(d.GROUP.sample),20);
d.addGroup('monitor',monitorId,1);
d.addRecordProp('monitor','*aX');%add a * before properties to record all elements
d.addRecordProp('monitor','*aY');
d.addRecordProp('monitor','*aZ');

%set the numerical simulation
d.mo.dT=d.mo.dT*4;
showType='aR';
d.figureNumber=d.show(showType);
d.SET.StandardBalanceNum=20;
standardBalanceTime=d.balance('Time');%time of one standard balance

%run the simulation and save the data
gpuStatus=d.mo.setGPU('auto');
totalCircle=10;
d.tic(totalCircle);
fName=['data/step/' B.name num2str(B.ballR) '-' num2str(B.distriRate) 'loopNum'];
standardBalanceRate=totalTime/totalCircle/standardBalanceTime;
save([fName '0.mat']);%return;
for i=1:totalCircle
    d.mo.setGPU(gpuStatus);
    d.balance('Standard',standardBalanceRate);
    d.show(showType);
    drawnow

    d.clearData(1);
    save([fName num2str(i) '.mat']);
    d.calculateData();
    d.toc();%show the note of time
end
%show the trace of the monitoring points
casefs.showMonitorTrace(d,'monitor');

figure;
d.showFilter('Group',{'all'});
d.show('Heat');

d.clearData(1);
d.recordCalHour('BoxStep2Finish');
save(['TempModel/' B.name '2.mat'],'B','d');
save(['TempModel/' B.name '2R' num2str(B.ballR) '-' num2str(B.distriRate)  'aNum' num2str(d.aNum) 'shear.mat']);
d.calculateData();