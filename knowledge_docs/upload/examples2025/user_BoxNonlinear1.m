clear;
fs.randSeed(1);
%---------------------start define the struct objects----------------------
ballR=0.1;
sampleW=4;
sampleL=4;
sampleH=3;

%fs.showObj(rectObj);
%---------------------end define the struct objects----------------------

%----------make a Box, and import the objects to the box---------
B=obj_Box;%declare a box object
B.name='BoxNonlinear';
B.ballR=ballR;%element radius
B.sampleW=sampleW;%width, length, height
B.sampleL=sampleL;%when L is zero, it is a 2-dimensional model
B.sampleH=sampleH;
B.isSample=1;%an empty box without sample elements

B.boundaryStatus=[0,0,0,0,0,0];%only botB and botPlaten will be set
B.setType('topPlaten');
B.buildInitialModel();
                                                                                            
%return
d=B.d;
d.mo.setShear('off');
%set the frame for showing the results
frame.minX=0;
frame.minY=0;
frame.minZ=0;
frame.maxX=B.sampleW;
frame.maxY=B.sampleL;
frame.maxZ=B.sampleH+B.ballR*2;
d.setFrame(frame);

%make sure all the elements will be limited in the frame area
d.mo.isFrame=1;

%----------end make a Box, and import the objects to the box---------
%d.mo.dT=d.mo.dT*4;
d.mo.setGPU('auto');
tic
B.gravitySediment();
d.mo.setShear('off');%increase density
B.compactSample(5);%increase density
d.mo.setShear('on');
toc

d.show('aR');
d.clearData(1);
d.recordCalHour('BoxStep1Finish');
save(['TempModel/' B.name '1.mat'],'B','d');
save(['TempModel/' B.name '1R' num2str(B.ballR) '-' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();