clear                                              
load('TempModel/sanzhou1.mat');
%------------initialize model-------------------
B.setUIoutput();
d=B.d;
d.calculateData();
d.mo.setGPU('off');
d.getModel();
d.resetStatus();
%------------end initialize model-------------------
sampleR=B.SET.sampleR;
sampleH=B.SET.sampleH;
ballR=B.ballR;
Rrate=0.7;
tubeR=sampleR+ballR;
tubeH=sampleH;    
tubeType='model'; 
topPlatenType='model'; 
botPlatenType='wall'; 
%------------------试样---------------------
tubeSampleId=d.getGroupId('sample');
sX=d.mo.aX(tubeSampleId);sY=d.mo.aY(tubeSampleId);sZ=d.mo.aZ(tubeSampleId);
dipD=0;dipA=0;radius=sampleR;height=sampleH;
columnFilter=f.run('fun/getColumnFilter.m',sX,sY,sZ,dipD,dipA,radius,height);
delId=tubeSampleId(~columnFilter);
delId=[delId;d.GROUP.topPlaten];
d.delElement(delId);

zmin=min(d.mo.aZ(d.GROUP.sample)-d.mo.aR(d.GROUP.sample));
d.moveGroup('sample',0,0,2.5*ballR-zmin);

%-----------------管和板-------------------
tubeObj=mfs.denseModel(Rrate,@mfs.makeTube,tubeR,tubeH+2*2*ballR*B.BexpandRate,0.75*ballR);
tubeObj=mfs.moveObj2Origin(tubeObj);
tubeObj=mfs.move(tubeObj,B.sampleW/2,B.sampleL/2,tubeH/2+2*ballR*B.BexpandRate);
tubeId=d.addElement(1,tubeObj,tubeType);
d.addGroup('tube',tubeId);  
d.setClump('tube');
tubeId=d.GROUP.tube;
topplatenObj=mfs.denseModel(Rrate,@mfs.makeDisc,sampleR+2*ballR*2,ballR);
topplatenObj=mfs.moveObj2Origin(topplatenObj);
topplatenObj=mfs.move(topplatenObj,B.sampleW/2,B.sampleL/2,tubeH+2*2*ballR);

topPlatenId=d.addElement(1,topplatenObj,topPlatenType);
d.addGroup('topPlaten',topPlatenId);
d.setClump('topPlaten');

%d.GROUP.topPlaten=d.addElement(1,topPlaten);

botplatenObj=mfs.denseModel(Rrate,@mfs.makeDisc,sampleR+2*ballR*2,ballR);
botplatenObj=mfs.moveObj2Origin(botplatenObj);
botplatenObj=mfs.move(botplatenObj,B.sampleW/2,B.sampleL/2,2*ballR);

botPlatenId=d.addElement(1,botplatenObj,botPlatenType);
d.addGroup('botPlaten',botPlatenId);
d.setClump('botPlaten');

%d.GROUP.botPlaten=d.addElement(1,botPlaten);

%-----------------------裂隙-------------------------------------
sId=d.GROUP.sample;
sX=d.mo.aX(sId);sY=d.mo.aY(sId);sZ=d.mo.aZ(sId);
dipA1=60;dipA2=90;length=0.015;width=0.003;height=1;fixedcx=0;fixedcy=0;fixedcz=0;
cuboidFilter = f.run('fun/getcuboidFilter.m', sX, sY, sZ , dipA1, dipA2, length, width, height, fixedcx, fixedcy, fixedcz);
d.addGroup('Crack1', sId(cuboidFilter)); 

dipA1=-60;dipA2=90;length=0.015;width=0.003;height=1;fixedcx=0;fixedcy=0;fixedcz=0;
cuboidFilter = f.run('fun/getcuboidFilter.m', sX, sY, sZ , dipA1, dipA2, length, width, height, fixedcx, fixedcy, fixedcz);
d.addGroup('Crack2', sId(cuboidFilter));


%-----------------------消除作用力-------------------------------------
d.addGroup('tubeBox',[d.GROUP.tube;d.GROUP.botPlaten;d.GROUP.topPlaten]);
d.minusGroup('sample','tubeBox',1.2);
d.removeGroupForce(d.GROUP.tube,d.GROUP.botPlaten);
d.removeGroupForce(d.GROUP.tube,d.GROUP.topPlaten);

d.mo.zeroBalance();
d.addFixId('XYZ','botPlaten');
d.addFixId('XY','topPlaten');
d.addFixId('Z','tube');

%d.balance('Standard',1);

d.setGroupId();
d.showFilter('SlideY',0.5,1,'groupId');
d.showFilter('SlideY',0.5,1);
d.show('groupId','StressZZ');

%------------return and save result--------------
d.status.dispEnergy();%display the energy of the model
d.clearData(1);%clear dependent data
d.recordCalHour('Step1Finish');
save(['TempModel/' B.name '2.mat'],'B','d');
save(['TempModel/' B.name '2R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();
%d.showFilter('SlideY',0.3,1,'StressXX');