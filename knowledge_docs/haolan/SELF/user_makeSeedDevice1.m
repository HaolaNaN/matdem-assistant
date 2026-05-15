clear;
fs.randSeed(1);
% geometric parameters
ballR=0.01;
Rrate=0.4;
discR=0.3;%radius of sow disc
tubeR1=0.05;
tubeR2=0.04;
tubeH=0.1;
coneNum=8;%number of buckets
% motion parameters
totalTime=4;%total time of simulation
sowRotateXYspeed=30;%degree per second 
sowDisplacement=0.25;%displacement per sec

% geometry
% tube
tubeHeight=0.1;
% tubeObj=mfs.denseModel0(Rrate,@mfs.makeTube,discR,tubeHeight,ballR);
% mX = tubeObj.X;
% mY = tubeObj.Y;
% mZ = tubeObj.Z;
% dipD=0;dipA=90;radius=tubeR1;height=1;
% filterX = abs(mX) < tubeR1;
% columnFilterX = mfs.getColumnFilter(mX, mY, mZ, dipD, dipA, radius, height);
% dipD=90;dipA=90;radius=tubeR1;height=1;
% filterY = abs(mY) < tubeR1;
% columnFilterY = mfs.getColumnFilter(mX, mY, mZ, dipD, dipA, radius, height);
% tubeObj=mfs.filterObj(tubeObj, ~((filterX & columnFilterX) | (filterY & columnFilterY)));
tubeObj = mfs.denseModel0(Rrate, @mfs.makeTube, discR, tubeHeight, ballR);
%---------------------------making holes---------------------------------------
mX = tubeObj.X;
mY = tubeObj.Y;
mZ = tubeObj.Z;
angleStep = 360/coneNum;
combinedFilter = false(size(mX));
%combinedFilter=zeros(size(mX),'logical');
for i = 1:coneNum
    dipD = (i-1)*angleStep;
    dipA = 90;
    radius = tubeR1;
    height = 1;
    columnFilter = mfs.getColumnFilter(mX, mY, mZ, dipD, dipA, radius, height);
    combinedFilter = combinedFilter | columnFilter;
end
%holes=~combinedFilter;
%tubeObj=mfs.filterObj(tubeObj,~combinedFilterb);
tubeObj = mfs.filterObj(tubeObj, ~combinedFilter);
%tubeObj.groupId=tubeObj.X*0+1;
%----------------------------end making holes----------------------------
% scoop
scoopObj=mfs.denseModel0(Rrate,@mfs.makeConeTube,tubeR1,tubeR2*0.6,tubeH,ballR);
scoopObj=mfs.rotate(scoopObj,'YZ',90);
scoopObj=mfs.align2Value('front',scoopObj,-discR-tubeH);
%hold all;fs.showObj(tubeObj);fs.showObj(scoopObj);return
scoopObjAll=mfs.rotateCopy(scoopObj,angleStep,coneNum,'XY');
%scoopObjAll.groupId=scoopObjAll.X*0+2;

% 2 disc
discObj=mfs.denseModel0(Rrate,@mfs.makeDisc,discR,ballR);
discObj=mfs.align2Value('top',discObj,0.5*tubeHeight);
discObj2=discObj;
discObj.name='disc';%each object must have a name
discObj2.name='disc2';
discObj2=mfs.align2Value('bottom',discObj2,-0.5*tubeHeight); %%%%%%%%%%%%%
%discObj.groupId=discObj.X*0+3;
%discObj2.groupId=discObj2.X*0+4;

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
%deviceObj.groupId(end+1)=4;
deviceObj=mfs.rotate(deviceObj,'YZ',90);
%deviceObj.groupId=-10-deviceObj.groupId;% < -10 for clump
%fs.showObj(deviceObj);return

%----------make a Box, and import the objects to the box---------
spaceSize=discR*3;%define the size of the box
B=obj_Box;%declare a box object
B.name='SeedSow';
B.ballR=0.015;%element radius changed to make less elements
B.sampleW=spaceSize*2;%width, length, height
B.sampleL=spaceSize;
B.sampleH=spaceSize*2;
B.isSample=1;
B.setType('topPlaten');
B.buildInitialModel();
B.gravitySediment();
d=B.d;
d.mo.setGPU('off');
d.GROUP.groupId(d.GROUP.sample) = 30; %set diff groupId to show diff
d.SET.totalTime=totalTime;
d.mo.isOverlapNote=0;
mo = d.mo;

%seed & cut the model
seedFilter = (mo.aX >= 0.25) & (mo.aX <= 0.55) & ...
    (mo.aY >= (0.425))& ...
    (mo.aY <= (0.475)) & ...
    (mo.aZ >= 0.37) & (mo.aZ <= 0.42);
seedFilter((d.mNum+1):end) = false;
seedId = find(seedFilter);
d.addGroup('seed', seedId);
d.mo.aR(d.GROUP.seed) = d.mo.aR(d.GROUP.seed) * 0.6;
d.GROUP.groupId(d.GROUP.seed)=60;
%cut the model
allDelFilter = mo.aX < 0.2 | mo.aZ>0.4;
allDelFilter(seedId) = false;
allDelFilter((d.mNum+1):end) = false;
delId=find(allDelFilter);
d.delElement(delId);
d.GROUP.sample = setdiff(d.GROUP.sample, d.GROUP.seed);

center=mfs.getObjCenter(deviceObj);%check the center to move
deviceObj=mfs.move(deviceObj,0.4,0.5*B.sampleL,B.sampleH*0.3);

%add group
deviceId=d.addElement(1,deviceObj);
d.addGroup('device',deviceId,1);
d.addFixId('XYZ',d.GROUP.device);
d.delElement('topPlaten');
d.GROUP.groupProtect=[];

%set material
% matTxt=load('Mats\Soil2.txt');
% Mats{1,1}=material('Soil2',matTxt,B.ballR);
% Mats{1,1}.Id=1;
% matTxt2=load('Mats\StrongRock.txt');
% Mats{2,1}=material('StrongRock',matTxt2,B.ballR);
% Mats{2,1}.Id=2;
% d.Mats=Mats;
% d.setGroupMat('sample','Soil2');
% d.setGroupMat('all','StrongRock');
% d.groupMat2Model({'sample','all'},3);
%end material

d.mo.mVZ(d.GROUP.seed)=-30;%speed up the descent of seeds
d.minusGroup('sample','device',3);
d.minusGroup('sample','seed',3);
d.showFilter;d.showFilter('SlideY',0.48,'groupId');

d.setClump('device');
d.mo.zeroBalance();
d.mo.setShear('off');
d.mo.setGPU('on');
d.mo.dT=d.mo.dT*4;
circleNum = 20;
%d.moveBoundary('lefB',min(d.mo.aX(d.GROUP.seed)),0,0);
% for i=1:circleNum
%     if min(d.mo.aZ(d.GROUP.seed))<min(d.mo.aZ(d.GROUP.device))
%         d.mo.mVZ(d.GROUP.seed) = 0;
%     end
%     d.balance('Standard',0.1)
% end
d.balance('Standard',2);
d.minusGroup('sample','seed',1);
%d.balance('Standard',0.1);
%Tool Motion to device
mAll=Tool_Motion(d,'device');
mAll.Ts=allObj.Ts;%second
mAll.Xs=allObj.dX;%displacement
mAll.RXZs=allObj.RXZs;%degree
d.showFilter;d.showFilter('SlideY',0.48,'StressZZ');
d.clearData(1);
d.recordCalHour('BoxStep1Finish');
save(['TempModel/' B.name '1.mat'],'B','d');
save(['TempModel/' B.name '1R' num2str(B.ballR) '-' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);