%% 基本尺寸
clear
unitFactor = 1e-3;      % mm to m
D = 120*unitFactor;     % 内径，mm
h = 1.5*D/2;              % 高度
e = 5*unitFactor;2.2*unitFactor;     % 最小间隙，mm

ballR=e/2;Rrate=0.8;    % 公共参数
%桨叶1
paddleW=D/2-2*e;paddleH=0.8*h-e;
leftPaddle=mfs.makeRect(paddleW,paddleH,ballR*Rrate);
leftPaddle.Z=leftPaddle.Y;
leftPaddle.Y(:)=0;leftPaddle.R(:)=ballR;
leftPaddle=mfs.moveObj2Origin(leftPaddle);

w0=9*unitFactor;
paddleFilter=abs(leftPaddle.X)>(paddleW/2-w0) | abs(leftPaddle.Z)>(paddleH/2-w0);
leftPaddle=mfs.filterObj(leftPaddle,paddleFilter);
leftPaddle=mfs.align2Value('bottom',leftPaddle,e);

paddle0=mfs.denseModel(Rrate,@mfs.makeColumn,w0/2,h,ballR);
paddle0=mfs.moveObj2Origin(paddle0);
paddle0=mfs.align2Value('bottom',paddle0,e+w0);
leftPaddle=mfs.combineObj(leftPaddle,paddle0);
leftPaddle.groupId=leftPaddle.X*0+1;

leftPaddle=mfs.move(leftPaddle,-D/4,0,0);
%桨叶2
rightPaddle=mfs.move(leftPaddle,D/4,0,0);
rightPaddle=mfs.rotate(rightPaddle,'XY',90);
rightPaddle=mfs.move(rightPaddle,D/4,0,0);
rightPaddle.groupId=rightPaddle.X*0+2;
%搅拌桶侧面
tube=mfs.denseModel(Rrate,@mfs.makeTube,D/2+ballR,h,ballR);
tube=mfs.moveObj2Origin(tube);
tube=mfs.align2Value('bottom',tube,0);
tube.groupId=tube.X*0+3;
%搅拌桶底座
disc=mfs.denseModel(Rrate,@mfs.makeDisc,D/2+ballR*2,ballR);
disc=mfs.moveObj2Origin(disc);
disc=mfs.align2Value('top',disc,0);
disc.groupId=disc.X*0+4;

bObj=mfs.combineObj(leftPaddle,rightPaddle,tube,disc);
bObj.groupId=bObj.groupId+10;
% bfs.show(bObj);

%记录模型与参数，保存
SET.name='Blender';
SET.ballR=ballR;
SET.sampleD=D;
SET.sampleH=h;
SET.bObj=bObj;
SET.groupId=struct('leftPaddle',11,'rightPaddle',12,'tube',13,'disc',14);

save(['TempModel/' SET.name '0.mat'],'SET','bObj');