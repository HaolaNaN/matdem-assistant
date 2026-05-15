%set the material of the model
clear
load('TempModel/BoxNonlinear1.mat');
%load('TempModel/BoxAT3D1R0.1-0.25aNum115609.mat');
B.setUIoutput();
d=B.d;
d.calculateData();%calculate data after loading the .mat file
d.mo.setGPU('off');%close the GPU before handling the model
d.getModel();%get X,Y,Z,R.. from d.mo
d.resetStatus();

planeW=0.5-B.ballR;
planeL=0.5-B.ballR;

pX=d.mo.aX(d.GROUP.topPlaten);
pY=d.mo.aY(d.GROUP.topPlaten);
fX1=pX<B.sampleW/2-planeW/2;
fX2=pX>B.sampleW/2+planeW/2;
fY1=pY<B.sampleL/2-planeL/2;
fY2=pY>B.sampleL/2+planeL/2;
planeFilter=fX1|fX2|fY1|fY2;
delPId=d.GROUP.topPlaten(planeFilter);

d.delElement(delPId);
d.mo.frame.knRate=1;%1 for rigid boundary, default is 0.5 (elastic

d.mo.aZ(d.GROUP.topPlaten)=max(d.mo.aZ(d.GROUP.topPlaten));
%--------------set material, define strong and weak rock
matTxt=load('Mats\ATSoil3.txt');
Mats{1,1}=material('soil',matTxt,B.ballR);
Mats{1,1}.Id=1;
matTxt2=load('Mats\ATSoil3.txt');
Mats{2,1}=material('planeMat',matTxt2,B.ballR);
Mats{2,1}.Id=2;
d.Mats=Mats;%assign the material to the model
d.setGroupMat('topPlaten','planeMat');
d.groupMat2Model({'sample','topPlaten'},1);%apply the new material

%--------------set balanceCommand for power relationship
d.mo.SET.b=0;
e_rate=1;
powerRate=1;
isPower=1;

if isPower==1
    strain = [1e-3, 1e-2];
    %particleE=d.Mats{1}.E;%*d.Mats{1}.rate(1)
    mat=d.Mats{1};
    particleE=mat.kn/(pi*mat.d/2);
    stress = strain*particleE;
    e_rate=0.3;%0.1<rate<1, 0.3 for slurry

    stress(2)=stress(2)*e_rate;
    [a,b]=casefs.powerFit(strain,stress,1);
    d.mo.SET.a=a;
    d.mo.SET.b=b;
    
    d.SET.rate=e_rate;
    powerRate=(1/e_rate)^0.6;%adjust the balance time,0.6~1
    C='nStrainN=nIJXn./nIJRsum;';
    C=[C 'nStressN=sign(nStrainN).*obj.SET.a.*abs(nStrainN).^obj.SET.b;'];
    C=[C 'nFN0=nStressN.*(pi*nIR.*nJR);'];
    C=[C 'nFN0_plane=obj.nKNe.*nIJXn;'];
    C=[C 'maxId=max(obj.dem.GROUP.sample);'];
    C=[C 'planeFilter=obj.dem.mo.nBall>maxId;'];
    C=[C 'planeFilter(1:maxId,:)=false;'];
    C=[C 'nFN0=nFN0.*(~planeFilter)+nFN0_plane.*planeFilter;'];
    C=[C 'clear nStrainN nStressN minR nFN0_sample planeFilter;'];
    d.mo.FnCommand=C;
    d.mo.zeroBalance();
end
d.SET.rate=e_rate;
d.SET.powerRate=powerRate;
%--------------end set balanceCommand for power relationship

d.groupMat2Model({'sample','topPlaten'},1);%apply the new material
d.balanceBondedModel0(0.5);%setGPU Auto


dTrate=4;%increase the dT to increase the computing speed, 1~4
d.mo.dT=d.mo.dT*dTrate;
aMUp0=d.mo.aMUp;
d.mo.aMUp(:)=0;%when MUp is 0, the coupling between fiber and soil will be increased
d.breakGroup();%reduce horizontal force
d.mo.setGPU('auto');
d.balance('Standard',1/dTrate*powerRate);
d.mo.aMUp=aMUp0;
%put a thin plane
d.mo.mGZ(d.GROUP.topPlaten)=d.mo.mGZ(d.GROUP.topPlaten)*0.01/B.ballR;

d.mo.setGPU('auto');
d.connectGroup('sample');
d.removePrestress(0.1);
d.balance('Standard',1/dTrate*powerRate);
d.connectGroup('sample');
d.removePrestress(0.1);
d.balance('Standard',1/dTrate*powerRate);
d.mo.dT=d.mo.dT/dTrate;

d.mo.setGPU('off');
d.clearData(1);
d.recordCalHour('Box2Finish');
save(['TempModel/' B.name '2.mat'],'B','d');
save(['TempModel/' B.name '2R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();
d.show('ZDisplacement');