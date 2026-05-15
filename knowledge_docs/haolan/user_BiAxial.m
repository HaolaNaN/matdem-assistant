clear;
fs.randSeed(2);%build random model
B=obj_Box;%build a box object
B.name='BiAxial';
B.GPUstatus='auto';
B.ballR=0.001;
B.isClump=0;
B.distriRate=0.2;
B.sampleW=0.1;
B.sampleL=0;
B.sampleH=0.2;
B.BexpandRate=10;
B.PexpandRate=10;
B.type='TriaxialCompression';
B.setType();
B.buildInitialModel();
B.setUIoutput();
d=B.d;

d.mo.setGPU('auto');
%--------------end initial model------------
B.gravitySediment();
B.compactSample(1);
%------------return and save result--------------
d.status.dispEnergy();%display the energy of the model

d.clearData(1);%clear dependent data
d.recordCalHour('Box1Finish');
save(['TempModel/' B.name '1.mat'],'B','d');
save(['TempModel/' B.name '1R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();
d.show('aR');

%%
clear;
load('TempModel/BiAxial1.mat');
B.setUIoutput();
d=B.d;
d.calculateData();
d.mo.setGPU('off');
d.getModel();

matTxt1=load('Mats\Rock1.txt');
Mats{1,1}=material('Rock1',matTxt1,B.ballR);
Mats{1,1}.Id=1;
d.Mats=Mats;
d.groupMat2Model({'sample'},1);    %赋予材料属性

d.mo.mGZ(:)=0;
d.mo.setShear('off');
B.SET.stressXX=-5e6;%confining pressure
B.SET.stressYY=0;
B.SET.stressZZ=-5e6;%axial pressure
B.setPlatenFixId();
d.resetStatus();
B.setPlatenStress(B.SET.stressXX,B.SET.stressYY,B.SET.stressZZ,B.ballR*5);

d.balanceBondedModel0(4);
d.mo.dT=d.mo.dT*4;
aMUp=d.mo.aMUp;d.mo.aMUp(:)=0;
d.balance('Standard',2);
d.mo.aMUp=aMUp;%restore friction
d.mo.dT=d.mo.dT/4;

d.connectGroup();
d.removePrestress();
d.deleteConnection('boundary');

d.mo.setGPU('off');
d.clearData(1);
d.recordCalHour('BoxModel2Finish');
save(['TempModel/' B.name '2.mat'],'B','d');
save(['TempModel/' B.name '2R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();
%%
clear;
load('TempModel/BiAxial2.mat');
d.calculateData();
d.mo.setGPU('off');
B.setUIoutput();
d=B.d;
d.mo.isCrack=1;

d.getModel();%d.setModel();%reset the initial status of the model
d.resetStatus();%initialize model status, which records running information
d.mo.isHeat=1;%calculate heat in the model

d.mo.setShear('on');
d.addFixId('XYZ',d.GROUP.topPlaten);
gpuStatus=d.mo.setGPU('auto');
totalCircle=10;
d.tic(totalCircle);
fName=['data\step\' B.name num2str(B.ballR) '-' num2str(B.distriRate) 'loopNum'];
save([fName '0.mat']);%return;
% d.mo.aBF=d.mo.aBF;
% d.mo.aMUp(d.GROUP.lefPlaten)=0;
% d.mo.aMUp(d.GROUP.rigPlaten)=0;
%d.mo.aMUp=d.mo.aMUp*0;
dis=0.02; %总位移
stepNum=10;
dDis=dis/stepNum/totalCircle;%每步位移
% ---------- 获取初始高度（压实后） ----------
sampleIDs = d.GROUP.sample;
z_min = min(d.mo.aZ(sampleIDs));
z_max = max(d.mo.aZ(sampleIDs));
H0 = z_max - z_min;                    % 初始试样高度
%sampleArea = pi * B.ballR^2;
% ---------- 位移控制加载，应变达到10%时停止 ----------
total_disp = 0;                         % 累积轴向位移（正值）
for i = 1:totalCircle
    for j=1:stepNum
        d.moveGroup('topPlaten', 0, 0, -dDis);
        d.balance('Standard', 0.1);            % 平衡计算
        z_min_now = min(d.mo.aZ(sampleIDs));
        z_max_now = max(d.mo.aZ(sampleIDs));
        H_current = z_max_now - z_min_now;
        strain = (H0 - H_current) / H0;      %应变
        F_vec = d.getGroupForce('topPlaten', 'sample');
        Fz = F_vec.totalGZ;                       
        stress_Pa = Fz / (B.sampleW * B.ballR);
        stress_MPa = stress_Pa / 1e6;

        % 可选：记录数据
        % strainVec(end+1) = strain;
        % stressVec(end+1) = stress_MPa;
    end
    d.figureNumber=d.show('ZDisplacement');
    d.mo.setGPU('off');
    save([fName num2str(i) '.mat']);%save data
    if strain >= 0.1
        d.dispNote(['应变达到10%，停止加载。当前应变: ', num2str(strain),'，当前循环第' num2str(i) '次']);
        break;
    end
end

d.mo.setGPU('off');
d.clearData(1);
d.recordCalHour('BoxCrush3Finish');
save(['TempModel/' B.name '3.mat'], 'd');
save(['TempModel/' B.name '3R' num2str(B.ballR) '-' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();
