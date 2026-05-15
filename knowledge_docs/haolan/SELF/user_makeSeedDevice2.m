%set the material of the model
clear;
load('TempModel/SeedSow1.mat');
B.setUIoutput();%set output of message
d=B.d;
d.calculateData();
d.mo.setGPU('on');
d.getModel();%get xyz from d.mo
d.resetStatus();%initialize model status, which records running information
d.setStandarddT();
% calculation para
totalTime=d.SET.totalTime;
%d.mo.MOTION.all.RXZs=-d.mo.MOTION.all.RXZs;
d.moveBoundary('lefB',min(d.mo.aX(d.GROUP.sample)),0,0);
d.mo.aMUp(:)=1.2;
%d.mo.isHeat=1;
%d.mo.mVis=d.mo.mVis*4;
%d.mo.setShear('off');

%add monitoring points
seedIds = d.GROUP.seed;
monitorId = seedIds(randperm(length(seedIds),10));%random pick 10 seeds to show the trace
d.addGroup('monitor',monitorId,1);
d.addRecordProp('monitor','*aX');
d.addRecordProp('monitor','*aY');
d.addRecordProp('monitor','*aZ');

%set the numerical simulation
d.mo.dT=d.mo.dT*4;
% showType='groupId';
% d.figureNumber=d.show(showType);
d.SET.StandardBalanceNum=50;
standardBalanceTime=d.balance('Time');%time of one standard balance

%run the simulation and save the data
gpuStatus=d.mo.setGPU('auto');
totalCircle=50;
d.tic(totalCircle);
fName=['data/step/' B.name num2str(B.ballR) '-' num2str(B.distriRate) 'loopNum'];
standardBalanceRate=totalTime/totalCircle/standardBalanceTime;
save([fName '0.mat']);

for i=1:totalCircle
    d.mo.setGPU(gpuStatus);
    d.balance('Standard',standardBalanceRate);
    d.showFilter('SlideY',0.48,'groupId');
    d.clearData(1);
    close(1);
    save([fName num2str(i) '.mat']);
    d.calculateData();
    d.toc();%show the note of time
end
%show the trace of the monitoring points
d.figureNumber=2;
casefs.showMonitorTrace(d,'monitor');
figure;d.showFilter;d.showFilter('SlideY',0.48,'groupId');

d.mo.setGPU('off');
% %get seeds coordinate
% Coordinate=[];
% Coordinate=[d.mo.aX(d.GROUP.seed),d.mo.aY(d.GROUP.seed),d.mo.aZ(d.GROUP.seed)];
% xlswrite('output.xlsx',Coordinate,'Sheet1','A1');

%get outer seeds
min_x = min(d.mo.aX(d.GROUP.device));
min_z = min(d.mo.aZ(d.GROUP.device));
filtered_coords = {'X', 'Y', 'Z'};
for i = 1:length(d.GROUP.seed)
    x = d.mo.aX(d.GROUP.seed(i));
    z = d.mo.aZ(d.GROUP.seed(i));
    if x < min_x || z < min_z
        filtered_coords = [filtered_coords; {x, d.mo.aY(d.GROUP.seed(i)), z}];
    end
end
xlswrite('outside_seed.xlsx', filtered_coords, 'Sheet1', 'A1');

d.clearData(1);
d.recordCalHour('BoxStep2Finish');
save(['TempModel/' B.name '2.mat'],'B','d');
save(['TempModel/' B.name '2R' num2str(B.ballR) '-' num2str(B.distriRate)  'aNum' num2str(d.aNum) ' .mat']);
d.calculateData();