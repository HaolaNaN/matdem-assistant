clear
load('TempModel/SeedSow1.mat');
B.setUIoutput();%set the output
d=B.d;
d.calculateData();%calculate data
d.mo.setGPU('off');%close the GPU calculation
d.getModel();%get xyz from d.mo
% geometric parameters
ballR=0.01;
Rrate=0.8;
discR=0.3;%radius of sow disc
tubeR1=0.05;
tubeR2=0.04;
tubeH=0.1;
coneNum=6;%number of buckets
% motion parameters
totalTime=2;%total time of simulation
sowRotateXYspeed=60;%degree per second 
sowDisplacement=0.5;%displacement per sec
% geometry
% tube
tubeHeight=0.1;
tubeObj = mfs.denseModel0(Rrate, @mfs.makeTube, discR, tubeHeight, ballR);
%---------------------------making holes---------------------------------------
mX = tubeObj.X;
mY = tubeObj.Y;
mZ = tubeObj.Z;
angleStep = 360/coneNum;
combinedFilter = false(size(mX));
for i = 1:coneNum
    dipD = (i-1)*angleStep;
    dipA = 90;
    radius = tubeR1;
    height = 1;
    columnFilter = mfs.getColumnFilter(mX, mY, mZ, dipD, dipA, radius, height);
    combinedFilter = combinedFilter | columnFilter;
end
%holes=~combinedFilter;
%holeObj=mfs.filterObj(tubeObj,~holes);
tubeObj = mfs.filterObj(tubeObj, ~combinedFilter);
%----------------------------end making holes----------------------------
% scoop
scoopObj=mfs.denseModel0(0.7,@mfs.makeConeTube,tubeR1,tubeR2*0.6,tubeH,ballR);
scoopObj=mfs.rotate(scoopObj,'YZ',90);
scoopObj=mfs.align2Value('front',scoopObj,-discR-tubeH);
scoopObjAll=mfs.rotateCopy(scoopObj,angleStep,coneNum,'XY');
% 2 disc
discObj=mfs.denseModel0(Rrate,@mfs.makeDisc,discR,ballR);
discObj=mfs.align2Value('top',discObj,0.5*tubeHeight);
discObj2=discObj;
discObj.name='disc';%each object must have a name
discObj2.name='disc2';
discObj2=mfs.align2Value('bottom',discObj2,-0.5*tubeHeight);
%add obj to allObj and assign motion paras
allObj.tube=tubeObj;
allObj.scoop=scoopObjAll;
allObj.disc1=discObj;
allObj.disc2=discObj2;
%the allObj will be rotated when .Ts and .RXYs are defined
allObj.Ts=[0,1]*totalTime;%see Tool_Motion.Ts
allObj.RXZs=[0,1]*sowRotateXYspeed*totalTime;%see Tool_Motion.RXYs
allObj.dX=[0,1]*sowDisplacement*totalTime;%see Tool_Motion.dX
allObj.name='all';%each object must have a name
objCells={tubeObj,scoopObjAll,discObj,discObj2};
deviceObj=mfs.combineObj(objCells{:});
deviceObj=mfs.addObjCenter(deviceObj);
deviceObj=mfs.rotate(deviceObj,'YZ',90);
fs.showObj(deviceObj);

center=mfs.getObjCenter(deviceObj);%check the center to move
deviceObj=mfs.move(deviceObj,0.4,0.5*B.sampleL,B.sampleH*0.3);
d.SET.totalTime=totalTime;
%add group
deviceId=d.addElement(1,deviceObj);
d.addGroup('device',deviceId,1);
d.addFixId('XYZ',d.GROUP.device);
d.delElement('topPlaten');

d.mo.mVZ(d.GROUP.seed)=-30;%speed up the descent of seeds
d.minusGroup('sample','device',2);
d.minusGroup('sample','seed',1);
d.setClump('device');
d.mo.zeroBalance();
d.mo.setGPU('on');
d.mo.dT=d.mo.dT*4;
d.balance('Standard');
d.minusGroup('sample','seed',1);

%Tool Motion to device
mAll=Tool_Motion(d,'device');
mAll.Ts=allObj.Ts;%second
mAll.Xs=allObj.dX;%displacement
mAll.RXZs=allObj.RXZs;%degree
d.showFilter;d.showFilter('SlideY',0.48,'groupId');
d.clearData(1);
d.recordCalHour('BoxStep1Finish');
save(['TempModel/' B.name '2.mat'],'B','d');
save(['TempModel/' B.name '2R' num2str(B.ballR) '-' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);