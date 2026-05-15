clear
[B,d]=fs.loadData('FramePeriod1.mat');%load data
d.getModel();%get X,Y,Z,R.. from d.mo
d.resetStatus();
directions='XY';%directions of periodic boundary, can be X, XY, XYZ...

%--------------assign new material
d.Mats=[];%reset the materials
d.addMaterial('Soil1','Mats\Soil1.txt',B.ballR);
d.groupMat2Model({'sample'},1);%apply the new material
%--------------end assign new material

%--------------balance the model
d.balanceBondedModel0();%balance the periodic boundary model
d.breakGroup();%break all the connections
%let the balls move
dTrate=4;%increase the dT to increase the computing speed, 1~4
d.mo.dT=d.mo.dT*dTrate;
d.mo.setGPU('auto');

%set the periodic boundary directions
fs.addPeriodBoundary(d,directions);%add the boundary (wall elements)
d.balance('Standard',2/dTrate);
%--------------end balance the model

%--------------connect the elements, the following code is optional
isBonded=0;
if isBonded==1
    topFilterAll=d.mo.aZ(1:d.aNum-1)>B.sampleH/2;
    d.addGroup('topLayerAll',find(topFilterAll));%elements of all topLayer, including wall elements
    d.addGroup('botLayerAll',find(~topFilterAll));

    d.connectGroup('topLayerAll');d.connectGroup('botLayerAll');
    d.removePrestress(0.1);
    d.balance('Standard',0.5/dTrate);
    d.connectGroup('topLayerAll');d.connectGroup('botLayerAll');
    d.removePrestress(0.1);
    d.balance('Standard',2/dTrate);
end
d.setStandarddT();

fs.saveData(B,2);%as the data in the folder TempModel