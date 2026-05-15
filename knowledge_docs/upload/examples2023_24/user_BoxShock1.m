%code for 2024 training
clear;
seedId=1;%make different model
fs.chooseGPU(1);
fs.randSeed(seedId);%change it to get a different model

%------------------set the grain size and box size------------------
rate='auto';%automatical balance rate in B.gravitySediment
isCement=0;%whether elements will be cemented when contacting, 1 high porosity
is2D=1;%build 3D model when is2D=0

%--------------step1: initializing Box model------------
B=obj_Box;%build a box object
if is2D==1
    sampleW=20;sampleL=0;sampleH=10;%width and length of the model, height will be determined by totalM
    ballR=5e-2;
else
    sampleW=5;sampleL=5;sampleH=3;%width and length of the model, height will be determined by totalM
    ballR=4e-2;
end
B.name='BoxShock';
B.GPUstatus='auto';
B.ballR=ballR;
B.isClump=0;
B.distriRate=0.2;
B.sampleW=sampleW;
B.sampleL=sampleL;
B.sampleH=sampleH;
B.type='topPlaten';
B.setType();
B.buildInitialModel();%B.show();
B.setUIoutput();
%--------------step1: end initializing Box model------------

%--------------step2: gravitySediment------------
d=B.d;
B.gravitySediment(rate,isCement);%element will be cemented when true

d.show();
%return and save result--------------
d.status.dispEnergy();%display the energy of the model
d.mo.setGPU('off');
d.clearData(1);%clear dependent data
d.recordCalHour('Shock1Finish');
save(['TempModel/' B.name '1.mat'],'B','d','-v7.3');
save(['TempModel/' B.name '1R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();%because data is clear, it will be re-calculated
%--------------step2: end gravitySediment------------