fs.randSeed(2);%change it to get a different model,1,2,3
%------------------set the grain size and box size------------------
friction=0.1;
grainDensity=2650;%density of the grains
moNum='auto';%divided into 'moNum' size groups (childModel),0~10,'auto'

is2D=0;%0,1
isCement=0;%0 or 1
grading=1;%1,2,3,4
%friction=0.5;%0,0.2,0.4,0.6,0.8,1

strengthRate=1;%1,2,5,10,
compactionNum=10;%0,10,
compactionPressure=-1e4;

%--------------------------
rate='auto';%automatical balance rate in B.gravitySediment
sizeRate=1;%
hRate=1.15;% box is bigger a bit, 1.0~1.2
hRate=hRate+isCement*0.1-is2D*0.1+friction*0.02;
E=5e6;
matTxt2=[E,0.14,E*1e-3*strengthRate,E*1e-2*strengthRate,1,1800];%[20e6,0.14,20e3,200e3,0.8,1900];%load a un-trained material file
shearStatus='on';
%--------------------------
if is2D==1
totalM=2e-7;%total mass of the sample
sampleW=0.002;sampleL=0;%width and length of the model, height will be determined by totalM
else
sRate=0.1;
totalM=2e-7;%total mass of the sample
sampleW=0.01*sRate;sampleL=0.01*sRate;%width and length of the model, height will be determined by totalM
end
%minmum diameter, maximum diameter, and mass rate
%数组敏感性分析，主要差异段在50-400微米，因此在该段需要多段拆分
%grainSizeDistribution=[8.6,14.6,10.097;14.6,24.6,10.988;24.6,35,5.036;35,50.238,6.497;50.238,70.963,5.429;70.963,89.337,3.278;89.337,112.468,4.073;112.468,143.8,5.835;143.8,163.4,3.653;163.4,200,4.21;200,224.404,4.311;224.404,251.785,4.47;251.785,309.5,8.967;309.5,355.656,4.169;355.656,399.5,3.21;399.5,453.9,2.548;453.9,515.7,1.864]*1e-6;%determine the grain radius (grainR) according to the above data
grainSizeDistribution=[8.6,14.6,11.132;14.6,24.6,12.249;24.6,35,5.727;35,50.238,7.431;50.238,70.963,6.002;70.963,89.337,3.288;89.337,112.468,3.776;112.468,143.8,5.282;143.8,163.4,3.297;163.4,200,3.881;200,224.404,3.876;224.404,251.785,4.015;251.785,309.5,8.045;309.5,355.656,3.74;355.656,399.5,2.897;399.5,453.9,2.285;453.9,515.7,1.672]*1e-6;
grainR=mfs.getGradationDiameter(grainSizeDistribution,totalM/grainDensity)/2;

d_upper = grainSizeDistribution(:, 2); 
mass = grainSizeDistribution(:, 3); 

total_mass = sum(mass);
percent = (mass / total_mass) * 100; 
cum_percent = cumsum(percent); 
figure;plot(d_upper, cum_percent, '-o', 'LineWidth', 3, 'MarkerSize', 6);
grid on;xlabel('粒径 (m)');ylabel('累计占比 (%)');title('颗粒级配曲线');
%determine the box size
SET=mfs.getBoxSample(grainR,sampleW,sampleL,hRate);
SET.moNum=moNum;%divided into 'moNum' size groups
%------------------end set the grain size and box size------------------

%--------------initializing Box model------------
B=obj_Box;%build a box object
B.name='low3DVisgroup2';
B.GPUstatus='auto';
B.setType('topPlaten');
B.PexpandRate=2;%incease platen size
B.uniformGRate=1;
B.buildInitialModel(SET);%B.show();
B.setUIoutput();

d=B.d;
if B.sampleL==0
B.convert2D(B.ballR);%change ball properties to 2D
end

Mats{1,1}=material('soil1',matTxt2,B.ballR);
Mats{1,1}.Id=1;
d.Mats=Mats;
d.groupMat2Model();

d.mo.setShear(shearStatus);
d.mo.aMUp(:)=friction;
d.showB=1;
d.breakGroup();

d.mo.mVis=d.mo.mVis.*(d.mo.aR(1:d.mNum)/B.ballR);

%--------------end initializing Box model----------
B.gravitySediment(1,isCement);%element will be cemented when true
ballDis=min(4,d.SET.packNum*0.1);
pZ=min(d.mo.aZ(d.GROUP.topPlaten))-B.ballR*2*ballDis;
porosity=mfs.getPorosity(B,pZ);
fs.disp(['Porosity of assemblage is ' num2str(porosity*100) '%']);
save(['TempModel/' B.name '1R' num2str(B.ballR) '-is2D' num2str(is2D) ',isCement' num2str(isCement) ',grading' num2str(grading) ',strengthRate' num2str(strengthRate) ',friction' num2str(friction) '.mat']);

%% 压实阶段
B.compactSample(compactionNum,compactionPressure);
d.status.dispEnergy();%display the energy of the model
d.setData();
porosityC=mfs.getPorosity(B,pZ);
fs.disp(['Porosity after compaction is ' num2str(porosityC*100) '%']);
%d.showFilter('Group',{'sample'});
d.show();

%------------return and save result--------------
d.mo.setGPU('off');
d.clearData(1);%clear dependent data
d.recordCalHour('Step1Finish');
save(['TempModel/' B.name '1.mat'],'B','d');
save(['TempModel/' B.name '1R' num2str(B.ballR) '-Compactis2D' num2str(is2D) ',isCement' num2str(isCement) ',grading' num2str(grading) ',strengthRate' num2str(strengthRate) ',friction' num2str(friction) '.mat']);
d.calculateData();%because data is clear, it will be re-calculated