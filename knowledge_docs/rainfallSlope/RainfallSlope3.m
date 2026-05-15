clear;
load('TempModel/RainfallSlope2.mat');
B.setUIoutput();
d=B.d;
d.calculateData();
d.mo.setGPU('off');
d.getModel();%d.setModel();%reset the initial status of the model
d.status=modelStatus(d);%initialize model status, which records running information

d.mo.isHeat=1;%calculate heat in the model
visRate=0.001;
d.mo.mVis=d.mo.mVis*visRate;
gpuStatus=d.mo.setGPU('auto');
d.setStandarddT();%reset the step time to default value

strengthRate=3;
d.mo.aBF=d.mo.aBF*strengthRate;
d.mo.aFS0=d.mo.aFS0*strengthRate;
d.mo.aMUp=d.mo.aMUp*strengthRate;

initialWC=0.04;
saturatedWC=0.4;
aK0=10;
aBF0=d.mo.aBF;
aFS00=d.mo.aFS0;
aMUp0=d.mo.aMUp;

d.mo.SET.aWC=ones(d.aNum,1)*initialWC;
d.mo.SET.aWC(d.mNum+1:d.aNum)=-1;%-1 indicates isulated boundary
d.mo.SET.mWater=d.mo.mM.*d.mo.SET.aWC(1:d.mNum);
%d.show('SETaWC');

d.mo.SET.aK=ones(d.aNum,1)*aK0;
%d.show('SETaK');

d.mo.dT=d.mo.dT*5;
d.figureNumber=1;
%return
totalCircle=30;
stepNum=1000;
d.tic(totalCircle*stepNum);
fName=['data/step/' B.name  num2str(B.ballR) '-' num2str(B.distriRate) 'loopNum'];
save([fName '0.mat']);%return;
fs.disp('Start calculation');
for i=1:totalCircle
    for j=1:stepNum
        d.toc();%show the note of time

        %-----1. determine the surface of the model
        mSurfaceFilter=getSurfaceFilter(B,1);

        %-----2. change water content of surface elements
        d.mo.SET.aWC(mSurfaceFilter)=0.4;
        d.mo.SET.mWater=d.mo.mM.*d.mo.SET.aWC(1:d.mNum);
        %d.show('SETaWC');
  
        %-----3. calculate the water content difference, nWaterDiff
        nRow=ones(1,size(d.mo.nBall,2));%a row whose width is the same as nBall  
        nWaterDiff=d.mo.SET.aWC(d.mo.nBall)-d.mo.SET.aWC(1:d.mNum)*nRow;%difference of water content bewteen elements and neighbors
        
        nWC=d.mo.SET.aWC(d.mo.nBall);%water content of neighboring elements
        %nWaterDiff(abs(nWC)>1)=0;%boundary is isulated, water content differences also are zero
        nWaterDiff(nWC==-1)=0;
        ndX=d.mo.aX(d.mo.nBall)-d.mo.aX(1:d.mNum)*nRow;
        ndZ=d.mo.aZ(d.mo.nBall)-d.mo.aZ(1:d.mNum)*nRow;
        nR=d.mo.aR(d.mo.nBall)+d.mo.aR(1:d.mNum)*nRow;
        nD=sqrt(ndX.^2+ndZ.^2);
        nNeighbourFilter=nD<2*nR;
        nWaterDiff(~nNeighbourFilter)=0;
        
        %-----4. water migation
        nK=min(d.mo.SET.aK(d.mo.nBall),d.mo.SET.aK(1:d.mNum)*nRow);
        nWaterFlow=nWaterDiff.*nK;%similar to darcy flow
        mWaterFlow=sum(nWaterFlow,2);%variation of water flow
        d.mo.SET.mWater=d.mo.SET.mWater+mWaterFlow;%new water mass of element
        d.mo.SET.aWC(1:d.mNum)=d.mo.SET.mWater./d.mo.mM;%calculate water content
        
        %-----5. update the shear strength of element according to water content
        rate1=1-(d.mo.SET.aWC./saturatedWC)*0.5;
        rate2=1-(d.mo.SET.aWC./saturatedWC)*0.7;
        d.mo.aBF=aBF0.*rate1;
        d.mo.aFS0=aFS00.*rate1;
        d.mo.aMUp=aMUp0.*rate2;

        d.balance();%calculation
        
        d.recordStatus();

    end
    
    d.show('SETaWC');
    d.clearData(1);
    save([fName num2str(i) '.mat']);
    d.calculateData();

end

fs.disp('Calculation finished');
d.showB=2;
d.show('SETaWC');%show the data in d.mo.SET.aWC
d.mo.setGPU('off');
d.clearData(1);
d.recordCalHour('RainSlope3Finish');
save(['TempModel/' B.name '3.mat'],'B','d');
save(['TempModel/' B.name '3R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();