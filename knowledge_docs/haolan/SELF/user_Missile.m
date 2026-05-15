%% step1
clear;
fs.randSeed(1);%random model seed, 1,2,3...
B=obj_Box;%declare a box object
B.name='BoxCrash';
%--------------initial model------------
B.GPUstatus='auto';%program will test the CPU and GPU speed, and choose the quicker one
B.ballR=2.5;
B.isShear=0;
B.isClump=0;%if isClump=1, particles are composed of several balls
B.distriRate=0.2;%define distribution of ball radius, 
B.sampleW=500;%width, length, height, average radius
B.sampleL=400;%when L is zero, it is a 2-dimensional model
B.sampleH=300;
B.BexpandRate=4;%boundary is 4-ball wider than sample
B.PexpandRate=0;
B.type='topPlaten';%add a top platen to compact model
B.isSample=1;
%B.type='TriaxialCompression';
B.setType();
B.buildInitialModel();%B.show();
B.setUIoutput();

d=B.d;%d.breakGroup('sample');d.breakGroup('lefPlaten');
%you may change the size distribution of elements here, e.g. d.mo.aR=d.aR*0.95;
d.mo.setShear('off');
frame.minX=0;
frame.minY=0;
frame.minZ=0;
frame.maxX=B.sampleW;
frame.maxY=B.sampleL;
frame.maxZ=B.sampleH+B.ballR*2;
d.setFrame(frame);

d.mo.isFrame=1;
d.mo.setGPU('auto');

%1. The simpleContact is the default contact model
%d.mo.balanceCommand='ContactModel.simpleContact(obj);';
%2. The normalContact only consider the normal force of element
%d.mo.balanceCommand='ContactModel.normalContact(obj);';
%3. The normalContact model is defined in a function file
%d.mo.setBalanceFunction('fun/normalContact.m');%user-defined normal model
%--------------end initial model------------

%---------- gravity sedimentation
B.gravitySediment();%you may use B.gravitySediment(10); to increase sedimentation time (10)
%d.show('mV');return;
%B.compactSample(1);%input is compaction time
%------------return and save result--------------
d.status.dispEnergy();%display the energy of the model

d.mo.setGPU('off');
d.clearData(1);%clear dependent data
d.recordCalHour('Step1Finish');
save(['TempModel/' B.name '1.mat'],'B','d');
save(['TempModel/' B.name '1R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();

%% step 2
%set the material of the model
clear
load('TempModel/BoxCrash1.mat');
B.setUIoutput();%set the output
d=B.d;
d.calculateData();%calculate data
d.mo.setGPU('off');%close the GPU calculation
d.getModel();%get xyz from d.mo
%---------------delete elements on the top
mZ=d.mo.aZ(1:d.mNum);%get the Z of elements
topLayerFilter=mZ>max(mZ)*0.5;
d.delElement(find(topLayerFilter));%delete elements according to id

sampleId = d.GROUP.sample;
ballR = mean(d.mo.aR(sampleId));
CC = find(d.mo.aX(sampleId)>235-2*ballR &d.mo.aX(sampleId)<265+2*ballR & (d.mo.aX(sampleId)-250).^2+(d.mo.aZ(sampleId)-40).^2<225+45*ballR & d.mo.aZ(sampleId)>40);
cc = find(d.mo.aX(sampleId)>235-2*ballR &d.mo.aX(sampleId)<265+2*ballR &d.mo.aZ(sampleId)<40 & d.mo.aZ(sampleId)>30-2*ballR);
CC =[CC;cc];
d.delElement(CC)

%--------------assign new material
matTxt=load('Mats\StrongRock.txt');%load material file
Mats{1,1}=material('StrongRock',matTxt,B.ballR);
Mats{1,1}.Id=1;
matTxt2=load('Mats\WeakRock.txt');
Mats{2,1}=material('WeakRock',matTxt2,B.ballR);
Mats{2,1}.Id=2;
d.Mats=Mats;%assign new material
%d.groupMat2Model({'sample'},1);%apply the new material

%----------make disc sample------------
%{
sampleId=d.GROUP.sample;
sX=d.aX(sampleId);sZ=d.aZ(sampleId);sR=d.aR(sampleId);
discCX=mean(sX);discCZ=mean(sZ);
discR=20;
discFilter=(d.aX-discCX).^2+(d.aZ-discCZ).^2<discR^2;
%d.setData();d.data.showFilter=discFilter;d.show('aR');
d.addGroup('Disc0',find(discFilter));%add a new group
discObj=d.group2Obj('Disc0');

discId=d.addElement('StrongRock',discObj);%mat Id, obj
d.addGroup('Disc',discId);%add a new group
disZ=max(sZ+sR)-min(discObj.Z-discObj.R);
d.moveGroup('Disc',0,0,disZ);%move the group
%}

%cc = find(d.mo.aZ(CC)<100 & d.mo.aZ(CC)>50)
%d.addGroup('mid',CC)
%d.showFilter()
%d.showFilter('Group','mid','aR')
%d.show('aR')

dipD=90;dipA=60;strongT=10;weakT=6;%dipD: dip direction of layer; dipA: dip angle of layer
weakFilter=mfs.getWeakLayerFilter(d.mo.aX,d.mo.aY,d.mo.aZ,dipD,dipA,strongT,weakT);%make weak layer filter of the box model
sampleId=d.getGroupId('sample');
aWFilter=false(size(weakFilter));
aWFilter(sampleId)=true;
sampleWfilter=aWFilter&weakFilter;
d.addGroup('WeakLayer',find(sampleWfilter));%define a WeakLayer group

ballR = 2;
Rrate=0.9;
lineX=[235+ballR;265-ballR;265-ballR;7.5*sqrt(3)+250-ballR;257.5-ballR;250;242.5+ballR;-7.5*sqrt(3)+250+ballR;235+ballR;235+ballR];
lineY=zeros(size(lineX));
lineZ=[30+ballR;30+ballR;40;47.5-ballR;40+7.5*sqrt(3)-ballR;55-ballR;40+7.5*sqrt(3)-ballR;47.5-ballR;40;30+ballR];
curveObj2=mfs.make3DCurve(lineX,lineY,lineZ,ballR,Rrate);

lineX=[235;265;265;7.5*sqrt(3)+250;257.5;250;242.5;-7.5*sqrt(3)+250;235;235];
lineY=zeros(size(lineX));
lineZ=[30;30;40;47.5;40+7.5*sqrt(3);55;40+7.5*sqrt(3);47.5;40;30];
curveObj3=mfs.make3DCurve(lineX,lineY,lineZ,ballR,Rrate);

curveObj=mfs.combineObj(curveObj2,curveObj3);

curveObj3D = mfs.make3Dfrom2D(curveObj,B.sampleL,ballR,'Y',Rrate);
fs.showObj(curveObj3D)

if B.sampleL == 0
    tunnelId = d.addElement('StrongRock',curveObj);
    missleL = 4;
    missleH = 12;
    ballR = 0.25;
    rate = 0.7;
    width = missleL;
    length =missleH;
    xNum=ceil(width/(2*ballR))/0.7;
    zNum=ceil(length/(2*ballR))/0.7;
    dx=(width-2*ballR)/(xNum-1);
    dy=(length-2*ballR)/(zNum-1);
    if xNum<=1
        xNum=1;dx=0;
    end
    if zNum<=1
        zNum=1;dy=0;
    end
    xList=ballR+(0:xNum-1)*dx;
    zList=ballR+(0:zNum-1)*dy;
    [X,Z]=meshgrid(xList,zList);
    rect.X=X(:);rect.Z=Z(:);
    rect.Y=zeros(size(rect.X));
    rect.R=ones(size(rect.X))*ballR;
    rect.width=width;rect.length=length;
    figure
    fs.showObj(rect)

    triL = 4;
    triH = 4;
    midCenterX=triL/2;
    midCenterY=0+ballR;
    yNum=ceil(triH/(2*ballR))/0.7;
    obj.X=[];
    obj.Z=[];
    for i = 1:yNum
        width = (triH-(i-1)*(2*ballR)*rate)*triL/triH;
        xNum =  ceil(width/(2*ballR))/rate;
        num = ceil(xNum / 2);

        midCenterY = midCenterY-(2*ballR)*rate;
        for j = 1:num
            xList=[];
            zList=[];
            if j==1
                xList=[midCenterX];
                zList=[midCenterY];
            else
                xList=[midCenterX-(j-1)*rate*2*ballR;midCenterX+(j-1)*rate*2*ballR];
                zList=[midCenterY;midCenterY];
            end

            %{
        if num*2 >xNum
            
            if j==1
                xList=[midCenterX];
                yList=[midCenterY];
            else
                xList=[midCenterX-(j-1)*rate*2*ballR;midCenterX+(j-1)*rate*2*ballR];
                yList=[midCenterY;midCenterY];
            end
        else
            xList=[midCenterX-(j-1.5)*rate*2*ballR;midCenterX+(j-1.5)*rate*2*ballR];
            yList=[midCenterY;midCenterY];
            if j==num
                xList=[xList;midCenterX-(j-2.5)*rate*2*ballR;midCenterX+(j-2.5)*rate*2*ballR];
                yList=[yList;midCenterY;midCenterY];
            end
        end
            %}
            obj.X=[obj.X;xList];
            obj.Z=[obj.Z;zList];
        end

    end
    obj.Y=zeros(size(obj.X));
    obj.R=ones(size(obj.X))*ballR;

    missile1=mfs.combineObj(rect,obj);
    missile2=mfs.combineObj(rect,obj);
    missile3=mfs.combineObj(rect,obj);
    fs.showObj(missile1)
    missile1Id = d.addElement('StrongRock',missile1);
    missile2Id = d.addElement('StrongRock',missile2);
    missile3Id = d.addElement('StrongRock',missile3);
    d.addGroup('missile1',missile1Id)
    d.addGroup('missile2',missile2Id)
    d.addGroup('missile3',missile3Id)
    d.moveGroup('missile1',150,0,200)
    d.moveGroup('missile2',250,0,200)
    d.moveGroup('missile3',350,0,200)
    missileId = [missile1Id;missile2Id;missile3Id];
    d.addGroup('missile',missileId)
    d.setClump('missile')
    B.isClump('missile') = 2;
    d.addFixId('X',missileId);
else
    tunnelId = d.addElement('StrongRock',curveObj3D);
    type=[1;1;1];
    %TConeBoxObj=mfs.makeTruncatedCone(2,5,10,2,0.7,type)
    figure;
    TConeBoxObj=mfs.makeTruncatedCone(1,3,4,1.5,0.7,type);

    colObj = mfs.makeColumnBox(3,16,1.5,0.7,type);
    colObj.Z = colObj.Z + 2.5;

    obj1=mfs.combineObj(colObj,TConeBoxObj);
    obj2 = obj1;
    obj2.X = obj2.X + 100;
    obj3 = obj2;
    obj3.X = obj3.X +100;
    obj=mfs.combineObj(obj1,obj2,obj3);
    fs.showObj(obj)
    missile1Id = d.addElement('StrongRock',obj1);
    missile2Id = d.addElement('StrongRock',obj2);
    missile3Id = d.addElement('StrongRock',obj3);
    missileId = [missile1Id;missile2Id;missile3Id];
    d.addGroup('missile',missileId)
    d.addGroup('missile1',missile1Id)
    d.addGroup('missile2',missile2Id)
    d.addGroup('missile3',missile3Id)
    d.moveGroup('missile',150,200,200)
    d.setClump('missile')
    B.isClump('missile') = 2;
    %d.rotateGroup('missile','XZ',30);
    d.addFixId('X',missileId);
end

d.addGroup('tunnel',tunnelId)
d.setClump('tunnel')
B.isClump('tunnel') = 2;

%d.minusGroup('sample','tunnel',0.4);

%coneTubeObj=mfs.makeConeTube(3,10,10,1)
%---------assign material to layers and balance the model
d.setGroupMat('WeakLayer','WeakRock');%material of WeakLayer group is WeakRock
d.groupMat2Model({'WeakLayer'},1);%assign material to WeakLayer group, material Id of other elements is 1


d.balanceBondedModel0();%balance the bonded model without friction
d.show('aMatId');
d.clearData(1);%clear dependent data
d.recordCalHour('Step2Finish');
save(['TempModel/' B.name '2.mat'],'B','d');
save(['TempModel/' B.name '2R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();
%% step3
ufs.setTitle('MatDEM钻地弹撞击地面实时模拟');
clear;
load('TempModel/BoxCrash2.mat');
d.calculateData();
d.mo.setGPU('off');
B.setUIoutput();
d=B.d;
d.getModel();%d.setModel();%reset the initial status of the model
d.resetStatus();%initialize model status, which records running information
d.mo.isShear=0;
d.mo.isClump=2;
d.mo.isHeat=1;%calculate heat in the model
visRate=0.01;
d.mo.mVis=d.mo.mVis*visRate;
isBoom1 = 1;
isBoom2 = 1;
isBoom3 = 1;
bombExpandRate = 1.5;
%discId=d.GROUP.Disc;
missileId=d.GROUP.missile;
d.setStandarddT();
d.mo.dT=d.mo.dT*4;%increase step time to increase computing speed


%d.mo.mVX(missileId)=577;rate
missile1Id=d.GROUP.missile1;
missile2Id=d.GROUP.missile2;
missile3Id=d.GROUP.missile3;
d.mo.mVZ(missileId)=-1000;
d.addFixId('X',d.GROUP.missile)
B.isClump(d.GROUP.tunnel)=0;
d.showB=0;
d.status.legendLocation='West';


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
%d.show('mVis')
d.showFilter('SlideX',0.5,1,'mVis')

%----------set the drawing of result during iterations
setappdata(0,'simpleFigure',1);
setappdata(0,'ballRate',0.01);
showType='mV';
%----------end set the drawing of result during iterations
topSample = max(d.mo.aZ(d.GROUP.sample));
gpuStatus=d.mo.setGPU('auto');
totalCircle=1000;
d.tic(totalCircle);
fName=['data/step/' B.name num2str(B.ballR) '-' num2str(B.distriRate) 'loopNum'];
save([fName '0.mat']);%return;

displacementZ = [min(d.mo.aZ(missile1Id))];
velocityZ = [mean(d.mo.mVZ(missile1Id))];

for i=1:totalCircle
    d.mo.setGPU(gpuStatus);
    d.balance('Standard',0.001);
    if(isBoom1 == 1)
        displacementZ = [displacementZ;min(d.mo.aZ(missile1Id))];
        velocityZ = [velocityZ;mean(d.mo.mVZ(missile1Id))];
    end
    if( mean(d.mo.aZ(missile1Id) < topSample-30 )&& isBoom1 == 1)
        d.mo.aR(missile1Id)=d.mo.aR(missile1Id)*bombExpandRate;%increase bomb element size
        isBoom1 = 0 ;
        %B.isClump(missile1Id) = 0
        d.removeFixId('X',missile1Id)
        nfilter = mfs.groupConnectFilter(d.mo.nBall,d.GROUP.missile1,d.GROUP.missile1);
        d.mo.nClump(nfilter) = 0;
    end
    if( mean(d.mo.aZ(missile2Id) < topSample-30 )&& isBoom2 == 1)
        d.mo.aR(missile2Id)=d.mo.aR(missile2Id)*bombExpandRate;%increase bomb element size
        isBoom2 = 0 ;
        B.isClump(missile2Id) = 0;
        d.removeFixId('X',missile2Id)
        nfilter = mfs.groupConnectFilter(d.mo.nBall,d.GROUP.missile2,d.GROUP.missile2);
        d.mo.nClump(nfilter) = 0;
    end
    if( mean(d.mo.aZ(missile3Id) < topSample-30 )&& isBoom3 == 1)
        d.mo.aR(missile3Id)=d.mo.aR(missile3Id)*bombExpandRate;%increase bomb element size
        isBoom3 = 0 ;
        B.isClump(missile3Id) = 0;
        d.removeFixId('X',missile3Id)
        nfilter = mfs.groupConnectFilter(d.mo.nBall,d.GROUP.missile3,d.GROUP.missile3);
        d.mo.nClump(nfilter) = 0;
    end
    %d.showFilter('Group',{'missile','tunnel'},'mV')
    d.showFilter('SlideY',0.5,1,'mV');
    d.figureNumber=d.show(showType);%result will be shown in one figure
    d.show('mV')
    view(0,0)
    clim([0,300]);
    d.clearData(1);
    save([fName num2str(i) '.mat']);
    d.calculateData();
    pause(0.05);
    d.toc();%show the note of time
end
d.mo.setGPU('off');
d.clearData(1);
d.recordCalHour('BoxCrush3Finish');
save(['TempModel/' B.name '3.mat'],'d');
save(['TempModel/' B.name '3R' num2str(B.ballR) '-' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();
