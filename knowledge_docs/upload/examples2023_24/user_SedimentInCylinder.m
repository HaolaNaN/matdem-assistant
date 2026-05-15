%%
clear;
B=obj_Box();
B.name='SedimentInCylinder';
B.ballR=0.005;
sampleD=0.2;
sampleH=0.2;
B.sampleW=sampleD;
B.sampleL=sampleD;
B.sampleH=sampleH;
B.buildInitialModel();
d=B.d;

d.delElement(find(d.mo.aZ(d.GROUP.sample)>sampleH*pi/4));
sObj=mfs.makeColumn(sampleD/2,sampleH,B.ballR);
sObj=mfs.move(sObj,sampleD/2,sampleD/2,sampleH/2);
d.mo.aX(d.GROUP.sample)=sObj.X(1:length(d.GROUP.sample));
d.mo.aY(d.GROUP.sample)=sObj.Y(1:length(d.GROUP.sample));
d.mo.aZ(d.GROUP.sample)=sObj.Z(1:length(d.GROUP.sample));
d.getModel();
%%
N0=d.mo.TAG.setNearbyBallTime;
d.SET.N0=N0;
d.SET.frames=[];
d.mo.afterBalance=fileread('fun/limitFrameInCylinder.m');
showCommand=['d=obj.dem;N0=obj.TAG.setNearbyBallTime;' 
'if mod(N0,5)==1&&N0>d.SET.N0,d.SET.N0=N0;d.figureNumber=d.show(''aR'');d.SET.frames=[d.SET.frames;getframe()];end;'];
d.mo.afterBalance=[d.mo.afterBalance newline showCommand];
warning('off','MATLAB:ui:javaframe:PropertyToBeRemoved');
tic
B.gravitySediment('auto');
toc
d.mo.afterBalance='';
d.show('aR');

fs.movie2gif('s.gif',d.SET.frames,0.10);