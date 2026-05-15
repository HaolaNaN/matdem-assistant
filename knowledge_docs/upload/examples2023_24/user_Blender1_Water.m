clear
load('TempModel/Blender0.mat');

B = obj_Box();
B.name = SET.name;
B.ballR = SET.ballR;
B.isSample = 0;
B.sampleW = SET.sampleD;
B.sampleL = SET.sampleD;
B.sampleH = SET.sampleH;
B.boundaryStatus = [0,0,0,0,0,1];
B.buildInitialModel();

d=B.d;
d.showB=3;
sId = d.addElement(1, SET.bObj, 'wall');
bId = SET.groupId;
gNames = fieldnames(bId);
for gi=1:length(gNames)
    gName=gNames{gi};
    gId = sId(SET.bObj.groupId == bId.(gName));
    d.addGroup(gName, gId);
end

sampleH = B.sampleH;  
sample = mfs.makeColumn(B.sampleW/2 - 8*B.ballR,sampleH,B.ballR);
sample.Z = sample.Z + 0.5*sampleH;
d.GROUP.sample = d.addElement(1, sample);
d.delElement([d.GROUP.topB;d.GROUP.topPlaten]);
d.mo.frame = struct('minX',-B.sampleW/2,'maxX',B.sampleW/2,'minY',-B.sampleL/2,'maxY',B.sampleL/2,'minZ',0,'maxZ',B.sampleH);
d.addGroup('PaddleAll',[d.GROUP.leftPaddle;d.GROUP.rightPaddle]);

d.mo.mGZ = d.mo.mGZ*10;
d.mo.dT=d.mo.dT*4;
tic
d.balance('Standard',8);
fs.disp(toc);
d.mo.mGZ = d.mo.mGZ/10;
% 自转转速与公转转速比值 C=8.1304
% 左右桨转速相反 k=-1
% 公转 : 左 : 右 = 1 : C/k : C
C=8.1304;k=-1;
rDis = 360; % degree, not radian
totalCircle=120;360;
dRDis = 0.1*1.0;% rDis/totalCircle;
d.tic(totalCircle);

cData=2*(d.mo.aZ>median(d.mo.aZ(d.GROUP.sample)))-1;
cData(d.mNum+1:d.aNum)=0;
d.mo.SET.cData=cData;

d.addGroup('Water',find(cData==-1));
d.mo.SET.aWC=(cData~=1)+0;
% d.mo.isShear=0;
d.mo.mGZ = d.mo.mGZ*10;
for ii=1:totalCircle
    for jj=1:10
    d.rotateGroup('PaddleAll','XY',-dRDis,0,0,0);     % 顺时针
    d.rotateGroup('leftPaddle','XY',dRDis*C/k);   % 顺时针
    d.rotateGroup('rightPaddle','XY',dRDis*C);      % 逆时针

    % water content
    nDWC=d.mo.SET.aWC(d.mo.nBall)-d.mo.SET.aWC(1:d.mNum);
    sumFilter=d.mo.nBall<=d.mNum;
    waterFilter=fs.ind2bool(d.GROUP.Water,d.aNum);
    % waterFilter2=waterFilter & (d.mo.aR > 0.2*d.aR); 
    % sumFilter=sumFilter & ~(waterFilter2(1:d.mNum) | waterFilter2(d.mo.nBall));
    
    mDWC=sum(0.01*nDWC.*sumFilter,2);
    d.mo.SET.aWC(1:d.mNum)=max(d.mo.SET.aWC(1:d.mNum)+mDWC,0);
    % update radius
    d.mo.aR(waterFilter)=d.aR(waterFilter).*(d.mo.SET.aWC(waterFilter)).^(1/3);
    d.mo.aR(~waterFilter)=d.aR(~waterFilter).*(1+d.mo.SET.aWC(~waterFilter)).^(1/3);
    d.mo.aR((1:d.mNum))=max(d.mo.aR(1:d.mNum),0.2*d.aR((1:d.mNum)));
    d.mo.aR((d.mNum+1:d.aNum))=d.aR((d.mNum+1:d.aNum));

    d.balance(50,1);
    end

    % d.showFilter('Group',{'Paddle1','Paddle2','sample'});
    d.showFilter('SlideY',0.5,1);
    d.data.showFilter(1:d.mNum)=true;
    d.data.showFilter(d.GROUP.PaddleAll)=true;
    d.figureNumber = d.show('aR');
    title(sprintf('Step %d/%d: elapsed %f minutes',ii,totalCircle,d.toc));
    % view(2);
    % pause(0.2);

    frames(ii)=getframe();

    % save(['data/step/', B.name, num2str(ii), '.mat'], 'd');
    
end
fs.movie2gif([B.name '_Water.gif'],frames,1/5);

save(['TempModel/' B.name '1.mat']);