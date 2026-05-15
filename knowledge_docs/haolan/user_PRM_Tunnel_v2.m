%% PRM Tunnel Excavation - Improved Version
% 相比原始版本的关键改进：
% 1. 碎片密排生成（排斥力松弛），消除初始重叠导致的数值发散
% 2. 应变能 → 径向破碎速度（能量守恒转化）
% 3. 排除已有碎片被二次检测（防止链式替换失控）
% 4. 每步最大替换数限制（保证数值稳定性）
% 5. 系统能量预算追踪（动能+应变能+热能）
% 6. 接触力数据在 PRM 检测前始终有效（调整了检测时机）

%% step 1: Build geometrical model
clear;
fs.randSeed(1);
B=obj_Box;
B.name='PRMTunnel';
B.GPUstatus='auto';
%--------------initial model------------
B.ballR=0.02;
B.isClump=0;
B.distriRate=0.3;
B.sampleW=1.2;
B.sampleL=0.6;
B.sampleH=0.6;
B.type='topPlaten';
B.setType();
B.buildInitialModel();
B.setUIoutput();

d=B.d;
%--------------end initial model------------
B.gravitySediment();
B.compactSample(2);
mfs.reduceGravity(d,10);
%------------return and save result--------------
d.status.dispEnergy();

d.mo.setGPU('off');
d.clearData(1);
d.recordCalHour('PRMBox1Finish');
save(['TempModel/' B.name '1.mat'],'B','d');
save(['TempModel/' B.name '1R' num2str(B.ballR) '-distri' num2str(B.distriRate) 'aNum' num2str(d.aNum) '.mat']);
d.calculateData();

%% step 2: Set material and create hob
clear
load('TempModel/PRMTunnel1.mat');
B.setUIoutput();
d=B.d;
d.calculateData();
d.mo.setGPU('off');
d.getModel();

%------------------remove top half (tunnel roof)-------------
mZ=d.mo.aZ(1:d.mNum);
topLayerFilter=mZ>max(mZ)*0.5;
d.delElement(find(topLayerFilter));

%--------------set material, define strong and weak rock
matTxt=load('Mats\StrongRock.txt');
Mats{1,1}=material('StrongRock',matTxt,B.ballR);
Mats{1,1}.Id=1;
matTxt2=load('Mats\WeakRock.txt');
Mats{2,1}=material('WeakRock',matTxt2,B.ballR);
Mats{2,1}.Id=2;
d.Mats=Mats;

%set different layers with different mechanical properties
dipD=90;dipA=60;strongT=0.1;weakT=0.1;
weakFilter=mfs.getWeakLayerFilter(d.mo.aX,d.mo.aY,d.mo.aZ,dipD,dipA,strongT,weakT);
sampleId=d.getGroupId('sample');
aWFilter=false(size(weakFilter));
aWFilter(sampleId)=true;
sampleWfilter=aWFilter&weakFilter;
d.addGroup('WeakLayer',find(sampleWfilter));

d.setGroupMat('WeakLayer','WeakRock');
d.groupMat2Model({'WeakLayer'},1);

%create a hob (tunnel boring tool)
hobR=0.2;hobT=0.1;ballR=B.ballR;Rrate=0.7;cutRate=1;
hob=mfs.makeHob(hobR,hobT,cutRate,ballR,Rrate);
hob=mfs.rotate(hob,'YZ',90);

%change the hob object to a build object to get nearby ball matrix
hobd=mfs.Obj2Build(hob);
aCN=sum(hobd.mo.nBall~=hobd.aNum,2);
aCN=[aCN;0];
CNFilter=aCN<mean(aCN)*0.88;
hobd.showFilter('Filter',CNFilter);
mFilter=hobd.data.showFilter(1:hobd.mNum);
hob=mfs.filterObj(hob,mFilter);

%add a central ball to record the coordinates
hob.X=[hob.X;(max(hob.X)+min(hob.X))/2];
hob.Y=[hob.Y;(max(hob.Y)+min(hob.Y))/2];
hob.Z=[hob.Z;(max(hob.Z)+min(hob.Z))/2];
hob.R=[hob.R;mean(hob.R)];

%-------------add the hob to the model
hobId=d.addElement(1,hob);
d.addGroup('Hob',hobId);
sampleId=d.GROUP.sample;
d.moveGroup('Hob',hobR,(max(d.aY(sampleId))+min(d.aY(sampleId)))/2,0);
hobBot=min(d.mo.aZ(hobId)-d.mo.aR(hobId));
sampleTop=max(d.mo.aZ(sampleId)+d.mo.aR(sampleId));
d.moveGroup('Hob',0,0,sampleTop-hobBot);
d.setClump('Hob');
d.removeGroupForce(d.GROUP.Hob,[d.GROUP.topB;d.GROUP.rigB]);

d.mo.isFix=1;
d.addFixId('X',hobId);
d.addFixId('Y',hobId);
d.mo.zeroBalance();
d.balanceBondedModel0();
d.mo.bFilter(:)=0;
d.balance('Standard');
d.balanceBondedModel0();
d.addFixId('Z',hobId);

d.mo.setGPU('off');
d.clearData(1);
d.recordCalHour('PRMBox2Finish');
save(['TempModel/' B.name '2.mat'],'B','d');
save(['TempModel/' B.name '2R' num2str(B.ballR) '-distri' num2str(B.distriRate) 'aNum' num2str(d.aNum) '.mat']);
d.calculateData();

%% step 3: PRM tunnel excavation
clear
load('TempModel/PRMTunnel2.mat');
B.setUIoutput();
d=B.d;
d.calculateData();
d.mo.setGPU('off');

%========================================================================
% PRM parameter initialization
%========================================================================
PRM_settings = struct();
hobR=0.2;hobT=0.1;ballR=B.ballR;Rrate=0.7;cutRate=1;
% --- Detection ---
PRM_settings.criterion = 'force';          % 替换判据: 'force' | 'energy' | 'combined'
PRM_settings.threshold = 3e+5;             % 力阈值(N)，超过此值的颗粒被替换
PRM_settings.detectionRadius = hobR * 1.5; % 检测半径（基于刀具尺寸）
PRM_settings.checkInterval = 5;            % 每N步检测一次（放在 balance 之后）
PRM_settings.maxReplacePerStep = 8;        % 单步最大替换颗粒数（防止同时替换过多导致发散）

% --- Fragment ---
PRM_settings.maxFragments = 8;             % 单母颗粒最大碎片数
PRM_settings.sizeSpread = 0.3;             % 碎片半径分布展宽（对数正态分布 sigma）
PRM_settings.burstEfficiency = 0.25;       % 应变能→动能转化效率（其余耗散为热/断裂能）

% --- Misc ---
PRM_settings.minRadius = B.ballR * 0.4;    % 最小替换半径

%========================================================================
% Simulation parameters
%========================================================================
totalCircle = 10;
stepNum = 20;
balanceNum = 5;

% Movement of the hob
sampleX = d.mo.aX(d.GROUP.sample);
hobX = d.mo.aX(d.GROUP.Hob);
hobR = (max(hobX)-min(hobX))/2 + B.ballR*2;
dis = (max(sampleX)-min(sampleX)) - hobR*2;
Dis = [1, 0, -0.1] * dis;
dDis = Dis / (totalCircle * stepNum);
dDis_L = sqrt(sum(dDis.^2));
dAngle = dDis_L / hobR * 180 / pi;

% Initial cleanup
d.mo.mVX(:)=0; d.mo.mVY(:)=0; d.mo.mVZ(:)=0;
d.status = modelStatus(d);
d.mo.isHeat = 1;
d.mo.mVis = d.mo.mVis * 0.00001;
d.setStandarddT();

disp(['Total real time is ' num2str(d.mo.dT*totalCircle*stepNum*balanceNum)]);
d.tic(totalCircle * stepNum);
fName = ['data/step/' B.name num2str(B.ballR) '-' num2str(B.distriRate) 'loopNum'];

% Bond all and save initial state
d.mo.bFilter(:) = 1;
d.mo.zeroBalance();
save([fName '0.mat']);
gpuStatus = d.mo.setGPU('auto');

%========================================================================
% Tracking arrays
%========================================================================
fragmentStats = [];  % [round, nFragment, newFrags, KE_before, KE_after, SE_before, SE_after, heat]
stepCounter = 0;
totalReplaced = 0;
energyLog = [];

%========================================================================
% Main PRM loop
%========================================================================
for i = 1:totalCircle
    newFragsThisRound = 0;

    % --- Energy before round ---
    eb = computeEnergyBudget(d);
    energyBefore = eb;

    for j = 1:stepNum
        % 1. Get hob center position
        hobId = d.GROUP.Hob;
        hobCx = gather(d.mo.aX(hobId(end)));
        hobCy = gather(d.mo.aY(hobId(end)));
        hobCz = gather(d.mo.aZ(hobId(end)));

        % 2. Move and rotate hob
        d.moveGroup('Hob', dDis(1), dDis(2), dDis(3));
        d.rotateGroup('Hob', 'XZ', -dAngle, hobCx, hobCy, hobCz);

        % 3. Balance (contact forces are now fresh)
        d.balance(balanceNum);
        stepCounter = stepCounter + 1;

        % 4. PRM detection and replacement (forces valid)
        if mod(stepCounter, PRM_settings.checkInterval) == 0
            center = [hobCx, hobCy, hobCz];
            [replaceIds, fragments] = detectReplaceableParticlesPRM(d, center, ...
                PRM_settings.detectionRadius, PRM_settings);

            if ~isempty(replaceIds)
                [d, newFragIds, energyData] = replaceParticlesPRM(d, replaceIds, ...
                    fragments, PRM_settings);
                totalReplaced = totalReplaced + length(replaceIds);
                newFragsThisRound = newFragsThisRound + length(newFragIds);

                % Log energy change from this replacement
                if ~isempty(energyData)
                    energyLog = [energyLog; stepCounter, ...
                        energyData.strainReleased, energyData.kineticAdded, ...
                        energyData.heatGenerated];
                end
            end
        end

        d.recordStatus();
        d.toc();
    end
    d.figureNumber=d.show('groupId');
    % --- End of round: energy budget ---
    ea = computeEnergyBudget(d);
    energyAfter = ea;

    % Maintain fragment group (dedup + valid IDs)
    if isfield(d.GROUP, 'fragment') && ~isempty(d.GROUP.fragment)
        d.GROUP.fragment = unique(d.GROUP.fragment);
        d.GROUP.fragment = d.GROUP.fragment(d.GROUP.fragment <= d.mNum & d.GROUP.fragment >= 1);
        d.GROUP.groupId(d.GROUP.fragment) = 50;
    end

    % Record statistics
    nFrag = 0;
    if isfield(d.GROUP, 'fragment') && ~isempty(d.GROUP.fragment)
        nFrag = length(d.GROUP.fragment);
    end
    fragmentStats = [fragmentStats; i, nFrag, newFragsThisRound, ...
        energyBefore.kinetic, energyAfter.kinetic, ...
        energyBefore.strain, energyAfter.strain, ...
        energyAfter.heat - energyBefore.heat];

    % Print round summary
    fprintf('\n========== ROUND %d SUMMARY ==========\n', i);
    fprintf('  Fragments: %d (+%d this round)\n', nFrag, newFragsThisRound);
    fprintf('  Total replaced: %d\n', totalReplaced);
    fprintf('  KE: %.6e -> %.6e (delta %.6e)\n', ...
        energyBefore.kinetic, energyAfter.kinetic, ...
        energyAfter.kinetic - energyBefore.kinetic);
    fprintf('  Strain E: %.6e -> %.6e (delta %.6e)\n', ...
        energyBefore.strain, energyAfter.strain, ...
        energyAfter.strain - energyBefore.strain);
    fprintf('  Heat: %.6e -> %.6e\n', energyBefore.heat, energyAfter.heat);
    fprintf('======================================\n\n');

    % Save checkpoint
    % NOTE: clearData(1) is NOT called here — force data kept for next round's detection
    d.calculateData();
    save([fName num2str(i) '.mat']);
end

% Final cleanup and save
d.mo.setGPU('off');
d.clearData(1);
d.recordCalHour('PRMBoxTunnelFinish');
save(['TempModel/' B.name '3.mat'], 'B', 'd');
save(['TempModel/' B.name '3R' num2str(B.ballR) '-distri' num2str(B.distriRate) 'aNum' num2str(d.aNum) '.mat']);
d.calculateData();

%% ========================================================================
%  FUNCTION: detectReplaceableParticlesPRM
%  改进：排除已有碎片 + 每步上限 + 指标排序择优
%% ========================================================================
function [replaceIds, fragmentObjs] = detectReplaceableParticlesPRM(d, center, radius, params)
replaceIds = [];
fragmentObjs = {};

% Check contact force data
if isempty(d.mo.nFnX) || isempty(d.mo.nFsX)
    return;
end

% ---- Step 1: Collect candidates within radius ----
dist = sqrt((d.mo.aX - center(1)).^2 + ...
    (d.mo.aY - center(2)).^2 + ...
    (d.mo.aZ - center(3)).^2);
% Model particles only (1:d.mNum), within radius, within force matrix dimensions
maxForceId = min(d.mNum, size(d.mo.nFnX, 1));
candidates = find(dist(1:maxForceId) <= radius);

% ---- Step 2: Exclude hob, fragment, boundary particles ----
% Hob
if isfield(d.GROUP, 'Hob') && ~isempty(d.GROUP.Hob)
    candidates = setdiff(candidates, d.GROUP.Hob);
end
% Existing fragments (do not re-fragment)
if isfield(d.GROUP, 'fragment') && ~isempty(d.GROUP.fragment)
    candidates = setdiff(candidates, d.GROUP.fragment);
end
% Boundary groups
boundGroups = {'topB','botB','lefB','rigB','froB','bacB'};
for g = 1:length(boundGroups)
    if isfield(d.GROUP, boundGroups{g}) && ~isempty(d.GROUP.(boundGroups{g}))
        candidates = setdiff(candidates, d.GROUP.(boundGroups{g}));
    end
end

if isempty(candidates)
    return;
end

% ---- Step 3: Compute indicator for each candidate ----
nCand = length(candidates);
indicators = zeros(nCand, 1);

for idx = 1:nCand
    ballId = candidates(idx);
    if ballId > d.mNum || ballId < 1
        continue;
    end

    switch params.criterion
        case 'force'
            FX = sum(d.mo.nFnX(ballId,:) + d.mo.nFsX(ballId,:), 2);
            FY = sum(d.mo.nFnY(ballId,:) + d.mo.nFsY(ballId,:), 2);
            FZ = sum(d.mo.nFnZ(ballId,:) + d.mo.nFsZ(ballId,:), 2);
            indicators(idx) = sqrt(FX^2 + FY^2 + FZ^2);

        case 'energy'
            vx = gather(d.mo.mVX(ballId));
            vy = gather(d.mo.mVY(ballId));
            vz = gather(d.mo.mVZ(ballId));
            mass = gather(d.mo.mM(ballId));
            indicators(idx) = 0.5 * mass * (vx^2 + vy^2 + vz^2);

        case 'combined'
            FX = sum(d.mo.nFnX(ballId,:) + d.mo.nFsX(ballId,:), 2);
            FY = sum(d.mo.nFnY(ballId,:) + d.mo.nFsY(ballId,:), 2);
            FZ = sum(d.mo.nFnZ(ballId,:) + d.mo.nFsZ(ballId,:), 2);
            force = sqrt(FX^2 + FY^2 + FZ^2);
            vx = gather(d.mo.mVX(ballId));
            vy = gather(d.mo.mVY(ballId));
            vz = gather(d.mo.mVZ(ballId));
            mass = gather(d.mo.mM(ballId));
            KE = 0.5 * mass * (vx^2 + vy^2 + vz^2);
            indicators(idx) = force * sqrt(KE + 1e-30);
    end
end

% ---- Step 4: Filter by threshold and minRadius ----
aboveThreshold = indicators > params.threshold;

% Also filter by minRadius
minR = params.minRadius;
for idx = 1:nCand
    if aboveThreshold(idx)
        ballId = candidates(idx);
        if d.mo.aR(ballId) < minR
            aboveThreshold(idx) = false;
        end
    end
end

qualified = find(aboveThreshold);
if isempty(qualified)
    return;
end

% ---- Step 5: Sort by indicator (descending), cap per step ----
[~, sortIdx] = sort(indicators(qualified), 'descend');
qualified = qualified(sortIdx);

if length(qualified) > params.maxReplacePerStep
    qualified = qualified(1:params.maxReplacePerStep);
end

% ---- Step 6: Generate fragments and compute mean radius ----
% Compute mean radius of candidates for fragment size estimation
validIds = candidates(qualified);
meanR = mean(d.mo.aR(validIds));

replaceIds = candidates(qualified);
fragmentObjs = cell(length(replaceIds), 1);

for idx = 1:length(replaceIds)
    ballId = replaceIds(idx);
    parentR = d.mo.aR(ballId);
    fragmentObjs{idx} = generateFragmentsPRM(parentR, meanR, params);
end
end

%% ========================================================================
%  FUNCTION: generateFragmentsPRM
%  改进：密排布置 + 对数正态粒径分布 + 重叠控制
%% ========================================================================
function fragmentObj = generateFragmentsPRM(parentR, meanRadius, params)
% ---- Step 1: Determine number of fragments ----
volRatio = (parentR / max(meanRadius, 1e-10))^3;
nTarget = max(2, round(volRatio * 0.5));
nFragments = min(params.maxFragments, nTarget);

if nFragments <= 1
    % Single particle — no fragmentation
    fragmentObj = struct('X', 0, 'Y', 0, 'Z', 0, 'R', parentR);
    return;
end

% ---- Step 2: Generate fragment radii (log-normal distribution) ----
% Target: total volume = parent volume
parentVolume = 4/3 * pi * parentR^3;
targetChildVolume = parentVolume / nFragments;
targetChildR = (targetChildVolume * 3 / (4*pi))^(1/3);

% Log-normal with given spread
sigma = params.sizeSpread;
mu = log(targetChildR) - sigma^2/2;  % ensure mean = targetChildR
rawRadii = exp(mu + sigma * randn(nFragments, 1));

% Clamp to minimum radius
minR = params.minRadius;
rawRadii = max(rawRadii, minR);

% Volume conservation scaling
rawVolume = sum(4/3 * pi * rawRadii.^3);
scale = (parentVolume / rawVolume)^(1/3);
radii = rawRadii * scale;

% ---- Step 3: Close-packing with repulsion ----
% Initialize positions randomly on sphere surface, then scale inward
positions = randn(nFragments, 3);
posNorm = sqrt(sum(positions.^2, 2));
positions = positions ./ max(posNorm, 1e-30);
positions = positions * parentR * 0.5;  % start at half-radius

% Repulsion iterations (push apart to minimize overlap)
for iter = 1:80
    maxOverlap = 0;
    for k = 1:nFragments
        % Vector from k to all others
        dp = positions - positions(k, :);
        d2 = sum(dp.^2, 2);
        d = sqrt(d2);
        d(k) = inf;

        % Overlap = (r_i + r_j) - d_ij
        minSep = radii(k) + radii;
        overlap = max(minSep - d, 0);

        % Repulsion force (proportional to overlap, along unit vector)
        unitVec = dp ./ max(d, 1e-30);
        repForce = sum(unitVec .* overlap, 1);

        % Center attraction (keeps particles from flying out)
        centerForce = -positions(k, :) / parentR^2 * 0.05;

        % Update position
        dr = repForce * 0.5 + centerForce;
        if any(isnan(dr)) || any(isinf(dr))
            dr = zeros(1, 3);
        end
        positions(k, :) = positions(k, :) + dr;

        % Clamp to parent sphere (with particle radius margin)
        pkNorm = sqrt(sum(positions(k, :).^2));
        maxR = parentR - radii(k) * 0.9;
        if pkNorm > maxR && pkNorm > 1e-30
            positions(k, :) = positions(k, :) * maxR / pkNorm;
        end

        % Track max overlap
        thisOverlap = max(overlap);
        if thisOverlap > maxOverlap
            maxOverlap = thisOverlap;
        end
    end

    if maxOverlap < parentR * 0.01
        break;  % overlap acceptably small
    end
end

% ---- Step 4: Final overlap check — scale down if still excessive ----
finalRadii = radii;
for k = 1:nFragments
    dp = positions - positions(k, :);
    d = sqrt(sum(dp.^2, 2));
    d(k) = inf;
    minSep = radii(k) + radii;
    overlap = max(minSep - d, 0);
    maxO = max(overlap);
    if maxO > parentR * 0.15
        % Scale down this particle slightly
        scaleFactor = 0.85;
        finalRadii(k) = radii(k) * scaleFactor;
    end
end

% Re-scale for volume conservation after adjustments
finalVolume = sum(4/3 * pi * finalRadii.^3);
if finalVolume > 0
    scale2 = (parentVolume / finalVolume)^(1/3);
    finalRadii = finalRadii * scale2;
end

% ---- Step 5: Build output struct ----
fragmentObj = struct('X', positions(:,1), 'Y', positions(:,2), ...
    'Z', positions(:,3), 'R', finalRadii);
end

%% ========================================================================
%  FUNCTION: replaceParticlesPRM
%  改进：应变能→径向破碎速度 + 能量追踪 + 组管理
%% ========================================================================
function [d, newFragmentIds, energyData] = replaceParticlesPRM(d, replaceIds, fragmentObjs, params)
newFragmentIds = [];
energyData = struct('strainReleased', 0, 'kineticAdded', 0, 'heatGenerated', 0);

% Initialize fragment group
if ~isfield(d.GROUP, 'fragment')
    d.GROUP.fragment = [];
end

% Sort descending for safe ID management
[replaceIds, sortIdx] = sort(replaceIds, 'descend');
fragmentObjs = fragmentObjs(sortIdx);

for k = 1:length(replaceIds)
    ballId = replaceIds(k);
    fragmentObj = fragmentObjs{k};

    % ---- Save parent properties ----
    parentX = gather(d.mo.aX(ballId));
    parentY = gather(d.mo.aY(ballId));
    parentZ = gather(d.mo.aZ(ballId));
    parentVx = gather(d.mo.mVX(ballId));
    parentVy = gather(d.mo.mVY(ballId));
    parentVz = gather(d.mo.mVZ(ballId));
    parentMatId = d.aMatId(ballId);
    parentMass = gather(d.mo.mM(ballId));

    % ---- Estimate strain energy from contacts ----
    strainEnergy = computeStrainEnergy(d, ballId);
    energyData.strainReleased = energyData.strainReleased + strainEnergy;

    % ---- Compute burst velocity from strain energy ----
    % E_strain * efficiency = 0.5 * M_total * v_burst^2
    nFrag = length(fragmentObj.R);
    if strainEnergy > 0 && parentMass > 0 && nFrag > 0
        efficiency = params.burstEfficiency;
        vBurst = sqrt(2 * strainEnergy * efficiency / parentMass);
    else
        vBurst = 0;
    end

    % Kinetic energy we're adding
    keAdded = 0.5 * parentMass * vBurst^2;
    energyData.kineticAdded = energyData.kineticAdded + keAdded;

    % ---- Position fragments at parent center ----
    fragmentObj.X = fragmentObj.X + parentX;
    fragmentObj.Y = fragmentObj.Y + parentY;
    fragmentObj.Z = fragmentObj.Z + parentZ;

    % ---- Delete parent ----
    d.delElement(ballId);

    % ---- Add children ----
    childIds = d.addElement(parentMatId, fragmentObj);

    if ~isempty(childIds)
        % Set child velocities: parent velocity + radial burst
        for ci = 1:length(childIds)
            cid = childIds(ci);
            % Radial direction from parent center
            rx = gather(d.mo.aX(cid)) - parentX;
            ry = gather(d.mo.aY(cid)) - parentY;
            rz = gather(d.mo.aZ(cid)) - parentZ;
            rNorm = sqrt(rx^2 + ry^2 + rz^2);

            if rNorm > 1e-30
                % Outward radial burst + parent velocity + perturbation
                burstV = vBurst * 0.5;  % distribute among fragments
                d.mo.mVX(cid) = parentVx + rx/rNorm * burstV * (0.8 + 0.4*rand());
                d.mo.mVY(cid) = parentVy + ry/rNorm * burstV * (0.8 + 0.4*rand());
                d.mo.mVZ(cid) = parentVz + rz/rNorm * burstV * (0.8 + 0.4*rand());
            else
                d.mo.mVX(cid) = parentVx * (0.9 + 0.2*rand());
                d.mo.mVY(cid) = parentVy * (0.9 + 0.2*rand());
                d.mo.mVZ(cid) = parentVz * (0.9 + 0.2*rand());
            end
        end

        % Append to fragment group
        d.GROUP.fragment = [d.GROUP.fragment; childIds(:)];
    end

    newFragmentIds = [newFragmentIds; childIds(:)];
end

% Estimate heat generated (strain energy not converted to KE)
energyData.heatGenerated = energyData.strainReleased - energyData.kineticAdded;
if energyData.heatGenerated < 0
    energyData.heatGenerated = 0;
end

% Update model state
d.mo.mNum = d.mNum;
d.mo.dis_mXYZ(:) = 0;
d.mo.zeroBalance();
end

%% ========================================================================
%  FUNCTION: computeStrainEnergy
%  计算颗粒在所有接触中储存的弹性应变能
%% ========================================================================
function E = computeStrainEnergy(d, ballId)
E = 0;
if ballId > d.mNum || ballId < 1
    return;
end

% Check force/stiffness matrices exist
if isempty(d.mo.nFnX) || isempty(d.mo.nKNe)
    return;
end
if ballId > size(d.mo.nFnX, 1) || ballId > size(d.mo.nKNe, 1)
    return;
end

try
    nContacts = size(d.mo.nFnX, 2);
    for c = 1:nContacts
        % Check if this is a valid contact (not d.aNum sentinel)
        if d.mo.nBall(ballId, c) == d.aNum || d.mo.nBall(ballId, c) <= 0
            continue;
        end

        % Normal force components
        fnx = gather(d.mo.nFnX(ballId, c));
        fny = gather(d.mo.nFnY(ballId, c));
        fnz = gather(d.mo.nFnZ(ballId, c));
        fnSq = fnx^2 + fny^2 + fnz^2;

        % Shear force components
        fsx = gather(d.mo.nFsX(ballId, c));
        fsy = gather(d.mo.nFsY(ballId, c));
        fsz = gather(d.mo.nFsZ(ballId, c));
        fsSq = fsx^2 + fsy^2 + fsz^2;

        % Stiffness
        kn = gather(d.mo.nKNe(ballId, c));
        ks = gather(d.mo.nKSe(ballId, c));

        % Strain energy: 0.5 * F^2 / K
        if kn > 1e-30
            E = E + 0.5 * fnSq / kn;
        end
        if ks > 1e-30
            E = E + 0.5 * fsSq / ks;
        end
    end
catch
    % If anything goes wrong (e.g., matrix dimension mismatch), return 0
    E = 0;
end
end

%% ========================================================================
%  FUNCTION: computeEnergyBudget
%  计算系统总能量（动能 + 应变能 + 热能）
%% ========================================================================
function budget = computeEnergyBudget(d)
budget = struct('kinetic', 0, 'strain', 0, 'heat', 0, 'total', 0);

% Kinetic energy: 0.5 * m * v^2
try
    vx = gather(d.mo.mVX(1:d.mNum));
    vy = gather(d.mo.mVY(1:d.mNum));
    vz = gather(d.mo.mVZ(1:d.mNum));
    mass = gather(d.mo.mM(1:d.mNum));
    KE = 0.5 * sum(mass .* (vx.^2 + vy.^2 + vz.^2));
    budget.kinetic = KE;
catch
    budget.kinetic = 0;
end

% Strain energy: sum over all contacts
try
    SE = 0;
    if ~isempty(d.mo.nFnX) && ~isempty(d.mo.nKNe) && ~isempty(d.mo.nBall)
        nM = min(d.mNum, size(d.mo.nFnX, 1));
        nC = size(d.mo.nFnX, 2);
        % Sample particles for strain energy (full sum is expensive)
        % Use every Nth particle for large models
        sampleStep = max(1, floor(nM / 500));
        sampleIds = 1:sampleStep:nM;

        for idx = 1:length(sampleIds)
            pid = sampleIds(idx);
            for c = 1:nC
                if d.mo.nBall(pid, c) == d.aNum || d.mo.nBall(pid, c) <= 0
                    continue;
                end
                fnx = gather(d.mo.nFnX(pid, c));
                fny = gather(d.mo.nFnY(pid, c));
                fnz = gather(d.mo.nFnZ(pid, c));
                fsx = gather(d.mo.nFsX(pid, c));
                fsy = gather(d.mo.nFsY(pid, c));
                fsz = gather(d.mo.nFsZ(pid, c));
                kn = gather(d.mo.nKNe(pid, c));
                ks = gather(d.mo.nKSe(pid, c));

                if kn > 1e-30
                    SE = SE + 0.5 * (fnx^2 + fny^2 + fnz^2) / kn;
                end
                if ks > 1e-30
                    SE = SE + 0.5 * (fsx^2 + fsy^2 + fsz^2) / ks;
                end
            end
        end
        % Scale up by sampling factor
        SE = SE * (nM / length(sampleIds));
    end
    budget.strain = SE;
catch
    budget.strain = 0;
end

% Heat
try
    if d.mo.isHeat && ~isempty(d.mo.aHeat)
        heatTotal = gather(sum(d.mo.aHeat(1:d.mNum)));
        budget.heat = heatTotal;
    else
        budget.heat = 0;
    end
catch
    budget.heat = 0;
end

budget.total = budget.kinetic + budget.strain + budget.heat;
end
