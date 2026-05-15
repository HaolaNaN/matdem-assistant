clear;
%% Step1
B=obj_Box('SeedSow');
B.ballR=0.1;%0.04;
B.setFrame([-2,-1,-1,2,1,1]);
B.setType('topPlaten');
B.buildInitialModel();
B.gravitySediment();
fs.saveData(B,1);
%% Step2
clear;
[B,d]=fs.loadData('SeedSow1.mat');
d.delElement(d.GROUP.topPlaten);
% tubeH=0.5;tubeR=0.5;ballR=0.1;
% tube=triangle();
% tube.name='tube';
% tubeId=tube.addTriangle(makeTube(tubeR,tubeH,ballR));
% tube.addGroup('tube',tubeId);
%d.addNewTriangle(tube);
hollowH=1;hollowR=2;ballRHol=0.1;
hollowObj=phlf.generateHollow(hollowR,hollowH,ballRHol);
hollow=triangle();
holId=hollow.addTriangle(hollowObj);
hollow.addGroup('device',holId);
disc=phlf.makediscTri(hollowR,ballRHol);
device=triangle();
discId=device.addTriangle(disc);
device.addGroup('disc',discId);
% tube.setMaterial(mean(d.mo.aKN(1:end-1)));
% tube.rotateGroup('tube','XZ',90);
fs.showObj(disc)
device.show

%%
function tube = makeTube(tubeR, tubeHeight, ballR)
perimeter = 2 * pi * tubeR;
minSlice = max(ceil(perimeter / (ballR * 2)), 12); % minimum value is 12 make sure smooth enough
nZ = max(ceil(tubeHeight / (ballR * 2)), 3); % minimum value 3 make sure height close
theta = linspace(0, 2*pi, minSlice+1); % 角度参数
zList = linspace(0, tubeHeight, nZ+1); % 高度坐标
[Theta, Z] = meshgrid(theta, zList);
X = tubeR * cos(Theta);
Y = tubeR * sin(Theta);
fvc = surf2patch(X, Y, Z, 'triangles');
faces = fvc.faces;
tube = struct();
tube.X = X(:);
tube.Y = Y(:);
tube.Z = Z(:);
tube.DT = faces;
tube.R = ones(size(tube.X)) * ballR;
tube.SET = struct('tubeR', tubeR, 'tubeHeight', tubeHeight, ...
    'ballR', ballR, 'nTheta', minSlice, 'nZ', nZ);
end

function hollowdiscObj=makeHollow(bowlR,bowlH,ballR)
discObj=mfs.makeDisc(bowlR,ballR);
discObj=trifs.delaunay(discObj);
discObj2=mfs.align2Value('top',discObj,bowlH+ballR);
tubeObj=mfs.makeTube(bowlR,bowlH+ballR*2,ballR);
tubeObj=trifs.delaunay(tubeObj,'Z','tube');
hollowdiscObj=mfs.combineObj(discObj,tubeObj,discObj2);
end