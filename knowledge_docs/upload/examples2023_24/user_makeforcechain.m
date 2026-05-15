%%
%在matlab里运行，fun目录下
clc;
clear;
load('TempModel/jacked_pipe_piles.mat');
d.mo.setGPU('off');
xmax = max(d.mo.aX+B.ballR);
xmin = min(d.mo.aX-B.ballR);
ymax = max(d.mo.aZ+B.ballR);
ymin = min(d.mo.aZ-B.ballR);
d.show('aR');
%=========接触力信息处理===================
FX = (d.mo.nFnX+d.mo.nFsX);
FY = (d.mo.nFnY+d.mo.nFsY);
FZ = (d.mo.nFnZ+d.mo.nFsZ);
F = (FX.^2+FY.^2+FZ.^2).^0.5;
B = (F>0);
nBall2 = d.mo.nBall.*B;
[rB,cB]=size(nBall2);
num_contact = length(find(nBall2>0));
inf_contact = zeros(num_contact,5);
count = 0;
for i=1:rB
    for j=1:cB
        if i*nBall2(i,j)~=0
            count = count +1;
            inf_contact(count,:) = [i,nBall2(i,j),F(i,j),FX(i,j),FZ(i,j)];
        end
    end
end
[rc,cc]=size(inf_contact);
for i=(1:rc)
    t = inf_contact(i,1);
    if inf_contact(i,1)<inf_contact(i,2)
        t1 = inf_contact(i,1);
        t2 = inf_contact(i,2);
    else
        t1 = inf_contact(i,2);
        t2 = inf_contact(i,1);
    end
    inf_contact(i,1) = t1;
    inf_contact(i,2) = t2;
end
inf_contact2 = sortrows(inf_contact);
inf_contact3 = inf_contact2;
count = 0;
for i=1:rc-1
    if inf_contact2(i,1)==inf_contact2(i+1,1)&inf_contact2(i,2)==inf_contact2(i+1,2)
        inf_contact3(i-count,:)=[];
        count = count + 1;
    end
end
%=====================
%可在此处加一个筛选力链的条件
%=====================
num_ball = d.mo.aNum;
inf_ball = [[1:num_ball]',d.mo.aX,d.mo.aZ,d.mo.aR];
figure;
R_ave = mean(inf_ball(:,4));
%===================画圆==============================
%--------画活动单元----------------
face_color = [0.7451 0.7451 0.7451];
alpha = 1;
edge_color = 'none';
axis equal
% xlim auto
% zlim auto
xlim([xmin,xmax]);
ylim([ymin,ymax]);
hold on
x1=[];
y1=[];
tic;
parfor i=1:d.mo.mNum % parfor not supported in MatDEM  
    cx = inf_ball(i,2);
    cy = inf_ball(i,3);
    radius = inf_ball(i,4);
    t = 0:.1:2*pi;
    x = radius * cos(t) + cx;
    y = radius * sin(t) + cy;
    x1=[x1,x'];
    y1=[y1,y'];
end
patch(x1, y1, face_color, 'facealpha', alpha, 'edgecolor', edge_color);
%---------画墙单元-------------------
face_color = 'g';
alpha = 1;
edge_color = 'none';
x2=[];
y2=[];
parfor i=d.mo.mNum+1:d.mo.aNum-1 % parfor not supported in MatDEM 
    cx = inf_ball(i,2);
    cy = inf_ball(i,3);
    radius = inf_ball(i,4);
    t = 0:.1:2*pi;
    x = radius * cos(t) + cx;
    y = radius * sin(t) + cy;
    x2=[x2,x'];
    y2=[y2,y'];
end
patch(x2, y2, face_color, 'facealpha', alpha, 'edgecolor', edge_color);
%==================画矩形=================
inf_contact =  inf_contact3;
[r2,c2]=size(inf_contact);
force_max = max(inf_contact(:,3));
force_min = min(inf_contact(:,3));
face_color = 'k';%力链颜色
alpha = 1;%力链透明度
edge_color = 'none';%边线颜色
xs1 = [];
ys1 = [];
parfor i=1:r2
    pos = [inf_ball(round(inf_contact(i,1)),2),inf_ball(round(inf_contact(i,1)),3);%两接触球的球心坐标
        inf_ball(round(inf_contact(i,2)),2),inf_ball(round(inf_contact(i,2)),3)];
    disR = sqrt((pos(1,1)-pos(2,1))^2+(pos(1,2)-pos(2,2))^2);%球心距
    r = [inf_ball(round(inf_contact(i,1)),4),inf_ball(round(inf_contact(i,2)),4)];%两球半径
    R = [r(1)/(r(1)+r(2))*disR,r(2)/(r(1)+r(2))*disR];
    factor1 = inf_contact(i,3)/(force_max-force_min);%力链宽度因子
    factor2 = 5;
    Rmin = R_ave*factor1*factor2;%力链宽度
    %-----------力链为圆心连圆心-------------
        cx = (pos(1,1)+pos(2,1))*0.5;
        cy = (pos(1,2)+pos(2,2))*0.5;
        seta = atan((pos(1,1)-pos(2,1))/(pos(1,2)-pos(2,2)));%偏转角
    %---------------------------------------
    %-------------力链方向沿合力方向------------------
    % AB = pos(2,:)-pos(1,:);
    % C = pos(1,:)+AB.*(R(1)/disR);
    % cx = C(1);
    % cy = C(2);
    % seta = atan((inf_contact(i,4))/(inf_contact(i,5)));
    %-------------------------------------------------
    pos1 = zeros(4,2);
    if pos(1,2)>=pos(2,2)
        pos1(1,1) = -0.5*Rmin;
        pos1(1,2) = +(R(1)/disR)*disR;
        pos1(2,1) = +0.5*Rmin;
        pos1(2,2) = +(R(1)/disR)*disR;
        pos1(3,1) = +0.5*Rmin;
        pos1(3,2) = -(R(2)/disR)*disR;
        pos1(4,1) = -0.5*Rmin;
        pos1(4,2) = -(R(2)/disR)*disR;
        pos2 = pos1;
    elseif pos(1,2)<pos(2,2)
        pos1(1,1) = -0.5*Rmin;
        pos1(1,2) = -(R(1)/disR)*disR;
        pos1(2,1) = +0.5*Rmin;
        pos1(2,2) = -(R(1)/disR)*disR;
        pos1(3,1) = +0.5*Rmin;
        pos1(3,2) = +(R(2)/disR)*disR;
        pos1(4,1) = -0.5*Rmin;
        pos1(4,2) = +(R(2)/disR)*disR;
        pos2 = pos1;
    end
    %-----------旋转坐标-------------
    pos1(1,1) = pos2(1,1)*cos(seta)+pos2(1,2)*sin(seta)+cx;
    pos1(1,2) = pos2(1,2)*cos(seta)-pos2(1,1)*sin(seta)+cy;
    pos1(2,1) = pos2(2,1)*cos(seta)+pos2(2,2)*sin(seta)+cx;
    pos1(2,2) = pos2(2,2)*cos(seta)-pos2(2,1)*sin(seta)+cy;
    pos1(3,1) = pos2(3,1)*cos(seta)+pos2(3,2)*sin(seta)+cx;
    pos1(3,2) = pos2(3,2)*cos(seta)-pos2(3,1)*sin(seta)+cy;
    pos1(4,1) = pos2(4,1)*cos(seta)+pos2(4,2)*sin(seta)+cx;
    pos1(4,2) = pos2(4,2)*cos(seta)-pos2(4,1)*sin(seta)+cy;
    xs = [pos1(1,1), pos1(2,1), pos1(3,1), pos1(4,1)];
    ys = [pos1(1,2), pos1(2,2), pos1(3,2), pos1(4,2)];
    xs1=[xs1,xs'];
    ys1=[ys1,ys'];
end
patch(xs1, ys1, face_color, 'facealpha', alpha, 'edgecolor', edge_color);
toc