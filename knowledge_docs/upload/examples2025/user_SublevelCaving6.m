%开始放矿
clear;
load('TempModel/fksks-1.mat');
B.setUIoutput();
d.mo.setGPU('off');
d.mo.frame.minZ=-Hfdgd;%空出放出颗粒存放的空间
Hhd = min(d.mo.aZ(d.GROUP.ks));%用于数据监测
Lhd = max(d.mo.aY(d.GROUP.hdks));

d.delElement(d.GROUP.hdks);%腾出放矿口

d.addFixId('XYZ',d.GROUP.gdfks);
d.addFixId('XYZ',d.GROUP.gdks);

d.mo.mGZ(d.GROUP.ks)=d.mo.mGZ(d.GROUP.ks)*4;%放大重力，使下坠加快，提升计算效率
d.mo.mGZ(d.GROUP.fks)=d.mo.mGZ(d.GROUP.fks)*2;
d.mo.aMUp(d.GROUP.gdks)=0.0;%不考虑摩擦力
d.mo.aMUp(d.GROUP.gdfks)=0.0;%不考虑摩擦力
figure;
d.show('groupId');
zhilbi0 = 2;
recordksM = zeros(200000,1);
recordfksM = zeros(200000,1);
d.setStandarddT();
d.mo.dT = 1e-3;
numks0 = length(d.GROUP.ks);
d.getModel(); 
d.mo.setGPU('auto'); 
for i = 1:20
    for j=1:1000
        d.balance();
        ballid_fks = find(d.mo.aZ(d.GROUP.fks)>0&d.mo.aZ(d.GROUP.fks)<Hhd&d.mo.aY(d.GROUP.fks)<Lhd);
        numfks = length(ballid_fks);
        ballid_ks = find(d.mo.aZ(d.GROUP.ks)>0&d.mo.aZ(d.GROUP.ks)<Hhd);
        numks = length(ballid_ks);
        if numks/numfks<zhilbi0
            break;
        end
        recordksM((i-1)*1000+j) = numks;
        recordfksM((i-1)*1000+j) = numfks;
    end
    figureNumber=d.show('ZDisplacement','groupId');
    d.figureNumber=figureNumber;
    if numks/numfks<zhilbi0
        break;
    end
end
d.mo.setGPU('off'); 
save('TempModel/fksks_2.mat'); 