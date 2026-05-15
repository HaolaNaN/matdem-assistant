clear
%% 1.generate fiber
% D0 = 2e-6;%diameter of fiber
% totalV = 0.1e-12;%total volume of fiber
% totalL = totalV/(pi/4*D0^2);%total length of fiber
load('TempModel/Blender0.mat');
D0=2*SET.ballR/5;
totalV=0.005*SET.sampleD^2*SET.sampleH;
totalL = totalV/(pi/4*D0^2);

lenRate = [10,20];%fiber length range: 10*D0 ~ 20*D0
n = ceil(totalL/D0/(lenRate(1)+lenRate(2))*2);%fiber number
fiberL = rand(n,1)*(lenRate(2)-lenRate(1))+lenRate(1);
fiberL = fiberL*D0;

%fiber orientation
azRange = [0,360];
elRange = [20,-20];

fiberAZ = rand(n,1)*(azRange(2)-azRange(1))+azRange(1);
fiberEL = rand(n,1)*(elRange(2)-elRange(1))+elRange(1);

[fiberX,fiberY,fiberZ] = sph2cart(deg2rad(fiberAZ),deg2rad(fiberEL),fiberL);

%plot3(fiberX'.*[-1;1],fiberY'.*[-1;1],fiberZ'.*[-1;1])
%daspect([1,1,1]);
%% 2.discrete fiber
fiberN = ceil(fiberL/D0/0.8)+1;
fiberId = zeros(sum(fiberN),1);
fiberId(cumsum([1;fiberN(1:end-1)]))=1;
fiberId = cumsum(fiberId);

fiberId2 = fiberId*0;
fiberId2(cumsum([1;fiberN(1:end-1)]))=([0;fiberN(1:end-1)]);
fiberId2 = cumsum(1-fiberId2);

fiberId2 = (fiberId2-1)./(fiberN(fiberId)-1)-0.5;

aX = fiberX(fiberId).*fiberId2;
aY = fiberY(fiberId).*fiberId2;
aZ = fiberZ(fiberId).*fiberId2;

fiberObj = struct('X',aX,'Y',aY,'Z',aZ,'R',ones(size(aX))*D0/2,'groupId',fiberId);
%fs.showObj(fiberObj)
bfs.show(fiberObj)
%% 3.place fiber in 3D box
boxWLH=1*[round(max(aX),1,'significant'),round(max(aY),1,'significant'),round(max(aZ),1,'significant')];
reorderIdx=randperm(n)';
[s1,s2,s3]=ind2sub([8,8,20],reorderIdx(fiberId));

fiberCX=s1*boxWLH(1);
fiberCY=s2*boxWLH(2);
fiberCZ=s3*boxWLH(3);

aX=aX+fiberCX;
aY=aY+fiberCY;
aZ=aZ+fiberCZ;

fiberObj2 = struct('X',aX,'Y',aY,'Z',aZ,'R',ones(size(aX))*D0/2,'groupId',fiberId);
%fs.showObj(fiberObj2)
bfs.show(fiberObj2)
save('TempModel/fiber.mat','fiberObj2')
%% 4.gravity sediment