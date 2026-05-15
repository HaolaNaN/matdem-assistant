discR=0.3;
totalTime=2;
spaceSize=discR*3;%define the size of the box
%--------------initialize model------------
B=obj_Box;%declare a box object
B.name='SeedSow';
B.ballR=0.03;%element radius changed to make less elements
B.sampleW=spaceSize*2;%width, length, height
B.sampleL=spaceSize*0.6;
B.sampleH=spaceSize*2;
B.isSample=1;
B.setType('topPlaten');
B.buildInitialModel();
B.gravitySediment();
d=B.d;

d.SET.totalTime=totalTime;
mo = d.mo;
%seed & cut the model
seedFilter = (mo.aX >= 0.3) & (mo.aX <= 0.6) & (mo.aY >= (0.24))& (mo.aY <= (0.30)) & (mo.aZ >= 0.35) & (mo.aZ <= 0.55);
seedFilter((d.mNum+1):end) = false;
seedId = find(seedFilter);
d.addGroup('seed', seedId);
d.mo.aR(d.GROUP.seed) = d.mo.aR(d.GROUP.seed) * 0.4;
d.GROUP.groupId(d.GROUP.seed)=60;
%cut the model
allDelFilter = mo.aX < 0.2 | mo.aZ>0.4;
allDelFilter(seedId) = false;
allDelFilter((d.mNum+1):end) = false;
delId=find(allDelFilter);
d.delElement(delId);
d.GROUP.sample = setdiff(d.GROUP.sample, d.GROUP.seed);

%------------return and save result--------------
d.status.dispEnergy();%display the energy of the model
d.mo.setGPU('off');
d.clearData(1);%clear dependent data
d.recordCalHour('Step1Finish');
save(['TempModel/' B.name '1.mat'],'B','d');
save(['TempModel/' B.name '1R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();