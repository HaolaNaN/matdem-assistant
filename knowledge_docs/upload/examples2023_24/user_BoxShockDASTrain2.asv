%set the material of the model
clear
load('TempModel/ShockDAS1.mat');
B.setUIoutput();%set the output
d=B.d;
d.calculateData();%calculate data
d.mo.setGPU('off');%close the GPU calculation
d.getModel();%get xyz from d.mo
d.resetStatus();

fiberDepth=B.SET.fiberDepth;
%suggestion by Liu: soil, fiber and block use the same material
%--------------assign new material
%matRate is used to change the Young's modulus and strength of material
matRate=1;%soft soil:0.2; hard: 5; normal 1
matRates=[matRate,1,matRate,matRate,1,1];
matTxt=load('Mats\Soil1.txt');%load material file
matTxt=matTxt.*matRates;
Mats{1,1}=material('Soil1',matTxt,B.ballR);
Mats{1,1}.Id=1;
matTxt=load('Mats\Fiber1.txt');%load material file
matTxt=matTxt.*matRates;
Mats{2,1}=material('Fiber1',matTxt,B.ballR);
Mats{2,1}.Id=2;
matTxt=load('Mats\Block1.txt');%load material file
matTxt=matTxt.*matRates;
Mats{3,1}=material('Block1',matTxt,B.ballR);
Mats{3,1}.Id=3;
d.Mats=Mats;%assign new material

%--------------balance the soil model
d.groupMat2Model({'sample'},1);%apply the new material
d.balanceBondedModel0(0.5);

%---------------add top block to the model
boxW=0.3;boxL=0.3;boxH=0.3;%define the width and height of the block
B.SET.boxW0=boxW;B.SET.boxL0=boxL;B.SET.boxH0=boxH;
boxL=boxL*sign(B.sampleL);%deal with 2D case
box_Rrate=0.8;
boxObj=mfs.denseModel(box_Rrate,@mfs.makeBox,boxW,boxL,boxH,B.ballR);%make a pile struct

if B.sampleL==0
    boxObj.Y(:)=0;
    boxL=0;
    B.SET.boxL=B.ballR*2;
end

topZ=max(d.mo.aZ(d.GROUP.topPlaten))-B.ballR;%no effect between box and platen
boxObj=mfs.move(boxObj,(B.sampleW-boxW)/2,(B.sampleL-boxL)/2,topZ);
boxId=d.addElement('Block1',boxObj);
d.addGroup('box',boxId);
d.setClump('box');%set the pile clump
d.removeGroupForce('box',[d.GROUP.topB;d.GROUP.topPlaten]);%no effect between box and platen

%----------------defines the fiber
fiberName='fiber';
fiber_Rrate=0.6;%defines the precision of fiber, 0.3~0.8
minusRate=0.1;%defines the coupling between fiber and soil,0.1~0.6
lineX=[B.ballR;B.sampleW/2;B.sampleW];
lineY=zeros(size(lineX))+B.sampleL/2;
maxZ=mean(d.mo.aZ(d.GROUP.topPlaten));
lineZ=ones(size(lineX))*(maxZ-fiberDepth);
fiberObj1=f.run('fun/make3DCurve.m',lineX,lineY,lineZ,B.ballR,fiber_Rrate);
%add the fiber to the model
fiberId=d.addElement('Fiber1',fiberObj1);
d.addGroup(fiberName,fiberId);
d.setClump(fiberName);
d.minusGroup('sample',fiberName,minusRate);

%when the fiber object is imported into the model, run the addFiber%record initial distance of fiber elements
casefs.addFiber(d,fiberName);%@@@@@@@@@@@@@@@@@@@@@@

%----------------end defines the fiber

%fix fiber, balance the model and remove pre-stress
d.setStandarddT();
d.addFixId('XYZ',d.GROUP.(fiberName));
balanceRate=0.5;%use small value to simulate rough surface?0.01~0.5
d.balanceBondedModel0(balanceRate);

dTrate=4;%increase the dT to increase the computing speed, 1~4
d.mo.dT=d.mo.dT*dTrate;
aMUp0=d.mo.aMUp;
d.mo.aMUp(:)=0;%when MUp is 0, the coupling between fiber and soil will be increased
d.mo.setGPU('auto');
d.balance('Standard',1/dTrate);
d.removeFixId('XYZ',d.GROUP.(fiberName));

%unfix fiber, connect the elements and remove prestress
d.mo.aMUp=aMUp0;
d.mo.setGPU('auto');
d.connectGroup('sample');
d.removePrestress(0.1);
d.balance('Standard',1/dTrate);
d.connectGroup('sample');
d.removePrestress(0.1);
d.balance('Standard',1/dTrate);
d.mo.dT=d.mo.dT/dTrate;

%d.show('mV','groupId');
d.mo.setGPU('off');
d.clearData(1);%clear dependent data
d.recordCalHour('Step2Finish');
save(['TempModel/' B.name '2.mat'],'B','d');
save(['TempModel/' B.name '2R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();