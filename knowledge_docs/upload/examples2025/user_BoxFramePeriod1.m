clear;
fs.randSeed(1);
%---------------------define parameters----------------------
ballR=0.015;%<=0.015, mean ball radius, 0.003
sampleW=0.5;%width (X) of the model
sampleL=0.2;%lenght (Y) of the model, 0 to get 2D model
sampleH=0.3+ballR*2;%height
frame=[0,0,0,sampleW,sampleL,sampleH];%first three value must be zero
%---------------------end define parameters----------------------

%----------make a Box, and import the objects to the box---------
B=obj_Box('FramePeriod');%declare a box object
B.ballR=ballR;%element radius
B.setFrame(frame);
B.setType('topPlaten');
B.buildInitialModel();

d=B.d;
B.gravitySediment();
d.mo.setShear('off');
d.delElement('topPlaten');

%the following code is optional
d.mo.setGPU('auto');
d.mo.dT=d.mo.dT*4;
d.balance('Standard',1);
d.setStandarddT();

d.show();
fs.saveData(B,1);%as the data in the folder TempModel