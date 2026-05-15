clear;
load('TempModel/ShockDAS2.mat');
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

%-----------------------set viscous layers
visRate0=3;%visRate can be an 1*6 array
Hrate=0.15;
gName='sample';
S0=d.group2Obj(gName);
F=mfs.getObjFrame(S0);%get frame of the object
%TH define layer thickness, [left,right,front,back,bottom,top]
TH=[F.width,F.width,F.length,F.length,F.height,F.height].*[Hrate,Hrate,Hrate,Hrate,Hrate*2,0];%3D
%TH=B.ballR*2*[0,30,0,0,0,0];%use ball number to define the layer
TW=B.ballR*2*ones(size(TH))*5;%define layer triangle width
B.SET.TH=TH;B.SET.TW=TW;%save the data

visId=casefs.makeSerraVisBlock(d,gName,TW,TH,visRate0);
rate=length(d.GROUP.(gName))/length(visId);%the rate of viscous area
%-----------------------end set viscous layers

%defines the initial strain
casefs.defineInitialFiberStrain(d);%record initial strain in d.SET@@@@@@@@@@@@@@@@@@@@@@@
%the following two commands has the same effect
d.status.recordCommand='d=obj.dem;obj.SET.fiber_Ts=[obj.SET.fiber_Ts,d.mo.totalT];fiberStrain1=gather(casefs.getFiberStrain(d,''fiber''));d.status.SET.fiber_Strain=[d.status.SET.fiber_Strain,fiberStrain1];';
%d.status.recordCommand='d=obj.dem;casefs.addFiberStrain(d);';

boxId=d.GROUP.box;
E0=d.status.dispEnergy();%initial energy in case of no wave
%----------set the drawing of result during iterations
showType='mV';
d.figureNumber=1;
%----------end set the drawing of result during iterations
fdT=1e-3;%1 ms sampling
StandardBalanceNum=round(fdT/d.mo.dT);
d.mo.dT=fdT/StandardBalanceNum;
recorddT=StandardBalanceNum*d.mo.dT;%real interval of the record
d.SET.StandardBalanceNum=StandardBalanceNum;
[time,~]=d.balance('Time');%get the real time of one standard balance

%---------------set up the wave signal of the box
boxM=50;%kg
shockA=1e-3;%m
shockF=10;%box frequency (hz)
totalT=0.2;%total real time (s)
stepNum=5;%sub step number in one circle, change this value to 1 in formal tests
totalCircle=ceil(totalT*shockF);
StandardBalanceRate=totalT/time/totalCircle/stepNum;
if d.is2D==1
    boxM=boxM*B.SET.boxL/B.SET.boxL0;%deal with 2D case
end
d.mo.mM(d.GROUP.box)=boxM/length(d.GROUP.box);
d.mo.mGZ(d.GROUP.box)=d.mo.mM(d.GROUP.box)*d.g;

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
title('上部块体的振动荷载（Z方向体力变化曲线）');
%---------------end set up the wave signal of the box

%---------------set the numerical model and run the simulation
waveProp='mGZ';
d.addTimeProp('Shocker',waveProp,Ts,Values);%assign the AZ to elements of LeftLine
d.addRecordProp('Shocker',waveProp);%declare recording mAZ

gpuStatus=d.mo.setGPU('auto');
d.tic(totalCircle);
fName=['data/step/' B.name num2str(B.ballR) '-' num2str(B.distriRate) 'loopNum'];
save([fName '0.mat']);%return;
for i=1:totalCircle
    d.mo.setGPU(gpuStatus);
    for j=1:stepNum
        d.balance('Standard',StandardBalanceRate);
        d.show(showType);
        %figure;d.status.show('PROPShocker_mGZ');
    end
    d.mo.setGPU('off');
    save([fName num2str(i) '.mat']);%save data
end

E=d.status.dispEnergy();
d.mo.setGPU('off');
figure;
casefs.showFiberRelativeStrains2(d,'fiber');

d.clearData(1);
d.recordCalHour('BoxCrush3Finish');
save(['TempModel/' B.name '3.mat'],'d');
save(['TempModel/' B.name '3R' num2str(B.ballR) '-' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();