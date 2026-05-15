%%
%+++++++++++++++++++第1步：分层制样++++++++++++++++++++  
clear;
clc;
%*****************1.1：随机生成分层颗粒信息*******************
layer1=f.run('fun/layeredball.m','slope/class.csv',1.9,4);%生成分层颗粒结构体
r_min = min(layer1.R);
r_max = max(layer1.R);
B_ballr=0.5*(r_min+r_max);%墙单元半径
layerHight = 4;%每一层的高度
W = 12;
L = 0;
H = 20;
num_layer = H/layerHight;%分层数
num_ball_total = size(layer1.R,1)/num_layer;%每一层的颗粒数量
%建立模型箱
B=obj_Box;
B.name='jacked_pipe_piles';
B.setUIoutput();

B.GPUstatus='off';
B.ballR=B_ballr;
B.isShear=1;
B.isClump=0;
B.distriRate=0.3;
B.sampleW=W;
B.sampleL=L;
B.sampleH=H-2*B.ballR;%去除上加载板的厚度
B.BexpandRate=4;
B.PexpandRate=4;
B.type='topPlaten';
B.isSample=0;

B.setType();
B.buildInitialModel();
d=B.d;
d.g=0;
d.showB=2;  

layer1Id=d.addElement(1,layer1);%导入颗粒
d.addGroup('layer1',layer1Id);

d.delElement('topPlaten');
% d.show('StressZZ');
%生成层间隔墙
for i =1:num_layer
    wall1=mfs.denseModel(0.3,@mfs.makeBox,(W),0,0,B_ballr);
    wall_Id=d.addElement(1,wall1,'wall');
    d.addGroup(['wall_' num2str(i*2-1)],wall_Id);
    d.moveGroup(['wall_' num2str(i*2-1)],0,-B_ballr,layerHight*i-2*B_ballr);
    
    wall1=mfs.denseModel(0.3,@mfs.makeBox,(W),0,0,B_ballr);
    wall_Id=d.addElement(1,wall1,'wall');
    d.addGroup(['wall_' num2str(i*2)],wall_Id);
    d.moveGroup(['wall_' num2str(i*2)],0,-B_ballr,layerHight*i);  
    figureNumber=d.show('StressZZ');
    d.figureNumber=figureNumber;
end
%消除墙的作用力
ball_id1 = d.getGroupId(['wall_' num2str(1)]);
ball_id2 = [(1+num_ball_total*(1-1)):(num_ball_total*1)]';
d.removeGroupForce(ball_id1,ball_id2);

count = 2;
for i = 2:num_layer
    ball_id1 = [d.getGroupId(['wall_' num2str(count)]);d.getGroupId(['wall_' num2str(count+1)])];
    ball_id2 = [(1+num_ball_total*(i-1)):(num_ball_total*i)]';
    d.removeGroupForce(ball_id1,ball_id2);
    count = count + 2;
end
%设置颗粒接触微观参数
d.getModel();    
d.mo.isHeat=1;                                                                                                
visRate=0.9;%认为压桩是一个准静态过程                                                                                                  
d.mo.mVisX=d.mo.mVisX*visRate;                                                                                
d.mo.mVisY=d.mo.mVisY*visRate;                                                                                
d.mo.mVisZ=d.mo.mVisZ*visRate;                                                                                
d.mo.aKN(1:d.mNum,1)=3e7;                                                                                    
d.mo.aKS(1:d.mNum,1)=3e7;                                                                                    
d.mo.aKN(d.mNum+1:d.aNum-1,1)=6e7;                                                                           
d.mo.aKS(d.mNum+1:d.aNum-1,1)=6e7;                                                                           
d.mo.aMUp(1:d.mNum,1)=0.0;%不考虑摩擦力                                                                                   
d.mo.aFS0(1:d.aNum-1,1)=0.0;                                                                                   
d.mo.aBF(1:d.aNum-1,1)=0;%砂土                                                                                      
d.mo.aMUp(d.mNum+1:d.aNum-1,1)=0;    
d.mo.mM(1:d.mNum,1)=pi.*d.mo.aR(1:d.mNum,1).^2.*2000;      
d.mo.mGZ = 0;%不考虑重力                                                                  
d.mo.setKNKS() ; 

%********************1.2：无重力摩擦下第一次平衡********************
% d.setStandarddT();
d.mo.dT=1e-5;
d.mo.setGPU('auto'); 
for i=1:40
    for j=1:50
        d.balance();
    end
    d.mo.mVX(1:d.mNum,1)=d.mo.mVX(1:d.mNum,1).*0;
    d.mo.mVY(1:d.mNum,1)=d.mo.mVY(1:d.mNum,1).*0;
    d.mo.mVZ(1:d.mNum,1)=d.mo.mVZ(1:d.mNum,1).*0;
    d.mo.mAX(1:d.mNum,1)=d.mo.mAX(1:d.mNum,1).*0;
    d.mo.mAY(1:d.mNum,1)=d.mo.mAY(1:d.mNum,1).*0;
    d.mo.mAZ(1:d.mNum,1)=d.mo.mAZ(1:d.mNum,1).*0;

end
figureNumber=d.show('StressZZ','mV');
d.figureNumber=figureNumber;
d.mo.dT=1e-5;
d.mo.setGPU('auto'); 
for i=1:10
    for j=1:3000
        d.balance();
    end
    figureNumber=d.show('StressZZ','mV');
    d.figureNumber=figureNumber;
end 
d.mo.setGPU('off');  
save(['TempModel/' B.name '_1.mat'])
%*********************************************************************
%********************1.3：删除隔墙后进行第二次平衡********************
clc;
clear;
load('TempModel/jacked_pipe_piles_1.mat');
B.setUIoutput();
%删除隔墙
for i =1:num_layer
    ball_id1 = [d.getGroupId(['wall_' num2str(2*(i-1)+1)]);d.getGroupId(['wall_' num2str(2*i)])];
    d.delElement(ball_id1);
    figureNumber=d.show('StressZZ');
    d.figureNumber=figureNumber;
end
%将左右墙加高
lef_id=d.GROUP.lefB;
d.delElement(lef_id);
rig_id=d.GROUP.rigB;
d.delElement(rig_id);

wall_left_1=mfs.denseModel(0.3,@mfs.makeBox,0,0,1.2*H,B_ballr);
wall_left_1_Id=d.addElement(1,wall_left_1,'wall');
d.addGroup('wall_left_1',wall_left_1_Id);
d.moveGroup('wall_left_1',-2*B_ballr,-B_ballr,-2*B_ballr);

wall_right_1=mfs.denseModel(0.3,@mfs.makeBox,0,0,1.2*H,B_ballr);
wall_right_1_Id=d.addElement(1,wall_right_1,'wall');
d.addGroup('wall_right_1',wall_right_1_Id);
d.moveGroup('wall_right_1',W,-B_ballr,-2*B_ballr);

%设置颗粒接触微观参数
d.getModel();    
d.mo.isHeat=1;                                                                                                
visRate=0.9;%认为压桩是一个准静态过程                                                                                                  
d.mo.mVisX=d.mo.mVisX*visRate;                                                                                
d.mo.mVisY=d.mo.mVisY*visRate;                                                                                
d.mo.mVisZ=d.mo.mVisZ*visRate;                                                                                
d.mo.aKN(1:d.mNum,1)=3e7;                                                                                    
d.mo.aKS(1:d.mNum,1)=3e7;                                                                                    
d.mo.aKN(d.mNum+1:d.aNum-1,1)=6e7;                                                                           
d.mo.aKS(d.mNum+1:d.aNum-1,1)=6e7;                                                                           
d.mo.aMUp(1:d.mNum,1)=0.0;%不考虑摩擦力                                                                                   
d.mo.aFS0(1:d.aNum-1,1)=0.0;                                                                                   
d.mo.aBF(1:d.aNum-1,1)=0;%砂土                                                                                      
d.mo.aMUp(d.mNum+1:d.aNum-1,1)=0;    
d.mo.mM(1:d.mNum,1)=pi.*d.mo.aR(1:d.mNum,1).^2.*2000;      
d.mo.mGZ = 0;%不考虑重力                                                                  
d.mo.setKNKS(); 

% d.setStandarddT();
d.mo.dT=3e-5;
d.mo.setGPU('auto'); 
for i=1:15
    for j=1:3000
        d.balance();
        d.recordStatus;
    end
    figureNumber=d.show('StressZZ','mV');
    d.figureNumber=figureNumber;
end 
d.mo.setGPU('off');  
save(['TempModel/' B.name '_2.mat']);
%*********************************************************************
%********************1.4：删除隔墙后进行第二次平衡********************
clc;
clear;
load('TempModel/jacked_pipe_piles_2.mat');
B.setUIoutput();
d.mo.aMUp(1:d.mNum,1)=0.5;%加上摩擦
d.mo.mGZ=-pi.*d.mo.aR(1:d.mNum,1).^2.*9.81.*2000;%加上重力
d.mo.dT=3e-5;
% d.setStandarddT();
d.SET.wucha = 0;
d.mo.setGPU('auto'); 
for k = 1:1000
    force_1=d.getGroupForce('botB');
    wall1_force0=force_1.totalFZ;
    d.balance('Standard',4);
    force_1=d.getGroupForce('botB');
    wall1_force=force_1.totalFZ;
    figureNumber=d.show('StressZZ','mV');
    d.figureNumber=figureNumber;
    d.SET.wucha=( wall1_force-wall1_force0)/(wall1_force0);
    if abs(d.SET.wucha)<1e-3
          break;
    end
end 
d.mo.setGPU('off');  
save(['TempModel/' B.name '.mat']);
