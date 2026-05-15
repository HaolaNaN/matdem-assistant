 clear;
%% Step1
B=obj_Box('Conveyer');
B.ballR=0.1;0.04;
B.setFrame([-2,-0.5,0,2,0.5,2]);
B.buildInitialModel();
B.gravitySediment();
fs.saveData(B,1);
%% Step2
[B,d]=fs.loadData('Conveyer1.mat');
d.Mats=[];%reset the materials
d.addMaterial('Soil1','Mats\Soil2.txt',B.ballR);
d.groupMat2Model({'sample'},1);%apply the new material
d.delElement(d.GROUP.topPlaten);
hopper=triangle();
hopper.name='hopperTri';
hopId=hopper.addTriangle(makeHopperTri(B.sampleW,B.sampleL,B.sampleH,B.sampleW/3,B.sampleH));%B.sampleW/6
hopper.addGroup('hopper',hopId);
d.addNewTriangle(hopper);
hopper.setMaterial(mean(d.mo.aKN(1:end-1)));
d.mo.frame.minZ=-B.sampleH;

ballR=B.ballR;R=B.sampleL;L=B.sampleW*2.5;
t0=makeTubeTri(R,L,R/10,-60,60);
t1=makeTubeTri(R,L,R/10,-90,90);% avoid flow out

t1=mfs.rotate(t1,'XZ',-80);
t2=mfs.rotate(t0,'XZ',-150);% copy t0
t2=mfs.move(t2,-0.4*L,0,-0.80*L);
t3=mfs.rotate(t0,'XZ',-100);% copy t0
t3=mfs.move(t3,0.2*L,0,-1.30*L);
t4=mfs.rotate(t0,'XY',90);% copy t0
t4=mfs.rotate(t4,'YZ',-60);
t4=mfs.move(t4,0.7*L,0,-2*L);
belt=triangle();
belt.name='beltTri';
belt.addGroup('t1',belt.addTriangle(t1));
belt.addGroup('t2',belt.addTriangle(t2));
belt.addGroup('t3',belt.addTriangle(t3));
belt.addGroup('t4',belt.addTriangle(t4));
d.addNewTriangle(belt);
belt.setMaterial(mean(d.mo.aKN(1:end-1)));
belt.addGroup('all',[belt.GROUP.t1;belt.GROUP.t2;belt.GROUP.t3;belt.GROUP.t4]);
belt.moveGroup('all',0,0,-B.sampleH);
%return
d.mo.frame.minX=-L;
d.mo.frame.maxX=L;
d.mo.frame.minY=-L/2;
d.mo.frame.maxY=L/2;
d.mo.frame.minZ=-2.5*L;
d.mo.frame.maxZ=L/2;

%d.show('aR');
d.showTri(0.5);
fs.saveData(B,2);
%% Step3
[B,d]=fs.loadData('Conveyer2.mat');
d.resetStatus();
d.setStandarddT();
d.mo.dT=d.mo.dT*4;
d.mo.mVis(:)=mean(d.mo.mVis(:));
d.mo.mVis=d.mo.mVis*0.01;
d.mo.aMUp(:)=0.3;%%
d.mo.setShear('on');

t0=d.balance('Time');
totalT=20;
totalCircle=100;
d.tic(totalCircle)
d.mo.setGPU('auto');
showType='mVX';%mV
fName=['data/step/' d.name num2str(B.ballR) 'loopNum'];
save([fName '0.mat']);
for ii=1:totalCircle
    d.balance('Standard',totalT/t0/totalCircle);
    d.figureNumber=d.show(showType);
    d.showTri(0.5);
    set(d.figureNumber,WindowState='maximized');
    set(findobj(d.figureNumber,Type='patch'),FaceColor=[0.9,0.9,1],FaceLighting='none',EdgeColor='none');
    frames(ii)=getframe();
    save([fName num2str(ii) '.mat']);
    d.toc;
end
fs.movie2gif([B.name,'_',showType,'_',regexprep(char(datetime),'[^\w+]','_'),'.gif'],frames,0.2)
fs.saveData(B,3);
%% ---------------------------------------------
function t=makeTubeTri(R,H,ballR,t1,t2)
n1=ceil(deg2rad(t2-t1)*R/ballR/2);
u1=linspace(t2,t1,n1+1);
n2=ceil(H/ballR/2);
u2=linspace(-H/2,H/2,n2+1)';
X=R*cosd(u1) + zeros(size(u2));
Y=R*sind(u1) + zeros(size(u2));
Z=u2 + zeros(size(u1));
fvc=surf2patch(X,Y,Z,'triangles');
t=struct('SET',[],'X',X(:),'Y',Y(:),'Z',Z(:),'DT',fvc.faces);
t.SET=struct('R',R,'H',H,'ballR',ballR,'theta1',t1,'theta2',t2);
end

function t=makeHopperTri(W,L,H,W2,H2)
    X=[-W2/2,W2/2,W2/2,-W2/2,-W2/2;-W/2,W/2,W/2,-W/2,-W/2;-W/2,W/2,W/2,-W/2,-W/2];
    Y=[-L/2,-L/2,L/2,L/2,-L/2;-L/2,-L/2,L/2,L/2,-L/2;-L/2,-L/2,L/2,L/2,-L/2];
    Z=X*0+[-H2,0,H]';
    fvc=surf2patch(X,Y,Z,'triangles');
    t.X=fvc.vertices(:,1);
    t.Y=fvc.vertices(:,2);
    t.Z=fvc.vertices(:,3);
    t.DT=fvc.faces;
end