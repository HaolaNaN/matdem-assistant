%组装试样
clear;
load('TempModel/fks-1.mat');
B.d.mo.setGPU('off');
packBallR=B.ballR;%record the ballR of the small box block
packBoxObj1=B.d.group2Obj('gdfks');%将废矿石转化为结构体
packBoxObj2=B.d.group2Obj('fks');%将废矿石转化为结构体

load('TempModel/ks-1.mat');
B.d.mo.setGPU('off');
packBoxObj3=B.d.group2Obj('layer1');%将矿石转化为结构体
packBoxObj4=B.d.group2Obj('layer2');%将矿石转化为结构体
packBoxObj5=B.d.group2Obj('layer3');%将矿石转化为结构体
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
B.name='npscm_fksandks';
B.GPUstatus='auto';
B.ballR=0.65;
B.isClump=0;
B.isSample=0;
B.distriRate=0.5;
B.sampleW=Wjljj;
B.sampleL=Lbkbj+Lfshd;
B.sampleH=20+Hx+Hfdgd;
B.BexpandRate=0;
B.PexpandRate=0;
B.platenStatus=[0,0,0,0,0,1];
B.boundaryStatus=[0,0,0,0,0,0];%only topPlaten will be set
B.buildInitialModel();
B.setUIoutput();
d=B.d;

%set the frame for showing the results
frame.minX=0;
frame.minY=0;
frame.minZ=0;
frame.maxX=B.sampleW;
frame.maxY=B.sampleL;
frame.maxZ=B.sampleH+4*B.ballR;
d.mo.frame=frame;
d.setFrame(frame);
d.mo.isFrame=1;
d.mo.frame.knRate=1;%1 for rigid boundary, default is 0.5 (elastic)

%导入三个结构体
boxObjId1=d.addElement(1,packBoxObj1);
d.addGroup('gdfks',boxObjId1);%导入废矿石
boxObjId2=d.addElement(1,packBoxObj2);
d.addGroup('fks',boxObjId2);%导入废矿石

boxObjId3=d.addElement(1,packBoxObj3);
d.addGroup('hdks',boxObjId3);%导入矿石
boxObjId4=d.addElement(1,packBoxObj4);
d.addGroup('gdks',boxObjId4);%导入矿石
boxObjId5=d.addElement(1,packBoxObj5);
d.addGroup('ks',boxObjId5);%导入矿石

d.delElement('topPlaten');%remove bottom platen
d.setStandarddT();
d.mo.setGPU('auto'); 
for i=1:200
    for j=1:10
        d.balance();
    end
    d.mo.mVX(1:d.mNum,1)=d.mo.mVX(1:d.mNum,1).*0;
    d.mo.mVY(1:d.mNum,1)=d.mo.mVY(1:d.mNum,1).*0;
    d.mo.mVZ(1:d.mNum,1)=d.mo.mVZ(1:d.mNum,1).*0;
    d.mo.mAX(1:d.mNum,1)=d.mo.mAX(1:d.mNum,1).*0;
    d.mo.mAY(1:d.mNum,1)=d.mo.mAY(1:d.mNum,1).*0;
    d.mo.mAZ(1:d.mNum,1)=d.mo.mAZ(1:d.mNum,1).*0;
end
d.balance('Standard',1);

d.data.groupId(d.GROUP.fks) = 8;
d.GROUP.groupId(d.GROUP.fks) = 8;
d.data.groupId(d.GROUP.ks) = 2;
d.GROUP.groupId(d.GROUP.ks) = 2;
figure;
d.show('groupId');
d.mo.setGPU('off');
save(['TempModel/' 'fksks-1.mat']);