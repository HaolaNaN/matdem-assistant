clear;
fs.randSeed(1);%build random model
B=obj_Box;%build a box object
B.name='sanzhou';
B.GPUstatus='auto';
B.ballR=0.00075;
B.isClump=0;
B.distriRate=0.2;
B.SET.sampleR=0.025;
B.SET.sampleH=0.1;
B.sampleW=B.SET.sampleR*3;
B.sampleL=B.SET.sampleR*3;
B.sampleH=B.SET.sampleH*1.5;
B.type='topPlaten';
B.setType();
B.buildInitialModel();%B.show();
B.setUIoutput();
d=B.d;
%--------------end initial model------------
B.gravitySediment();
B.compactSample(2);%input is compaction time
%mfs.reduceGravity(d,10);%reduce the gravity of element
%------------return and save result--------------
d.status.dispEnergy();%display the energy of the model
d.show('aR');
d.mo.setGPU('off');
d.clearData(1);%clear dependent data
d.recordCalHour('Step0Finish');
save(['TempModel/' B.name '1.mat'],'B','d');
d.calculateData();%because data is clear, it will be re-calculated