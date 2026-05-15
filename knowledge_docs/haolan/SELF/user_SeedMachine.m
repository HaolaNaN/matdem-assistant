clear;
n=15;dA=360/n;
dA2=dA*1/2;
R=1;R2=1.8*R;R3=1.6*R;

X=[R*cosd(0),R*cosd((dA-dA2)/2),R2*cosd((dA-dA2)/2),R3*cosd((dA+dA2)/2),R*cosd((dA+dA2)/2),R*cosd(dA)];
Y=[R*sind(0),R*sind((dA-dA2)/2),R2*sind((dA-dA2)/2),R3*sind((dA+dA2)/2),R*sind((dA+dA2)/2),R*sind(dA)];
%X=[R3*cosd(-(dA-dA2)/2),R*cosd(-(dA-dA2)/2),X([1,2,3])];
%Y=[R3*sind(-(dA-dA2)/2),R*sind(-(dA-dA2)/2),Y([1,2,3])];

dx=R*deg2rad(dA-dA2)/10;
pts = makeCurve([X',Y'],dx);
S.X=pts(:,1);S.Y=S.X*0;S.Z=pts(:,2);S.R=S.X*0+dx/2;
% fs.showObj(S);
S2=mfs.rotateCopy(S,dA,n,'XZ');
fs.showObj(S2);

B=obj_Box();
B.name='SeedMachine';
B.ballR=dx/2;
B.sampleW=R2*2.1;
B.sampleL=0;
B.sampleH=R2*2.1;
% B.isSample=0;
B.buildInitialModel();
d=B.d;
d.mo.aX=d.mo.aX-B.sampleW/2;
d.mo.aZ=d.mo.aZ-B.sampleH/2;
d.mo.zeroBalance();
B.gravitySediment();

keepFilter=sqrt(d.mo.aX.^2+d.mo.aZ.^2)<R/2 | d.mo.aZ<-(0.3*R2+0.7*R3);
keepFilter(d.mNum+1:end)=true;
d.delElement(find(~keepFilter));
d.GROUP.Machine=d.addElement(1,S2,'Wall');
d.minusGroup('sample','Machine',0.5);
d.showB=2;d.show('aR');

d.clearData();
save(['TempModel/',B.name,'1.mat']);
d.calculateData();
