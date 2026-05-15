%% step1
clear;
fs.randSeed(1);%change number to get different random model
%---------------------define parameters----------------------
ballR=0.02;
frameValue=4;
frame.minX=0;
frame.minY=0;
frame.minZ=0;
frame.maxX=frameValue*1.5;
frame.maxY=0;
frame.maxZ=frameValue;
%---------------------end define parameters-------------  ---------
%----------make a Box, and pack balls---------
B=obj_Box('SeedDevice');%declare a box object
B.ballR=ballR;%element radius
B.setFrame(frame);
B.setType('topPlaten');
B.buildInitialModel();
B.gravitySediment();
d=B.d;
mo=d.mo;
soil=(0 < d.mo.aX & d.mo.aX < frame.maxX) & ( 0 < d.mo.aZ & d.mo.aZ < 1);
d.addGroup('soil',find(soil),1);
d.GROUP.sample = setdiff(d.GROUP.sample,d.GROUP.soil);
centerX = 1; centerZ = 1.5;innerRadius = 0.35;outerRadius = 0.4;
index = sqrt((d.mo.aX - centerX).^2 + (d.mo.aZ - centerZ).^2);
seedRegion = (index >= innerRadius) & (index <= outerRadius);
d.delElement(find(~soil & ~seedRegion));
selectedIndex = randperm(length(d.GROUP.sample), 20);
d.GROUP.sample = d.GROUP.sample(selectedIndex);
keepFilter = false(size(d.mo.aX));
keepFilter(d.GROUP.soil) = true;%true
keepFilter(d.GROUP.sample) = true;
d.delElement(find(~keepFilter));
d.mo.aR(d.GROUP.sample)=d.mo.aR(d.GROUP.sample)*0.5;
d.GROUP.groupId(d.GROUP.sample)=30;
d.show('groupId');
fs.saveData(B,1);
%% step2
% geometric parameters
clear;
[B,d]=fs.loadData('SeedDevice1.mat');
seedX=1;seedZ=1.5;
d.delElement('topPlaten');
%ring
ringR=0.5;ringH=0.1;ballR=0.1;holeNum=4;holeAngle=15;
W1=holeAngle*pi*ringR/180; L=ringH;H=0.2;W2=W1/3;outL=0.01;
ring=makeRingWithHoles(ringR,ringH,ballR/20,holeNum,holeAngle);
ring=mfs.rotate(ring,'YZ',-90);
ring=mfs.move(ring,seedX,0,seedZ);
%ring2
ring2=makeRingWithHoles(ringR*0.6,ringH,ballR/20,0,0);
ring2=mfs.rotate(ring2,'YZ',-90);
ring2=mfs.move(ring2,seedX,0,seedZ);
ringObj=trifs.combineTriObj(ring,ring2);
%disc
discR=ringR;
discObj1=mfs.makeDisc(discR,ballR);
discObj1=mfs.rotate(discObj1,'YZ',-90);
discObj1=mfs.move(discObj1,seedX,-ringH*0.5,seedZ);
discObj1.DT=delaunay(discObj1.X,discObj1.Z);
discObj2=mfs.move(discObj1,0,ringH,0);
%seed
seed=makeHollowInvertedHopper(W1,L,H/2,W2,outL,ballR);
seed=mfs.move(seed,ringR+ringH,0,0);
seedAll=mfs.rotateCopy(seed,360/holeNum,holeNum,'XZ');
seedAll=mfs.move(seedAll,seedX,0,seedZ);
%scoop
scoop=makeHollowInvertedHopper(W1*2,L,H*1.5,W2*2,outL*20,ballR);
scoop=mfs.move(scoop,ringR+ringH*2+ballR,0,0);
scoop=mfs.rotate(scoop,'XZ',holeAngle*1.5);
scoopAll=mfs.rotateCopy(scoop,180/holeNum,holeNum*2,'XZ');
scoopAll=mfs.move(scoopAll,seedX,0,seedZ);
%hold all;fs.showObj(ringObj);fs.showObj(discObj1);fs.showObj(discObj2);fs.showObj(scoopAll);fs.showObj(seedAll);pbaspect([1,1,1]);return
discObj=trifs.combineTriObj(discObj1,discObj2);
deviceObj=trifs.combineTriObj(seedAll,ringObj);
deviceObj=trifs.combineTriObj(deviceObj,discObj);
deviceObj=trifs.combineTriObj(scoopAll,deviceObj);
deviceObj=mfs.addObjCenter(deviceObj);
device=triangle();
device.addGroup('device',device.addTriangle(deviceObj));
device.setMaterial(mean(d.mo.aKN(1:end-1)));
d.addNewTriangle(device);
d.minusGroup('soil','sample',6);
d.addFixId('Y',d.GROUP.soil);

d.Mats=[];
d.addMaterial('Soil1','Mats\Soil1.txt',B.ballR);
d.groupMat2Model({'soil'},1);
d.addMaterial('Fiber1','Mats\Fiber1.txt',B.ballR);
d.groupMat2Model({'sample','soil'},1);

d.mo.mVZ(d.GROUP.sample)=-40;

% d.balanceBondedModel();
d.balance('Standard',2);
d.show('groupId');
d.showTri(0.5);
fs.saveData(B,2);
%% step3
clear;
[B,d]=fs.loadData('SeedDevice2.mat');
d.resetStatus();
d.setStandarddT();
d.mo.dT=d.mo.dT*4;%increase the step time
d.mo.mVis(d.GROUP.soil)=d.mo.mVis(d.GROUP.soil)*0.05;
d.mo.setShear('on');
d.addFixId('Y',d.GROUP.soil);
totalT=5;
mAll=Tool_Motion(d.tri{1},'device');
mAll.Ts=[0,1]*totalT;%second
mAll.Xs=[0,0.5]*totalT;%displacement 0.5m per sec
mAll.RXZs=[0,-15]*totalT;%degree - is clockwise 15deg per sec

totalCircle=40;
B.SET.totalCircle=totalCircle;
time=d.balance('Time');
StandardBalanceRate=totalT/time/totalCircle;
gpuStatus=d.mo.setGPU('auto');

d.tic(totalCircle);
fName=['data/step/' d.name num2str(B.ballR) 'loopNum'];
save([fName '0.mat']);
for i=1:totalCircle
    d.mo.setGPU(gpuStatus);
    d.balance('Standard',StandardBalanceRate);
    d.showB=1;
    % Xs=[Xs;mean(d.tri{1,1}.aPointX)];
    % Zs=[Zs;mean(d.tri{1,1}.aPointZ)];
    % plot(Xs,Zs);daspect([1,1,1]);title(num2str(i));drawnow;pause(0.1)
    d.figureNumber=d.show('groupId');
    %plot3([0,B.sampleW],[0,0],[2.1,2.1],'--b');
    d.showTri(0.6);
    set(d.figureNumber,WindowState='maximized');
    set(findobj(d.figureNumber,Type='patch'),FaceColor=[1,1,1],FaceLighting='none',EdgeColor='g');
    frames(i)=getframe();
    d.mo.setGPU('off');
    save([fName num2str(i) '.mat']);
    d.toc();
end
fs.movie2gif([B.name,'_','groupId','_',regexprep(char(datetime),'[^\w+]','_'),'.gif'],frames,0.2)
%---------end numerical simulation
fs.saveData(B,3);
%%
function ringWithHoles = makeRingWithHoles(R, H, ballR, numHoles, holeAngle)
% R: 圆环外半径, H: 圆环高度, ballR: 三角面片密度控制参数
% numHoles: 开孔数量, holeAngle: 单个开孔角度(度, 如30°)

% 步骤1: 生成完整圆环主体
fullRing = makeFullTubeTri(R, H, ballR);
theta = atan2(fullRing.Y, fullRing.X);  % 计算所有顶点的极角(弧度)
theta(theta < 0) = theta(theta < 0) + 2*pi;  % 统一转换为[0, 2π)

% 步骤2: 定义开孔角度范围并裁剪三角面
holeAngleRad = deg2rad(holeAngle);
sectorAngle = 2*pi / numHoles;  % 开孔间隔角度
keepFaces = true(size(fullRing.DT, 1), 1);  % 标记需保留的三角面

for i = 1:numHoles
    % 开孔中心角(弧度)
    theta0 = (i-1)*sectorAngle;
    % 开孔角度范围 [thetaMin, thetaMax]
    thetaMin = theta0 - holeAngleRad/2;
    thetaMax = theta0 + holeAngleRad/2;
    if thetaMin < 0, thetaMin = thetaMin + 2*pi; end
    if thetaMax > 2*pi, thetaMax = thetaMax - 2*pi; end

    % 判断三角面是否位于开孔区域内
    for f = 1:size(fullRing.DT, 1)
        faceVerts = fullRing.DT(f, :);  % 当前三角面的3个顶点索引
        faceTheta = theta(faceVerts);   % 顶点极角

        % 若三角面所有顶点均在开孔范围内，则剔除
        if thetaMax > thetaMin  % 开孔不跨0°
            inHole = all(faceTheta >= thetaMin & faceTheta <= thetaMax);
        else  % 开孔跨0°(如thetaMin=350°, thetaMax=10°)
            inHole = all(faceTheta >= thetaMin | faceTheta <= thetaMax);
        end
        if inHole, keepFaces(f) = false; end
    end
end

% 步骤3: 保留非开孔区域的三角面
ringWithHoles.X = fullRing.X;
ringWithHoles.Y = fullRing.Y;
ringWithHoles.Z = fullRing.Z;
ringWithHoles.DT = fullRing.DT(keepFaces, :);
ringWithHoles.R = ballR;
end

% 辅助函数: 生成360°闭合圆环的三角面
function t = makeFullTubeTri(R, H, ballR)
nTheta = ceil(2*pi*R / (ballR*2));  % 周向点数(确保闭合)
nZ = ceil(H / (ballR*2));           % 轴向点数
theta = linspace(0, 2*pi, nTheta+1); theta(end) = [];  % 避免0°/360°重复
z = linspace(-H/2, H/2, nZ+1);

% 生成网格坐标
[Theta, Z] = meshgrid(theta, z);
X = R * cos(Theta);
Y = R * sin(Theta);
Z = Z;

% 转换为三角面
fvc = surf2patch(X, Y, Z, 'triangles');
t = struct('X', X(:), 'Y', Y(:), 'Z', Z(:), 'DT', fvc.faces,'R',ballR);
end

function t = makeHollowInvertedHopper(W, L, H, W2, extLen, ballR)
% 生成带右斜边延伸的空心倒四棱台
% 特点：无顶面和底面，只包含四个梯形侧面

% 验证输入参数
if W2 >= W
    error('下底宽W2必须小于上底宽W');
end

% 步骤1：生成空心主体（只包含侧面）
hollowHopper = makeHollowHopperTri(W, L, H, W2, ballR);

% 步骤2：计算延伸段顶点
dx = W2/2 - W/2; dz = 0 - H;
len = sqrt(dx^2 + dz^2);
unitVec = [dx, dz]/len;
extX = W2/2 + unitVec(1)*extLen;
extZ = 0 + unitVec(2)*extLen;

% 添加延伸段顶点
nOrig = length(hollowHopper.X);
X_ext = [hollowHopper.X; extX; extX];
Y_ext = [hollowHopper.Y; -L/2; L/2];
Z_ext = [hollowHopper.Z; extZ; extZ];

% 步骤3：查找下底右顶点索引
tol = 1e-10;
idx_right_front = find(abs(hollowHopper.X - W2/2) < tol & abs(hollowHopper.Y - (-L/2)) < tol & abs(hollowHopper.Z - 0) < tol, 1);
idx_right_back = find(abs(hollowHopper.X - W2/2) < tol & abs(hollowHopper.Y - L/2) < tol & abs(hollowHopper.Z - 0) < tol, 1);

if isempty(idx_right_front) || isempty(idx_right_back)
    % 如果找不到精确匹配，查找最接近的顶点
    [~, idx_right_front] = min((hollowHopper.X - W2/2).^2 + (hollowHopper.Y - (-L/2)).^2 + (hollowHopper.Z - 0).^2);
    [~, idx_right_back] = min((hollowHopper.X - W2/2).^2 + (hollowHopper.Y - L/2).^2 + (hollowHopper.Z - 0).^2);
end

idx_ext_front = nOrig + 1;
idx_ext_back = nOrig + 2;

% 步骤4：生成延伸段三角面
faces_ext = [idx_right_front, idx_ext_front, idx_ext_back;
    idx_right_front, idx_ext_back, idx_right_back];

% 步骤5：合并所有三角面
DT_combined = [hollowHopper.DT; faces_ext];

% 步骤6：逆时针旋转90度（绕Y轴）
[X_rot, Y_rot, Z_rot] = rotatePoints(X_ext, Y_ext, Z_ext, [0, 1, 0], -pi/2);  % 负号表示逆时针

% 输出结构
t = struct('X', X_rot, 'Y', Y_rot, 'Z', Z_rot, 'DT', DT_combined, 'R', ballR);
end
% 辅助函数：生成空心倒四棱台的三角面（只包含侧面）
function t = makeHollowHopperTri(W, L, H, W2, ballR)
% 计算网格密度
nSeg = max(ceil((W - W2) / ballR) + 2, 3);
nHeight = max(ceil(H / ballR) + 1, 3);

% 只生成四个侧面，不生成上下底面
[side_verts, side_faces] = generateHollowSideFaces(W, L, H, W2, nSeg, nHeight);

t = struct('X', side_verts(:,1), 'Y', side_verts(:,2), 'Z', side_verts(:,3), 'DT', side_faces);
end
% 辅助函数：生成四个空心侧面
function [vertices, faces] = generateHollowSideFaces(W, L, H, W2, nSeg, nHeight)
vertices = [];
faces = [];

% 前后面（Y = ±L/2）
u_side = linspace(0, 1, nSeg);
w_side = linspace(0, 1, nHeight);
[U_side, W_side] = meshgrid(u_side, w_side);

% 前面（Y = -L/2）
X_front = (-0.5 + U_side) .* (W + (W2 - W) * W_side);
Y_front = ones(size(X_front)) * (-L/2);
Z_front = H * (1 - W_side);

fvc_front = surf2patch(X_front, Y_front, Z_front, 'triangles');

% 后面（Y = L/2）
X_back = (-0.5 + U_side) .* (W + (W2 - W) * W_side);
Y_back = ones(size(X_back)) * (L/2);
Z_back = H * (1 - W_side);

fvc_back = surf2patch(X_back, Y_back, Z_back, 'triangles');
fvc_back.faces = fvc_back.faces + size(fvc_front.vertices, 1);

% 左右面（梯形侧面）
v_side = linspace(0, 1, nSeg);
[V_side, W_side] = meshgrid(v_side, w_side);

% 左面（X = -W/2 到 -W2/2）
Y_left = (-0.5 + V_side) * L;
X_left_top = ones(size(Y_left)) * (-W/2);
X_left_bottom = ones(size(Y_left)) * (-W2/2);
X_left = X_left_top + (X_left_bottom - X_left_top) .* W_side;
Z_left = H * (1 - W_side);

fvc_left = surf2patch(X_left, Y_left, Z_left, 'triangles');
fvc_left.faces = fvc_left.faces + size(fvc_front.vertices, 1) + size(fvc_back.vertices, 1);

% 右面（X = W/2 到 W2/2）
Y_right = (-0.5 + V_side) * L;
X_right_top = ones(size(Y_right)) * (W/2);
X_right_bottom = ones(size(Y_right)) * (W2/2);
X_right = X_right_top + (X_right_bottom - X_right_top) .* W_side;
Z_right = H * (1 - W_side);

fvc_right = surf2patch(X_right, Y_right, Z_right, 'triangles');
fvc_right.faces = fvc_right.faces + size(fvc_front.vertices, 1) + size(fvc_back.vertices, 1) + size(fvc_left.vertices, 1);

% 合并所有侧面（形成空心结构）
vertices = [fvc_front.vertices; fvc_back.vertices; fvc_left.vertices; fvc_right.vertices];
faces = [fvc_front.faces; fvc_back.faces; fvc_left.faces; fvc_right.faces];
end
% 辅助函数：坐标旋转（逆时针）
function [X_rot, Y_rot, Z_rot] = rotatePoints(X, Y, Z, axis, angle)
% 绕指定轴逆时针旋转点集
axis = axis / norm(axis);
u = axis(1); v = axis(2); w = axis(3);

cosA = cos(angle);
sinA = sin(angle);
oneMinusCosA = 1 - cosA;

R = [u^2*oneMinusCosA+cosA, u*v*oneMinusCosA-w*sinA, u*w*oneMinusCosA+v*sinA;
    u*v*oneMinusCosA+w*sinA, v^2*oneMinusCosA+cosA, v*w*oneMinusCosA-u*sinA;
    u*w*oneMinusCosA-v*sinA, v*w*oneMinusCosA+u*sinA, w^2*oneMinusCosA+cosA];

points = [X, Y, Z];
points_rot = points * R';

X_rot = points_rot(:,1);
Y_rot = points_rot(:,2);
Z_rot = points_rot(:,3);
end
