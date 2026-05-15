clear;
load('TempModel\SandProduction0.mat');
boxType='wall';

coet=B.SET.coet;
para= [3,-sqrt(3)/2,6,1]*coet;
x0=para(1);y0=para(2);r1=para(3);r2=para(4);
d.SET.x0= x0;d.SET.y0= y0;d.SET.r1= r1;d.SET.r2= r2;
aX=d.mo.aX(1:d.mo.mNum);aY=d.mo.aY(1:d.mo.mNum);aZ=d.mo.aZ(1:d.mo.mNum);aR=d.mo.aR(1:d.mo.mNum);
maxX= aX+aR;maxY=aY+aR;minX= aX-aR;minY=aY-aR;
% 2x+y-5=0左下侧\\2x-y-7=0右下侧
filter1= (maxX-x0).^2+(maxY-y0).^2>=r1^2 | (maxX-x0).^2+(maxY-y0).^2<=r2^2;
filter2= (minX-x0).^2+(minY-y0).^2>=r1^2 | (minX-x0).^2+(minY-y0).^2<=r2^2;
filter3= sqrt(3)*(aX-x0)+aY-y0<=0 | sqrt(3)*(aX-x0)-aY+y0>=0;
filter4= abs(sqrt(3)*(aX-x0)+aY-y0)/2<aR | abs(sqrt(3)*(aX-x0)-aY+y0)/2<aR;
filter5= aZ>max(aZ,[],1)*0.9;
DelIndex= find(filter1|filter2|filter3|filter4|filter5);
colIndex= setdiff((1:d.mo.mNum)',DelIndex);

d.addGroup('col',colIndex);
sampleObj= d.group2Obj('col');

wallH= max(d.mo.aZ(1:d.mo.mNum))*0.95;
wallR= 3e-3;
wallObj= f.run('fun/makeWallObj.m',d.SET,wallR,wallH);
%------------------------end make boudary of box-----------------
fs.randSeed(1);%random model seed, 1,2,3...
B=obj_Box;%declare a box object
B.name='SandProduction';
B.ballR= 1e-3;
B.isShear=0;
B.isClump=0;
B.distriRate=0.2;
B.sampleW=2*x0*1.2;
B.sampleL=2*x0*1.3;
B.sampleH=wallH*1.2;
B.BexpandRate=2;%boundary is 4-ball wider than 
B.PexpandRate=0;
B.type='botPlaten';
B.isSample=0;
B.setType();
B.SET.boxType=boxType;
B.SET.coet= coet;
B.buildInitialModel();
d=B.d;

wallId= d.addElement(1,wallObj);
d.addGroup('wall0',wallId,boxType);%add a new group
d.setClump('wall0');
d.moveGroup('wall0',B.ballR+wallR,B.ballR+6*wallR,B.ballR+wallR);
maxWallZ= max(d.mo.aZ(d.GROUP.wall0));
boxSampleId=d.addElement(1,sampleObj);
d.addGroup('sample',boxSampleId);%add a new group
d.moveGroup('sample',B.ballR+wallR,B.ballR+6*wallR,B.ballR+wallR);
d.delElement('botPlaten');
d.minusGroup('sample','wall0',0.9);
d.GROUP.wallTop= find(d.mo.aZ(d.GROUP.wall0)== maxWallZ);
d.mo.zeroBalance();
d.addFixId('X',d.GROUP.wall0);
d.addFixId('Y',d.GROUP.wall0);
d.addFixId('Z',d.GROUP.wall0);

B.gravitySediment(0.5);

filter = gather(d.mo.aR(1:d.mNum)>1e-3);
CoarseId= find(filter==1);
FineId= find(filter==0);
d.addGroup('Coarse',CoarseId);
d.addGroup('Fine',FineId);
d.SET.wallR= wallR;

%------------return and save result--------------
d.mo.setGPU('off');
d.clearData(1);%clear dependent data
d.recordCalHour('Step1Finish');
save(['TempModel/' B.name '1.mat'],'B','d');
d.calculateData();%because data is clear, it will be re-calculated
% deId= d.mo.aZ<0.04 | d.mo.aX<0.05;
% d.showFilter('BallId',deId,'aR');