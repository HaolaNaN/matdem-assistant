clear all;
fs.randSeed(1);
ballR=20;
sampleW=2000;sampleL=0;sampleH=2200;
B=obj_Box;%declare a box object
B.name='GeoThermalBox';
B.ballR=ballR;%element radius
% B.sampleW=sampleW;%width, length, height
% B.sampleL=sampleL;%when L is zero, it is a 2-dimensional model
% B.sampleH=sampleH;
B.GPUstatus='off';
B.isSample=1;%
B.distriRate=0.2;
frame=[0,0,0,sampleW,sampleL,sampleH];%first three value must be zero
B.setFrame(frame);
B.setType('botPlaten');%add a top platen to compact model
B.buildInitialModel();
B.setUIoutput();
B.gravitySediment(2);%you may use B.gravitySediment(10); to increase sedimentation time (10)
B.compactSample(2);%input is compaction time

d=B.d;
d.mo.setGPU('off');
%cut the model
mo=d.mo;
d.delElement(find(mo.aZ>2000));
confine1 = mo.aX < 800 ;confine2 = mo.aX > 1200;
combined_confine1 = confine1 | confine2;
confine3 = mo.aZ < 1000;
confine4 = mo.aZ < -1.25*mo.aX + 1000;
confine5 = mo.aZ < 1.25*mo.aX -1500;
combine_confine2 = confine4 | confine5;
combined_confine = combined_confine1 & confine3 & combine_confine2;
d.delElement(find(combined_confine));

%set the confine
lefLine=mfs.makeLine('X',2000,10);
topLine=mfs.move(lefLine,0,0,2000);
vertical1=mfs.rotate(lefLine,'XZ',90);
vertical1=mfs.move(vertical1,0,0,1000);
vertical2=mfs.move(vertical1,2000,0,0);
Hline=mfs.move(lefLine,200,0,0);
tan_value = 5/4;angle_rad = atan(tan_value);angle_deg = rad2deg(angle_rad);
lefLine=mfs.rotate(lefLine,'XZ',-angle_deg);
lefLine=mfs.move(lefLine,-20,0,sqrt(800^2+1000^2));
rigLine=mfs.rotate(lefLine,'XZ',-180+angle_deg*2);
rigLine=mfs.move(rigLine,1220,0,1000);
%verticalLine=mfs.combineObj(vertical1,vertical2);
confineObj=mfs.combineObj(lefLine,rigLine,Hline);
confineObj=mfs.move(confineObj,-220,0,0);
confineObj=mfs.combineObj(confineObj,topLine);
confineObj=mfs.combineObj(confineObj,vertical1);
confineObj=mfs.combineObj(confineObj,vertical2);
confinedId=d.addElement(1,confineObj);
d.addGroup('confine',confinedId,1);
d.defineWallElement('confine');
d.addFixId('XYZ',d.GROUP.confine);
d.moveBoundary('left',-1000,0,0);d.moveBoundary('right',1000,0,0);d.moveBoundary('bottom',0,0,-300);
d.balance('Standard',2);
d.show('aR');
%------------return and save result--------------
d.status.dispEnergy();%display the energy of the model
d.mo.bFilter(:)=1;
d.mo.zeroBalance();
d.Rrate=1;
d.mo.setGPU('off');
d.clearData(1);%clear dependent data
d.recordCalHour('Step1Finish');
save(['TempModel/' B.name '1.mat'],'B','d');
save(['TempModel/' B.name '1R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();
