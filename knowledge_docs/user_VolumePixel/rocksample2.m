clear;
load('TempModel/BoxMicroParticle1.mat'); 

B.setUIoutput();
d=B.d;
B.name='rocksample';
d.calculateData();
d.mo.setGPU('off');
d.getModel();%get xyz from d.mo

sampleR=B.SET.sampleR;
sampleH=B.SET.sampleH;
ballR=B.ballR;
%Z_max = max(d.mo.aZ(1:d.mNum)); 
sampleId=d.getGroupId('sample');
sZ=d.mo.aZ(sampleId);

topLayerFilter=sZ > 0.0025;
d.delElement(find(topLayerFilter));
d.delElement('topPlaten');
%Z_max1 = max(d.mo.aZ(1:d.mNum));

sampleObj=struct('X',d.mo.aX(1:d.mNum),'Y',d.mo.aY(1:d.mNum),'Z',d.mo.aZ(1:d.mNum),'R',d.mo.aR(1:d.mNum));
%d.moveGroup('sample',B.ballR,B.ballR,B.ballR);
%fs.showObj(sampleObj);

%% 定义体素
nii_info = niftiinfo('USER/ganzao.nii');  
source = niftiread(nii_info); 
source =logical(source);
sz=nii_info.ImageSize;
L=0.0025; % 模型长度
W=0.0025;%模型宽度
H=0.0025;% 模型高度
ppx=100/L;
ppy=100/W;
ppz=100/H;
%[xi,yi,zi]=ndgrid(1:sz(1),1:sz(2),1:sz(3));
voxels =source;

%% 求解 
% 1.基于体素区域的连续性假设，仅基于球心坐标判断（尖锐边界处误差较大）
mPos_x=d.mo.aX(1:d.mNum)*ppx;
mPos_y=d.mo.aY(1:d.mNum)*ppy;
mPos_z=d.mo.aZ(1:d.mNum)*ppz;
mPos=[mPos_x,mPos_y,mPos_z];
mSub=ceil(mPos);% 将颗粒位置转换为体素坐标
mInd=sub2ind(sz,mSub(:,1),mSub(:,2),mSub(:,3));
mFilter=voxels(mInd);

s1=mfs.filterObj(sampleObj,mFilter);
%fs.showObj(sampleObj);

% 2.提取球心附近若干体素点（约2000个），统计体素点百分比判断
batchSize=1024;%avoid out of memory
mNum=d.mNum;
sId=1:batchSize:mNum;
eId=min(sId+batchSize-1,mNum);
ppi=40000;
N=max(ceil(d.mo.aR(1:d.mNum)*ppi));
[dx,dy,dz]=ndgrid(-N:N,-N:N,-N:N);

tic
mFilter2=mFilter;
for ii=1:length(sId)
    gId=sId(ii):eId(ii);
    mSub1=mSub(gId,1)+dx(:)';
    mSub2=mSub(gId,2)+dy(:)';
    mSub3=mSub(gId,3)+dz(:)';

    mDis=((mSub1-0.5)/ppi-mPos(gId,1)).^2+((mSub2-0.5)/ppi-mPos(gId,2)).^2+(((mSub3-0.5)/ppi-mPos(gId,3)).^2);
    mN0Filter=sqrt(mDis)<=d.mo.aR(gId);

    %TODO: deal with invalid subs
    mInd=mSub1+(mSub2-1)*sz(1)+(mSub3-1)*sz(1)*sz(2);%sub2ind
    f=mSub1<1 | mSub2<1 | mSub3<1 | mSub1>sz(1) | mSub2>sz(2) | mSub3>sz(3);

    mInd(f)=1;%avoid index error
    mVoxels=voxels(mInd);
    mVoxels(f)=false;
    threshold = 0.5; 
    mFilter2(gId)=sum(mN0Filter&mVoxels,2)./sum(mN0Filter,2)>=threshold;
end
toc


s2=mfs.filterObj(sampleObj,mFilter2);

%%
sampleObj.groupId=sampleObj.X*0;
sampleObj.groupId(mFilter&(~mFilter2))=1;
sampleObj.groupId((~mFilter)&mFilter2)=1;
sampleObj.groupId((~mFilter)&(~mFilter2))=2;

startId=1;
matrixFilter=sampleObj.groupId==startId;
matrixId=find(matrixFilter);
d.addGroup('Matrix',matrixId);%add a new group
endId=2;
delFilter=sampleObj.groupId==endId;
poreId=find(delFilter);
d.addGroup('Pores',poreId);%add a new group
d.delElement(find(delFilter));

d.show('aMatId');

d.clearData();  
d.recordCalHour('step2Finish');
save(['TempModel/' B.name '2.mat'],'B','d');
d.calculateData();