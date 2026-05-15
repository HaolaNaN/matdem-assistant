clear
sampleR=34e-3;
sampleH=90e-3;
ballR=4e-3;
load('TempModel/highSizeRatioC1.mat');
load('TempModel/highSizeRatioC2.mat');
load('TempModel/highSizeRatioC3.mat');
C1.Z=C1.Z+ballR*0.5;
addZ2=max(C1.Z+C1.R)-min(C2.Z-C2.R);
C2.Z=C2.Z+addZ2;
addZ3=max(C2.Z+C2.R)-min(C3.Z-C3.R);
C3.Z=C3.Z+addZ3;

Rrate=0.7;
tubeObj=mfs.denseModel(Rrate,@mfs.makeTube,sampleR+(1-Rrate)*ballR*2,sampleH+ballR*4,ballR);
tubeObj.X=tubeObj.X-ballR;
tubeObj.Y=tubeObj.Y-ballR;
discObjBot=mfs.denseModel(Rrate,@mfs.makeDisc,sampleR+(1-Rrate)*ballR*1,ballR);
discObjTop=mfs.move(discObjBot,0,0,sampleH+ballR*2);

boxType='wall';%boxType could be 'model' or 'wall', see element type in help
%make a big box for the simulation
B=obj_Box;%declare a box object
B.name='BoxShear';
%--------------initial model------------
B.GPUstatus='auto';%program will test the CPU and GPU speed, and hoose the quicker one
B.ballR=ballR;
B.isShear=0;
B.isClump=0;%if isClump=1, particles are composed of several balls
B.distriRate=0.2;%define distribution of ball radius, 
B.sampleW=sampleR*2;
B.sampleL=sampleR*2;
B.sampleH=sampleH*1;
B.BexpandRate=2;%boundary is 4-ball wider than 
B.PexpandRate=0;
B.type='botPlaten';
B.isSample=0;
%B.type='TriaxialCompression';
B.setType();
B.SET.boxType=boxType;
B.buildInitialModel();

d=B.d;
d.mo.setGPU('off');
[C1Id,C2Id,C3Id]=d.addElement(1,{C1,C2,C3});
[tubeId,discBotId,discTopId]=d.addElement(1,{tubeObj,discObjBot,discObjTop},boxType);
d.addGroup('C1',C1Id);
d.addGroup('C2',C1Id);
d.addGroup('C3',C1Id);
d.addGroup('tube',tubeId);
d.addGroup('discBot',discBotId);
d.addGroup('discTop',discTopId);
d.show('aR');