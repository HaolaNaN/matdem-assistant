clear;
fs.randSeed(2);
grainDensity=2650;
moNum=2;%divided into 'moNum' size groups (childModel)
hRate=1.00;
totalM=1;
coet= 0.015;
sampleW=coet*6;sampleL=coet*7;%width and length of the model, height will be determined by totalM
grainSizeDistribution=2*[0.4,0.6,0.1;2,4,0.9]*2e-3;
grainR=mfs.getGradationDiameter(grainSizeDistribution,totalM/grainDensity)/2;
%determine the box size
SET=mfs.getBoxSample(grainR,sampleW,sampleL,hRate);
SET.moNum=moNum;%divided into 'moNum' size groups
%------------------end set the grain size and box size------------------

%--------------initializing Box model------------
B=obj_Box;%build a box object
B.name='SandProduction';
B.GPUstatus='auto';
B.setType('topPlaten');
B.buildInitialModel(SET);

d=B.d;
d.showB=1;

B.gravitySediment();
B.compactSample(2);
mfs.reduceGravity(d,10)
d.show('aR');
d.mo.setGPU('off');
d.delElement('topPlaten');
B.SET.coet= coet;

d.clearData();%clear dependent data
d.recordCalHour('Step1Finish');
save(['TempModel/' B.name '0.mat'],'B','d');
d.calculateData();
