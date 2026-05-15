%in this code, we will learn how to generate seismic wave and make
%receivers to record data of seismic wave
clear;

visRate0=2;%visRate can be an 1*6 array
Hrate=0.5;
num=251;%126, 251 or 501; 1/100: 26;100:2501
load('TempModel/BoxWave2.mat');
totalT=0.0006/sqrt(d.Mats{1}.E/5e9);%total time

%load('TempModel/BoxWave2R0.002-distri0.2aNum7067.mat');

d.calculateData();
d.mo.setGPU('off');
B.setUIoutput();
d=B.d;
d.getModel();%d.setModel();%reset the initial status of the model
d.resetStatus();%initialize model status, which records running information
d.mo.isHeat=1;%calculate heat in the model
visRate=0.0001;
d.mo.mVis=d.mo.mVis*visRate;
d.mo.isCrack=1;
d.setStandarddT();

%E=d.status.dispEnergy();return

%-----------------------set viscous layers
gName='sample';
S0=d.group2Obj('sample');
F=mfs.getObjFrame(S0);%get frame of the object
%define layer thickness, [left,right,front,back,bottom,top]
TH=[F.width,F.width,F.length,F.length,F.height,F.height].*[0,Hrate,0,0,0,0];
%TH=B.ballR*2*[0,30,0,0,0,0];
TW=B.ballR*2*ones(size(TH))*5;%define layer triangle width

visId=casefs.makeSerraVisBlock(d,gName,TW,TH,visRate0);
rate=length(d.GROUP.(gName))/length(visId);%the rate of viscous area
%-----------------------end set viscous layers


%---------------------define the source of the wave
%leftBlock is used to generate wave
mX=d.mo.aX(1:d.mNum);
leftFilter=mX<B.sampleW*0.05;
d.addGroup('leftBlock',find(leftFilter));
%generating sine wave on the leftLine group
totalBalanceNum=10000;%data number of the wave

period=1e-4;%period of the wave
Ts=(0:totalBalanceNum)*d.mo.dT;
maxA=1000;%maximum acceleration
Values=maxA*sin(Ts*(2*pi)/period);
Values=Values(1:num);
Ts=Ts(1:num);

waveProp='mAX';
d.addTimeProp('leftBlock',waveProp,Ts,Values);%assign the AZ to elements of LeftLine
d.addRecordProp('leftBlock',waveProp);%declare recording mAZ
%---------------------end define the source of the wave

%-------------------define the receiver
receiverNum=6;%receiver number
centerx=B.sampleW/receiverNum;%center position of the receiver
centery=0;
centerz=B.sampleH/2;
R=B.ballR*4;%radius of the receiver
gNames={};
prop1='mAX';%record the property 1
prop2='mVX';%record the property 2
for i=1:receiverNum
    gName=['Receiver' num2str(i)];
    gNames=[gNames(:);gName];
    f.run('fun/defineSphereGroup.m',d,gName,centerx*i,centery,centerz,R);
    d.addRecordProp(gName,prop1);%declare recording mAZ
    d.addRecordProp(gName,prop2);%declare recording mAZ
end
figure;
subplot(2,1,1);
d.setGroupId();
d.showFilter('Group',gNames,'aR');
subplot(2,1,2);
plot(Ts,Values);xlabel('Ts [second]');ylabel('X acceleration of the leftBlock [m/s^2]');title('Wave on the leftBlock');
%-------------------end define the receiver


%define the recording interval
[time,~]=d.balance('Time');
totalCircle=10;
StandardBalanceRate=totalT/time/totalCircle;

gpuStatus=d.mo.setGPU('auto');
d.tic(totalCircle);
fName=['data/step/' B.name num2str(B.ballR) '-' num2str(B.distriRate) 'loopNum'];
save([fName '0.mat']);
d.figureNumber=d.show('mV');
for i=1:totalCircle
    d.mo.setGPU(gpuStatus);
    d.balance('Standard',StandardBalanceRate);
    d.show('mV');
    d.clearData(1);
    save([fName num2str(i) '.mat']);
    d.calculateData();
    d.toc();%show the note of time
end
d.mo.setGPU('off');

%show the curves
curveFigure=figure;
for i=1:receiverNum
    subplot(6,2,i*2-1);
    d.status.show(['PROPReceiver' num2str(i) '_' prop1]);
    subplot(6,2,i*2);
    d.status.show(['PROPReceiver' num2str(i) '_' prop2]);
end
set(curveFigure, 'position', get(0,'ScreenSize'));

E=d.status.dispEnergy();
d.clearData(1);
d.recordCalHour('BoxCrush3Finish');
save(['TempModel/' B.name '3.mat'],'d');
save(['TempModel/' B.name '3R' num2str(B.ballR) '-' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();