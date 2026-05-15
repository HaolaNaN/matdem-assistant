clear
[B,d]=fs.loadData('TriDig1.mat');%load data
ballRTri=0.15;%ballR of bucket and truck box
ballRBowl=0.3;%ballR of the bowl tank
bowlH=d.mo.frame.maxZ;
bowlR=d.mo.frame.maxX;
%cut the box to get round box
delFilter=sqrt(d.mo.aX.*d.mo.aX+d.mo.aY.*d.mo.aY+d.mo.aZ.*d.mo.aZ)+d.mo.aR*1.5>bowlR;
d.delElement(find(delFilter));
d.delElement('topPlaten');
%increase the size of the frame to include truck box
d.mo.frame.maxX=d.mo.frame.maxX*2.2;
d.mo.frame.maxZ=d.mo.frame.maxZ*2;

%----------------defines objects for triangles
boxStatus=[0,1,1,1,1,0];%make the right-side box object (small truck)
w=2;l=1;h=0.5;Rrate=0.7;BexpandRate=2;%define the box size
boxObj=mfs.makeEmptyBox(w,l,h,BexpandRate,ballRTri,Rrate,boxStatus);
bowlObj=mfs.makeBowl(bowlR,bowlH,ballRBowl);%make big bowl for filling elements

sizeRate=1;%make the bucket object
bWidth=1*sizeRate;bHeight=0.53*sizeRate;bLength=0.8*sizeRate;
bucketObj=casefs.makeBucketTri(bWidth,bLength,bHeight,ballRTri);
bucketObj=mfs.move(bucketObj,-bWidth/2,-bHeight/2,bowlH);
bucketObj=mfs.align2Value('middleY',bucketObj,0);
bucketObj=trifs.clearTriangle(bucketObj);%remove narrow triangles
%----------------end defines objects for triangles

%----------------make triangles according to objects
roughTri=triangle();
bowlId=roughTri.addTriangle(bowlObj);
denseTri=triangle();
bucketId=denseTri.addTriangle(bucketObj);
boxId=denseTri.addTriangle(boxObj);

roughTri.addGroup('bowl',bowlId);
denseTri.addGroup('bucket',bucketId);
denseTri.addGroup('box',boxId);

denseTri.moveGroup('bucket',-bowlR/2,0,0);
denseTri.moveGroup('box',bowlR,-l/2,bowlH+ballRTri);
denseTri.rotateGroup('box','XZ',-10);

d.addNewTriangle(roughTri);
d.addNewTriangle(denseTri);
roughTri.setMaterial(mean(d.mo.aKN(1:end-1)));
denseTri.setMaterial(mean(d.mo.aKN(1:end-1)));
%----------------end make triangles according to objects

%----------set material of model
matTxt=load('Mats\Soil1.txt');
Mats{1,1}=material('Soil1',matTxt,B.ballR);
Mats{1,1}.Id=1;
d.Mats=Mats;
%----------end set material of model
%---------assign material to layers and balance the model
d.setGroupMat('sample','Soil1');
d.groupMat2Model({'sample'});
d.balanceBondedModel();%balance the bonded model
d.mo.setGPU('auto');
d.mo.dT=d.mo.dT*4;
d.balance('Standard');

d.show('aR');
d.showTri(0.6);%show triangles with specific alpha
%---------end assign material to layers and balance the model
fs.saveData(B,2);%as the data in the folder TempModel