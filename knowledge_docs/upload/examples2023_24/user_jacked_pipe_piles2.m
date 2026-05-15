%%
%+++++++++++++++++++第2步：压桩++++++++++++++++++++ 
clear;
clc;
load('TempModel/jacked_pipe_piles33.mat');
% load('TempModel/jacked_pipe_piles_2.mat');
B.setUIoutput();
%*****************2.1：生成桩******************* 
%桩几何参数
z_max = max(d.mo.aZ(1:d.mNum,1)); 
R_max = max(d.mo.aR(1:d.mNum,1));
h_pilebot = z_max+R_max;%获得桩端标高
pile_L = 1;%桩长
pile_D = 0.06;%桩外径
pile_t = 0.015;%壁厚
pile_d = (pile_D-pile_t*2);%桩内径
B_ballr = B_ballr*0.3;

top_id=d.GROUP.topB;
d.delElement(top_id);

%生成左外壁
left_pile=mfs.denseModel(0.5,@mfs.makeBox,0,0,pile_L,B_ballr);                         
left_pile_Id1=d.addElement(1,left_pile,'wall');                                      
d.addGroup('left_pile1',left_pile_Id1);                                               
d.moveGroup('left_pile1',0.5*W-0.5*pile_D,-B_ballr,h_pilebot); 
%生成左内壁
left_pile=mfs.denseModel(0.5,@mfs.makeBox,0,0,pile_L,B_ballr);                         
left_pile_Id2=d.addElement(1,left_pile,'wall');                                      
d.addGroup('left_pile2',left_pile_Id2);                                               
d.moveGroup('left_pile2',0.5*W-0.5*pile_D+pile_t-2*B_ballr,-B_ballr,h_pilebot); 
%生成右外壁
right_pile=mfs.denseModel(0.5,@mfs.makeBox,0,0,pile_L,B_ballr);                        
right_pile_Id1=d.addElement(1,right_pile,'wall');                                    
d.addGroup('right_pile1',right_pile_Id1);                                             
d.moveGroup('right_pile1',0.5*W+0.5*pile_d,-B_ballr,h_pilebot);
%生成右内壁
right_pile=mfs.denseModel(0.5,@mfs.makeBox,0,0,pile_L,B_ballr);                        
right_pile_Id2=d.addElement(1,right_pile,'wall');                                    
d.addGroup('right_pile2',right_pile_Id2);                                             
d.moveGroup('right_pile2',0.5*W+0.5*pile_d+pile_t-2*B_ballr,-B_ballr,h_pilebot);
%生成左桩端
right_pile=mfs.denseModel(0.5,@mfs.makeBox,pile_t,0,0,B_ballr);                        
right_pile_Id3=d.addElement(1,right_pile,'wall');                                    
d.addGroup('right_pile3',right_pile_Id3);                                             
d.moveGroup('right_pile3',0.5*W+0.5*pile_d,-B_ballr,h_pilebot);
%生成右桩端
left_pile=mfs.denseModel(0.5,@mfs.makeBox,pile_t,0,0,B_ballr);                         
left_pile_Id3=d.addElement(1,left_pile,'wall');                                      
d.addGroup('left_pile3',left_pile_Id3);                                               
d.moveGroup('left_pile3',0.5*W-0.5*pile_D,-B_ballr,h_pilebot);

s1 = d.getGroupId('left_pile1');
s2 = d.getGroupId('left_pile2');
s3 = d.getGroupId('right_pile1');
s4 = d.getGroupId('right_pile2');
s5 = d.getGroupId('right_pile3');
s6 = d.getGroupId('left_pile3');
d.addGroup('pile',[s1;s2;s3;s4;s5;s6]);
%设置颗粒接触微观参数
d.mo.isHeat=1;                                                                                                
visRate=0.9;                                                                                                  
d.mo.mVisX=d.mo.mVisX*visRate;                                                                                
d.mo.mVisY=d.mo.mVisY*visRate;                                                                                
d.mo.mVisZ=d.mo.mVisZ*visRate;                                                                                
d.mo.aKN(1:d.mNum,1)=3e7;                                                                                    
d.mo.aKS(1:d.mNum,1)=3e7;                                                                                    
d.mo.aKN(d.mNum+1:d.aNum-1,1)=6e7;                                                                           
d.mo.aKS(d.mNum+1:d.aNum-1,1)=6e7;
d.mo.aKN([s1;s2;s3;s4;s5;s6])=3e8;%设置桩的接触微观参数                                                                           
d.mo.aKS([s1;s2;s3;s4;s5;s6])=3e8;
d.mo.aMUp(1:d.mNum,1)=0.0;                                                                                   
d.mo.aFS0(1:d.aNum-1,1)=0.0;                                                                                   
d.mo.aBF(1:d.aNum-1,1)=0;                                                                                      
d.mo.aMUp(d.mNum+1:d.aNum-1,1)=0;    
d.mo.mM(1:d.mNum,1)=pi.*d.mo.aR(1:d.mNum,1).^2.*2000;      
d.mo.mGZ = 0;                                                                  
d.mo.setKNKS(); 
d.mo.aMUp(1:d.mNum,1)=0.5;
d.mo.mGZ=-pi.*d.mo.aR(1:d.mNum,1).^2.*9.81.*2000;

d.mo.aMUp([s1;s2;s3;s4;s5;s6])=0.5;%设置桩的摩擦系数 

% d.setStandarddT();
d.mo.dT=3e-5;       
d.getModel();
d.resetStatus();
d.show('StressZZ');
d.mo.setGPU('auto');

summove = 10;%总的位移量
wall_v = -1;%设置桩的下沉速度
sumtime = summove/abs(wall_v);%模拟总时间
totalcircle = round(sumtime/d.mo.dT);
step = 10;%分步保存
stepnum = round(totalcircle/step);
wall_m = wall_v*d.mo.dT;%计算桩每个移动的下沉量
ffss = wall_m*(3e7*3e8*1.0/(3e7+3e8));%计算桩每一次移动的切向力
d.mo.setRotate('on');
for j=1:5
    for i=1:4000      
        xx = d.mo.nBall;
        xx(xx>s1(1)|xx<s4(end)) = 0;
        xx(xx<=s1(1)&xx>=s4(end)) = 1;
        xx = xx.*d.mo.cFilter;%得到当前和桩内外壁产生接触的颗粒
        fff = ffss*xx;
        d.mo.nFsZ = d.mo.nFsZ+fff;%补充桩每一次移动未计算的切向力
        d.moveGroup('pile',0,0,wall_m);
        d.balance();
    end
    figureNumber=d.show('XDisplacement','mV');
    d.figureNumber=figureNumber;
    % d.mo.setGPU('off');
    % save(['data/step/' 'op-' num2str(j) '.mat']);
end

save('TempModel/soil_doneys_3.mat');