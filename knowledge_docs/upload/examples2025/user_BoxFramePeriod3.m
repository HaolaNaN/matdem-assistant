clear;
[B,d]=fs.loadData('FramePeriod2.mat');%load data
d.getModel();%d.setModel();%reset the initial status of the model
d.resetStatus();%initialize model status, which records running information
d.setStandarddT();

%---------set the loading
d.mo.mVis=d.mo.mVis*0.01;%reduce viscosity, 0.001~1 see the book
d.mo.aMUp(:)=0.1;%reduce the coefficient of friction
d.mo.setShear('on');
topFilterModel=d.mo.aZ(1:d.mNum)>B.sampleH/2;
d.mo.mGX(topFilterModel)=d.mo.mGZ(topFilterModel)*50;%apply great body force along X
d.mo.mGX(~topFilterModel)=-d.mo.mGZ(~topFilterModel)*50;
if sum(d.mo.periodB.directions=='Y')%set the Y loading
    d.mo.mGY(topFilterModel)=d.mo.mGZ(topFilterModel)*50;
end
%---------end set the loading

%---------numerical simulation
totalCircle=30;
showType='SlippingHeat';%show the result
gpuStatus=d.mo.setGPU('on');
fName=['data/step/' B.name num2str(B.ballR) '-' num2str(B.distriRate) 'loopNum'];
save([fName '0.mat']);
d.tic(totalCircle);

for i=1:totalCircle
    d.mo.setGPU(gpuStatus);
    d.balance('Standard',0.08);%0.02
    d.recordStatus();
    d.showB=1;%1 show model elements, 2 also show the periodic elements
    d.Rrate=1;%show the balls with smaller raidus
    d.figureNumber=d.show(showType);
    d.clearData(1);
    save([fName num2str(i) '.mat']);
    d.calculateData();
    d.toc();
end
%---------end numerical simulation
d.show();

fs.saveData(B,3);%as the data in the folder TempModel