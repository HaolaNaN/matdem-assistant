%set the material of the model
clear
load('TempModel/BoxShock1.mat');
B.setUIoutput();%set the output
d=B.d;
d.calculateData();%calculate data
d.mo.setGPU('off');%close the GPU calculation
d.getModel();%get xyz from d.mo
d.resetStatus();

%suggestion by Liu: soil and block use the same material
%--------------assign new material
%matRate is used to change the Young's modulus and strength of material
matRate=1;%soft soil:0.2; hard: 5; normal 1
matRates=[matRate,1,matRate,matRate,1,1];
matTxt=load('Mats/Soil1.txt');%load material file
matTxt=matTxt.*matRates;
Mats{1,1}=material('Soil1',matTxt,B.ballR);
Mats{1,1}.Id=1;
matTxt=load('Mats/Block1.txt');%load material file
matTxt=matTxt.*matRates;
Mats{2,1}=material('Block1',matTxt,B.ballR);
Mats{2,1}.Id=2;
d.Mats=Mats;%assign new material

%--------------balance the soil model
d.groupMat2Model({'sample'},1);%apply the new material
d.balanceBondedModel0(0.5);

%---------------add top block to the model
sphereR=0.1;%define the width and height of the block
if sphereR<B.ballR
    sphereR=B.ballR;
end
B.SET.sphereR=sphereR;
Rrate=0.8;
if d.is2D==1
    boxObj=mfs.makeDiscV(sphereR,B.ballR);
    boxObj=mfs.move(boxObj,(B.sampleW-sphereR*2)/2,0,0);
    boxObj.Y(:)=0;
else
    boxObj=mfs.makeSphere(sphereR,B.ballR,Rrate);%make a pile struct
    boxObj=mfs.move(boxObj,(B.sampleW-sphereR*2)/2,(B.sampleL-sphereR*2)/2,0);
end
topZ=max(d.mo.aZ(d.GROUP.topPlaten))-B.ballR;%no effect between box and platen
boxObj=mfs.align2Value('bottom',boxObj,topZ);

boxId=d.addElement('Block1',boxObj);
d.addGroup('box',boxId);
d.setClump('box');%set the pile clump
d.removeGroupForce('box',[d.GROUP.topB;d.GROUP.topPlaten]);%no effect between box and platen


%balance the model and remove pre-stress
d.setStandarddT();
balanceRate=0.5;%use small value to simulate rough surface?0.01~0.5
d.balanceBondedModel0(balanceRate);

dTrate=4;%increase the dT to increase the computing speed, 1~4
d.mo.dT=d.mo.dT*dTrate;
d.mo.setGPU('auto');
d.removePrestress(0.1);
d.balance('Standard',4/dTrate);
d.mo.dT=d.mo.dT/dTrate;

%d.showFilter('Group',{'sample','box'});
d.show('mV','groupId');
d.mo.setGPU('off');
d.clearData(1);%clear dependent data
d.recordCalHour('Shock2Finish');
save(['TempModel/' B.name '2.mat'],'B','d');
save(['TempModel/' B.name '2R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();