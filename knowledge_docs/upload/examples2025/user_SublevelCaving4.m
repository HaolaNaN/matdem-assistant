%切割矿石样本
clear
load('TempModel/npscm_ks-2.mat');
%-----------初始化参数
Whd = 3.3;%进路宽
Hhd = 3.6;%进路高
Lbkbj = 3;%崩矿步距
Lfshd = 6;%废石厚度
Hfdgd = 14;%分段高度
Wjljj = 16;%进路间距
Hx = (Wjljj-Whd)*0.5*tan(50/360*2*pi);%斜段高度

%-----------生成切割层面数据
line1 = [0 0 0;Wjljj,0,0;Wjljj,0,0;Wjljj,0,0;Wjljj,0,0;Wjljj,0,0;Wjljj,0,0];
line2 = [0 0 0;0.5*Wjljj-0.5*Whd,0,0;0.5*Wjljj-0.5*Whd+Whd*0.00001,0,Hhd;0.5*Wjljj+0.5*Whd,0,Hhd;0.5*Wjljj+0.5*Whd+Whd*0.00001,0,0;Wjljj,0,0;Wjljj,0,0];
line3 = [0 0 Hx+Hhd;0.5*Wjljj-0.5*Whd,0,Hhd;0.5*Wjljj+0.5*Whd,0,Hhd;Wjljj,0,Hx+Hhd;Wjljj,0,Hx+Hhd;Wjljj,0,Hx+Hhd;Wjljj,0,Hx+Hhd];
line4 = [0 0 Hfdgd;0.5*Whd 0 Hfdgd;0.5*Whd*1.00001 0 Hfdgd+Hhd;0.5*Wjljj 0 Hfdgd+Hhd+Hx;Wjljj-0.5*Whd 0 Hfdgd+Hhd;Wjljj-0.5*Whd+Whd*0.00001 0 Hfdgd;Wjljj 0 Hfdgd];

B.setUIoutput();%set output of message
d=B.d;
d.calculateData();
d.mo.setGPU('off');
d.getModel();
d.delElement(d.GROUP.topPlaten);

%---------切割出矿体
C=Tool_Cut(d);%cut the model
lSurf=[line1,line2,line3,line4];%load the surface data
C.addSurf(lSurf);%add the surfaces to the cut
C.setLayer({'sample'},[1,2,3,4]);%set layers according geometrical data

ballid0 = [d.GROUP.layer1;d.GROUP.layer3];
ballid = find(d.mo.aY(ballid0)>=Lbkbj);
d.delElement(ballid0(ballid));%删除岩石部分位置

d.makeModelByGroups({'layer1','layer2','layer3'});
d.mo.setGPU('off');
save(['TempModel/' 'ks-1.mat']);
figure;
d.show('aR');