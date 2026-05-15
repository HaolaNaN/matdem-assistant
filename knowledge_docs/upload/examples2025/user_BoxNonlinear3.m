clear;
load('TempModel/BoxNonlinear2.mat');
d.calculateData();
d.mo.setGPU('off');
B.setUIoutput();
d=B.d;  
%figure;d.showC();return

%regular basic set of the model
d.getModel();%d.setModel();%reset the initial status of the model
d.resetStatus();%initialize model status, which records running information
d.mo.isCrack=1;
d.mo.isHeat=1;%calculate heat in the model
visRate=0.5;%defines the viscosity rate, related to soil moisture
d.mo.mVis=d.mo.mVis*visRate;
d.setStandarddT();
d.mo.dT=d.mo.dT*4;
d.mo.isClump=1;
powerRate=d.SET.powerRate;

d.addRecordProp('topPlaten','aZ');%declare recording mAZ
loadNum=8;
StandardBalanceRate=0.2;
powerRates=(1+1.5*(powerRate-1)*(1:loadNum).^2/loadNum);%for rate 0.3
showType='ZDisplacement';
loadPiece=4*(1:loadNum);
%loadPiece(end)=loadPiece(end)-2;
loadSteps=-33.4*9.8*loadPiece;
loadSteps=[loadSteps,fliplr(loadSteps)];powerRates=[powerRates,fliplr(powerRates)];
totalCircle=length(loadSteps);

gpuStatus=d.mo.setGPU('auto');
d.tic(totalCircle);
fName=['data/step/' B.name num2str(B.ballR) '-' num2str(B.distriRate) 'vis0.5loopNum'];
save([fName '0.mat']);%return;

TPid=d.GROUP.topPlaten;
TP_GZ=loadSteps/length(TPid);
TPstatusI=ones(totalCircle+1,1);
for i=1:totalCircle
    d.mo.mGZ(TPid)=TP_GZ(i);
    d.mo.setGPU(gpuStatus);
    d.balance('Standard',StandardBalanceRate*powerRates(i));
    TPstatusI(i+1)=length(d.status.Ts);
    d.figureNumber=d.show(showType);
    d.clearData(1);
    save([fName num2str(i) '.mat']);
    d.calculateData();
    d.toc();%show the note of time
end
%d.status.show('PROPtopPlaten_aZ');

d.status.SET.PROP.dZ=d.status.SET.PROP.topPlaten_aZ-d.status.SET.PROP.topPlaten_aZ(1);
figure;d.status.show('PROPdZ');

dZ2=d.status.SET.PROP.dZ(TPstatusI);
stress=-[0,loadSteps]/0.25;
[a,b]=casefs.powerFit(stress(2:9)/1000,dZ2(2:9)*1000,1,'Vertical stress on plane [kPa]','Vertical displacement of plane [mm]');

figure;
plot(stress/1000,dZ2*1000,'.-');
xlabel('Vertical stress on plane [kPa]');
ylabel('Vertical displacement of plane [mm]');

d.clearData(1);
d.recordCalHour('Box3Finish');
save(['TempModel/' B.name '3.mat'],'d');
save(['TempModel/' B.name '3R' num2str(B.ballR) '-' num2str(B.distriRate)  'aNum' num2str(d.aNum) 'rate' num2str(d.SET.rate) 'friction' num2str(d.Mats{1}.Mui) '.mat']);
d.calculateData();