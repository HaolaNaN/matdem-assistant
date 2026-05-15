%% TailingsDAM_3DGeoModel_fenceng.m
% 三维地质分层建模 - 参照教材第8章

clear

%% ======== 路径与参数 ========
ascFile = 'data\m11.asc';
duijiFile = 'data\duiji.asc';
saveDir = 'TempModel\';
nodata = -9999;
baseZ = 0;
ballR = 6;
distriRate = 0.3;
botPackNum = 2;
topPackNum = 1.5;
surfPackNum = 1;
surfPackNum2 = 1;
topLayerThick = 30;
duijiThick = 20;
% 降采样步长：减小传入Tool_Cut的曲面矩阵尺寸，防止addSurf内部失败
dsStep = 3;

if ~exist(saveDir, 'dir')
    mkdir(saveDir)
end

%% ======== 辅助函数：构造只含X/Y/Z的精简曲面（无NaN，降采样）========
% MatDEM Tool_Cut.addSurf 只需要 X/Y/Z 三个字段
% 用精简结构体避免多余字段触发内部错误

%% ======== Step0-A：读取主DEM ========
fprintf('=== Step0-A: 读取主DEM ===\n')

fid = fopen(ascFile, 'r');
xll_main = 0;
yll_main = 0;
cs_main = 5;
for k = 1:6
    line = strtrim(fgetl(fid));
    tok = regexp(line, '\s+', 'split');
    if numel(tok) >= 2
        keyRaw = lower(regexprep(tok{1}, '[^a-zA-Z]', ''));
        val = str2double(tok{2});
        if ~isnan(val)
            if strcmp(keyRaw, 'xllcorner') || strcmp(keyRaw, 'xllcenter')
                xll_main = val;
            elseif strcmp(keyRaw, 'yllcorner') || strcmp(keyRaw, 'yllcenter')
                yll_main = val;
            elseif strcmp(keyRaw, 'cellsize')
                cs_main = val;
            end
        end
    end
end
fclose(fid);
fprintf('  xll=%.2f  yll=%.2f  cellsize=%.2f\n', xll_main, yll_main, cs_main)

Z_main = dlmread(ascFile, '', 6, 0);
Z_main = flipud(Z_main);
Z_main(Z_main == nodata) = NaN;
Z_main = Z_main - baseZ;
[nr_main, nc_main] = size(Z_main);
fprintf('  实际数据: %d 行 x %d 列\n', nr_main, nc_main)
x_main = xll_main + (0:nc_main-1) * cs_main;
y_main = yll_main + (0:nr_main-1) * cs_main;
[gX_geo, gY_geo] = meshgrid(x_main, y_main);
minX_geo = min(gX_geo(:));
minY_geo = min(gY_geo(:));
gX0 = gX_geo - minX_geo;
gY0 = gY_geo - minY_geo;
gZ0 = Z_main;
validMask0 = ~isnan(gZ0);
fprintf('  有效点: %d / %d\n', sum(validMask0(:)), numel(validMask0))

% PCA旋转
validX0 = gX0(validMask0);
validY0 = gY0(validMask0);
cx = mean(validX0);
cy = mean(validY0);
dx0 = validX0 - cx;
dy0 = validY0 - cy;
covMat = [sum(dx0.*dx0), sum(dx0.*dy0); sum(dx0.*dy0), sum(dy0.*dy0)];
[eigVec, ~] = eig(covMat);
mainVec = eigVec(:, 2);
rotAngle = atan2d(mainVec(1), mainVec(2));
fprintf('  PCA旋转角度: %.1f 度\n', rotAngle)
[gX_rot, gY_rot] = mfs.rotateIJ(gX0(:), gY0(:), rotAngle);
gX_rot = reshape(gX_rot, size(gX0));
gY_rot = reshape(gY_rot, size(gY0));
minXr = min(gX_rot(validMask0));
minYr = min(gY_rot(validMask0));
gX_rot = gX_rot - minXr;
gY_rot = gY_rot - minYr;

% 插值到规则网格（全分辨率，用于显示和S结构体）
validXr = gX_rot(validMask0);
validYr = gY_rot(validMask0);
validZr = gZ0(validMask0);
[gX, gY] = meshgrid(0:cs_main:max(validXr), 0:cs_main:max(validYr));
F_main = scatteredInterpolant(validXr, validYr, validZr, 'natural', 'nearest');
gZ_raw = F_main(gX, gY);
k_hull = convhull(validXr, validYr);
inHull = inpolygon(gX, gY, validXr(k_hull), validYr(k_hull));
gZ_raw(~inHull) = NaN;
validMask = ~isnan(gZ_raw);
% 全填充版（无NaN，供曲面构造使用）
gZ_fill = gZ_raw;
gZ_fill(~validMask) = F_main(gX(~validMask), gY(~validMask));
vz = gZ_raw(validMask);
demZmin = min(vz);
demZmax = max(vz);
fprintf('  Z范围: %.0f ~ %.0f m\n', demZmin, demZmax)

% 图1
gZ_disp = gZ_raw;
gZ_disp(~validMask) = NaN;
figure(1)
clf
surface(gX, gY, gZ_disp, gZ_disp)
shading interp
axis equal
colorbar
xlabel('X [m]')
ylabel('Y [m]')
zlabel('Z [m]')
title('主DEM地形')
fs.general3Dset()

%% ======== Step0-B：读取堆积体DEM ========
fprintf('=== Step0-B: 读取堆积体DEM ===\n')
fid = fopen(duijiFile, 'r');
xll_dj = 0;
yll_dj = 0;
cs_dj = 5;
for k = 1:6
    line = strtrim(fgetl(fid));
    tok = regexp(line, '\s+', 'split');
    if numel(tok) >= 2
        keyRaw = lower(regexprep(tok{1}, '[^a-zA-Z]', ''));
        val = str2double(tok{2});
        if ~isnan(val)
            if strcmp(keyRaw, 'xllcorner') || strcmp(keyRaw, 'xllcenter')
                xll_dj = val;
            elseif strcmp(keyRaw, 'yllcorner') || strcmp(keyRaw, 'yllcenter')
                yll_dj = val;
            elseif strcmp(keyRaw, 'cellsize')
                cs_dj = val;
            end
        end
    end
end
fclose(fid);
Z_dj = dlmread(duijiFile, '', 6, 0);
Z_dj = flipud(Z_dj);
Z_dj(Z_dj == nodata) = NaN;
Z_dj = Z_dj - baseZ;
[nr_dj, nc_dj] = size(Z_dj);
x_dj = xll_dj + (0:nc_dj-1) * cs_dj;
y_dj = yll_dj + (0:nr_dj-1) * cs_dj;
[gX_dj_geo, gY_dj_geo] = meshgrid(x_dj, y_dj);
gX_dj0 = gX_dj_geo - minX_geo;
gY_dj0 = gY_dj_geo - minY_geo;
[gX_dj_rot, gY_dj_rot] = mfs.rotateIJ(gX_dj0(:), gY_dj0(:), rotAngle);
gX_dj_rot = reshape(gX_dj_rot, size(gX_dj0)) - minXr;
gY_dj_rot = reshape(gY_dj_rot, size(gY_dj0)) - minYr;
validMask_dj = ~isnan(Z_dj);
validX_dj = gX_dj_rot(validMask_dj);
validY_dj = gY_dj_rot(validMask_dj);
validZ_dj = Z_dj(validMask_dj);
fprintf('  堆积体有效点: %d  高程: %.1f~%.1f m\n', numel(validX_dj), min(validZ_dj), max(validZ_dj))
F_dj = scatteredInterpolant(validX_dj, validY_dj, double(validZ_dj), 'natural', 'nearest');

%% ======== Step0-C：构造分层曲面 ========
% 关键：传给 C.addSurf 的曲面必须：
%   1. 只含 X/Y/Z 三个字段（不含 name/dZ/Z1/Z2 等）
%   2. 矩阵完全无 NaN（全填充）
%   3. 降采样（每隔dsStep行列取一个点）减小规模
fprintf('=== Step0-C: 构造分层曲面 ===\n')

% 降采样索引
ri = 1:dsStep:size(gX,1);
ci = 1:dsStep:size(gX,2);

% 基础地表曲面（全填充，降采样）
gX_ds = gX(ri, ci);
gY_ds = gY(ri, ci);
gZ_ds = gZ_fill(ri, ci);

% 各层面 Z 值（全部基于 gZ_fill 计算，无 NaN）
% S_bot：底面（地表下移 ballR*2*(botPackNum+surfPackNum)）
zBot = gZ_fill(ri, ci) - ballR*2*(botPackNum+surfPackNum);
% S1：主体层下界/底壳上界（S_bot 上移 ballR*2*botPackNum）
zS2 = zBot + ballR*2*botPackNum;
% S2：表层底界/主体层上界（地表下移 topLayerThick=30m）
zS1 = gZ_fill(ri, ci) - topLayerThick;


% S0：地表
zS0 = gZ_fill(ri, ci);
% S_top：顶盖顶面（地表上移 ballR*2*(topPackNum+surfPackNum2)）
zStop = gZ_fill(ri, ci) + ballR*2*(topPackNum+surfPackNum2);
% 顶部高处额外抬升（防颗粒逸出）
topRate = 0.3;
dZ_val = max(zStop(:)) - min(zStop(:));
topFilt = zStop > (max(zStop(:)) - dZ_val*topRate);
topZ = zStop(topFilt);
dTopZ = 100*(topZ - min(topZ)) / (dZ_val*topRate);
zStop(topFilt) = zStop(topFilt) + dTopZ;
% S_top0：顶盖底面/缓冲层顶界（S_top 下移 ballR*2*topPackNum）
zStop0 = zStop - ballR*2*topPackNum;


fprintf('  S_bot  Z: %.0f~%.0f m\n', min(zBot(:)), max(zBot(:)))
fprintf('  S1     Z: %.0f~%.0f m\n', min(zS1(:)), max(zS1(:)))
fprintf('  S2     Z: %.0f~%.0f m  (表层底界 深%.0fm)\n', min(zS2(:)), max(zS2(:)), topLayerThick)
fprintf('  S0     Z: %.0f~%.0f m  (地表)\n', min(zS0(:)), max(zS0(:)))
fprintf('  S_top0 Z: %.0f~%.0f m\n', min(zStop0(:)), max(zStop0(:)))
fprintf('  S_top  Z: %.0f~%.0f m\n', min(zStop(:)), max(zStop(:)))
fprintf('  降采样后矩阵尺寸: %d x %d\n', size(gX_ds,1), size(gX_ds,2))

% 构造只含 X/Y/Z 的精简结构体（不含 name 等字段）
S_bot.X = gX_ds;   S_bot.Y = gY_ds;   S_bot.Z = zBot;
S1.X    = gX_ds;   S1.Y    = gY_ds;   S1.Z    = zS1;
S2.X    = gX_ds;   S2.Y    = gY_ds;   S2.Z    = zS2;
S0.X    = gX_ds;   S0.Y    = gY_ds;   S0.Z    = zS0;
S_top0.X = gX_ds;  S_top0.Y = gY_ds;  S_top0.Z = zStop0;
S_top.X  = gX_ds;  S_top.Y  = gY_ds;  S_top.Z  = zStop;

%% ======== Step1：建立几何模型 ========
fprintf('\n=== Step1: 建立几何模型 ===\n')
fs.randSeed(1)
B = obj_Box;
B.name = 'TailingsDAM_fenceng';
B.GPUstatus = 'auto';
boxWidth = max(S_top.X(:));
boxLength = max(S_top.Y(:));
boxHeight = max(S_top.Z(:)) * 1.1;
fprintf('  模型箱: W=%.0f  L=%.0f  H=%.0f m\n', boxWidth, boxLength, boxHeight)
B.isUI = 1;
B.ballR = ballR;
B.isClump = 0;
B.distriRate = distriRate;
B.sampleW = boxWidth;
B.sampleL = boxLength;
B.sampleH = boxHeight;
B.platenStatus(:) = 0;
B.buildModel()
B.createSample()
B.sample.R = B.sample.R * 2^(1/12);

S_Bbot.X = gX_ds;   S_Bbot.Y = gY_ds;   S_Bbot.Z = zBot - ballR*4;
S_Btop.X = gX_ds;   S_Btop.Y = gY_ds;   S_Btop.Z = zStop + 500;

B.addSurf(S_bot)
B.addSurf(S_top)
B.addSurf(S_Bbot)
B.addSurf(S_Btop)
B.cutGroup({'sample', 'botB', 'topB'}, 1, 2)
B.cutGroup({'lefB', 'rigB', 'froB', 'bacB'}, 3, 4)
B.finishModel()
B.setSoftMat()
B.d = B.exportModel();
B.d.mo.isShear = 0;
d = B.d;
d.showB = 1;

%% ======== Step1-B：Tool_Cut 分层切割 ========
% 完全按教材第8.2.2节：
%   C=Tool_Cut(d)
%   C.addSurf 6次（只含X/Y/Z的精简结构体，无NaN，降采样）
%   C.setLayer({'sample'},[1,2,3,4,5,6])
%   d.makeModelByGroups({'layer1';...;'layer5'})
fprintf('=== Step1-B: Tool_Cut 分层切割 ===\n')
C = Tool_Cut(d);
C.addSurf(S_bot)
C.addSurf(S1)
C.addSurf(S2)
C.addSurf(S0)
C.addSurf(S_top0)
C.addSurf(S_top)
fprintf('  C.Surf 注册数量: %d\n', numel(C.Surf))

% 详细诊断第一层筛选条件
botZ = C.Surf{1}(d.mo.aX, d.mo.aY);   % S_bot
topZ = C.Surf{2}(d.mo.aX, d.mo.aY);   % S1

fprintf('\n=== 第一层筛选诊断 (S_bot -> S1) ===\n');
fprintf('单元总数: %d\n', d.aNum);
fprintf('单元 aZ 范围: [%.2f, %.2f]\n', min(d.mo.aZ), max(d.mo.aZ));
fprintf('S_bot 插值 Z 范围: [%.2f, %.2f]\n', min(botZ), max(botZ));
fprintf('S1    插值 Z 范围: [%.2f, %.2f]\n', min(topZ), max(topZ));

C.setLayer({'sample'}, [1, 2, 3, 4, 5, 6])
gNames = {'layer1'; 'layer2'; 'layer3'; 'layer4'; 'layer5'};
d.makeModelByGroups(gNames)

for i = 1:5
    layerName = ['layer' num2str(i)];
    if isfield(d.GROUP, layerName)
        d.GROUP.groupId(d.GROUP.(layerName)) = i;  % 使用1,2,3作为组ID
    end
end

% 更新setGroupId
d.setGroupId();
fprintf('  layer1(底壳)     : %d\n', numel(d.GROUP.layer1))
fprintf('  layer2(主体层)   : %d\n', numel(d.GROUP.layer2))
fprintf('  layer3(表层%.0fm): %d\n', topLayerThick, numel(d.GROUP.layer3))
fprintf('  layer4(缓冲层)   : %d\n', numel(d.GROUP.layer4))
fprintf('  layer5(顶盖)     : %d\n', numel(d.GROUP.layer5))

%% 固定底板和顶盖
d.defineWallElement('layer1')
d.mo.aR(d.GROUP.layer1) = B.ballR * 1.3;
mo = d.mo;
mo.isFix = 1;
gId_top = d.getGroupId('layer2');
mo.FixXId = gId_top;
mo.FixYId = gId_top;
mo.FixZId = gId_top;
nBall = d.mo.nBall;
bcFilter = sum(nBall > d.mNum & nBall ~= d.aNum, 2) > 0;
gFilter = zeros(size(bcFilter));
gFilter(gId_top) = 1;
mo.aR(gId_top) = B.ballR;
mo.aR(gFilter & (~bcFilter)) = B.ballR * 1.3;
d.setClump('layer2')
%d.addFixId('XYZ','layer2')
%% 重力沉积与平衡
fprintf('\n=== 重力沉积与平衡 ===\n')
B.uniformGRate = 1;
%d.show('aR')

B.gravitySediment(0.5)
d.mo.FixZId = [];
d.mo.dT = d.mo.dT * 4;

d.balance('Standard')
d.mo.dT = d.mo.dT / 4;
mZ_active = d.mo.aZ(1:d.mNum);
mX_active = d.mo.aX(1:d.mNum);
mY_active = d.mo.aY(1:d.mNum);
maxZlimit = max(gZ_raw(validMask)) + ballR * 10;
outZfilter = mZ_active > maxZlimit;
outXfilter = mX_active < -ballR*4 | mX_active > boxWidth  + ballR*4;
outYfilter = mY_active < -ballR*4 | mY_active > boxLength + ballR*4;
outFilter  = outZfilter | outXfilter | outYfilter;
outId = find(outFilter);
outId(outId > d.mNum) = [];
if ~isempty(outId)
    d.delElement(outId);
    fs.disp(['删除飞出颗粒: ' num2str(numel(outId)) ' 个']);
end
%% 保存
d.status.dispEnergy()
d.mo.setGPU('off')
d.clearData(1)
d.recordCalHour('TailingsDAM_fenceng_Finish')
mainSave = fullfile(saveDir, [B.name '1.mat']);
save(mainSave, 'B', 'd', 'C', 'validX_dj', 'validY_dj', 'validZ_dj', 'F_dj', 'duijiThick', 'demZmin', 'demZmax', 'topLayerThick', '-v7.3');
fprintf('  模型已保存: %s\n', mainSave)

%% ======== 显示三维地质分层模型 ========
fprintf('\n=== 显示三维地质分层模型 ===\n')
d.calculateData()
zThreshold = demZmax + ballR*2;

k_dj = convhull(validX_dj, validY_dj);
inDuijiXY = inpolygon(d.mo.aX, d.mo.aY, validX_dj(k_dj), validY_dj(k_dj));
Z_dji = zeros(d.aNum, 1);
idxIn = find(inDuijiXY);
if ~isempty(idxIn)
    Z_dji(idxIn) = F_dj(d.mo.aX(idxIn), d.mo.aY(idxIn));
end
inDuiji = inDuijiXY & (d.mo.aZ >= Z_dji - duijiThick) & (d.mo.aZ <= Z_dji + ballR*3);

showMask = false(d.aNum, 1);
showMask(d.GROUP.layer2) = true;
showMask(d.GROUP.layer3) = true;
showMask(d.GROUP.layer4) = true;
showMask(d.mo.aZ > zThreshold) = false;

colorData = ones(d.aNum, 1);
colorData(d.GROUP.layer3) = 2;
colorData(d.GROUP.layer4) = 1;
colorData(inDuiji & showMask) = 3;
d.data.aZ = colorData;
d.data.showFilter = showMask;

d.showB = 1;
d.Rrate = 1;
figure(2)
clf
d.show('aZ')
cmap = zeros(128, 3);
cmap(1:42, :) = repmat([0.20, 0.40, 0.85], 42, 1);
cmap(43:85, :) = repmat([0.10, 0.75, 0.20], 43, 1);
cmap(86:128, :) = repmat([0.90, 0.15, 0.10], 43, 1);
colormap(cmap)
caxis([1, 3])
view(135, 35)
xlabel('X [m]')
ylabel('Y [m]')
zlabel('Z [m]')
title('三维地质分层模型  蓝=主体层/绿=表层30m/红=堆积体')
cb = colorbar;
cb.Ticks = [1.33, 2.0, 2.67];
cb.TickLabels = {'主体层(layer2)', '表层30m(layer3)', 'duiji堆积体'};
fprintf('建模完成！总颗粒: %d  保存: %s\n', d.aNum, mainSave)