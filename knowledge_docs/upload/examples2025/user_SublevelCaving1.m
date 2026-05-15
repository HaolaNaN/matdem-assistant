%堆积岩石试样
clear;
%-----------初始化参数
Whd = 3.3;%进路宽
Hhd = 3.6;%进路高
Lbkbj = 3;%崩矿步距
Lfshd = 6;%废石厚度
Hfdgd = 14;%分段高度
Wjljj = 16;%进路间距
Hx = (Wjljj-Whd)*0.5*tan(50/360*2*pi);%斜段高度

fs.randSeed(10);
B=obj_Box;%build a box object
B.name='npscm_fks';
B.GPUstatus='auto';
B.ballR=0.75;
B.isClump=0;
B.distriRate=0.5;
B.sampleW=Wjljj;
B.sampleL=Lbkbj+Lfshd;
B.sampleH=20+Hx+Hfdgd;
B.BexpandRate=0;
B.PexpandRate=0;
B.platenStatus=[0,0,0,0,0,1];
B.boundaryStatus=[0,0,0,0,0,0];%only topPlaten will be set
B.buildInitialModel();B.show();
B.setUIoutput();
d=B.d;

%set the frame for showing the results
frame.minX=0;
frame.minY=0;
frame.minZ=0;
frame.maxX=B.sampleW;
frame.maxY=B.sampleL;
frame.maxZ=B.sampleH*1.5;
d.mo.frame=frame;
d.setFrame(frame);
d.mo.isFrame=1;
d.mo.frame.knRate=1;%1 for rigid boundary, default is 0.5 (elastic)

d.mo.setGPU('auto');
B.gravitySediment();
d.status.dispEnergy();%消散模型的能量

d.clearData(1);%清除独立性数据
d.recordCalHour('Box1Finish');
save(['TempModel/' B.name '-1.mat'],'B','d');
save(['TempModel/' B.name num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
d.calculateData();
d.showB=2;
d.show('StressZZ');