%% step 1
%build the geometrical model
clear;
fs.randSeed(1);%build random model
B=obj_Box;%build a box object
B.name='PRMTunnel';
B.GPUstatus='auto';
%--------------initial model------------
B.ballR=0.02;
B.isClump=0;
B.distriRate=0.3;
B.sampleW=1.2;
B.sampleL=0.6;
B.sampleH=0.6;
%B.BexpandRate=4;
%B.PexpandRate=4;
B.type='topPlaten';
%B.type='TriaxialCompression';
B.setType();
B.buildInitialModel();%B.show();
B.setUIoutput();

d=B.d;%d.breakGroup('sample');d.breakGroup('lefPlaten');
%--------------end initial model------------
B.gravitySediment();
B.compactSample(2);%iput is compaction time
mfs.reduceGravity(d,10);
%------------return and save result--------------
d.status.dispEnergy();%display the energy of the model

d.mo.setGPU('off');
d.clearData(1);%clear dependent data
d.recordCalHour('PRMBox1Finish');
save(['TempModel/' B.name '1.mat'],'B','d');
save(['TempModel/' B.name '1R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();
d.showFilter('Group','sample','aR');
d.showFilter;

%% step 2
%set the material of the model
clear
load('TempModel/PRMTunnel1.mat');
B.setUIoutput();
d=B.d;
d.calculateData();%calculate data after loading the .mat file
d.mo.setGPU('off');%close the GPU before handling the model
d.getModel();%get X,Y,Z,R.. from d.mo

%------------------remove top elements
mZ=d.mo.aZ(1:d.mNum);
topLayerFilter=mZ>max(mZ)*0.5;
d.delElement(find(topLayerFilter));

%--------------set material, define strong and weak rock
matTxt=load('Mats\StrongRock.txt');
Mats{1,1}=material('StrongRock',matTxt,B.ballR);
Mats{1,1}.Id=1;
matTxt2=load('Mats\WeakRock.txt');
Mats{2,1}=material('WeakRock',matTxt2,B.ballR);
Mats{2,1}.Id=2;
d.Mats=Mats;%assign the material to the model

%set different layers with different mechanical properties
dipD=90;dipA=60;strongT=0.1;weakT=0.1;%dipD: dip direction of layer; dipA: dip angle of layer
weakFilter=mfs.getWeakLayerFilter(d.mo.aX,d.mo.aY,d.mo.aZ,dipD,dipA,strongT,weakT);%make weak layer filter of the box model
sampleId=d.getGroupId('sample');
aWFilter=false(size(weakFilter));
aWFilter(sampleId)=true;
sampleWfilter=aWFilter&weakFilter;
d.addGroup('WeakLayer',find(sampleWfilter));%define a WeakLayer group

%B.setPlatenFixId();
d.setGroupMat('WeakLayer','WeakRock');%material of WeakLayer group is WeakRock
d.groupMat2Model({'WeakLayer'},1);%assign material to WeakLayer group, material Id of other elements is 1
%d.show('StressZZ');view(5,5);

%create a hob, define the size of a hob
hobR=0.2;hobT=0.1;ballR=B.ballR;Rrate=0.7;cutRate=1;
hob=mfs.makeHob(hobR,hobT,cutRate,ballR,Rrate);
%fs.showObj(hob);%show the hob
hob=mfs.rotate(hob,'YZ',90);

%change the hob object to a build object to get nearby ball matrix
hobd=mfs.Obj2Build(hob);
aCN=sum(hobd.mo.nBall~=hobd.aNum,2);
aCN=[aCN;0];
CNFilter=aCN<mean(aCN)*0.88;
hobd.showFilter('Filter',CNFilter);
%hobd.showFilter('SlideZ',0,0.3);
mFilter=hobd.data.showFilter(1:hobd.mNum);
hob=mfs.filterObj(hob,mFilter);%make new object

%add a central ball to record the coordinates
hob.X=[hob.X;(max(hob.X)+min(hob.X))/2];
hob.Y=[hob.Y;(max(hob.Y)+min(hob.Y))/2];
hob.Z=[hob.Z;(max(hob.Z)+min(hob.Z))/2];
hob.R=[hob.R;mean(hob.R)];

%fs.showObj(hob);
%-------------add the hob to the model
hobId=d.addElement(1,hob);%mat Id, obj
d.addGroup('Hob',hobId);
sampleId=d.GROUP.sample;
d.moveGroup('Hob',hobR,(max(d.aY(sampleId))+min(d.aY(sampleId)))/2,0);
hobBot=min(d.mo.aZ(hobId)-d.mo.aR(hobId));
sampleTop=max(d.mo.aZ(sampleId)+d.mo.aR(sampleId));
d.moveGroup('Hob',0,0,sampleTop-hobBot);
d.setClump('Hob');%define the hob as a clump
d.removeGroupForce(d.GROUP.Hob,[d.GROUP.topB;d.GROUP.rigB]);%not force between hob and boundaries

d.mo.isFix=1;
d.addFixId('X',hobId);%fix the X-coordinate of the hob
d.addFixId('Y',hobId);%fix the Y-coordinate of the hob
d.mo.zeroBalance();
%d.show('StressZZ');return;
d.balanceBondedModel0();%setGPU Auto
d.mo.bFilter(:)=0;
d.balance('Standard');%==d.balance(50,d.SET.packNum);
%d.balanceBondedModel();%bonded all elements and balance the model with element friction
d.balanceBondedModel0();%bonded all elements and balance the model without element friction
d.addFixId('Z',hobId);%fix the Y-coordinate of the hob

d.mo.setGPU('off');
d.clearData(1);
d.recordCalHour('PRMBox2Finish');
save(['TempModel/' B.name '2.mat'],'B','d');
save(['TempModel/' B.name '2R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();
d.show('ZDisplacement');

%% step 3
clear;
load('TempModel/PRMTunnel2.mat');
B.setUIoutput();
d=B.d;
d.calculateData();
d.mo.setGPU('off');
hobR=0.2;hobT=0.1;ballR=B.ballR;Rrate=0.7;cutRate=1;
%d.setClump('sample');
%d.addFixId('XYZ',d.GROUP.sample);
% PRM参数初始化
PRM_settings = struct();
PRM_settings.criterion = 'force';          % 使用接触力准则
PRM_settings.threshold = 3e+5;             % 力阈值(N)
PRM_settings.checkInterval = 5;            % 每5步检测一次
PRM_settings.maxFragments = 6;             % 最大碎片数
PRM_settings.packingDensity = 0.7;         % 堆积密度
PRM_settings.detectionRadius = hobR * 1.5; % 检测半径
PRM_settings.minRadius = B.ballR * 0.8;    % 最小替换半径：小于该值的颗粒不会被替换，防止生成过小颗粒

% 初始化计数器
stepCounter = 0;
totalReplaced = 0;

d.mo.mVX(:)=0;d.mo.mVY(:)=0;d.mo.mVZ(:)=0;
d.status=modelStatus(d);%initialize model status, which records running information


d.mo.isHeat=1;%calculate heat in the model
visRate=0.00001;
d.mo.mVis=d.mo.mVis*visRate;
d.setStandarddT();%set standard step time

%--------------define the interation
totalCircle=10;stepNum=20;
balanceNum=5;%you may use greater stepNum and balanceNum
disp(['Total real time is ' num2str(d.mo.dT*totalCircle*stepNum*balanceNum)]);
d.tic(totalCircle*stepNum);
fName=['data/step/' B.name  num2str(B.ballR) '-' num2str(B.distriRate) 'loopNum'];

%define the movement of the hob
sampleX=d.mo.aX(d.GROUP.sample);
hobX=d.mo.aX(d.GROUP.Hob);
hobR=(max(hobX)-min(hobX))/2+B.ballR*2;
dis=(max(sampleX)-min(sampleX))-hobR*2;
Dis=[1,0,-0.1]*dis;
dDis=Dis/(totalCircle*stepNum);
dDis_L=sqrt(sum(dDis.^2));
dAngle=dDis_L/hobR*180/pi;

%d.show('Displacement');return;
d.mo.bFilter(:)=1;%bond all elements
d.mo.zeroBalance();
save([fName '0.mat']);%return;
gpuStatus=d.mo.setGPU('auto');

% 记录每轮循环后的碎片数量变化
fragmentStats = []; % 每轮记录 [轮次, fragment数量, 本轮新增碎片数]

for i=1:totalCircle
    newFragsThisRound = 0;  % 初始化本轮新增碎片计数器
     for j=1:stepNum
        hobId=d.GROUP.Hob;
        hobCx=gather(d.mo.aX(hobId(end)));
        hobCy=gather(d.mo.aY(hobId(end)));
        hobCz=gather(d.mo.aZ(hobId(end)));

        % === PRM检测和替换 ===
        if mod(stepCounter, PRM_settings.checkInterval) == 0
            center = [hobCx, hobCy, hobCz];
            [replaceIds, fragments] = phlf.detectReplaceableParticles(d, center, ...
                PRM_settings.detectionRadius, PRM_settings);

            if ~isempty(replaceIds)
                [d, newFragIds] = phlf.replaceParticlesPRM(d, replaceIds, fragments, PRM_settings);
                totalReplaced = totalReplaced + length(replaceIds);
                newFragsThisRound = newFragsThisRound + length(newFragIds);  % 累加本轮新增碎片数
            end

        end
        d.moveGroup('Hob',dDis(1),dDis(2),dDis(3));
        d.rotateGroup('Hob','XZ',-dAngle,hobCx,hobCy,hobCz);
        d.balance(balanceNum);
        stepCounter = stepCounter + 1;
        % === 结束PRM ===
        d.recordStatus();
        d.toc();
    end

    d.clearData(1);
    % 更新fragment组（追加方式，在replaceParticlesPRM中已维护）
    if isfield(d.GROUP, 'fragment') && ~isempty(d.GROUP.fragment)
        % 去重并移除无效ID
        d.GROUP.fragment = unique(d.GROUP.fragment);
        d.GROUP.groupId(d.GROUP.fragment) = 50;
        fragmentStats = [fragmentStats; i, length(d.GROUP.fragment), newFragsThisRound];
    else
        fragmentStats = [fragmentStats; i, 0, newFragsThisRound];
    end

    d.figureNumber=d.show('groupId');

        orphanIds = [];
    for id = 1:d.mNum
        inSample = ismember(id, d.GROUP.sample);
        inHob = ismember(id, d.GROUP.Hob);
        inFragment = isfield(d.GROUP,'fragment') && ismember(id, d.GROUP.fragment);
        inBoundary = false;
        bGroups = {'topB','botB','lefB','rigB','froB','bacB'};
        for g = 1:length(bGroups)
            if isfield(d.GROUP, bGroups{g}) && ismember(id, d.GROUP.(bGroups{g}))
                inBoundary = true;
                break;
            end
        end
        if ~inSample && ~inHob && ~inFragment && ~inBoundary
            orphanIds = [orphanIds; id];
        end
    end
    if ~isempty(orphanIds)
        fprintf('第%d轮: 发现%d个孤儿颗粒\n', i, length(orphanIds));
        % 快速检查这些孤儿颗粒来自哪里
        if isfield(d.GROUP, 'WeakLayer')
            orphansInWeak = intersect(orphanIds, d.GROUP.WeakLayer);
            if ~isempty(orphansInWeak)
                fprintf('  -> %d个孤儿原本在WeakLayer中\n', length(orphansInWeak));
            end
        end
    end

    save([fName num2str(i) '.mat']);
    d.calculateData();
end

d.mo.setGPU('off');
d.clearData(1);
d.recordCalHour('BoxTBMCutter3Finish');
save(['TempModel/' B.name '3.mat'],'B','d');
save(['TempModel/' B.name '3R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();