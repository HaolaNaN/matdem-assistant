%set the material of the model
clear
load('TempModel/RainfallSlope1.mat');
B.setUIoutput();%set output of message
d=B.d;
d.calculateData();
d.mo.setGPU('off');
d.getModel();%get xyz from d.mo

%---------cut the model to make slope
C=Tool_Cut(d);%cut the model
lSurf=load('USER/rainfallSlope/layer surface 4.txt');%load the surface data
C.addSurf(lSurf);%add the surfaces to the cut
C.setLayer({'sample'},[1,2]);%set layers according geometrical data
gNames={'lefPlaten';'rigPlaten';'botPlaten';'layer1'};
d.makeModelByGroups(gNames);
%---------end cut the model to make slope
d.show('aR');

%----------set material of model
matTxt=load('Mats\Soil1.txt');
Mats{1,1}=material('Soil1',matTxt,B.ballR);
Mats{1,1}.Id=1;
d.Mats=Mats;
d.groupMat2Model({'sample'},1);
%----------end set material of model

d.balanceBondedModel();

%---------save the data
d.mo.setGPU('off');
d.clearData(1);
d.recordCalHour('RainfallSlope2Finish');
save(['TempModel/' B.name '2.mat'],'B','d');
save(['TempModel/' B.name '2R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();