clear;
load('TempModel/BoxShock2.mat');
d.calculateData();
d.mo.setGPU('off');
B.setUIoutput();
d=B.d;

%regular basic set of the model
d.getModel();%d.setModel();%reset the initial status of the model
d.resetStatus();%initialize model status, which records running information
d.mo.isCrack=1;
d.mo.isHeat=1;%calculate heat in the model
visRate=0.001;%defines the viscosity rate, related to soil moisture
d.mo.mVis=d.mo.mVis*visRate;
d.setStandarddT();
d.mo.dT=d.mo.dT*2;

%d.show('mV');
%-----------------------set viscous layers
visRate0=15;%visRate can be an 1*6 array
Hrate=1/6;
gName='sample';
S0=d.group2Obj(gName);
F=mfs.getObjFrame(S0);%get frame of the object
%TH define layer thickness, [left,right,front,back,bottom,top]
if d.is2D==1
TH=[F.width,F.width,F.length,F.length,F.height,F.height].*[Hrate/2,Hrate/2,0,0,Hrate,0];%2D
else
TH=[F.width,F.width,F.length,F.length,F.height,F.height].*[Hrate/2,Hrate/2,Hrate/2,Hrate/2,Hrate,0];%3D
end
%TH=B.ballR*2*[0,30,0,0,0,0];%use ball number to define the layer
TW=B.ballR*2*ones(size(TH))*3;%define layer triangle width

visId=casefs.makeSerraVisBlock(d,gName,TW,TH,visRate0);
rate=length(d.GROUP.(gName))/length(visId);%the rate of viscous area
%d.showFilter('Group',{'sample'});d.show('mVis');return
%-----------------------end set viscous layers
%-----------------------add receivers
if d.is2D==1
    rX=[0;F.width*Hrate;2;6;8;9;ones(6,1)*10];%X position of the seismograph
    rY=zeros(12,1);
    platenz=mean(d.mo.aZ(d.GROUP.topPlaten))-B.ballR*2;
    rZ=[ones(6,1)*platenz;platenz-1;platenz-2;platenz-4;platenz-8;F.height-F.height*(1-Hrate);0];
    props={'mAX','mVX','mAZ','mVZ'};
    receiverNames=casefs.addRecordPropPoints(d,rX,rY,rZ,gName,props,4);
    % d.showFilter('Group',receiverNames,'aR');
    % d.setGroupId();d.show('groupId');return
else
    rX=[0;F.width*Hrate;0.5;1.5;2;2.25;ones(6,1)*2.5];%X position of the seismograph
    rY=ones(12,1)*2.5;
    platenz=mean(d.mo.aZ(d.GROUP.topPlaten))-B.ballR*2;
    rZ=[ones(6,1)*platenz;platenz-0.25;platenz-0.5;platenz-1;platenz-2;F.height-F.height*(1-Hrate);0];
    props={'mAX','mVX','mAZ','mVZ'};
    receiverNames=casefs.addRecordPropPoints(d,rX,rY,rZ,gName,props,4);
    % d.showFilter('Group',receiverNames,'aR');
    % d.setGroupId();d.show('groupId');return
end

d.addFixId('XY',d.GROUP.box);
boxId=d.GROUP.box;
E0=d.status.dispEnergy();%initial energy in case of no wave
%----------set the drawing of result during iterations
showType='mV';
d.figureNumber=1;
%----------end set the drawing of result during iterations
fdT=0.5e-3;%1 ms sampling
StandardBalanceNum=round(fdT/d.mo.dT);
d.mo.dT=fdT/StandardBalanceNum;
recorddT=StandardBalanceNum*d.mo.dT;%real interval of the record
d.SET.StandardBalanceNum=StandardBalanceNum;
[time,~]=d.balance('Time');%get the real time of one standard balance
% d.setGroupId();d.show('groupId');return

type='default';
% type='wave';
%-----------------------simulation of
if strcmp(type,'default')||strcmp(type,'')
    %define the recording interval
    boxM=10;%mass of box (kg)，夯锤质量
    dropH=2;
    totalT=0.2;%total real time (s)
    boxVZ=-sqrt(2*9.8*dropH);
    totalCircle=40;
    StandardBalanceRate=totalT/time/totalCircle;
    d.mo.mM(d.GROUP.box)=boxM/length(d.GROUP.box);
    d.mo.mGZ(d.GROUP.box)=d.mo.mM(d.GROUP.box)*d.g;
    d.mo.mVZ(boxId)=boxVZ;%velocity of the block
    %-----------------------define the properties of box

    d.mo.zeroBalance();
    d.recordStatus();
    E0=d.status.dispEnergy();%initial energy in case of no wave

    gpuStatus=d.mo.setGPU('auto');
    d.tic(totalCircle);
    fName=['data/step/' B.name num2str(B.ballR) '-' num2str(B.distriRate) 'loopNum'];
    save([fName '0.mat']);%return;
    for i=1:totalCircle
        d.mo.setGPU(gpuStatus);
        d.balance('Standard',StandardBalanceRate);
        d.show(showType);
        %casefs.showFiberRelativeStrain(d,d.GROUP.fiber);

        d.mo.setGPU('off');
        save([fName num2str(i) '.mat']);%save data
    end
elseif strcmp(type,'wave')
    boxM=10;%kg
    shockA=1e-3;%m
    shockF=10;%box frequency (hz)
    totalT=0.2;%total real time (s)
    % totalCircle=ceil(totalT*shockF); % 时间步较小，无法做出动图
    totalCircle=40;
    StandardBalanceRate=totalT/time/totalCircle;
    d.mo.mM(d.GROUP.box)=boxM/length(d.GROUP.box);
    d.mo.mGZ(d.GROUP.box)=d.mo.mM(d.GROUP.box)*d.g;
    %-----------------------define the properties of box

    totalBalanceNum=ceil(totalT/d.mo.dT);

    shockId=d.GROUP.box;
    d.addGroup('Shocker',shockId);
    vM=boxM/length(shockId);
    vGZ0=vM*-9.8;
    maxAddGZ=-vM*shockA*(2*pi*shockF)^2;
    d.mo.mM(shockId)=vM;

    dT2=1/shockF/20;
    if d.mo.dT>=dT2
        Ts=(0:totalBalanceNum)*d.mo.dT;
    else
        Ts=(0:ceil(totalT/dT2))*dT2;
    end
    Values=vGZ0+maxAddGZ*sin((2*pi)*shockF*Ts);
    figure;
    plot(Ts,Values);
    title('上压力板的振动荷载（Z方向体力变化曲线）');

    waveProp='mGZ';
    d.addTimeProp('Shocker',waveProp,Ts,Values);%assign the AZ to elements of LeftLine
    d.addRecordProp('Shocker',waveProp);%declare recording mAZ

    gpuStatus=d.mo.setGPU('auto');
    d.tic(totalCircle);
    fName=['data/step/' B.name num2str(B.ballR) '-' num2str(B.distriRate) 'loopNum'];
    save([fName '0.mat']);%return;
    for i=1:totalCircle
        d.mo.setGPU(gpuStatus);
        d.balance('Standard',StandardBalanceRate);
        d.showFilter('Group',{'sample','box'});
        d.show(showType);
        d.mo.setGPU('off');
        save([fName num2str(i) '.mat']);%save data
    end
end

E=d.status.dispEnergy();
d.mo.setGPU('off');

%show the curves of receivers
curveFigureX=figure;
receiverNum=length(rX);
for i=1:receiverNum/2
    subplot(receiverNum/2,2,i*2-1);
    d.status.show(['PROPReceiver' num2str(receiverNum/2-i+1) '_' props{1}]);
    subplot(receiverNum/2,2,i*2);
    d.status.show(['PROPReceiver' num2str(receiverNum/2-i+1) '_' props{2}]);
end
curveFigureZ=figure;
receiverNum=length(rX);
for i=1:receiverNum/2
    subplot(receiverNum/2,2,i*2-1);
    d.status.show(['PROPReceiver' num2str(i+receiverNum/2) '_' props{3}]);
    subplot(receiverNum/2,2,i*2);
    d.status.show(['PROPReceiver' num2str(i+receiverNum/2) '_' props{4}]);
end
%set(curveFigure, 'position', get(0,'ScreenSize'));

d.clearData(1);
d.recordCalHour('Shock3Finish');
save(['TempModel/' B.name '3.mat'],'B','d');
save(['TempModel/' B.name '3R' num2str(B.ballR) '-' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();