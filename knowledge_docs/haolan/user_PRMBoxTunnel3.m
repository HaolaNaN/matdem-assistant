%% step 3
clear;
load('TempModel/PRMTunnel2.mat');
B.setUIoutput();
d=B.d;
d.calculateData();
d.mo.setGPU('off');
hobR=0.2;hobT=0.1;ballR=B.ballR;Rrate=0.7;cutRate=1;
% PRM参数初始化
PRM_config = struct();
PRM_config.criterion = 'force';          % 使用接触力准则
PRM_config.threshold = 5e-4;             % 力阈值(N)
PRM_config.checkInterval = 5;            % 每5步检测一次
PRM_config.maxFragments = 6;             % 最大碎片数
PRM_config.packingDensity = 0.7;         % 堆积密度
PRM_config.detectionRadius = hobR * 1.5; % 检测半径

% 初始化计数器
stepCounter = 0;
totalReplaced = 0;

d.mo.mVX(:)=0;d.mo.mVY(:)=0;d.mo.mVZ(:)=0;
d.status=modelStatus(d);%initialize model status, which records running information


d.mo.isHeat=1;%calculate heat in the model
visRate=0.00001;
d.mo.mVis=d.mo.mVis*visRate;
d.setStandarddT();%set standard step time

%--------------define the interation
totalCircle=20;stepNum=100;
balanceNum=5;%you may use greater stepNum and balanceNum
disp(['Total real time is ' num2str(d.mo.dT*totalCircle*stepNum*balanceNum)]);
d.tic(totalCircle*stepNum);
fName=['data/step/' B.name  num2str(B.ballR) '-' num2str(B.distriRate) 'loopNum'];

%define the movement of the hob
sampleX=d.mo.aX(d.GROUP.sample);
hobX=d.mo.aX(d.GROUP.Hob);
hobR=(max(hobX)-min(hobX))/2+B.ballR*2;
dis=(max(sampleX)-min(sampleX))-hobR*2;
Dis=[1,0,-0.1]*dis;
dDis=Dis/(totalCircle*stepNum);
dDis_L=sqrt(sum(dDis.^2));
dAngle=dDis_L/hobR*180/pi;

%d.show('Displacement');return;
d.mo.bFilter(:)=1;%bond all elements
d.mo.zeroBalance();
save([fName '0.mat']);%return;
gpuStatus=d.mo.setGPU('auto');

for i=1:totalCircle
    d.mo.setGPU(gpuStatus);
    for j=1:stepNum
        d.moveGroup('Hob',dDis(1),dDis(2),dDis(3));
        hobId=d.GROUP.Hob;
        hobCx=gather(d.mo.aX(hobId(end)));
        hobCy=gather(d.mo.aY(hobId(end)));
        hobCz=gather(d.mo.aZ(hobId(end)));
        d.rotateGroup('Hob','XZ',-dAngle,hobCx,hobCy,hobCz);
        
        d.balance(balanceNum);
        
        % === PRM检测和替换 ===
        if mod(stepCounter, PRM_config.checkInterval) == 0
            center = [hobCx, hobCy, hobCz];
            [replaceIds, fragments] = detectReplaceableParticles(d, center, ...
                PRM_config.detectionRadius, PRM_config);
            
            if ~isempty(replaceIds)
                d = replaceParticlesPRM(d, replaceIds, fragments, PRM_config);
                totalReplaced = totalReplaced + length(replaceIds);
                fprintf('Step %d-%d: Replaced %d particles (total: %d)\n', ...
                    i, j, length(replaceIds), totalReplaced);
            end
        end
        stepCounter = stepCounter + 1;
        % === 结束PRM ===
        
        d.recordStatus();
        d.toc();
    end
    d.clearData(1);
    save([fName num2str(i) '.mat']);
    d.calculateData();
end

% 输出统计信息
fprintf('\n=== PRM Statistics ===\n');
fprintf('Total particles replaced: %d\n', totalReplaced);

function [replaceIds, fragmentObjs] = detectReplaceableParticles(d, center, radius, params)
    % 获取检测范围内的颗粒ID
    if nargin < 3 || isempty(radius)
        sampleIds = d.GROUP.sample; % 默认检测所有sample颗粒
    else
        % 计算到中心的距离
        dist = sqrt((d.mo.aX - center(1)).^2 + ...
                    (d.mo.aY - center(2)).^2 + ...
                    (d.mo.aZ - center(3)).^2);
        sampleIds = find(dist <= radius);
    end
    
    replaceIds = [];
    fragmentObjs = {};
    
    for i = 1:length(sampleIds)
        ballId = sampleIds(i);
        
        % 根据准则计算指标
        switch params.criterion
            case 'force'
                % 计算总接触力大小
                FX = sum(d.mo.nFnX(ballId,:) + d.mo.nFsX(ballId,:), 2);
                FY = sum(d.mo.nFnY(ballId,:) + d.mo.nFsY(ballId,:), 2);
                FZ = sum(d.mo.nFnZ(ballId,:) + d.mo.nFsZ(ballId,:), 2);
                indicator = sqrt(FX^2 + FY^2 + FZ^2);
                
            case 'energy'
                % 计算动能
                vx = d.mo.mVX(ballId);
                vy = d.mo.mVY(ballId);
                vz = d.mo.mVZ(ballId);
                mass = d.mo.mM(ballId);
                indicator = 0.5 * mass * (vx^2 + vy^2 + vz^2);
                
            case 'heat'
                % 使用总热量（如果启用了热计算）
                if d.mo.isHeat
                    indicator = sum(d.mo.aHeat(ballId,:));
                else
                    indicator = 0;
                end
                
            case 'combined'
                % 组合准则（示例：力×能量）
                FX = sum(d.mo.nFnX(ballId,:) + d.mo.nFsX(ballId,:), 2);
                FY = sum(d.mo.nFnY(ballId,:) + d.mo.nFsY(ballId,:), 2);
                FZ = sum(d.mo.nFnZ(ballId,:) + d.mo.nFsZ(ballId,:), 2);
                force = sqrt(FX^2 + FY^2 + FZ^2);
                
                vx = d.mo.mVX(ballId);
                vy = d.mo.mVY(ballId);
                vz = d.mo.mVZ(ballId);
                mass = d.mo.mM(ballId);
                energy = 0.5 * mass * (vx^2 + vy^2 + vz^2);
                
                indicator = force * energy; % 自定义组合
        end
        
        % 检查是否超过阈值
        if indicator > params.threshold
            replaceIds = [replaceIds; ballId];
            
            % 预生成碎片对象
            parentR = d.mo.aR(ballId);
            fragmentObj = generateFragments(parentR, params);
            fragmentObjs{end+1} = fragmentObj;
        end
    end
end

function fragmentObj = generateFragments(parentR, params)
    % 生成替换碎片
    % 方案A：规则球体填充
    nFragments = min(params.maxFragments, ceil((parentR/mean(d.mo.aR))^3));
    
    if nFragments <= 1
        % 如果碎片太少，保持原颗粒
        fragmentObj = struct('X', 0, 'Y', 0, 'Z', 0, 'R', parentR);
        return;
    end
    
    % 计算子颗粒半径（体积守恒考虑堆积密度）
    parentVolume = (4/3)*pi*parentR^3;
    childR = (parentVolume * params.packingDensity / nFragments / (4/3*pi))^(1/3);
    
    % 生成随机位置（在母颗粒半径内）
    fragmentObj = struct('X', [], 'Y', [], 'Z', [], 'R', []);
    
    for i = 1:nFragments
        % 球坐标随机生成
        theta = 2*pi*rand();
        phi = acos(2*rand() - 1);
        r = parentR * rand()^(1/3); % 均匀分布在球体内
        
        x = r * sin(phi) * cos(theta);
        y = r * sin(phi) * sin(theta);
        z = r * cos(phi);
        
        fragmentObj.X = [fragmentObj.X; x];
        fragmentObj.Y = [fragmentObj.Y; y];
        fragmentObj.Z = [fragmentObj.Z; z];
        fragmentObj.R = [fragmentObj.R; childR];
    end
end

function d = replaceParticlesPRM(d, replaceIds, fragmentObjs, params)
    % 批量替换颗粒，保持动量守恒
    
    for k = 1:length(replaceIds)
        ballId = replaceIds(k);
        fragmentObj = fragmentObjs{k};
        
        % 保存母颗粒属性
        parentX = d.mo.aX(ballId);
        parentY = d.mo.aY(ballId);
        parentZ = d.mo.aZ(ballId);
        parentVx = d.mo.mVX(ballId);
        parentVy = d.mo.mVY(ballId);
        parentVz = d.mo.mVZ(ballId);
        parentMass = d.mo.mM(ballId);
        parentMatId = d.aMatId(ballId);
        
        % 调整碎片位置到母颗粒中心
        fragmentObj.X = fragmentObj.X + parentX;
        fragmentObj.Y = fragmentObj.Y + parentY;
        fragmentObj.Z = fragmentObj.Z + parentZ;
        
        % 计算碎片总质量（近似）
        childMassTotal = sum((4/3)*pi*fragmentObj.R.^3) * mean(d.Mats{parentMatId}.density);
        
        % 动量守恒：分配速度
        if childMassTotal > 0
            velocityScale = parentMass / childMassTotal;
            childVx = parentVx * velocityScale;
            childVy = parentVy * velocityScale;
            childVz = parentVz * velocityScale;
            
            % 可以添加随机扰动模拟破碎能量耗散
            randomFactor = 0.1; % 10%随机扰动
            childVx = childVx + randomFactor * parentVx * (rand() - 0.5);
            childVy = childVy + randomFactor * parentVy * (rand() - 0.5);
            childVz = childVz + randomFactor * parentVz * (rand() - 0.5);
        else
            childVx = 0; childVy = 0; childVz = 0;
        end
        
        % 删除母颗粒
        d.delElement(ballId);
        
        % 添加碎片颗粒
        childIds = d.addElement(parentMatId, fragmentObj);
        
        % 为碎片分配速度（需要直接操作mo数组）
        if ~isempty(childIds)
            d.mo.mVX(childIds) = childVx;
            d.mo.mVY(childIds) = childVy;
            d.mo.mVZ(childIds) = childVz;
        end
        
        % 可选：将碎片添加到新组中便于追踪
        d.addGroup(['fragment_' num2str(k)], childIds);
    end
    
    % 重新平衡接触（重要！）
    d.mo.setNearbyBall();
end
