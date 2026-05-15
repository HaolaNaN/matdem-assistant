clear;

load('TempModel/sanzhou3(1).mat'); % 加载前三步模型
B.setUIoutput();
d = B.d;
d.calculateData();

% -------------------- 参数设置 --------------------
confining_pressure = 1e6;      % 围压 (Pa)
static_targetStress  = 5e6;    % 静加载目标轴压 (Pa)
static_rate          = 0.05e6; % 静加载速率 (Pa/s)
unload_rate          = 0.05e6; % 卸载速率 (Pa/s)
strainRate_control   = 0.001/1000; % 破坏阶段应变速率 (m/s)
failure_strain       = 0.03;   % 破坏应变 3%
dt                   = 0.01;   % 平衡步长 s
balance_tolerance    = 0.5;    % 平衡精度
current_time=0;
% 动载参数：每级[下限,上限,频率Hz]
levels = [2e6,3e6,1;3e6,4e6,2;4e6,5e6,3];
cycles_per_level = 30;
samples_per_cycle = 50;  % 每个周期采样点数

% -------------------- 几何与分组 --------------------
sampleIDs   = d.GROUP.sample;
membraneIDs = d.GROUP.tube;
topPlatenIDs= d.GROUP.topPlaten;
sampleR     = B.SET.sampleR;
sampleArea  = pi*sampleR^2;
H0          = B.sampleH;

% 记录数据
stressVec   = [];
VstrainVec  = [];
strainVec   = [];

%% -------------------- Phase 1: 施加围压 --------------------
d.mo.SET.CPressure = confining_pressure;
%d.balance('Standard', balance_tolerance);
d.setData();

%% -------------------- Phase 2: 轴向静加载（应力控制） --------------------
currentStress = mean(d.data.StressZZ(sampleIDs));
d.moveGroup('topPlaten',0,0,-max(d.mo.aZ(d.GROUP.topPlaten)-max(d.mo.aZ(d.GROUP.sample))))
iter = 0; maxIterPerStage = 1000;
while currentStress < static_targetStress && iter < maxIterPerStage
    iter = iter + 1;
    targetStressStep = min(currentStress + static_rate*dt, static_targetStress);
    Ftot = targetStressStep * sampleArea;
    d.mo.mGZ(topPlatenIDs) = -Ftot/numel(topPlatenIDs);
    %d.balance('Standard', balance_tolerance);
    d.setData();
    currentStress = mean(d.data.StressZZ(sampleIDs));

    %记录
    % stressVec(end+1) = currentStress;
    % V_total = f.run('fun/getVolume.m', d.mo.aX(sampleIDs), d.mo.aY(sampleIDs), d.mo.aZ(sampleIDs));
    % V0 = V_total;  % 初始体积
    % VstrainVec(end+1) = (V_total-V0)/V0*100;
    % strainVec(end+1) = mean(d.data.DisplacementZ(sampleIDs))/H0*100;
end

%% -------------------- Phase 3: 动载正弦循环（使用 addTimeProp） --------------------
% 记录动载开始时间
dynamicTime = current_time;

% 计算总动载时长
total_duration = 0;
for lev = 1:size(levels,1)
    period = 1 / levels(lev,3);
    total_duration = total_duration + cycles_per_level * period;
end

dt_dyn = dt;   % 0.01 s，动载时间步长，可根据需要调整

% 生成时间向量
DymT = dynamicTime : dt_dyn : dynamicTime + total_duration;
if DymT(end) < dynamicTime + total_duration
    DymT(end+1) = dynamicTime + total_duration;
end
forcePerParticle = zeros(size(DymT));%预设每个压力板颗粒的数组大小
Stress = zeros(size(DymT));
%计算体力
t_level_start = dynamicTime;
for lev = 1:size(levels,1)
    smin = levels(lev,1); smax = levels(lev,2); freq = levels(lev,3);
    mid = 0.5*(smax + smin); amp = 0.5*(smax - smin);
    period = 1 / freq;
    t_level_end = t_level_start + cycles_per_level * period;

    % 找到当前级别对应的时间索引
    index = (DymT >= t_level_start) & (DymT < t_level_end);
    t_within = DymT(index) - t_level_start;   % 该级别内的时间
    targetStress = mid + amp * sin(2*pi*freq * t_within);%目标压力大小
    Stress(index) = targetStress;
    forcePerParticle(index) = -targetStress * sampleArea / numel(topPlatenIDs);
    t_level_start = t_level_end;   % 分级加载，考虑下一级别开始时间
end

propName = 'mGZ';
d.addTimeProp('topPlaten', propName, DymT, forcePerParticle);
d.addRecordProp('topPlaten',propName);
for i = 1:length(DymT)
    %plot(DymT, -forcePerParticle * numel(topPlatenIDs));
    %d.mo.SET.currentTime = DymT(i);      % 设置当前时间，如有需要可保留
    d.balance('Standard', balance_tolerance/50);
    d.setData();
 
    % 记录
    % stressVec(end+1) = mean(d.data.StressZZ(sampleIDs));
    % V_total = f.run('fun/getVolume.m', d.mo.aX(sampleIDs), d.mo.aY(sampleIDs), d.mo.aZ(sampleIDs));
    % VstrainVec(end+1) = (V_total-V0)/V0*100;
    % strainVec(end+1) = mean(d.data.DisplacementZ(sampleIDs))/H0*100;
end
plot(DymT, Stress, 'b-');
xlabel('Time (s)'); ylabel('Axial Stress (MPa)');
%%
% for lev = 1:size(levels,1)
%     smin = levels(lev,1); smax = levels(lev,2); freq = levels(lev,3);
%     mid = 0.5*(smax + smin); amp = 0.5*(smax - smin);
%     period = 1/freq;
%     dt_sample = period/samples_per_cycle;
%     nSub = max(1, round(dt_sample/dt));
%
%     for cyc = 1:cycles_per_level
%         for s = 1:samples_per_cycle
%             t_within = (s-1)/samples_per_cycle*period;
%             targetStress = mid + amp*sin(2*pi*freq*t_within);
%             Ftot = targetStress * sampleArea;
%             d.mo.mGZ(topPlatenIDs) = -Ftot/numel(topPlatenIDs);
%             for sub = 1:nSub
%                 d.balance('Standard', balance_tolerance);
%             end
%             d.setData();
%
%             % 记录
%             % stressVec(end+1) = mean(d.data.StressZZ(sampleIDs));
%             % V_total = f.run('fun/getVolume.m', d.mo.aX(sampleIDs), d.mo.aY(sampleIDs), d.mo.aZ(sampleIDs));
%             % VstrainVec(end+1) = (V_total-V0)/V0*100;
%             % strainVec(end+1) = mean(d.data.DisplacementZ(sampleIDs))/H0*100;
%         end
%     end
% end

%% -------------------- Phase 4: 卸载轴压至0 --------------------
currStress = mean(d.data.StressZZ(sampleIDs));
while currStress > 1e3
    targetStress = max(currStress - unload_rate*dt, 0);
    Ftot = targetStress * sampleArea;
    d.mo.mGZ(topPlatenIDs) = -Ftot/numel(topPlatenIDs);
    d.balance('Standard', balance_tolerance);
    d.setData();
    currStress = mean(d.data.StressZZ(sampleIDs));

    % 记录
    % stressVec(end+1) = currStress;
    % V_total = f.run('fun/getVolume.m', d.mo.aX(sampleIDs), d.mo.aY(sampleIDs), d.mo.aZ(sampleIDs));
    % VstrainVec(end+1) = (V_total-V0)/V0*100;
    % strainVec(end+1) = mean(d.data.DisplacementZ(sampleIDs))/H0*100;
end

%% -------------------- Phase 5: 应变控制加载至破坏 --------------------
axial_disp_total = 0;
z_top0 = mean(d.mo.aZ(topPlatenIDs));
while axial_disp_total/H0 < failure_strain
    dz = -strainRate_control * dt;
    d.moveGroup('topPlaten', 0, 0, dz);
    d.mo.SET.CPressure = confining_pressure;
    d.balance('Standard', balance_tolerance);
    d.setData();

    z_top = mean(d.mo.aZ(topPlatenIDs));
    axial_disp_total = z_top0 - z_top;

    % 记录
    stressVec(end+1) = mean(d.data.StressZZ(sampleIDs));
    V_total = f.run('fun/getVolume.m', d.mo.aX(sampleIDs), d.mo.aY(sampleIDs), d.mo.aZ(sampleIDs));
    VstrainVec(end+1) = (V_total-V0)/V0*100;
    strainVec(end+1) = axial_disp_total/H0*100;
end

%% -------------------- 保存与绘图 --------------------
stressAndStrain = [stressVec(:), VstrainVec(:), strainVec(:)];
xlswrite('Triaxial/data_cycle.xls', stressAndStrain);

figure;
subplot(1,2,1);
plot(strainVec, stressVec/1e6);
ylabel('Stress (MPa)'); xlabel('Axial Strain (%)');
title('Axial Stress-Strain');

subplot(1,2,2);
plot(strainVec, VstrainVec);
ylabel('Volumetric Strain (%)'); xlabel('Axial Strain (%)');
title('Volumetric Strain vs Axial Strain');

%% -------------------- 保存模型 --------------------
save(['TempModel/' B.name '4.mat'],'B','d');