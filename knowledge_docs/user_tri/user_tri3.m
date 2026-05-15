clear
load('TempModel/sanzhou2.mat');
%------------initialize model-------------------
%B.setUIoutput();
%d=B.d;
%d.calculateData();
%d.mo.setGPU('off');
%d.getModel();
%d.resetStatus();
%------------end initialize model-------------------

%-------------set new material----------------
%---膜---
matTxt1=load('Mats\rouxingmo.txt');
Mats{1,1}=material('rouxingmo',matTxt1,B.ballR);
Mats{1,1}.Id=1;
%---花岗岩---
load('Mats\Mat_Granite.mat');
Mats{2,1}=Mat_Granite;
Mats{2,1}.Id=2;
d.Mats{2,1}.kn=1.2e9
d.Mats{2,1}.ks=6e8
d.Mats{2,1}.xb=9.5e-7
d.Mats{2,1}.mup=1.5
d.Mats{2,1}.fs0=13.25
%---压力板---
load('Mats\Mat_yaliban.mat');
Mats{3,1}=Mat_yaliban;
Mats{3,1}.Id=3;
d.Mats{3,1}.kn=5e11
d.Mats{3,1}.ks=3e11
d.Mats{3,1}.xb=9.5e-6
d.Mats{3,1}.mup=2
d.Mats{3,1}.fs0=5e8
%---裂隙---
load('Mats\Mat_liexi1.mat');
Mats{4,1}=Mat_liexi1;
Mats{4,1}.Id=4;
d.Mats = Mats;

d.setGroupMat('tube','rouxingmo');  
d.setGroupMat('sample','Granite'); 
d.setGroupMat('topPlaten','yaliban'); 
d.setGroupMat('Crack1','liexi1'); 
d.setGroupMat('Crack2','liexi1'); 
d.Mats=Mats;

d.groupMat2Model({'sample','tube','Crack1','Crack2','topPlaten'}); 

crackId = [d.GROUP.Crack1; d.GROUP.Crack2];
d.mo.aBF(crackId) = d.mo.aBF(crackId) * 0.15;  % 强度降
d.mo.aKN(crackId) = d.mo.aKN(crackId) * 0.10;  % 法向刚度降
d.mo.aKS(crackId) = d.mo.aKS(crackId) * 0.20;  % 切向稍软
d.mo.zeroBalance();

d.balanceBondedModel0;
d.connectGroup('sample');
d.removePrestress(0.1);
d.balance('Standard',2);
d.connectGroup('sample');
d.removePrestress(0.1);
d.balance('Standard',2);

%-------------end set new material----------------

%--------------------save data-----------------------
d.mo.setGPU('off');
d.clearData(1);
d.recordCalHour('Step2Finish');
save(['TempModel/' B.name '3.mat'],'B','d');
save(['TempModel/' B.name '2R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
%--------------------end save data-----------------------
d.calculateData();