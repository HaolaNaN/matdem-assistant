
%set the material of the model
clear
fs.randSeed(2);
load('TempModel/PoreAdsorption2.mat');

%---------------regular setting
B.setUIoutput();
d=B.d;
d.calculateData();
d.mo.setGPU('on');
d.getModel();%get xyz from d.mo
d.showB=2;
d.deleteConnection('boundary');
d.Rrate=1;
d.getModel();
d.mo.isCrack=1;
%---------------end regular setting

%---------------set different layers of the box model
interface=[0.0714;0.7964];%interface between layers
maxZ=max(d.mo.aZ);
botLayerFilter=d.mo.aZ<maxZ*interface(1);
midLayerFilter=d.mo.aZ>=maxZ*interface(1)&d.mo.aZ<=maxZ*interface(2);
topLayerFilter=d.mo.aZ>maxZ*interface(2);
d.addGroup('botLayer',find(botLayerFilter));%define the bottom layer of the model
d.addGroup('midLayer',find(midLayerFilter));
d.addGroup('topLayer',find(topLayerFilter));
d.mo.zeroBalance();
d.setGroupId();%distinguish different groups
d.show('groupId');%show groupId
%---------------end set different layers of the box model

%-------------initializing the pore network
p=pore(d);%make pore object
p.dT=p.d.mo.dT;%use the same step time, may be modified later
p.pathLimitRate=0.3;%path diameter<pathLimitRate*ballR will be connection
p.isCouple=0;%no fluid-solid coupling
p.isInterphase=1;%Start adsorption simulation
p.setInitialPores();
p.setPlaten('fix');%fix the coordinates of platens
%-------------end initializing the pore network

%-----------set the fluid flow parameters (permeability)
p.aWaterdR=d.mo.aR*0.1;%%water radius deviation of model elements
p.aWaterdR(d.GROUP.midLayer)=p.aWaterdR(d.GROUP.midLayer)/5;
%elements of midLayer use lower value, i.e. lower permeability
p.setWaterdR();%calculate the p.addDiameter based on aWaterdR
%d.mo.SET.aWaterdR=p.aWaterdR;
%d.show('SETaWaterdR');%show the water radius of element
%return
%-----------end set the fluid flow parameters (permeability)

%---------calculate connection diameter and flow K
kFlow=0.00000001;%permeability factor
kCd=10;
%---------end calcualte connection diameter and flow K

%---------find four corners of the box model
sX=d.mo.aX(d.GROUP.sample);sZ=d.mo.aZ(d.GROUP.sample);
[~,lefBotId]=min(sX+sZ);
[~,rigBotId]=min(-sX+sZ);
[~,lefTopId]=min(sX-sZ);
[~,rigTopId]=min(-sX-sZ);
pressureHigh=p.pPressure(1)*10000;%use great pressure to increase the speed
pressureLow=p.pPressure(1)*1;
%---------end find four corners of the box model

%---------------add temperature "solute"
CdPara.Id=1;
CdPara.name='Cd';
CdPara.initialValue=0;%initial temperature
CdPara.KL=1 ;
CdPara.Qm=15;
CdPara.K1=0.02;
p.addSolutePara(CdPara);
%---------------end add temperature "solute"

aM=d.mo.mNum;
d.mo.SET.pC=zeros(aM,1);
d.mo.SET.KL=CdPara.KL*ones(aM,1);
d.mo.SET.Qm=CdPara.Qm*ones(aM,1);
d.mo.SET.K1=CdPara.K1*ones(aM,1);

dNum=1000;%save the figure every dNum steps


for step=1:10000
    %----------heat conduct
    p.SET.cKCd=p.cLength*kCd;
    p.setBallPara('Cd',lefBotId,30);%3 degrees
    p.setBallPara('Cd',lefTopId,30);%30 degrees
    %------------fluid flow
    cDiameterFlow=p.cDiameter+p.cDiameterAdd;%calculate the diameter of
    cDiameterFlow(cDiameterFlow<0)=0;
    p.cKFlow=cDiameterFlow*kFlow./p.cPathLength;%default K of throat is determined by diameter and path length
    p.setBallPressure(lefBotId,pressureHigh);%set the pore pressure around the ball
    p.setBallPressure(lefTopId,pressureHigh);
    p.setBallPressure(rigBotId,pressureLow);
    %------------end fluid flow
    p.balance();%calculation

    if mod(step, dNum) == 0
        d.show('SETpC');
        title(['颗粒吸附量Step ' num2str(step)]);
        set(gca, 'ColorScale', 'log');
        fprintf('Step %d\n', step);
    end
end


    d.mo.zeroBalance();
    d.mo.setGPU('off');
    d.clearData(1);
    d.recordCalHour('Step3Finish');
    save(['TempModel/' B.name '3.mat'],'B','d');
    save(['TempModel/' B.name '3R' num2str(B.ballR) '-distri' num2str(B.distriRate) 'aNum' num2str(d.aNum) '.mat']);
    d.calculateData();