clear;
fs.randSeed(4);%change it to get a different model
type=1;%change it from 1 to 3 to generate three layers 
%------------------set the grain size and box size------------------
grainDensity=2650;%density of the grains
moNum='auto';%divided into 'moNum' size groups (childModel)
hRate=1.00;% box is bigger a bit, 1.0~1.2
if type==1
totalM=200e-3;%total mass of the sample
sampleW=70e-3;sampleL=70e-3;%width and length of the model, height will be determined by totalM
%minmum diameter, maximum diameter, and mass rate
grainSizeDistribution=[4,8,0.2;8,16,0.2;16,32,0.2]*1e-3;
elseif type==2
totalM=200e-3;%total mass of the sample
sampleW=70e-3;sampleL=70e-3;%width and length of the model, height will be determined by totalM
grainSizeDistribution=[4,8,0.2;8,16,0.2]*1e-3;
elseif type==3
totalM=200e-3;%total mass of the sample
sampleW=70e-3;sampleL=70e-3;%width and length of the model, height will be determined by totalM
grainSizeDistribution=[2,4,0.2;4,8,0.2]*1e-3;
end
%determine the grain radius (grainR) according to the above data
grainR=mfs.getGradationDiameter(grainSizeDistribution,totalM/grainDensity)/2;

%determine the box size
SET=mfs.getBoxSample(grainR,sampleW,sampleL,hRate);
SET.moNum=moNum;%divided into 'moNum' size groups
%------------------end set the grain size and box size------------------

%--------------initializing Box model------------
B=obj_Box;%build a box object
B.name='highSizeRatio';
B.GPUstatus='auto';
B.setType('topPlaten');
B.PexpandRate=2;
B.buildInitialModel(SET);%B.show();
B.setUIoutput();

d=B.d;
%--------------end initializing Box model------------
B.gravitySediment(1);

d.status.dispEnergy();%display the energy of the model
d.setData();
d.showFilter('Group',{'sample'});
d.show();

%cut the model, save it to struct C
sampleR=34e-3;
mX=d.mo.aX(1:d.mNum);
mR=d.mo.aR(1:d.mNum);
mY=d.mo.aY(1:d.mNum);
columnFilter=sqrt((abs(mX-sampleR)+mR).^2+((abs(mY-sampleR)+mR).^2))<sampleR;
d.delElement(find(~columnFilter));
C=d.group2Obj('sample');
Ctype=['C' num2str(type)];
C1=C;C2=C;C3=C;
save(['TempModel/highSizeRatio' Ctype '.mat'],Ctype);

%------------return and save result--------------
d.mo.setGPU('off');
d.clearData(1);%clear dependent data
d.recordCalHour('Step1Finish');
save(['TempModel/' B.name '1.mat'],'B','d');
save(['TempModel/' B.name '1R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();%because data is clear, it will be re-calculated